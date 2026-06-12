# Backend Progress Dashboard Design

## Goal

Publish a public, read-only dashboard that shows the AI PC-building app's backend development progress.

## Interface

- `/` redirects to `/progress`.
- `/progress` renders a responsive project dashboard.
- The top summary shows completion percentage, current phase, completed item count, and last update.
- Phase cards show every planned backend capability and its status.

## Data Source

`backend/progress.json` is the single source of truth. Each backend task updates this file as part of its completion workflow. The dashboard calculates completion from item statuses rather than storing a separate percentage.

Supported statuses:

- `completed`
- `in_progress`
- `not_started`

## Deployment

- Remote directory: `/opt/new-site`
- PM2 name: `new-site`
- Preferred port: `8790`
- Runtime environment file: `/opt/new-site/.env`
- Nginx, ports 80/443, and existing applications are out of scope.

The deployment script excludes remote-owned `.env`, virtual environments, caches, and test output. It restarts only the `new-site` PM2 process.

## Verification

- Validate progress JSON and completion calculation with tests.
- Verify `/progress` and `/` behavior locally.
- Verify remote PM2 status, local-server HTTP, public HTTP, and existing 8787/8788 services.

