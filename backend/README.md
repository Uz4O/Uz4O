# AI PC Builder API

This directory contains the backend foundation for the AI PC-building assistant.
It runs without PostgreSQL, Redis, or Docker by default.

## Requirements

- Python 3.9 or newer
- Docker Compose only when running the optional PostgreSQL and Redis services

## Install

```bash
cd /Users/may/Documents/AI装机/backend
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -e '.[dev]'
```

## Run

```bash
.venv/bin/uvicorn app.main:app --reload
```

Open:

- Health: `http://127.0.0.1:8000/health`
- OpenAPI docs: `http://127.0.0.1:8000/docs`
- Backend progress: `http://127.0.0.1:8000/progress`

Without environment variables, `/health` reports PostgreSQL and Redis as
`not_configured`. This is expected for the initial local setup.

## Test

```bash
.venv/bin/pytest
```

## Optional PostgreSQL and Redis

Docker is not required for the initial scaffold. After Docker is installed:

```bash
docker compose up -d postgres redis
cp .env.example .env
.venv/bin/uvicorn app.main:app --reload
```

With `.env` loaded, `/health` reports both dependencies as `configured`. The
health endpoint intentionally does not connect to them yet; real connectivity
checks will be added with the first persistence-backed feature.

## Environment Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_SERVICE_NAME` | `ai-pc-builder-api` | Service name returned by health checks |
| `APP_HOST` | `0.0.0.0` in deployment | Uvicorn bind address used by `scripts/run.sh` |
| `APP_PORT` | `8790` in deployment | Uvicorn port used by `scripts/run.sh` |
| `APP_POSTGRES_URL` | unset | Reserved PostgreSQL connection URL |
| `APP_REDIS_URL` | unset | Reserved Redis connection URL |

## Progress Update Rule

`progress.json` is the single source of truth for the public backend roadmap.
Every completed backend capability must update its item status, completion date,
top-level `updated_at`, and `current_phase` before deployment.

After tests pass, deploy the updated backend from this directory:

```bash
./scripts/deploy.sh
```

The script syncs only this backend into `/opt/new-site`, preserves the remote
`.env`, installs production dependencies, and restarts only the PM2 application
named `new-site`.

## Production Deployment

- Directory: `/opt/new-site`
- PM2 application: `new-site`
- Public progress URL: `http://36.213.128.58:8790/progress`
- Environment file: `/opt/new-site/.env`

Useful commands:

```bash
ssh -i ~/.ssh/mark_six_deploy root@36.213.128.58
pm2 restart new-site
pm2 logs new-site
```
