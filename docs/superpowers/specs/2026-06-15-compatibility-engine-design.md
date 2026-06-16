# Compatibility Engine Design

## Goal

Add a deterministic backend compatibility checker for PC build drafts. The
first version should catch obvious hard conflicts and basic risks before AI
build generation, configuration review, and upgrade advice depend on it.

## Scope

- Add `POST /v1/compat/check`.
- Accept component ids for the current build draft.
- Load components from the maintained hardware catalog in PostgreSQL.
- Return an overall compatibility result plus rule findings.
- Use plain Chinese messages suitable for app users.
- Do not use an LLM for compatibility decisions.

## MVP Rules

The MVP only checks fields already present or safely optional in the current
hardware catalog:

- Required core parts: CPU, motherboard, RAM, and PSU.
- Unknown component ids.
- CPU socket must match motherboard socket when both are known.
- RAM type must match motherboard `mem_type` when the motherboard data has it.
- PSU wattage must leave basic headroom when enough watt data is available.

GPU length, case clearance, detailed CPU/GPU TDP, and performance balance are
left out of the MVP because the current seed importer does not yet provide
reliable fields for those checks.

## API

Request:

```json
{
  "components": {
    "cpu": "i5-14600k",
    "motherboard": "b760m",
    "ram": "ram-6000-cl30",
    "gpu": "rtx-5070",
    "psu": "psu-rm750e"
  }
}
```

Response:

```json
{
  "compatible": true,
  "summary": "这套配置没有发现硬性兼容问题。",
  "findings": [
    {
      "level": "pass",
      "code": "cpu_motherboard_socket",
      "title": "CPU 和主板插槽匹配",
      "detail": "i5-14600K 可以安装在 B760M AORUS ELITE 上。",
      "component_ids": ["i5-14600k", "b760m"]
    }
  ]
}
```

Finding levels:

- `pass`: checked and ok.
- `warning`: can continue, but user should review.
- `error`: hard compatibility problem or missing required core part.

## Implementation

- Add a small `app.compat` module with request data objects and rule functions.
- Add repository helper to fetch components by id.
- Add `app.api.compat` router.
- Keep rule functions pure so they are easy to test without FastAPI.
- Do not create new database tables for the MVP.

## Testing

- Unit-test socket mismatch, missing parts, unknown ids, RAM type checks, and PSU
  headroom warnings.
- API-test a passing build and a failing socket mismatch.
- Keep existing catalog and progress tests green.
