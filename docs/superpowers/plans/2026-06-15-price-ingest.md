# Price Ingest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe offline ingestion of approved hardware reference prices and expose read-only price APIs.

**Architecture:** Parse approved CSV into typed records, upsert them into `component_price`, and serve prices from the catalog API. Keep all writes behind CLI until backend auth/admin permissions exist.

**Tech Stack:** Python 3.9, FastAPI, Pydantic, SQLAlchemy, Alembic, PostgreSQL, pytest

---

### Task 1: Approved CSV parser

- [ ] Write failing parser tests for valid approved rows and skipped blank prices.
- [ ] Implement CSV parsing.
- [ ] Verify parser tests pass.

### Task 2: Database model and ingest command

- [ ] Add `component_price` SQLAlchemy model.
- [ ] Add Alembic migration.
- [ ] Add idempotent repository upsert.
- [ ] Add `ingest-prices` CLI command.

### Task 3: Price read APIs

- [ ] Add list and component-specific price endpoints.
- [ ] Verify API tests with seeded SQLite data.

### Task 4: Deployment and progress

- [ ] Deploy code.
- [ ] Run migration.
- [ ] Ingest an approved CSV when available.
- [ ] Verify remote APIs and existing services.
- [ ] Mark progress item complete only after successful ingest verification.
