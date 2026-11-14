#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>

#include "tensorflow/lite/schema/schema_generated.h"

int main(int argc, char** argv) {
  if (argc != 2) return 2;
  std::ifstream input(argv[1], std::ios::binary);
  std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(input)), {});
  const auto* model = tflite::GetModel(bytes.data());
  const auto* graph = model->subgraphs()->Get(0);
  std::cout << "tensors=" << graph->tensors()->size() << " operators="
            << graph->operators()->size() << " opcode_tables="
            << model->operator_codes()->size() << " opcode_table_offset="
            << reinterpret_cast<const uint8_t*>(
                   model->operator_codes()->Data()) -
                   bytes.data()
            << "\n";
  for (size_t op_index = 0; op_index < graph->operators()->size(); ++op_index) {
    const auto* op = graph->operators()->Get(op_index);
    const size_t opcode_index = op->opcode_index();
    if (opcode_index >= model->operator_codes()->size()) {
      std::cout << "op=" << op_index << " opcode_index=" << opcode_index
                << " OUT_OF_RANGE\n";
      continue;
    }
    const auto* code = model->operator_codes()->Get(opcode_index);
    std::cout << "op=" << op_index << " opcode_index=" << opcode_index
              << " builtin=" << static_cast<int>(code->builtin_code())
              << " version=" << code->version() << " inputs=";
    for (size_t i = 0; i < op->inputs()->size(); ++i) {
      std::cout << op->inputs()->Get(i);
      if (i + 1 < op->inputs()->size()) std::cout << ',';
    }
    std::cout << '\n';
  }
}
