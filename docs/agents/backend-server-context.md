# Backend and Server Context

Last verified: 2026-06-29.

Read this before backend, API, deployment, ICP/domain, or production-readiness work. Treat this file as the current operational map; some older backend docs still mention the previous server and PM2 setup.

## Product Scope

- Product: UzBox / AI PC-building assistant.
- Frontend: SwiftUI iOS app in `May/`.
- Backend: FastAPI API in `backend/`.
- Current first-release plan: no public community feature. Community code exists, but first release should hide community entry points and should not require OSS/community moderation as launch blockers.
- Production API used by Release iOS builds: `https://api.uzbox.top`.
- Debug API used by iOS Debug builds: `http://127.0.0.1:8790`.

## Local Repository

- Workspace: `/Users/may/Documents/AI装机`.
- iOS project: `May/May.xcodeproj`.
- iOS scheme: `May`.
- iOS API client: `May/May/Networking/AppAPIClient.swift`.
- Backend root: `backend/`.
- Backend roadmap source of truth: `backend/progress.json`.
- Backend docs to check: `backend/README.md`, `backend/AGENTS.md`, `docs/后端开发完成总结-2026-06-16.md`.

Always run this first:

```bash
git status --short --branch
```

The repo often has unrelated uncommitted UI/backend changes. Do not revert changes you did not make.

## Backend Tech Stack

- Runtime: Python 3.9+.
- Web framework: FastAPI.
- ASGI server: Uvicorn.
- Database layer: SQLAlchemy 2.x.
- Migrations: Alembic.
- PostgreSQL driver: `psycopg[binary]`.
- Settings: `pydantic-settings`.
- Auth/token: `PyJWT[crypto]`.
- HTTP client: `httpx`.
- Redis client: `redis`.
- OCR dependency: `paddleocr`.
- Tests: `pytest`.

Important backend modules:

- `backend/app/api`: routers.
- `backend/app/auth`: SMS login, Apple login, account deletion, token handling.
- `backend/app/builds`: AI/rules build generation and templates.
- `backend/app/catalog`: hardware catalog, prices, data readiness.
- `backend/app/compat`: compatibility rules.
- `backend/app/review`: quote/config risk review.
- `backend/app/upgrade`: upgrade advice.
- `backend/app/perf`: performance estimates.
- `backend/app/guide`: guide content.
- `backend/app/community`: community APIs; do not expose in first release unless asked.
- `backend/app/core`: config, database, security headers, rate limits.

Useful local commands:

```bash
cd /Users/may/Documents/AI装机/backend
.venv/bin/pytest
.venv/bin/uvicorn app.main:app --reload
```

## Current Server

Current production server:

- Public IP: `8.152.202.123`.
- Hostname: `iZ2ze49fr1yszolz2mhecsZ`.
- OS: Ubuntu 22.04.5 LTS x86_64.
- SSH: `ssh -i ~/.ssh/ai_builder_aliyun root@8.152.202.123`.
- App directory: `/opt/ai-builder-api`.
- Environment file: `/opt/ai-builder-api/.env`.
- Never print secret values from `.env`; list keys only.

Current service manager:

- systemd service: `ai-builder-api.service`.
- Working directory: `/opt/ai-builder-api`.
- ExecStart: `/opt/ai-builder-api/.venv/bin/uvicorn app.main:app --host ${APP_HOST} --port ${APP_PORT}`.
- Current bind: `127.0.0.1:8790`.

Useful server commands:

```bash
systemctl status ai-builder-api --no-pager
journalctl -u ai-builder-api -n 100 --no-pager
systemctl restart ai-builder-api
```

## Nginx and HTTPS

Current public API domain:

- Domain: `api.uzbox.top`.
- DNS A record: `8.152.202.123`.
- Nginx listens on public `80` and `443`.
- Nginx proxies `api.uzbox.top` to `http://127.0.0.1:8790`.
- Config path seen in prior work: `/etc/nginx/sites-available/ai-builder-api`, enabled from `/etc/nginx/sites-enabled/ai-builder-api`.

Certificate:

- Provider: Let's Encrypt.
- Certificate name: `api.uzbox.top`.
- Current expiry when last checked: 2026-09-27 02:34:49 UTC.
- Certbot timer is enabled.

Useful checks:

```bash
nginx -t
systemctl reload nginx
certbot certificates
curl -k https://127.0.0.1/health -H 'Host: api.uzbox.top'
curl -I https://api.uzbox.top
```

Note: the local Mac may resolve `api.uzbox.top` to a `198.18.*` fake-IP through local proxy DNS. If terminal HTTPS checks fail locally, verify with browser or force the real IP:

```bash
curl --noproxy '*' --resolve api.uzbox.top:443:8.152.202.123 -I https://api.uzbox.top
```

## Current Production Health

Last checked health showed the backend process is reachable but not production-ready:

```json
{
  "status": "ok",
  "dependencies": {
    "postgres": "not_configured",
    "redis": "not_configured"
  },
  "security": {
    "auth_token_secret": "default",
    "ai_provider_api_key": "not_configured",
    "apple_login": "not_configured",
    "ops_token": "not_configured",
    "community_image_upload": "not_configured",
    "api_docs": "disabled",
    "sms_debug": "enabled",
    "sms_provider": "debug"
  },
  "production": {
    "ready": false,
    "blocking_items": [
      "postgres_not_configured",
      "auth_token_secret_default",
      "sms_debug_enabled",
      "ai_provider_api_key_not_configured",
      "apple_login_not_configured",
      "ops_token_not_configured",
      "community_image_upload_not_configured"
    ]
  }
}
```

Because first release will not expose community, `community_image_upload_not_configured` may be handled by hiding community/image features rather than configuring OSS immediately. Do not silently remove the health gate without an explicit release decision.

## Deployment Warning

`backend/scripts/deploy.sh` is currently stale. It still points at the old server `36.213.128.58`, key `~/.ssh/mark_six_deploy`, remote directory `/opt/new-site`, and PM2 app `new-site`.

Do not use that script for the current production server until it is updated and verified. Current production is:

- Server: `8.152.202.123`.
- Directory: `/opt/ai-builder-api`.
- Service: `ai-builder-api.service`.
- Manager: systemd, not PM2.

## ICP and Domain Notes

- App backend service domain: `api.uzbox.top`.
- Website/main备案 domain should be the root domain: `uzbox.top`.
- In Alibaba Cloud filing, the App service can list `api.uzbox.top`, while website filing should use `uzbox.top` without `www`.
- After root-domain filing succeeds, subdomains such as `api.uzbox.top` should be covered for Alibaba Cloud access.

## Safety Rules

- Do not print `.env` values, API keys, SMS secrets, database passwords, or private keys.
- Do not modify Nginx, systemd, DNS, or cloud security groups unless the user asked for deployment/server work.
- Before claiming production readiness, verify `/health`, HTTPS, and the iOS Release API base URL.
- For backend roadmap work, keep `backend/progress.json` synchronized as required by `backend/AGENTS.md`.
