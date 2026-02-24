#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

VPS_IP="$(get_vps_ip "${1:-}")"
ENV_FILE="$ROOT_DIR/secrets/openclaw.env"
LOCAL_OAUTH_JSON="$ROOT_DIR/secrets/google/oauth-client.json"
LOCAL_TOKEN_JSON="$ROOT_DIR/secrets/google/token.json"
REMOTE_DIR="/home/${VPS_USER}/.openclaw/secrets/google"

require_file "$ENV_FILE"

if [[ ! -f "$LOCAL_OAUTH_JSON" || ! -f "$LOCAL_TOKEN_JSON" ]]; then
  echo "Rendering local Google secret JSON files from $ENV_FILE"
  python3 "$ROOT_DIR/scripts/render-google-oauth-secrets.py" --env-file "$ENV_FILE" --out-dir "$ROOT_DIR/secrets/google"
fi

require_file "$LOCAL_OAUTH_JSON"
require_file "$LOCAL_TOKEN_JSON"

echo "Pushing Google OAuth files to $VPS_USER@$VPS_IP:$REMOTE_DIR"
vps_ssh "$VPS_IP" "mkdir -p '$REMOTE_DIR' && chmod 700 '/home/${VPS_USER}/.openclaw/secrets' '$REMOTE_DIR' 2>/dev/null || true"
scp "${SSH_OPTS[@]}" "$LOCAL_OAUTH_JSON" "$VPS_USER@$VPS_IP:$REMOTE_DIR/oauth-client.json"
scp "${SSH_OPTS[@]}" "$LOCAL_TOKEN_JSON" "$VPS_USER@$VPS_IP:$REMOTE_DIR/token.json"
vps_ssh "$VPS_IP" "chmod 600 '$REMOTE_DIR/oauth-client.json' '$REMOTE_DIR/token.json'"

echo "Done: Google OAuth JSON files pushed"
