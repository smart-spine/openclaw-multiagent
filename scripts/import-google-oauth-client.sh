#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/secrets/openclaw.env"
LOCAL_SECRETS_DIR="$ROOT_DIR/secrets/google"
LOCAL_OAUTH_JSON="$LOCAL_SECRETS_DIR/oauth-client.json"

usage() {
  cat <<'EOF'
Usage:
  scripts/import-google-oauth-client.sh /absolute/path/to/client_secret.json

If path is omitted, script attempts to auto-detect the newest matching JSON in ~/Downloads.
This script:
  1) copies OAuth client JSON to secrets/google/oauth-client.json
  2) upserts Google OAuth variables in secrets/openclaw.env
EOF
}

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "Error: file not found: $f" >&2
    exit 1
  fi
}

pick_source_file() {
  local src="${1:-}"
  if [[ -n "$src" ]]; then
    printf '%s\n' "$src"
    return 0
  fi

  local latest
  latest="$(
    ls -1t "$HOME"/Downloads/client_secret*.json "$HOME"/Downloads/*oauth*client*.json 2>/dev/null | head -n 1 || true
  )"
  if [[ -z "$latest" ]]; then
    echo "Error: source JSON not provided and no matching file in ~/Downloads" >&2
    usage
    exit 1
  fi
  printf '%s\n' "$latest"
}

extract_with_jq() {
  local src="$1"
  jq -r '
    (.installed // .web) as $o
    | if $o == null then
        error("JSON must contain top-level `installed` or `web` object")
      else
        [
          "GOOGLE_OAUTH_CLIENT_ID=" + ($o.client_id // ""),
          "GOOGLE_OAUTH_CLIENT_SECRET=" + ($o.client_secret // ""),
          "GOOGLE_OAUTH_REDIRECT_URI=" + (($o.redirect_uris // [""])[0] // ""),
          "GOOGLE_OAUTH_PROJECT_ID=" + ($o.project_id // "")
        ] | .[]
      end
  ' "$src"
}

extract_with_python() {
  local src="$1"
  python3 - "$src" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, "r", encoding="utf-8") as f:
    data = json.load(f)
obj = data.get("installed") or data.get("web")
if not obj:
    raise SystemExit("JSON must contain top-level `installed` or `web` object")
rid = (obj.get("redirect_uris") or [""])[0]
print(f"GOOGLE_OAUTH_CLIENT_ID={obj.get('client_id','')}")
print(f"GOOGLE_OAUTH_CLIENT_SECRET={obj.get('client_secret','')}")
print(f"GOOGLE_OAUTH_REDIRECT_URI={rid}")
print(f"GOOGLE_OAUTH_PROJECT_ID={obj.get('project_id','')}")
PY
}

extract_kv() {
  local src="$1"
  if command -v jq >/dev/null 2>&1; then
    extract_with_jq "$src"
  elif command -v python3 >/dev/null 2>&1; then
    extract_with_python "$src"
  else
    echo "Error: need jq or python3 to parse OAuth JSON" >&2
    exit 1
  fi
}

upsert_env() {
  local key="$1"
  local val="$2"
  local tmp
  tmp="$(mktemp)"
  awk -v k="$key" -v v="$val" '
    BEGIN { done=0 }
    $0 ~ "^"k"=" { print k"="v; done=1; next }
    { print }
    END { if (!done) print k"="v }
  ' "$ENV_FILE" > "$tmp"
  mv "$tmp" "$ENV_FILE"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  local src
  src="$(pick_source_file "${1:-}")"
  require_file "$ENV_FILE"
  require_file "$src"

  mkdir -p "$LOCAL_SECRETS_DIR"
  cp "$src" "$LOCAL_OAUTH_JSON"
  chmod 600 "$LOCAL_OAUTH_JSON"

  local client_id=""
  local client_secret=""
  local redirect_uri=""
  local project_id=""

  while IFS='=' read -r k v; do
    case "$k" in
      GOOGLE_OAUTH_CLIENT_ID) client_id="$v" ;;
      GOOGLE_OAUTH_CLIENT_SECRET) client_secret="$v" ;;
      GOOGLE_OAUTH_REDIRECT_URI) redirect_uri="$v" ;;
      GOOGLE_OAUTH_PROJECT_ID) project_id="$v" ;;
    esac
  done < <(extract_kv "$src")

  if [[ -z "$client_id" || -z "$client_secret" ]]; then
    echo "Error: missing client_id or client_secret in OAuth JSON" >&2
    exit 1
  fi

  upsert_env "GOOGLE_OAUTH_CLIENT_ID" "$client_id"
  upsert_env "GOOGLE_OAUTH_CLIENT_SECRET" "$client_secret"
  upsert_env "GOOGLE_OAUTH_REDIRECT_URI" "$redirect_uri"
  upsert_env "GOOGLE_OAUTH_PROJECT_ID" "$project_id"
  upsert_env "GOOGLE_OAUTH_CLIENT_JSON_PATH" "/home/node/.openclaw/secrets/google/oauth-client.json"

  if ! grep -q '^GOOGLE_OAUTH_REFRESH_TOKEN=' "$ENV_FILE"; then
    printf '\nGOOGLE_OAUTH_REFRESH_TOKEN=\n' >> "$ENV_FILE"
  fi
  if ! grep -q '^GOOGLE_CALENDAR_ID=' "$ENV_FILE"; then
    printf 'GOOGLE_CALENDAR_ID=primary\n' >> "$ENV_FILE"
  fi
  if ! grep -q '^GOOGLE_CALENDAR_DEFAULT_TZ=' "$ENV_FILE"; then
    printf 'GOOGLE_CALENDAR_DEFAULT_TZ=America/New_York\n' >> "$ENV_FILE"
  fi

  chmod 600 "$ENV_FILE"

  echo "Imported OAuth client JSON into: $LOCAL_OAUTH_JSON"
  echo "Updated: $ENV_FILE"
  echo "Next steps:"
  echo "  1) Fill GOOGLE_OAUTH_REFRESH_TOKEN in $ENV_FILE"
  echo "  2) Run: make push-google-secrets"
  echo "  3) Run: make push-env"
}

main "${1:-}"
