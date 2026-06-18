from html import escape

from fastapi import APIRouter
from fastapi.responses import HTMLResponse, RedirectResponse

from app.progress import ProgressDashboard, load_progress


STATUS_LABELS = {
    "completed": "已完成",
    "in_progress": "进行中",
    "not_started": "未开始",
}


def create_progress_router() -> APIRouter:
    router = APIRouter()

    @router.get("/", include_in_schema=False)
    def root() -> RedirectResponse:
        return RedirectResponse("/progress")

    @router.get("/progress", response_class=HTMLResponse, include_in_schema=False)
    def progress_dashboard() -> str:
        return render_progress_dashboard(load_progress())

    return router


def render_progress_dashboard(progress: ProgressDashboard) -> str:
    phases = "".join(_render_phase(phase) for phase in progress.phases)
    user_actions = _render_user_actions(progress)
    percentage = progress.completion_percentage

    return f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{escape(progress.project)} · 开发进度</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f4f7fb;
      --card: #ffffff;
      --ink: #172033;
      --muted: #667085;
      --line: #e4e9f2;
      --primary: #2563eb;
      --primary-soft: #eaf1ff;
      --success: #138a5b;
      --success-soft: #e8f7f0;
      --warning: #b76e00;
      --warning-soft: #fff4dc;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      color: var(--ink);
      background:
        radial-gradient(circle at top right, #e7efff 0, transparent 32rem),
        var(--bg);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    main {{ width: min(1080px, calc(100% - 32px)); margin: 0 auto; padding: 52px 0 72px; }}
    .eyebrow {{ color: var(--primary); font-size: 13px; font-weight: 750; letter-spacing: .12em; }}
    h1 {{ margin: 10px 0 8px; font-size: clamp(30px, 6vw, 50px); letter-spacing: -.04em; }}
    .subtitle {{ margin: 0; color: var(--muted); font-size: 16px; }}
    .summary {{
      display: grid;
      grid-template-columns: 1.4fr repeat(4, 1fr);
      gap: 14px;
      margin: 30px 0 36px;
    }}
    .summary-card, .phase, .user-actions {{
      background: color-mix(in srgb, var(--card) 94%, transparent);
      border: 1px solid var(--line);
      border-radius: 20px;
      box-shadow: 0 16px 40px rgba(23, 32, 51, .06);
    }}
    .summary-card {{ min-height: 128px; padding: 22px; }}
    .summary-card strong {{ display: block; margin-top: 10px; font-size: 26px; letter-spacing: -.03em; }}
    .label {{ color: var(--muted); font-size: 13px; font-weight: 650; }}
    .meter {{ height: 9px; margin-top: 18px; overflow: hidden; border-radius: 99px; background: #e8edf5; }}
    .meter span {{ display: block; width: {percentage}%; height: 100%; border-radius: inherit; background: var(--primary); }}
    .user-actions {{ margin: -12px 0 36px; padding: 24px; border-color: #f1d39a; background: #fffaf0; }}
    .user-actions h2 {{ margin: 0 0 6px; font-size: 20px; }}
    .user-actions > p {{ margin: 0 0 16px; color: var(--muted); line-height: 1.6; }}
    .phases {{ display: grid; gap: 18px; }}
    .phase {{ padding: 24px; }}
    .phase-header {{ display: flex; justify-content: space-between; gap: 20px; margin-bottom: 18px; }}
    .phase h2 {{ margin: 0 0 6px; font-size: 20px; }}
    .phase p {{ margin: 0; color: var(--muted); line-height: 1.6; }}
    .items {{ display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }}
    .item {{ padding: 17px; border: 1px solid var(--line); border-radius: 15px; background: #fbfcfe; }}
    .item-top {{ display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 7px; }}
    .item h3 {{ margin: 0; font-size: 15px; line-height: 1.45; }}
    .item p {{ font-size: 13px; }}
    .status {{ flex: none; border-radius: 99px; padding: 5px 9px; font-size: 11px; font-weight: 750; }}
    .completed {{ color: var(--success); background: var(--success-soft); }}
    .in_progress {{ color: var(--warning); background: var(--warning-soft); }}
    .not_started {{ color: var(--muted); background: #eef1f6; }}
    .date {{ display: block; margin-top: 10px; color: var(--success); font-size: 11px; font-weight: 650; }}
    footer {{ margin-top: 28px; color: var(--muted); font-size: 12px; text-align: center; }}
    @media (max-width: 820px) {{
      main {{ padding-top: 32px; }}
      .summary {{ grid-template-columns: repeat(2, 1fr); }}
      .summary-card:first-child {{ grid-column: 1 / -1; }}
      .items {{ grid-template-columns: 1fr; }}
    }}
    @media (max-width: 520px) {{
      .summary {{ grid-template-columns: 1fr; }}
      .summary-card:first-child {{ grid-column: auto; }}
      .phase, .summary-card {{ border-radius: 16px; }}
    }}
  </style>
</head>
<body>
  <main>
    <header>
      <div class="eyebrow">BACKEND ROADMAP</div>
      <h1>{escape(progress.project)}</h1>
      <p class="subtitle">只展示未完成和待精进事项；已完成任务从页面隐藏，历史仍保留在 progress.json。</p>
    </header>
    <section class="summary" aria-label="项目摘要">
      <div class="summary-card">
        <span class="label">总体完成度</span>
        <strong>{percentage}%</strong>
        <div class="meter" aria-label="总体完成度 {percentage}%"><span></span></div>
      </div>
      <div class="summary-card"><span class="label">当前阶段</span><strong>{escape(progress.current_phase)}</strong></div>
      <div class="summary-card"><span class="label">已完成</span><strong>{progress.completed_items} / {progress.total_items}</strong></div>
      <div class="summary-card"><span class="label">最近更新</span><strong>{escape(progress.updated_at)}</strong></div>
      <div class="summary-card"><span class="label">预计完成时间</span><strong>{escape(progress.estimated_completion)}</strong></div>
    </section>
    {user_actions}
    <section class="phases" aria-label="开发阶段">{phases}</section>
    <footer>状态来源：项目内 progress.json · 页面只展示，不接受外部修改</footer>
  </main>
</body>
</html>"""


def _render_user_actions(progress: ProgressDashboard) -> str:
    if not progress.user_action_items:
        return ""

    items = "".join(_render_item(item) for item in progress.user_action_items)
    return f"""
    <section class="user-actions" aria-label="需要你完成">
      <h2>需要你完成</h2>
      <p>下面这些不是后端代码缺口，不计入预计完成时间；它们需要你提供资料、密钥、人工确认数据或服务器安全策略。</p>
      <div class="items">{items}</div>
    </section>"""


def _render_phase(phase) -> str:
    open_items = [item for item in phase.items if item.status != "completed"]
    if not open_items:
        return ""

    items = "".join(_render_item(item) for item in open_items)
    return f"""
    <article class="phase">
      <div class="phase-header">
        <div><h2>{escape(phase.name)}</h2><p>{escape(phase.description)}</p></div>
        <span class="label">{len(open_items)} 项待处理</span>
      </div>
      <div class="items">{items}</div>
    </article>"""


def _render_item(item) -> str:
    completed_at = (
        f'<span class="date">完成于 {escape(item.completed_at)}</span>'
        if item.completed_at
        else ""
    )
    return f"""
    <div class="item">
      <div class="item-top">
        <h3>{escape(item.title)}</h3>
        <span class="status {item.status}">{STATUS_LABELS[item.status]}</span>
      </div>
      <p>{escape(item.description)}</p>
      {completed_at}
    </div>"""
