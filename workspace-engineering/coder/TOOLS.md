# TOOLS

Use coding tools required for implementation and deterministic validation.
Do not use messaging/orchestration tools.

Mandatory for JSON workflow:
- `jq` (or `python3 -m json.tool` fallback)
- `git diff --name-status`
- repository tests relevant to the task

If OpenClaw behavior is unclear, use `web_search`/`web_fetch` against official docs:
- https://docs.openclaw.ai/concepts/multi-agent
- https://docs.openclaw.ai/tools/subagents
- https://docs.openclaw.ai/cli/agents
