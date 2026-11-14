`ifndef ics_TEST_PKG_SV
`define ics_TEST_PKG_SV

package ics_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import ics_mst_pkg::*;
    import i2c_mon_pkg::*;
    import ics_mon_pkg::*;
    import ics_mem_model_pkg::*;
    import ics_env_pkg::*;

    `include "sequence/ics_base_sequence.sv"
    `include "sequence/ics_smoke_sequence.sv"
    `include "sequence/ics_case1_sequence.sv"
    `include "sequence/ics_case2_sequence.sv"
    `include "sequence/ics_case3_sequence.sv"
    `include "sequence/ics_case4_sequence.sv"

    `include "ics_base_test.sv"
    `include "ics_case1_test.sv"
    `include "ics_case2_test.sv"
    `include "ics_case3_test.sv"
    `include "ics_case4_test.sv"

endpackage : ics_test_pkg

`endif // ics_TEST_PKG_SV
