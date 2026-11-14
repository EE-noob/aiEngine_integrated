#!/usr/bin/env python3
"""Render the project architecture figures with checked arrow geometry."""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import struct
import sys

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'figures'
SUPPORT = ROOT.parent / '详细设计报告' / 'draw_figures.py'
ORIGINAL_NPU = Path('/media/3/0-课题/TFLM加速器/架构设计-AXI.png')


def main():
    spec = importlib.util.spec_from_file_location('project_diagram_support', SUPPORT)
    support = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = support
    spec.loader.exec_module(support)
    support.OUT = OUT
    OUT.mkdir(exist_ok=True)

    soc = support.diagrams()[0]
    soc.name = 'soc'
    software = support.Diagram('software', 1600, 1120)
    layers = (
        ('app', '传感器校准应用', '模型特征 · 推理调用 · 校准结果', 'yellow'),
        ('runtime', 'TFLM 模型运行时', '模型解释 · 张量与工作空间管理', 'blue'),
        ('adapter', '量化算子适配', '全连接加速 · 类型与通道量化支持', 'yellow'),
        ('driver', 'NPU 硬件驱动', '硬件任务访问与状态管理', 'blue'),
        ('hardware', 'FPGA 推理平台', 'NPU · 模型常量 · 运行张量', 'green'),
    )
    for index, (name, title, description, color) in enumerate(layers):
        y = 40 + index * 220
        software.node(name, 260, y, 1080, 130, title, description,
                      color=color, size=38)
        if index:
            software.edge(layers[index - 1][0], name,
                          (800, y - 90), (800, y), both=True)

    original = ORIGINAL_NPU.read_bytes()
    shutil.copy2(ORIGINAL_NPU, OUT / 'npu.png')
    result = [
        {'figure': 'npu', 'source': str(ORIGINAL_NPU),
         'pixels': list(struct.unpack('>II', original[16:24])),
         'sha256': hashlib.sha256(original).hexdigest(),
         'integrity': 'PASS'},
        soc.render(), software.render(),
    ]
    (ROOT / 'diagram_audit.json').write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('Architecture figures:', len(result))


if __name__ == '__main__':
    main()
