# AI Build Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a template-first AI build generation API that can run before the model API key and final templates are available.

**Architecture:** Store approved build templates in PostgreSQL, use deterministic matching for ready results, run compatibility checks against selected components, and leave AI fallback as an explicit pending state until credentials are provided.

**Tech Stack:** Python 3.9, FastAPI, SQLAlchemy, Alembic, Pydantic, pytest

---

### Task 1: Build Template Model and Matching

- [ ] Add failing unit tests for budget/use-case/preference template matching.
- [ ] Add `BuildTemplate` SQLAlchemy model and migration.
- [ ] Add repository functions to upsert/list/match templates.

### Task 2: Build Generation API

- [ ] Add failing API tests for template match and no-template fallback.
- [ ] Add `POST /v1/build/generate`.
- [ ] Run compatibility checks for template output.
- [ ] Include build router in the FastAPI app.

### Task 3: Template Import CLI

- [ ] Add failing CLI test for importing template JSON.
- [ ] Add `import-build-templates` CLI command.

### Task 4: Progress and Deployment

- [ ] Mark `AI 一键装机` as `in_progress`.
- [ ] Run the full backend test suite.
- [ ] Run Alembic upgrade against a temporary database.
- [ ] Deploy to `new-site`.
- [ ] Run server migration.
- [ ] Verify `8790`, `8787`, and `8788`.
