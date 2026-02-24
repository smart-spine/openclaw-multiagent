---
name: test-report-format
description: Strict QA verdict format for CTO approval/rework decisions.
---
When validating coder output, return:

TEST_REPORT
Status: PASS | FAIL | BLOCKED
TaskId: <TASK_ID>
BlockerClass: NONE | TRANSIENT_INFRA | MISSING_ACCESS | SPEC_GAP | RUNTIME_ERROR
ArchitectureGate:
- Mode: OPENCLAW_NATIVE | EXTERNAL_INTEGRATION
- StandaloneRuntime: PASS | FAIL | SKIPPED
- OpenClawProjectFit: PASS | FAIL | SKIPPED
- Notes: <short>
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
- For `OPENCLAW_NATIVE`, run ArchitectureGate before JsonGate and behavior checks.
- If JSON candidate path exists, JSON gate must run first.
- For non-apply config work, live config mutation means FAIL.
- Semantic FAIL cannot be approved.
- Findings must be actionable and reproducible.
- If no findings: `Findings: none`, `Recommendation: APPROVE_FOR_CTO`.
- If checks cannot run: `Status: BLOCKED` with precise unblock actions.
- If called for announce-only delivery, return exactly `ANNOUNCE_SKIP`.
