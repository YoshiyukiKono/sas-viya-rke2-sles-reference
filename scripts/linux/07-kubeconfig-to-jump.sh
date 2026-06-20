#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="07-kubeconfig-to-jump"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

INVENTORY="${1:-inventory.csv}"
KUBECONFIG_OUT="${KUBECONFIG_OUT:-$HOME/.kube/config}"

require_file "$INVENTORY"

cp_ip="$(find_first_ip_by_role "$INVENTORY" rke2-control-plane)"
[[ -n "$cp_ip" ]] || die "role=rke2-control-plane was not found."

echo "Control plane IP: $cp_ip"
echo "Kubeconfig out  : $KUBECONFIG_OUT"
echo

tmp_remote="/home/${DEFAULT_SSH_USER}/rke2.yaml"
tmp_local="./rke2-$(date +%Y%m%d-%H%M%S).yaml"

run_sudo_ssh "$cp_ip" "
  set -e
  cp /etc/rancher/rke2/rke2.yaml '$tmp_remote'
  chown '$DEFAULT_SSH_USER':'$DEFAULT_SSH_USER' '$tmp_remote'
"

scp "${SSH_OPTS[@]}" "${DEFAULT_SSH_USER}@${cp_ip}:${tmp_remote}" "$tmp_local"

mkdir -p "$(dirname "$KUBECONFIG_OUT")"
sed "s/127.0.0.1/$cp_ip/g" "$tmp_local" > "$KUBECONFIG_OUT"
chmod 600 "$KUBECONFIG_OUT"

rm -f "$tmp_local"

echo "Kubeconfig written to: $KUBECONFIG_OUT"
echo
kubectl --kubeconfig "$KUBECONFIG_OUT" get nodes -o wide
