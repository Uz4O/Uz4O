# AGENTS.md

Before starting work in this repository:

1. Read `CLAUDE.md`.
2. For backend, API, server, deployment, domain, ICP, or launch-readiness work, also read `docs/agents/backend-server-context.md`.
3. Run `git status --short --branch` and preserve unrelated user or agent changes.

Keep changes small and scoped. Do not use `backend/scripts/deploy.sh` for production until it is updated; current production deployment details are in `docs/agents/backend-server-context.md`.

For iOS builds, runs, and simulator verification, use the `iPhone 17 Pro Max` simulator.

## Visual Acceptance

For UI and animation changes, the agent is responsible for code correctness, builds, and runtime-functional verification. Final visual and aesthetic acceptance belongs to the user. Unless the user explicitly requests it, do not claim that a design has passed visual review or continue changing visual parameters based on the agent's own aesthetic judgment.
