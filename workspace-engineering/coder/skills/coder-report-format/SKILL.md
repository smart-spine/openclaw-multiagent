---
name: coder-report-format
description: Deterministic Coder handoff format for CTO and Tester.
---
When finishing implementation, return:

CODER_REPORT
Status: DONE | BLOCKED
TaskId: <TASK_ID>
Summary: <brief>
ApplyPhase: true | false
BlockerClass: NONE | TRANSIENT_INFRA | MISSING_ACCESS | SPEC_GAP | RUNTIME_ERROR
Architecture:
- Mode: OPENCLAW_NATIVE | EXTERNAL_INTEGRATION
- StandaloneRuntimeDetected: YES | NO
- OpenClawCompliance: PASS | FAIL
SessionJson:
- Path: <path or none>
- SyntaxCheck: PASS | FAIL | SKIPPED
- LiveConfigTouched: YES | NO
ChangedFiles:
- <path>
CommandsRun:
- <command>
Validation:
- <result>
KnownLimitations:
- <item or none>
ChatSummary:
- HumanResult: <plain-language outcome>
- RuntimeSeconds: <number or unknown>
- Tokens: <number or unknown>
- CostUSD: <number or unknown>
HandoffToTester:
- <validation target>

Rules:
- Include only files actually changed.
- Include only commands actually executed.
- If `SESSION_JSON_PATH` was provided, include it in `SessionJson.Path` and run JSON syntax check.
- If blocked, set `BlockerClass` and provide exact unblock options in `KnownLimitations`.
- Missing deliverable directories/files are not blockers by default; create scaffold and continue.
- For OpenClaw-native tasks, absence of app repository files (`package.json`, `pyproject.toml`, etc.) is not a blocker.
- For OpenClaw-native tasks, if standalone runtime patterns were added, set `OpenClawCompliance: FAIL`.
- Never answer with prose-only output; always emit full `CODER_REPORT` block.
- If called for announce-only delivery, return exactly `ANNOUNCE_SKIP`.
