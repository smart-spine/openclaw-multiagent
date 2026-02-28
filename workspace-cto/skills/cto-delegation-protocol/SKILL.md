---
name: cto-delegation-protocol
description: Deterministic CTO orchestration for Coder->Tester pipelines with retries, rework loop, and plan/apply gates.
---
Use this skill for implementation tasks.

## Scope

This skill owns:
- packet construction for Coder and Tester,
- execution order and retries,
- rework loop,
- apply/smoke/rollback flow.

It does not own user-facing message formatting. Use `cto-user-reporting` for that.

## Preconditions

Before delegation, require:
1. `ARCHITECTURE_BRIEF` (2+ options + recommendation).
2. `ASSUMPTIONS_LOG` (especially in unknown-friendly flows).
3. `FAILURE_POLICY` and `MIN_TEST_PLAN`.

## Packet Schemas

Use compact payloads with stable keys.

### Coder Packet (schema)

```yaml
TASK_ID: <id>
OBJECTIVE: <one-paragraph goal>
APPLY_PHASE: <true|false>
IMPLEMENTATION_MODE: OPENCLAW_NATIVE
AGENT_INTENT: <NEW_AGENT|SUB_AGENT|NEW_AGENT_WITH_SUBAGENTS>
TARGET_ROOT_PATH: <absolute path>
TARGET_WORKSPACE: <absolute path>
PATH_HINTS: [<abs path>, ...]
ARCHITECTURE_BRIEF: <summary>
OPTIONS_EVALUATED: [<optA>, <optB>]
SELECTED_OPTION_RATIONALE: <why>
PLAN_QUALITY_SCORE: <0-10>
ASSUMPTIONS_LOG: [<assumption>, ...]
FAILURE_POLICY:
  TRANSIENT_INFRA: retry_2_backoff
  RECOVERABLE_SPEC_GAP: proceed_with_assumptions
  HARD_BLOCKER: escalate_with_unblock_action
MIN_TEST_PLAN:
  - happy_path
  - failure_path
  - regression_relevant
ACCEPTANCE_CRITERIA: [<criterion>, ...]
DELIVERABLE_FORMAT: CODER_REPORT
```

### Tester Packet (schema)

```yaml
TASK_ID: <id>
APPLY_PHASE: <true|false>
SCOPE: <what to validate>
INPUTS: [<absolute path>, ...]
ASSUMPTIONS_LOG: [<assumption>, ...]
FAILURE_POLICY: <same as coder>
MIN_TEST_PLAN: [happy_path, failure_path, regression_relevant]
ARCHITECTURE_GATE_REQUIRED: true
ACCEPTANCE_CRITERIA: [<criterion>, ...]
REQUIRED_OUTPUT: TEST_REPORT
```

## Orchestration Flow

1. Send immediate status via `cto-user-reporting` and continue.
2. If complexity is medium/high or audience mode is `tech`, run `PLAN_APPROVAL` checkpoint before build (unless user opted out).
3. Run Coder via `sessions_send(sessionKey=agent:coder:main, thinking=high, timeoutSeconds>0)`.
4. Parse strict `CODER_REPORT`.
5. Run Tester via `sessions_send(sessionKey=agent:tester:main, thinking=high, timeoutSeconds>0)`.
6. Parse strict `TEST_REPORT` and decide:
   - PASS -> `READY_FOR_APPLY` (Phase A) or proceed apply (Phase B).
   - FAIL actionable -> send rework packet to Coder and loop (max 5 iterations).
   - BLOCKED hard -> escalate with explicit unblock action.

## Retry and Recovery

- On timeout/incomplete child result: retry once.
- If still incomplete: use `sessions_history` + `session_status` to recover latest result.
- If report format remains invalid after one resend request: mark `BLOCKED`.

## Apply Flow (only when APPLY_PHASE=true)

1. Backup targets.
2. Apply changes.
3. Restart/reload runtime.
4. Run smoke checks from `MIN_TEST_PLAN`.
5. If smoke fails: rollback immediately and mark `REQUIRES_REWORK`.

## Failure Contract

- `TRANSIENT_INFRA`: retry up to 2 with bounded backoff.
- `RECOVERABLE_SPEC_GAP`: proceed with assumptions + risk note.
- `HARD_BLOCKER`: stop only with owner + exact unblock action.

Never classify missing non-critical details as hard blockers.

## Resume Policy

On each new user message:
1. Check unfinished pipeline state.
2. Resume from missing mandatory step first.
3. Avoid asking user to restate task unless artifacts are genuinely missing.
