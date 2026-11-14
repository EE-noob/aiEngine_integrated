#!/usr/bin/env python3
"""Build the editable Word and PDF deliverables from the Markdown source."""
from pathlib import Path
import subprocess
import tempfile

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "脉动阵列吞吐量与TileCache瓶颈分析.md"
DOCX = SOURCE.with_suffix(".docx")
PDF = SOURCE.with_suffix(".pdf")

def set_font(run, east="宋体", west="Times New Roman", size=10.5, bold=None):
    run.font.name = west
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), east)
    run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold

def set_cell_shading(cell, fill):
    tcpr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd"); shd.set(qn("w:fill"), fill); tcpr.append(shd)

def prevent_row_split(row):
    trpr = row._tr.get_or_add_trPr()
    trpr.append(OxmlElement("w:cantSplit"))

def set_repeat_table_header(row):
    trpr = row._tr.get_or_add_trPr()
    el = OxmlElement("w:tblHeader"); el.set(qn("w:val"), "true"); trpr.append(el)

def add_page_number(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = paragraph.add_run()
    set_font(run, size=9)
    fld = OxmlElement("w:fldSimple"); fld.set(qn("w:instr"), "PAGE")
    run._r.addnext(fld)

def format_docx(path):
    doc = Document(path)
    for sec in doc.sections:
        sec.page_width, sec.page_height = Cm(21), Cm(29.7)
        sec.top_margin = sec.bottom_margin = Cm(2.54)
        sec.left_margin = sec.right_margin = Cm(3.175)
        sec.header_distance = sec.footer_distance = Cm(1.5)
        for p in sec.header.paragraphs:
            p.clear()
        for p in sec.footer.paragraphs:
            p.clear()
        add_page_number(sec.footer.paragraphs[0])

    for name in ["Normal", "Body Text", "First Paragraph"]:
        if name in doc.styles:
            st = doc.styles[name]
            st.font.name = "Times New Roman"; st.font.size = Pt(10.5)
            st._element.rPr.rFonts.set(qn("w:eastAsia"), "宋体")
            st.paragraph_format.line_spacing = Pt(20)
            st.paragraph_format.space_after = Pt(0)
    for name,size in [("Title",22),("Heading 1",16),("Heading 2",15),("Heading 3",14)]:
        st = doc.styles[name]
        st.font.name = "Arial"; st.font.size = Pt(size); st.font.bold = True
        st.font.color.rgb = None
        st._element.rPr.rFonts.set(qn("w:eastAsia"), "黑体")
        st.paragraph_format.keep_with_next = True
        st.paragraph_format.line_spacing = 1.0 if name == "Title" else Pt(20)

    for p in doc.paragraphs:
        if p.style.name == "Title":
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.space_after = Pt(18)
            for r in p.runs: set_font(r, east="黑体", west="Arial", size=22, bold=True)
        elif p.style.name.startswith("Heading"):
            for r in p.runs: set_font(r, east="黑体", west="Arial", size=doc.styles[p.style.name].font.size.pt, bold=True)
        else:
            for r in p.runs:
                set_font(r, size=10.5)
        if p.text.startswith("图 ") or p.text.startswith("表 "):
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.keep_with_next = p.text.startswith("表 ")
        if p._p.xpath(".//w:drawing"):
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.line_spacing = 1.0
            p.paragraph_format.keep_together = True

    for shape in doc.inline_shapes:
        old_width, old_height = shape.width, shape.height
        new_width = Cm(14.5)
        shape.width = new_width
        shape.height = int(old_height * new_width / old_width)

    for ti, table in enumerate(doc.tables):
        ncols = len(table.columns)
        widths = {
            3: [Cm(4.3), Cm(2.0), Cm(7.9)],
            5: [Cm(2.2), Cm(2.1), Cm(2.7), Cm(2.6), Cm(4.6)],
        }.get(ncols, [Cm(16.0/ncols)]*ncols)
        table.autofit = False
        for ri, row in enumerate(table.rows):
            prevent_row_split(row)
            for i, cell in enumerate(row.cells):
                cell.width = widths[i]
                cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
                for p in cell.paragraphs:
                    p.paragraph_format.line_spacing = 1.0
                    p.paragraph_format.space_after = Pt(0)
                    p.paragraph_format.keep_with_next = ri < len(table.rows)-1
                    for r in p.runs: set_font(r, size=8.5)
        if table.rows:
            set_repeat_table_header(table.rows[0])
            for cell in table.rows[0].cells:
                set_cell_shading(cell, "E8EEF7")
                for p in cell.paragraphs:
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                    for r in p.runs: set_font(r, size=8.5, bold=True)

    doc.core_properties.title = "脉动阵列吞吐量与 Tile Cache 瓶颈分析"
    doc.core_properties.subject = "16×16 int8 脉动阵列供数带宽、tile 复用与 cache 容量分析"
    doc.save(path)

def main():
    subprocess.run(["python3", "draw_figures.py"], cwd=HERE, check=True)
    with tempfile.TemporaryDirectory(prefix="throughput-report-") as tmp:
        ref = Path(tmp)/"reference.docx"
        with ref.open("wb") as f:
            subprocess.run(["pandoc", "--print-default-data-file", "reference.docx"], stdout=f, check=True)
        subprocess.run(["pandoc", str(SOURCE), "-o", str(DOCX), "--resource-path", str(HERE), "--reference-doc", str(ref)], check=True)
    format_docx(DOCX)
    subprocess.run(["libreoffice", "--headless", "--convert-to", "pdf", "--outdir", str(HERE), str(DOCX)], check=True)
    print(f"Wrote {DOCX.name} and {PDF.name}")

if __name__ == "__main__":
    main()
