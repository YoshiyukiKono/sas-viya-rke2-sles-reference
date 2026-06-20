#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="03-nfs-server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

INVENTORY="${1:-inventory.csv}"
NFS_EXPORT_PATH="${NFS_EXPORT_PATH:-/srv/nfs/viya}"
NFS_ALLOWED_CIDR="${NFS_ALLOWED_CIDR:-10.0.0.0/24}"
NFS_EXPORT_OPTIONS="${NFS_EXPORT_OPTIONS:-rw,sync,no_subtree_check,no_root_squash}"

require_file "$INVENTORY"

echo "Inventory       : $INVENTORY"
echo "Export path     : $NFS_EXPORT_PATH"
echo "Allowed CIDR    : $NFS_ALLOWED_CIDR"
echo "Export options  : $NFS_EXPORT_OPTIONS"
echo

found="false"

read_inventory "$INVENTORY" | while IFS=',' read -r hostname ip role; do
  [[ "$role" == "nfs" ]] || continue
  found="true"

  echo "==> Configuring NFS server: $hostname ($ip)"

  run_sudo_ssh "$ip" "
    set -e
    zypper --non-interactive refresh
    zypper --non-interactive install nfs-kernel-server

    mkdir -p '$NFS_EXPORT_PATH'
    chown nobody:nobody '$NFS_EXPORT_PATH'
    chmod 0777 '$NFS_EXPORT_PATH'

    if grep -q '^$NFS_EXPORT_PATH ' /etc/exports 2>/dev/null; then
      sed -i \"#^$NFS_EXPORT_PATH #c\\$NFS_EXPORT_PATH $NFS_ALLOWED_CIDR($NFS_EXPORT_OPTIONS)#\" /etc/exports
    else
      echo '$NFS_EXPORT_PATH $NFS_ALLOWED_CIDR($NFS_EXPORT_OPTIONS)' >> /etc/exports
    fi

    exportfs -ra
    systemctl enable --now nfs-server

    if systemctl list-unit-files firewalld.service >/dev/null 2>&1; then
      if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-service=nfs || true
        firewall-cmd --permanent --add-service=mountd || true
        firewall-cmd --permanent --add-service=rpc-bind || true
        firewall-cmd --reload || true
      fi
    fi

    echo 'Exports:'
    exportfs -v
  "

  echo
done
