#!/usr/bin/env python3
import argparse
import base64
import hashlib
import json
import os
import secrets
import socket
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


DEFAULT_SCOPES = [
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/calendar.freebusy",
]


def load_env(path: Path) -> dict:
    data = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        data[k] = v
    return data


def upsert_env(path: Path, key: str, value: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    replaced = False
    out = []
    for line in lines:
        if line.startswith(f"{key}="):
            out.append(f"{key}={value}")
            replaced = True
        else:
            out.append(line)
    if not replaced:
        out.append(f"{key}={value}")
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    os.chmod(path, 0o600)


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def load_client_json(root: Path, env: dict) -> tuple[dict, str]:
    candidates = []
    env_json_path = env.get("GOOGLE_OAUTH_CLIENT_JSON_PATH", "").strip()
    if env_json_path:
        candidates.append(Path(env_json_path))
    candidates.append(root / "secrets" / "google" / "oauth-client.json")

    for p in candidates:
        if not p.is_file():
            continue
        data = json.loads(p.read_text(encoding="utf-8"))
        if "installed" in data:
            return data["installed"], "installed"
        if "web" in data:
            return data["web"], "web"
    return {}, "unknown"


def get_client_credentials(root: Path, env: dict) -> tuple[str, str, str, str]:
    obj, kind = load_client_json(root, env)

    cid = env.get("GOOGLE_OAUTH_CLIENT_ID", "").strip() or obj.get("client_id", "")
    csecret = env.get("GOOGLE_OAUTH_CLIENT_SECRET", "").strip() or obj.get("client_secret", "")
    redirects = obj.get("redirect_uris") or []
    first_redirect = redirects[0] if redirects else ""

    if cid and csecret:
        return cid, csecret, kind, first_redirect

    raise RuntimeError(
        "Google OAuth client credentials not found. "
        "Run scripts/import-google-oauth-client.sh first."
    )


def exchange_code(
    code: str,
    client_id: str,
    client_secret: str,
    redirect_uri: str,
    code_verifier: str,
) -> dict:
    body = urllib.parse.urlencode(
        {
            "grant_type": "authorization_code",
            "code": code,
            "client_id": client_id,
            "client_secret": client_secret,
            "redirect_uri": redirect_uri,
            "code_verifier": code_verifier,
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError:
        # Fallback for local Python certificate-store issues.
        payload = body.decode("utf-8")
        proc = subprocess.run(
            [
                "curl",
                "--silent",
                "--show-error",
                "--fail",
                "-X",
                "POST",
                "https://oauth2.googleapis.com/token",
                "-H",
                "Content-Type: application/x-www-form-urlencoded",
                "--data",
                payload,
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(proc.stdout)


def maybe_open_browser(url: str, no_open: bool) -> None:
    if no_open:
        return
    try:
        if sys.platform == "darwin":
            subprocess.run(["open", url], check=False)
        elif sys.platform.startswith("linux"):
            subprocess.run(["xdg-open", url], check=False)
    except Exception:
        pass


def run_flow(
    env_file: Path,
    scopes: list[str],
    no_open: bool,
    timeout_sec: int,
    redirect_uri_override: str,
) -> int:
    root = env_file.parent.parent
    env = load_env(env_file)
    client_id, client_secret, client_kind, json_redirect_uri = get_client_credentials(root, env)

    configured_redirect = (
        redirect_uri_override.strip()
        or env.get("GOOGLE_OAUTH_REDIRECT_URI", "").strip()
        or json_redirect_uri.strip()
    )

    if configured_redirect:
        parsed = urllib.parse.urlparse(configured_redirect)
        if parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost"):
            raise RuntimeError(
                "Configured redirect URI must be local HTTP loopback "
                "(http://127.0.0.1:<port>/path or http://localhost:<port>/path)."
            )
        if not parsed.port:
            raise RuntimeError(
                "Configured redirect URI must include explicit port, e.g. "
                "http://127.0.0.1:8787/oauth2callback"
            )
        host = parsed.hostname
        port = parsed.port
        callback_path = parsed.path or "/"
        redirect_uri = configured_redirect
    else:
        if client_kind == "web":
            raise RuntimeError(
                "OAuth client is type `web` but no redirect URI is configured. "
                "Add Authorized redirect URI in Google Cloud and set GOOGLE_OAUTH_REDIRECT_URI."
            )
        host = "127.0.0.1"
        port = find_free_port()
        callback_path = "/oauth2callback"
        redirect_uri = f"http://{host}:{port}{callback_path}"

    state = secrets.token_urlsafe(24)
    code_verifier = b64url(secrets.token_bytes(48))
    code_challenge = b64url(hashlib.sha256(code_verifier.encode("ascii")).digest())

    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": " ".join(scopes),
        "access_type": "offline",
        "include_granted_scopes": "true",
        "prompt": "consent",
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
    }
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(params)

    result = {"code": None, "error": None}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path != callback_path:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"Not found.")
                return
            qs = urllib.parse.parse_qs(parsed.query)
            got_state = qs.get("state", [""])[0]
            code = qs.get("code", [""])[0]
            err = qs.get("error", [""])[0]

            if got_state != state:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"State mismatch. You can close this tab.")
                result["error"] = "state_mismatch"
                return

            if err:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"Authorization failed. You can close this tab.")
                result["error"] = err
                return

            result["code"] = code
            self.send_response(200)
            self.end_headers()
            self.wfile.write(
                b"Authorization complete. You can close this tab and return to terminal."
            )

        def log_message(self, fmt, *args):
            return

    httpd = HTTPServer((host, port), Handler)
    httpd.timeout = 1

    print("Open this URL and complete Google sign-in/consent:")
    print(auth_url)
    maybe_open_browser(auth_url, no_open)

    started = time.time()
    while not result["code"] and not result["error"] and time.time() - started < timeout_sec:
        httpd.handle_request()

    if result["error"]:
        print(f"OAuth flow failed: {result['error']}", file=sys.stderr)
        return 1
    if not result["code"]:
        print("OAuth flow timed out waiting for callback.", file=sys.stderr)
        return 1

    token_resp = exchange_code(
        code=result["code"],
        client_id=client_id,
        client_secret=client_secret,
        redirect_uri=redirect_uri,
        code_verifier=code_verifier,
    )
    refresh_token = token_resp.get("refresh_token", "")
    if not refresh_token:
        print(
            "No refresh_token in token response. "
            "Revoke app access and retry (prompt=consent is already set).",
            file=sys.stderr,
        )
        return 1

    upsert_env(env_file, "GOOGLE_OAUTH_REFRESH_TOKEN", refresh_token)
    print(f"Saved GOOGLE_OAUTH_REFRESH_TOKEN to {env_file}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Obtain Google OAuth refresh token and store it in secrets/openclaw.env")
    parser.add_argument(
        "--env-file",
        default=str(Path(__file__).resolve().parent.parent / "secrets" / "openclaw.env"),
        help="Path to env file",
    )
    parser.add_argument(
        "--scope",
        action="append",
        default=[],
        help="OAuth scope (repeatable). Defaults to calendar.events + calendar.freebusy",
    )
    parser.add_argument("--no-open", action="store_true", help="Do not auto-open browser")
    parser.add_argument("--timeout", type=int, default=300, help="Callback wait timeout in seconds")
    parser.add_argument(
        "--redirect-uri",
        default="",
        help="Explicit redirect URI override (must be local HTTP loopback URI with port)",
    )
    args = parser.parse_args()

    env_file = Path(args.env_file).resolve()
    if not env_file.is_file():
        print(f"Env file not found: {env_file}", file=sys.stderr)
        return 1

    scopes = args.scope if args.scope else DEFAULT_SCOPES
    return run_flow(env_file, scopes, args.no_open, args.timeout, args.redirect_uri)


if __name__ == "__main__":
    raise SystemExit(main())
