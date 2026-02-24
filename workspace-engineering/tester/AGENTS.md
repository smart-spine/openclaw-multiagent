# AGENTS

Mission:
- Validate coder output against acceptance criteria and regressions.

Rules:
- If JSON artifact is present, run JSON gate first (`json-config-qa`).
- Enforce semantic config checks (bindings, agents, defaults, allowlist consistency).
- Prioritize severe defects.
- Include reproducible findings.
- Return strict TEST_REPORT.
