# Backend and Server Context

Last verified: 2026-08-31.

## Core-First Budget Fill and 9850X3D Price Update (2026-08-31)

- Deterministic base generation now treats CPU/GPU pairs as the protected core: a non-dominated CPU/GPU upgrade is considered before any motherboard step-up, and a lower-performing core cannot be selected merely to buy a high-priced motherboard.
- The hard budget floor remains `total >= budget - 200`; motherboard upgrades are only considered after the core pair and locked capacities are fixed.
- R7 9850X3D whitelist references are `2799` yuan new and `2550` yuan used. High-budget artifacts were regenerated with 350 templates.
- The 26000 yuan / 3A / 1TB audit checked 54 purchase-direction-capacity combinations: 51 returned valid options, while the three 16GB all-new combinations correctly returned `no_option` because no reviewed 8-part combination fits the hard budget window. The corresponding 32GB combinations all returned valid options without a low-CPU/high-price-board regression.

## Low-Budget Used Parts and DDR4 FPS Memory Update (Deployed 2026-08-30)

- User-confirmed used references are R5 5600X `650`, GTX 1080 Ti `949`, 玄武 550 V4 550W `109`, 玄武 650SE 650W `139`, Thermalright AX120 SE `39`, and DDR4 8GB×2 3200 `450` yuan.
- GTX 1080 Ti uses the existing canonical `gtx-1080-ti` catalog ID, project performance index `38`, and 250W TDP. R5 5600X + GTX 1080 Ti requires at least 650W, so the reviewed `3000` yuan used template selects 玄武 650SE rather than the cheaper 550W unit.
- DDR4 8GB×2 3600 is available at `499/759` yuan used/new and is preferred for DDR4 FPS templates only when it remains within the normal budget ceiling; other directions retain the cheaper 3200 tier by default.
- Low-budget, high-budget, and office artifacts were regenerated and deployed. The lowest reviewed used build is `base-3000-balanced-used` at `2937` yuan with DDR4-3200; the FPS variant is `base-3000-fps-used` at `2986` yuan with DDR4-3600. Both use R5 5600X, GTX 1080 Ti, 玄武 650SE, and a used AX120 SE.
- Production contains `503` active templates, `6628` hardware components, and `5987` approved component prices. `ai-builder-api.service` is active; local and public health/readiness checks pass with `ready: true`; a public `3000` yuan FPS request returns the `2986` yuan used template with the reviewed condition-specific prices.
- Deployment backup: `/opt/ai-builder-api/backups/used-ddr4-20260830-182324` (`files.tgz` and `catalog.dump`).

## AMD GPU Used Price Update (Deployed 2026-08-30)

- User-confirmed used reference prices are RX 6750 GRE `1699`, RX 7650 GRE `1499`, RX 7700 XT `2300`, RX 7800 XT `2799`, RX 7900 XT `3999`, RX 7900 XTX `5399`, RX 9060 XT 8GB `2299`, RX 9060 XT 16GB `2899`, RX 9070 GRE `3699`, and RX 9070 XT `5099` yuan.
- Low-budget, high-budget, and office artifacts were regenerated and deployed with price date `2026-08-30`. Production whitelist rows and public catalog-backed recommendations use these prices; deployment counts, verification, and backup are recorded in the section above.

## i5-14600KF DDR4 Platform Alternative and Low-Budget Rules (Deployed 2026-08-26)

- `i5-14600KF` is back in the approved CPU whitelist at an all-new price of `1499` yuan with no invented used price. It is reserved for a user-selectable platform alternative and does not silently replace existing base-build CPUs.
- Every returned build whose main CPU is R5 7500F now includes a complete alternative containing i5-14600KF, MSI B760M-A DDR4, same-capacity dual-channel DDR4-3200 memory, and a dual-tower six-heatpipe cooler. If the 181W CPU raises the calculated PSU requirement, the response also replaces the PSU with the cheapest reviewed adequate model.
- The iOS result page places the alternative card directly below the CPU. It shows the project CPU-performance gain of about `40%`, recalculates the total and game-performance CPU when selected, and explains that 7500F is slower today but has the stronger AM5 upgrade path, while 14600KF is faster today but a later major upgrade usually requires replacing CPU, motherboard, and memory together.
- Production smoke verification passed at `7500` yuan all-new 3A: the main build uses R5 7500F and the alternative returns all-new i5-14600KF `1499`, B760M-A DDR4 `850`, DDR4 8GB×2 `500`, and dual-tower cooling `150`; the platform is `51` yuan cheaper for that configuration. At `8500` yuan with RX 9070 GRE, the alternative correctly adds a 750W PSU because the original 650W unit is insufficient for 14600KF.
- The previously completed low-budget rules are deployed with the same release: R5 5600/5600X always uses an all-new Thermalright AX120 SE at `69` yuan; ASUS A520M-K is `339` yuan all-new and is allowed only through RX 7650 GRE-class GPU performance. A public `4500` yuan balanced 16GB/512GB request returns all three modes; the all-new option is `4735` yuan with 5600X, A520M-K, and AX120 SE.
- Production now has `494` active templates, `6626` hardware components, and `5984` approved component prices. Catalog readiness is `ready: true`, public health is HTTP 200, and the user-confirmed AMD GPU whitelist prices were rechecked in production.
- Deployment backup: `/opt/ai-builder-api/backups/cpu-platform-20260826-1700`.

## AMD GPU Price and RX 9060 XT Model Correction (Deployed 2026-08-26)

- User-confirmed all-new prices are RX 7650 GRE `2199`, RX 7700 XT `2699`, RX 9060 XT 8GB `3099`, RX 9060 XT 16GB `3099`, RX 9070 GRE `4699`, and RX 9070 XT `6999` yuan. RX 7800 XT is discontinued and has no all-new price.
- The nonexistent RX 9060 XT 12GB entry was retired and removed from production prices. RX 9060 XT 16GB is the canonical model with the retained `2200` yuan used reference price, project performance index `55`, and 200W TDP.
- Low-budget, high-budget, and office artifacts were regenerated with price date `2026-08-26`. Production contains `491` active templates; none uses RX 9060 XT 12GB or RX 7800 XT as an all-new GPU.
- Production verification passed: `ai-builder-api.service` is active, public health and catalog readiness return HTTP 200, catalog readiness is `ready: true`, and a public `5000` yuan balanced request returned all three purchase modes with the updated prices.
- Deployment backup: `/opt/ai-builder-api/backups/amd-gpu-price-20260826-133425`.

## Direction Allocation and DDR4 Dual-Channel Gate (Deployed 2026-08-23)

- Deterministic customization now derives its minimum focus performance from reviewed candidates that fit the request ceiling: FPS protects CPU performance, 3A protects GPU performance, and balanced protects the weaker side. Only candidates inside the complete budget window may dominate another CPU/GPU pair, so a below-floor base can no longer eliminate the correct direction and force a price-filling reversal.
- Every final path rejects R5 5600/5600X for gaming requests from `6000` yuan unless the user explicitly names that CPU. The check covers direct templates, deterministic search, and selected-result cache reuse.
- DDR4 is hard-gated to dual-channel DDR4-3200. A 16GB result displays `DDR4 8GB×2 3200`; a 32GB result displays `DDR4 16GB×2 3200`. DDR5 remains outside this dual-channel gate.
- Below `10000` yuan with no explicit GPU vendor or ray-tracing choice, 3A/balanced generation compares both NVIDIA and AMD candidates and selects by the requested direction instead of stopping at the first NVIDIA result.
- The full `4500` through `30000` yuan, every-`100`-yuan capacity matrix checked `13824` options: `13103` passed (`94.78%`), and all `721` failures were honest `no_option` results. The realistic-capacity subset passed `12643/13059` (`96.81%`). There were zero accepted budget-window, R5 5600/5600X, DDR4 dual-channel, AM5 C28, cooling, or power violations.
- A separate `6000` through `30000` direction-allocation audit checked `2169` budget/direction/purchase-mode results with 1TB, 16GB, and Wi-Fi: zero FPS-vs-3A/balanced allocation reversals were found. Forty-six individual combinations were unavailable rather than returning a direction-regressing build.
- Production verification for the reported `7000` yuan, 16GB, 1TB, Wi-Fi request: all three modes returned; all-new FPS is i5-12600KF + RTX 5060 at `7116`, all-new 3A/balanced is R5 7500F + RX 7700 XT at `7127`, and no mode uses 5600/5600X. Health and catalog readiness pass with `487` active templates.
- Deployment backup: `/opt/ai-builder-api/backups/direction-memory-policy-20260823-161342`.

## RTX 4090 / 4090 D Used Price Record (2026-08-23)

- User-confirmed used reference prices are RTX 4090 `21000` yuan and RTX 4090 D `15500` yuan.
- The user-confirmed gaming-performance order is RTX 5090 D V2, RTX 4090, RTX 4090 D, then RTX 5080. RTX 4090 and RTX 4090 D participate in used and mixed high-budget generation with that strict order.

## Continuous Budget Window Update (Deployed 2026-08-22)

- Base templates, deterministic customization, and selected-option cache reuse all enforce the same request-budget window: below `10000`, totals must be from `budget - 200` through `budget + 300` by default or `budget + 500` when flexibility is enabled; from `10000`, the ceiling is `budget + 800`.
- An explicitly selected `16GB`/`32GB` memory capacity and `512GB`/`1TB`/`2TB` storage capacity are exact locks. Search never changes either capacity to fill the budget; remaining money is spent only on reviewed CPU, GPU, motherboard, PSU, cooler, or case improvements.
- Arbitrary budgets search all lower reviewed anchors plus the immediately higher reviewed tier, then run a deterministic whitelist-only combination search. DeepSeek is outside the synchronous feasibility and success path.
- At `4500` yuan and above, the public API requires new, used, and mixed options together. If any mode has no honest combination satisfying capacity, compatibility, power, direction-performance, and budget rules, the whole request returns `503` instead of silently returning one or two modes.
- The matrix gate checks `4500` through `30000` every `100` yuan across FPS/3A/balanced, `16GB`/`32GB`, `512GB`/`1TB`/`2TB`, and all three purchase modes: `12957/13824` options pass (`93.73%`). With realistic capacity floors (`32GB >= 6000`, `1TB >= 5000`, `2TB >= 7000`), `12586/13059` pass (`96.38%`). All `867` remaining failures are `no_option`; no accepted option violates the budget window, locked capacity, AM5 C28, hot-CPU cooling, or power rules.
- A Pareto quality gate rejects a candidate when another reviewed candidate that fits the same hard requirements and budget ceiling is at least as fast in both CPU and GPU and strictly faster in one. This removed `806` previously counted “successes” that reached the price floor only by replacing a cheaper, faster core part or by lowering core performance to buy a pricier motherboard. CPU/GPU tradeoffs where each candidate wins on one side remain valid.
- R7 9800X3D and R7 9850X3D cannot use the entry-level ASUS PRIME B650M-K; base-template and deterministic paths both enforce this before returning an option.
- Mixed-mode search may buy the same reviewed cooler or case new when that is a meaningful reliability improvement needed to enter the strict budget window. It still cannot pad the total with larger storage, more memory, or an oversized PSU.
- PUBG and 永劫无间 force NVIDIA from `7900`; 三角洲/三角洲行动 force NVIDIA from `7500`. Below those stable NVIDIA thresholds, value-first AMD/NVIDIA selection remains enabled. A lower-budget request can still return `503` when one purchase mode has no non-dominated option inside the strict budget window; it does not substitute a more expensive but weaker GPU merely to force three-mode coverage.
- Selection-cache version `build-selection-v2` fingerprints customization, request classification, and API vendor/purchase rules, automatically invalidating results selected under older policies.
- Production backups: `/opt/ai-builder-api/backups/continuous-budget-strict-20260822-174338` preserves the pre-continuous-search version; `/opt/ai-builder-api/backups/pareto-quality-20260822-181510` preserves the pre-Pareto version. Full backend tests, public HTTPS, health/readiness, critical budget/capacity requests, ray tracing, special-game thresholds, dominated-option rejection, and progress-page smoke tests passed after deployment.

## Three Purchase Modes and Ray-Tracing Budget Gate (2026-08-22)

- Public gaming requests from `4500` through `30000` yuan now return new, used, and mixed purchase modes for every reviewed FPS / 3A / balanced tier. The API refuses a silent one- or two-mode partial response at `4500` yuan and above.
- Every returned option must total at least `budget - 200`. High-budget generation may move from the 512GB TLC baseline to 1TB/2TB only when the otherwise identical 512GB candidate would fall below that floor and no higher core-performance tier fits the ceiling.
- Ray tracing forces NVIDIA only from `10000` yuan. Below `10000`, enabling ray tracing keeps the ordinary value-first vendor fallback; from `10000`, FPS, 3A, and balanced all have NVIDIA coverage in new, used, and mixed modes.
- In-between requests may use the immediately higher reviewed tier only when its total still fits the original request's budget ceiling; production verification passed at `9999` yuan using the `10000` yuan tier.
- The high-budget catalog contains `332` templates and reports public purchase-mode coverage for all `26/26` tiers. Production contains `487` active templates (`83` low-budget gaming + `332` high-budget gaming + `72` office), `6388` components, and `5745` approved prices; readiness is `ready: true`.
- Full backend regression tests passed. Public HTTPS smoke tests passed at `4500`, `7000`, `9500`, `9999`, `10000`, and `30000` yuan. The deployment backup is `/opt/ai-builder-api/backups/purchase-mode-raytracing-20260822-145330`.

## RTX 40/50 Series Price Update (2026-08-22)

- User-confirmed all-new reference prices are RTX 5060 `3299`, RTX 5060 Ti `3599`, RTX 5070 `6999`, RTX 5070 Ti `9799`, and RTX 5080 `13499` yuan.
- User-confirmed used reference prices are RTX 4060 `1999`, RTX 4060 Ti `2300`, RTX 4070 `3299`, RTX 4070 SUPER `3700`, RTX 4070 Ti `4200`, RTX 4070 Ti SUPER `4799`, RTX 5060 `2650`, RTX 5060 Ti `3099`, RTX 5070 `5999`, RTX 5070 Ti `7299`, and RTX 5080 `10500` yuan. The earlier RTX 4080 `6900` and RTX 4080 SUPER `7300` references remain unchanged.
- RTX 4070 Ti is price-recorded only: it remains unrecommended and excluded from gaming generation. RTX 4070 Ti SUPER is approved with project performance index `80`, 285W TDP, and the existing Time Spy score; production has `19` active templates using it.
- Low-budget, high-budget, and office artifacts were regenerated with price date `2026-08-22`. Production contains `449` active templates.
- The all-new-to-used recommendation mapping remains RTX 5060 to used RTX 4070 `3299`, RTX 5060 Ti to used RTX 4070 SUPER `3700`, RTX 5070 to used RTX 4080 `6900`, and RTX 5070 Ti to used RTX 4080 SUPER `7300`. RTX 5080 has no non-regressing used RTX 40-series alternative under the maintained rules.
- Production verification passed: `/v1/catalog/readiness` is ready with `6388` components, `5745` approved component prices, and `449` active templates. A public `9000` yuan 3A request returned RTX 4070 Ti SUPER at `4799` yuan in both used and mixed modes.

## AM5 DDR5 6000 C28 Update (2026-08-22)

- Every generated AM5 build now uses DDR5 6000 C28 in new, used, and mixed purchase modes; the same rule is enforced again during structured customization.
- User-confirmed 16GB reference prices are `1350` yuan used and `1650` yuan new. The maintained 32GB (16GB x2) entries are `2700` yuan used and `3300` yuan new.
- Low-budget, high-budget, and office artifacts were regenerated and imported. Production contains `447` active templates; all `321` active AM5 templates passed the C28 audit.
- Production data readiness remains ready with `6388` hardware components and `5744` approved component prices.

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
- RTX 4070 Ti was blocked by regression coverage and remains excluded; its later `4200` yuan used reference is recorded for comparison only. RTX 4070 Ti SUPER is a separate allowed model.
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
