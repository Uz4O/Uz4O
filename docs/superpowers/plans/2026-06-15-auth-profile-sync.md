# Auth and Profile Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add phone-code account login and authenticated onboarding/hardware profile sync.

**Architecture:** Keep authentication in a focused `app.auth` package and profile persistence in `app.profile`. Use SQLAlchemy models plus repository functions, and expose thin FastAPI routers. Use signed bearer tokens without adding third-party auth dependencies.

**Tech Stack:** Python 3.9, FastAPI, SQLAlchemy, Alembic, Pydantic, pytest

---

### Task 1: Auth Core and Persistence

- [ ] Add failing tests for token signing, SMS code verification, and account creation.
- [ ] Add `Account` and `AuthSmsCode` SQLAlchemy models.
- [ ] Add HMAC token helpers and SMS code hashing helpers.
- [ ] Add repository functions for creating SMS codes and logging in by phone code.
- [ ] Add Alembic migration.

### Task 2: Auth API

- [ ] Add failing API tests for SMS send, login, `GET /v1/auth/me`, and missing token rejection.
- [ ] Add FastAPI auth router.
- [ ] Add reusable current-account dependency.
- [ ] Include auth router in the app.

### Task 3: Profile Sync API

- [ ] Add failing repository/API tests for onboarding and hardware profile defaults and upserts.
- [ ] Add `OnboardingProfile` and `HardwareProfile` models.
- [ ] Add repository functions for profile get/upsert.
- [ ] Add FastAPI profile router.
- [ ] Include profile router in the app.

### Task 4: Progress, Verification, and Deployment

- [ ] Mark `账户、登录与配置同步` as `in_progress` when implementation starts.
- [ ] Run the full backend test suite.
- [ ] Run Alembic upgrade against a temporary database.
- [ ] Deploy with `backend/scripts/deploy.sh`.
- [ ] Run server Alembic upgrade.
- [ ] Ensure `/opt/new-site/.env` has `APP_AUTH_TOKEN_SECRET` without printing it.
- [ ] Verify auth/profile APIs on `8790`.
- [ ] Mark progress completed and redeploy.
- [ ] Verify `8790`, `8787`, and `8788`.
