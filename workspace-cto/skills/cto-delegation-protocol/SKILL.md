---
name: cto-delegation-protocol
description: Autonomous CTO packet flow with watchdog, rework loop, and concise user reporting.
---
Use this skill for every implementation task.

## Terminology (must be enforced in packets)

- `NEW_AGENT`: persistent OpenClaw agent definition and config artifacts.
- `SUB_AGENT`: delegated child execution via `sessions_spawn` to existing `agentId` (ephemeral).
- `NEW_AGENT_WITH_SUBAGENTS`: both of the above.
- `SEQUENTIAL_SYNC`: default orchestration mode for Coder->Tester pipelines, executed with `sessions_send` and `timeoutSeconds>0`.
- `ASYNC_BACKGROUND`: optional orchestration mode for non-blocking background runs, executed with `sessions_spawn`.

If user says "create a new agent", default `AGENT_INTENT=NEW_AGENT` unless they explicitly ask only for temporary run logic.

## 0) Immediate User Ack

Send:

`CTO_STATUS`
- TaskId
- Phase: INTAKE
- Done
- Next
- Blockers

Then continue in the same run.

## 1) Intake Wizard (organizational)

Collect only what is needed to proceed:
- expected business outcome,
- target environment/channel,
- trigger/cadence,
- output style,
- hard constraints.

Rules:
- Ask max 3 concise questions per turn.
- Use sensible defaults and proceed.
- Ask technical questions only for hard blockers.

## 2) Coder Packet

Always include:
- TASK_ID
- OBJECTIVE
- CONTEXT
- CONSTRAINTS
- ACCEPTANCE_CRITERIA
- NON_GOALS
- TARGET_WORKSPACE
- APPLY_PHASE
- DELIVERABLE_FORMAT=CODER_REPORT
- PATH_HINTS (absolute paths when relevant)
- EXECUTION_BUDGET (bounded discovery, then implement)
- IMPLEMENTATION_MODE (use `OPENCLAW_NATIVE` unless user explicitly requests external repo integration)
- AGENT_INTENT (`NEW_AGENT` | `SUB_AGENT` | `NEW_AGENT_WITH_SUBAGENTS`)
- TARGET_ROOT_PATH (absolute path; same intent as TARGET_WORKSPACE)
- ARCHITECTURE_CONSTRAINTS
- FORBIDDEN_PATTERNS (for `OPENCLAW_NATIVE`)

For JSON/config tasks also include:
- SESSION_JSON_PATH
- BASELINE_JSON_PATH
- LIVE_CONFIG_PATH
- REQUIRED_TOP_LEVEL_KEYS
- IMMUTABLE_PATHS (optional)
- DOC_LINKS (relevant `docs.openclaw.ai` URLs used for the implementation choice)

## 3) Tester Packet

Always include:
- TASK_ID
- SCOPE
- INPUTS
- ACCEPTANCE_CRITERIA
- APPLY_PHASE
- REQUIRED_OUTPUT=TEST_REPORT
- PATH_HINTS (absolute paths when relevant)
- ARCHITECTURE_GATE_REQUIRED=true

For JSON/config tasks also include:
- CANDIDATE_JSON_PATH
- BASELINE_JSON_PATH
- LIVE_CONFIG_PATH
- REQUIRED_TOP_LEVEL_KEYS
- IMMUTABLE_PATHS (optional)
- DOC_LINKS (relevant `docs.openclaw.ai` URLs used to validate architecture/gates)

For cross-workspace validation, always pass absolute file paths in `INPUTS`; tester must validate those paths directly.

Suggested budget values:
- `DISCOVERY_COMMAND_BUDGET=8`
- `TOTAL_RUNTIME_TARGET_MIN=15`

OpenClaw-native defaults:
- Do not require external app repository.
- Missing deliverable directories/files are normal: scaffold then continue.
- Searching outside `TARGET_ROOT_PATH` is not allowed unless explicitly required.
- Implement as OpenClaw artifacts/config/workspace changes, not as standalone runtime service.

Required `ARCHITECTURE_CONSTRAINTS` for `OPENCLAW_NATIVE`:
- `PROJECT_CONTEXT=OPENCLAW_PROJECT`
- `NO_STANDALONE_RUNTIME=true`
- `MUTATE_ONLY_TARGET_ROOT=true`

Suggested `FORBIDDEN_PATTERNS` for `OPENCLAW_NATIVE`:
- custom Telegram polling/webhook service (`python-telegram-bot`, `run_polling`, custom long-running bot loop),
- requiring ad-hoc `token.json` OAuth runtime bootstrap inside artifact folder,
- direct channel transport replacement outside OpenClaw gateway bindings.

## 4) Watchdog and Execution Control

Default (`SEQUENTIAL_SYNC`) for build/test pipeline:

1. Resolve deterministic direct session keys:
   - coder: `agent:coder:main`
   - tester: `agent:tester:main`
2. Send Coder packet with `sessions_send` (`sessionKey=agent:coder:main`, `timeoutSeconds>0`).
3. Treat `sessions_send` as synchronous wait; parse returned text for strict `CODER_REPORT`.
4. If send times out or returns incomplete output: retry once, then fallback to `sessions_history(sessionKey=agent:coder:main, limit=8)` and `session_status`.
5. Validate strict `CODER_REPORT` format; if invalid, request one resend via `sessions_send`; then mark BLOCKED.
6. Send Tester packet with `sessions_send` (`sessionKey=agent:tester:main`, `timeoutSeconds>0`).
7. Parse strict `TEST_REPORT` from returned text and validate gate outcome.
8. Do not emit final user status until tester verdict exists (PASS/FAIL/BLOCKED).

Optional (`ASYNC_BACKGROUND`) mode:

1. Use `sessions_spawn` only when user explicitly allows asynchronous/background execution.
2. If `sessions_spawn` is used, maintain a resume checkpoint and continue monitoring until tester/final decision is complete.
3. Never end the CTO turn in a waiting state for mandatory pipeline steps.

## 5) Rework Loop

- Flow: Coder -> Tester -> (if fail) Coder rework.
- Maximum 5 loops.
- If fail reason is actionable code/config defect: continue loop.
- If fail reason is external blocker (missing access/credentials/owner decision): stop and escalate to user.
- For each loop iteration, keep `SEQUENTIAL_SYNC` semantics (`sessions_send`) so the loop does not detach.

Architecture gate behavior:
- If Tester reports `ArchitectureGate.StandaloneRuntime=FAIL` for `OPENCLAW_NATIVE`, this is an automatic FAIL and must be sent back to Coder for rework.
- Do not approve Phase A with standalone runtime artifacts unless user explicitly requested that architecture.

## 6) Apply/Smoke/Rollback

Default for implementation tasks: `APPLY_PHASE=false` (Phase A).

Phase A output contract:
- If build/test gates pass and no live mutation is needed: report `Decision: READY_FOR_APPLY`, `Apply: SKIPPED`.
- If not pass: `Decision: BLOCKED` or `REQUIRES_REWORK`.

Phase B starts only when current thread explicitly requests `APPLY_PHASE=true`.

If applying:
1. backup targets,
2. apply change,
3. restart/reload runtime,
4. run smoke checks,
5. if smoke fails: rollback and report `REQUIRES_REWORK` or `BLOCKED`.

## 7) User-Facing Reporting

Do not expose raw `CODER_REPORT` / `TEST_REPORT` by default.

Use short phase updates:

`CTO_STATUS`
- TaskId
- Phase
- Done
- Next
- Blockers: none | <short>

Final output:

`FINAL_REPORT`
- Decision: READY_FOR_APPLY | APPROVED | REQUIRES_REWORK | BLOCKED
- TaskId
- UserSummary
- Delivered
- Verification
- Apply: APPLIED | SKIPPED | ROLLED_BACK
- Risks
- NextAction

## 8) Critical Blocker Definition

A blocker is critical only if CTO cannot resolve it autonomously, for example:
- missing/invalid external credentials,
- missing permissions/access,
- required business decision unavailable,
- external service outage with no fallback.

Only then ask the user for help.

## 9) Resume Policy (anti-stall)

On each new user message before starting fresh work:
1. Check whether there is unfinished pipeline state from prior run (coder completed but tester/final missing).
2. If found, resume from missing step first (usually tester), then publish `FINAL_REPORT`.
3. Do not ask user to repeat the same task unless artifacts are genuinely missing.
