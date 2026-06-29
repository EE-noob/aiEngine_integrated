#include <stdint.h>

#include "gen/my_model/testdata/W_test_image_data.h"
#include "gen/my_model/testdata/Z_test_image_data.h"
#include "model_interface.h"
#include "model_settings.h"

namespace {

constexpr int kCaseZ = 1;
constexpr int kCaseW = 2;
constexpr uintptr_t kSocProgressAddr = 0x2000000cu;

void WriteProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = value;
}

uint32_t EncodeMismatch(int test_case, int expected, int observed) {
  return 0x92000000u | ((test_case & 0xff) << 16) |
         ((expected & 0xff) << 8) | (observed & 0xff);
}

}  // namespace

extern "C" int main(void) {
  WriteProgress(0x5a100001u);

  int init_status = ModelInit();
  if (init_status != 0) {
    WriteProgress(0x5a10e000u | (init_status & 0xfff));
    return 0x91000000u | (init_status & 0xffff);
  }
  WriteProgress(0x5a100002u);

  WriteProgress(0x5a200001u);
  int z_result = ModelInference(g_Z_test_image_data);
  WriteProgress(0x5a200100u | (z_result & 0xff));
  if (z_result != kZIndex) {
    return EncodeMismatch(kCaseZ, kZIndex, z_result);
  }

  WriteProgress(0x5a200002u);
  int w_result = ModelInference(g_W_test_image_data);
  WriteProgress(0x5a200200u | (w_result & 0xff));
  if (w_result != kWIndex) {
    return EncodeMismatch(kCaseW, kWIndex, w_result);
  }

  return 1;
}
