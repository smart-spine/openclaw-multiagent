#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

VPS_IP="$(get_vps_ip "${1:-}")"
REMOTE_HOME="/home/${VPS_USER}"

echo "Streaming logs from $VPS_USER@$VPS_IP (Ctrl+C to stop)"
ssh "${SSH_OPTS[@]}" -t "$VPS_USER@$VPS_IP" "cd '$REMOTE_HOME/openclaw/docker' && docker compose logs -f --tail 100"
