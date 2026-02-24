#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path


DEFAULT_REDIRECT_URI = "http://127.0.0.1:8787/oauth2callback"
DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token"
DEFAULT_AUTH_URI = "https://accounts.google.com/o/oauth2/auth"
DEFAULT_CERT_URL = "https://www.googleapis.com/oauth2/v1/certs"
DEFAULT_SCOPES = [
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/calendar.freebusy",
]


def load_env(path: Path) -> dict:
    data: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        data[key] = val
    return data


def require(env: dict, key: str) -> str:
    val = env.get(key, "").strip()
    if not val:
        raise RuntimeError(f"Missing required key in env: {key}")
    return val


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    os.chmod(path, 0o600)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Render oauth-client.json and token.json for Google Calendar runtime"
    )
    parser.add_argument(
        "--env-file",
        default=str(Path(__file__).resolve().parent.parent / "secrets" / "openclaw.env"),
        help="Path to env file with GOOGLE_OAUTH_* keys",
    )
    parser.add_argument(
        "--out-dir",
        default=str(Path(__file__).resolve().parent.parent / "secrets" / "google"),
        help="Output directory for oauth-client.json and token.json",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing files",
    )
    args = parser.parse_args()

    env_file = Path(args.env_file).resolve()
    out_dir = Path(args.out_dir).resolve()
    if not env_file.is_file():
        raise RuntimeError(f"Env file not found: {env_file}")

    env = load_env(env_file)
    client_id = require(env, "GOOGLE_OAUTH_CLIENT_ID")
    client_secret = require(env, "GOOGLE_OAUTH_CLIENT_SECRET")
    refresh_token = require(env, "GOOGLE_OAUTH_REFRESH_TOKEN")
    redirect_uri = env.get("GOOGLE_OAUTH_REDIRECT_URI", "").strip() or DEFAULT_REDIRECT_URI
    project_id = env.get("GOOGLE_OAUTH_PROJECT_ID", "").strip()

    oauth_client_path = out_dir / "oauth-client.json"
    token_path = out_dir / "token.json"

    oauth_client_payload = {
        "installed": {
            "client_id": client_id,
            "project_id": project_id,
            "auth_uri": DEFAULT_AUTH_URI,
            "token_uri": DEFAULT_TOKEN_URI,
            "auth_provider_x509_cert_url": DEFAULT_CERT_URL,
            "client_secret": client_secret,
            "redirect_uris": [redirect_uri],
        }
    }
    token_payload = {
        "type": "authorized_user",
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "token_uri": DEFAULT_TOKEN_URI,
        "scopes": DEFAULT_SCOPES,
    }

    if args.force or not oauth_client_path.exists():
        write_json(oauth_client_path, oauth_client_payload)
        print(f"wrote {oauth_client_path}")
    else:
        print(f"exists {oauth_client_path}")

    if args.force or not token_path.exists():
        write_json(token_path, token_payload)
        print(f"wrote {token_path}")
    else:
        print(f"exists {token_path}")

    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
