# Backend and Server Context

Last verified: 2026-07-20.

Read this before backend, API, deployment, ICP/domain, or production-readiness work. Treat this file as the current operational map; some older backend docs still mention the previous server and PM2 setup.

## Productivity Hardware Data Update (2026-07-20)

- Added three priced LGA1851 motherboard whitelist entries for 15th-generation/Core Ultra 200S productivity builds: ASUS PRIME B860M-K at `550/700`, MSI PRO B860M-A WIFI at `750/1050`, and MSI MAG B860M MORTAR WIFI at `900/1200` yuan used/new.
- Added the Intel-productivity-only default memory component `DDR5 16GB 7200 C36` at the user-provided all-new price of `1800` yuan. It is isolated from the existing AMD gaming base-template pool.
- Production now contains `749` hardware components, `73` approved component reference prices, and `20` motherboard whitelist price rows. It has `340` active templates: `275` reviewed gaming templates plus `65` office templates.
- Office requests use separate general/2D, media-editing, and Blender/CUDA profiles. Pure office may use Intel Arc, Blender/CUDA is NVIDIA-only, and gaming-plus-office is forced to NVIDIA while retaining the selected gaming direction.
- Production verification passed: Alembic is `20260720_0015 (head)`, `ai-builder-api` is active, and `/v1/catalog/readiness` returns `ready: true`.

## Product Scope

- Product: UzBox / AI PC-building assistant.
- Frontend: SwiftUI iOS app in `May/`.
- Backend: FastAPI API in `backend/`.
- Current first-release plan: no public community feature. Community code exists, but first release should hide community entry points and should not require OSS/community moderation as launch blockers.
- Production API used by Release iOS builds: `https://api.uzbox.top`.
- Debug API used by iOS Debug builds: `http://127.0.0.1:8790`.

## Local Repository

- Workspace: `/Users/may/Documents/AI装机`.
- iOS project: `May/May.xcodeproj`.
- iOS scheme: `May`.
- iOS API client: `May/May/Networking/AppAPIClient.swift`.
- Backend root: `backend/`.
- Backend roadmap source of truth: `backend/progress.json`.
- Backend docs to check: `backend/README.md`, `backend/AGENTS.md`, `docs/后端开发完成总结-2026-06-16.md`.

Always run this first:

```bash
git status --short --branch
```

The repo often has unrelated uncommitted UI/backend changes. Do not revert changes you did not make.

## Backend Tech Stack

- Runtime: Python 3.9+.
- Web framework: FastAPI.
- ASGI server: Uvicorn.
- Database layer: SQLAlchemy 2.x.
- Migrations: Alembic.
- PostgreSQL driver: `psycopg[binary]`.
- Settings: `pydantic-settings`.
- Auth/token: `PyJWT[crypto]`.
- HTTP client: `httpx`.
- Redis client: `redis`.
- OCR dependency: `paddleocr`.
- Tests: `pytest`.

Important backend modules:

- `backend/app/api`: routers.
- `backend/app/auth`: SMS login, Apple login, account deletion, token handling.
- `backend/app/builds`: AI/rules build generation and templates.
- `backend/app/catalog`: hardware catalog, prices, data readiness.
- `backend/app/compat`: compatibility rules.
- `backend/app/review`: quote/config risk review.
- `backend/app/upgrade`: upgrade advice.
- `backend/app/perf`: performance estimates.
- `backend/app/community`: community APIs; do not expose in first release unless asked.
- `backend/app/core`: config, database, security headers, rate limits.

Useful local commands:

```bash
cd /Users/may/Documents/AI装机/backend
.venv/bin/pytest
.venv/bin/uvicorn app.main:app --reload
```

## Current Server

Current production server:

- Public IP: `8.152.202.123`.
- Hostname: `iZ2ze49fr1yszolz2mhecsZ`.
- OS: Ubuntu 22.04.5 LTS x86_64.
- SSH: `ssh -i ~/.ssh/ai_builder_aliyun root@8.152.202.123`.
- App directory: `/opt/ai-builder-api`.
- Environment file: `/opt/ai-builder-api/.env`.
- Never print secret values from `.env`; list keys only.

Current service manager:

- systemd service: `ai-builder-api.service`.
- Working directory: `/opt/ai-builder-api`.
- ExecStart: `/opt/ai-builder-api/.venv/bin/uvicorn app.main:app --host ${APP_HOST} --port ${APP_PORT}`.
- Current bind: `127.0.0.1:8790`.

Useful server commands:

```bash
systemctl status ai-builder-api --no-pager
journalctl -u ai-builder-api -n 100 --no-pager
systemctl restart ai-builder-api
```

## Nginx and HTTPS

Current public API domain:

- Domain: `api.uzbox.top`.
- DNS A record: `8.152.202.123`.
- Nginx listens on public `80` and `443`.
- Nginx proxies `api.uzbox.top` to `http://127.0.0.1:8790`.
- Config path seen in prior work: `/etc/nginx/sites-available/ai-builder-api`, enabled from `/etc/nginx/sites-enabled/ai-builder-api`.

Certificate:

- Provider: Let's Encrypt.
- Certificate name: `api.uzbox.top`.
- Current expiry when last checked: 2026-09-27 02:34:49 UTC.
- Certbot timer is enabled.

Useful checks:

```bash
nginx -t
systemctl reload nginx
certbot certificates
curl -k https://127.0.0.1/health -H 'Host: api.uzbox.top'
curl -I https://api.uzbox.top
```

Note: the local Mac may resolve `api.uzbox.top` to a `198.18.*` fake-IP through local proxy DNS. If terminal HTTPS checks fail locally, verify with browser or force the real IP:

```bash
curl --noproxy '*' --resolve api.uzbox.top:443:8.152.202.123 -I https://api.uzbox.top
```

## Current Production Health

Last checked health showed the backend process is reachable and PostgreSQL is configured, but the app is not production-ready:

```json
{
  "status": "ok",
  "dependencies": {
    "postgres": "configured",
    "redis": "not_configured"
  },
  "security": {
    "auth_token_secret": "default",
    "ai_provider_api_key": "configured",
    "ai_provider_base_url": "configured",
    "apple_login": "not_configured",
    "ops_token": "not_configured",
    "community_image_upload": "not_configured",
    "api_docs": "disabled",
    "sms_debug": "enabled",
    "sms_provider": "debug"
  },
  "production": {
    "ready": false,
    "blocking_items": [
      "auth_token_secret_default",
      "sms_debug_enabled",
      "apple_login_not_configured",
      "ops_token_not_configured",
      "community_image_upload_not_configured"
    ]
  }
}
```

The database schema is at Alembic revision `20260720_0015`.

The production base-build catalog now contains:

- Active build templates: `275` (`96` low-budget plus `179` high-budget).
- Budget coverage: `3000` through `10000` every `500`, then `11000` through `20000` every `1000`; individual purchase modes remain unavailable where no honest combination satisfies the price, power, and performance floors.
- All templates retain structured eight-part details and condition-specific reference prices.
- Hardware components: `741`.
- Approved component reference prices: `59`.
- Budgets from `3000` through `4000` return only purchase modes that are feasible with approved prices instead of inventing unavailable new/mixed builds.
- Budgets from `4500` through `20000` contain the feasible FPS / 3A / balanced combinations in new / used / mixed purchase modes.
- `POST /v1/build/options` returns available purchase summaries plus structured eight-part details and reports infeasible modes in `unavailable_modes`.
- `GET /v1/catalog/readiness` returns `ready: true`.

Deployment verified on 2026-07-17:

- Generated templates: `386` (`93` low-budget plus `293` high-budget).
- Every returned template total is between its target budget and target budget plus `300` yuan.
- Budgets from `5000` through `20000` include NVIDIA and AMD variants for 3A/balanced builds in each purchase mode; FPS keeps one NVIDIA-first option per mode.
- `/v1/build/options` can return NVIDIA-only options for ray tracing, NVIDIA plus AMD options when ray tracing is off, and NVIDIA-first options when the preference is absent.
- RTX 4060 is allowed new at `2100`; RTX 4060 Ti remains used-only.
- New DDR5 references include 6000 C28 16GB at `1900` and 6000 C32 16GB at `1700`; existing used C30 remains `1300`.
- High-price combinations that cannot use the full budget without spending more than 15% on the motherboard are unavailable instead of being padded with an excessive board.
- `ai-builder-api.service` is active, Alembic is at head, public HTTPS checks pass, and `/v1/catalog/readiness` returns `ready: true`.

Deployment verified on 2026-07-18:

- Used builds at `5000` yuan and above prefer RTX 40-series or newer and RX 7000-series or newer; RTX 30-series and RX 6000-series remain last-resort fallbacks.
- R7 9800X3D and R7 9850X3D require at least RTX 5060 Ti-class GPU performance; otherwise the generator drops to R7 7800X3D and reallocates budget to the GPU.
- The `7000` yuan used FPS option now returns R7 7800X3D plus RX 9070 GRE at `7230` yuan.
- Before the later base-template re-generation, production contained `386` active templates with `739` hardware components and `49` approved reference prices.
- `ai-builder-api.service` is active and Alembic remains at `20260715_0014 (head)`.

Base-template rules deployed on 2026-07-18:

- Every base template uses a `512GB TLC SSD`; larger storage is reserved for explicit user requirements and may trigger CPU/GPU/RAM/motherboard tradeoffs during customization.
- PSU demand is calculated from CPU and GPU power, and the generator selects the smallest available PSU tier that meets the requirement instead of using wattage to fill budget.
- Base templates at `6000` yuan and above cannot use R5 5600 or R5 5600X.
- The previous `7000` yuan all-new 3A result using R5 5600X, 2TB SSD, and 850W PSU is replaced by R5 7500F, RTX 5060, 512GB SSD, and 650W PSU at `7069` yuan.
- That deployment contained `354` active templates with `739` hardware components and `51` approved reference prices before the later 3A value-part update.

3A value-part rules deployed on 2026-07-18:

- All-new 3A base templates use DDR5 6000 C32 rather than spending another `200` yuan on C28; the saving is directed toward the GPU.
- ASUS PRIME B650M-K is available at a `700` yuan all-new reference price for value-focused 7500F/9600X builds; it is not paired with 9800X3D/9850X3D.
- The all-new 650W Gold PSU reference price is `250` yuan and wattage remains selected from the CPU/GPU power formula.
- Base templates may total up to `100` yuan below the target tier when no meaningful upgrade fits, while the upper limit remains target plus `300` yuan.
- The `7000` yuan all-new NVIDIA 3A option returns R5 7500F plus RTX 5060 Ti at `6950` yuan.
- The `7500` yuan all-new NVIDIA 3A option returns R5 9600X plus RTX 5060 Ti at `7450` yuan.
- That deployment contained `361` active templates before the later full-tier non-performance-part audit.

Full-tier base-template audit deployed on 2026-07-18:

- Every base template uses 16GB RAM and a 512GB TLC SSD; 32GB RAM and larger storage are user-specific customizations only.
- Every 3A base template maximizes the GPU first and starts with the cheapest safe motherboard; it may step up at most `300` yuan, while staying below 15% of budget, only when needed to enter the allowed budget interval.
- PSU wattage remains the smallest available tier that satisfies the CPU/GPU power formula.
- The generator enforces the RTX 5060 Ti-class GPU floor for 9800X3D/9850X3D in every direction, not only FPS.
- The audit found zero remaining 3A motherboard overbuilds, 32GB base templates, oversized PSUs, non-512GB storage, or 9800X3D GPU-floor violations.
- That deployment contained `274` active templates before the later GPU-first and B850 whitelist update.

GPU-first and B850 whitelist update deployed on 2026-07-18:

- The `7000` yuan mixed NVIDIA 3A option uses R5 9600X, ASUS B650M TUF, and RTX 5060 Ti at `7050` yuan instead of retaining R7 7800X3D with RTX 5060.
- Generated B850 boards are limited to MSI B850M POWER and ASUS B850 AYW GAMING OC; MSI B850M MORTAR is not selected.
- The `8000` yuan used FPS option uses R7 9800X3D, MSI B850M POWER, and RX 9070 GRE at `8230` yuan.
- That deployment contained `280` active templates before the later RTX 5060 price update.

RTX 5060 value update deployed on 2026-07-19:

- The all-new RTX 5060 reference price is `2300` yuan, only `200` yuan above RTX 4060.
- The `5500` yuan mixed NVIDIA 3A option uses RTX 5060 at `5750` yuan.
- The `6000` yuan all-new FPS option uses DDR5 6000 C32 and RTX 5060 at `6250` yuan; the all-new 3A option also reaches RTX 5060 at `6250` yuan.
- When ray tracing is unspecified, `/v1/build/options` remains NVIDIA-first but falls back to AMD for an individual purchase mode when no NVIDIA template is feasible. This restores the `5000` yuan mixed option for 3A and balanced use.
- That deployment contained `280` active templates before the later ¥6000 tier update.

¥6000 tier update deployed on 2026-07-19:

- New reference prices: R5 9600X `1050` yuan, RTX 5060 Ti `2800` yuan, DDR5 6000 C36 16GB `1300` yuan, and a new 650W Gold PSU `200` yuan.
- The all-new FPS and balanced options use R5 9600X, RTX 5060, and DDR5 6000 C36 at `6250` yuan.
- The all-new 3A NVIDIA option uses R5 7500F, RTX 5060 Ti, and DDR5 6000 C36 at `6300` yuan; the AMD alternative uses RX 7700 XT at `6100` yuan.
- Used and mixed ¥6000 options retain stronger fitting CPU/GPU pairs instead of being reduced to the all-new baseline.
- DDR5 6000 C36 is selected only when a lower-latency kit would prevent the stronger CPU/GPU combination from fitting the allowed budget interval.
- That deployment contained `290` active templates before the later FPS/3A direction correction.

FPS/3A direction correction deployed on 2026-07-19:

- The `6500` yuan mixed FPS option keeps R7 7800X3D and upgrades the GPU to RTX 5060 at `6830` yuan; this reviewed option is the only template allowed `30` yuan beyond the normal `budget + 300` ceiling.
- The used RTX 4070 SUPER reference price is `3700` yuan. The `8000` yuan used NVIDIA 3A option uses R7 7800X3D + RTX 4070 SUPER at `7980` yuan instead of overspending on 9800X3D.
- RTX 4070 Ti has no whitelist price, recommendation flag, or component price and is blocked by regression coverage.
- FPS motherboard share may reach 16% when the former 15% cap would eliminate the CPU-priority candidate; 3A and balanced builds retain the 15% cap.
- The `8500` yuan mixed FPS option uses R7 9800X3D + RTX 5060 Ti at `8679` yuan.
- The `9000` yuan mixed FPS option uses R7 9800X3D + RX 9070 GRE at `8980` yuan. AMD may override NVIDIA for FPS only when it unlocks a higher CPU tier without lowering GPU performance.
- The `9500` yuan mixed FPS option uses R7 9800X3D + RX 9070 GRE with MSI B850M POWER at `9480` yuan instead of R5 9600X + RTX 5070.
- At `9500` yuan and above, FPS templates cannot drop below R7 7800X3D; 3A templates using R7 9800X3D/9850X3D require at least RTX 5070 Ti-class GPU performance.
- Balanced scoring now penalizes large CPU/GPU performance gaps after protecting the weaker side. A full audit left only two 25-point gaps where the available GPU upgrade would reduce the weaker side from 75 to 60, so the original stronger overall combination is retained.
- That deployment contained `290` active templates before the later all-new baseline floor.

All-new baseline floor deployed on 2026-07-19:

- At `10000` yuan and above, used and mixed FPS options cannot have lower CPU performance than all-new; 3A cannot have lower GPU performance; balanced cannot have lower weaker-side performance.
- The `10000` yuan mixed FPS option now uses R7 9800X3D + RX 7800 XT at `10049` yuan instead of the previous R7 7800X3D + RTX 5070 configuration.
- Four FPS options with no honest candidate meeting the all-new CPU floor are unavailable: `11000` used, `12500` mixed, `13000` used, and `14500` mixed.
- The `11500` yuan mixed NVIDIA balanced option was regenerated to meet the all-new weaker-side performance floor.
- Production contains `286` active templates; readiness remains ready with `741` hardware components and `55` approved reference prices.

850W price and FPS mode-coverage update deployed on 2026-07-19:

- The 850W Gold PSU reference is `400` yuan all-new and `250` yuan used. All generated templates use those prices, and PSU wattage is still selected from the CPU/GPU power formula rather than used to pad budget.
- The `10000` yuan all-new FPS option uses R7 9800X3D, MSI B850M POWER, and RX 9070 GRE at `10450` yuan. This user-reviewed board upgrade is the explicit exception to the normal `budget + 300` ceiling.
- The `10000` yuan mixed NVIDIA 3A option uses ASUS B650M TUF and the corrected `400` yuan 850W PSU at `10130` yuan.
- Every FPS tier from `11000` through `17500` now returns all-new, used, and mixed modes without lowering used/mixed CPU performance below the all-new option. The `11000` yuan used FPS option uses R7 9850X3D plus RX 7900 XTX at `11080` yuan.
- Missing high-budget FPS modes are limited to combinations that cannot honestly fit between RTX 5080 and RTX 5090 D V2 with the fixed 16GB RAM, 512GB SSD, and calculated PSU rules: used at `18000` through `20000`, plus mixed at `19500` and `20000`.
- Production contains `303` active templates with `741` hardware components and `58` approved component reference prices. `/v1/catalog/readiness` remains ready.

RTX 5070 Ti CPU floor deployed on 2026-07-19:

- RTX 5070 Ti, RTX 5080, and higher NVIDIA GPUs require at least R7 9700X-class CPU performance. The generator prefers R7 7800X3D and uses R7 9700X only when the X3D option cannot fit.
- The `11000` yuan all-new NVIDIA 3A option uses R7 7800X3D + RTX 5070 at `10950` yuan instead of pairing RTX 5070 Ti with R5 7500F.
- The `11000` yuan used NVIDIA 3A option uses R7 7800X3D + RTX 5070 Ti at `10780` yuan.
- The `11000` yuan mixed NVIDIA 3A option uses R7 7800X3D + RTX 5070 + MSI B850M POWER at `10630` yuan instead of pairing RTX 5070 Ti with R5 9600X.
- Production contains `301` active templates with `741` hardware components and `59` approved component reference prices. The production audit found zero active templates violating the new CPU floor.

High-tier interval, memory floor, and 9800X3D price update deployed on 2026-07-19:

- R7 9800X3D is `2500` yuan new and `2400` yuan used in the CPU whitelist and generated template prices.
- High-budget tiers are `7500` through `10000` every `500` yuan, then `11000` through `20000` every `1000` yuan. Requests between tiers use the lower maintained tier, so a `11500` yuan request matches the `11000` yuan templates.
- Templates at `10000` yuan and above may total up to target plus `800` yuan and must use DDR5 6000 C32 or better latency; used C30 qualifies and C36 is rejected by both generation and import validation.
- The `11000` yuan all-new FPS option uses R7 9800X3D, MSI B850M POWER, RTX 5070, and DDR5 6000 C32 at `11750` yuan.
- The lower 9800X3D price upgrades a motherboard only when CPU, GPU, and RAM do not regress and the result stays inside the applicable ceiling. Configurations where that upgrade does not fit keep the adequate B650 board.
- Production contains `242` active templates (`96` low-budget plus `146` high-budget), `741` hardware components, and `59` approved component prices. The production audit found zero stale half-tier, C36-at-10000+, budget-overage, or 9800X3D-price violations.

RTX 5070 price and reviewed ¥11000 3A update deployed on 2026-07-20:

- RTX 5070 is `5000` yuan new and `4300` yuan used in the GPU whitelist and generated component prices.
- The `11000` yuan all-new NVIDIA 3A option is the user-reviewed exception to the normal 9800X3D/5070 Ti-class pairing floor: R7 9800X3D, ASUS B650M TUF, RTX 5070, and DDR5 6000 C32 at `11250` yuan.
- The `11000` yuan all-new NVIDIA FPS option uses R7 9800X3D, MSI B850M POWER, RTX 5070, and DDR5 6000 C32 at `11750` yuan.
- Production and public `/v1/build/options` both return the updated prices and parts; catalog readiness remains ready with `242` active templates.

Reviewed ¥12000-¥15000 builds and high-tier mode coverage deployed on 2026-07-20:

- The `12000` yuan NVIDIA 3A all-new and mixed options both use ASUS B650M TUF. All-new uses DDR5 6000 C32 at `12750` yuan; mixed keeps used DDR5 6000 C30 at `12130` yuan.
- The `14000` yuan all-new NVIDIA 3A and balanced options use R7 9800X3D + MSI B850M POWER + RTX 5070 Ti. The used 3A option uses R7 9800X3D + MSI B850M POWER + RTX 5080 at `13930` yuan.
- The `14000` yuan mixed NVIDIA balanced option uses used R7 9800X3D + new MSI X870E Tomahawk + new RTX 5070 Ti at `13880` yuan.
- The `15000` yuan used NVIDIA 3A option uses R7 9850X3D + MSI X870E EDGE TI + RTX 5080 at `14880` yuan.
- Missing NVIDIA 3A/balanced modes from `15000` yuan are retried only after normal selection fails, with at most `550` yuan shortfall, `23%` motherboard share, and a `3500` yuan motherboard step-up ceiling.
- Every direction from `10000` through `20000` now has all-new, used, and mixed purchase modes.
- At `18000` through `20000`, where RTX 5090 cannot fit, base templates use 32GB RAM instead of leaving the second DIMM slot as unused budget. New FPS uses DDR5 6000 C28, new 3A/balanced uses C32, and used/mixed uses C30.
- Coverage-only X870E upgrades at those tiers may reach 32% of budget and a `6000` yuan step-up ceiling; SSD remains 512GB and PSU wattage remains formula-driven.
- Production contains `275` active templates (`96` low-budget plus `179` high-budget), `741` hardware components, and `61` approved component prices. Public build options and catalog readiness checks pass with zero missing purchase modes.

Productivity CPU whitelist update deployed on 2026-07-20:

- The retained productivity additions are i5-14400F, i7-13700KF, Ultra 5 245K, Ultra 5 250 Plus, Ultra 7 265K, and Ultra 7 270 Plus. After the user's value review, i5-14490F, i5-14600KF, i7-14700KF, i9-14900KF, and Ultra 5 225F were removed from `cpu_whitelist_price`.
- Used/new tray references are i5-14400F `900/900`, i7-13700KF `1450/1750`, Ultra 5 245K `850/1090`, Ultra 5 250 Plus `1300/1450`, Ultra 7 265K `1500/1799`, and Ultra 7 270 Plus `2000/2100`.
- The three previously missing Ultra models were added to the hardware catalog. They remain outside existing gaming base templates and are not marked recommended for gaming customization.
- Production contains `744` hardware components, `15` CPU whitelist rows, and the same `275` active gaming templates. Catalog readiness remains ready.

Office-only Intel Arc whitelist update deployed on 2026-07-20:

- Added Intel Arc A580 8GB, Arc A770 16GB, Arc B570 10GB, and Arc B580 12GB to the hardware and GPU whitelist catalogs. Used/new prices are A580 `850/1400`, A770 16GB `1300/2000`, B570 `1300/2000`, and B580 `1500/2500`.
- All four Arc components remain `is_recommended=false`, so they cannot be selected before office base templates explicitly approve them.
- Arc rule specs live outside `GPU_PERFORMANCE`; the existing FPS/3A/balanced generators therefore ignore Arc even after prices are supplied. The skill also forbids Arc for any gaming or gaming-plus-office request.
- Production contains `748` hardware components, `15` CPU whitelist rows, `30` GPU whitelist rows, and the same `275` active gaming templates. Catalog readiness remains ready.

DeepSeek controlled customization deployed on 2026-07-20:

- The temporary official DeepSeek key is configured only in local and production `.env` files; the configured model is `deepseek-v4-flash` and the base URL is `https://api.deepseek.com`.
- DeepSeek cannot return a complete build. It must choose a same-direction approved `base_template_id` and may return only whitelisted component patches plus short reasons.
- The server applies memory/storage, Wi-Fi/Bluetooth, and self-owned GPU requirements, then validates condition-specific prices, compatibility, the CPU/GPU power formula, GPU CPU floors, direction performance, and final budget.
- Customized builds may total up to requested budget plus `500` yuan below `10000`, or plus `800` yuan at `10000` and above.
- A normal motherboard gains a `WIFI` suffix and `50` yuan; ASUS A520M-K instead receives a separate `50` yuan Wi-Fi/Bluetooth adapter under `extras`.
- Self-owned GPU mode requires a recognizable whitelisted GPU model and returns that GPU with condition `owned` and price `0`.
- Invalid model output gets one controlled retry. If it still fails, the API returns the strongest valid same-direction base customization rather than inventing parts or failing the whole result page.
- Production smoke tests passed for unchanged base options, `7000` yuan FPS with 1TB and Wi-Fi across all three purchase modes, the A520M-K adapter exception, a self-owned RTX 5070, and missing-GPU-model rejection.

Selected-build reuse cache deployed on 2026-07-20:

- Migration `20260720_0015` adds `build_selection_cache`; generated options are stored as pending records, but only records with `selected_count > 0` may be reused.
- Every customized option returns an opaque `selection_id`. The iOS app posts to `/v1/build/options/{selection_id}/select` when the user opens that option, including the automatic single-option path.
- The request hash includes budget, use case, selected games, direction, ray tracing, office apps, Wi-Fi, memory, storage, self-owned GPU, chassis color, CPU constraints, specified parts, and notes. Purchase mode and GPU vendor are separate option keys.
- Cache validity includes active template, hardware, and approved-price counts/latest timestamps plus a hash of the customization rules. A catalog, price, template, or rules change prevents stale reuse automatically.
- Concurrent identical first requests share the unique request/option record instead of returning a database conflict.
- Production verification: the first `7200` yuan FPS + 16GB + 1TB + Wi-Fi request returned three `ai_provider` options; after selecting the used option, the same request returned `selection_cache` for used while new and mixed still used AI. Public HTTPS selection confirmation also passed.

`APP_PRODUCTION_DATA_READINESS_REQUIRED` is currently disabled, so `/health` reports data readiness as `not_checked` even though the dedicated readiness endpoint is ready. `/health` still reports `production.ready: false` because login secrets, production SMS, Apple login, the ops token, and community image upload are not configured; those are separate from the base-build data deployment.

Because first release will not expose community, `community_image_upload_not_configured` may be handled by hiding community/image features rather than configuring OSS immediately. Do not silently remove the health gate without an explicit release decision.

## Deployment

Do not use `backend/scripts/deploy.sh` for production work until its behavior is re-verified against the current worktree. Deploy narrowly scoped files so unrelated local changes are not copied.

Current production target:

- Server: `8.152.202.123`.
- SSH key: `~/.ssh/ai_builder_aliyun`.
- Directory: `/opt/ai-builder-api`.
- Service: `ai-builder-api.service`.
- Manager: systemd.

The old server `36.213.128.58` still exists for previous projects, but it is not the current `api.uzbox.top` target.

## ICP and Domain Notes

- App backend service domain: `api.uzbox.top`.
- Website/main备案 domain should be the root domain: `uzbox.top`.
- In Alibaba Cloud filing, the App service can list `api.uzbox.top`, while website filing should use `uzbox.top` without `www`.
- After root-domain filing succeeds, subdomains such as `api.uzbox.top` should be covered for Alibaba Cloud access.

## Safety Rules

- Do not print `.env` values, API keys, SMS secrets, database passwords, or private keys.
- Do not modify Nginx, systemd, DNS, or cloud security groups unless the user asked for deployment/server work.
- Before claiming production readiness, verify `/health`, HTTPS, and the iOS Release API base URL.
- For backend roadmap work, keep `backend/progress.json` synchronized as required by `backend/AGENTS.md`.
