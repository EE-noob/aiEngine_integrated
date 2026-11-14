"""Explicit heading typography, independent of Word theme font substitutions."""
from __future__ import annotations

import re

from docx.oxml import OxmlElement
from docx.oxml.ns import qn

HEADING_FONT = '黑体'
FONT_SCRIPTS = ('ascii', 'hAnsi', 'eastAsia', 'cs')


def is_heading_style(name):
    normalized = re.sub(r'[\s_-]', '', name).lower()
    return (normalized in ('title', 'titlechar', 'subtitle', 'subtitlechar',
                           'booktitle', 'caption', 'heading', 'indexheading')
            or normalized.startswith(('heading', 'toc', 'contents')))


def set_font(rpr):
    fonts = rpr.find(qn('w:rFonts'))
    if fonts is None:
        fonts = OxmlElement('w:rFonts')
        rpr.insert(0, fonts)
    for attr in list(fonts.attrib):
        if attr.rsplit('}', 1)[-1].lower().endswith('theme'):
            del fonts.attrib[attr]
    for script in FONT_SCRIPTS:
        fonts.set(qn('w:' + script), HEADING_FONT)


def apply_heading_fonts(document):
    """Preserve sizes/spacing; cover styles, direct runs, and TOC hyperlinks."""
    style_ids = set()
    for style in document.styles:
        if is_heading_style(style.name):
            set_font(style.element.get_or_add_rPr())
            style_ids.add(style.style_id)
    paragraphs = runs = 0
    for paragraph in document.element.body.iter(qn('w:p')):
        ppr = paragraph.find(qn('w:pPr'))
        if ppr is None:
            continue
        pstyle = ppr.find(qn('w:pStyle'))
        if pstyle is None or pstyle.get(qn('w:val')) not in style_ids:
            continue
        mark = ppr.find(qn('w:rPr'))
        if mark is None:
            mark = OxmlElement('w:rPr')
            ppr.append(mark)
        set_font(mark)
        for run in paragraph.iter(qn('w:r')):
            set_font(run.get_or_add_rPr())
            runs += 1
        paragraphs += 1
    return {'styles': len(style_ids), 'paragraphs': paragraphs, 'runs': runs}
