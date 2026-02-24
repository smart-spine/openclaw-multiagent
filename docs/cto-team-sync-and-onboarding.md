# CTO Team Sync And Onboarding

This runbook lets another engineer reproduce the same OpenClaw CTO team setup and sync it to the VPS.

## What this sync includes

- Runtime config: `config/openclaw.json`
- Skills manifest: `config/skills-manifest.txt`
- Workspaces:
  - `workspace-main/`
  - `workspace-cto/`
  - `workspace-engineering/`

## Preconditions

- SSH access to the VPS as `openclaw`
- SSH key path exported in `config/inputs.sh` as `OPENCLAW_SSH_KEY`
- Local env files present:
  - `config/inputs.sh`
  - `secrets/openclaw.env` (for deploy/push-env if needed)

## Sync Steps

```bash
cd /Users/uladzislaupraskou/openclaw-multiagent
source config/inputs.sh

# Optional: confirm target host
make -s ip

# Push config + workspaces
make push-config

# Ensure gateway is running with the new config/workspaces
ssh -o StrictHostKeyChecking=accept-new -i "$OPENCLAW_SSH_KEY" -o IdentitiesOnly=yes \
  "${OPENCLAW_SSH_USER:-openclaw}"@"$(make -s ip)" \
  "cd /home/openclaw/openclaw/docker && docker compose up -d && docker compose ps"

# Health checks
make status
```

## Quick Smoke (all core agents)

```bash
ssh -o StrictHostKeyChecking=accept-new -i "$OPENCLAW_SSH_KEY" -o IdentitiesOnly=yes \
  "${OPENCLAW_SSH_USER:-openclaw}"@"$(make -s ip)" '
set -e
for a in main cto coder tester; do
  docker exec docker-openclaw-gateway-1 openclaw agent --local --agent "$a" \
    -m "Reply with ${a^^}_SYNC_OK only" --json
done
'
```

## Tunnel + Dashboard

```bash
make tunnel
# open http://127.0.0.1:18789
```

## Prompt To Paste Into Local Codex

Use this exact prompt in your teammate's local Codex session:

```text
You are working in /Users/uladzislaupraskou/openclaw-multiagent.
Goal: make my local environment and VPS runtime match this repository's current OpenClaw CTO-team setup.

Do the following in order:
1) Read Makefile and scripts/push-config.sh to confirm the sync flow.
2) Source config/inputs.sh.
3) Run make push-config.
4) Restart runtime with:
   ssh -o StrictHostKeyChecking=accept-new -i "$OPENCLAW_SSH_KEY" -o IdentitiesOnly=yes "${OPENCLAW_SSH_USER:-openclaw}"@"$(make -s ip)" "cd /home/openclaw/openclaw/docker && docker compose up -d && docker compose ps"
5) Run make status and summarize container + logs.
6) Run smoke checks for agents: main, cto, coder, tester with local CLI and return results.
7) Do not print secrets or tokens.
8) If something fails, diagnose first and report the minimal fix before applying it.
```

## Notes

- This runbook syncs config/workspaces only. It does not automatically rotate or rewrite secrets.
- If OAuth or Telegram secrets changed, push them separately with `make push-env` and/or `make push-google-secrets`.
