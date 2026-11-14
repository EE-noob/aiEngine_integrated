#pragma once
#include <array>
#include <cstdint>
#include <fstream>
#include <limits>
#include <vector>

struct Capture {
    uint64_t cycles = 0;
    uint64_t time_ps = 0;
    uint64_t start_cycle = std::numeric_limits<uint64_t>::max();
    uint64_t ready_cycle = std::numeric_limits<uint64_t>::max();
    bool saw_busy = false;
    bool initialized = false;
    std::array<uint32_t, 32> scalars{};
    std::array<std::vector<uint32_t>, 4> lanes;
    std::ofstream csv;
    void initialize();
};

extern thread_local Capture* active_capture;
