#!/usr/bin/env bash
set -euo pipefail
SCRIPT_NAME="01-register-sles"
source "$(dirname "$0")/../lib/log.sh"

INVENTORY="${1:-inventory.csv}"
REGCODE="${SUSE_REGCODE:-}"

if [[ ! -f "$INVENTORY" ]]; then
  echo "Inventory not found: $INVENTORY"
  exit 1
fi

if [[ -z "$REGCODE" ]]; then
  echo "Set SUSE_REGCODE before running this script."
  echo "Example: export SUSE_REGCODE='<your-reg-code>'"
  exit 1
fi

echo "This script is a reference placeholder."
echo "It should SSH to target nodes and run SUSEConnect using SUSE_REGCODE."
