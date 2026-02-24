# OpenClaw on Hetzner (Cheap and Practical)

This repository is a deployment template for running OpenClaw 24/7 on Hetzner with:

- infrastructure as code (Terraform)
- reproducible Docker deployment
- Git-based config/version control
- SSH-tunnel-only dashboard access by default

## Repo layout

- `infra/terraform`: Hetzner VPS + firewall provisioning
- `infra/cloud-init`: server bootstrap (Docker, user, firewall)
- `docker`: OpenClaw image + compose runtime
- `config`: OpenClaw runtime configuration (`openclaw.json`, skills manifest)
- `secrets`: local-only `.env` template for server runtime secrets
- `deploy`: bootstrap/deploy/status/log scripts
- `docs`: detailed step-by-step guide (EN)

## Quick start

1. Copy and edit infra inputs:

```bash
cp config/inputs.example.sh config/inputs.sh
```

2. Copy and edit runtime secrets:

```bash
cp secrets/openclaw.env.example secrets/openclaw.env
```

3. Source inputs and provision the server:

```bash
source config/inputs.sh
make tf-init
make tf-plan
make tf-apply
```

4. Bootstrap server files and deploy OpenClaw:

```bash
make bootstrap
make deploy
```

5. Open dashboard via SSH tunnel:

```bash
make tunnel
# then open http://127.0.0.1:18789
```

For full instructions, see `docs/openclaw-hetzner-quickstart-en.md`.

## Google OAuth client import (optional, for meeting agents)

If you downloaded OAuth client JSON from Google Cloud:

```bash
./scripts/import-google-oauth-client.sh /absolute/path/to/client_secret_*.json
make google-refresh-token
make push-google-secrets
make push-env
```

This stores OAuth JSON locally under `secrets/google/` (gitignored), obtains and saves a refresh token into `secrets/openclaw.env`, and pushes file/env to VPS.
