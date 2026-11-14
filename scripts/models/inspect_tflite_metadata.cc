#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <vector>

#include "flatbuffers/flatbuffers.h"
#include "tensorflow/lite/schema/schema_generated.h"

int main(int argc, char** argv) {
  for (int arg = 1; arg < argc; ++arg) {
    std::ifstream file(argv[arg], std::ios::binary);
    std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(file)), {});
    const auto* model = flatbuffers::GetRoot<tflite::Model>(bytes.data());
    std::cout << argv[arg] << " bytes=" << bytes.size()
              << " version=" << model->version() << "\n";
    const auto* graph = model->subgraphs()->Get(0);
    auto print_tensor = [&](const char* label, int32_t index) {
      const auto* tensor = graph->tensors()->Get(index);
      std::cout << "  " << label << " tensor=" << index << " type="
                << tflite::EnumNameTensorType(tensor->type()) << " shape=[";
      for (flatbuffers::uoffset_t d = 0; d < tensor->shape()->size(); ++d) {
        if (d) std::cout << ',';
        std::cout << tensor->shape()->Get(d);
      }
      std::cout << "] scale="
                << (tensor->quantization() && tensor->quantization()->scale() &&
                            tensor->quantization()->scale()->size()
                        ? tensor->quantization()->scale()->Get(0)
                        : 0.0f)
                << " zero="
                << (tensor->quantization() && tensor->quantization()->zero_point() &&
                            tensor->quantization()->zero_point()->size()
                        ? tensor->quantization()->zero_point()->Get(0)
                        : 0)
                << "\n";
    };
    for (auto index : *graph->inputs()) print_tensor("input", index);
    for (auto index : *graph->outputs()) print_tensor("output", index);
    std::cout << "  operators:";
    for (const auto* op : *graph->operators()) {
      const auto* code = model->operator_codes()->Get(op->opcode_index());
      std::cout << ' ' << tflite::EnumNameBuiltinOperator(code->builtin_code());
    }
    std::cout << "\n";
  }
}
