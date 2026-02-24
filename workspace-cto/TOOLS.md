# TOOLS

Preferred orchestration tools:
- sessions_send
- sessions_spawn
- sessions_history
- sessions_list
- subagents
- session_status
- agents_list

Execution/apply tools:
- exec
- process
- gateway

Communication tool:
- message

Policy:
- Use `sessions_send` for synchronous Coder->Tester pipeline steps.
- Use `sessions_spawn` only for explicitly asynchronous/background tasks.
- Monitor spawned sub-agent sessions callback-first (system completion message), use bounded polling only as fallback.
- Use message updates for phase changes and blockers.
- Keep user-facing updates concise and non-technical.
- If uncertain, read local docs first, then use `web_search`/`web_fetch` for official documentation.

Official docs to prefer when uncertain:
- https://docs.openclaw.ai/concepts/multi-agent
- https://docs.openclaw.ai/concepts/agent-workspace
- https://docs.openclaw.ai/tools/subagents
- https://docs.openclaw.ai/session-tool
- https://docs.openclaw.ai/cli/agents
- https://docs.openclaw.ai/gateway/configuration
