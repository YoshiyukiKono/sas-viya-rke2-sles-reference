#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="05-rke2-server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

INVENTORY="${1:-inventory.csv}"
RKE2_VERSION="${RKE2_VERSION:-}"
CLUSTER_CIDR="${CLUSTER_CIDR:-10.42.0.0/16}"
SERVICE_CIDR="${SERVICE_CIDR:-10.43.0.0/16}"

require_file "$INVENTORY"

cp_ip="$(find_first_ip_by_role "$INVENTORY" rke2-control-plane)"
[[ -n "$cp_ip" ]] || die "role=rke2-control-plane was not found."

echo "Inventory       : $INVENTORY"
echo "Control plane IP: $cp_ip"
echo "RKE2_VERSION    : ${RKE2_VERSION:-latest}"
echo

version_env=""
if [[ -n "$RKE2_VERSION" ]]; then
  version_env="INSTALL_RKE2_VERSION='$RKE2_VERSION'"
fi

run_sudo_ssh "$cp_ip" "
  set -e

  mkdir -p /etc/rancher/rke2

  cat >/etc/rancher/rke2/config.yaml <<EOF
write-kubeconfig-mode: '0644'
tls-san:
  - '$cp_ip'
cluster-cidr: '$CLUSTER_CIDR'
service-cidr: '$SERVICE_CIDR'
EOF

  if ! command -v rke2 >/dev/null 2>&1; then
    curl -sfL https://get.rke2.io | $version_env sh -
  fi

  systemctl enable rke2-server
  systemctl start rke2-server

  echo 'Waiting for rke2-server...'
  timeout 180 bash -c 'until systemctl is-active --quiet rke2-server; do sleep 5; done'

  echo 'Node token:'
  cat /var/lib/rancher/rke2/server/node-token

  echo
  echo 'Cluster nodes:'
  /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes -o wide || true
"
