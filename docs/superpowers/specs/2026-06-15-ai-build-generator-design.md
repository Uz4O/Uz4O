# AI Build Generator Design

## Goal

Add the backend foundation for AI one-click PC builds using a template-first,
AI-fallback flow.

## Product Rule

The model must not invent hardware. It can choose, explain, and adjust only
within the maintained template pool and hardware catalog.

## Flow

1. Receive user budget, use case, and preferences.
2. Try to match an approved build template.
3. If a template matches, return a structured build plan from that template.
4. If no template matches, return an AI fallback state until a model API key and
   provider integration are configured.
5. Every produced build plan must be compatible with the existing compatibility
   checker before it is returned as ready.

## MVP Scope

- Add `build_template` storage.
- Add `POST /v1/build/generate`.
- Add deterministic template matching by budget/use case/preferences.
- Add compatibility-check output to template results.
- Add a safe AI-provider placeholder that reports missing configuration instead
  of fabricating a build.
- Add a CLI command to import template JSON later.

Out of scope until the user provides data/API credentials:

- Real DeepSeek API calls.
- Final production template data.
- Completion status on the progress page.

## API

Request:

```json
{
  "budget": 7000,
  "use_case": "gaming",
  "preferences": ["quiet", "2k"],
  "notes": "主要玩 2K 3A，希望安静"
}
```

Response when a template matches:

```json
{
  "status": "ready",
  "source": "template",
  "template_id": "gaming-7000-2k",
  "title": "7000 元 2K 游戏配置",
  "components": {
    "cpu": "i5-14600k",
    "motherboard": "b760m",
    "ram": "ram-6000-cl30",
    "gpu": "rtx-5070",
    "psu": "psu-cooler-master-v750"
  },
  "estimated_total": 7000,
  "explanation": "这套优先把预算放在显卡上，适合 2K 游戏。",
  "compatibility": { "...": "..." }
}
```

Response when no template matches and AI is not configured:

```json
{
  "status": "needs_ai_generation",
  "source": "ai_pending",
  "template_id": null,
  "title": "需要 AI 生成新配置",
  "components": {},
  "estimated_total": null,
  "explanation": "没有命中现有配置模板，等待配置 AI API Key 后生成。",
  "compatibility": null
}
```

## Template JSON Import Shape

```json
[
  {
    "id": "gaming-7000-2k",
    "title": "7000 元 2K 游戏配置",
    "budget_min": 6500,
    "budget_max": 7500,
    "use_cases": ["gaming"],
    "tags": ["2k", "quiet"],
    "components": {
      "cpu": "i5-14600k",
      "motherboard": "b760m",
      "ram": "ram-6000-cl30",
      "gpu": "rtx-5070",
      "psu": "psu-cooler-master-v750"
    },
    "estimated_total": 7000,
    "explanation": "这套优先把预算放在显卡上，适合 2K 游戏。"
  }
]
```
