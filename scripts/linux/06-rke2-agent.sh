#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="06-rke2-agent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

INVENTORY="${1:-inventory.csv}"
RKE2_VERSION="${RKE2_VERSION:-}"

require_file "$INVENTORY"

cp_ip="$(find_first_ip_by_role "$INVENTORY" rke2-control-plane)"
[[ -n "$cp_ip" ]] || die "role=rke2-control-plane was not found."

echo "Reading RKE2 token from control plane: $cp_ip"
token="$(run_sudo_ssh "$cp_ip" "cat /var/lib/rancher/rke2/server/node-token" | tail -n 1)"
[[ -n "$token" ]] || die "Failed to read RKE2 token."

version_env=""
if [[ -n "$RKE2_VERSION" ]]; then
  version_env="INSTALL_RKE2_VERSION='$RKE2_VERSION'"
fi

read_inventory "$INVENTORY" | while IFS=',' read -r hostname ip role; do
  if ! role_matches_any "$role" viya-control viya-compute viya-default viya-cas viya-stateful viya-stateless; then
    continue
  fi

  echo "==> Joining RKE2 agent: $hostname ($ip) [$role]"

  run_sudo_ssh "$ip" "
    set -e

    mkdir -p /etc/rancher/rke2

    cat >/etc/rancher/rke2/config.yaml <<EOF
server: https://$cp_ip:9345
token: $token
node-name: $hostname
EOF

    if ! command -v rke2 >/dev/null 2>&1; then
      curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE='agent' $version_env sh -
    fi

    systemctl enable rke2-agent
    systemctl start rke2-agent

    echo 'Waiting for rke2-agent...'
    timeout 180 bash -c 'until systemctl is-active --quiet rke2-agent; do sleep 5; done'
  "

  echo
done

echo "Current nodes:"
run_sudo_ssh "$cp_ip" "/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes -o wide"
