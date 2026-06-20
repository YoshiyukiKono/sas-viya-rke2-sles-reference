#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="02-common-setup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

INVENTORY="${1:-inventory.csv}"
require_file "$INVENTORY"

COMMON_PACKAGES="${COMMON_PACKAGES:-curl wget jq vim git-core tar gzip unzip chrony qemu-guest-agent}"

echo "Inventory       : $INVENTORY"
echo "Common packages : $COMMON_PACKAGES"
echo

read_inventory "$INVENTORY" | while IFS=',' read -r hostname ip role; do
  echo "==> $hostname ($ip) [$role]"

  run_sudo_ssh "$ip" "
    set -e
    zypper --non-interactive refresh
    zypper --non-interactive install $COMMON_PACKAGES

    systemctl enable --now chronyd || systemctl enable --now chrony || true
    systemctl enable --now qemu-guest-agent || true

    echo 'Hostname:'
    hostnamectl

    echo 'Time sync:'
    timedatectl || true
  "

  echo
done
