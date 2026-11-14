#!/usr/bin/env python3
"""Export the test report using the project's established Word format."""
from pathlib import Path
import argparse
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile

from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from report_typography import apply_heading_fonts

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "NPU与传感器校准SoC测试验证报告.md"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--converter", type=Path, default=Path("/media/3/工作/CKS58/md_report_to_docx.py"))
    args = parser.parse_args()
    subprocess.run([sys.executable, str(ROOT / "draw_test_figures.py")], check=True)
    spec = importlib.util.spec_from_file_location("test_report_format", args.converter)
    formatter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(formatter)
    formatter.REPORT_TYPE = "测试验证报告"
    original_prepare = formatter.prepare_markdown

    def prepare(source, target, date_text):
        title, expected = original_prepare(source, target, "")
        target.write_text(re.sub(r"(?m)^date:.*\n", "", target.read_text(), count=1))
        return title, expected

    formatter.prepare_markdown = prepare
    original_tables = formatter.format_tables

    def tables(document):
        original_tables(document)
        widths = ((.24,.38,.38),(.49,.17,.20,.14),(.20,.16,.16,.16,.16,.16),
                  (.13,.20,.20,.20,.27),(.34,.22,.22,.22))
        section = document.sections[0]
        available = section.page_width-section.left_margin-section.right_margin
        for table, ratios in zip(document.tables, widths):
            table.autofit = False
            for column, ratio in zip(table.columns, ratios):
                column.width = round(available*ratio)
            for row in table.rows:
                formatter.prevent_row_split(row)
                for cell, ratio in zip(row.cells, ratios):
                    cell.width = round(available*ratio)
                    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
                    for paragraph in cell.paragraphs:
                        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
                        paragraph.paragraph_format.keep_with_next = False

    formatter.format_tables = tables
    original_styles = formatter.configure_styles

    def styles(document):
        original_styles(document)
        document.styles["Title"].paragraph_format.line_spacing = 1.0
        apply_heading_fonts(document)

    formatter.configure_styles = styles
    original_post = formatter.postprocess_docx

    def postprocess(path, title, **kwargs):
        result = original_post(path, title, **kwargs)
        doc = formatter.Document(path)
        for paragraph in doc.paragraphs:
            if paragraph.style.name == "Title":
                paragraph.clear()
                paragraph.add_run("NPU 与传感器校准 SoC")
                paragraph.add_run().add_break()
                paragraph.add_run("测试验证报告")
        for previous, following in zip(doc.paragraphs, doc.paragraphs[1:]):
            if following.style.name == "Equation" and previous.text.strip():
                previous.paragraph_format.keep_with_next = True
        conclusion = False
        for index, paragraph in enumerate(doc.paragraphs):
            if paragraph.style.name == "Heading 1" and paragraph.text.startswith("7 "):
                conclusion = True
            if conclusion:
                paragraph.paragraph_format.keep_with_next = index < len(doc.paragraphs)-1
        doc.core_properties.subject = "NPU 与传感器校准 SoC 测试验证"
        doc.core_properties.keywords = "NPU; SoC; TFLM; 量化推理; 联合仿真; FPGA"
        apply_heading_fonts(doc)
        doc.save(path)
        return result

    formatter.postprocess_docx = postprocess
    sys.argv = [str(args.converter), str(SOURCE)]
    status = formatter.main()
    if status:
        return status
    with tempfile.TemporaryDirectory(prefix=".test-fields-", dir=ROOT) as tmp:
        work = Path(tmp) / "report.docx"
        shutil.copy2(SOURCE.with_suffix(".docx"), work)
        if not formatter.update_fields_with_libreoffice(work):
            raise SystemExit("最终目录更新失败")
        document = formatter.Document(work)
        formatter.set_update_fields_on_open(document)
        apply_heading_fonts(document)
        document.save(work)
        formatter.remove_unused_courier_definitions(work)
        _, expected = formatter.prepare_markdown(SOURCE, Path(tmp) / "source.md", "")
        formatter.audit_docx(work, expected, True)
        formatter.export_pdf(work, work.with_suffix(".pdf"))
        os.replace(work, SOURCE.with_suffix(".docx"))
        os.replace(work.with_suffix(".pdf"), SOURCE.with_suffix(".pdf"))
    print("Word 和 PDF 已导出。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
