#!/usr/bin/env bash
set -euo pipefail

MANIFEST="/home/node/.openclaw/skills-manifest.txt"
STAMP_FILE="/home/node/.openclaw/.skills-manifest.sha256"

if [[ -f "$MANIFEST" ]]; then
  CURRENT_HASH="$(sha256sum "$MANIFEST" | awk '{print $1}')"
  PREV_HASH="$(cat "$STAMP_FILE" 2>/dev/null || true)"

  if [[ "$CURRENT_HASH" != "$PREV_HASH" ]]; then
    echo "[entrypoint] skills manifest changed, installing skills..."
    INSTALL_FAILED=0

    while IFS= read -r line; do
      skill="$(echo "$line" | sed 's/#.*$//' | xargs)"
      if [[ -z "$skill" ]]; then
        continue
      fi

      echo "[entrypoint] clawhub install $skill"
      if ! clawhub --workdir "/home/node/.openclaw" --dir "skills" install "$skill"; then
        echo "[entrypoint] warning: failed to install skill '$skill'"
        INSTALL_FAILED=1
      fi
    done < "$MANIFEST"

    if [[ "$INSTALL_FAILED" -eq 0 ]]; then
      echo "$CURRENT_HASH" > "$STAMP_FILE"
    else
      echo "[entrypoint] one or more skills failed, will retry on next start"
      rm -f "$STAMP_FILE"
    fi
  fi
fi

exec "$@"
