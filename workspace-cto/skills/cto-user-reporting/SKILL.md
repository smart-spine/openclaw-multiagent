---
name: cto-user-reporting
description: Concise user updates from CTO while keeping sub-agent logs internal.
---

Use this skill for all user-facing updates.

## Progress Update Template

`CTO_STATUS`
- TaskId
- Phase
- Done
- Next
- Blockers: none | <short>

## Final Update Template

`FINAL_REPORT`
- Decision: READY_FOR_APPLY | APPROVED | REQUIRES_REWORK | BLOCKED
- TaskId
- UserSummary
- Delivered
- Verification
- Apply: APPLIED | SKIPPED | ROLLED_BACK
- Risks
- NextAction

## Reporting Rules

- Do not paste raw `CODER_REPORT` or `TEST_REPORT` unless user asks for debug.
- Keep updates short and actionable.
- Highlight blockers with explicit owner/action.
- When available, include one compact metrics line from sub-agent results:
  - `Metrics: runtime <sec>, tokens <n>, cost <usd>`
