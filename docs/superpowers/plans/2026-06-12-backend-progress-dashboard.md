# Backend Progress Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public backend progress dashboard and deploy it as an isolated PM2 application.

**Architecture:** Store progress in a versioned JSON file, load and validate it in a focused Python module, and render a server-side HTML dashboard through FastAPI. Use an isolated deployment script and PM2 definition that target only `/opt/new-site` and `new-site`.

**Tech Stack:** Python 3.9, FastAPI, Pydantic, pytest, PM2, rsync

---

### Task 1: Progress data model

**Files:**
- Create: `backend/progress.json`
- Create: `backend/app/progress.py`
- Create: `backend/tests/test_progress.py`

- [ ] Write failing tests for progress loading and completion calculation.
- [ ] Run the focused tests and confirm the missing module failure.
- [ ] Implement the minimal progress models and loader.
- [ ] Run the focused tests and confirm they pass.

### Task 2: Progress dashboard

**Files:**
- Create: `backend/app/api/progress.py`
- Modify: `backend/app/main.py`
- Modify: `backend/tests/test_progress.py`

- [ ] Write failing tests for `/progress` and `/`.
- [ ] Run the focused tests and confirm the routes are missing.
- [ ] Implement the responsive server-rendered dashboard and root redirect.
- [ ] Run the focused tests and confirm they pass.

### Task 3: Isolated deployment

**Files:**
- Create: `backend/ecosystem.config.cjs`
- Create: `backend/scripts/deploy.sh`
- Modify: `backend/README.md`
- Modify: `backend/.env.example`

- [ ] Add a PM2 definition for only `new-site`.
- [ ] Add a deployment script that preserves remote `.env` and excludes local state.
- [ ] Document the progress update and deployment workflow.
- [ ] Validate shell syntax and PM2 configuration structure.

### Task 4: Deploy and verify

- [ ] Run all local backend tests and compile checks.
- [ ] Confirm remote port 8790 and `/opt/new-site` remain available.
- [ ] Sync files and install production dependencies.
- [ ] Create the remote `.env`, start only `new-site`, and run `pm2 save`.
- [ ] Verify localhost and public progress URLs.
- [ ] Verify existing 8787 and 8788 services remain healthy.
