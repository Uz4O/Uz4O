# Hardware Catalog Seed Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import all current Swift hardware catalog entries into PostgreSQL and expose basic catalog query endpoints.

**Architecture:** Parse Swift source into typed Python records, normalize only reliable specs, store rows via SQLAlchemy with Alembic migration, and expose FastAPI read endpoints backed by the database. Keep the importer idempotent through primary-key upserts.

**Tech Stack:** Python 3.9, FastAPI, Pydantic, SQLAlchemy, Alembic, psycopg, PostgreSQL, pytest

---

### Task 1: Parser and spec normalization

- [ ] Write parser tests for all six categories and known spec fields.
- [ ] Implement Swift catalog extraction and detail parsing.
- [ ] Verify parser tests pass.

### Task 2: Database table and seed command

- [ ] Add SQLAlchemy, Alembic, and PostgreSQL driver dependencies.
- [ ] Add `hardware_component` model and migration.
- [ ] Add idempotent seed command.
- [ ] Verify seed command against test database/session boundaries.

### Task 3: Catalog APIs

- [ ] Add component list filters.
- [ ] Add compatible motherboard lookup.
- [ ] Verify API tests with seeded test data.

### Task 4: Deployment and progress

- [ ] Deploy code.
- [ ] Run migration on `/opt/new-site`.
- [ ] Seed 715 components from `HardwareCatalog.swift`.
- [ ] Verify remote APIs and existing services.
- [ ] Mark progress item completed and redeploy.
