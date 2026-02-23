#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

VPS_IP="$(get_vps_ip "${1:-}")"

require_file "$ROOT_DIR/docker/docker-compose.yml"
require_file "$ROOT_DIR/docker/Dockerfile"
require_file "$ROOT_DIR/docker/entrypoint.sh"

echo "Deploy target: $VPS_USER@$VPS_IP"

REMOTE_HOME="/home/${VPS_USER}"

"$ROOT_DIR/scripts/push-env.sh" "$VPS_IP"
"$ROOT_DIR/scripts/push-config.sh" "$VPS_IP"

scp "${SSH_OPTS[@]}" \
  "$ROOT_DIR/docker/docker-compose.yml" \
  "$ROOT_DIR/docker/Dockerfile" \
  "$ROOT_DIR/docker/entrypoint.sh" \
  "$VPS_USER@$VPS_IP:/home/${VPS_USER}/openclaw/docker/"

vps_ssh "$VPS_IP" "chmod +x '$REMOTE_HOME/openclaw/docker/entrypoint.sh'"

echo "Building and restarting container on VPS..."
vps_ssh "$VPS_IP" "cd '$REMOTE_HOME/openclaw/docker' && docker compose build --pull && docker compose up -d"

vps_ssh "$VPS_IP" "docker image prune -f >/dev/null 2>&1 || true"

echo "Deploy completed"
vps_ssh "$VPS_IP" "cd '$REMOTE_HOME/openclaw/docker' && docker compose ps"
