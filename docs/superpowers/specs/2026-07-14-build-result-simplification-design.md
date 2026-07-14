# 配置结果页精简设计

## 目标

配置结果页只保留方案摘要、八大件清单和“保存配置单”。删除方案分析、风险提示、复制文本、分享图片、重新生成和继续优化。后端不再为 AI 装机结果生成、保存或返回方案优缺点与风险文案。

## 范围

- `BuildResultView` 删除“方案分析”“风险提示”和四个次级按钮。
- `BuildPlan` 删除 `advantages`、`disadvantages`、`risks`，AI 结果映射不再构造这些数据。
- `BuildTemplateDetails` 删除 `advantages`、`disadvantages`、`risks`。
- `BuildOptionResponse` 不再返回 `compatibility`。
- 高低预算模板生成器不再生成分析/风险字段，Markdown 报告不再渲染这些段落。
- 重新生成 63 套低预算模板和 234 套高预算模板并导入生产数据库。

## 保留能力

- 后端继续运行 `evaluate_compatibility`，用于候选过滤、模板导入校验和独立兼容性接口。
- `/v1/compat`、配置排雷、升级建议与其他独立工具不变。
- 旧 `/v1/build/generate` 的兼容性响应保持不变，避免破坏现有调用方；本次只精简当前 App 使用的 `/v1/build/options` 契约。
- “保存配置单”按钮和配件清单保留。

## 数据迁移

模板 JSON 由现有确定性生成器重写。生产环境重新导入两份模板文件后，`BuildTemplate.details` 会被不含旧字段的新结构覆盖，不需要新增数据库迁移。

## 验证

- 后端模型拒绝依赖已删除字段，`/v1/build/options` 响应不包含分析、风险和兼容性详情。
- 297 套模板继续保持八大件、采购状态、价格、方向与兼容性校验完整。
- iOS DTO 可以解码精简响应，结果页只显示摘要、配件和保存按钮。
- 后端全量测试、iOS Debug/Release 构建和生产接口抽样通过。
