#!/usr/bin/env bash
set -euo pipefail

candidate=""
baseline=""
required_keys=""
live_config=""
immutable_paths=""
apply_phase="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --candidate)
      candidate="${2:-}"
      shift 2
      ;;
    --baseline)
      baseline="${2:-}"
      shift 2
      ;;
    --required-keys)
      required_keys="${2:-}"
      shift 2
      ;;
    --live-config)
      live_config="${2:-}"
      shift 2
      ;;
    --immutable-paths)
      immutable_paths="${2:-}"
      shift 2
      ;;
    --apply-phase)
      apply_phase="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${candidate}" ]]; then
  echo "ERROR: --candidate is required" >&2
  exit 2
fi

case "${apply_phase}" in
  true|false) ;;
  *)
    apply_phase="false"
    ;;
esac

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

json_backend=""
if command -v jq >/dev/null 2>&1; then
  json_backend="jq"
elif command -v python3 >/dev/null 2>&1; then
  json_backend="python3"
elif command -v node >/dev/null 2>&1; then
  json_backend="node"
else
  echo "ERROR: require jq, python3, or node for JSON validation" >&2
  exit 2
fi

parse_json() {
  local file="$1"
  if [[ "${json_backend}" == "jq" ]]; then
    jq -e . "${file}" >/dev/null 2>&1
  elif [[ "${json_backend}" == "python3" ]]; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "${file}" >/dev/null 2>&1
  else
    node -e 'const fs=require("fs"); JSON.parse(fs.readFileSync(process.argv[1],"utf8"));' "${file}" >/dev/null 2>&1
  fi
}

canonicalize_json() {
  local file="$1"
  local out="$2"
  if [[ "${json_backend}" == "jq" ]]; then
    jq -S . "${file}" > "${out}"
  elif [[ "${json_backend}" == "python3" ]]; then
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); json.dump(d, sys.stdout, sort_keys=True, indent=2); print()' "${file}" > "${out}"
  else
    node -e 'const fs=require("fs"); const sortObj=(v)=>Array.isArray(v)?v.map(sortObj):(v&&typeof v==="object"?Object.keys(v).sort().reduce((a,k)=>(a[k]=sortObj(v[k]),a),{}):v); const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.stdout.write(JSON.stringify(sortObj(d), null, 2)+"\n");' "${file}" > "${out}"
  fi
}

has_top_level_key() {
  local file="$1"
  local key="$2"
  if [[ "${json_backend}" == "jq" ]]; then
    jq -e --arg k "${key}" 'has($k)' "${file}" >/dev/null 2>&1
  elif [[ "${json_backend}" == "python3" ]]; then
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d,dict) and sys.argv[2] in d else 1)' "${file}" "${key}" >/dev/null 2>&1
  else
    node -e 'const fs=require("fs"); const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.exit((d && typeof d==="object" && !Array.isArray(d) && Object.prototype.hasOwnProperty.call(d, process.argv[2])) ? 0 : 1);' "${file}" "${key}" >/dev/null 2>&1
  fi
}

status="PASS"
syntax_status="PASS"
required_status="SKIPPED"
structural_diff="SKIPPED"
semantic_status="SKIPPED"
semantic_findings="none"
immutable_status="SKIPPED"
immutable_violations="none"
missing_keys="none"
breaking_changes="none"
live_config_mutation="SKIPPED"

breaking_list=()
add_breaking() {
  local reason="$1"
  [[ -z "${reason}" ]] && return 0
  breaking_list+=("${reason}")
}

set_blocked() {
  if [[ "${status}" == "PASS" ]]; then
    status="BLOCKED"
  fi
}

set_fail() {
  status="FAIL"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

candidate_norm="${tmp_dir}/candidate.norm.json"
baseline_norm="${tmp_dir}/baseline.norm.json"
live_norm="${tmp_dir}/live.norm.json"
diff_file="${tmp_dir}/baseline.diff"
: > "${diff_file}"

if [[ ! -f "${candidate}" ]]; then
  syntax_status="BLOCKED"
  set_blocked
  add_breaking "candidate file not found"
else
  if ! parse_json "${candidate}"; then
    syntax_status="FAIL"
    set_fail
    add_breaking "candidate JSON parse failed"
  else
    canonicalize_json "${candidate}" "${candidate_norm}"
  fi
fi

if [[ "${status}" != "FAIL" && -n "${required_keys}" ]]; then
  required_status="PASS"
  IFS=',' read -r -a keys <<< "${required_keys}"
  missing=()
  for key in "${keys[@]}"; do
    key="$(trim "${key}")"
    [[ -z "${key}" ]] && continue
    if ! has_top_level_key "${candidate_norm}" "${key}"; then
      missing+=("${key}")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    required_status="FAIL"
    missing_keys="$(IFS=, ; echo "${missing[*]}")"
    set_fail
    add_breaking "missing required top-level keys"
  fi
fi

if [[ -n "${baseline}" ]]; then
  if [[ ! -f "${baseline}" ]]; then
    set_blocked
    add_breaking "baseline file not found"
  elif ! parse_json "${baseline}"; then
    set_blocked
    add_breaking "baseline JSON parse failed"
  else
    canonicalize_json "${baseline}" "${baseline_norm}"
    if diff -u "${baseline_norm}" "${candidate_norm}" > "${diff_file}"; then
      structural_diff="UNCHANGED"
    else
      structural_diff="CHANGED"
    fi
  fi
fi

if [[ -n "${immutable_paths}" ]]; then
  immutable_status="PASS"
  if [[ -z "${baseline}" || ! -f "${baseline_norm}" ]]; then
    immutable_status="SKIPPED"
    set_blocked
    add_breaking "immutable path check requires baseline"
  else
    if command -v python3 >/dev/null 2>&1; then
      IFS=',' read -r -a paths <<< "${immutable_paths}"
      changed=()
      for path in "${paths[@]}"; do
        path="$(trim "${path}")"
        [[ -z "${path}" ]] && continue
        check="$(python3 - "${baseline_norm}" "${candidate_norm}" "${path}" <<'PY'
import json,sys
baseline=json.load(open(sys.argv[1]))
candidate=json.load(open(sys.argv[2]))
path=sys.argv[3]
def get_path(obj, dotted):
    cur=obj
    for raw in dotted.split('.'):
        part=raw.strip()
        if part == "":
            raise KeyError("empty path segment")
        if isinstance(cur, dict) and part in cur:
            cur=cur[part]
            continue
        if isinstance(cur, list) and part.isdigit():
            idx=int(part)
            if idx < 0 or idx >= len(cur):
                raise KeyError("index out of range")
            cur=cur[idx]
            continue
        raise KeyError(f"segment not found: {part}")
    return cur
try:
    b=get_path(baseline,path)
    c=get_path(candidate,path)
except KeyError:
    print("MISSING")
    sys.exit(0)
print("SAME" if b == c else "DIFF")
PY
)"
        if [[ "${check}" == "DIFF" || "${check}" == "MISSING" ]]; then
          changed+=("${path}")
        fi
      done
      if [[ ${#changed[@]} -gt 0 ]]; then
        immutable_status="FAIL"
        immutable_violations="$(IFS=, ; echo "${changed[*]}")"
        set_fail
        add_breaking "immutable paths changed"
      fi
    elif command -v node >/dev/null 2>&1; then
      result="$(node - "${baseline_norm}" "${candidate_norm}" "${immutable_paths}" <<'NODE'
const fs = require("fs");
const baseline = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const candidate = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
const raw = process.argv[4] || "";
const paths = raw.split(",").map((s) => s.trim()).filter(Boolean);
function getPath(obj, dotted) {
  let cur = obj;
  for (const partRaw of dotted.split(".")) {
    const part = partRaw.trim();
    if (!part.length) return { ok: false };
    if (Array.isArray(cur)) {
      if (!/^\d+$/.test(part)) return { ok: false };
      const idx = Number(part);
      if (idx < 0 || idx >= cur.length) return { ok: false };
      cur = cur[idx];
      continue;
    }
    if (cur && typeof cur === "object" && Object.prototype.hasOwnProperty.call(cur, part)) {
      cur = cur[part];
      continue;
    }
    return { ok: false };
  }
  return { ok: true, value: cur };
}
const changed = [];
for (const p of paths) {
  const b = getPath(baseline, p);
  const c = getPath(candidate, p);
  if (!b.ok || !c.ok || JSON.stringify(b.value) !== JSON.stringify(c.value)) {
    changed.push(p);
  }
}
process.stdout.write(changed.join(","));
NODE
)"
      if [[ -n "${result}" ]]; then
        immutable_status="FAIL"
        immutable_violations="${result}"
        set_fail
        add_breaking "immutable paths changed"
      fi
    else
      immutable_status="SKIPPED"
      set_blocked
      add_breaking "immutable path checks require python3 or node"
    fi
  fi
fi

if [[ "${status}" != "BLOCKED" ]]; then
  if command -v node >/dev/null 2>&1; then
    semantic_raw="$(node - "${candidate_norm}" <<'NODE'
const fs = require("fs");
const cfg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const findings = [];
const hasTop = (obj, key) => obj && typeof obj === "object" && !Array.isArray(obj) && Object.prototype.hasOwnProperty.call(obj, key);
const isOpenClawLike = hasTop(cfg, "agents") && hasTop(cfg, "bindings");
if (!isOpenClawLike) {
  process.stdout.write("STATUS=SKIPPED\nFINDINGS=none\n");
  process.exit(0);
}
const agents = cfg.agents && Array.isArray(cfg.agents.list) ? cfg.agents.list : null;
if (!agents || agents.length === 0) {
  findings.push("agents.list missing or empty");
}
const ids = [];
if (agents) {
  for (const a of agents) {
    if (!a || typeof a !== "object" || typeof a.id !== "string" || !a.id.trim().length) {
      findings.push("agent entry without valid id");
      continue;
    }
    ids.push(a.id);
  }
}
const uniq = new Set(ids);
if (ids.length !== uniq.size) {
  findings.push("duplicate agent ids detected");
}
if (agents) {
  const defaults = agents.filter((a) => a && a.default === true);
  if (defaults.length !== 1) {
    findings.push("exactly one default agent is required");
  }
}
const bindings = Array.isArray(cfg.bindings) ? cfg.bindings : [];
for (const b of bindings) {
  const id = b && b.agentId;
  if (!id || !uniq.has(id)) {
    findings.push(`binding references unknown agentId: ${String(id)}`);
  }
}
const groups = cfg.channels && cfg.channels.telegram && cfg.channels.telegram.groups
  && typeof cfg.channels.telegram.groups === "object"
  ? cfg.channels.telegram.groups
  : {};
for (const b of bindings) {
  if (!b || !b.match || b.match.channel !== "telegram") continue;
  const peer = b.match.peer || {};
  if (peer.kind !== "group") continue;
  const pid = String(peer.id || "");
  const groupId = pid.split(":topic:")[0];
  if (!groupId || !Object.prototype.hasOwnProperty.call(groups, groupId)) {
    findings.push(`telegram binding group not in allowlist: ${pid || "<missing>"}`);
  }
}
const cto = agents ? agents.find((a) => a && a.id === "cto") : null;
if (cto && cto.subagents && Array.isArray(cto.subagents.allowAgents)) {
  for (const target of cto.subagents.allowAgents) {
    if (!uniq.has(target)) {
      findings.push(`cto.subagents.allowAgents unknown target: ${String(target)}`);
    }
  }
}
const status = findings.length ? "FAIL" : "PASS";
process.stdout.write(`STATUS=${status}\n`);
process.stdout.write(`FINDINGS=${findings.length ? findings.join("; ") : "none"}\n`);
NODE
)"
    semantic_status="$(printf '%s\n' "${semantic_raw}" | awk -F= '/^STATUS=/{print $2}' | head -n1)"
    semantic_findings="$(printf '%s\n' "${semantic_raw}" | awk -F= '/^FINDINGS=/{print substr($0,10)}' | head -n1)"
    [[ -z "${semantic_status}" ]] && semantic_status="SKIPPED"
    [[ -z "${semantic_findings}" ]] && semantic_findings="none"
    if [[ "${semantic_status}" == "FAIL" ]]; then
      set_fail
      add_breaking "semantic config checks failed"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    semantic_raw="$(python3 - "${candidate_norm}" <<'PY'
import json,sys
cfg=json.load(open(sys.argv[1]))
findings=[]
is_openclaw_like=isinstance(cfg,dict) and "agents" in cfg and "bindings" in cfg
if not is_openclaw_like:
    print("STATUS=SKIPPED")
    print("FINDINGS=none")
    raise SystemExit(0)

agents=(cfg.get("agents") or {}).get("list")
if not isinstance(agents,list) or not agents:
    findings.append("agents.list missing or empty")
    agents=[]

ids=[]
for agent in agents:
    if not isinstance(agent,dict) or not isinstance(agent.get("id"),str) or not agent["id"].strip():
        findings.append("agent entry without valid id")
        continue
    ids.append(agent["id"])

if len(ids) != len(set(ids)):
    findings.append("duplicate agent ids detected")

defaults=[a for a in agents if isinstance(a,dict) and a.get("default") is True]
if len(defaults) != 1:
    findings.append("exactly one default agent is required")

bindings=cfg.get("bindings") if isinstance(cfg.get("bindings"),list) else []
id_set=set(ids)
for b in bindings:
    aid=(b or {}).get("agentId")
    if not isinstance(aid,str) or aid not in id_set:
        findings.append(f"binding references unknown agentId: {aid}")

groups=((cfg.get("channels") or {}).get("telegram") or {}).get("groups") or {}
if not isinstance(groups,dict):
    groups={}
for b in bindings:
    match=(b or {}).get("match") or {}
    if match.get("channel") != "telegram":
        continue
    peer=match.get("peer") or {}
    if peer.get("kind") != "group":
        continue
    pid=str(peer.get("id") or "")
    gid=pid.split(":topic:")[0]
    if not gid or gid not in groups:
        findings.append(f"telegram binding group not in allowlist: {pid or '<missing>'}")

cto=None
for a in agents:
    if isinstance(a,dict) and a.get("id") == "cto":
        cto=a
        break
if isinstance(cto,dict):
    allow=((cto.get("subagents") or {}).get("allowAgents"))
    if isinstance(allow,list):
        for target in allow:
            if not isinstance(target,str) or target not in id_set:
                findings.append(f"cto.subagents.allowAgents unknown target: {target}")

print(f"STATUS={'FAIL' if findings else 'PASS'}")
print("FINDINGS=" + ("; ".join(findings) if findings else "none"))
PY
)"
    semantic_status="$(printf '%s\n' "${semantic_raw}" | awk -F= '/^STATUS=/{print $2}' | head -n1)"
    semantic_findings="$(printf '%s\n' "${semantic_raw}" | awk -F= '/^FINDINGS=/{print substr($0,10)}' | head -n1)"
    [[ -z "${semantic_status}" ]] && semantic_status="SKIPPED"
    [[ -z "${semantic_findings}" ]] && semantic_findings="none"
    if [[ "${semantic_status}" == "FAIL" ]]; then
      set_fail
      add_breaking "semantic config checks failed"
    fi
  else
    semantic_status="SKIPPED"
  fi
fi

if [[ -n "${live_config}" ]]; then
  if [[ -z "${baseline}" || ! -f "${baseline_norm}" ]]; then
    set_blocked
    add_breaking "live config mutation check requires baseline"
  elif [[ ! -f "${live_config}" ]]; then
    set_blocked
    add_breaking "live config file not found"
  elif ! parse_json "${live_config}"; then
    set_blocked
    add_breaking "live config JSON parse failed"
  else
    canonicalize_json "${live_config}" "${live_norm}"
    if [[ "${apply_phase}" == "false" ]]; then
      if diff -u "${baseline_norm}" "${live_norm}" >/dev/null 2>&1; then
        live_config_mutation="NONE"
      else
        live_config_mutation="DETECTED"
        set_fail
        add_breaking "live config mutated outside artifact workflow"
      fi
    else
      live_config_mutation="SKIPPED"
    fi
  fi
fi

if [[ ${#breaking_list[@]} -gt 0 ]]; then
  breaking_changes="$(printf '%s\n' "${breaking_list[@]}" | awk '!seen[$0]++' | paste -sd '; ' -)"
fi

echo "JSON_GATE"
echo "Status: ${status}"
echo "CandidatePath: ${candidate}"
if [[ -n "${baseline}" ]]; then
  echo "BaselinePath: ${baseline}"
else
  echo "BaselinePath: none"
fi
if [[ -n "${live_config}" ]]; then
  echo "LiveConfigPath: ${live_config}"
else
  echo "LiveConfigPath: none"
fi
echo "ApplyPhase: ${apply_phase}"
echo "Syntax: ${syntax_status}"
echo "RequiredBlocks: ${required_status}"
echo "MissingKeys: ${missing_keys}"
echo "StructuralDiff: ${structural_diff}"
echo "SemanticChecks: ${semantic_status}"
echo "SemanticFindings: ${semantic_findings}"
echo "ImmutablePaths: ${immutable_status}"
echo "ImmutablePathViolations: ${immutable_violations}"
echo "BreakingChanges: ${breaking_changes}"
echo "LiveConfigMutation: ${live_config_mutation}"

if [[ -s "${diff_file}" ]]; then
  echo "DiffPreview:"
  sed -n '1,120p' "${diff_file}"
fi

case "${status}" in
  PASS) exit 0 ;;
  FAIL) exit 1 ;;
  BLOCKED) exit 2 ;;
  *) exit 2 ;;
esac
