// -------------------------
// filo_env_if.sv
// -------------------------
interface filo_env_if#(
  parameter RDW_A = 52,
  parameter RDW_B = 20,
  parameter RDW_C = 8,
  parameter RDW_D = 3
)(input logic clk);

  // DUT 信号定义（保持原命名风格）
  logic part0_filoA_rdA_en, part0_filoB_rdA_en;
  logic part1_filoA_rdA_en, part1_filoB_rdA_en;
  logic part2_filoA_rdA_en, part2_filoB_rdA_en;

  logic part0_filoA_rdB_en, part0_filoB_rdB_en;
  logic part1_filoA_rdB_en, part1_filoB_rdB_en;
  logic part2_filoA_rdB_en, part2_filoB_rdB_en;

  logic part0_filoA_rdC_en, part0_filoB_rdC_en;
  logic part1_filoA_rdC_en, part1_filoB_rdC_en;
  logic part2_filoA_rdC_en, part2_filoB_rdC_en;

  logic part0_filoA_rdD_en, part0_filoB_rdD_en;
  logic part1_filoA_rdD_en, part1_filoB_rdD_en;
  logic part2_filoA_rdD_en, part2_filoB_rdD_en;

  logic part0_filoA_rd1_en, part0_filoB_rd1_en;
  logic part1_filoA_rd1_en, part1_filoB_rd1_en;
  logic part2_filoA_rd1_en, part2_filoB_rd1_en;

  logic [RDW_A - 1:0] part0_filoA_rdA_data, part0_filoB_rdA_data;
  logic [RDW_A - 1:0] part1_filoA_rdA_data, part1_filoB_rdA_data;
  logic [RDW_A - 1:0] part2_filoA_rdA_data, part2_filoB_rdA_data;

  logic [RDW_B - 1:0] part0_filoA_rdB_data, part0_filoB_rdB_data;
  logic [RDW_B - 1:0] part1_filoA_rdB_data, part1_filoB_rdB_data;
  logic [RDW_B - 1:0] part2_filoA_rdB_data, part2_filoB_rdB_data;

  logic [RDW_C - 1:0] part0_filoA_rdC_data, part0_filoB_rdC_data;
  logic [RDW_C - 1:0] part1_filoA_rdC_data, part1_filoB_rdC_data;
  logic [RDW_C - 1:0] part2_filoA_rdC_data, part2_filoB_rdC_data;

  logic [RDW_D - 1:0] part0_filoA_rdD_data, part0_filoB_rdD_data;
  logic [RDW_D - 1:0] part1_filoA_rdD_data, part1_filoB_rdD_data;
  logic [RDW_D - 1:0] part2_filoA_rdD_data, part2_filoB_rdD_data;

  logic part0_filoA_rd1_data, part0_filoB_rd1_data;
  logic part1_filoA_rd1_data, part1_filoB_rd1_data;
  logic part2_filoA_rd1_data, part2_filoB_rd1_data;

  logic part0_filoA_rdy4rd, part0_filoB_rdy4rd;
  logic part1_filoA_rdy4rd, part1_filoB_rdy4rd;
  logic part2_filoA_rdy4rd, part2_filoB_rdy4rd;

  //Wait this signal for compare
  logic combine_eof;

  //support E-L operation
  logic [13:0] ics_part0_e_size;
  logic [13:0] ics_part0_l_size;
  logic [13:0] ics_part1_e_size;
  logic [13:0] ics_part1_l_size;
  logic [13:0] ics_part2_e_size;
  logic [13:0] ics_part2_l_size;
  logic [13:0] ics_part0_st_idx;
  logic [13:0] ics_part1_st_idx;
  logic [13:0] ics_part2_st_idx;
  

  // 封装访问方法
  function logic get_rdy4rd(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rdy4rd;
      1: return part0_filoB_rdy4rd;
      2: return part1_filoA_rdy4rd;
      3: return part1_filoB_rdy4rd;
      4: return part2_filoA_rdy4rd;
      5: return part2_filoB_rdy4rd;
      default: return 1'b0;
    endcase
  endfunction

  function logic get_rdA_en(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rdA_en;
      1: return part0_filoB_rdA_en;
      2: return part1_filoA_rdA_en;
      3: return part1_filoB_rdA_en;
      4: return part2_filoA_rdA_en;
      5: return part2_filoB_rdA_en;
      default: return 1'b0;
    endcase
  endfunction

  function logic get_rdB_en(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rdB_en;
      1: return part0_filoB_rdB_en;
      2: return part1_filoA_rdB_en;
      3: return part1_filoB_rdB_en;
      4: return part2_filoA_rdB_en;
      5: return part2_filoB_rdB_en;
      default: return 1'b0;
    endcase
  endfunction

    function logic get_rdC_en(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rdC_en;
      1: return part0_filoB_rdC_en;
      2: return part1_filoA_rdC_en;
      3: return part1_filoB_rdC_en;
      4: return part2_filoA_rdC_en;
      5: return part2_filoB_rdC_en;
      default: return 1'b0;
    endcase
  endfunction

    function logic get_rdD_en(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rdD_en;
      1: return part0_filoB_rdD_en;
      2: return part1_filoA_rdD_en;
      3: return part1_filoB_rdD_en;
      4: return part2_filoA_rdD_en;
      5: return part2_filoB_rdD_en;
      default: return 1'b0;
    endcase
  endfunction

  function logic get_rd1_en(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rd1_en;
      1: return part0_filoB_rd1_en;
      2: return part1_filoA_rd1_en;
      3: return part1_filoB_rd1_en;
      4: return part2_filoA_rd1_en;
      5: return part2_filoB_rd1_en;
      default: return 1'b0;
    endcase
  endfunction

  function logic [RDW_A - 1:0] get_rdA_data(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rdA_data;
      1: return part0_filoB_rdA_data;
      2: return part1_filoA_rdA_data;
      3: return part1_filoB_rdA_data;
      4: return part2_filoA_rdA_data;
      5: return part2_filoB_rdA_data;
      default: return '0;
    endcase
  endfunction

  function logic [RDW_B - 1:0] get_rdB_data(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rdB_data;
      1: return part0_filoB_rdB_data;
      2: return part1_filoA_rdB_data;
      3: return part1_filoB_rdB_data;
      4: return part2_filoA_rdB_data;
      5: return part2_filoB_rdB_data;
      default: return '0;
    endcase
  endfunction

  function logic [RDW_C - 1:0] get_rdC_data(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rdC_data;
      1: return part0_filoB_rdC_data;
      2: return part1_filoA_rdC_data;
      3: return part1_filoB_rdC_data;
      4: return part2_filoA_rdC_data;
      5: return part2_filoB_rdC_data;
      default: return '0;
    endcase
  endfunction

  function logic [RDW_D - 1:0] get_rdD_data(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rdD_data;
      1: return part0_filoB_rdD_data;
      2: return part1_filoA_rdD_data;
      3: return part1_filoB_rdD_data;
      4: return part2_filoA_rdD_data;
      5: return part2_filoB_rdD_data;
      default: return '0;
    endcase
  endfunction

  function logic get_rd1_data(int part, int fifo);
    case (part*2 + fifo)
      0: return part0_filoA_rd1_data;
      1: return part0_filoB_rd1_data;
      2: return part1_filoA_rd1_data;
      3: return part1_filoB_rd1_data;
      4: return part2_filoA_rd1_data;
      5: return part2_filoB_rd1_data;
      default: return '0;
    endcase
  endfunction

endinterface