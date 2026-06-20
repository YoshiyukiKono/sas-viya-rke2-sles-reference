#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="08-node-labels"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

INVENTORY="${1:-inventory.csv}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

require_file "$INVENTORY"
require_file "$KUBECONFIG_PATH"

echo "Inventory : $INVENTORY"
echo "Kubeconfig: $KUBECONFIG_PATH"
echo

read_inventory "$INVENTORY" | while IFS=',' read -r hostname ip role; do
  case "$role" in
    rke2-control-plane|viya-control|viya-compute|viya-default|viya-cas|viya-stateful|viya-stateless)
      echo "==> Labeling $hostname as $role"
      kubectl --kubeconfig "$KUBECONFIG_PATH" label node "$hostname" "viya.sas.com/role=$role" --overwrite || true
      kubectl --kubeconfig "$KUBECONFIG_PATH" label node "$hostname" "node-role.kubernetes.io/$role=true" --overwrite || true
      ;;
    *)
      echo "Skipping $hostname [$role]"
      ;;
  esac
done

echo
kubectl --kubeconfig "$KUBECONFIG_PATH" get nodes --show-labels
