# Hardware Price Crawler

本工具用于每周人工监督采集京东 CPU、显卡和主板搜索结果，并生成供 AI 装机使用的参考价格复核文件。

它完全独立于 SwiftUI 前端，不会修改 `May/`，也不会自动把价格发布到 App。

## 工作方式

```text
现有 HardwareCatalog.swift
→ 导出硬件清单
→ 可见 Edge 浏览器逐个搜索京东
→ 保存原始商品 CSV
→ 自动排除明显错误商品
→ 计算价格中位数
→ 人工检查异常清单
```

工具不会绕过登录或验证码。遇到京东验证时，在打开的浏览器中手动处理，再回到终端继续。

## 安装

```bash
cd /Users/may/Documents/AI装机/tools/hardware-price-crawler
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

默认使用电脑上已安装的 Microsoft Edge。若要改用 Playwright Chromium：

```bash
python3 -m playwright install chromium
```

运行采集时增加 `--channel chromium`。

## 第一次运行

### 1. 导出硬件清单

```bash
python3 run.py catalog
```

生成 `data/hardware.csv`。当前项目的主板型号较多，第一次建议打开 CSV，保留近期值得推荐的型号，再开始采集。

### 2. 小批量试采集

```bash
python3 run.py crawl --category gpu --limit 3 --delay 5
```

浏览器打开后，手动登录京东并按终端提示继续。工具每完成一个型号就会更新 `raw-products.csv`。

### 3. 生成参考价和复核清单

将上一步输出的路径传给：

```bash
python3 run.py build-prices --raw data/runs/运行时间/raw-products.csv
```

输出：

- `reference-prices.csv`：按可信商品中位数计算的参考价格。
- `review-required.csv`：样本不足、价格变化超过 20%、无可信商品以及被排除商品。

确认一轮价格后，可以手动将确认过的 `reference-prices.csv` 保存为：

```text
data/approved-reference-prices.csv
```

下一次运行会以它作为价格变化比较基准。工具不会自动执行这一步。

## 每周建议流程

1. 先用 `--limit 3` 验证京东页面结构仍然可读取。
2. 分类别运行，避免一次执行时间过长。
3. 保留至少 5 秒搜索间隔。
4. 查看 `review-required.csv`，重点检查无结果、样本不足和价格变化超过 20% 的型号。
5. 只在人工确认后更新 `approved-reference-prices.csv`。

## 测试

```bash
python3 -m unittest discover -s tests -v
```

测试不访问京东，也不需要 Playwright。

