/*
 * kernel_loader 权重加载控制器设计说明（自主访存版本）
 * ------------------------------------------------------------
 * 功能概述:
 *  本模块负责面向分块矩阵运算，从外部存储器自主读取权重数据（RHS），并按行输出到脉动阵列。
 *  模块内部负责计算每个权重分块（Weight Tile）的访存地址、发起 ICB 读请求、缓存并按需输出权重。
 *  设计目标：支持权重在多个IA Tile间复用，完成一次权重Tile的发送后自动申请并加载下一批权重，以保证计算流水的连续性。
 *
 * 分块与存储格式（更新）:
 *  - 权重矩阵 B 的尺寸：K 行 × N 列（或写作 n × m，模块接口使用 n、m）
 *  - 外部存储格式：权重在外部存储中按列主序（column-major）排列，即内存中相邻元素沿列方向排列
 *    * 例如列主序：{w00, w10, w20, ..., w01, w11, w21, ...}
 *  - Weight Tile: k 行 × SIZE 列（k <= SIZE），模块读取时需根据列主序的布局按列或按块进行访存，并在内部缓冲中重排为按行输出格式
 *  - 输出格式：脉动阵列需要按行（row-major）接收权重，模块在读取并重排后按行输出
 *
 *  访存与地址生成策略（列主序考虑）：
 *  - 模块在 init_cfg 时锁存基地址（cfg_rhs_base）、行/列间距（cfg_rhs_row_stride_b）和分块尺寸
 *  - 对于列主序存储，计算每个 Weight Tile 的访存地址时需要以列为主的偏移步长：
 *      tile_base = cfg_rhs_base + tile_col * cfg_rhs_col_stride + tile_row * cfg_rhs_row_stride (按实现约定)
 *  - 实现上可以按列逐列读取 tile（每次读取 k 个连续元素），或按块化读取后在缓冲区内做重排
 *  - 读取完成后模块将数据重排为按行格式，然后置 weight_data_valid=1，表示当前 Tile 已准备好发送
 *
 * 自动重触发行为:
 *  - 在每次权重Tile的发送完成（weight_sending_done）后，模块自动增加 tile 索引并驱动 load_weight_req=1
 *  - 外部控制器通过 load_weight_granted 授权后，模块开始下一个 Weight Tile 的访存
 *  - 当所有 Weight Tile 读取并发送完成后，模块停止申请
 *
 * 信号语义与时序（关键）：
 *  - weight_out[SIZE]: 并行输出的一整行权重数据（signed [DATA_WIDTH-1:0]）
 *    * 在 store_weight_req=1 且发送周期内，weight_out 上的数据为有效，脉动阵列应在该周期采样
 *    * 对于矩阵边界处无效元素，应输出0或定义的填充值
 *  - store_weight_req: 与 weight_out 同步的有效指示，表示当前周期 weight_out 可被阵列加载
 *  - weight_data_valid: 指示内部已完成当前 Weight Tile 的全部行读取并可用于发送
 *  - weight_sending_done: 指示当前 Weight Tile 的逐行发送已全部完成（SEND 完结）
 *
 * ICB 及错误处理:
 *  - 模块作为 ICB Master 发起读命令，驱动 icb_cmd_m；从端通过 icb_cmd_s.ready/ icb_rsp_s 提供握手
 *  - 模块需检测并处理响应中的错误标志（若 icb_rsp_s 表示错误，则进入错误处理分支并向上层上报）
 *
 * 实现建议:
 *  - 在模块内部维护 tile_row_idx、tile_col_idx、current_tile_base、rows_to_read 等控制变量
 *  - 对列主序数据，可按列块读取并在内部缓冲区完成按行重排（transpose/pack）以便按行输出
 *  - 在 SEND 完成后立即设置 load_weight_req，等待 load_weight_granted 后开始读下一个tile
 *  - 将 weight_data_valid 与 store_weight_req/weight_sending_done 保持明确的握手顺序，避免竞态
 */

`include "define.svh"
`include "icb_types.svh"

module kernel_loader #(
    parameter int unsigned DATA_WIDTH = 8,   // 权重数据宽度
    parameter int unsigned SIZE       = 16,  // 阵列大小
    parameter int unsigned BUS_WIDTH  = 32,  // 总线宽度
    parameter int unsigned REG_WIDTH  = 32   // 配置寄存器宽度
) (
    // 时钟与复位
    input wire clk,   // 时钟信号
    input wire rst_n, // 异步复位，低有效

    // 配置控制接口
    input wire init_cfg,  // 触发配置参数锁存

    // 自动重触发控制接口
    output reg  load_weight_req,      // 申请下一次访存授权（输出到外部控制器）
    input  wire load_weight_granted,  // 外部控制器授权下一次访存（握手信号）
    input  wire send_weight_trigger,  // 触发发送权重到脉动阵列（单拍触发）

    // 矩阵尺寸与分块配置（在 init_cfg 时被锁存）
    input wire [REG_WIDTH-1:0] k,  // 输入激活矩阵行数
    input wire [REG_WIDTH-1:0] n,  // 输入激活矩阵列数
    input  wire [REG_WIDTH-1:0]        m,                 // 输出矩阵列数（LHS_COLS），用于计算是否为最后一个tile

    // 配置寄存器（在 init_cfg 时锁存）
    input wire signed [REG_WIDTH-1:0] rhs_zp,  // 权重零点（s32）
    input wire [REG_WIDTH-1:0] rhs_base,  // 权重数据基地址（第一个分块）
    input wire [REG_WIDTH-1:0] rhs_row_stride_b,  // 权重行间地址间距

    // ICB 主接口（模块作为 Master, 扩展三通道）
    output icb_ext_cmd_m_t icb_cmd_m,  // Master -> Slave: 命令有效载荷
    output icb_ext_wr_m_t  icb_wr_m,   // Master -> Slave: 写数据有效载荷
    input  icb_ext_cmd_s_t icb_cmd_s,  // Slave -> Master: 命令就绪
    input  icb_ext_wr_s_t  icb_wr_s,   // Slave -> Master: 写数据就绪
    input  icb_ext_rsp_s_t icb_rsp_s,  // Slave -> Master: 响应有效载荷
    output icb_ext_rsp_m_t icb_rsp_m,  // Master -> Slave: 响应就绪

    // 输出信号到脉动阵列
    output reg weight_sending_done,  // 权重发送完成
    output reg store_weight_req,  // 控制脉动阵列权重加载
    output reg signed [DATA_WIDTH-1:0] weight_out[SIZE],   // 输出到脉动阵列的权重（按行输出）

    // 新增输出：当完成所有权重读取时指示数据已准备好
    output reg weight_data_valid  // 所有权重数据已读取完毕并可用于发送
);

    // 状态定义
    typedef enum logic [1:0] {
        IDLE = 2'b00,  // 空闲状态
        LOAD = 2'b01,  // 读取权重数据状态
        SEND = 2'b10   // 发送权重数据状态
    } state_t;

    state_t     state;

    // ICB 命令与响应内部信号与连接（保持旧打包以便内部逻辑复用）
    icb_cmd_m_t icb_cmd_m_reg;  // 驱动可变字段的寄存器
    icb_cmd_m_t icb_cmd_m_wire;  // 由寄存器与常量 size 组合成的输出线网
    icb_rsp_m_t icb_rsp_m_wire_legacy;
    // 固定 size 字段为 2'b10，其余字段从寄存器取值
    assign icb_cmd_m_wire = '{
            icb_cmd_m_reg.valid,
            icb_cmd_m_reg.addr,
            icb_cmd_m_reg.read,
            icb_cmd_m_reg.wdata,
            icb_cmd_m_reg.wmask,
            2'b10
        };

    // 将旧版打包信号映射到扩展三通道端口
    assign icb_cmd_m.valid = icb_cmd_m_wire.valid;
    assign icb_cmd_m.addr = icb_cmd_m_wire.addr;
    assign icb_cmd_m.read = icb_cmd_m_wire.read;
    assign icb_cmd_m.len = 3'd0;  // 默认单拍

    assign icb_wr_m.w_valid = icb_cmd_m_reg.valid & (~icb_cmd_m_reg.read);
    assign icb_wr_m.wdata = icb_cmd_m_reg.wdata;
    assign icb_wr_m.wmask = icb_cmd_m_reg.wmask;

    // 响应就绪沿用旧版寄存器名
    assign icb_rsp_m = '{icb_rsp_m_wire_legacy.rsp_ready};

    // 权重缓冲区（按列主序存储）
    reg signed [DATA_WIDTH-1:0] weight_buffer[SIZE*SIZE];
    integer i, j;

    // 锁存的配置信号
    reg        [REG_WIDTH-1:0] cfg_n;
    reg        [REG_WIDTH-1:0] cfg_m;
    reg signed [REG_WIDTH-1:0] cfg_rhs_zp;
    reg        [REG_WIDTH-1:0] cfg_rhs_base;
    reg        [REG_WIDTH-1:0] cfg_rhs_row_stride_b;

    // 计数器与状态寄存器
    reg        [REG_WIDTH-1:0] load_row_count;
    reg        [REG_WIDTH-1:0] load_col_count;
    reg        [REG_WIDTH-1:0] cur_addr;

    // 配置参数锁存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_n                <= '0;
            cfg_m                <= '0;
            cfg_rhs_zp           <= '0;
            cfg_rhs_base         <= '0;
            cfg_rhs_row_stride_b <= '0;
        end else if (init_cfg) begin
            cfg_n                <= n;
            cfg_m                <= m;
            cfg_rhs_zp           <= rhs_zp;
            cfg_rhs_base         <= rhs_base;
            cfg_rhs_row_stride_b <= rhs_row_stride_b;
        end
    end

    // 状态机实现（待补充）

endmodule
