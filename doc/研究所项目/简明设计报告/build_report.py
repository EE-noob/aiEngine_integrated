#!/usr/bin/env python3
"""Build the project report with the specified scientific-report formatter."""
from pathlib import Path
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
SUPPORT = ROOT.parent / '详细设计报告'
CONVERTER = Path('/media/3/工作/CKS58/md_report_to_docx.py')
SOURCE = ROOT / '简明NPU与SoC设计技术报告.md'
sys.path.insert(0, str(SUPPORT))
from report_typography import apply_heading_fonts


def main():
    subprocess.run([sys.executable, str(ROOT / 'draw_figures.py')], check=True)
    spec = importlib.util.spec_from_file_location('project_report_format', CONVERTER)
    formatter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(formatter)
    formatter.REPORT_TYPE = '设计报告'
    prepare_source = formatter.prepare_markdown

    def prepare(source, target, date_text):
        title, expected = prepare_source(source, target, '')
        content = target.read_text(encoding='utf-8')
        target.write_text(re.sub(r'(?m)^date:.*\n', '', content, count=1),
                          encoding='utf-8')
        return title, expected

    formatter.prepare_markdown = prepare
    configure_styles = formatter.configure_styles

    def styles(document):
        configure_styles(document)
        document.styles['Title'].paragraph_format.line_spacing = 1.0
        apply_heading_fonts(document)

    formatter.configure_styles = styles
    postprocess_docx = formatter.postprocess_docx

    def postprocess(path, title, **kwargs):
        result = postprocess_docx(path, title, **kwargs)
        document = formatter.Document(path)
        for paragraph in document.paragraphs:
            if paragraph.style.name == 'Title':
                paragraph.clear()
                paragraph.add_run('NPU 与 SoC 设计')
                paragraph.add_run().add_break()
                paragraph.add_run('技术报告')
        document.core_properties.subject = '传感器校准项目的 NPU、SoC 与软件设计'
        document.core_properties.keywords = 'NPU; SoC; FPGA; TFLM; 传感器校准'
        apply_heading_fonts(document)
        document.save(path)
        return result

    formatter.postprocess_docx = postprocess
    sys.argv = [str(CONVERTER), str(SOURCE)]
    status = formatter.main()
    if status:
        return status

    with tempfile.TemporaryDirectory(prefix='.report-fields-', dir=ROOT) as temp:
        working = Path(temp) / 'report.docx'
        shutil.copy2(SOURCE.with_suffix('.docx'), working)
        if not formatter.update_fields_with_libreoffice(working):
            raise RuntimeError('目录更新失败')
        document = formatter.Document(working)
        formatter.set_update_fields_on_open(document)
        apply_heading_fonts(document)
        document.save(working)
        formatter.remove_unused_courier_definitions(working)
        _, expected = formatter.prepare_markdown(SOURCE, Path(temp) / 'source.md', '')
        formatter.audit_docx(working, expected, True)
        formatter.export_pdf(working, working.with_suffix('.pdf'))
        os.replace(working, SOURCE.with_suffix('.docx'))
        os.replace(working.with_suffix('.pdf'), SOURCE.with_suffix('.pdf'))
    print('Word:', SOURCE.with_suffix('.docx'))
    print('PDF:', SOURCE.with_suffix('.pdf'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
