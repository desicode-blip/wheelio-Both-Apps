"""Render the committed Markdown handoff with ReportLab; no app/runtime changes."""
from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Flowable, PageBreak, Paragraph, SimpleDocTemplate,
    Spacer, Table, TableStyle, XPreformatted,
)

ROOT = Path(__file__).resolve().parents[2]
BLUE = colors.HexColor("#0049FF")
INK = colors.HexColor("#22282D")
MUTED = colors.HexColor("#566572")
PALE = colors.HexColor("#F0F5FF")


def register_fonts():
    choices = [
        (ROOT / "apps/flutter/packages/washkrew_ui/lib/fonts/Roboto-Regular.ttf", ROOT / "apps/flutter/packages/washkrew_ui/lib/fonts/Roboto-Bold.ttf"),
        (Path("C:/Windows/Fonts/arial.ttf"), Path("C:/Windows/Fonts/arialbd.ttf")),
        (Path("/Library/Fonts/Arial.ttf"), Path("/Library/Fonts/Arial Bold.ttf")),
        (Path("/System/Library/Fonts/Supplemental/Arial.ttf"), Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")),
        (Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"), Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")),
    ]
    for regular, bold in choices:
        if regular.exists() and bold.exists():
            pdfmetrics.registerFont(TTFont("Handoff", str(regular)))
            pdfmetrics.registerFont(TTFont("Handoff-Bold", str(bold)))
            pdfmetrics.registerFontFamily("Handoff", normal="Handoff", bold="Handoff-Bold", italic="Handoff", boldItalic="Handoff-Bold")
            return "Handoff", "Handoff-Bold"
    return "Helvetica", "Helvetica-Bold"


def inline(text, code_font="Courier"):
    escaped = html.escape(text)
    escaped = re.sub(r"\[([^\]]+)\]\((https?://[^\s)]+)\)", lambda match: f'<link href="{match.group(2)}" color="#0049FF"><u>{match.group(1)}</u></link>', escaped)
    escaped = re.sub(r"`([^`]+)`", lambda match: f'<font name="{code_font}" size="8.8">{match.group(1)}</font>', escaped)
    return re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)


class Rule(Flowable):
    def __init__(self, width):
        super().__init__()
        self.width, self.height = width, 9

    def draw(self):
        self.canv.setStrokeColor(BLUE)
        self.canv.setLineWidth(2)
        self.canv.line(0, 5, self.width, 5)


def render(source, target, *, title="WashKrew - Mac and iPhone continuation report", header="WASHKREW  /  ENGINEERING HANDOFF", footer="27 October 2026  |  staging  |  Test mode", subject="Remaining implementation, device acceptance, training placeholders and separate Razorpay merchant migration"):
    regular, bold = register_fonts()
    code_font = "Courier"
    for font_path in [Path("C:/Windows/Fonts/consola.ttf"), Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf")]:
        if font_path.exists():
            pdfmetrics.registerFont(TTFont("Handoff-Code", str(font_path)))
            code_font = "Handoff-Code"
            break
    width = A4[0] - 88
    styles = {
        "title": ParagraphStyle("title", fontName=bold, fontSize=30, leading=34, textColor=BLUE, spaceAfter=10),
        "heading": ParagraphStyle("heading", fontName=bold, fontSize=18, leading=23, textColor=INK, spaceAfter=11),
        "sub": ParagraphStyle("sub", fontName=bold, fontSize=10.6, leading=14, textColor=INK, spaceBefore=8, spaceAfter=5, keepWithNext=True),
        "body": ParagraphStyle("body", fontName=regular, fontSize=9.6, leading=13.6, textColor=INK, spaceAfter=8, splitLongWords=True),
        "cell": ParagraphStyle("cell", fontName=regular, fontSize=8.7, leading=11.8, textColor=INK, splitLongWords=True),
        "headcell": ParagraphStyle("headcell", fontName=bold, fontSize=8.7, leading=11.8, textColor=colors.white),
        "code": ParagraphStyle("code", fontName=code_font, fontSize=9, leading=12.5, textColor=INK, borderColor=colors.HexColor("#D8E3F8"), borderWidth=0.6, borderPadding=8, backColor=PALE, spaceBefore=5, spaceAfter=10),
        "bullet": ParagraphStyle("bullet", fontName=regular, fontSize=9.6, leading=13.6, textColor=INK, leftIndent=14, firstLineIndent=-14, spaceAfter=6),
    }

    def p(text, kind="body"):
        return Paragraph(inline(text, code_font), styles[kind])

    story = []
    pages = source.read_text(encoding="utf-8").split("<!-- pagebreak -->")
    for page_index, page in enumerate(pages):
        if page_index:
            story.append(PageBreak())
        lines = page.strip().splitlines()
        index = 0
        while index < len(lines):
            line = lines[index].strip()
            if not line:
                index += 1
                continue
            if line.startswith("```"):
                block = []
                index += 1
                while index < len(lines) and not lines[index].startswith("```"):
                    block.append(lines[index])
                    index += 1
                story.append(XPreformatted(html.escape("\n".join(block)), styles["code"]))
            elif line.startswith("|"):
                rows = []
                while index < len(lines) and lines[index].strip().startswith("|"):
                    cells = [value.strip() for value in lines[index].strip().strip("|").split("|")]
                    if not all(re.fullmatch(r":?-+:?", cell) for cell in cells):
                        rows.append([p(cell, "headcell" if not rows else "cell") for cell in cells])
                    index += 1
                table = Table(rows, colWidths=[width * .275, width * .725], repeatRows=1, hAlign="LEFT")
                table.setStyle(TableStyle([
                    ("BACKGROUND", (0, 0), (-1, 0), BLUE),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PALE]),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 8),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                    ("TOPPADDING", (0, 0), (-1, -1), 7),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
                    ("LINEBELOW", (0, -1), (-1, -1), .5, colors.HexColor("#D8E3F8")),
                ]))
                story.extend([table, Spacer(1, 10)])
                continue
            elif line.startswith("### "):
                story.append(p(line[4:], "sub"))
            elif line.startswith("## "):
                story.append(p(line[3:], "heading"))
                story.append(Rule(width))
            elif line.startswith("# "):
                story.append(p(line[2:], "title"))
            elif re.match(r"^\d+\. ", line):
                paragraph = [line]
                while index + 1 < len(lines) and lines[index + 1].strip() and not re.match(r"^(#|\||```|\d+\. )", lines[index + 1].strip()):
                    index += 1
                    paragraph.append(lines[index].strip())
                story.append(p(" ".join(paragraph), "bullet"))
            else:
                paragraph = [line]
                while index + 1 < len(lines) and lines[index + 1].strip() and not re.match(r"^(#|\||```|\d+\. )", lines[index + 1].strip()):
                    index += 1
                    paragraph.append(lines[index].strip())
                story.append(p(" ".join(paragraph)))
            index += 1

    def decorate(canvas, doc):
        canvas.saveState()
        canvas.setFont(bold, 8.4)
        canvas.setFillColor(BLUE)
        canvas.drawString(44, A4[1] - 28, header)
        canvas.setStrokeColor(colors.HexColor("#DCE4EF"))
        canvas.setLineWidth(.5)
        canvas.line(44, 35, A4[0] - 44, 35)
        canvas.setFillColor(MUTED)
        canvas.setFont(regular, 8)
        canvas.drawString(44, 22, footer)
        canvas.drawRightString(A4[0] - 44, 22, f"Page {doc.page}")
        canvas.restoreState()

    target.parent.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(str(target), pagesize=A4, rightMargin=44, leftMargin=44, topMargin=48, bottomMargin=48, title=title, author="WashKrew project handoff", subject=subject, pageCompression=1)
    document.build(story, onFirstPage=decorate, onLaterPages=decorate)
    print(target)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=ROOT / "docs/CLAUDE-MAC-CONTINUATION-2026-10-27.md")
    parser.add_argument("--output", type=Path, default=ROOT / "output/pdf/WashKrew-Mac-Continuation-Report-2026-10-27.pdf")
    parser.add_argument("--title", default="WashKrew - Mac and iPhone continuation report")
    parser.add_argument("--header", default="WASHKREW  /  ENGINEERING HANDOFF")
    parser.add_argument("--footer", default="27 October 2026  |  staging  |  Test mode")
    parser.add_argument("--subject", default="Remaining implementation, device acceptance, training placeholders and separate Razorpay merchant migration")
    args = parser.parse_args()
    render(args.source, args.output, title=args.title, header=args.header, footer=args.footer, subject=args.subject)
