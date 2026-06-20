#!/usr/bin/env bash
set -euo pipefail
SCRIPT_NAME="10-rancher-import-rke2"
source "$(dirname "$0")/../lib/log.sh"

MANIFEST_URL="${1:-}"

if [[ -z "$MANIFEST_URL" ]]; then
  echo "Usage: $0 <rancher-import-manifest-url>"
  exit 1
fi

kubectl apply -f "$MANIFEST_URL"
kubectl -n cattle-system get pods
