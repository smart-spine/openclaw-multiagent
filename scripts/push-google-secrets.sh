#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

VPS_IP="$(get_vps_ip "${1:-}")"
LOCAL_OAUTH_JSON="$ROOT_DIR/secrets/google/oauth-client.json"
REMOTE_DIR="/home/${VPS_USER}/.openclaw/secrets/google"

require_file "$LOCAL_OAUTH_JSON"

echo "Pushing Google OAuth client file to $VPS_USER@$VPS_IP:$REMOTE_DIR/oauth-client.json"
vps_ssh "$VPS_IP" "mkdir -p '$REMOTE_DIR' && chmod 700 '/home/${VPS_USER}/.openclaw/secrets' '$REMOTE_DIR' 2>/dev/null || true"
scp "${SSH_OPTS[@]}" "$LOCAL_OAUTH_JSON" "$VPS_USER@$VPS_IP:$REMOTE_DIR/oauth-client.json"
vps_ssh "$VPS_IP" "chmod 600 '$REMOTE_DIR/oauth-client.json'"

echo "Done: Google OAuth client JSON pushed"
