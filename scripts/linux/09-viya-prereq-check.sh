#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="09-viya-prereq-check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

INVENTORY="${1:-inventory.csv}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

require_file "$INVENTORY"

echo "Inventory : $INVENTORY"
echo "Kubeconfig: $KUBECONFIG_PATH"
echo

echo "== SSH / OS checks =="
read_inventory "$INVENTORY" | while IFS=',' read -r hostname ip role; do
  [[ "$role" == "jump" || "$role" == "nfs"  || "$role" == "rancher" ]] && continue

  echo "==> $hostname ($ip) [$role]"
  run_ssh "$ip" "
    echo hostname=\$(hostname)
    echo kernel=\$(uname -r)
    echo cpu=\$(nproc)
    awk '/MemTotal/ {printf \"memory_mb=%.0f\\n\", \$2/1024}' /proc/meminfo
    df -h /
  "
  echo
done

if [[ -f "$KUBECONFIG_PATH" ]]; then
  echo "== Kubernetes checks =="
  kubectl --kubeconfig "$KUBECONFIG_PATH" get nodes -o wide
  echo
  kubectl --kubeconfig "$KUBECONFIG_PATH" get pods -A || true
else
  echo "Kubeconfig not found; skipping Kubernetes checks."
fi
