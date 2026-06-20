#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="${SCRIPT_NAME:-$(basename "$0" .sh)}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOGFILE="${LOGFILE:-./${SCRIPT_NAME}-${TIMESTAMP}.log}"

exec > >(tee -a "$LOGFILE") 2>&1

echo "Log file : $LOGFILE"
echo "Started  : $(date)"
echo "Script   : $SCRIPT_NAME"
echo
