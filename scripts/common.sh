#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/infra/terraform/envs/prod"
VPS_USER="${OPENCLAW_SSH_USER:-openclaw}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
SSH_KEY="${OPENCLAW_SSH_KEY:-}"

if [[ -n "$SSH_KEY" ]]; then
  if [[ ! -f "$SSH_KEY" ]]; then
    echo "Error: OPENCLAW_SSH_KEY points to missing file: $SSH_KEY" >&2
    exit 1
  fi
  SSH_OPTS+=(-i "$SSH_KEY" -o IdentitiesOnly=yes)
fi

get_vps_ip() {
  if [[ -n "${1:-}" ]]; then
    echo "$1"
    return 0
  fi

  if ! command -v terraform >/dev/null 2>&1; then
    echo "Error: terraform is not installed and VPS_IP was not provided." >&2
    return 1
  fi

  local ip
  ip="$(cd "$TERRAFORM_DIR" && terraform output -raw server_ip 2>/dev/null || true)"
  if [[ -z "$ip" ]]; then
    echo "Error: could not resolve server_ip from Terraform output." >&2
    echo "Run: source config/inputs.sh && make tf-apply" >&2
    return 1
  fi

  echo "$ip"
}

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Error: required file not found: $file" >&2
    return 1
  fi
}

vps_ssh() {
  local ip="$1"
  shift
  ssh "${SSH_OPTS[@]}" "$VPS_USER@$ip" "$@"
}
