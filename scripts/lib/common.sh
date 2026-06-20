#!/usr/bin/env bash
set -euo pipefail

DEFAULT_SSH_USER="${SSH_USER:-suse}"
DEFAULT_SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

if [[ -n "${DEFAULT_SSH_KEY:-}" && -f "$DEFAULT_SSH_KEY" ]]; then
  SSH_OPTS+=(-i "$DEFAULT_SSH_KEY")
fi

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || die "File not found: $file"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read_inventory() {
  local inventory="$1"
  require_file "$inventory"

  tail -n +2 "$inventory" | while IFS=',' read -r hostname ip role rest; do
    hostname="$(trim "${hostname:-}")"
    ip="$(trim "${ip:-}")"
    role="$(trim "${role:-}")"

    [[ -z "$hostname" || "$hostname" == \#* ]] && continue
    [[ -z "$ip" ]] && continue
    [[ -z "$role" ]] && continue

    printf '%s,%s,%s\n' "$hostname" "$ip" "$role"
  done
}

find_first_ip_by_role() {
  local inventory="$1"
  local role="$2"

  read_inventory "$inventory" | while IFS=',' read -r hostname ip item_role; do
    if [[ "$item_role" == "$role" ]]; then
      echo "$ip"
      return 0
    fi
  done | head -n 1
}

run_ssh() {
  local ip="$1"
  shift
  ssh "${SSH_OPTS[@]}" "${DEFAULT_SSH_USER}@${ip}" "$@"
}

run_sudo_ssh() {
  local ip="$1"
  shift
  local command="$*"
  run_ssh "$ip" "sudo bash -lc $(printf '%q' "$command")"
}

copy_to_remote() {
  local src="$1"
  local ip="$2"
  local dst="$3"
  scp "${SSH_OPTS[@]}" "$src" "${DEFAULT_SSH_USER}@${ip}:${dst}"
}

role_matches_any() {
  local role="$1"
  shift
  local candidate
  for candidate in "$@"; do
    [[ "$role" == "$candidate" ]] && return 0
  done
  return 1
}
