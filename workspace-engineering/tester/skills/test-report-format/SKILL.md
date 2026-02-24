---
name: test-report-format
description: Strict QA verdict format for CTO approval/rework decisions.
---
When validating coder output, return:

TEST_REPORT
Status: PASS | FAIL | BLOCKED
TaskId: <TASK_ID>
JsonGate:
- CandidatePath: <path or none>
- BaselinePath: <path or none>
- LiveConfigPath: <path or none>
- Syntax: PASS | FAIL | BLOCKED
- RequiredBlocks: PASS | FAIL | SKIPPED
- StructuralDiff: CHANGED | UNCHANGED | SKIPPED
- SemanticChecks: PASS | FAIL | SKIPPED
- ImmutablePaths: PASS | FAIL | SKIPPED
- BreakingChanges: <item or none>
LiveConfigMutation: NONE | DETECTED | SKIPPED
Scope:
- <validated scope>
ChecksRun:
- <command>: <result>
Findings:
- [SEV-1|SEV-2|SEV-3] <file:line> <issue>
RegressionRisk: LOW | MEDIUM | HIGH
Recommendation: APPROVE_FOR_CTO | RETURN_TO_CODER
ReworkInstructions:
- <fix request>
ChatSummary:
- HumanResult: <plain-language outcome>
- RuntimeSeconds: <number or unknown>
- Tokens: <number or unknown>
- CostUSD: <number or unknown>

Rules:
- If `CANDIDATE_JSON_PATH` exists, JSON gate runs first and cannot be skipped.
- For config tasks, if live config changed before APPLY_PHASE, set `LiveConfigMutation: DETECTED` and fail.
- If semantic config checks fail, recommendation cannot be APPROVE_FOR_CTO.
- Findings must be actionable and reproducible.
- If no findings, set `Findings: none` and `Recommendation: APPROVE_FOR_CTO`.
- If checks cannot run, use `Status: BLOCKED` with exact reason and unblock steps.
