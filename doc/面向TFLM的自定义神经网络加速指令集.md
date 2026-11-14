# AI-DSA 指令扩展规范（Draft v0.3）

## 0. RISC-V 标准指令格式参考（Informative）

RISC-V 32 位基本 R-type / I-type 编码（低位在右）：

```
31           25 24      20 19      15 14   12 11      7 6         0
+---------------+----------+----------+--------+----------+----------+
|    funct7     |   rs2    |   rs1    | funct3 |    rd    |  opcode  |  R-type
+---------------+----------+----------+--------+----------+----------+

31           20 19      15 14   12 11      7 6         0
+---------------+----------+--------+----------+----------+
|     imm[11:0] |   rs1    | funct3 |    rd    |  opcode  |  I-type
+---------------+----------+--------+----------+----------+
```

> 本扩展采用自定义 opcode 空间（`CUSTOM_1`, `CUSTOM_3`），并遵循 **NICE** 对 `funct3` 的用法约束：  
> `funct3[2]`→是否写回 `rd`，`funct3[1]`→是否使用 `rs1`，`funct3[0]`→是否使用 `rs2`。

---

## 1. 约定与术语

- **NICE funct3 约定**  
    `funct3[2]=1` → 指令写回 `rd`；`funct3[1]=1` → 使用 `rs1`；`funct3[0]=1` → 使用 `rs2`。  
    译码示例（Verilog）：  
    `nice_need_rd = rv32_instr[14]; nice_need_rs1 = rv32_instr[13]; nice_need_rs2 = rv32_instr[12];`
    
- **矩阵符号**
    
    - A[M×K]：左乘数（行主语义，存储布局由实现与库接口决定）。
        
    - B[K×N]：右乘数。
        
    - 结果 C[M×N] 或向量形式（M=1）。
        
- **T/NT 约定**
    
    - `mat_mult_t` 语义固定 **NT×T**：A（非转置/原始）× B（以列主/转置视图参与运算）。
        
    - `vec_mat_t` 语义固定 **vec×T**：1×K 与 B[K×N]。
        
- **cfg（配置字）**  
    R-type 的 `rs2` 寄存器载入的 32 位配置值，仅描述“位宽/特性开关”。所有地址、尺寸、量化、激活等在 **CSR** 配置。
    
- **返回码**  
    所有运算类指令把 **状态码**写回 `rd`（0=成功；详见 §5）。
    

---

## 2. 指令编码

### 2.1 CSR 访问类（I-type, `CUSTOM_3`）

|指令|语法|opcode|funct3|语义|编码要点|
|---|---|---|---|---|---|
|`csrwr`|`csrwr rs1, imm12`|CUSTOM_3|`010`|`CSR[imm12] ← rs1`|I-type：`rd=x0`；未实现 CSR → 非法指令异常|
|`csrrd`|`csrrd rd, imm12`|CUSTOM_3|`100`|`rd ← CSR[imm12]`|I-type：`rs1=x0`；未实现 CSR → 非法指令异常|

> 说明：`imm12` 为 CSR 编号；实现需对未实现/保留编号抛出非法指令异常。

### 2.2 运算类（R-type, `CUSTOM_1`）

通用：`rd`=状态码；`rs1`=输出起始地址（byte 指针）；s`rs2`=cfg。

| 指令              | 语法                          | opcode   | funct7 | funct3（NICE） | rs2 含义    |
| --------------- | --------------------------- | -------- | ------ | ------------ | --------- |
| `mat_mult_t`    | `mat_mult_t rd, rs1, rs2`   | CUSTOM_1 | 0x01   | `111`        | cfg 配置字   |
| `dwconv_mult_4` | `dwconv_mult_4 rd, rs1, x0` | CUSTOM_1 | 0x04   | `110`        | cfg 配置字|

NICE 合规性：

- 需要 rd+rs1+rs2 → `funct3=0b111`；需要 rd+rs1 → `funct3=0b110`。
    
- 其它 `funct3` 编码为保留/非法（实现可直接触发非法指令异常）。
    

---

## 3. 配置字（cfg）定义（适用 `mat_mult_t`）

| 位段       | 名称/编码            | 描述                                                |
| -------- | ---------------- | ------------------------------------------------- |
| \[2:0]   | `OUT_W` 输出位宽     | 000=s4, 001=s8, 010=s16, 011=s32, 100=s64（饱和截断写回） |
| \[4:3]   | `BIAS_W` bias 位宽 | 00=s8, 01=s16, 10=s32, 11=s64                     |
| \[6:5]   | `B_W` 右乘数位宽      | 00=s4, 01=s8, 10=s16                              |
| \[8:7]   | `A_W` 左乘数位宽      | 00=s4, 01=s8, 10=s16                              |
| \[9]     | `PER_CH` 量化模式    | 0=per-tensor，1=per-channel                        |
| \[31:10] | 保留               | 写 0                                               |


**实现约束**

- `ROW_ADDR_OFFSET_EN=1` 时，必须预先正确配置 `MULT_ROW_ADDR_OFFSET`；否则返回错误码（§5）。
    

---

## 4. 指令语义

### 4.1 关联 CSR（摘录）

- **指针**：`MULT_LHS_PTR`、`MULT_RHS_PTR`、`MULT_DST_PTR`、`MULT_BIAS_PTR`、`MULT_KSUM_PTR`
    
- **偏移**：`MULT_LHS_OFFSET`、`MULT_RHS_OFFSET`、`MULT_DST_OFFSET`
    
- **量化**：
    
    - per-tensor：`MULT_DST_MULT`、`MULT_DST_SHIFT`
        
    - per-channel：`MULT_DST_MULT`、`MULT_DST_SHIFT` 可作为指针指向长度为 N 的数组（见 §3 寄存器映射）
        
- **尺寸/几何**：`MULT_LHS_ROWS(M)`、`MULT_RHS_COLS(K)`、`MULT_RHS_ROWS(N)`、`MULT_ROW_ADDR_OFFSET`
    
- **激活裁剪**：`MULT_ACT_MIN`、`MULT_ACT_MAX`
    
- **DWConv 专用**：`DW_*` 组（通道倍增/步幅/核形状等）
    

> 任一**必需 CSR** 缺失或地址为 0，返回 `0x02`（§5）。

### 4.2 `mat_mult_t`（A[M×K] × B[K×N]，NT×T）

- **入口**：  
    `rd`（写回状态码）、`rs1`=C[0] 起始地址（byte），`rs2`=cfg  
    CSR 提供：A/B/C 指针与偏移、M/K/N、量化参数、可选 row-addr-offset、激活阈值
    
- **语义（伪代码）**：
    
    ```c
    require(CSRs_valid());
    cfg = RS2;
    
    for m in 0..M-1:
      for n in 0..N-1:
        acc = (bias ? load_bias(n, BIAS_W) : 0);
    
        // 可选：row address offset（逐行基址修正）
        baseA = A_ptr + row_base(m, ROW_ADDR_OFFSET_EN ? MULT_ROW_ADDR_OFFSET : 0);
    
        // 主乘累加
        for k in 0..K-1:
          a = load_A(baseA, k, A_W, LHS_OFFSET);
          b = load_B(B_ptr, k, n, B_W, RHS_OFFSET); // B 以“列视图/转置视图”参与
          acc += (int32)a * (int32)b;
    
        // 量化 & 写回
        // 若 cfg 指定 per_channel，则从 MULT_DST_MULT/ MULT_DST_SHIFT（当作指针）加载对应通道的 mult/shift，
        // 否则直接使用作为标量的 MULT_DST_MULT / MULT_DST_SHIFT（per-tensor）。
        {mult,shift} = per_channel ? load_q(n) : {MULT_DST_MULT, MULT_DST_SHIFT};
        x = requantize(acc, mult, shift, OUT_W);
        x = clamp(x, ACT_MIN, ACT_MAX);
        store_C(C_ptr, m, n, x, OUT_W, DST_OFFSET);
    return OK;
    ```
    
- **注意事项**：
    
    - `OUT_W` 控制饱和写回位宽；`BIAS_W` 控制 bias 加法位宽。
        
    - `A_W/B_W` 允许 s4/s8/s16 组合，非法组合 → `0x01`。
        
    - per-channel 时，量化参数地址需有效，否则 `0x02`。
        
    - `ROW_ADDR_OFFSET_EN=1` 必须已设定 `MULT_ROW_ADDR_OFFSET`，否则 `0x03`。
        

### 4.3 `dwconv_mult_4`（Depthwise-Conv 4× 通道展开变体）

- **加速前置条件（全部满足才执行硬件加速）**：
    
    1. `ch_mult % 4 == 0`；2) `N == 1`（无 batch 扩展）；3) `dilation.w == 1 && dilation.h == 1`。  
- **语义概述**：
    
    - 输入特征图按 NHWC（实现可兼容 TFLM/NMSIS-NN 默认布局）；
        
    - 滑窗核逐像素执行通道独立的点乘与偏置、量化、激活；
        
    - 通道乘法（`ch_mult`）按 4 的倍数展开并行累加与写回。
        
- **配置**：尺寸、步幅、padding、指针、量化等均由 `DW_*` CSR 族提供；`rs2` 固定 `x0`。
    

---

## 5. 异常与错误码

### 5.1 非法指令异常（架构异常）

- 访问未实现/保留 CSR 编号（`csrrd/csrwr`）。
- 使用保留的 `funct3` 或保留 `funct7` 编码。
- 自定义空间以外的 opcode 误用。

> 说明：上述项属于架构级异常，由处理器直接触发非法指令或环境异常处理流程。

### 5.2 运行时返回码（写回到 `rd`）

为简化实现与软件处理，运行时返回码仅保留最必要的几类：

| 代码           | 含义                                       |
| ------------ | ---------------------------------------- |
| `0x00000000` | 成功                                       |
| `0x00000001` | 无效/不支持的配置或位宽/模式（包括非法位宽组合、算子模式不支持、几何不一致等） |
| `0x00000002` | 必需资源缺失或指针为 0（例如必需的 CSR/量化指针未配置或为 0）      |
| `0x00000003` | 资源暂时不可用 / 内部忙（可重试）                       |

> 说明：
> - 设计原则为用尽量少的返回码覆盖可区分的错误类别，便于软件端采取纠正、补救或重试策略。
> - 文档中此前引用的 `0x01`/`0x02`/`0x03` 语义已与此处对齐；实现若需更细粒度错误信息，应在实现内记录详细状态供调试使用，但对外仍返回上述简化码。

## 6. 反汇编与示例（推荐，非规范约束）

### 6.1 建议反汇编格式

- `mat_mult_t rd, rs1, rs2` ; `CUSTOM_1`/`funct7=0x01`/`funct3=0b111`
    
- `vec_mat_t rd, rs1, rs2` ; `CUSTOM_1`/`funct7=0x02`/`funct3=0b111`
    
- `dwconv_mult_4 rd, rs1` ; `CUSTOM_1`/`funct7=0x04`/`funct3=0b110`
    
- `csrwr rs1, imm12` ; `CUSTOM_3`/I-type/`funct3=0b010`
    
- `csrrd rd, imm12` ; `CUSTOM_3`/I-type/`funct3=0b100`
    

### 6.2 GCC inline 宏（供参考）

```c
enum { W_S4=0, W_S8=1, W_S16=2 };
enum { BIAS_S8=0, BIAS_S16=1, BIAS_S32=2, BIAS_S64=3 };
enum { OUT_S4=0, OUT_S8=1, OUT_S16=2, OUT_S32=3, OUT_S64=4 };

#define CFG_OUT_W(x)       ((uint32_t)(x) & 7u)
#define CFG_BIAS_W(x)      (((uint32_t)(x) & 3u) << 3)
#define CFG_B_W(x)         (((uint32_t)(x) & 3u) << 5)
#define CFG_A_W(x)         (((uint32_t)(x) & 3u) << 7)
#define CFG_PER_CH(b)      ((uint32_t)(!!(b)) << 9)
#define CFG_ROW_ADDR_EN(b) ((uint32_t)(!!(b)) << 10)

#define MATVEC_CFG(a_w,b_w,bias_w,out_w, per_ch, row_addr_en) \
  ( CFG_A_W(a_w) | CFG_B_W(b_w) | CFG_BIAS_W(bias_w) | CFG_OUT_W(out_w) | \
    CFG_PER_CH(per_ch) | CFG_ROW_ADDR_EN(row_addr_en) )

#define MAT_MULT_T(status_out, dst_ptr, cfg) \
  __asm__ volatile (".insn r CUSTOM_1, 0x7, %0, %1, %2, 0x01" \
                    : "=r"(status_out) : "r"(dst_ptr), "r"(cfg))

#define VEC_MAT_T(status_out, dst_ptr, cfg) \
  __asm__ volatile (".insn r CUSTOM_1, 0x7, %0, %1, %2, 0x02" \
                    : "=r"(status_out) : "r"(dst_ptr), "r"(cfg))

#define DWCONV_MULT_4(status_out, dst_ptr) \
  __asm__ volatile (".insn r CUSTOM_1, 0x6, %0, %1, x0, 0x04" \
                    : "=r"(status_out) : "r"(dst_ptr))
```

### 6.3 cfg 速用示例

- **常规 per-channel：s8×s8 + bias s32 → out s8；禁用行偏移**
    
    ```c
    uint32_t cfg = MATVEC_CFG(W_S8, W_S8, BIAS_S32, OUT_S8, /*per_ch=*/1, /*row_addr=*/0);
    ```
    
- **s8×s16 行偏移核：bias s32 → out s8；启用行偏移**
    
    ```c
    uint32_t cfg = MATVEC_CFG(W_S8, W_S16, BIAS_S32, OUT_S8, /*per_ch=*/1, /*row_addr=*/1);
    // 需配好 MULT_ROW_ADDR_OFFSET、MULT_DST_MULT_PTR/SHIFT_PTR 等 CSR
    ```
    

### 6.4 最小调用序（示意）

```c
// 1) 配 CSR（指针/尺寸/量化/激活/偏移等）
csrwr(MULT_LHS_PTR,   (uintptr_t)A);
csrwr(MULT_RHS_PTR,   (uintptr_t)B);
csrwr(MULT_DST_PTR,   (uintptr_t)C);
csrwr(MULT_LHS_ROWS,  M);
csrwr(MULT_RHS_COLS,  K);
csrwr(MULT_RHS_ROWS,  N);
csrwr(MULT_DST_MULT,  dst_mult);              // per-tensor 或 指向数组的指针（per-channel）
csrwr(MULT_DST_SHIFT, dst_shift);             // per-tensor 或 指向数组的指针（per-channel）
csrwr(MULT_ACT_MIN,   act_min);
csrwr(MULT_ACT_MAX,   act_max);
// 可选：per-channel / row offset
// 若 per-channel：csrwr(MULT_DST_MULT, (uintptr_t)mult_ptr); csrwr(MULT_DST_SHIFT, (uintptr_t)shift_ptr);
// csrwr(MULT_ROW_ADDR_OFFSET, ...);

// 2) 触发
uint32_t status;
uint32_t cfg = MATVEC_CFG(W_S8, W_S8, BIAS_S32, OUT_S8, 1 /*per_ch*/, 0 /*row_addr=*/);
MAT_MULT_T(status, /*dst_ptr=*/C, cfg);
// or: VEC_MAT_T(status, C, cfg);

// 3) 检查返回码
if (status != 0) { /* 处理错误 */ }
```

---

# 3 地址映射（Register Map）

## 3.0 总述（规范性）

**处理器假设**：RV32（XLEN=32）。  
**指针语义**：所有 `*_PTR` CSR 均为**字节地址**（byte address），指向对齐内存。  
**访问粒度**：除特别说明外，均为 **32-bit** 访问。  
**复位值**：未特别说明均为 **0x0000_0000**。  
**保留位（RES0/RES1）**：未定义位 **必须写 0、读出为 0**（RES0）。  
**非法值**：实现对非法值的处置见 §5（错误码）。  
**访问方式**：推荐使用本规范自定义的 `csrrd/csrwr`（CUSTOM_3）指令访问；若实现允许，也可通过标准 CSR 读写类指令（实现自定）。  
**对齐要求**：

- 指针：按其数据类型自然对齐（例如 s8 数据至少 1B 对齐；s16 → 2B；s32 → 4B）。
    
- 尺寸：`K`/`N` 等维度为非负整数；若硬件要求对齐（如 `aligned_num_col_a`），见对应 CSR 描述。  
    **生命周期**：运算类指令在取值时**快照**本组 CSR；指令执行中修改无效，直至下一条运算指令生效。
    

---

## 3.1 MULT 组（矩阵/向量×矩阵）参数 CSR

> 适用 `mat_mult_t` / `vec_mat_t`。如未特别指出，两指令共用同一组 CSR。

### 3.1.1 指针类

|    编号 | 名称              | 访问  | 复位  | 类型/单位           | 说明                              |
| ----: | --------------- | :-: | :-: | --------------- | ------------------------------- |
| 0x7C0 | `MULT_LHS_PTR`  | RW  |  0  | u32 / byte addr | A（LHS）基址；元素位宽由**指令**决定（s8/s16）。 |
| 0x7C1 | `MULT_RHS_PTR`  | RW  |  0  | u32 / byte addr | B（RHS）基址；按 **N×K 行主序**，元素 s8。   |
| 0x7C2 | `MULT_DST_PTR`  | RW  |  0  | u32 / byte addr | C（DST）写回基址；元素 s8。               |
| 0x7C3 | `MULT_BIAS_PTR` | RW  |  0  | u32 / byte addr | Bias（s32）数组；可为 0（无 bias）。       |

> 说明：指针类 `*_PTR` 若为 0 表示未提供。若当前 cfg/路径要求该指针，则运算应返回 `0x0000_0002`（参见 §5）。

### 3.1.2 尺寸/步进

|    编号 | 名称                     |  访问 |  复位 | 类型/单位           | 说明                                           |
| ----: | ---------------------- | :-: | :-: | --------------- | -------------------------------------------- |
| 0x7C4 | `MULT_LHS_ROWS`        |  RW |  0  | u32             | `K`（A 的行数）。                             |
| 0x7C5 | `MULT_RHS_COLS`        |  RW |  0  | u32             | `N`（B 的行数/内积长度）。                             |
| 0x7C6 | `MULT_RHS_ROWS`        |  RW |  0  | u32             | `M`（B 的列数/输出通道数）。                            |         |
| 0x7C7 | `MULT_ROW_ADDR_OFFSET` |  RW |  0  | u32 / byte step | 输出行写回步距（row stride；字节）。0 表示使用致密行步距 `N*1` 字节。 |
| 0x7C8 | `MULT_LHS_COLS_OFFSET` |  RW |  0  | u32 / byte step | A 行步距（相邻行首地址差；字节）。0 表示自动：s8→`K*1`，s16→`K*2`。 |
| 0x7C9 | `MULT_RHS_ROW_STRIDE`  |  RW |  0  | u32 / byte step | B 行步距（通常设为 `K_aligned * 1` 字节）。0 表示按该默认值推导。  |

> 说明：尺寸类字段必须满足实现对齐/范围要求。若 K/N/M 等尺寸不满足实现对齐或一致性约束，应返回 `0x0000_0003`（详见 §5）。

### 3.1.3 量化/激活/类型

|    编号 | 名称                | 访问  | 复位  | 类型/单位         | 说明                                                                     |
| ----: | ----------------- | :-: | :-: | ------------- | ---------------------------------------------------------------------- |
| 0x7CA | `MULT_LHS_OFFSET` | RW  |  0  | s32           | **A 的零点偏移（lhs_offset）**；**s8/s16 两种位宽下均参与计算**。                         |
| 0x7CB | `MULT_RHS_OFFSET` | RW  |  0  | s32           | **B 的零点偏移（rhs_offset）**；通常为 0（对称量化），预留扩展。                              |
| 0x7CC | `MULT_DST_OFFSET` | RW  |  0  | s32           | 输出零点（dst_offset）。                                                      |
| 0x7CD | `MULT_DST_MULT`   | RW  |  0  | s32 / u32 ptr | per-tensor 时为标量 mult；per-channel 时可存放指针（非 0 表示为地址，指向 N 元素的 mult 数组）。   |
| 0x7CE | `MULT_DST_SHIFT`  | RW  |  0  | s32 / u32 ptr | per-tensor 时为标量 shift；per-channel 时可存放指针（非 0 表示为地址，指向 N 元素的 shift 数组）。 |
| 0x7CF | `MULT_ACT_MIN`    | RW  |  0  | s32           | 激活下限。                                                                  |
| 0x7D0 | `MULT_ACT_MAX`    | RW  |  0  | s32           | 激活上限（需满足 `ACT_MIN ≤ ACT_MAX`）。                                         |
    
> 说明：
> - per-tensor：使用 `MULT_DST_MULT` 与 `MULT_DST_SHIFT`（标量）。
> - per-channel：`MULT_DST_MULT` 与 `MULT_DST_SHIFT` 字段应保存指针（非 0），指向各通道长度为 N 的数组；指针缺失或地址为 0 应导致返回码 `0x0000_0002`。

---

## 3.3 Depthwise Conv（DWConv）参数 CSR

> 适用 `dwconv_mult_4`。若不满足该指令的**前置条件**（§4.4），硬件须返回 `0x0000_0001`（不支持）。

### 3.3.1 索引表（概览）

|    编号 | 名称            | 访问  | 复位  | 类型/单位           | 简述（规范性）           |
| ----: | ------------- | :-: | :-: | --------------- | ----------------- |
| 0x7F0 | `DW_IN_PTR`   | RW  |  0  | u32 / byte addr | 输入特征图指针（s8，NHWC）  |
| 0x7F1 | `DW_KER_PTR`  | RW  |  0  | u32 / byte addr | Kernel 指针（s8）     |
| 0x7F2 | `DW_BIAS_PTR` | RW  |  0  | u32 / byte addr | Bias 指针（s32；允许 0） |
| 0x7F3 | `DW_OUT_PTR`  | RW  |  0  | u32 / byte addr | 输出特征图指针（s8）       |
| 0x7F4 | `DW_IN_X`     | RW  |  0  | u32             | 输入宽               |
| 0x7F5 | `DW_IN_Y`     | RW  |  0  | u32             | 输入高               |
| 0x7F6 | `DW_IN_CH`    | RW  |  0  | u32             | 输入通道              |
| 0x7F7 | `DW_OUT_CH`   | RW  |  0  | u32             | 输出通道              |
| 0x7F8 | `DW_CH_MULT`  | RW  |  0  | u32             | 通道倍增（ch_mult）     |
| 0x7F9 | `DW_KER_X`    | RW  |  0  | u32             | Kernel 宽          |
| 0x7FA | `DW_KER_Y`    | RW  |  0  | u32             | Kernel 高          |
| 0x7FB | `DW_PAD_X`    | RW  |  0  | u32             | Padding X         |
| 0x7FC | `DW_PAD_Y`    | RW  |  0  | u32             | Padding Y         |
| 0x7FD | `DW_STRIDE_X` | RW  |  0  | u32             | 步幅 X              |
| 0x7FE | `DW_STRIDE_Y` | RW  |  0  | u32             | 步幅 Y              |
| 0x7FF | `DW_SHFT_PTR` | RW  |  0  | u32 / byte addr | output_shift 数组指针 |
| 0x800 | `DW_MULT_PTR` | RW  |  0  | u32 / byte addr | output_mult 数组指针  |
| 0x801 | `DW_OUT_X`    | RW  |  0  | u32             | 输出宽               |
| 0x802 | `DW_OUT_Y`    | RW  |  0  | u32             | 输出高               |
| 0x803 | `DW_OUT_OFFS` | RW  |  0  | s32             | 输出零点（offset）      |
| 0x804 | `DW_IN_OFFS`  | RW  |  0  | s32             | 输入零点（offset）      |
| 0x805 | `DW_ACT_MIN`  | RW  |  0  | s32             | 激活下限              |
| 0x806 | `DW_ACT_MAX`  | RW  |  0  | s32             | 激活上限              |

### 3.3.2 字段语义与前置条件（规范性）

- **`dwconv_mult_4` 加速前置条件**（全部满足）：
    
    1. `DW_CH_MULT % 4 == 0`；
        
    2. `N == 1`（本算子无 batch 展开；实现以单图像为单位）；
        
    3. 膨胀 `dilation.{x,y} == 1`（本规范不经由 CSR 暴露膨胀，固定为 1）。  
        不满足时返回 `0x0000_0001`。
        
- **量化参数**：`DW_MULT_PTR`/`DW_SHFT_PTR` 指向长度为 **`DW_OUT_CH`** 的数组；缺失 → `0x02`。
    
- **几何一致性**：`DW_OUT_X/Y` 应与由输入/步幅/填充/Kernel 推导的尺寸一致；不一致 → `0x03`。
    
- **通道一致性**：若 `DW_OUT_CH != DW_IN_CH * DW_CH_MULT` → `0x03`。
    
- **零点与激活**：按 s32 提供；最终裁剪至 s8 写回。
    
- **布局**：默认 NHWC；若实现支持其他布局，应由实现文档说明额外 CSR 或模式位（本规范不展开）。
    

---

## 3.4 编程模型（信息性，推荐）

### 3.4.1 MULT 最小配置序（per-tensor）

1. 设置 A/B/C 指针与偏移：`MULT_LHS_PTR/_RHS_PTR/_DST_PTR`，`MULT_LHS_OFFSET/_RHS_OFFSET/_DST_OFFSET`。
    
2. 设置尺寸：`MULT_LHS_ROWS=M`，`MULT_RHS_COLS=K`，`MULT_RHS_ROWS=N`。
    
3. 设置量化（per-tensor）：`MULT_DST_MULT`，`MULT_DST_SHIFT`。
    
4. 可选：激活裁剪 `MULT_ACT_MIN/MAX`；行偏移核则设置 `MULT_ROW_ADDR_OFFSET` 与相关专用 CSR。
    
5. 发起：`mat_mult_t` 或 `vec_mat_t`（cfg 由 §3 参数与 §2 cfg 位宽匹配）。
    

### 3.4.2 MULT per-channel 差异

- 第 3 步改为：将 `MULT_DST_MULT`、`MULT_DST_SHIFT` 写为指针，指向 **N** 元素数组，并在 cfg 中置 `PER_CH=1`（当作 pointer 使用）。
- 其余同上。
    

### 3.4.3 DWConv 最小配置序

1. 设置 `DW_IN_PTR/_KER_PTR/_BIAS_PTR/_OUT_PTR` 与零点/激活。
    
2. 设置输入/卷积几何：`DW_IN_X/Y/CH`、`DW_KER_X/Y`、`DW_PAD_X/Y`、`DW_STRIDE_X/Y`、`DW_CH_MULT`，以及派生一致的 `DW_OUT_X/Y/CH`。
    
3. 量化：`DW_MULT_PTR`、`DW_SHFT_PTR`（长度 = `DW_OUT_CH`）。
    
4. 发起：`dwconv_mult_4`。若前置条件不满足，返回 `0x01`。

