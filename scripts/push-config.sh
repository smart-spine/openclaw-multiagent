#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

VPS_IP="$(get_vps_ip "${1:-}")"
REMOTE_CONFIG_DIR="/home/${VPS_USER}/.openclaw"
REMOTE_WORKSPACE_DIR="$REMOTE_CONFIG_DIR/workspace"
LOCAL_CONFIG="$ROOT_DIR/config/openclaw.json"
LOCAL_SKILLS="$ROOT_DIR/config/skills-manifest.txt"
LOCAL_WORKSPACE_MAIN="$ROOT_DIR/workspace-main"
LOCAL_WORKSPACE_CTO="$ROOT_DIR/workspace-cto"
LOCAL_WORKSPACE_ENGINEERING="$ROOT_DIR/workspace-engineering"

require_file "$LOCAL_CONFIG"
require_file "$LOCAL_SKILLS"
if [[ ! -d "$LOCAL_WORKSPACE_MAIN" ]]; then
  echo "Error: required directory not found: $LOCAL_WORKSPACE_MAIN" >&2
  exit 1
fi
if [[ ! -d "$LOCAL_WORKSPACE_CTO" ]]; then
  echo "Error: required directory not found: $LOCAL_WORKSPACE_CTO" >&2
  exit 1
fi
if [[ ! -d "$LOCAL_WORKSPACE_ENGINEERING" ]]; then
  echo "Error: required directory not found: $LOCAL_WORKSPACE_ENGINEERING" >&2
  exit 1
fi

echo "Pushing config files to $VPS_USER@$VPS_IP:$REMOTE_CONFIG_DIR"
vps_ssh "$VPS_IP" "mkdir -p '$REMOTE_CONFIG_DIR' '$REMOTE_WORKSPACE_DIR' && chmod 700 '$REMOTE_CONFIG_DIR' '$REMOTE_WORKSPACE_DIR'"
scp "${SSH_OPTS[@]}" "$LOCAL_CONFIG" "$VPS_USER@$VPS_IP:$REMOTE_CONFIG_DIR/openclaw.json"
scp "${SSH_OPTS[@]}" "$LOCAL_SKILLS" "$VPS_USER@$VPS_IP:$REMOTE_CONFIG_DIR/skills-manifest.txt"
vps_ssh "$VPS_IP" "chmod 600 '$REMOTE_CONFIG_DIR/openclaw.json' && chmod 644 '$REMOTE_CONFIG_DIR/skills-manifest.txt'"

echo "Syncing workspace templates to $VPS_USER@$VPS_IP:$REMOTE_WORKSPACE_DIR"
vps_ssh "$VPS_IP" "mkdir -p '$REMOTE_WORKSPACE_DIR/workspace-main' '$REMOTE_WORKSPACE_DIR/workspace-cto' '$REMOTE_WORKSPACE_DIR/workspace-engineering'"
scp -r "${SSH_OPTS[@]}" "$LOCAL_WORKSPACE_MAIN/." "$VPS_USER@$VPS_IP:$REMOTE_WORKSPACE_DIR/workspace-main/"
scp -r "${SSH_OPTS[@]}" "$LOCAL_WORKSPACE_CTO/." "$VPS_USER@$VPS_IP:$REMOTE_WORKSPACE_DIR/workspace-cto/"
scp -r "${SSH_OPTS[@]}" "$LOCAL_WORKSPACE_ENGINEERING/." "$VPS_USER@$VPS_IP:$REMOTE_WORKSPACE_DIR/workspace-engineering/"
vps_ssh "$VPS_IP" "chmod -R u+rwX,go-rwx '$REMOTE_WORKSPACE_DIR/workspace-main' '$REMOTE_WORKSPACE_DIR/workspace-cto' '$REMOTE_WORKSPACE_DIR/workspace-engineering'"

echo "Ensuring remote agent directories exist"
vps_ssh "$VPS_IP" "mkdir -p \
  '$REMOTE_CONFIG_DIR/agents/main/agent' \
  '$REMOTE_CONFIG_DIR/agents/cto/agent' \
  '$REMOTE_CONFIG_DIR/agents/coder/agent' \
  '$REMOTE_CONFIG_DIR/agents/tester/agent' \
  && chmod -R u+rwX,go-rwx '$REMOTE_CONFIG_DIR/agents'"

echo "Done: config pushed"
