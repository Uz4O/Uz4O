# PC-Builds FPS 数据采集与 App 接入设计

日期：2026-07-12

## 目标

为游戏性能测试功能建立受控的 FPS 估算数据库，覆盖 App 当前目录中的 101 个 CPU、77 个显卡和 15 款游戏。用户选择 CPU、显卡、游戏和分辨率后，App 返回中等画质下的平均、最低和最高 FPS，以及瓶颈信息。

成功标准：

- App 当前 CPU、显卡和目标游戏都有明确的 PC-Builds 映射状态。
- 精确匹配的组合可以离线、低速、可断点地采集。
- 1080P、2K、4K结果经过校验后才能导入正式后端。
- App 只调用自己的后端，不在运行时访问 PC-Builds。
- 没有精确数据时明确显示暂不支持，不使用相近型号替代，也不生成看似精确的虚假数值。

## 权限边界

PC-Builds 将结果描述为基于基准分数和 FPS 记录生成的估算值，不是每个硬件组合的直接跑机实测。

公开页面可访问不等于允许将整套数据库复制进商业 App。采集结果在取得站方书面授权前只用于内部验证。正式发布时的数据使用范围、署名和链接方式必须遵守授权条件。

采集程序不得绕过访问限制：

- 不使用代理池、验证码绕过或身份伪装。
- 遇到 403、429、验证码或其他明确限制时暂停全部任务。
- 遵守 `Retry-After`。
- 不访问登录、账号或其他非公开区域。

## 数据范围

### 游戏

“什么都玩”是聚合入口，不是采集目标。实际采集以下 15 款游戏：

| App 名称 | PC-Builds 名称 |
| --- | --- |
| 瓦罗兰特 | Valorant |
| CS2 | Counter-Strike 2 |
| PUBG | PUBG: Battlegrounds |
| 三角洲行动 | Delta Force |
| 云顶之弈 | Teamfight Tactics |
| LOL | League of Legends |
| COD | Call of Duty: Warzone |
| 赛博朋克2077 | Cyberpunk 2077 |
| 荒野大镖客2 | Red Dead Redemption 2 |
| GTA5 | Grand Theft Auto V |
| 黑神话悟空 | Black Myth: Wukong |
| 地平线6 | Forza Horizon 6 |
| 艾尔登法环 | Elden Ring |
| 城市天际线 | Cities: Skylines |
| 我的世界 | Minecraft: Java Edition |

### CPU

以 `May/May/Models/HardwareCatalog.swift` 当前 101 个 CPU 为唯一范围：

- Intel 第 10 至第 14 代酷睿。
- Intel 第 15 代 Core Ultra。
- AMD Ryzen 5000、7000、9000 系列。

只匹配 PC-Builds 的 Desktop 型号，不匹配同名 Mobile 型号。

### 显卡

以 `May/May/Models/HardwareCatalog.swift` 当前 77 个显卡为唯一范围：

- NVIDIA GTX 10、16 和 RTX 20、30、40、50 系列。
- AMD RX 5000、6000、7000、9000 系列。

显存容量、Ti、Super、GRE、D、D V2 等后缀必须精确匹配。

### 结果维度

- 分辨率：1920×1080、2560×1440、3840×2160。
- 画质：中等。
- 指标：平均 FPS、最低 FPS、最高 FPS、瓶颈类型、瓶颈比例。
- 审计字段：来源页面、采集时间、导入批次。

若全部型号均可精确匹配，目标任务数为 `101 × 77 × 15 = 116,655` 个结果页；每页解析三个分辨率，最多产生 349,965 条 FPS 记录。

## 架构

```text
App 硬件目录
    ↓
型号与游戏映射文件
    ↓
采集任务生成器
    ↓
低速单进程采集器
    ↓
SQLite 暂存与断点续传
    ↓
校验和审核导出器
    ↓
后端 FPS 正式表
    ↓
/v1/perf/estimate
    ↓
iOS 游戏性能结果页
```

采集器是离线维护工具，不部署到 iPhone，也不参与正式 API 请求链路。

## 映射规则

CPU、显卡和游戏映射文件进入版本控制。每条映射包含 App ID、App 名称、PC-Builds ID、slug、设备类型和状态。

映射状态：

- `exact`：桌面型号和关键后缀完全一致，可以生成任务。
- `review`：名称相近，但显存、地区版本或后缀存在歧义，需要人工确认。
- `missing`：PC-Builds 没有该型号或游戏。

只有 `exact` 可以生成采集任务。`review` 和 `missing` 必须进入覆盖率报告，不得自动回退到相近型号。

## 采集流程

结果页结构：

```text
/zh/fps-calculator/result/{CPU_ID}{GPU_ID}{GAME_ID}/{cpu}/{gpu}/{game}/{resolution}/
```

采集器默认使用单进程，每次请求间隔 2 秒，并加入少量随机间隔。任务从映射文件确定性生成，写入 SQLite 后再开始请求。

任务状态：

```text
pending → fetching → succeeded
                   ↘ retryable → fetching
                   ↘ missing
                   ↘ parse_failed
                   ↘ blocked
```

处理规则：

- 普通网络错误最多重试 3 次，并逐步延长等待时间。
- 404 标记为 `missing`，等待映射复核。
- 403、429、验证码或访问限制标记为 `blocked`，并暂停全部任务。
- 连续 3 个页面解析失败时暂停全部任务，防止页面改版后继续写入错误数据。
- 成功页面保存解析结果、来源地址、采集时间和响应摘要。
- 只有解析失败的页面保存压缩 HTML；另外保存一个人工确认的成功页面作为解析器测试样本。

## 暂存与正式数据

SQLite 暂存库保存任务、尝试次数、错误、页面元数据和解析结果。重复启动采集器时，从未完成任务继续，不重新请求成功页面。

后端正式表一行代表一个硬件组合在一款游戏、一个分辨率和一个画质下的结果：

```text
cpu_id
gpu_id
game_id
resolution
quality
average_fps
minimum_fps
maximum_fps
bottleneck_type
bottleneck_percent
source_url
source_fetched_at
import_batch
```

唯一约束是 CPU、GPU、游戏、分辨率和画质。导入采用 upsert，同一批数据重复导入不会产生重复行。

## 数据校验

记录必须满足：

- `minimum_fps ≤ average_fps ≤ maximum_fps`。
- 三个 FPS 都是正数且不超过配置的合理上限。
- 成功页面包含 1080P、2K、4K 三档中等画质结果。
- CPU、GPU、游戏 ID 与来源页面一致。
- 同一任务不得产生重复分辨率。

不通过校验的记录留在暂存库并标记失败，不能进入正式表。导入前生成覆盖率、缺失映射、采集失败和异常值报告。

## 后端接口行为

保留现有 `/v1/perf/estimate` 路径，内部从公式估算改为精确记录查询。

- 单款游戏命中：返回平均、最低、最高 FPS、瓶颈和采集时间。
- 单款游戏未命中：返回该组合暂时没有可靠数据。
- 多款游戏部分命中：返回已有结果和缺失游戏列表。
- “什么都玩”：查询 15 款游戏，返回整体平均、最好、最差和缺失数量。

现有固定游戏权重公式不再作为精确 FPS 回退。接口响应需要支持 `ready`、`partial` 和 `needs_more_data`。

## iOS 展示

结果页显示：

- 当前分辨率的平均、最低和最高 FPS。
- 流畅度评价。
- CPU 或 GPU 瓶颈及比例。
- 多选游戏的逐款结果。
- 数据更新时间。

固定说明：

> 结果为中等画质下的性能估算，实际表现会受驱动、散热、内存、游戏版本和画质设置影响。

正式发布是否显示 PC-Builds 名称或链接，以书面授权条件为准。

## 测试与验收

- 用 Ryzen 5 5600、RTX 4060、Cyberpunk 2077 的确认页面建立解析器样本测试。
- 验证全部 App CPU、显卡和 15 款游戏都有映射状态。
- 验证只有 `exact` 映射会生成任务，任务数量可重复计算。
- 验证断点续传、三次重试、全局暂停和重复运行。
- 验证异常 FPS、缺失分辨率和 ID 不一致不能导入。
- 验证重复导入不会产生重复记录。
- 后端测试覆盖精确命中、部分缺失、完全缺失和“什么都玩”。
- iOS 规则测试覆盖结果展示、部分缺失和无数据提示。
- 最后运行完整后端测试和 iPhone 17 模拟器构建。

## 非目标

- 不采集低、高、极高画质。
- 不采集 1080P、2K、4K 以外的分辨率。
- 不推算或补齐 PC-Builds 不支持的型号。
- 不在 App 查询时实时访问第三方网站。
- 不在未取得授权时将采集数据用于正式商业发布。
