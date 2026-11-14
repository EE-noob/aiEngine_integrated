#!/usr/bin/env python3
"""Editable diagram definitions, SVG/PNG export, and geometry checks.

Palette and outlined rounded arrows follow 架构设计-AXI.png supplied by user.
Seven diagrams are editable here; figure 2 uses the supplied PNG unchanged.
"""
from __future__ import annotations

import html
import hashlib
import json
import math
import shutil
import struct
import subprocess
from dataclasses import dataclass
from pathlib import Path

from PIL import ImageFont
from shapely.geometry import LineString, Point, box as polygon_box

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "figures"
ORIGINAL_NPU = Path("/media/3/0-课题/TFLM加速器/架构设计-AXI.png")
PALETTE = {"blue": "#C6E4F0", "yellow": "#FFF2CC", "green": "#A7D5A3", "red": "#FF6272"}
FONT = "/usr/share/fonts/truetype/NotoSansCJKsc-VF.otf"
INK = "#191919"


@dataclass
class Node:
    name: str
    x: float
    y: float
    w: float
    h: float
    lines: tuple[str, ...]
    color: str = "yellow"
    size: int = 32


@dataclass
class Edge:
    source: str
    target: str
    points: tuple[tuple[float, float], ...]
    color: str = "blue"
    both: bool = False


class Diagram:
    def __init__(self, name, width, height):
        self.name, self.width, self.height = name, width, height
        self.nodes: list[Node] = []
        self.edges: list[Edge] = []
        self.labels: list[tuple[float, float, str, int]] = []
        self.containers = []

    def node(self, name, x, y, w, h, *lines, color="yellow", size=32):
        self.nodes.append(Node(name, x, y, w, h, tuple(lines), color, size))
        return self

    def edge(self, source, target, *points, color="blue", both=False):
        self.edges.append(Edge(source, target, tuple(points), color, both))
        return self

    def label(self, x, y, text, size=28):
        self.labels.append((x, y, text, size))
        return self

    @staticmethod
    def text_extent(x, y, text, size):
        font = ImageFont.truetype(FONT, size)
        font.set_variation_by_name('Bold')
        width = font.getlength(text)
        return polygon_box(x-width/2, y-size*.55, x+width/2, y+size*.55)

    def text_items(self):
        items = []
        for n in self.nodes:
            spacing = n.size * 1.20
            for i, line in enumerate(n.lines):
                cy = n.y+n.h/2 + (i-(len(n.lines)-1)/2)*spacing
                size = n.size if i == 0 else n.size-3
                rect = self.text_extent(n.x+n.w/2, cy, line, size)
                items.append((n.name, n.x+n.w/2, cy, line, size, rect))
        for x, y, text, size in self.labels:
            items.append((None, x, y, text, size, self.text_extent(x,y,text,size)))
        return items

    def audit(self):
        nodes = {n.name: n for n in self.nodes}
        rects = {n.name: polygon_box(n.x,n.y,n.x+n.w,n.y+n.h) for n in self.nodes}
        failures = []
        text_items = self.text_items()
        for owner, _, _, text, _, rect in text_items:
            if owner and not rects[owner].buffer(-18).covers(rect):
                failures.append(f"text outside safe node area: {owner}: {text}")
            if not polygon_box(8,8,self.width-8,self.height-8).covers(rect):
                failures.append(f"text outside canvas: {text}")
            for x,y,w,h in self.containers:
                if polygon_box(x,y,x+w,y+h).boundary.buffer(5).intersects(rect):
                    failures.append(f"text touches container border: {text}")
        for i, n in enumerate(self.nodes):
            for other in self.nodes[i+1:]:
                if rects[n.name].intersects(rects[other.name]):
                    failures.append(f"overlapping nodes: {n.name}, {other.name}")
        paths = []
        for e in self.edges:
            p = LineString(e.points)
            paths.append(p)
            for ident, xy in [(e.source,e.points[0]),(e.target,e.points[-1])]:
                n = nodes[ident]
                x,y = xy
                valid = ((abs(x-n.x)<.01 or abs(x-n.x-n.w)<.01) and n.y+25 <= y <= n.y+n.h-25) or ((abs(y-n.y)<.01 or abs(y-n.y-n.h)<.01) and n.x+25 <= x <= n.x+n.w-25)
                if not valid:
                    failures.append(f"endpoint outside straight node edge: {ident}: {xy}")
            for n in self.nodes:
                if n.name not in (e.source,e.target) and p.buffer(11).intersects(rects[n.name]):
                    failures.append(f"arrow enters unrelated node: {e.source}->{e.target}: {n.name}")
            for owner, _, _, text, _, rect in text_items:
                if p.buffer(15).intersects(rect):
                    failures.append(f"arrow overlaps text: {e.source}->{e.target}: {text}")
            for a,b in zip(e.points,e.points[1:]):
                if a[0]!=b[0] and a[1]!=b[1]:
                    failures.append(f"nonorthogonal route: {e.source}->{e.target}")
                if math.dist(a,b)<40:
                    failures.append(f"short route segment: {e.source}->{e.target}")
        for i,p in enumerate(paths):
            for j,q in enumerate(paths[i+1:],i+1):
                if p.buffer(10).intersects(q.buffer(10)):
                    failures.append(f"arrows intersect or lack separation: {i+1}, {j+1}")
        # Free labels must remain wholly outside all module boxes and other labels.
        for i, item in enumerate(text_items):
            owner,_,_,text,_,rect = item
            if owner is None:
                for name,nr in rects.items():
                    if nr.intersects(rect): failures.append(f"label enters node: {text}: {name}")
            for other in text_items[i+1:]:
                if rect.intersects(other[-1]): failures.append(f"text overlap: {text}: {other[3]}")
        if failures:
            raise ValueError(self.name+"\n"+"\n".join(failures))
        return {"figure":self.name,"nodes":len(nodes),"arrows":len(paths),"text_items":len(text_items),"geometry":"PASS"}

    @staticmethod
    def rounded_path(points, radius=24):
        out = [f"M {points[0][0]} {points[0][1]}"]
        for prev,corner,nxt in zip(points,points[1:],points[2:]):
            a,b=math.dist(prev,corner),math.dist(corner,nxt)
            r=min(radius,a/2,b/2)
            p=(corner[0]+(prev[0]-corner[0])*r/a,corner[1]+(prev[1]-corner[1])*r/a)
            q=(corner[0]+(nxt[0]-corner[0])*r/b,corner[1]+(nxt[1]-corner[1])*r/b)
            out += [f"L {p[0]:.2f} {p[1]:.2f}",f"Q {corner[0]} {corner[1]} {q[0]:.2f} {q[1]:.2f}"]
        out.append(f"L {points[-1][0]} {points[-1][1]}")
        return " ".join(out)

    def render(self):
        result=self.audit()
        out=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}">',f'<title>{html.escape(self.name)}</title>', '<rect width="100%" height="100%" fill="white"/>','<defs>']
        for k,color in PALETTE.items():
            out.append(f'<marker id="{k}" markerUnits="userSpaceOnUse" markerWidth="28" markerHeight="26" refX="28" refY="13" orient="auto-start-reverse"><path d="M 1 1 L 28 13 L 1 25 L 6 13 Z" fill="{color}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/></marker>')
        out.append('</defs>')
        for x,y,w,h in self.containers:
            out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="30" fill="white" stroke="{INK}" stroke-width="3"/>')
        for e in self.edges:
            d=self.rounded_path(e.points)
            out.append(f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>')
            start=f' marker-start="url(#{e.color})"' if e.both else ''
            out.append(f'<path d="{d}" fill="none" stroke="{PALETTE[e.color]}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" marker-end="url(#{e.color})"{start}/>')
        for n in self.nodes:
            out.append(f'<rect id="{n.name}" x="{n.x}" y="{n.y}" width="{n.w}" height="{n.h}" rx="25" fill="{PALETTE[n.color]}" stroke="{INK}" stroke-width="3"/>')
        for _,x,y,text,size,_ in self.text_items():
            out.append(f'<text x="{x}" y="{y}" text-anchor="middle" dominant-baseline="central" fill="{INK}" font-family="Noto Sans CJK SC" font-weight="700" font-size="{size}">{html.escape(text)}</text>')
        out.append('</svg>')
        svg=OUT/(self.name+'.svg')
        svg.write_text('\n'.join(out)+'\n',encoding='utf-8')
        subprocess.run(['inkscape',str(svg),'--export-type=png',f'--export-filename={svg.with_suffix(".png")}','--export-width=2400'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        return result


def flow(name, labels, colors=None):
    d=Diagram(name,1600,610)
    xs=[40,440,840,1240]
    colors=colors or ['blue','blue','yellow','yellow','blue','yellow','green','green']
    for i,lines in enumerate(labels):
        col=i if i<4 else 7-i
        d.node(f'n{i}',xs[col],70 if i<4 else 400,320,140,*lines,color=colors[i],size=34)
    for i in range(7):
        if i<3:
            d.edge(f'n{i}',f'n{i+1}',(xs[i]+320,140),(xs[i+1],140),color='green')
        elif i==3:
            d.edge('n3','n4',(1400,210),(1400,400),color='green')
        else:
            col=7-i
            d.edge(f'n{i}',f'n{i+1}',(xs[col],470),(xs[col-1]+320,470),color='green')
    return d


def diagrams():
    ds=[]
    d=Diagram('图01-SoC总体架构',1600,1130)
    d.node('lmb',80,70,360,140,'本地程序与数据 BRAM','LMB · 512 KiB',color='blue')
    d.node('cpu',620,70,360,140,'MicroBlaze V','RISC-V 控制处理器',color='red')
    d.node('npu',1190,70,330,140,'DSA NPU','16×16 · INT32 累加')
    d.node('axi',80,410,1440,130,'AXI Interconnect','2 个主设备输入 · 16 个从设备输出',color='green',size=36)
    d.node('periph',80,750,370,160,'传感器与显示外设','I²C / SPI / GPIO','UART / 定时器 / 中断')
    d.node('ctrl',610,750,380,160,'AXI BRAM 控制器','单控制器 · 32 位','CPU / NPU 共享访问',color='blue')
    d.node('ram',1110,750,410,160,'共享 URAM / BRAM','模型常量与运行张量','统一逻辑地址')
    d.node('io',80,1010,370,90,'实际传感器 / OLED',color='blue')
    d.edge('lmb','cpu',(440,140),(620,140),both=True).label(530,102,'LMB')
    d.edge('cpu','axi',(800,210),(800,410),color='blue').label(675,310,'AXI 主访问')
    d.edge('axi','npu',(1270,410),(1270,210),color='red').label(1140,310,'AXI-Lite')
    d.edge('npu','axi',(1400,210),(1400,410),color='green').label(1500,310,'AXI4 DMA',size=26)
    d.edge('axi','periph',(265,540),(265,750),both=True).label(390,645,'外设访问')
    d.edge('axi','ctrl',(800,540),(800,750),color='green',both=True).label(930,645,'共享存储访问')
    d.edge('ctrl','ram',(990,830),(1110,830),color='green',both=True).label(1050,790,'RAM',size=26)
    d.edge('periph','io',(265,910),(265,1010),both=True)
    d.label(990,1040,'推理主通路共同使用 125 MHz 时钟',size=32)
    ds.append(d)

    ds.append(flow('图03-任务执行流程',[
        ('软件提交任务','地址 / 尺寸 / 参数'),('配置锁存与检查','清除旧状态'),('加载与分块计算','缓存 / 阵列 / 部分和'),('缩放与结果打包','类型与激活限幅'),
        ('发出输出写事务','数据 / 字节使能'),('等待全部写响应','在途事务计数归零'),('置位完成状态','done / error'),('CPU 使用输出','进入后续算子或应用')]))

    d=Diagram('图04-加载与缓存',1500,900)
    d.node('dma',550,40,400,120,'DMA 读引擎与仲裁','共享存储 → 各读取客户端',color='green')
    for name,x,lines in [('ia',80,('输入激活加载','行步长 / INT8 或 INT16')),('w',565,('权重加载','按输出通道取连续权重')),('p',1050,('偏置与缩放参数读取','INT32 偏置 / 通道参数'))]:
        d.node(name,x,350,370,140,*lines)
    d.node('ic',80,650,370,160,'输入激活缓存','分块复用 / 发送次序',color='blue')
    d.node('wc',565,650,370,160,'权重缓存','装入 / 驻留 / 复用',color='blue')
    d.node('pc',1050,650,370,160,'通道参数寄存器','偏置 / 乘数 / 移位',color='blue')
    d.edge('dma','ia',(650,160),(650,245),(265,245),(265,350),color='green')
    d.edge('dma','w',(750,160),(750,350),color='green')
    d.edge('dma','p',(850,160),(850,245),(1235,245),(1235,350),color='green')
    for a,b,x in [('ia','ic',265),('w','wc',750),('p','pc',1235)]:d.edge(a,b,(x,490),(x,650))
    d.label(750,860,'有效数据、通道编号与当前分块一致',size=30)
    ds.append(d)

    d=Diagram('图05-计算与部分和',1500,920)
    d.node('in',80,70,350,140,'输入激活与权重','按阵列时序发送')
    d.node('bias',1050,70,350,140,'INT32 偏置','首次累加初始化',color='blue')
    d.node('array',560,350,380,160,'脉动阵列与加法选择','INT32 乘累加')
    d.node('ps',560,690,380,150,'部分和缓存','内积分块 / 输出块位置',color='blue')
    d.node('out',1050,690,350,150,'最终结果向量','进入重量化流水')
    d.edge('in','array',(255,210),(255,430),(560,430))
    d.edge('bias','array',(1225,210),(1225,430),(940,430))
    d.edge('array','ps',(680,510),(680,690)).label(560,600,'保存中间结果',size=26)
    d.edge('ps','array',(820,690),(820,510)).label(895,600,'回送',size=26)
    d.edge('ps','out',(940,765),(1050,765)).label(995,725,'最终',size=26)
    ds.append(d)

    d=Diagram('图06-输出处理',1500,690)
    d.node('acc',60,240,320,170,'INT32 加偏置结果','有效标志 / 分块结束',color='blue')
    d.node('s8',500,60,340,150,'INT8 缩放通路','乘数 / 移位 / 输出偏移','激活与类型限幅')
    d.node('s16',500,440,340,150,'INT16 缩放通路','扩展 / 乘法 / 舍入','移位与激活限幅')
    d.node('fifo',1000,240,420,170,'类型对应的输出 FIFO','32 位打包 / WSTRB','有效行列数',color='blue')
    d.node('writer',1000,540,420,110,'OA Writer / AXI 写回','数据写入与响应等待',color='green')
    d.edge('acc','s8',(380,285),(440,285),(440,135),(500,135))
    d.edge('acc','s16',(380,365),(440,365),(440,515),(500,515))
    d.edge('s8','fifo',(840,135),(920,135),(920,285),(1000,285))
    d.edge('s16','fifo',(840,515),(920,515),(920,365),(1000,365))
    d.edge('fifo','writer',(1210,410),(1210,540),color='green')
    ds.append(d)

    ds.append(flow('图07-软件栈',[
        ('传感器应用','采集与有效性检查'),('特征与输入张量','顺序 / 归一化 / 量化'),('TFLM 运行时','图执行 / 张量管理'),('全连接算子适配','加速内核接口'),
        ('NPU 驱动','配置 / 启动 / 轮询'),('真实 NPU 执行','DMA / 阵列 / 写回'),('输出反量化','各分支独立尺度'),('校准结果使用','OLED / UART 调试')]))

    d=Diagram('图08-验证流程',1600,660)
    xs=[40,440,840,1240]
    titles=[('RAM 读写检查','地址 / 字节 / 时序'),('NPU 单算子','真实硬件整数结果'),('处理器软件提交','寄存器 / 启动 / 状态'),('完整模型推理','相同整数特征输入')]
    checks=[('数据返回一致','连续读取 / 字节写入'),('逐元素比较','尾块 / 通道参数 / 反压'),('确实发生硬件调用','DMA 访问与输出写回'),('执行与校准误差','分别统计物理量单位')]
    for i,x in enumerate(xs):
        d.node(f't{i}',x,100,320,140,*titles[i],size=33)
        d.node(f'c{i}',x,450,320,140,*checks[i],color='blue',size=32)
        d.edge(f't{i}',f'c{i}',(x+160,240),(x+160,450),color='green')
        if i<3:d.edge(f't{i}',f't{i+1}',(x+320,170),(xs[i+1],170),color='green')
    d.label(800,35,'真实硬件执行结果与离线期望值逐项比较',size=30)
    ds.append(d)
    return ds


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    results=[d.render() for d in diagrams()]
    # Preserve the user-controlled raster source byte for byte, without redrawing,
    # cropping, downsampling or changing its labels. Word scales display only.
    original=ORIGINAL_NPU.read_bytes()
    assert original[:8]==b'\x89PNG\r\n\x1a\n'
    target=OUT/'图02-NPU总体架构.png'
    shutil.copy2(ORIGINAL_NPU,target)
    assert target.read_bytes()==original
    results.insert(1,{
        'figure':'图02-NPU总体架构',
        'source':str(ORIGINAL_NPU),
        'sha256':hashlib.sha256(original).hexdigest(),
        'pixels':list(struct.unpack('>II',original[16:24])),
        'integrity':'PASS',
        'geometry':'USER_SUPPLIED_ORIGINAL_UNCHANGED',
    })
    # Remove only the generated assets belonging to the deleted deployment
    # figure and the superseded verification figure number.
    for name in ('图08-部署流程','图09-验证流程'):
        for suffix in ('.svg','.png'):
            stale=OUT/(name+suffix)
            if stale.exists():
                stale.unlink()
    (ROOT/'diagram_audit.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(results,ensure_ascii=False,indent=2))


if __name__=='__main__': main()
