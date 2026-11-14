#include "VNpuPython.h"
#include "VNpuPython___024root.h"
#include "capture.hpp"
#include "verilated.h"
#include <memory>

struct Model {
    std::unique_ptr<VerilatedContext> context;
    std::unique_ptr<VNpuPython> top;
    Capture capture;
    bool finalized = false;
    Model(int argc, const char** argv) {
        context = std::make_unique<VerilatedContext>();
        context->threads(1);
        context->commandArgs(argc, argv);
        context->randReset(0);
        Verilated::threadContextp(context.get());
        active_capture = &capture;
        top = std::make_unique<VNpuPython>(context.get(), "TOP");
        top->eval();
    }
    ~Model() {
        Verilated::threadContextp(context.get());
        active_capture = &capture;
        if (!finalized) top->final();
        top.reset();
        active_capture = nullptr;
    }
};

#define API extern "C" __attribute__((visibility("default")))
API Model* npu_create(int argc, const char** argv) { return new Model(argc, argv); }
API void npu_destroy(Model* model) { delete model; }
API int npu_finished(Model* model) { return model->context->gotFinish(); }
API int npu_step(Model* model) {
    Verilated::threadContextp(model->context.get());
    active_capture = &model->capture;
    const uint64_t before = model->capture.cycles;
    while (!model->context->gotFinish() && model->capture.cycles == before) {
        if (!model->top->eventsPending()) return -1;
        model->context->time(model->top->nextTimeSlot());
        model->top->eval();
    }
    return model->capture.cycles != before;
}
API uint64_t npu_cycles(Model* model) { return model->capture.cycles; }
API uint64_t npu_time_ps(Model* model) { return model->capture.time_ps; }
API uint64_t npu_start_cycle(Model* model) { return model->capture.start_cycle; }
API uint64_t npu_ready_cycle(Model* model) { return model->capture.ready_cycle; }
API uint32_t npu_scalar(Model* model, unsigned index) {
    return model->capture.scalars.at(index);
}
API uint32_t npu_lane(Model* model, unsigned kind, unsigned index) {
    return model->capture.lanes.at(kind).at(index);
}
API uint32_t npu_read_word(Model* model, unsigned index) {
    if (index >= 131072) return 0;
    return model->top->rootp->tb_npu_top__DOT__u_mem__DOT__mem_r[index];
}
API void npu_read_words(Model* model, unsigned start, unsigned count, uint32_t* out) {
    for (unsigned i = 0; i < count; ++i) out[i] = npu_read_word(model, start+i);
}
API void npu_flush(Model* model) {
    model->capture.csv.flush();
    Verilated::flushCall();
}
