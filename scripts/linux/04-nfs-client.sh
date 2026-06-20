#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="04-nfs-client"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log.sh"
source "$SCRIPT_DIR/../lib/common.sh"

INVENTORY="${1:-inventory.csv}"
NFS_SERVER_IP="${NFS_SERVER_IP:-$(find_first_ip_by_role "$INVENTORY" nfs)}"
NFS_EXPORT_PATH="${NFS_EXPORT_PATH:-/srv/nfs/viya}"
NFS_MOUNT_PATH="${NFS_MOUNT_PATH:-/mnt/viya-nfs}"

require_file "$INVENTORY"

if [[ -z "$NFS_SERVER_IP" ]]; then
  die "NFS_SERVER_IP is not set and role=nfs was not found in inventory."
fi

echo "Inventory     : $INVENTORY"
echo "NFS server IP : $NFS_SERVER_IP"
echo "Export path   : $NFS_EXPORT_PATH"
echo "Mount path    : $NFS_MOUNT_PATH"
echo

read_inventory "$INVENTORY" | while IFS=',' read -r hostname ip role; do
  [[ "$role" == "nfs" || "$role" == "jump" ]] && continue

  echo "==> Configuring NFS client: $hostname ($ip) [$role]"

  run_sudo_ssh "$ip" "
    set -e
    zypper --non-interactive refresh
    zypper --non-interactive install nfs-client

    mkdir -p '$NFS_MOUNT_PATH'

    if ! grep -q '^$NFS_SERVER_IP:$NFS_EXPORT_PATH ' /etc/fstab 2>/dev/null; then
      echo '$NFS_SERVER_IP:$NFS_EXPORT_PATH $NFS_MOUNT_PATH nfs defaults,_netdev 0 0' >> /etc/fstab
    fi

    mount '$NFS_MOUNT_PATH' || mount -a

    echo 'Mounted NFS:'
    df -h '$NFS_MOUNT_PATH' || true
  "

  echo
done
