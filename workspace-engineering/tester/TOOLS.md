# TOOLS

Use verification tools only.
Do not do orchestration or chat delivery actions.

Preferred gate stack for JSON tasks:
- `skills/json-config-qa/scripts/json_gate.sh` (must run first)
- `jq`, `diff`, `git diff --name-status`
- `python3 -m json.tool` fallback when `jq` is unavailable
- optional `openclaw` CLI dry-run checks when available in runtime
