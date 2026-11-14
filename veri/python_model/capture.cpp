#include "capture.hpp"
#include "svdpi.h"
#include "verilated.h"
#include <string>

thread_local Capture* active_capture = nullptr;
static Capture native_capture;
static const char* names[] = {
    "rst_n", "calc_start", "sa_ready", "done_valid", "err_code",
    "ia_row_valid", "store_weight_req", "acc_valid", "requant_valid",
    "fifo_full", "tile_over", "axi_flags", "araddr", "arlen", "rdata",
    "awaddr", "awlen", "wdata", "wstrb", "controller_state",
    "ia_l1_switch", "ia_tile_start", "ia_calc_done", "weight_valid",
    "fifo_valid", "fifo_ready", "ia_dma_done", "kernel_dma_done",
    "oa_dma_done", "is_mode", "int16_output", "int16_input"
};

void Capture::initialize() {
    initialized = true;
    const char* arg = Verilated::threadContextp()->commandArgsPlusMatch("PY_TRACE=");
    if (arg && std::string(arg).rfind("+PY_TRACE=", 0) == 0) {
        csv.open(std::string(arg).substr(10));
        if (!csv) VL_FATAL_MT(__FILE__, __LINE__, "", "Cannot open PY_TRACE file");
        csv << "cycle,time_ps";
        for (const auto* name : names) csv << ',' << name;
        const char* prefixes[] = {"ia", "weight", "acc", "requant"};
        for (size_t kind = 0; kind < lanes.size(); ++kind)
            for (size_t i = 0; i < lanes[kind].size(); ++i)
                csv << ',' << prefixes[kind] << i;
        csv << '\n';
    }
}

extern "C" void py_capture(
    unsigned int lane_count,
    const unsigned int* scalar_values, const unsigned int* ia_values,
    const unsigned int* weight_values, const unsigned int* acc_values,
    const unsigned int* requant_values
) {
    Capture& cap = active_capture ? *active_capture : native_capture;
    for (size_t i = 0; i < cap.scalars.size(); ++i) cap.scalars[i] = scalar_values[i];
    cap.lanes[0] = std::vector<uint32_t>(ia_values,ia_values+lane_count);
    cap.lanes[1] = std::vector<uint32_t>(weight_values,weight_values+lane_count);
    cap.lanes[2] = std::vector<uint32_t>(acc_values,acc_values+lane_count);
    cap.lanes[3] = std::vector<uint32_t>(requant_values,requant_values+lane_count);
    if (!cap.initialized) cap.initialize();
    cap.time_ps = Verilated::threadContextp()->time();
    if (cap.scalars[1] && cap.start_cycle == UINT64_MAX) cap.start_cycle = cap.cycles;
    if (cap.start_cycle != UINT64_MAX && !cap.scalars[2]) cap.saw_busy = true;
    if (cap.saw_busy && cap.scalars[2] && cap.ready_cycle == UINT64_MAX)
        cap.ready_cycle = cap.cycles;
    if (cap.csv) {
        cap.csv << cap.cycles << ',' << cap.time_ps;
        for (uint32_t value : cap.scalars) cap.csv << ',' << value;
        for (const auto& vector : cap.lanes)
            for (uint32_t value : vector) cap.csv << ',' << value;
        cap.csv << '\n';
    }
    ++cap.cycles;
}
