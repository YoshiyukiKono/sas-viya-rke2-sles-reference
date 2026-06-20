#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="01-register-sles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

INVENTORY="${1:-inventory.csv}"
REGCODE="${SUSE_REGCODE:-}"
ENABLE_PACKAGEHUB="${ENABLE_PACKAGEHUB:-true}"

require_file "$INVENTORY"

if [[ -z "$REGCODE" ]]; then
  cat <<'EOF'
SUSE_REGCODE is not set.

Example:
  export SUSE_REGCODE='<your-registration-code>'
  ./scripts/linux/01-register-sles.sh inventory.csv
EOF
  exit 1
fi

echo "Inventory : $INVENTORY"
echo "SSH user  : $DEFAULT_SSH_USER"
echo "PackageHub: $ENABLE_PACKAGEHUB"
echo

read_inventory "$INVENTORY" | while IFS=',' read -r hostname ip role; do
  echo "==> $hostname ($ip) [$role]"

  run_ssh "$ip" "hostname"

  run_sudo_ssh "$ip" "
    set -e
    if SUSEConnect --status-text | grep -q 'Registered'; then
      echo 'Already registered'
    else
      echo 'Registering SLES'
      SUSEConnect -r '$REGCODE'
    fi

    if [[ '$ENABLE_PACKAGEHUB' == 'true' ]]; then
      if SUSEConnect --list-extensions | grep -q 'SUSE Package Hub 15 SP7 x86_64 (Activated)'; then
        echo 'PackageHub already active'
      else
        echo 'Activating PackageHub'
        SUSEConnect -p PackageHub/15.7/x86_64 || true
      fi
    fi

    zypper --non-interactive refresh
  "

  echo
done
