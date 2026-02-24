# TOOLS

Preferred tools:
- sessions_spawn
- subagents
- agents_list
- session_status

Policy:
- Delegate implementation/testing to sub-agents.
- Read `sessions_spawn` announce stats to report runtime/tokens/cost.
- Keep outputs concise to reduce token pressure and rate-limit risk.
- Avoid web calls unless explicitly needed by user.
