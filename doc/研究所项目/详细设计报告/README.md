# 详细设计报告说明

主稿为 [NPU与传感器校准SoC详细设计技术报告.md](NPU与传感器校准SoC详细设计技术报告.md)，Word 和 PDF 使用相同文件名。报告包含 11 章、8 幅插图、2 张表格和 5 个独立可编辑公式。

报告介绍传感器校准任务、整数数值设计、SoC 结构、NPU 任务控制、加载缓存、脉动计算、DMA、重量化、软件栈、FPGA 部署和验证方法。SoC 设计以 Vivado 的 bit_soc 为依据，说明处理器、本地存储、互连、共享存储、外设、时钟和复位的连接。软件部分介绍 TFLM 的基本作用、张量分配、算子执行过程及全连接加速接口。部署部分说明 XSA 导出、Vitis 平台生成、静态库接入、模型初始化、ELF 生成和程序合并。

正文中的技术参数核对当前传感器 SoC 的硬件封装、Block Design、链接脚本、运行程序和构建脚本。电压、电流、湿度模型分别采用 18、12、7 个输入特征。模型常量以 TFLite FlatBuffer 保存，BRAM 提供模型初始化内容，UltraRAM 提供解释器运行空间。验证章节说明数值比较和时间测量的方法。

Word 排版调用 `/media/3/工作/CKS58/md_report_to_docx.py`。页面使用 A4，正文使用五号宋体和 Times New Roman，固定行距 20 磅；封面、各级标题、目录和图表题统一使用黑体。表格内容水平及垂直居中，公式以 OMML 保存，目录与页码由文档字段生成。PDF 用于核对分页、字体、图表位置和目录跳转。

在本目录运行：

```sh
python3 build_report.py
python3 test_report_terminology.py
python3 audit_report.py
```

`build_report.py` 生成插图、Word 和 PDF；`report_typography.py` 设置标题字体；`audit_report.py` 检查报告结构、用词、字体、表格、公式、目录和图像，并将页面渲染至 `proofs/`。语言规则覆盖正文、标题、表格、图内文字、说明文件以及 Word/PDF 提取文字，结果写入 `quality_audit.json`。

图 2 直接采用 `/media/3/0-课题/TFLM加速器/架构设计-AXI.png`，原始像素为 19750×12717，报告素材与 Word 内嵌文件保持相同字节内容。其余七幅图由 `draw_figures.py` 定义，使用圆角矩形、彩色圆角箭头和黑色轮廓，导出 SVG 与 PNG。`diagram_audit.json` 保存节点、箭头和文字的几何检查结果，`插图与图源.zip` 包含八幅 PNG、七幅 SVG 及绘图程序。

“量化”用于量化方法、量化误差和量化精度等技术描述。限制词按完整语境检查；检查程序中的词语清单与规则测试集中维护报告的语言要求。
