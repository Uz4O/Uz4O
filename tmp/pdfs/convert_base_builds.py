import html
import re
from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_RIGHT
from reportlab.lib.pagesizes import A5
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import KeepTogether, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / "pdf"

def parse(path):
    title = budget = heading = ""
    rows, configs, total = [], [], None
    table = False
    def finish():
        nonlocal rows, total, heading
        if heading and rows and total is not None:
            configs.append((budget, heading, rows, total))
        rows, total, heading = [], None, ""
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("# "): title = line[2:].strip()
        elif line.startswith("## "):
            finish(); budget = line[3:].strip(); table = False
        elif line.startswith("### "):
            finish(); heading = line[4:].strip(); table = False
        elif line.startswith("| 配件 |"): table = True
        elif table and line.startswith("|"):
            cells = [x.strip() for x in line.strip("|").split("|")]
            if len(cells) >= 4 and cells[0] not in {"配件", "---"} and set(cells[0]) != {"-"}:
                rows.append(tuple(cells[:4]))
        elif line.startswith("**总价："):
            match = re.search(r"总价：¥\s*([0-9,]+)", line)
            if match: total = match.group(1)
            table = False
    finish()
    return title, configs

def p(value, style): return Paragraph(html.escape(str(value)), style)

def make(source, destination):
    title, configs = parse(source)
    styles = getSampleStyleSheet()
    body = ParagraphStyle("Body", parent=styles["BodyText"], fontName="PhoneHeiti", fontSize=8.2, leading=10.5, textColor=colors.HexColor("#20252B"))
    cell = ParagraphStyle("Cell", parent=body, fontSize=7.8, leading=9.5)
    right = ParagraphStyle("Right", parent=cell, alignment=TA_RIGHT)
    header = ParagraphStyle("Header", parent=cell, textColor=colors.white)
    title_style = ParagraphStyle("Title", parent=body, fontSize=15, leading=18, textColor=colors.HexColor("#111827"), spaceAfter=3 * mm)
    budget_style = ParagraphStyle("Budget", parent=body, fontSize=12, leading=15, textColor=colors.white)
    config_style = ParagraphStyle("Config", parent=body, fontSize=10.5, leading=13, textColor=colors.HexColor("#0F172A"))
    total_style = ParagraphStyle("Total", parent=body, fontSize=9.5, leading=12, alignment=TA_RIGHT, textColor=colors.HexColor("#0F766E"), spaceBefore=1.5 * mm, spaceAfter=3 * mm)
    doc = SimpleDocTemplate(str(destination), pagesize=A5, leftMargin=13 * mm, rightMargin=13 * mm, topMargin=12 * mm, bottomMargin=12 * mm, title=title, author="AI装机")
    story, last_budget = [p(title, title_style)], None
    for current_budget, current_heading, rows, current_total in configs:
        block = []
        if current_budget != last_budget:
            budget_band = Table([[p(current_budget, budget_style)]], colWidths=[119 * mm])
            budget_band.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#0F766E")), ("LEFTPADDING", (0, 0), (-1, -1), 8), ("RIGHTPADDING", (0, 0), (-1, -1), 8), ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6)]))
            block += [Spacer(1, 2 * mm), budget_band, Spacer(1, 1.5 * mm)]
            last_budget = current_budget
        config_band = Table([[p(current_heading.replace(" / ", " · "), config_style)]], colWidths=[119 * mm])
        config_band.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#E2E8F0")), ("LINEBEFORE", (0, 0), (0, -1), 3, colors.HexColor("#0EA5E9")), ("LEFTPADDING", (0, 0), (-1, -1), 8), ("RIGHTPADDING", (0, 0), (-1, -1), 8), ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5)]))
        block += [config_band, Spacer(1, 1.5 * mm)]
        data = [[p("配件", header), p("型号", header), p("状态", header), p("价格", header)]]
        data += [[p(role, cell), p(model, cell), p(condition, cell), p(price, right)] for role, model, condition, price in rows]
        t = Table(data, colWidths=[24 * mm, 57 * mm, 18 * mm, 20 * mm], repeatRows=1, hAlign="LEFT")
        t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#334155")), ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#CBD5E1")), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("LEFTPADDING", (0, 0), (-1, -1), 4), ("RIGHTPADDING", (0, 0), (-1, -1), 4), ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3), ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FAFC")])]))
        block += [t, p(f"总价：¥{current_total}", total_style)]
        story.append(KeepTogether(block))
    def footer(canvas, _doc):
        canvas.saveState(); canvas.setFont("PhoneHeiti", 7); canvas.setFillColor(colors.HexColor("#64748B")); canvas.drawString(13 * mm, 7 * mm, "AI装机基底配置 · 人工审查版"); canvas.drawRightString(A5[0] - 13 * mm, 7 * mm, f"第 {canvas.getPageNumber()} 页"); canvas.restoreState()
    doc.build(story, onFirstPage=footer, onLaterPages=footer)

if __name__ == "__main__":
    pdfmetrics.registerFont(TTFont("PhoneHeiti", "/System/Library/Fonts/STHeiti Medium.ttc", subfontIndex=0))
    make(ROOT / "docs/3000-7000-yuan-base-builds.md", OUT / "3000-7000-yuan-base-builds.pdf")
    make(ROOT / "docs/7500-20000-yuan-base-builds.md", OUT / "7500-20000-yuan-base-builds.pdf")
