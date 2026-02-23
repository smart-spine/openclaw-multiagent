#!/usr/bin/env bash
# Copy to config/inputs.sh and fill values:
#   cp config/inputs.example.sh config/inputs.sh
# Then load before running terraform:
#   source config/inputs.sh

# Required: Hetzner Cloud API token
# https://console.hetzner.cloud/ -> Project -> Security -> API Tokens
export HCLOUD_TOKEN="CHANGE_ME"
export TF_VAR_hcloud_token="$HCLOUD_TOKEN"

# Required: fingerprint of existing SSH key in Hetzner
# curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" https://api.hetzner.cloud/v1/ssh_keys | jq '.ssh_keys[] | {name, fingerprint}'
export TF_VAR_ssh_key_fingerprint="CHANGE_ME"

# Restrict SSH ingress to your IP(s)
# Example for one IP: export TF_VAR_ssh_allowed_cidrs='["203.0.113.10/32"]'
export TF_VAR_ssh_allowed_cidrs='["0.0.0.0/0"]'

# Optional server sizing/location (cheap default)
export TF_VAR_server_type="cx23"
export TF_VAR_server_location="nbg1"

# Optional overrides
export TF_VAR_project_name="openclaw"
export TF_VAR_app_user="openclaw"
export TF_VAR_app_directory="/home/openclaw/.openclaw"

# Optional runtime for scripts/Makefile
export OPENCLAW_SSH_USER="openclaw"
# If multiple keys exist locally, set the exact private key used by Hetzner fingerprint
# export OPENCLAW_SSH_KEY="$HOME/.ssh/hetzner_ed25519"
