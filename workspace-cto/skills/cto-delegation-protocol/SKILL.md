---
name: cto-delegation-protocol
description: Strict packet and control-flow protocol for CTO -> Coder -> Tester loops.
---
Use this skill for every implementation task.

## 0) Immediate Ack

Before any spawn, send:

CTO_ACK
- TaskId
- Plan
- NextAction

## 1) Coder Packet

Always send:
- TASK_ID
- OBJECTIVE
- CONTEXT
- CONSTRAINTS
- ACCEPTANCE_CRITERIA
- NON_GOALS
- SESSION_JSON_PATH (for JSON workflow)
- BASELINE_JSON_PATH (for JSON workflow)
- LIVE_CONFIG_PATH (for JSON workflow)
- REQUIRED_TOP_LEVEL_KEYS (for JSON workflow)
- APPLY_PHASE (for JSON workflow)
- DELIVERABLE_FORMAT=CODER_REPORT

## 2) Tester Packet

Always send:
- TASK_ID
- SCOPE
- INPUTS
- CANDIDATE_JSON_PATH (for JSON workflow)
- BASELINE_JSON_PATH (for JSON workflow)
- LIVE_CONFIG_PATH (for JSON workflow)
- REQUIRED_TOP_LEVEL_KEYS (for JSON workflow)
- APPLY_PHASE (for JSON workflow)
- REQUIRED_OUTPUT=TEST_REPORT

## 3) Control Flow

1. Intake -> clarify missing requirements.
2. For JSON tasks define:
   - `SESSION_JSON_PATH=artifacts/openclow-<TASK_ID>.json`
   - `BASELINE_JSON_PATH=artifacts/openclow-<TASK_ID>-baseline.json` (snapshot)
   - `LIVE_CONFIG_PATH=<current source file>`
   - `REQUIRED_TOP_LEVEL_KEYS=<comma list>`
   - `APPLY_PHASE=false`
3. Send packet to `coder` (`sessions_spawn`, `mode=run`).
4. If coder status is `BLOCKED`, ask user for unblock decision.
5. Publish Coder Agent Run Card from announce stats.
6. Send coder result to `tester` (`sessions_spawn`, `mode=run`).
7. Tester must run JSON gate first for JSON tasks.
8. If tester status is `FAIL`, send precise rework to coder.
9. Publish Tester Agent Run Card from announce stats.
10. Max 3 rework cycles, then return `BLOCKED`.
11. If PASS and user confirms apply:
    - set `APPLY_PHASE=true`
    - apply candidate onto live config path
    - restart/reload gateway
12. Final user response is only from CTO.

## 4) JSON Gate Policy

- For JSON workflow, approval is impossible without `TEST_REPORT` JsonGate PASS.
- If JsonGate is FAIL/BLOCKED, decision must be `REQUIRES_REWORK` or `BLOCKED`.
- If tester reports live config mutation outside apply phase, decision must be `REQUIRES_REWORK`.
- Apply/restart actions are allowed only after JsonGate PASS and functional PASS.
- If `APPLY_PHASE=false`, never mutate `LIVE_CONFIG_PATH`.

## 5) Report Validation

Reject sub-agent outputs that do not match required format. Ask that agent to resend in proper format.

## 6) Agent Run Card Format

When `sessions_spawn` returns/announces stats, print:

AGENT_RUN_CARD
Agent: <coder|tester>
TaskId: <TASK_ID>
ResultWords: <plain-language summary>
RuntimeSeconds: <seconds|unknown>
Tokens: <count|unknown>
CostUSD: <usd|unknown>
NextAction: <cto next step>
