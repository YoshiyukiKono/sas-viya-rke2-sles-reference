#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="10-rancher-import-rke2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

MANIFEST_URL="${1:-}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

if [[ -z "$MANIFEST_URL" ]]; then
  cat <<'EOF'
Usage:
  ./scripts/linux/10-rancher-import-rke2.sh <rancher-import-manifest-url>

Example:
  ./scripts/linux/10-rancher-import-rke2.sh https://rancher.example/v3/import/xxxx.yaml
EOF
  exit 1
fi

require_file "$KUBECONFIG_PATH"

echo "Manifest URL: $MANIFEST_URL"
echo "Kubeconfig  : $KUBECONFIG_PATH"
echo

kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f "$MANIFEST_URL"

echo
echo "Waiting for cattle-system objects..."
kubectl --kubeconfig "$KUBECONFIG_PATH" -n cattle-system get pods || true

echo
echo "If cattle-cluster-agent exists, waiting for rollout..."
if kubectl --kubeconfig "$KUBECONFIG_PATH" -n cattle-system get deploy cattle-cluster-agent >/dev/null 2>&1; then
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n cattle-system rollout status deploy/cattle-cluster-agent --timeout=180s
fi

kubectl --kubeconfig "$KUBECONFIG_PATH" -n cattle-system get pods -o wide || true
