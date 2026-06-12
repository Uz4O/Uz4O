# FastAPI Backend Scaffold Design

## Goal

Create a minimal, locally runnable FastAPI foundation for the AI PC-building assistant without changing the existing SwiftUI app.

## Scope

- Add an independent `backend/` service.
- Support Python 3.9.
- Run locally without PostgreSQL, Redis, or Docker.
- Reserve configuration and Docker Compose services for PostgreSQL and Redis.
- Expose a deterministic health endpoint.
- Include automated tests and startup documentation.

## Architecture

The service uses a small package boundary:

- `app/main.py` creates the FastAPI application.
- `app/api/health.py` owns the health endpoint.
- `app/core/config.py` reads environment-backed settings.

No ORM, migrations, database tables, authentication, or business APIs are included yet. Those belong to later backend phases once the hardware catalog schema is designed.

## Health Contract

`GET /health` returns:

```json
{
  "status": "ok",
  "service": "ai-pc-builder-api",
  "dependencies": {
    "postgres": "not_configured",
    "redis": "not_configured"
  }
}
```

Configured dependency URLs change the matching value to `configured`. The scaffold does not make network calls during health checks.

## Verification

- Install dependencies in a local virtual environment.
- Run the pytest suite.
- Import the FastAPI application.
- Start Uvicorn and request `/health`.

