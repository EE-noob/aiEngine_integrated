#!/usr/bin/env python3
"""Check the submitted report structure, language, typography and figures."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import sys
import zipfile

from docx import Document
from lxml import etree
from PIL import Image, ImageDraw
import pymupdf

ROOT = Path(__file__).resolve().parent
SUPPORT = ROOT.parent / '详细设计报告'
BASE = ROOT / '简明NPU与SoC设计技术报告'
sys.path.insert(0, str(SUPPORT))
from report_typography import FONT_SCRIPTS, HEADING_FONT, is_heading_style

spec = importlib.util.spec_from_file_location('project_report_language', SUPPORT / 'audit_report.py')
rules = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rules)
NS = rules.NS


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    source = BASE.with_suffix('.md').read_text()
    chapters = re.findall(r'^## (\d+) (.+)$', source, re.M)
    assert chapters == [('1', 'NPU 设计'), ('2', 'SoC 设计与 FPGA 部署'), ('3', '软件栈设计')]
    for number in (1, 2, 3):
        assert re.findall(rf'^### {number}\.(\d+) ', source, re.M) == ['1', '2', '3']
    assert not re.search(r'Prepare|Eval|Invoke|0x[0-9A-Fa-f]|riscv_fully|dsa_matmul', source)
    figure_paths = [ROOT / item for item in re.findall(r'^!\[[^]]*\]\(([^)]+)\)', source, re.M)]
    assert len(figure_paths) == 3 and all(path.exists() for path in figure_paths)
    assert re.findall(r'^图 (\d+)\u3000', source, re.M) == ['1', '2', '3']
    original = rules.ORIGINAL_NPU.read_bytes()
    assert (ROOT / 'figures/npu.png').read_bytes() == original

    with zipfile.ZipFile(BASE.with_suffix('.docx')) as archive:
        xml = etree.fromstring(archive.read('word/document.xml'))
        styles = etree.fromstring(archive.read('word/styles.xml'))
        docx_text = ''.join(xml.xpath('//w:t/text() | //m:t/text()', namespaces=NS))
        assert len(xml.xpath('//w:drawing', namespaces=NS)) == 3
        assert not xml.xpath('//w:tbl | //m:oMath', namespaces=NS)
        assert not any(b'Courier' in archive.read(name)
                       for name in archive.namelist() if name.endswith('.xml'))
        embed = xml.xpath('(//w:drawing)[1]//a:blip/@r:embed', namespaces=NS)[0]
        rels = etree.fromstring(archive.read('word/_rels/document.xml.rels'))
        target = next(rel.get('Target') for rel in rels if rel.get('Id') == embed)
        member = target.lstrip('/') if target.startswith('/') else 'word/' + target
        assert archive.read(member) == original

    document = Document(BASE.with_suffix('.docx'))
    heading_ids = {style.style_id for style in document.styles if is_heading_style(style.name)}
    heading_nodes = [element for element in styles if element.get('{'+NS['w']+'}styleId') in heading_ids]
    heading_nodes += [run for paragraph in xml.xpath('//w:p', namespaces=NS)
                     if paragraph.xpath('./w:pPr/w:pStyle/@w:val', namespaces=NS) in [[item] for item in heading_ids]
                     for run in paragraph.xpath('.//w:r[w:t]', namespaces=NS)]
    for node in heading_nodes:
        fonts = node.find('w:rPr/w:rFonts', namespaces=NS)
        assert fonts is not None
        assert all(fonts.get('{'+NS['w']+'}'+script) == HEADING_FONT for script in FONT_SCRIPTS)
    section = document.sections[0]
    assert abs(section.page_width.cm - 21) < .02
    assert abs(section.page_height.cm - 29.7) < .02
    assert abs(section.left_margin.cm - 3.175) < .01
    normal = styles.xpath('//w:style[@w:styleId="Normal"]', namespaces=NS)[0]
    assert normal.xpath('./w:rPr/w:rFonts/@w:eastAsia', namespaces=NS) == ['宋体']
    assert normal.xpath('./w:rPr/w:sz/@w:val', namespaces=NS) == ['21']

    pdf = pymupdf.open(BASE.with_suffix('.pdf'))
    surfaces = {'Markdown': source, 'Word': docx_text,
                'PDF': '\n'.join(page.get_text() for page in pdf),
                'README': (ROOT / 'README.md').read_text(),
                'drawing_source': (ROOT / 'draw_figures.py').read_text()}
    surfaces.update({str(path.relative_to(ROOT)): path.read_text()
                     for path in (ROOT / 'figures').glob('*.svg')})
    for name, text in surfaces.items():
        assert not re.search(rules.PROHIBITED, text), (name, re.findall(rules.PROHIBITED, text))
        rules.audit_restricted_terms(text)
    for name in ('Markdown', 'Word', 'PDF'):
        text = surfaces[name]
        assert not re.search(rules.REMOVED_CONTENT, text, re.I), name
        assert not re.search(rules.NEGATIVE_PHRASES, text), name
        assert not re.search(r'<sup>|\[\d+(?:[,–-]\d+)*\]', text), name

    toc_count = caption_count = image_count = 0
    for page_index, page in enumerate(pdf):
        body = page.get_text(clip=pymupdf.Rect(60, 75, 535, 770))
        images = page.get_image_info()
        assert len(body.strip()) > 8 or images, ('empty page', page_index + 1)
        if images:
            assert len(re.findall(r'图\s*\d+\s*\u3000', body)) == len(images), ('figure caption', page_index + 1)
        image_count += len(images)
        for info in images:
            box = pymupdf.Rect(info['bbox'])
            assert box.x0 >= 89 and box.x1 <= 507 and box.y0 >= 65 and box.y1 <= 773
        for block in page.get_text('dict')['blocks']:
            for line in block.get('lines', []):
                line_text = ''.join(span['text'] for span in line['spans'])
                if re.match(r'^图\s*\d+\s*\u3000', line_text):
                    assert all('simhei' in span['font'].lower() for span in line['spans'] if span['text'].strip())
                    caption_count += 1
                for span in line['spans']:
                    if span['text'].strip() and span['size'] >= 14:
                        assert 'simhei' in span['font'].lower(), (page_index, span)
        for link in page.get_links():
            if link['kind'] != pymupdf.LINK_GOTO:
                continue
            visible = page.get_textbox(link['from'])
            match = re.search(r'(\d+)\s*$', visible)
            assert match and int(match[1]) == link['page'], ('TOC', visible, link)
            toc_count += 1
    assert image_count == caption_count == 3
    assert toc_count == len(re.findall(r'^#{2,3} ', source, re.M)) == 13

    proof = ROOT / 'proofs'
    proof.mkdir(exist_ok=True)
    thumbnails = []
    for index, page in enumerate(pdf):
        path = proof / f'page-{index+1:02d}.png'
        page.get_pixmap(matrix=pymupdf.Matrix(110/72, 110/72), alpha=False).save(path)
        preview = Image.open(path).convert('RGB')
        preview.thumbnail((595, 842))
        thumbnails.append(preview)
    for start in range(0, len(thumbnails), 4):
        sheet = Image.new('RGB', (1230, 1740), '#d9d9d9')
        pen = ImageDraw.Draw(sheet)
        for offset, preview in enumerate(thumbnails[start:start+4]):
            x, y = 10 + (offset % 2)*615, 22 + (offset // 2)*870
            sheet.paste(preview, (x, y))
            pen.text((x, y-16), f'PDF page {start+offset+1}', fill='black')
        sheet.save(proof / f'sheet-{start//4+1:02d}.png')

    assets = [*figure_paths, *sorted((ROOT / 'figures').glob('*.svg')),
              ROOT / 'draw_figures.py', ROOT / 'diagram_audit.json', SUPPORT / 'draw_figures.py']
    with zipfile.ZipFile(ROOT / '插图与图源.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in assets:
            member = path.relative_to(ROOT) if path.is_relative_to(ROOT) else Path('support') / path.name
            archive.write(path, member)
    result = {'chapters': dict(chapters), 'body_han_characters': len(re.findall(r'[\u4e00-\u9fff]', source)),
              'pdf_pages': len(pdf), 'figures': image_count, 'toc_entries_checked': toc_count,
              'language_checks': {name: 'PASS' for name in surfaces},
              'heading_fonts': '黑体', 'docx_structure': 'PASS', 'pdf_checks': 'PASS',
              'npu_original_image': 'PASS',
              'sha256': {str(path.relative_to(ROOT)): digest(path) for path in
                         [BASE.with_suffix('.md'), BASE.with_suffix('.docx'), BASE.with_suffix('.pdf'),
                          ROOT / 'build_report.py', ROOT / 'draw_figures.py', ROOT / 'audit_report.py', ROOT / 'README.md']}}
    (ROOT / 'quality_audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'sha256'}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
