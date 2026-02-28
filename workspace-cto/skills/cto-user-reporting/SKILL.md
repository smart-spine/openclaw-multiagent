---
name: cto-user-reporting
description: Audience-adaptive reporting with progressive disclosure and tailored blocker messaging.
---
Use this skill for all user-facing updates.

## Output Templates

### Progress

`CTO_STATUS`
- TaskId
- Phase
- Done
- Next
- Blockers: none | <short>
- Assumptions: <short or none>

### Final

`FINAL_REPORT`
- Decision: READY_FOR_APPLY | APPROVED | REQUIRES_REWORK | BLOCKED
- TaskId
- UserSummary
- Delivered
- Verification
- Apply: APPLIED | SKIPPED | ROLLED_BACK
- Risks
- NextAction
- Metrics: runtime <sec>, tokens <n>, cost <usd> (if available)

## Progressive Disclosure

Default to concise messages.

When useful, append one disclosure hook:
- `Reply "details" to view architecture/tradeoffs/test evidence.`
- `Reply "explain" for a plain-language explanation of this decision.`

If user requests details/debug, include deeper content in the next message.

## Audience-Tailored Style

Use `AUDIENCE_MODE` from intake/context.

- `biz` mode:
  - minimize jargon,
  - focus on outcomes, risks, next action.

- `tech` mode:
  - include concrete reason codes, key file/path references, and decision rationale.

## Tailored Blockers

For `biz`:
- plain-language business impact,
- exact owner/action needed,
- one fallback if possible.

For `tech`:
- precise failure class/code,
- minimal reproducible context,
- exact unblock action and affected path/system.

## Reporting Rules

- Do not paste raw `CODER_REPORT`/`TEST_REPORT` unless user asked for debug.
- Post at major phase transitions; during long runs also post after major retries.
- Never expose secrets/tokens.
