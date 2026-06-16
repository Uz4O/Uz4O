# Compatibility Engine Implementation Plan

Goal: ship the deterministic compatibility checker MVP and deploy it to
`new-site`.

## Tasks

- [ ] Mark `规则与兼容性引擎` as `in_progress`.
- [ ] Add failing unit tests for required parts, unknown ids, socket matching,
      RAM type matching, and PSU headroom.
- [ ] Add failing API tests for `POST /v1/compat/check`.
- [ ] Implement pure compatibility rule evaluation.
- [ ] Add repository helper for fetching components by id.
- [ ] Add FastAPI router and include it in the app.
- [ ] Run the full backend test suite.
- [ ] Mark progress completed only after local and server verification.
- [ ] Deploy with `backend/scripts/deploy.sh`.
- [ ] Verify public `8790` plus existing `8787` and `8788` services.
