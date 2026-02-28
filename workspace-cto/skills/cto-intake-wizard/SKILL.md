---
name: cto-intake-wizard
description: Audience-adaptive intake for turning broad user intent into executable CTO packets.
---
Use this skill at the beginning of new tasks.

## Goal

Collect enough information to execute without over-questioning.

## Step 1: Detect Audience Mode

Set `audience_mode`:
- `tech` when request is implementation-heavy (APIs, schemas, infra, migrations, performance, models, tools).
- `biz` when request is outcome-driven and non-technical.
- `auto` fallback when uncertain.

Allow explicit overrides from user:
- `/tech` -> `tech`
- `/biz` -> `biz`

## Step 2: Ask Minimal Clarifications (max 3)

### For `biz`
Ask organizational questions only:
1. What outcome should be true when done?
2. Where should result appear/run?
3. Any hard business constraints (deadline/compliance/no-downtime)?

### For `tech`
Ask high-impact design questions:
1. Critical non-functional constraints (latency/reliability/cost)?
2. Integration boundaries (systems/secrets/ownership)?
3. Whether plan approval is desired before coding?

## Step 3: Unknown-Friendly Handling

If user says “don’t know/not sure”:
1. Acknowledge.
2. Choose safe defaults.
3. Record in `ASSUMPTIONS_LOG`.
4. Continue execution without stalling.

Do not escalate unknowns unless they are true blockers.

## Step 4: Produce Intake Output

Return structured intake context for delegation:

```yaml
TASK_ID: <id>
AUDIENCE_MODE: <tech|biz|auto>
OBJECTIVE: <normalized>
DESTINATION: <channel/thread/path>
CADENCE_OR_TRIGGER: <on-demand|schedule|event>
CONSTRAINTS: [<item>, ...]
ASSUMPTIONS_LOG: [<assumption>, ...]
PLAN_APPROVAL_REQUIRED: <true|false>
APPLY_PHASE: <false by default>
```

## Defaults

When user is unsure:
- Destination: current channel/thread.
- Output style: short actionable summary.
- Cadence: on-demand (or hourly for monitoring automations).
- Language: mirror user language.
- Apply mode: `APPLY_PHASE=false` unless explicitly requested.
