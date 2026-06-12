# Backend Development Rules

These rules apply to all work inside `backend/`.

## Progress Synchronization

When starting, completing, or deploying a backend roadmap capability or its
infrastructure prerequisite:

1. Ensure the work has a matching item in `progress.json`; add one when an
   infrastructure prerequisite is not represented.
2. Set its status accurately when work starts and set its completion date only
   after verification.
3. Update the top-level `updated_at` and `current_phase`.
4. Run the full backend test suite.
5. Deploy with `./scripts/deploy.sh`.
6. Verify `http://36.213.128.58:8790/progress`.
7. Verify the existing services on ports `8787` and `8788` remain healthy.

Do not mark work completed or deploy a progress update before verification.

## Deployment Isolation

- Deploy only to `/opt/new-site`.
- Manage only the PM2 application `new-site`.
- Use port `8790`; never use `8080`.
- Preserve `/opt/new-site/.env`.
- Do not modify Nginx, ports 80/443, other project directories, other PM2
  applications, databases, or upload directories.
