#!/usr/bin/env python3
"""Audit delivered source/DOCX/PDF and render all pages for visual review."""
from __future__ import annotations
import hashlib
import json
import posixpath
import re
import struct
import zipfile
from pathlib import Path

import pymupdf
from docx import Document
from lxml import etree
from PIL import Image, ImageDraw

from report_typography import FONT_SCRIPTS, HEADING_FONT, is_heading_style

ROOT=Path(__file__).resolve().parent
BASE=ROOT/'NPU与传感器校准SoC详细设计技术报告'
NS={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'm':'http://schemas.openxmlformats.org/officeDocument/2006/math',
    'a':'http://schemas.openxmlformats.org/drawingml/2006/main',
    'r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    'wp':'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'}
ORIGINAL_NPU=Path('/media/3/0-课题/TFLM加速器/架构设计-AXI.png')
REPORT_PROHIBITED_WORDS=(
    '链路','实践','口径','闭环','签核','映射','判据','令牌','历元','重定向',
    '生产者','所有者','负载','元数据','语义','组合锥','时隙','同址','归约','根因','排程',
)
AGENTS_PROHIBITED_EXPRESSIONS=(
    '落地','钉死','门禁','夹具','探针','基线','收掉','追溯','冒烟','烟测',
    '全量','验收矩阵','颗粒度','证据','关键一刀','约定','合同',
)
PROHIBITED='|'.join(map(re.escape,REPORT_PROHIBITED_WORDS+
    AGENTS_PROHIBITED_EXPRESSIONS+('后继','年轻','公开结果','票据','体系 PC','分配证明')))
REMOVED_CONTENT=r'SiLU|参考文献|候选发布|版本|20\d{2}\s*年|\b20\d{2}[-/]\d{1,2}[-/]\d{1,2}\b|\b20\d{6}\b|传感器模型部署与存储实现|时钟、时序与资源设计'
NEGATIVE_PHRASES=r'不(?!同)|尚未|没有|未验证|未完成|无法|可能'
# Structural/physical separation must be reviewed in its actual sentence.
# Add an exact excerpt and a concrete separation-object explanation only after
# manual review; a generic word whitelist cannot establish the intended sense.
BOUNDARY_CONTEXT_APPROVALS: dict[str,str]={}
QUANTIZATION_EXAMPLES=('量化方法','量化误差','量化精度')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit_restricted_terms(text,*,boundary_approvals=None):
    """Check the fixed phrase and require recorded review of separation uses."""
    approvals=BOUNDARY_CONTEXT_APPROVALS if boundary_approvals is None else boundary_approvals
    convergence=list(re.finditer('收敛',text))
    invalid=[text[max(0,m.start()-18):m.end()+18] for m in convergence
        if text[max(0,m.start()-2):m.start()]!='时序']
    assert not invalid,('restricted term outside fixed phrase 时序收敛',invalid)
    reviewed=[]
    for match in re.finditer('边界',text):
        reasons=[]
        for excerpt,reason in approvals.items():
            assert '边界' in excerpt and excerpt!='边界' and reason.strip(),('invalid context approval',excerpt)
            if any(m.start()<=match.start() and match.end()<=m.end()
                   for m in re.finditer(re.escape(excerpt),text)):
                reasons.append({'excerpt':excerpt,'separation_object':reason})
        context=text[max(0,match.start()-24):match.end()+24]
        assert reasons,('physical/structural separation needs context review',context)
        reviewed.append({'context':context,'approvals':reasons})
    return {'quantization_occurrences':text.count('量化'),
        'quantization_examples_present':[term for term in QUANTIZATION_EXAMPLES if term in text],
        'timing_convergence_occurrences':len(convergence),
        'invalid_convergence_occurrences':0,
        'boundary_occurrences':len(reviewed),'boundary_reviews':reviewed,
        'unreviewed_boundary_occurrences':0}


def main():
    source=BASE.with_suffix('.md').read_text()
    han=len(re.findall(r'[\u4e00-\u9fff]',source))
    chapters=re.findall(r'^## (\d+) ',source,re.M)
    assert chapters==[str(i) for i in range(1,12)],chapters
    assert han>10000,han
    for term in ('### 3.5 Vivado 模块连接与时钟复位','bit_soc_wrapper',
                 'MicroMutableOpResolver','Prepare','Eval','riscv_fully_connected_s16_s32_bias_acc',
                 '18 个特征','12 个特征','7 个特征','NOLOAD','.incbin','COE'):
        assert term in source,('design coverage',term)
    deployment=source.split('## 9 基于 MicroBlaze 的 FPGA 部署\n',1)[1].split('## 10 ',1)[0]
    assert re.findall(r'^### 9\.(\d+) ',deployment,re.M)==[str(i) for i in range(1,7)]
    for term in ('MicroBlaze V','XSA','sensor_hw_v2','sensor_sw_v2','Standalone','BSP',
                 'libtflite-micro.a','.dsa_model','.dsa_arena','AllocateTensors','ELF',
                 'MMI','updatemem','sensor_calibration_runtime_init',
                 'sensor_calibration_runtime_predict','OLED','UART'):
        assert term in deployment,('deployment coverage',term)
    expected_toc=len(re.findall(r'^#{2,3} ',source,re.M))
    figure_paths=[ROOT/p for p in re.findall(r'^!\[[^]]*\]\(([^)]+)\)',source,re.M)]
    assert len(figure_paths)==8
    assert re.findall(r'^图 (\d+)\u3000',source,re.M)==[str(i) for i in range(1,9)]
    with zipfile.ZipFile(BASE.with_suffix('.docx')) as z:
        xml=etree.fromstring(z.read('word/document.xml'))
        styles=etree.fromstring(z.read('word/styles.xml'))
        docx_text=''.join(xml.xpath('//w:t/text()',namespaces=NS))
        assert not any(b'Courier' in z.read(n) for n in z.namelist() if n.endswith('.xml'))
        original=ORIGINAL_NPU.read_bytes()
        asset=ROOT/'figures/图02-NPU总体架构.png'
        assert asset.read_bytes()==original,'NPU figure asset differs from original'
        image_ids=xml.xpath('(//w:drawing)[2]//a:blip/@r:embed',namespaces=NS)
        assert len(image_ids)==1,image_ids
        rels=etree.fromstring(z.read('word/_rels/document.xml.rels'))
        image_targets=[r.get('Target') for r in rels if r.get('Id')==image_ids[0]]
        assert len(image_targets)==1,image_targets
        target=image_targets[0]
        npu_media=target.lstrip('/') if target.startswith('/') else posixpath.normpath('word/'+target)
        assert z.read(npu_media)==original,'Word must embed the exact supplied NPU PNG'
        pixels=struct.unpack('>II',original[16:24])
        extent=xml.xpath('(//w:drawing)[2]//wp:extent',namespaces=NS)[0]
        # LibreOffice rounds display extents to twips (635 EMU); the embedded
        # bitmap itself remains byte-identical and keeps its original pixels.
        expected_height=round(int(extent.get('cx'))*pixels[1]/pixels[0])
        assert abs(int(extent.get('cy'))-expected_height)<=635
    assert len(xml.xpath('//w:drawing',namespaces=NS))==8
    assert len(xml.xpath('//w:tbl',namespaces=NS))==2
    equations=xml.xpath('//w:p[w:pPr/w:pStyle[@w:val="Equation"]]',namespaces=NS)
    assert len(equations)==5,len(equations)
    for eq in equations:
        assert eq.xpath('.//m:oMath',namespaces=NS)
        assert re.fullmatch(r'（[1-5]）',''.join(eq.xpath('.//w:t/text()',namespaces=NS)).strip())
    citations=xml.xpath('//w:hyperlink[starts-with(@w:anchor,"BIB_REF_")]',namespaces=NS)
    assert len(citations)==0
    assert not xml.xpath('//w:bookmarkStart[starts-with(@w:name,"BIB_REF_")]',namespaces=NS)
    assert not xml.xpath('//w:p[w:pPr/w:pStyle[@w:val="Date"]]',namespaces=NS)
    cells=xml.xpath('//w:tbl//w:tc',namespaces=NS)
    assert all(row.xpath('./w:trPr/w:cantSplit',namespaces=NS)
        for row in xml.xpath('//w:tbl//w:tr',namespaces=NS))
    for cell in cells:
        assert cell.xpath('./w:tcPr/w:vAlign/@w:val',namespaces=NS)==['center']
        for paragraph in cell.xpath('./w:p',namespaces=NS):
            assert paragraph.xpath('./w:pPr/w:jc/@w:val',namespaces=NS)==['center']
    doc=Document(BASE.with_suffix('.docx'))
    heading_style_ids={s.style_id for s in doc.styles if is_heading_style(s.name)}
    def check_heading_font(fonts,where):
        assert fonts is not None,('missing heading fonts',where)
        for script in FONT_SCRIPTS:
            assert fonts.get('{'+NS['w']+'}'+script)==HEADING_FONT,(where,script,dict(fonts.attrib))
        assert not any(k.rsplit('}',1)[-1].lower().endswith('theme') for k in fonts.attrib),where
    for style in styles.xpath('//w:style',namespaces=NS):
        if style.get('{'+NS['w']+'}styleId') in heading_style_ids:
            check_heading_font(style.find('w:rPr/w:rFonts',namespaces=NS),'style '+style.get('{'+NS['w']+'}styleId'))
    heading_paragraphs=0
    heading_runs=0
    for paragraph in xml.xpath('//w:p',namespaces=NS):
        ids=paragraph.xpath('./w:pPr/w:pStyle/@w:val',namespaces=NS)
        if not ids or ids[0] not in heading_style_ids:continue
        heading_paragraphs+=1
        for run in paragraph.xpath('.//w:r[w:t]',namespaces=NS):
            check_heading_font(run.find('w:rPr/w:rFonts',namespaces=NS),''.join(run.xpath('./w:t/text()',namespaces=NS)))
            heading_runs+=1
    sec=doc.sections[0]
    assert abs(sec.page_width.cm-21)<.02 and abs(sec.page_height.cm-29.7)<.02
    assert abs(sec.left_margin.cm-3.175)<.01 and abs(sec.top_margin.cm-2.54)<.01
    normal=styles.xpath('//w:style[@w:styleId="Normal"]',namespaces=NS)[0]
    assert normal.xpath('./w:rPr/w:rFonts/@w:eastAsia',namespaces=NS)==['宋体']
    assert normal.xpath('./w:rPr/w:sz/@w:val',namespaces=NS)==['21']
    assert normal.xpath('./w:pPr/w:spacing/@w:line',namespaces=NS)==['400']
    pdf=pymupdf.open(BASE.with_suffix('.pdf'))
    pdf_text='\n'.join(p.get_text() for p in pdf)
    terminology_surfaces={'MD':source,'DOCX':docx_text,'PDF':pdf_text,
        'figure_source':(ROOT/'draw_figures.py').read_text()}
    terminology_surfaces.update({name:(ROOT/name).read_text()
        for name in ('README.md','审查记录.md')})
    terminology_surfaces.update({str(f.relative_to(ROOT)):f.read_text()
        for f in sorted((ROOT/'figures').glob('*.svg'))})
    restricted_term_checks={}
    for name,text in terminology_surfaces.items():
        assert not re.search(PROHIBITED,text),(name,re.findall(PROHIBITED,text))
        try:
            restricted_term_checks[name]=audit_restricted_terms(text)
        except AssertionError as error:
            raise AssertionError((name,*error.args)) from error
    for name,text in [('MD',source),('DOCX',docx_text),('PDF',pdf_text)]:
        assert not re.search(REMOVED_CONTENT,text,re.I),(name,re.findall(REMOVED_CONTENT,text,re.I))
        assert not re.search(NEGATIVE_PHRASES,text),(name,re.findall(NEGATIVE_PHRASES,text))
        assert not re.search(r'<sup>|\[\d+(?:[,–-]\d+)*\]',text),(name,'citation residue')
        assert not any(s in text for s in ['Error! Reference source not found','错误！未找到引用源','{width=','{height='])
    image_pages=[]
    image_count=0
    figure_numbers=[]
    toc_entries=0
    pdf_heading_spans=0
    pdf_caption_lines=0
    pdf_toc_spans=0
    for i,page in enumerate(pdf):
        body=page.get_text(clip=pymupdf.Rect(60,75,535,770))
        assert len(body.strip())>8 or page.get_image_info(),f'blank page {i+1}'
        infos=page.get_image_info()
        for block in page.get_text('dict')['blocks']:
            for line in block.get('lines',[]):
                line_text=''.join(s['text'] for s in line['spans'])
                if re.match(r'^[图表]\s*\d+\s*\u3000',line_text):
                    assert all('simhei' in s['font'].lower() for s in line['spans'] if s['text'].strip()),('PDF caption font',i+1,line)
                    pdf_caption_lines+=1
                for span in line['spans']:
                    # Display equations use enlarged operator glyphs; these
                    # remain mathematical fonts and are not report headings.
                    math_operator=re.fullmatch(r'[∑∏∫√]+',span['text'].strip())
                    if span['text'].strip() and span['size']>=14 and not math_operator:
                        assert 'simhei' in span['font'].lower(),('PDF heading font',i+1,span)
                        pdf_heading_spans+=1
        for info in infos:
            r=pymupdf.Rect(info['bbox'])
            assert r.x0>=89 and r.x1<=507 and r.y0>=65 and r.y1<=773,(i+1,r)
        if infos:
            captions=re.findall(r'图\s*(\d+)\s*\u3000',body)
            assert len(captions)==len(infos),f'detached caption page {i+1}'
            figure_numbers.extend(int(n) for n in captions)
            image_pages.append(i+1)
            image_count+=len(infos)
        for link in page.get_links():
            if link['kind']==pymupdf.LINK_GOTO:
                assert 0<=link['page']<len(pdf)
                visible=page.get_textbox(link['from'])
                match=re.search(r'(\d+)\s*$',visible)
                assert match,(i+1,visible)
                assert int(match[1])==link['page'],('stale TOC page',visible,link['page'])
                for block in page.get_text('dict',clip=link['from'])['blocks']:
                    for line in block.get('lines',[]):
                        for span in line['spans']:
                            if span['text'].strip():
                                assert 'simhei' in span['font'].lower(),('PDF TOC font',i+1,span)
                                pdf_toc_spans+=1
                toc_entries+=1
    assert image_count==8,image_pages
    assert figure_numbers==list(range(1,9)),figure_numbers
    assert toc_entries==expected_toc,(toc_entries,expected_toc)
    assert pdf_caption_lines==10,pdf_caption_lines
    assert pdf_toc_spans>=toc_entries,pdf_toc_spans
    table_pdf_pages=[]
    for markers in [('0x00000000','0x40610000','0x51000000'),('WB_DATA','0x0FC')]:
        matches=[i+1 for i,p in enumerate(pdf) if all(m in re.sub(r'\s+','',p.get_text()) for m in markers)]
        assert len(matches)==1,('split table',markers,matches)
        table_pdf_pages.extend(matches)
    proof=ROOT/'proofs'
    proof.mkdir(exist_ok=True)
    # Rendered page files correspond to the current PDF page count.
    for p in proof.iterdir():
        match=re.fullmatch(r'(page|sheet)-(\d+)\.png',p.name)
        if match:
            limit=len(pdf) if match[1]=='page' else (len(pdf)+3)//4
            if int(match[2])>limit:p.unlink()
    thumbs=[]
    for i,p in enumerate(pdf):
        pm=p.get_pixmap(matrix=pymupdf.Matrix(110/72,110/72),alpha=False)
        path=proof/f'page-{i+1:02d}.png';pm.save(path)
        im=Image.open(path).convert('RGB');im.thumbnail((595,842))
        thumbs.append(im)
    for start in range(0,len(thumbs),4):
        sheet=Image.new('RGB',(1230,1740),'#d9d9d9');draw=ImageDraw.Draw(sheet)
        for j,im in enumerate(thumbs[start:start+4]):
            x=10+(j%2)*615;y=22+(j//2)*870
            sheet.paste(im,(x,y));draw.text((x,y-16),f'PDF page {start+j+1}',fill='black')
        sheet.save(proof/f'sheet-{start//4+1:02d}.png')
    source_paths=[
        ORIGINAL_NPU,
        Path('/media/3/工作/CKS58/md_report_to_docx.py'),
        ROOT/'README.md',
        ROOT/'审查记录.md',
        ROOT/'audit_report.py',
        ROOT/'build_report.py',
        ROOT/'draw_figures.py',
        ROOT/'test_report_terminology.py',
        ROOT/'report_typography.py',
        Path('/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.srcs/sources_1/bd/bit_soc/bit_soc.bd'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.srcs/sources_1/new/dsa_npu/npu_axil_bd_wrapper.v'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.srcs/sources_1/new/dsa_npu/axi_inferred_shared_ram.sv'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/calibration/sensor_calibration_runtime_20261111_pre_release.cc'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/calibration/deploy_20261111_pre_release/model_data.S'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/usr_lib/ui.c'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.srcs/sources_1/new/dsa_npu/npu_axil_reg_if.sv'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.srcs/sources_1/new/dsa_npu/ia_loader_cache_mgr.sv'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.srcs/sources_1/new/dsa_npu/ws_systolic_cell.sv'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.srcs/sources_1/new/dsa_npu/axi_block_dma_arbiter.sv'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.srcs/sources_1/new/dsa_npu/vec_requant_s64.sv'),
        ROOT.parents[2]/'scripts/fpga/export_sensor_hw_platform.tcl',
        ROOT.parents[2]/'scripts/fpga/update_vitis_sensor_platform.py',
        ROOT.parents[2]/'scripts/fpga/merge_vu3p_sensor_elf.py',
        ROOT.parents[2]/'scripts/models/prepare_vu3p_sensor_models_20261108_coe.py',
        Path('/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/CMakeLists.txt'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/UserConfig.cmake'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/lscript.ld'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/main.c'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/vitis-comp.json'),
        Path('/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/tools/build_tflm_dsa.sh')]
    result={'body_han_characters':han,'chapters':11,'microblaze_deployment_sections':6,'pdf_pages':len(pdf),'figures':8,'tables':2,'table_cells_centered':len(cells),'table_vertical_alignment':'CENTER','table_horizontal_alignment':'CENTER','editable_equations':5,'editable_inline_equations':len(xml.xpath('//m:oMath',namespaces=NS))-5,'references':0,'citation_links':0,'toc_entries_checked':toc_entries,'image_pdf_pages':image_pages,'prohibited_word_hits':0,'negative_phrase_hits':0,'visible_date_or_version':'NONE','docx_structure':'PASS','pdf_automated_checks':'PASS','visual_review':'See 审查记录.md','sha256':{str(p):digest(p) for p in [BASE.with_suffix('.md'),BASE.with_suffix('.docx'),BASE.with_suffix('.pdf'),*source_paths]}}
    result['npu_original_image']={'source':str(ORIGINAL_NPU),'asset':str(asset),
        'pixels':list(pixels),'docx_media':npu_media,'sha256':digest(ORIGINAL_NPU),
        'unchanged_png_in_docx':'PASS','aspect_ratio':'PASS','display_rounding_tolerance_emu':635}
    result['table_pdf_pages']=table_pdf_pages
    result['tables_kept_on_single_page']='PASS'
    result['terminology_checks']={'user_prohibited_words':list(REPORT_PROHIBITED_WORDS),
        'user_prohibited_word_count':len(REPORT_PROHIBITED_WORDS),
        'agents_prohibited_expressions':list(AGENTS_PROHIBITED_EXPRESSIONS),
        'hits_by_surface':{name:0 for name in terminology_surfaces},
        'original_npu_figure':'UNCHANGED_USER_SUPPLIED_IMAGE'}
    result['restricted_term_checks']={
        'quantization':'ALLOWED_TECHNICAL_TERM',
        'convergence_allowed_phrase':'时序收敛',
        'boundary_policy':'REVIEW_EXACT_CONTEXT_FOR_PHYSICAL_OR_STRUCTURAL_SEPARATION',
        'surfaces':restricted_term_checks}
    result['heading_fonts']={'family':HEADING_FONT,'styles_checked':len(heading_style_ids),
        'paragraphs_checked':heading_paragraphs,'text_runs_checked':heading_runs,
        'pdf_large_heading_spans_checked':pdf_heading_spans,
        'pdf_caption_lines_checked':pdf_caption_lines,'pdf_toc_spans_checked':pdf_toc_spans,
        'theme_font_overrides':'NONE','docx_fonts':'PASS','pdf_fonts':'PASS'}
    (ROOT/'quality_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    # Package the current figure set and its editable drawing definitions.
    archive=ROOT/'插图与图源.zip'
    pending=ROOT/'插图与图源.tmp.zip'
    assets=figure_paths+[p.with_suffix('.svg') for p in figure_paths if p.with_suffix('.svg').exists()]
    with zipfile.ZipFile(pending,'w',zipfile.ZIP_DEFLATED) as z:
        for p in [ROOT/'draw_figures.py',ROOT/'diagram_audit.json',*assets]:
            z.write(p,p.relative_to(ROOT))
    pending.replace(archive)
    print(json.dumps({k:v for k,v in result.items() if k!='sha256'},ensure_ascii=False,indent=2))


if __name__=='__main__':main()
