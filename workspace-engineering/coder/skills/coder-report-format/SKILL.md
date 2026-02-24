---
name: coder-report-format
description: Deterministic Coder handoff format for CTO and Tester.
---
When finishing implementation, return:

CODER_REPORT
Status: DONE | BLOCKED
TaskId: <TASK_ID>
Summary: <brief>
SessionJson:
- Path: <path or none>
- SyntaxCheck: PASS | FAIL | SKIPPED
ChangedFiles:
- <path>
CommandsRun:
- <command>
Validation:
- <result>
KnownLimitations:
- <item or none>
HandoffToTester:
- <validation target>

Rules:
- Include only files actually changed.
- Include only commands actually executed.
- If `SESSION_JSON_PATH` was provided, include it in `SessionJson.Path` and run `jq -e`.
- If blocked, explain exact blocker and unblock options in `Summary` and `KnownLimitations`.
