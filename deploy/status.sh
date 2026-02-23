#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

VPS_IP="$(get_vps_ip "${1:-}")"
REMOTE_HOME="/home/${VPS_USER}"

echo "Status target: $VPS_USER@$VPS_IP"

echo ""
echo "[containers]"
vps_ssh "$VPS_IP" "cd '$REMOTE_HOME/openclaw/docker' && docker compose ps"

echo ""
echo "[gateway logs tail]"
vps_ssh "$VPS_IP" "cd '$REMOTE_HOME/openclaw/docker' && docker compose logs --tail 30 --no-log-prefix openclaw-gateway"

echo ""
echo "[system]"
vps_ssh "$VPS_IP" "bash -s" <<'REMOTE_SCRIPT'
printf 'Disk: '
df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}'
printf 'Memory: '
free -h | awk 'NR==2{print $3"/"$2}'
uptime
REMOTE_SCRIPT
