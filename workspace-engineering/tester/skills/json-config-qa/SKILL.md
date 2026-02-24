---
name: json-config-qa
description: Deterministic JSON integrity, semantic OpenClaw checks, and live-config mutation gate.
---

Use this skill when CTO packet includes `CANDIDATE_JSON_PATH`.

## Inputs

- `TASK_ID` (required)
- `CANDIDATE_JSON_PATH` (required)
- `BASELINE_JSON_PATH` (optional but recommended)
- `LIVE_CONFIG_PATH` (optional, required for non-apply config guard)
- `REQUIRED_TOP_LEVEL_KEYS` (optional, comma-separated)
- `IMMUTABLE_PATHS` (optional, comma-separated dot paths)
- `APPLY_PHASE` (required for config tasks)

## Mandatory Order

1. Run JSON gate script first:

```bash
bash skills/json-config-qa/scripts/json_gate.sh \
  --candidate "<CANDIDATE_JSON_PATH>" \
  --baseline "<BASELINE_JSON_PATH>" \
  --live-config "<LIVE_CONFIG_PATH>" \
  --required-keys "<REQUIRED_TOP_LEVEL_KEYS>" \
  --immutable-paths "<IMMUTABLE_PATHS>" \
  --apply-phase "<APPLY_PHASE>"
```

2. If script returns non-zero, stop and return `TEST_REPORT` with `Status: FAIL` or `BLOCKED`.
3. If script passes, continue with repository-specific functional checks.
4. Keep `JsonGate` section in `TEST_REPORT` populated from script output.

## Interpretation Rules

- `Syntax: FAIL` is always `Status: FAIL`.
- Missing required top-level keys is always `Status: FAIL`.
- Baseline diff with deleted required blocks is always `Status: FAIL`.
- `SemanticChecks: FAIL` is always `Status: FAIL`.
- `ImmutablePaths: FAIL` is always `Status: FAIL`.
- If baseline path is missing and compare is required by CTO packet, use `Status: BLOCKED`.
- If `LIVE_CONFIG_PATH` is provided and differs from baseline while `APPLY_PHASE=false`, set `Status: FAIL`.

## Notes

- Use `jq` when available; fallback parsers `python3` and `node` are supported.
- Compare normalized JSON (`jq -S .`) rather than raw text.
- Script performs OpenClaw semantic checks when candidate looks like OpenClaw config.
- Do not approve when JSON gate failed or was skipped for a JSON task.
