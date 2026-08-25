# 风格方案批量接入

这个脚本完全本地运行，不调用 image2，并通过 `schemes.json` 增量保存已接入方案：

1. 从 JSON 读取多套方案和黑白原图。
2. 使用 OpenCV 本地抠图，输出透明 PNG。
3. 自动创建 Xcode `imageset`。
4. 自动生成风格页 Swift 数据，方案会出现在风格页、沉浸全景和方案详情中。

运行：

```bash
python3 tools/style_catalog/add_style_schemes.py /path/to/schemes.json
```

JSON 最小格式：

```json
{
  "schemes": [
    {
      "id": "cougarV235",
      "title": "骨伽凌空V235",
      "images": {
        "black": "/path/to/black.png",
        "white": "/path/to/white.png"
      },
      "parts": [
        {"name": "机箱", "detail": "骨伽凌空 V235", "price": 449},
        {"name": "风扇套装", "detail": "棱镜 8 Pro × 9", "price": 89},
        {"name": "一体式水冷", "detail": "利民 PV360", "price": 499}
      ]
    }
  ]
}
```

`summary`、`tags`、`signature`、`highDetail`、`completeDetail` 可选；不写时脚本会生成默认文案。多套方案直接放进 `schemes` 数组，脚本会并行处理图片；下次只提交新增方案，脚本不会覆盖之前的方案。

新增方案后刷新沉浸模式缩略图、透明边界数据和等高线纹理：

```bash
python3 tools/style_catalog/generate_explorer_assets.py
```

## 导出后端正式目录

风格配件或价格变动后，在项目根目录重新生成去重 SKU 和人工参考价：

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/May/Models/AIBuildFlow.swift May/May/Models/AestheticBuildFlow.swift May/May/Models/AestheticGeneratedCatalog.swift tools/style_catalog/export_backend_catalog.swift -o /tmp/export-aesthetic-catalog
/tmp/export-aesthetic-catalog backend/data/aesthetic-style-components-2026-08-24.json backend/data/aesthetic-style-reference-prices-2026-08-24.csv
```

部署时先导入硬件，再导入价格：

```bash
cd backend
.venv/bin/python -m app.cli seed-hardware data/aesthetic-style-components-2026-08-24.json
.venv/bin/python -m app.cli ingest-prices data/aesthetic-style-reference-prices-2026-08-24.csv --approved-at 2026-08-24
```
