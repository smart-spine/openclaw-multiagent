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
require_file "$ROOT_DIR/secrets/openclaw.env"
require_file "$ROOT_DIR/config/openclaw.json"
require_file "$ROOT_DIR/config/skills-manifest.txt"

echo "Bootstrap target: $VPS_USER@$VPS_IP"

if ! vps_ssh "$VPS_IP" "echo SSH_OK" >/dev/null 2>&1; then
  echo "Error: cannot connect to $VPS_USER@$VPS_IP" >&2
  exit 1
fi

REMOTE_HOME="/home/${VPS_USER}"

vps_ssh "$VPS_IP" "mkdir -p '$REMOTE_HOME/openclaw/docker' '$REMOTE_HOME/.openclaw/workspace'"

scp "${SSH_OPTS[@]}" \
  "$ROOT_DIR/docker/docker-compose.yml" \
  "$ROOT_DIR/docker/Dockerfile" \
  "$ROOT_DIR/docker/entrypoint.sh" \
  "$VPS_USER@$VPS_IP:/home/${VPS_USER}/openclaw/docker/"

vps_ssh "$VPS_IP" "chmod +x '$REMOTE_HOME/openclaw/docker/entrypoint.sh'"

"$ROOT_DIR/scripts/push-env.sh" "$VPS_IP"
"$ROOT_DIR/scripts/push-config.sh" "$VPS_IP"

echo "Bootstrap completed"
echo "Next step: make deploy"
