# OpenClaw Agent Development Guide

Last updated: 2026-02-23
Scope: OpenClaw framework (including legacy names Clawdbot/Moltbot) for production multi-agent systems.

---

## 1. What OpenClaw Is (in practice)

OpenClaw is a local-first AI gateway with one control plane process (`Gateway`) that:
- accepts inbound messages from channels (WhatsApp/Telegram/Discord/Slack/etc.),
- routes each message to a specific agent (`agentId`),
- runs agent turns with tools,
- persists per-agent sessions/transcripts/state.

Core model:
- one running Gateway process,
- many isolated agents in one Gateway,
- deterministic routing via `bindings`.

---

## 2. Legacy Naming (Clawdbot/Moltbot -> OpenClaw)

OpenClaw currently ships compatibility shims:
- `packages/moltbot/package.json` (`name: "moltbot"`, description: compatibility shim)
- `packages/clawdbot/package.json` (`name: "clawdbot"`, description: compatibility shim)
- postinstall scripts print:
  - `moltbot renamed -> openclaw`
  - `clawdbot renamed -> openclaw`

Takeaway:
- production configs and docs should target `openclaw` names/commands,
- old package names are alias/shim paths for migration compatibility.

---

## 3. Runtime Architecture

### 3.1 Gateway

Gateway is the single long-lived control plane:
- default WS/HTTP endpoint: `127.0.0.1:18789`,
- first client frame must be `connect`,
- multiplexes RPC/events/channels/web UI/tools APIs on one service.

It owns:
- channel connections,
- routing resolution,
- session persistence,
- agent execution orchestration.

### 3.2 Agent runtime loop

High-level loop:
1. Accept request (`agent` RPC).
2. Resolve session + agent + model/tool policy.
3. Build system prompt + context.
4. Execute model/tool loop.
5. Stream lifecycle/assistant/tool events.
6. Persist transcript + session metadata.

Important:
- per-session execution is serialized (queue lanes),
- sub-agent flows use dedicated queue lane `subagent`.

### 3.3 Storage and path model

Default paths:
- config: `~/.openclaw/openclaw.json` (JSON5),
- state root: `~/.openclaw`,
- default workspace: `~/.openclaw/workspace`,
- per-agent state dir: `~/.openclaw/agents/<agentId>/agent`,
- per-agent sessions store: `~/.openclaw/agents/<agentId>/sessions/sessions.json`,
- per-session transcript: `~/.openclaw/agents/<agentId>/sessions/<SessionId>.jsonl`.

Critical isolation rule:
- never reuse `agentDir` across agents (auth/session collisions risk),
- each agent should have separate `workspace` and `agentDir`.

---

## 4. Workspace Contract and Agent Identity

### 4.1 Bootstrap files

OpenClaw expects bootstrap files in workspace root:
- `AGENTS.md`
- `SOUL.md`
- `TOOLS.md`
- `IDENTITY.md`
- `USER.md`
- `HEARTBEAT.md`
- `BOOTSTRAP.md` (new workspace only)
- optional `MEMORY.md` / `memory.md`

These files are injected into context (with truncation limits):
- `agents.defaults.bootstrapMaxChars` (default 20000 per file),
- `agents.defaults.bootstrapTotalMaxChars` (default 150000 total).

### 4.2 Identity configuration options

Identity is configured in `agents.list[].identity`:
- `name`
- `theme`
- `emoji`
- `avatar`

And can be imported from workspace `IDENTITY.md`:

```bash
openclaw agents set-identity --workspace ~/.openclaw/workspace --from-identity
```

Parser behavior (source-level):
- reads Markdown lines like `- Name: ...`, `- Emoji: ...`, `- Creature: ...`, `- Vibe: ...`, `- Avatar: ...`,
- maps `creature`/`vibe` into `theme` fallback when applying identity.

Note on YAML:
- identity is not configured via YAML config files in OpenClaw runtime config,
- YAML is used in other places (for example skill frontmatter in `SKILL.md`), not as primary agent identity config.

---

## 5. Creating Isolated Agents

### 5.1 CLI workflow

Interactive:

```bash
openclaw agents add work
```

Non-interactive:

```bash
openclaw agents add work \
  --workspace ~/.openclaw/workspace-work \
  --agent-dir ~/.openclaw/agents/work/agent \
  --model openai/gpt-5.2 \
  --bind telegram:alerts \
  --non-interactive
```

What this configures:
- `agents.list[].id`
- `agents.list[].workspace`
- `agents.list[].agentDir`
- optional `agents.list[].model`
- optional bindings

### 5.2 Config-first approach

Minimal multi-agent skeleton:

```json5
{
  agents: {
    list: [
      { id: "main", default: true, workspace: "~/.openclaw/workspace-main" },
      { id: "work", workspace: "~/.openclaw/workspace-work" }
    ]
  }
}
```

---

## 6. Multi-Agent Routing

Routing is deterministic via `bindings`.

Example:

```json5
{
  agents: {
    list: [
      { id: "home", default: true, workspace: "~/.openclaw/workspace-home" },
      { id: "work", workspace: "~/.openclaw/workspace-work" }
    ]
  },
  bindings: [
    { agentId: "home", match: { channel: "whatsapp", accountId: "personal" } },
    { agentId: "work", match: { channel: "whatsapp", accountId: "biz" } }
  ]
}
```

Match priority (resolved in code/runtime):
1. `peer`
2. `parentPeer` (thread inheritance)
3. `guildId + roles`
4. `guildId`
5. `teamId`
6. account-level match
7. channel-wide match (`accountId: "*"`)
8. default agent

If multiple bindings match in same tier, first in config order wins.

---

## 7. Session Model and Context Isolation

Main direct session:
- `agent:<agentId>:main`

Group/channel sessions:
- `agent:<agentId>:<channel>:group:<id>`
- `agent:<agentId>:<channel>:channel:<id>`

DM scope control (`session.dmScope`):
- `main` (default),
- `per-peer`,
- `per-channel-peer`,
- `per-account-channel-peer`.

Use `identityLinks` when you want one person across channels to map to one canonical identity key.

---

## 8. Inter-Agent Task Transfer and Delegation

OpenClaw provides two core mechanisms:

### 8.1 `sessions_send` (message another session)

Capabilities:
- send to another session key/session id,
- optional wait for completion,
- can trigger agent-to-agent ping-pong + announce flow.

Security gates:
- `tools.sessions.visibility` (`self` | `tree` | `agent` | `all`),
- cross-agent requires `tools.agentToAgent.enabled=true`,
- optional allowlist in `tools.agentToAgent.allow`.

### 8.2 `sessions_spawn` (sub-agent)

Creates isolated child session:
- key shape: `agent:<agentId>:subagent:<uuid>`

Key controls:
- `agents.list[].subagents.allowAgents` (which `agentId` can be targeted),
- `agents.defaults.subagents.maxSpawnDepth`,
- `agents.defaults.subagents.maxChildrenPerAgent`,
- `agents.defaults.subagents.maxConcurrent`,
- `agents.defaults.subagents.archiveAfterMinutes`.

Modes:
- `mode: "run"` one-shot,
- `mode: "session"` persistent thread-bound (with `thread: true`).

Sub-agent defaults:
- isolated session,
- reduced prompt mode (`minimal`),
- by default no session tools for leaf sub-agents.

---

## 9. Tools, Skills, and Guardrails

### 9.1 Tool policy

Main controls:
- global: `tools.profile`, `tools.allow`, `tools.deny`,
- per-agent: `agents.list[].tools.*`,
- sandbox-only policy: `tools.sandbox.tools.*` / `agents.list[].tools.sandbox.tools.*`,
- sub-agent policy: `tools.subagents.tools.*`.

Rule:
- `deny` always wins.

### 9.2 Sandbox

`agents.defaults.sandbox` or `agents.list[].sandbox`:
- `mode`: `off` | `non-main` | `all`,
- `scope`: `session` | `agent` | `shared`,
- `workspaceAccess`: `none` | `ro` | `rw`.

Important:
- workspace path alone is not hard isolation,
- hard(er) isolation requires sandboxing + strict tool policy.

### 9.3 Elevated and exec approvals

`tools.elevated`:
- exec-only host escape hatch from sandbox,
- does not override tool denial.

Exec approvals:
- separate guardrail for host exec,
- policy + allowlist + approval prompt path,
- configured per host (`~/.openclaw/exec-approvals.json`).

### 9.4 Skills

Skill source precedence:
1. `<workspace>/skills` (highest)
2. `~/.openclaw/skills`
3. bundled skills
4. `skills.load.extraDirs` (lowest)

Per-agent behavior:
- each agent sees workspace-local skills from its own workspace,
- managed skills are shared at machine scope.

---

## 10. Production Design Principles for Multi-Agent Systems

1. Isolate by default:
   - one workspace + one agentDir per agent.
2. Route most specific to least specific:
   - peer rules before account/channel rules.
3. Enforce tool least-privilege:
   - start from `minimal`/`messaging`, then open only required tools.
4. Sandbox untrusted surfaces:
   - especially public/group-facing agents.
5. Treat cross-agent communication as privileged:
   - require explicit `tools.agentToAgent` enablement and allowlist.
6. Keep bootstrap docs concise:
   - they are injected every run and consume tokens.
7. Run security audit regularly:
   - `openclaw security audit --deep`.

---

## 11. Suggested Folder Layout (for multi-agent org setups)

```text
~/.openclaw/
  openclaw.json
  skills/                          # shared managed skills
  agents/
    cto/
      agent/auth-profiles.json
      sessions/
    coder/
      agent/auth-profiles.json
      sessions/
    tester/
      agent/auth-profiles.json
      sessions/
  workspace-cto/
    AGENTS.md
    SOUL.md
    IDENTITY.md
    TOOLS.md
    USER.md
    skills/
  workspace-coder/
    ...
  workspace-tester/
    ...
```

---

## 12. Operational Commands (day-2)

```bash
openclaw gateway status
openclaw channels status --probe
openclaw agents list --bindings
openclaw sandbox explain --json
openclaw security audit --deep
openclaw doctor
```

---

## 13. Reference Links (Primary Sources)

- Gateway architecture: https://docs.openclaw.ai/concepts/architecture
- Multi-agent routing: https://docs.openclaw.ai/concepts/multi-agent
- Channel routing: https://docs.openclaw.ai/channels/channel-routing
- Session model: https://docs.openclaw.ai/concepts/session
- Session tools: https://docs.openclaw.ai/concepts/session-tool
- Sub-agents: https://docs.openclaw.ai/tools/subagents
- System prompt: https://docs.openclaw.ai/concepts/system-prompt
- Context: https://docs.openclaw.ai/concepts/context
- Agent workspace: https://docs.openclaw.ai/concepts/agent-workspace
- Gateway config reference: https://docs.openclaw.ai/gateway/configuration-reference
- Sandboxing: https://docs.openclaw.ai/gateway/sandboxing
- Sandbox vs tool policy vs elevated: https://docs.openclaw.ai/gateway/sandbox-vs-tool-policy-vs-elevated
- Skills: https://docs.openclaw.ai/tools/skills
- CLI agents: https://docs.openclaw.ai/cli/agents
- OpenClaw repo: https://github.com/openclaw/openclaw
- Legacy package shim evidence:
  - https://github.com/openclaw/openclaw/tree/main/packages/moltbot
  - https://github.com/openclaw/openclaw/tree/main/packages/clawdbot

---

## 14. Implemented IT-Department Blueprint v2 (This Repository)

Implemented file structure:

```text
/Users/uladzislaupraskou/openclaw-multiagent/
  config/openclaw.json
  workspace-main/
    AGENTS.md
    IDENTITY.md
    SOUL.md
    TOOLS.md
    USER.md
    HEARTBEAT.md
    BOOTSTRAP.md
  workspace-cto/
    AGENTS.md
    IDENTITY.md
    SOUL.md
    TOOLS.md
    USER.md
    HEARTBEAT.md
    skills/
  workspace-engineering/
    coder/
      AGENTS.md
      IDENTITY.md
      SOUL.md
      TOOLS.md
      USER.md
      HEARTBEAT.md
      skills/
    tester/
      AGENTS.md
      IDENTITY.md
      SOUL.md
      TOOLS.md
      USER.md
      HEARTBEAT.md
      skills/
  agents/
    main/agent/
    cto/agent/
    coder/agent/
    tester/agent/
```

Runtime mapping on VPS/container after `make push-config`:
- `workspace-main/*` -> `~/.openclaw/workspace/workspace-main/*`
- `workspace-cto/*` -> `~/.openclaw/workspace/workspace-cto/*`
- `workspace-engineering/*` -> `~/.openclaw/workspace/workspace-engineering/*`
- agent dirs ensured at:
  - `~/.openclaw/agents/main/agent`
  - `~/.openclaw/agents/cto/agent`
  - `~/.openclaw/agents/coder/agent`
  - `~/.openclaw/agents/tester/agent`

Configured behavior in `config/openclaw.json`:
- `main` is default fallback agent.
- `cto` is bound only to Telegram topic:
  - `group:-1003633569118:topic:2`
- `coder` and `tester` are worker sub-agents.
- Models:
  - primary: `openai/gpt-5.2-codex`
  - fallback: `openai/gpt-5.1-codex`
- Cross-agent communication enabled via:
  - `tools.agentToAgent.enabled = true`
  - `tools.agentToAgent.allow = ["cto", "coder", "tester"]`
- CTO can spawn only `coder` and `tester` via:
  - `agents.list[id=cto].subagents.allowAgents = ["coder", "tester"]`
- CTO tool surface is intentionally minimal:
  - `sessions_spawn`, `subagents`, `agents_list`, `session_status`
- Telegram command handling is set to plain-text mode:
  - `channels.telegram.commands.native = false`
- Group history window is capped:
  - `messages.groupChat.historyLimit = 20`
- Global elevated mode disabled (`tools.elevated.enabled = false`).

Workspace skills:
- `workspace-cto/skills/cto-delegation-protocol/SKILL.md`
- `workspace-engineering/coder/skills/coder-report-format/SKILL.md`
- `workspace-engineering/tester/skills/test-report-format/SKILL.md`

Delegation contract:
1. CTO receives user goal.
2. CTO runs `sessions_spawn` -> `coder`.
3. CTO runs `sessions_spawn` -> `tester`.
4. On tester `FAIL`, CTO returns task to coder with rework instructions.
5. On tester `PASS`, CTO reports completion to user.

---

## 15. Verified Runtime Notes (2026-02-23)

Verified on VPS:
- Gateway container starts and binds `127.0.0.1:18789`.
- Telegram plugin is loaded and channel probe is healthy.
- `main`, `coder`, and `tester` local smoke calls succeed on `gpt-5.2-codex`.
- `cto` prompt footprint was reduced significantly by bootstrap/tool minimization.

Stability hardening applied:
- `agents.defaults.contextPruning` is enabled with `cache-ttl` pruning.
- CTO now uses explicit `maxTokens` cap to reduce burst output and retry pressure.
- CTO sub-agent calls are pinned to `openai/gpt-5.2-codex` to avoid accidental model inheritance.
- Group history injection is reduced (`messages.groupChat.historyLimit=12`).

---

## 16. Launch and Test Commands

From local machine in this repository:

```bash
source config/inputs.sh
make push-config
make deploy
make status
```

If `make push-config` fails with intermittent SSH reset, rerun the command; this was observed as transient infrastructure behavior.

Open tunnel to dashboard (optional):

```bash
make tunnel
# then open http://127.0.0.1:18789
```

SSH to VPS and test CTO directly inside gateway container:

```bash
make ssh
cd ~/openclaw/docker
docker compose ps
docker compose exec openclaw-gateway openclaw agents list --bindings
docker compose exec openclaw-gateway openclaw channels status --probe --json
docker compose exec openclaw-gateway openclaw models status --agent main --json
docker compose exec openclaw-gateway openclaw models status --agent cto --json
docker compose exec openclaw-gateway openclaw agent --local --agent main -m "Reply with MAIN_OK only" --json
docker compose exec openclaw-gateway openclaw agent --local --agent coder -m "Reply with CODER_OK only" --json
docker compose exec openclaw-gateway openclaw agent --local --agent tester -m "Reply with TESTER_OK only" --json
docker compose exec openclaw-gateway openclaw agent --local --agent cto -m "Reply with CTO_OK only" --json
```

Telegram e2e and edge-case scenarios:
- See `docs/cto-agent-team-test-cases.md`.

---

## 17. JSON-First QA Workflow for CTO Team (Verified Pattern)

This repository now uses a JSON-first guardrail for config-style tasks:

1. CTO creates a per-task artifact path:
   - `artifacts/openclow-<TASK_ID>.json`
2. Coder edits that artifact and runs JSON syntax check (`jq -e`).
3. Tester runs JSON gate before any other QA:
   - syntax,
   - required top-level blocks,
   - normalized diff vs baseline (`jq -S` + `diff`),
   - semantic OpenClaw checks (agent ids/defaults/bindings/telegram allowlist consistency),
   - immutable path checks (optional),
   - live-config mutation detection for `APPLY_PHASE=false`.
4. CTO allows apply/restart only after:
   - Tester `JsonGate: PASS`,
   - overall `TEST_REPORT Status: PASS`.

Implemented files:
- `workspace-engineering/tester/skills/json-config-qa/SKILL.md`
- `workspace-engineering/tester/skills/json-config-qa/scripts/json_gate.sh`
- `workspace-engineering/tester/IDENTITY.md`
- `workspace-cto/IDENTITY.md`
- `workspace-cto/skills/cto-delegation-protocol/SKILL.md`

### 17.1 Sub-Agent Chat Reporting (Runtime/Tokens/Cost)

For each `sessions_spawn` call (Coder and Tester), CTO should post an `AGENT_RUN_CARD`:

```text
AGENT_RUN_CARD
Agent: <coder|tester>
TaskId: <TASK_ID>
ResultWords: <plain-language summary>
RuntimeSeconds: <seconds|unknown>
Tokens: <count|unknown>
CostUSD: <usd|unknown>
NextAction: <cto next step>
```

Source of metrics:
- `sessions_spawn` response/announce stats (runtime/tokens and optional cost when provider returns cost data).

### 17.2 Local Skill Smoke Check

Quick local validation for the new QA skill script:

```bash
bash -n workspace-engineering/tester/skills/json-config-qa/scripts/json_gate.sh

# PASS example
bash workspace-engineering/tester/skills/json-config-qa/scripts/json_gate.sh \
  --candidate config/openclaw.json \
  --baseline config/openclaw.json \
  --required-keys "gateway,channels,agents,tools,bindings,auth" \
  --immutable-paths "gateway.port,auth.order" \
  --apply-phase "false"
```
