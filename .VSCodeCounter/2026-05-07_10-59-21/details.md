# Details

Date : 2026-05-07 10:59:21

Directory /home/posedge/work/aiEngine_integrated/picorv32

Total : 133 files,  15176 codes, 907 comments, 2919 blanks, all 19002 lines

[Summary](results.md) / Details / [Diff Summary](diff.md) / [Diff Details](diff-details.md)

## Files
| filename | language | code | comment | blank | total |
| :--- | :--- | ---: | ---: | ---: | ---: |
| [picorv32/.github/workflows/ci.yml](/picorv32/.github/workflows/ci.yml) | YAML | 33 | 0 | 5 | 38 |
| [picorv32/Makefile](/picorv32/Makefile) | Makefile | 140 | 3 | 42 | 185 |
| [picorv32/README.md](/picorv32/README.md) | Markdown | 515 | 0 | 226 | 741 |
| [picorv32/README\_中文翻译.md](/picorv32/README_%E4%B8%AD%E6%96%87%E7%BF%BB%E8%AF%91.md) | Markdown | 317 | 0 | 226 | 543 |
| [picorv32/USAGE\_LEARNING\_CN.md](/picorv32/USAGE_LEARNING_CN.md) | Markdown | 600 | 0 | 201 | 801 |
| [picorv32/dhrystone/Makefile](/picorv32/dhrystone/Makefile) | Makefile | 51 | 0 | 19 | 70 |
| [picorv32/dhrystone/dhry.h](/picorv32/dhrystone/dhry.h) | C++ | 60 | 355 | 14 | 429 |
| [picorv32/dhrystone/dhry\_1.c](/picorv32/dhrystone/dhry_1.c) | C | 297 | 75 | 56 | 428 |
| [picorv32/dhrystone/dhry\_1\_orig.c](/picorv32/dhrystone/dhry_1_orig.c) | C | 262 | 73 | 51 | 386 |
| [picorv32/dhrystone/dhry\_2.c](/picorv32/dhrystone/dhry_2.c) | C | 115 | 53 | 25 | 193 |
| [picorv32/dhrystone/stdlib.c](/picorv32/dhrystone/stdlib.c) | C | 165 | 10 | 36 | 211 |
| [picorv32/dhrystone/syscalls.c](/picorv32/dhrystone/syscalls.c) | C | 76 | 6 | 14 | 96 |
| [picorv32/dhrystone/testbench.v](/picorv32/dhrystone/testbench.v) | Verilog | 111 | 0 | 16 | 127 |
| [picorv32/dhrystone/testbench\_nola.v](/picorv32/dhrystone/testbench_nola.v) | Verilog | 80 | 1 | 15 | 96 |
| [picorv32/firmware/firmware.h](/picorv32/firmware/firmware.h) | C++ | 22 | 12 | 10 | 44 |
| [picorv32/firmware/hello.c](/picorv32/firmware/hello.c) | C | 5 | 6 | 4 | 15 |
| [picorv32/firmware/irq.c](/picorv32/firmware/irq.c) | C | 107 | 10 | 24 | 141 |
| [picorv32/firmware/makehex.py](/picorv32/firmware/makehex.py) | Python | 13 | 8 | 7 | 28 |
| [picorv32/firmware/multest.c](/picorv32/firmware/multest.c) | C | 114 | 6 | 32 | 152 |
| [picorv32/firmware/print.c](/picorv32/firmware/print.c) | C | 28 | 6 | 8 | 42 |
| [picorv32/firmware/sieve.c](/picorv32/firmware/sieve.c) | C | 63 | 8 | 14 | 85 |
| [picorv32/firmware/stats.c](/picorv32/firmware/stats.c) | C | 32 | 6 | 5 | 43 |
| [picorv32/picorv32.v](/picorv32/picorv32.v) | Verilog | 2,704 | 42 | 304 | 3,050 |
| [picorv32/picosoc/Makefile](/picorv32/picosoc/Makefile) | Makefile | 79 | 5 | 40 | 124 |
| [picorv32/picosoc/README.md](/picorv32/picosoc/README.md) | Markdown | 87 | 0 | 28 | 115 |
| [picorv32/picosoc/firmware.c](/picorv32/picosoc/firmware.c) | C | 596 | 39 | 136 | 771 |
| [picorv32/picosoc/hx8kdemo.v](/picorv32/picosoc/hx8kdemo.v) | Verilog | 117 | 0 | 23 | 140 |
| [picorv32/picosoc/hx8kdemo\_tb.v](/picorv32/picosoc/hx8kdemo_tb.v) | Verilog | 89 | 0 | 20 | 109 |
| [picorv32/picosoc/ice40up5k\_spram.v](/picorv32/picosoc/ice40up5k_spram.v) | Verilog | 81 | 1 | 10 | 92 |
| [picorv32/picosoc/icebreaker.v](/picorv32/picosoc/icebreaker.v) | Verilog | 126 | 0 | 26 | 152 |
| [picorv32/picosoc/icebreaker\_tb.v](/picorv32/picosoc/icebreaker_tb.v) | Verilog | 99 | 3 | 21 | 123 |
| [picorv32/picosoc/overview.svg](/picorv32/picosoc/overview.svg) | XML | 755 | 1 | 2 | 758 |
| [picorv32/picosoc/performance.py](/picorv32/picosoc/performance.py) | Python | 149 | 3 | 14 | 166 |
| [picorv32/picosoc/picosoc.v](/picorv32/picosoc/picosoc.v) | Verilog | 214 | 4 | 45 | 263 |
| [picorv32/picosoc/simpleuart.v](/picorv32/picosoc/simpleuart.v) | Verilog | 125 | 0 | 13 | 138 |
| [picorv32/picosoc/spiflash.v](/picorv32/picosoc/spiflash.v) | Verilog | 339 | 17 | 54 | 410 |
| [picorv32/picosoc/spiflash\_tb.v](/picorv32/picosoc/spiflash_tb.v) | Verilog | 318 | 0 | 49 | 367 |
| [picorv32/picosoc/spimemio.v](/picorv32/picosoc/spimemio.v) | Verilog | 516 | 0 | 64 | 580 |
| [picorv32/scripts/csmith/Makefile](/picorv32/scripts/csmith/Makefile) | Makefile | 67 | 0 | 19 | 86 |
| [picorv32/scripts/csmith/riscv-isa-sim.diff](/picorv32/scripts/csmith/riscv-isa-sim.diff) | Diff | 59 | 0 | 4 | 63 |
| [picorv32/scripts/csmith/syscalls.c](/picorv32/scripts/csmith/syscalls.c) | C | 76 | 6 | 14 | 96 |
| [picorv32/scripts/csmith/testbench.cc](/picorv32/scripts/csmith/testbench.cc) | C++ | 14 | 0 | 5 | 19 |
| [picorv32/scripts/csmith/testbench.v](/picorv32/scripts/csmith/testbench.v) | Verilog | 83 | 4 | 14 | 101 |
| [picorv32/scripts/cxxdemo/Makefile](/picorv32/scripts/cxxdemo/Makefile) | Makefile | 31 | 0 | 8 | 39 |
| [picorv32/scripts/cxxdemo/firmware.cc](/picorv32/scripts/cxxdemo/firmware.cc) | C++ | 71 | 0 | 17 | 88 |
| [picorv32/scripts/cxxdemo/hex8tohex32.py](/picorv32/scripts/cxxdemo/hex8tohex32.py) | Python | 27 | 1 | 7 | 35 |
| [picorv32/scripts/cxxdemo/syscalls.c](/picorv32/scripts/cxxdemo/syscalls.c) | C | 76 | 6 | 14 | 96 |
| [picorv32/scripts/cxxdemo/testbench.v](/picorv32/scripts/cxxdemo/testbench.v) | Verilog | 105 | 0 | 10 | 115 |
| [picorv32/scripts/icestorm/Makefile](/picorv32/scripts/icestorm/Makefile) | Makefile | 58 | 15 | 32 | 105 |
| [picorv32/scripts/icestorm/example.v](/picorv32/scripts/icestorm/example.v) | Verilog | 61 | 7 | 13 | 81 |
| [picorv32/scripts/icestorm/example\_tb.v](/picorv32/scripts/icestorm/example_tb.v) | Verilog | 26 | 0 | 5 | 31 |
| [picorv32/scripts/icestorm/firmware.c](/picorv32/scripts/icestorm/firmware.c) | C | 49 | 0 | 10 | 59 |
| [picorv32/scripts/icestorm/readme.md](/picorv32/scripts/icestorm/readme.md) | Markdown | 8 | 0 | 5 | 13 |
| [picorv32/scripts/presyn/Makefile](/picorv32/scripts/presyn/Makefile) | Makefile | 15 | 0 | 8 | 23 |
| [picorv32/scripts/presyn/firmware.c](/picorv32/scripts/presyn/firmware.c) | C | 40 | 0 | 4 | 44 |
| [picorv32/scripts/presyn/testbench.v](/picorv32/scripts/presyn/testbench.v) | Verilog | 70 | 1 | 11 | 82 |
| [picorv32/scripts/quartus/Makefile](/picorv32/scripts/quartus/Makefile) | Makefile | 49 | 0 | 14 | 63 |
| [picorv32/scripts/quartus/firmware.c](/picorv32/scripts/quartus/firmware.c) | C | 40 | 0 | 4 | 44 |
| [picorv32/scripts/quartus/synth\_area.sdc](/picorv32/scripts/quartus/synth_area.sdc) | Xilinx Design Constraints | 1 | 0 | 1 | 2 |
| [picorv32/scripts/quartus/synth\_area\_top.v](/picorv32/scripts/quartus/synth_area_top.v) | Verilog | 122 | 4 | 15 | 141 |
| [picorv32/scripts/quartus/synth\_speed.sdc](/picorv32/scripts/quartus/synth_speed.sdc) | Xilinx Design Constraints | 1 | 0 | 1 | 2 |
| [picorv32/scripts/quartus/synth\_system.sdc](/picorv32/scripts/quartus/synth_system.sdc) | Xilinx Design Constraints | 1 | 0 | 1 | 2 |
| [picorv32/scripts/quartus/synth\_system.tcl](/picorv32/scripts/quartus/synth_system.tcl) | Tcl | 11 | 1 | 6 | 18 |
| [picorv32/scripts/quartus/system.v](/picorv32/scripts/quartus/system.v) | Verilog | 88 | 2 | 12 | 102 |
| [picorv32/scripts/quartus/system\_tb.v](/picorv32/scripts/quartus/system_tb.v) | Verilog | 33 | 0 | 6 | 39 |
| [picorv32/scripts/quartus/table.sh](/picorv32/scripts/quartus/table.sh) | Shell Script | 14 | 1 | 3 | 18 |
| [picorv32/scripts/quartus/tabtest.sh](/picorv32/scripts/quartus/tabtest.sh) | Shell Script | 61 | 2 | 16 | 79 |
| [picorv32/scripts/quartus/tabtest.v](/picorv32/scripts/quartus/tabtest.v) | Verilog | 107 | 0 | 12 | 119 |
| [picorv32/scripts/romload/Makefile](/picorv32/scripts/romload/Makefile) | Makefile | 31 | 1 | 10 | 42 |
| [picorv32/scripts/romload/firmware.c](/picorv32/scripts/romload/firmware.c) | C | 17 | 0 | 5 | 22 |
| [picorv32/scripts/romload/hex8tohex32.py](/picorv32/scripts/romload/hex8tohex32.py) | Python | 27 | 1 | 7 | 35 |
| [picorv32/scripts/romload/map2debug.py](/picorv32/scripts/romload/map2debug.py) | Python | 24 | 1 | 6 | 31 |
| [picorv32/scripts/romload/syscalls.c](/picorv32/scripts/romload/syscalls.c) | C | 76 | 6 | 14 | 96 |
| [picorv32/scripts/romload/testbench.v](/picorv32/scripts/romload/testbench.v) | Verilog | 120 | 8 | 13 | 141 |
| [picorv32/scripts/smtbmc/axicheck.sh](/picorv32/scripts/smtbmc/axicheck.sh) | Shell Script | 7 | 2 | 5 | 14 |
| [picorv32/scripts/smtbmc/axicheck.v](/picorv32/scripts/smtbmc/axicheck.v) | Verilog | 178 | 3 | 30 | 211 |
| [picorv32/scripts/smtbmc/axicheck2.sh](/picorv32/scripts/smtbmc/axicheck2.sh) | Shell Script | 7 | 1 | 5 | 13 |
| [picorv32/scripts/smtbmc/axicheck2.v](/picorv32/scripts/smtbmc/axicheck2.v) | Verilog | 132 | 0 | 16 | 148 |
| [picorv32/scripts/smtbmc/mulcmp.sh](/picorv32/scripts/smtbmc/mulcmp.sh) | Shell Script | 7 | 1 | 5 | 13 |
| [picorv32/scripts/smtbmc/mulcmp.v](/picorv32/scripts/smtbmc/mulcmp.v) | Verilog | 73 | 0 | 15 | 88 |
| [picorv32/scripts/smtbmc/notrap\_validop.sh](/picorv32/scripts/smtbmc/notrap_validop.sh) | Shell Script | 8 | 1 | 5 | 14 |
| [picorv32/scripts/smtbmc/notrap\_validop.v](/picorv32/scripts/smtbmc/notrap_validop.v) | Verilog | 55 | 1 | 12 | 68 |
| [picorv32/scripts/smtbmc/opcode.v](/picorv32/scripts/smtbmc/opcode.v) | Verilog | 96 | 0 | 9 | 105 |
| [picorv32/scripts/smtbmc/tracecmp.gtkw](/picorv32/scripts/smtbmc/tracecmp.gtkw) | gtkw_waveconfig | 71 | 0 | 1 | 72 |
| [picorv32/scripts/smtbmc/tracecmp.sh](/picorv32/scripts/smtbmc/tracecmp.sh) | Shell Script | 7 | 1 | 5 | 13 |
| [picorv32/scripts/smtbmc/tracecmp.v](/picorv32/scripts/smtbmc/tracecmp.v) | Verilog | 91 | 5 | 14 | 110 |
| [picorv32/scripts/smtbmc/tracecmp2.sh](/picorv32/scripts/smtbmc/tracecmp2.sh) | Shell Script | 7 | 1 | 5 | 13 |
| [picorv32/scripts/smtbmc/tracecmp2.v](/picorv32/scripts/smtbmc/tracecmp2.v) | Verilog | 175 | 5 | 17 | 197 |
| [picorv32/scripts/smtbmc/tracecmp3.sh](/picorv32/scripts/smtbmc/tracecmp3.sh) | Shell Script | 12 | 1 | 5 | 18 |
| [picorv32/scripts/smtbmc/tracecmp3.v](/picorv32/scripts/smtbmc/tracecmp3.v) | Verilog | 114 | 2 | 20 | 136 |
| [picorv32/scripts/tomthumbtg/run.sh](/picorv32/scripts/tomthumbtg/run.sh) | Shell Script | 32 | 1 | 11 | 44 |
| [picorv32/scripts/tomthumbtg/testbench.v](/picorv32/scripts/tomthumbtg/testbench.v) | Verilog | 71 | 2 | 11 | 84 |
| [picorv32/scripts/torture/Makefile](/picorv32/scripts/torture/Makefile) | Makefile | 73 | 3 | 26 | 102 |
| [picorv32/scripts/torture/asmcheck.py](/picorv32/scripts/torture/asmcheck.py) | Python | 29 | 1 | 7 | 37 |
| [picorv32/scripts/torture/config.py](/picorv32/scripts/torture/config.py) | Python | 29 | 1 | 6 | 36 |
| [picorv32/scripts/torture/riscv-isa-sim-notrap.diff](/picorv32/scripts/torture/riscv-isa-sim-notrap.diff) | Diff | 14 | 0 | 3 | 17 |
| [picorv32/scripts/torture/riscv-isa-sim-sbreak.diff](/picorv32/scripts/torture/riscv-isa-sim-sbreak.diff) | Diff | 26 | 0 | 1 | 27 |
| [picorv32/scripts/torture/riscv-torture-genloop.diff](/picorv32/scripts/torture/riscv-torture-genloop.diff) | Diff | 37 | 0 | 4 | 41 |
| [picorv32/scripts/torture/riscv-torture-rv32.diff](/picorv32/scripts/torture/riscv-torture-rv32.diff) | Diff | 128 | 0 | 14 | 142 |
| [picorv32/scripts/torture/riscv\_test.h](/picorv32/scripts/torture/riscv_test.h) | C++ | 10 | 0 | 4 | 14 |
| [picorv32/scripts/torture/test.sh](/picorv32/scripts/torture/test.sh) | Shell Script | 16 | 4 | 13 | 33 |
| [picorv32/scripts/torture/testbench.cc](/picorv32/scripts/torture/testbench.cc) | C++ | 14 | 0 | 5 | 19 |
| [picorv32/scripts/torture/testbench.v](/picorv32/scripts/torture/testbench.v) | Verilog | 120 | 0 | 15 | 135 |
| [picorv32/scripts/vivado/Makefile](/picorv32/scripts/vivado/Makefile) | Makefile | 54 | 1 | 15 | 70 |
| [picorv32/scripts/vivado/firmware.c](/picorv32/scripts/vivado/firmware.c) | C | 40 | 0 | 4 | 44 |
| [picorv32/scripts/vivado/synth\_area.tcl](/picorv32/scripts/vivado/synth_area.tcl) | Tcl | 6 | 0 | 3 | 9 |
| [picorv32/scripts/vivado/synth\_area.xdc](/picorv32/scripts/vivado/synth_area.xdc) | Xilinx Design Constraints | 1 | 0 | 1 | 2 |
| [picorv32/scripts/vivado/synth\_area\_large.tcl](/picorv32/scripts/vivado/synth_area_large.tcl) | Tcl | 8 | 0 | 3 | 11 |
| [picorv32/scripts/vivado/synth\_area\_regular.tcl](/picorv32/scripts/vivado/synth_area_regular.tcl) | Tcl | 8 | 0 | 3 | 11 |
| [picorv32/scripts/vivado/synth\_area\_small.tcl](/picorv32/scripts/vivado/synth_area_small.tcl) | Tcl | 8 | 0 | 3 | 11 |
| [picorv32/scripts/vivado/synth\_area\_top.v](/picorv32/scripts/vivado/synth_area_top.v) | Verilog | 122 | 4 | 15 | 141 |
| [picorv32/scripts/vivado/synth\_speed.tcl](/picorv32/scripts/vivado/synth_speed.tcl) | Tcl | 9 | 0 | 5 | 14 |
| [picorv32/scripts/vivado/synth\_speed.xdc](/picorv32/scripts/vivado/synth_speed.xdc) | Xilinx Design Constraints | 1 | 0 | 1 | 2 |
| [picorv32/scripts/vivado/synth\_system.tcl](/picorv32/scripts/vivado/synth_system.tcl) | Tcl | 11 | 1 | 6 | 18 |
| [picorv32/scripts/vivado/synth\_system.xdc](/picorv32/scripts/vivado/synth_system.xdc) | Xilinx Design Constraints | 25 | 4 | 6 | 35 |
| [picorv32/scripts/vivado/system.v](/picorv32/scripts/vivado/system.v) | Verilog | 88 | 2 | 12 | 102 |
| [picorv32/scripts/vivado/system\_tb.v](/picorv32/scripts/vivado/system_tb.v) | Verilog | 33 | 0 | 6 | 39 |
| [picorv32/scripts/vivado/table.sh](/picorv32/scripts/vivado/table.sh) | Shell Script | 18 | 1 | 3 | 22 |
| [picorv32/scripts/vivado/tabtest.sh](/picorv32/scripts/vivado/tabtest.sh) | Shell Script | 84 | 2 | 18 | 104 |
| [picorv32/scripts/vivado/tabtest.v](/picorv32/scripts/vivado/tabtest.v) | Verilog | 107 | 0 | 12 | 119 |
| [picorv32/scripts/yosys-cmp/README.md](/picorv32/scripts/yosys-cmp/README.md) | Markdown | 48 | 0 | 15 | 63 |
| [picorv32/scripts/yosys-cmp/lse.sh](/picorv32/scripts/yosys-cmp/lse.sh) | Shell Script | 38 | 6 | 10 | 54 |
| [picorv32/scripts/yosys-cmp/synplify.sh](/picorv32/scripts/yosys-cmp/synplify.sh) | Shell Script | 48 | 11 | 16 | 75 |
| [picorv32/scripts/yosys-cmp/vivado.tcl](/picorv32/scripts/yosys-cmp/vivado.tcl) | Tcl | 3 | 0 | 1 | 4 |
| [picorv32/scripts/yosys/synth\_gates.v](/picorv32/scripts/yosys/synth_gates.v) | Verilog | 28 | 0 | 3 | 31 |
| [picorv32/scripts/yosys/synth\_osu018.sh](/picorv32/scripts/yosys/synth_osu018.sh) | Shell Script | 7 | 1 | 1 | 9 |
| [picorv32/showtrace.py](/picorv32/showtrace.py) | Python | 51 | 1 | 15 | 67 |
| [picorv32/testbench.cc](/picorv32/testbench.cc) | C++ | 36 | 2 | 7 | 45 |
| [picorv32/testbench.v](/picorv32/testbench.v) | Verilog | 414 | 7 | 59 | 480 |
| [picorv32/testbench\_ez.v](/picorv32/testbench_ez.v) | Verilog | 70 | 6 | 11 | 87 |
| [picorv32/testbench\_wb.v](/picorv32/testbench_wb.v) | Verilog | 250 | 1 | 43 | 294 |
| [picorv32/tests/riscv\_test.h](/picorv32/tests/riscv_test.h) | C++ | 57 | 0 | 8 | 65 |
| [picorv32/tests/test\_macros.h](/picorv32/tests/test_macros.h) | C++ | 505 | 1 | 80 | 586 |

[Summary](results.md) / Details / [Diff Summary](diff.md) / [Diff Details](diff-details.md)