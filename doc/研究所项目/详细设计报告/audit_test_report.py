#!/usr/bin/env python3
"""Check numerical records, document structure, typography and rendered pages."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

import pymupdf
from docx import Document
from lxml import etree
from PIL import Image, ImageDraw

from audit_report import NS, PROHIBITED, REMOVED_CONTENT, NEGATIVE_PHRASES, audit_restricted_terms
from report_typography import FONT_SCRIPTS, HEADING_FONT, is_heading_style

ROOT = Path(__file__).resolve().parent
BASE = ROOT / "NPU与传感器校准SoC测试验证报告"


def main():
    source = BASE.with_suffix(".md").read_text()
    records = json.loads((ROOT / "test_results.json").read_text())
    assert re.findall(r"^## (\d+) ", source, re.M) == list(map(str, range(1,8)))
    for kind in ("图", "表"):
        assert re.findall(r"^\**"+kind+r" (\d+)\u3000", source, re.M) == list(map(str,range(1,6)))
    images = [ROOT / p for p in re.findall(r"!\[[^]]*\]\(([^)]+)\)", source)]
    assert len(images) == 5 and all(p.exists() and p.with_suffix(".svg").exists() for p in images)
    tables = [block for block in re.findall(r"(?m)(?:^\|.*\n)+", source)]
    assert len(tables) == 5
    rtl_rows = [line for line in tables[1].splitlines()[2:]]
    assert len(rtl_rows) == 12
    for line, case in zip(rtl_rows, records["rtl"]["cases"]):
        cells = [x.strip().replace(" ", "") for x in line.strip("|").split("|")]
        assert int(cells[1]) == case["ia_cache_blocks"]
        assert int(cells[2]) == case["start_to_ready_cycles"] and cells[3] == "通过"
    assert sum(c["compared_cycles"] for c in records["rtl"]["cases"]) == 72461
    for line, actual, delta in zip(tables[3].splitlines()[2:], records["multi_input_model"]["actual"],
                                  records["multi_input_model"]["signed_delta"]):
        cells = [int(x.strip().replace(" ", "")) for x in line.strip("|").split("|")]
        assert cells[1:4] == actual and cells[4] == max(map(abs,delta))
    assert records["multi_input_model"]["max_absolute_delta"] == [0,0,1]
    for line, resource in zip(tables[4].splitlines()[2:],records["fpga"]["resources"]):
        cells = [x.strip().replace(" ", "") for x in line.strip("|").split("|")]
        assert float(cells[1]) == resource["used"] and float(cells[2]) == resource["available"]
        assert float(cells[3].strip("%")) == resource["percent"]
    assert records["fpga"]["wns_ns"] == .171 and records["fpga"]["whs_ns"] == .010
    assert records["compact_model"]["invoke_cycles"] == [94170,94125,94102]
    assert sum(m["bytes"] for m in records["deployment_models"]) == 41616
    with zipfile.ZipFile(BASE.with_suffix(".docx")) as archive:
        xml = etree.fromstring(archive.read("word/document.xml"))
        styles = etree.fromstring(archive.read("word/styles.xml"))
        docx_text = "".join(xml.xpath("//w:t/text()", namespaces=NS))
        assert len(xml.xpath("//w:drawing",namespaces=NS)) == 5
        assert len(xml.xpath("//w:tbl",namespaces=NS)) == 5
        equations = xml.xpath('//w:p[w:pPr/w:pStyle[@w:val="Equation"]]',namespaces=NS)
        assert len(equations) == 3
        for i,eq in enumerate(equations,1):
            assert eq.xpath(".//m:oMath",namespaces=NS)
            assert "".join(eq.xpath(".//w:t/text()",namespaces=NS)).strip() == f"（{i}）"
        assert any("TOC" in x for x in xml.xpath("//w:instrText/text()",namespaces=NS))
        for cell in xml.xpath("//w:tc",namespaces=NS):
            assert cell.xpath("./w:tcPr/w:vAlign/@w:val",namespaces=NS) == ["center"]
            for paragraph in cell.xpath("./w:p",namespaces=NS):
                assert paragraph.xpath("./w:pPr/w:jc/@w:val",namespaces=NS) == ["center"]
        ids = {s.style_id for s in Document(BASE.with_suffix(".docx")).styles if is_heading_style(s.name)}
        for style in styles.xpath("//w:style",namespaces=NS):
            if style.get("{"+NS["w"]+"}styleId") in ids:
                fonts = style.find("w:rPr/w:rFonts",namespaces=NS)
                assert fonts is not None
                assert all(fonts.get("{"+NS["w"]+"}"+s)==HEADING_FONT for s in FONT_SCRIPTS)
    pdf = pymupdf.open(BASE.with_suffix(".pdf"))
    pdf_text = "\n".join(page.get_text() for page in pdf)
    svg_text = "\n".join("".join(etree.parse(str(p.with_suffix(".svg"))).getroot().itertext()) for p in images)
    surfaces = {"Markdown":source, "DOCX":docx_text, "PDF":pdf_text,"SVG":svg_text,
                "说明":(ROOT/"测试报告说明.md").read_text()}
    for name, text in surfaces.items():
        assert not re.search(PROHIBITED,text),(name,re.findall(PROHIBITED,text))
        assert not re.search(REMOVED_CONTENT,text),(name,re.findall(REMOVED_CONTENT,text))
        assert not re.search(NEGATIVE_PHRASES,text),(name,re.findall(NEGATIVE_PHRASES,text))
        audit_restricted_terms(text)
        assert not any(s in text for s in ("错误！未找到", "Error! Reference", "{width=", "{height="))
    proof = ROOT / "test_proofs"
    proof.mkdir(exist_ok=True)
    toc_count = 0
    image_pages = []
    thumbs = []
    layout = []
    for i,page in enumerate(pdf):
        body = page.get_text(clip=pymupdf.Rect(60,75,535,770))
        infos = page.get_image_info()
        assert len(body.strip())>8 or infos, ("blank page", i+1)
        if infos:
            assert len(re.findall(r"图\s*\d+\s*\u3000",body)) == len(infos),("caption",i+1)
            image_pages.append(i+1)
        for info in infos:
            rect = pymupdf.Rect(info["bbox"])
            assert rect.x0>=89 and rect.x1<=507 and rect.y0>=65 and rect.y1<=773,(i+1,rect)
        for block in page.get_text("dict")["blocks"]:
            for line in block.get("lines",[]):
                for span in line["spans"]:
                    math_font = any(name in span["font"].lower() for name in ("opensymbol", "cambriamath"))
                    if span["text"].strip() and span["size"]>=14 and not math_font:
                        assert "simhei" in span["font"].lower(),("heading font",i+1,span)
        for link in page.get_links():
            if link["kind"] == pymupdf.LINK_GOTO:
                visible = page.get_textbox(link["from"])
                number = re.search(r"(\d+)\s*$",visible)
                assert number and int(number[1])==link["page"],("TOC page",visible,link["page"])
                toc_count += 1
        pixmap = page.get_pixmap(matrix=pymupdf.Matrix(110/72,110/72),alpha=False)
        path = proof / f"page-{i+1:02d}.png"
        pixmap.save(path)
        image = Image.open(path).convert("RGB")
        image.thumbnail((595,842))
        thumbs.append(image)
        blocks = page.get_text("blocks")
        layout.append({"page":i+1,"text_characters":len(body),"images":len(infos),
                       "body_bottom_pt":max((b[3] for b in blocks if b[1]>75),default=0)})
    assert toc_count == len(re.findall(r"^#{2,3} ", source,re.M))
    for start in range(0,len(thumbs),4):
        sheet = Image.new("RGB",(1230,1740),"#D9D9D9")
        draw = ImageDraw.Draw(sheet)
        for j,image in enumerate(thumbs[start:start+4]):
            x,y = 10+(j%2)*615,22+(j//2)*870
            sheet.paste(image,(x,y))
            draw.text((x,y-16),f"PDF page {start+j+1}",fill="black")
        sheet.save(proof/f"sheet-{start//4+1:02d}.png")
    audit = {"chapters":7,"pages":len(pdf),"figures":5,"tables":5,"editable_equations":3,
             "han_characters":len(re.findall(r"[\u4e00-\u9fff]",source)),
             "numerical_record_checks":"PASS","terminology":"PASS","tables_centered":"PASS",
             "heading_font":"黑体","toc_entries_checked":toc_count,"image_pages":image_pages,
             "structure":"PASS","visual_review_record":"测试报告说明.md","layout_pages":layout,
             "sha256":{p.name:hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in [BASE.with_suffix(s) for s in (".md",".docx",".pdf")]}}
    (ROOT/"test_quality_audit.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({k:v for k,v in audit.items() if k not in ("sha256","layout_pages")},ensure_ascii=False,indent=2))


if __name__ == "__main__":
    main()
