#!/usr/bin/env python3
"""Use the user's authoritative Word converter; preserve its named styles."""
from pathlib import Path
import importlib.util
import subprocess
import sys
import tempfile
import shutil
import os
import re

from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH

from report_typography import apply_heading_fonts

ROOT=Path(__file__).resolve().parent
CONVERTER=Path('/media/3/工作/CKS58/md_report_to_docx.py')
SOURCE=ROOT/'NPU与传感器校准SoC详细设计技术报告.md'


def main():
    subprocess.run([sys.executable,str(ROOT/'draw_figures.py')],check=True)
    spec=importlib.util.spec_from_file_location('report_format',CONVERTER)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.REPORT_TYPE='设计报告'
    original_prepare=module.prepare_markdown
    def prepare(source,target,date_text):
        title,expected=original_prepare(source,target,'')
        # The deliverable has no visible date or release/version record.
        content=target.read_text(encoding='utf-8')
        target.write_text(re.sub(r'(?m)^date:.*\n','',content,count=1),encoding='utf-8')
        return title,expected
    module.prepare_markdown=prepare
    original_tables=module.format_tables
    def tables(document):
        original_tables(document)
        for table in document.tables:
            for row_index,row in enumerate(table.rows):
                # These two short tables fit on one page; retain each row and
                # the table as a single readable object with its caption.
                module.prevent_row_split(row)
                for cell in row.cells:
                    cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
                    for paragraph in cell.paragraphs:
                        paragraph.alignment=WD_ALIGN_PARAGRAPH.CENTER
                        paragraph.paragraph_format.keep_with_next=row_index<len(table.rows)-1
    module.format_tables=tables
    original=module.configure_styles
    def styles(document):
        original(document)
        # The longer title can wrap. Single line spacing prevents the body
        # 20-pt exact spacing from clipping its 22-pt title glyphs.
        document.styles['Title'].paragraph_format.line_spacing=1.0
        apply_heading_fonts(document)
    module.configure_styles=styles
    original_post=module.postprocess_docx
    def postprocess(path,title,**kwargs):
        result=original_post(path,title,**kwargs)
        doc=module.Document(path)
        for paragraph in doc.paragraphs:
            if paragraph.style.name=='Title':
                paragraph.clear()
                paragraph.add_run('NPU 与传感器校准 SoC')
                paragraph.add_run().add_break()
                paragraph.add_run('详细设计技术报告')
        for previous,following in zip(doc.paragraphs,doc.paragraphs[1:]):
            if following.style.name=='Equation' and previous.text.strip():
                previous.paragraph_format.keep_with_next=True
        doc.core_properties.subject='NPU 与传感器校准 SoC 设计'
        doc.core_properties.keywords='NPU; SoC; TFLM; 脉动阵列; 传感器校准'
        apply_heading_fonts(doc)
        doc.save(path)
        return result
    module.postprocess_docx=postprocess
    sys.argv=[str(CONVERTER),str(SOURCE)]
    status=module.main()
    if status:return status
    # Layout postprocessing after the converter's first field refresh can move
    # a kept heading. Refresh once more at the final layout, then only restore
    # settings/citation functionality and explicit heading font declarations
    # (font sizes, spacing and other layout properties stay unchanged).
    with tempfile.TemporaryDirectory(prefix='.final-fields-',dir=ROOT) as tmp:
        work=Path(tmp)/'report.docx'
        shutil.copy2(SOURCE.with_suffix('.docx'),work)
        if not module.update_fields_with_libreoffice(work):
            raise SystemExit('最终目录更新失败')
        doc=module.Document(work)
        module.set_update_fields_on_open(doc)
        module.add_citation_cross_references(doc)
        apply_heading_fonts(doc)
        doc.save(work)
        module.remove_unused_courier_definitions(work)
        _,expected=module.prepare_markdown(SOURCE,Path(tmp)/'source.md','')
        module.audit_docx(work,expected,True)
        module.export_pdf(work,work.with_suffix('.pdf'))
        os.replace(work,SOURCE.with_suffix('.docx'))
        os.replace(work.with_suffix('.pdf'),SOURCE.with_suffix('.pdf'))
    print(f'最终 Word：{SOURCE.with_suffix(".docx")}')
    print(f'最终 PDF：{SOURCE.with_suffix(".pdf")}')
    return 0


if __name__=='__main__': raise SystemExit(main())
