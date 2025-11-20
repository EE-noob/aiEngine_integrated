`ifndef CAM_IF_SV
`define CAM_IF_SV

interface cam_if (
    input  logic cam_pclk
);

    logic        cam_rst_n;
    logic        cam_vsync;
    logic        cam_href;
    logic [7:0]  cam_data;

    clocking drv_cb @(posedge cam_pclk);
        default input #1step output #1step;
        input  cam_rst_n;
        output cam_vsync;
        output cam_href;
        output cam_data;
    endclocking

    clocking mon_cb @(posedge cam_pclk);
        default input #1step output #1step;
        input cam_rst_n;
        input cam_vsync;
        input cam_href;
        input cam_data;
    endclocking

    modport drv (
        input  cam_pclk,
        clocking drv_cb
    );

    modport mon (
        input  cam_pclk,
        clocking mon_cb
    );

endinterface

`endif

