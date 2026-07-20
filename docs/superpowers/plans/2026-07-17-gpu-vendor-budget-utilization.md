# 显卡厂商与预算利用率优化实施计划

## 验收标准

- 每套可返回配置满足 `目标预算 <= 总价 <= 目标预算 + 300`。
- RTX 4060 全新参考价为 2100 元；RTX 4060 Ti 仅允许二手。
- 5000 元以下和 FPS 方向不增加光追分支，默认只返回每种采购方式的最优方案。
- 5000 元及以上的 3A/均衡方向：开光追只返回 NVIDIA；不开光追返回每种采购方式的 NVIDIA 与 AMD 方案；未传偏好时保持 NVIDIA 优先。
- 每套模板包含八大件、准确分项价、新旧状态和 `gpu_vendor`。
- 全量后端测试通过后才更新完成状态，不执行生产部署。

## 任务 1：固定规则与数据结构

**修改：**

- `backend/app/builds/service.py`
- `backend/data/gpu-whitelist-prices-2026-07-07.csv`
- `docs/gpu-whitelist-tier-2026-07-07.md`
- `/Users/may/.codex/skills/china-pc-build-advisor/SKILL.md`
- `/Users/may/.codex/skills/china-pc-build-advisor/REFERENCE.md`

1. 给 `BuildTemplateDetails` 增加 `gpu_vendor: nvidia | amd`。
2. 给 `BuildRequest` 增加可选光追偏好，兼容 camelCase 与 snake_case。
3. 更新 RTX 4060 与 RTX 4060 Ti 的全新/二手资格和说明。
4. 把预算下限、厂商矩阵和预算补齐顺序写入 Skill。

## 任务 2：先写生成器回归测试

**修改：**

- `backend/tests/test_low_budget_base_builds.py`
- `backend/tests/test_high_budget_base_builds.py`
- `backend/tests/test_high_budget_base_import.py`

1. 将预算断言改为 `[预算, 预算+300]`。
2. 验证 5000 元以上 3A/均衡在三种采购方式下都有 N/A 两个厂商方案。
3. 验证 RTX 4060 可用于全新模板、RTX 4060 Ti 不可用于全新模板且仍可用于二手模板。
4. 更新模板唯一键与预期数量，避免同采购方式的 N/A 方案互相覆盖。

## 任务 3：扩展高低预算模板生成器

**修改：**

- `backend/app/builds/low_budget_catalog.py`
- `backend/app/builds/high_budget_catalog.py`
- 必要时仅补充 `backend/data/base-build-support-components-2026-07-12.json` 中有实际收益的容量档位。

1. 对 5000 元以上 3A/均衡按 `nvidia`、`amd` 分别选候选；其他组合保留单个最优候选。
2. 使用厂商感知的模板 ID、标签和详情字段。
3. 候选总价低于预算时，按方向尝试有实际收益的内存、SSD、CPU、显卡或电源升级。
4. 无法进入预算区间的组合记为不可用，不使用主板、散热或外观件硬凑预算。
5. 高预算基底的主板价格不得超过目标预算的 15%，避免用旗舰主板填满游戏整机预算。

## 任务 4：扩展 API 选择逻辑

**修改：**

- `backend/app/api/builds.py`
- `backend/tests/test_build_api.py`

1. 开光追时，每种采购方式只选 NVIDIA。
2. 不开光追时，每种采购方式按 NVIDIA、AMD 顺序各选一套。
3. 未传光追偏好、5000 元以下或 FPS 方向时，每种采购方式只返回默认最优方案。
4. 继续跳过不兼容或结构不完整模板，并准确返回不可用采购方式。

## 任务 5：生成制品与验证

**重新生成：**

- `backend/data/low-budget-base-*`
- `backend/data/high-budget-base-*`
- `docs/3000-7000-yuan-base-builds.md`
- `docs/7500-20000-yuan-base-builds.md`

1. 运行高低预算生成器并核对审计文件。
2. 运行生成器、导入、API 和兼容性测试。
3. 运行 `backend/.venv/bin/pytest` 全量测试。
4. 用实际模板数更新 `backend/progress.json` 和 `docs/agents/backend-server-context.md`。
5. 不部署服务器；部署作为验证后的单独步骤。
