#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

VPS_IP="$(get_vps_ip "${1:-}")"
ENV_FILE="$ROOT_DIR/secrets/openclaw.env"
REMOTE_DIR="/home/${VPS_USER}/openclaw/docker"

require_file "$ENV_FILE"

if ! grep -qE '^OPENCLAW_GATEWAY_TOKEN=.+$' "$ENV_FILE"; then
  echo "Error: OPENCLAW_GATEWAY_TOKEN is missing in $ENV_FILE" >&2
  exit 1
fi

echo "Pushing environment file to $VPS_USER@$VPS_IP:$REMOTE_DIR/.env"
vps_ssh "$VPS_IP" "mkdir -p '$REMOTE_DIR'"
scp "${SSH_OPTS[@]}" "$ENV_FILE" "$VPS_USER@$VPS_IP:$REMOTE_DIR/.env"
vps_ssh "$VPS_IP" "chmod 600 '$REMOTE_DIR/.env'"

echo "Done: env pushed"
