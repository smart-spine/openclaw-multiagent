---
name: cto-intake-wizard
description: Non-technical intake flow for turning broad user intent into executable CTO packets.
---

Use this skill at the start of new user tasks.

## Goal

Collect only organizational inputs and proceed fast with defaults.

## Intake Questions (choose only missing ones)

1. What outcome should be true when this is done?
2. Where should it run (chat/channel/environment)?
3. Should it run on demand, schedule, or trigger?
4. What user-facing output is expected (short alert/report)?
5. Any hard constraints (deadline, compliance, no-downtime)?

## Rules

- Ask at most 3 questions per message.
- Avoid implementation-detail questions unless blocking.
- If user answers partially, fill defaults and continue.
- After intake, immediately publish `CTO_STATUS` and start execution.
- Default to Phase A (`APPLY_PHASE=false`) unless user explicitly asks to apply now.
- Classify intent for delegation packet:
  - user says "create new agent" -> `AGENT_INTENT=NEW_AGENT`
  - user says "sub-agent" -> `AGENT_INTENT=SUB_AGENT`
  - user asks for both -> `AGENT_INTENT=NEW_AGENT_WITH_SUBAGENTS`
- Default orchestration mode:
  - sequential build/test pipeline -> `SEQUENTIAL_SYNC` (`sessions_send`)
  - only explicit background request -> `ASYNC_BACKGROUND` (`sessions_spawn`)
