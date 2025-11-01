/*
 * ia_loader 输入激活加载控制器设计说明（自主访存版本）
 * ------------------------------------------------------------
 * 功能概述:
 *  本模块负责面向分块矩阵运算，从外部存储器自主读取输入激活（IA），并按行输出到脉动阵列。
 *  模块内部完全控制IA Tile的访存与重用逻辑，通过多个IA Tile的部分和累加得到一个OA Tile。
 *  设计目标：在最少访存次数下满足脉动阵列的吞吐，支持IA Tile在不同Weight Tile间的重复使用。
 *
 * 分块访存策略（简要）:
 *  使用常见的Tile化矩阵乘法策略：C[M×N] = A[M×K] × B[K×N]
 *  - IA矩阵(A): M行K列（输入激活）
 *  - Weight矩阵(B): K行N列（权重）
 *  - OA矩阵(C): M行N列（输出）
 *
 *  术语:
 *   - SIZE: 脉动阵列的行/列宽度（通常为16），模块参数 SIZE 即脉动阵列规格
 *   - IA Tile: 尺寸为 SIZE 行 × k 列 的输入子块（k <= SIZE）
 *   - Weight Tile: 尺寸为 k 行 × SIZE 列
 *   - OA Tile: 尺寸为 SIZE 行 × SIZE 列
 *
 *  重要推导:
 *   - ia_tiles_per_oa_row = ceil(K / k)          // 为覆盖 K 维度每个OA行需的IA Tile数
 *   - weight_tiles_per_oa_col = ceil(N / SIZE)   // 每个OA列需要的Weight Tile数
 *   - 每个IA Tile 会被重复使用 weight_tiles_per_oa_col 次（与不同的Weight Tile相乘）
 *   - 总的IA访存次数（对于一个OA Tile）= ia_tiles_per_oa_row * weight_tiles_per_oa_col
 *
 * 工作流程（高层）：
 *  1) 配置阶段（init_cfg）
 *     - 锁存所有需要的寄存器：k、n、m、lhs_base、lhs_row_stride_b、lhs_zp、ia_use_offset、use_16bits
 *     - 根据 k、SIZE、N 等计算 ia_tiles_per_oa_row 与 weight_tiles_per_oa_col 等访存参数
 *
 *  2) 自主Load阶段（模块内部驱动 ICB）
 *     - 根据当前 IA Tile 索引计算基地址（cfg_lhs_base + tile_row * lhs_row_stride_b + col_offset）
 *     - 发起连续的 ICB 读请求，读取一个 IA Tile 的所有行数据（每行包含 k 个元素）
 *     - 将读取的数据缓存到内部行缓冲或Tile缓冲中；当完整Tile可用时置 ia_data_valid=1
 *
 *  3) Send阶段（外部通过 send_ia_trigger 启动逐行发送）
 *     - 当 ia_data_valid=1 且收到 send_ia_trigger 后，模块进入发送阶段（SEND）
 *     - 每个时钟周期输出一行 IA 数据到 ia_out，同时将 ia_row_valid 置1 表示该周期数据有效
 *     - 发送持续 tile 内的行数（最多 SIZE 行，实际行数由矩阵边界决定）
 *     - ia_calc_done: 指示该行为生成最终OA所需的最后一次部分和（用于阵列控制决定是否写回）
 *     - ia_sending_done: 在发送完整个 IA Tile 后置1
 *
 *  4) 自动重触发与重用策略
 *     - 模块维护 current_ia_tile 与 reuse_count
 *     - 若同一 IA Tile 需与下一个 Weight Tile 复用，则不重新访存，仅重复发送已缓存数据；否则发起下一次Load
 *     - 通过 load_ia_req / load_ia_granted 完成与外部调度器的交互（模块可在获得授权后开始下一个访存）
 *
 * 信号语义与时序（关键）:
 *  - ia_out [SIZE]: 并行输出的一整行 IA 数据（signed [DATA_WIDTH-1:0]）
 *      * 在 ia_row_valid=1 的周期内，ia_out 上的数据为有效，并可被脉动阵列采样
 *      * 对于未有效元素（矩阵边界处），应由模块在输出时填充0或保持定义的填充值
 *  - ia_row_valid: 与 ia_out 同步的有效指示信号
 *      * 在SEND状态且当模块在某周期输出一行有效数据时置1
 *      * 非发送周期（IDLE/LOAD/行间空闲）保持0，接收方不得采样 ia_out
 *  - ia_data_valid: 指示内部已经完成当前 IA Tile 的全部行读取并可用于发送（Load->Send 的条件）
 *      * ia_data_valid 与 ia_calc_done 保持一致：当 ia_data_valid 为高时，ia_calc_done 同步为高，且两者在相同周期范围内持续输出
 *      * 接收方或上层控制逻辑可使用该组合信号确认当前Tile可用于参与最终OA的部分和累加
 *  - ia_is_init_data: 指示当前Tile是否为该OA累加序列中的第一个IA Tile（用于累加器清零判断）
 *      * 当为第一个IA Tile时，在该Tile的整个数据有效周期内（与 ia_data_valid 相同）输出高电平，接收阵列可据此清零或初始化累加器
 *      * 该信号应与 ia_data_valid/ia_row_valid 同步输出，以避免采样竞态
 *  - ia_sending_done: 指示当前 IA Tile 的逐行发送已全部完成（SEND 完结）
 *  - ia_calc_done: 与 ia_data_valid 同步（见上），用于标记当前Tile在计算流程中的特殊语义（例如表明该Tile为最后一次用于某输出元素的部分和）
 *
 * 重加载逻辑（Reloading）：
 *  - 当一个 IA Tile 的逐行发送完成并且 ia_sending_done 置1 时，模块应自动驱动 load_ia_req=1，申请下一次访存授权。
 *  - 在收到外部调度器的 load_ia_granted 授权后，模块计算下一个 IA Tile 的基地址（基于 cfg_lhs_base 与 tile 索引、cfg_lhs_row_stride_b 等）并进入 LOAD 状态发起读请求。
 *  - 若同一 IA Tile 需被重复使用（reuse_count 未达到重复次数），模块可在不发起新的访存情况下，直接重复发送已缓存的数据；只有在确实需要新的 IA Tile 时才申请新的访存。
 *  - 该自动重触发机制保证在权重Tile切换或重用完成后，模块能连续驱动访存以维持计算流水线的连续性。
 *
 * 边界数据处理（Zero-padding 与 Skip）：
 *  - 在矩阵边界处，某些 Tile 的实际有效行或列可能少于 SIZE 或 k。模块必须在访存与输出时兼顾效率与正确性：
 *    * 跳过完全无效的行/列：对于完全超出原矩阵范围的行/列，模块可以跳过对应的访存操作以节省带宽与延迟。
 *    * 局部读取并补零：对于部分有效的行/列（例如最后一个tile只含部分列），模块应读取有效元素并在内部缓冲中对剩余位置填充0，以保证向阵列输出固定宽度的数据。
 *    * 发送时补零：在 SEND 阶段输出 ia_out，所有无效元素应确保为0或其它约定的填充值，ia_row_valid 在这些周期仍然表明该周期输出有效（但包含填充值）。
 *  - 在跳过访存的场景下，需保证 ia_data_valid、ia_sending_done 时序仍然正确，避免上层误判数据准备或发送完成。
 */

`include "define.svh"
`include "icb_types.svh"

// 输入激活加载控制器，双缓冲区交替向脉动阵列加载输入数据
module ia_loader #(
    parameter int unsigned DATA_WIDTH = 16,   // 单个输入数据宽度
    parameter int unsigned SIZE = 16,         // 输入阵列大小（每行元素数）
    parameter int unsigned BUS_WIDTH = 32,    // 总线位宽（用于 ICB 数据宽度）
    parameter int unsigned REG_WIDTH = 32     // 配置寄存器宽度（地址/偏移/零点）
) (
    // 时钟与复位
    input  wire                        clk,               // 时钟信号
    input  wire                        rst_n,             // 异步复位，低有效

    // 配置控制接口
    input  wire                        init_cfg,          // 触发配置参数锁存

    // Load/Send 控制接口
    output reg                         load_ia_req,       // 申请下一次访存授权（输出到外部控制器）
    input  wire                        load_ia_granted,   // 外部控制器授权下一次访存（握手信号）
    input  wire                        send_ia_trigger,   // 触发发送输入激活到脉动阵列

    // 矩阵尺寸配置（在 init_cfg 时被锁存）
    input  wire [REG_WIDTH-1:0]        k,                 // 输入激活矩阵行数
    input  wire [REG_WIDTH-1:0]        n,                 // 输入激活矩阵列数
    input  wire [REG_WIDTH-1:0]        m,                 // 输出矩阵列数（LHS_COLS），用于计算是否为最后一个tile

    // 配置寄存器（在 init_cfg 时锁存）
    input  wire signed [REG_WIDTH-1:0] lhs_zp,            // 输入激活零点（s32）
    input  wire [REG_WIDTH-1:0]        lhs_row_stride_b,  // 每行之间的地址间距（以调用方约定的单位）
    input  wire [REG_WIDTH-1:0]        lhs_base,          // 读取基地址（第一个分块）
    input  wire                        use_16bits,        // 输入数据类型指示，1为s16，0为s8

    // ICB 主接口（模块作为 Master, 扩展三通道）
    output icb_ext_cmd_m_t              icb_cmd_m,         // Master -> Slave: 命令有效载荷（模块驱动）
    output icb_ext_wr_m_t            icb_wr_m,       // Master -> Slave: 写数据有效载荷
    input  icb_ext_cmd_s_t              icb_cmd_s,         // Slave -> Master: 命令就绪（从设备驱动）
    input  icb_ext_wr_s_t            icb_wr_s,       // Slave -> Master: 写数据就绪
    input  icb_ext_rsp_s_t              icb_rsp_s,         // Slave -> Master: 响应有效载荷（从设备驱动）
    output icb_ext_rsp_m_t              icb_rsp_m,         // Master -> Slave: 响应就绪（模块驱动）

    // 输出信号到脉动阵列
    output wire                         ia_sending_done,   // trigger后，一整个tile已经输出完毕
    output wire                         ia_row_valid,      // 当前行数据有效
    output wire                         ia_is_init_data,    // 当前行数据为Tile的第一行
    output wire                         ia_calc_done,      // 当前输入的行已经是最后一个tile，部分和将累加得到最终结果
    output wire signed [DATA_WIDTH-1:0] ia_out [SIZE],      // 输出到脉动阵列的输入数据

    // 新增输出：当完成所有行读取时指示数据已准备好
    output wire                         ia_data_valid      // 所有行数据已读取完毕并可用于发送
);

    // 状态定义
    typedef enum logic [1:0] {
        IDLE = 2'b00,     // 空闲状态
        LOAD = 2'b01,    // 读取数据状态
        SEND = 2'b10     // 发送数据状态
    } state_t;

    state_t state;

    // ICB 命令与响应内部信号与连接（保持旧打包以便内部逻辑复用）
    icb_cmd_m_t icb_cmd_m_reg; // 驱动可变字段的寄存器
    icb_cmd_m_t icb_cmd_m_wire; // 由寄存器与常量 size 组合成的输出线网
    icb_rsp_m_t icb_rsp_m_wire_legacy;
    // 固定 size 字段为 2'b10，其余字段从寄存器取值（旧版）
    assign icb_cmd_m_wire = '{ icb_cmd_m_reg.valid,
                               icb_cmd_m_reg.addr,
                               icb_cmd_m_reg.read,
                               icb_cmd_m_reg.wdata,
                               icb_cmd_m_reg.wmask,
                               2'b10 };

    // 将旧版打包信号映射到扩展三通道端口
    assign icb_cmd_m.valid = icb_cmd_m_wire.valid;
    assign icb_cmd_m.addr  = icb_cmd_m_wire.addr;
    assign icb_cmd_m.read  = icb_cmd_m_wire.read;
    assign icb_cmd_m.len   = 3'd0; // 默认单拍（可由后续实现按需拉长）

    assign icb_wr_m.w_valid = icb_cmd_m_reg.valid & (~icb_cmd_m_reg.read);
    assign icb_wr_m.wdata   = icb_cmd_m_reg.wdata;
    assign icb_wr_m.wmask   = icb_cmd_m_reg.wmask;

    // 响应就绪沿用旧版寄存器名
    assign icb_rsp_m = '{ icb_rsp_m_wire_legacy.rsp_ready };

    // 行数据缓存（单缓冲区：保存最近读取的一行）
    reg signed [DATA_WIDTH-1:0] line_buffer [SIZE];
    integer i;

    // 锁存的配置信号
    reg [REG_WIDTH-1:0] cfg_k;
    reg [REG_WIDTH-1:0] cfg_n;
    reg signed [REG_WIDTH-1:0] cfg_lhs_zp;
    reg [REG_WIDTH-1:0] cfg_lhs_row_stride_b;
    reg [REG_WIDTH-1:0] cfg_lhs_base;
    reg cfg_use_16bits;

    // 计数器与状态寄存器
    reg [REG_WIDTH-1:0] load_count;
    reg [REG_WIDTH-1:0] send_count;
    reg [REG_WIDTH-1:0] cur_addr;
    reg [REG_WIDTH-1:0] cur_rd_ptr;

    // 配置参数锁存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_k <= '0;
            cfg_n <= '0;
            cfg_lhs_zp <= '0;
            cfg_lhs_row_stride_b <= '0;
            cfg_lhs_base <= '0;
            cfg_use_16bits <= 0;
        end else if (init_cfg) begin
            cfg_k <= k;
            cfg_n <= n;
            cfg_lhs_zp <= lhs_zp;
            cfg_lhs_row_stride_b <= lhs_row_stride_b;
            cfg_lhs_base <= lhs_base;
            cfg_use_16bits <= use_16bits;
        end
    end

    // 状态机与主控逻辑（待实现）

endmodule