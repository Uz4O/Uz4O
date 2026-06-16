# 后端修复指令（给 Codex 执行）

> 来源：Claude 评审 + Codex 复核后达成一致的最终清单。
> Claude 负责设计判断，Codex 负责实操。本文件每一项都标注了**确切文件、行号、做法、验收标准**。
> 修改前先 `cd backend`，每改完一项跑一次对应测试，最后整体 `./.venv/bin/python -m pytest -q` 必须保持全绿（当前基线 160 passed）。

---

## 优先级总览

| # | 任务 | 优先级 | 风险 |
|---|------|--------|------|
| 1 | access token 改标准 JWT（HS256），兼容旧 token 过渡 | 🔴 高 | 中（动登录） |
| 2 | `_fallback_candidates_by_role` 去下划线，显式导出 | 🔴 高 | 低 |
| 3 | `rules_fallback_response` 组合剪枝，限制爆炸 | 🟡 中 | 中（动核心算法） |
| 4 | 生产环境 `APP_ENV=production` 时默认密钥 fail-fast | 🟡 中 | 低 |
| 5 | （可选）`/health` 的 session factory 挪到 `app.state` | ⚪️ 低 | 低 |
| 6 | 更新过时的 `CLAUDE.md`（后端已完成，非"未开始"） | 🟡 中 | 无 |

> 注意：原评审里的「`ai_model` 默认值」一项**不做** —— Codex 已用该模型名实测返回 200，不是错误，不要盲改。

---

## 任务 1：access token 改为标准 JWT（HS256），兼容旧 token

### 背景
当前 `app/auth/security.py` 是自研的 `base64(payload).hmac_signature` 格式，HMAC 校验逻辑本身没错，但缺标准 JWT 头（`alg`/`typ`），将来换算法、轮换密钥、接其它客户端会麻烦。项目已依赖 `PyJWT[crypto]>=2.8`（见 `pyproject.toml:15`），直接用它。

### 涉及文件
- `app/auth/security.py` —— 签发 + 校验
- 调用点无需改签名：`app/api/auth.py:84`、`app/api/auth.py:117` 仍调 `sign_access_token(account_id, secret, expires_at)`；`app/auth/dependencies.py:31` 仍调 `verify_access_token(token, secret)`。**保持这两个函数的签名不变**，只换内部实现。

### 具体做法
1. `sign_access_token(account_id, secret, expires_at)` 内部改用：
   ```python
   import jwt
   def sign_access_token(account_id: str, secret: str, expires_at: datetime) -> str:
       return jwt.encode(
           {"sub": account_id, "exp": int(expires_at.timestamp())},
           secret,
           algorithm="HS256",
       )
   ```
2. `verify_access_token(token, secret)` 改为**先试 JWT，失败再回退旧格式**（过渡期）：
   ```python
   def verify_access_token(token: str, secret: str) -> Optional[str]:
       # 1) 新格式：标准 JWT
       try:
           payload = jwt.decode(token, secret, algorithms=["HS256"])
           sub = payload.get("sub")
           return sub if isinstance(sub, str) and sub else None
       except jwt.PyJWTError:
           pass
       # 2) 过渡期回退：旧自研格式（保留现有 _legacy_verify 逻辑，2 周后删除）
       return _legacy_verify_access_token(token, secret)
   ```
   - 把现有的自研校验逻辑（split(".")、`_signature`、`_urlsafe_decode`、过期判断那一整套）**原样挪进** `_legacy_verify_access_token`，不要改它，只是改个名字、降级为兜底分支。
   - `jwt.decode` 默认会校验 `exp` 过期，无需手动再判一次。
   - **算法必须硬编码 `algorithms=["HS256"]`**，禁止从 token 头读 alg（防 alg=none / alg 混淆攻击）。

3. 在 `_legacy_verify_access_token` 上方加一行注释：
   ```python
   # TODO(过渡期至 2026-06-30): 旧自研 token 兼容分支，过渡期后连同此函数一起删除。
   ```

### 验收
- `./.venv/bin/python -m pytest tests/test_auth_security.py tests/test_auth_profile_api.py -q` 全绿。
- 新增一个测试用例：用 `sign_access_token` 签发的新 token 能被 `verify_access_token` 正确解出 `account_id`；过期 token 返回 `None`；被篡改 1 个字符的 token 返回 `None`。
- 旧格式 token（可在测试里手工用旧逻辑构造一个）仍能通过 `verify_access_token`，证明过渡兼容生效。

---

## 任务 2：`_fallback_candidates_by_role` 去下划线，显式导出

### 背景
`app/api/builds.py:17` 跨模块导入了 `app/builds/service.py` 的私有函数 `_fallback_candidates_by_role`（下划线开头）。被跨模块用，就不该是私有的，否则后续重构容易误删。

### 涉及文件 / 引用点（共 4 处）
- `app/builds/service.py:320` —— 定义处
- `app/builds/service.py:238` —— 同文件内调用
- `app/api/builds.py:17` —— import
- `app/api/builds.py:79` —— 调用

### 具体做法
- 把函数名 `_fallback_candidates_by_role` 重命名为 `fallback_candidates_by_role`（去掉前导下划线），**4 处全部同步改**。
- 纯重命名，**不改函数体、不改参数、不改返回值**。

### 验收
- `grep -rn "_fallback_candidates_by_role" app/ tests/` 应**无任何残留**（只允许出现新名字 `fallback_candidates_by_role`）。
- `./.venv/bin/python -m pytest tests/test_build_api.py tests/test_build_template_matching.py -q` 全绿。

---

## 任务 3：`rules_fallback_response` 组合剪枝

### 背景
`app/builds/service.py:255` 用 `product(*candidate_groups)` 暴力枚举所有角色组合。每角色上限 8（`FALLBACK_MAX_CANDIDATES_PER_ROLE`），6 角色 = `8^6 ≈ 26 万`组合，每组还跑一次 `evaluate_compatibility`。正常请求不炸，但数据变多 / 恶意请求会吃 CPU。

### ⚠️ 正确性陷阱（务必遵守）
**不能简单贪心只保留每角色 top-1**，否则可能剪掉**唯一兼容解**：比如贪心选了最贵 CPU，挤掉了能配它的主板预算，导致无解；但换个稍便宜 CPU 其实有解。

### 具体做法（二选一，优先方案 A）
**方案 A（推荐，改动小、保留搭配空间）：**
- 在 `_fallback_candidates_by_role`（任务 2 后叫 `fallback_candidates_by_role`）里，把每角色的 `FALLBACK_MAX_CANDIDATES_PER_ROLE` 从 8 降到 **4**（按现有 perf/价格排序后取 top-4）。`4^6 = 4096`，组合数降 64 倍，仍保留每角色多个搭配选项，不会剪掉兼容解。
- 在 `product` 枚举循环里，**先算 total、超预算就 `continue`**（这段 `service.py:260-262` 已有，确认在兼容性检查之前即可），把昂贵的 `evaluate_compatibility` 放在预算过滤之后。
- 加一个**枚举总数硬上限**做兜底（例如最多评估 `5000` 个组合，超过就 break），并在 `explanation` 里**不暴露**该细节，但用 `# 防御性上限` 注释说明。

**方案 B（更彻底，但改动大，非必须）：** 按预算分层 + 每角色分价位段取候选。**除非方案 A 不够，否则不做 B。**

### 验收
- `./.venv/bin/python -m pytest tests/test_build_api.py -q` 全绿。
- 现有兜底相关测试结果**不退化**（原本能出方案的请求仍能出方案）。如果有测试断言了具体选型，确认降到 top-4 后仍命中；若因候选变少而断言失败，说明测试依赖了第 5+ 个候选，需与人确认而非强行改测试。

---

## 任务 4：生产环境默认密钥 fail-fast

### 背景
`app/core/config.py:18` 的 `auth_token_secret` 默认 `"dev-only-change-me"`。`/health` 已会标记 `default` 并阻断 production-ready（非裸奔），但应用仍能用弱密钥**启动并签发 token**。开发环境用默认密钥是正常的，**只在生产环境**要硬失败。

### 具体做法
1. 在 `app/core/config.py` 的 `Settings` 加一个字段：
   ```python
   app_env: str = "development"   # env: APP_ENV
   ```
   （注意现有 `env_prefix="APP_"`，所以环境变量名是 `APP_APP_ENV`；若希望就是 `APP_ENV`，给该字段单独设 alias `validation_alias="APP_ENV"` 并确认不被 prefix 影响——实现时验证一下实际读取的变量名，以最终能用 `APP_ENV=production` 生效为准。）
2. 在 `app/main.py` 的 `create_app(settings)` **开头**加启动校验：
   ```python
   if settings.app_env == "production" and settings.auth_token_secret == "dev-only-change-me":
       raise RuntimeError("APP_ENV=production 下禁止使用默认 auth_token_secret，请配置生产密钥后再启动。")
   ```
   - 放在 `create_app` 最前面，**fail-fast，进程直接起不来**。
   - 开发 / 测试环境（`app_env != "production"`）不受影响，照常启动。

### 验收
- 新增测试：`app_env="production"` + 默认密钥 → `create_app` 抛 `RuntimeError`；`app_env="production"` + 自定义强密钥 → 正常创建；`app_env="development"` + 默认密钥 → 正常创建。
- `./.venv/bin/python -m pytest -q` 全绿。
- 确认现有所有测试构造 `Settings` 时没有意外带上 `app_env=production`，否则会集体报错——若有，给测试显式传开发态或强密钥。

---

## 任务 5（可选，低优先）：`/health` 的 session factory 挪到 `app.state`

### 背景澄清
Codex 复核正确：`app/db.py:26` 的 `create_session_factory` 已有 `@lru_cache(maxsize=8)`，同一 DB URL 会复用 engine，**不存在"每次新建 engine 泄漏连接池"**。所以这不是 bug，**仅为代码整洁的可选项**。

### 做法（想做再做）
- 在 `create_app` 里把 session factory 存到 `app.state.session_factory`，`/health` 从 `app.state` 取，而非每次调 `create_session_factory(settings)`。
- 不做也完全可以，不影响正确性。

### 验收
- 若改，`tests/test_health.py` 全绿即可。

---

## 任务 6：更新过时的 `CLAUDE.md`

### 背景
`CLAUDE.md:7` 仍写 "Backend work has not been started yet"，但后端已基本完成并部署（160 测试通过，PM2 `new-site`，端口 8790）。这会误导后续协作的 agent / 人。

### 做法
- 把"Current Tech Stack"和"Project Overview"里关于"无后端 / 后端未开始"的描述，更新为：**后端已实现，技术栈 FastAPI + PostgreSQL，部署为 PM2 应用 `new-site`（端口 8790）**，并指向 `docs/后端开发完成总结-2026-06-16.md` 作为权威进度。
- 补一句后端核心目录结构指引：`backend/app/{api,auth,builds,catalog,compat,community,review,upgrade,perf,guide,core}`。
- 保留前端相关章节不动。
- **不要**删除原有的前端构建/验证说明。

### 验收
- 人工通读 `CLAUDE.md`，无"后端未开始"类过时表述。

---

## 提交建议
- 每个任务**独立 commit**，信息清晰（例：`auth: 改用标准 JWT 并兼容旧 token`）。
- 任务 1、4 涉及测试要**新增用例**，不要只改实现。
- 全部完成后跑一次完整 `./.venv/bin/python -m pytest -q`，附最终通过数，应 ≥ 160 + 新增用例数。
- 不要碰 `docs/后端开发完成总结-2026-06-16.md` 里列的「需要人工提供」的密钥/数据项——那些不是代码任务。
