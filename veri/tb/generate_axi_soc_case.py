import argparse
import os
import re

import numpy as np

from generate_test_case_complex_mem import generate_test_case


def parse_config(path):
    cfg = {}
    pattern = re.compile(r"^\s*([A-Za-z0-9_]+)\s*=\s*([^#\s]+)")
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            match = pattern.match(line)
            if match:
                key, value = match.group(1), match.group(2)
                if value.startswith("DSA_DTYPE_"):
                    cfg[key] = value
                else:
                    cfg[key] = int(value, 0)
    return cfg


def read_matrix(path, shape):
    data = np.loadtxt(path, dtype=np.int64)
    return np.array(data, dtype=np.int64).reshape(shape)


def read_vector(path, size):
    data = np.loadtxt(path, dtype=np.int64)
    return np.array(data, dtype=np.int64).reshape(size)


def emit_c_array(f, c_type, name, values, per_line=12, qualifiers=""):
    values = [int(value) for value in values]
    qualifier_text = f"{qualifiers} " if qualifiers else ""
    f.write(f"__attribute__((aligned(16))) {qualifier_text}{c_type} {name}[{len(values)}] = {{\n")
    for start in range(0, len(values), per_line):
        chunk = values[start:start + per_line]
        suffix = "," if start + per_line < len(values) else ""
        f.write("    " + ", ".join(str(value) for value in chunk) + suffix + "\n")
    f.write("};\n\n")


def emit_zero_array(f, c_type, name, size, qualifiers=""):
    qualifier_text = f"{qualifiers} " if qualifiers else ""
    f.write(f"__attribute__((aligned(16))) {qualifier_text}{c_type} {name}[{size}];\n\n")


def emit_soc_case_files(out_dir, cfg, random_case=False):
    dtype = cfg.get("lhs_dtype", "DSA_DTYPE_S8")
    if isinstance(dtype, str):
        dtype_value = 2 if dtype == "DSA_DTYPE_S16" else 1
    else:
        dtype_value = dtype

    k = cfg["K"]
    n = cfg["N"]
    m = cfg["M"]
    lhs_c_type = "int16_t" if dtype_value == 2 else "int8_t"
    lhs = read_matrix(os.path.join(out_dir, "lhs.txt"), (k, n)).reshape(k * n)
    rhs = read_matrix(os.path.join(out_dir, "rhs.txt"), (n, m)).flatten(order="F")
    bias = read_vector(os.path.join(out_dir, "bias.txt"), m)
    expected = read_matrix(os.path.join(out_dir, "expected_dst.txt"), (k, m)).reshape(k * m)

    values = {
        "SOC_K": k,
        "SOC_N": n,
        "SOC_M": m,
        "SOC_LHS_ADDR": "((uint32_t)(uintptr_t)lhs_data)",
        "SOC_RHS_ADDR": "((uint32_t)(uintptr_t)rhs_data)",
        "SOC_BIAS_ADDR": "((uint32_t)(uintptr_t)bias_data)",
        "SOC_OUTPUT_BASE_ADDR": "((uint32_t)(uintptr_t)dst_data)",
        "SOC_DST_MULT_ADDR": "((uint32_t)(uintptr_t)dst_mult_data)" if cfg["quant_mode"] == 1 else "0u",
        "SOC_DST_SHIFT_ADDR": "((uint32_t)(uintptr_t)dst_shift_data)" if cfg["quant_mode"] == 1 else "0u",
        "SOC_LHS_ROW_STRIDE": cfg["lhs_row_stride"],
        "SOC_RHS_ROW_STRIDE": cfg["rhs_row_stride"],
        "SOC_DST_ROW_STRIDE": cfg["dst_row_stride"],
        "SOC_LHS_DTYPE": "DSA_DTYPE_S16" if dtype_value == 2 else "DSA_DTYPE_S8",
        "SOC_QUANT_MODE": cfg["quant_mode"],
        "SOC_LHS_OFFSET": cfg.get("lhs_offset", 0),
        "SOC_RHS_OFFSET": cfg.get("rhs_offset", 0),
        "SOC_DST_OFFSET": cfg.get("dst_offset", 0),
        "SOC_DST_MULT": cfg.get("dst_mult", 0),
        "SOC_DST_SHIFT": cfg.get("dst_shift", 0),
        "SOC_ACT_MIN": cfg.get("act_min", -128),
        "SOC_ACT_MAX": cfg.get("act_max", 127),
        "SOC_OUTPUT_SIZE": k * m,
        "SOC_EXPECTED_DST_SIZE": k * m,
        "SOC_CASE_SEED": cfg.get("seed", 0),
        "SOC_CASE_RANDOM": 1 if random_case else 0,
    }

    header_path = os.path.join(out_dir, "soc_case.h")
    with open(header_path, "w", encoding="utf-8") as f:
        f.write("#ifndef SOC_CASE_H\n#define SOC_CASE_H\n\n")
        f.write("#include <stdint.h>\n")
        f.write('#include "dsa_accel_mmio.h"\n\n')
        f.write(f"extern {lhs_c_type} lhs_data[{k * n}];\n")
        f.write(f"extern int8_t rhs_data[{n * m}];\n")
        f.write(f"extern int32_t bias_data[{m}];\n")
        f.write(f"extern const int8_t expected_dst_data[{k * m}];\n")
        f.write(f"extern volatile int8_t dst_data[{k * m}];\n")
        if cfg["quant_mode"] == 1:
            f.write(f"extern int32_t dst_mult_data[{m}];\n")
            f.write(f"extern int32_t dst_shift_data[{m}];\n")
        f.write("\n")
        for key, value in values.items():
            f.write(f"#define {key} {value}\n")
        f.write("\n#endif\n")

    c_path = os.path.join(out_dir, "soc_case.c")
    with open(c_path, "w", encoding="utf-8") as f:
        f.write('#include "soc_case.h"\n\n')
        emit_c_array(f, lhs_c_type, "lhs_data", lhs, per_line=n)
        emit_c_array(f, "int8_t", "rhs_data", rhs, per_line=n)
        emit_c_array(f, "int32_t", "bias_data", bias, per_line=m)
        emit_c_array(f, "int8_t", "expected_dst_data", expected, per_line=m, qualifiers="const")
        emit_zero_array(f, "int8_t", "dst_data", k * m, qualifiers="volatile")
        if cfg["quant_mode"] == 1:
            dst_mult = read_vector(os.path.join(out_dir, "dst_mult.txt"), m)
            dst_shift = read_vector(os.path.join(out_dir, "dst_shift.txt"), m)
            emit_c_array(f, "int32_t", "dst_mult_data", dst_mult, per_line=m)
            emit_c_array(f, "int32_t", "dst_shift_data", dst_shift, per_line=m)

    return header_path, c_path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--K", type=int, default=None)
    parser.add_argument("--N", type=int, default=None)
    parser.add_argument("--M", type=int, default=None)
    parser.add_argument("--lhs_dtype", type=int, choices=[1, 2], default=None)
    parser.add_argument("--quant_mode", type=int, choices=[0, 1], default=None)
    parser.add_argument("--random", action="store_true")
    parser.add_argument("--fix_mode", action="store_true")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--lhs_offset", type=int, default=0)
    parser.add_argument("--rhs_offset", type=int, default=0)
    parser.add_argument("--dst_offset", type=int, default=0)
    parser.add_argument("--dst_mult", type=int, default=None)
    parser.add_argument("--dst_shift", type=int, default=None)
    parser.add_argument("--act_min", type=int, default=-128)
    parser.add_argument("--act_max", type=int, default=127)
    parser.add_argument("--min_dim", type=int, default=16)
    parser.add_argument("--max_dim", type=int, default=32)
    parser.add_argument("--dim_multiple", type=int, default=16)
    parser.add_argument("--out_dir", type=str, default="./axi_soc_case")
    args = parser.parse_args()

    generate_test_case(
        K=args.K,
        N=args.N,
        M=args.M,
        lhs_dtype=args.lhs_dtype,
        fix_mode=args.fix_mode,
        quant_mode=args.quant_mode,
        seed=args.seed,
        lhs_offset=args.lhs_offset,
        rhs_offset=args.rhs_offset,
        dst_offset=args.dst_offset,
        dst_mult=args.dst_mult,
        dst_shift=args.dst_shift,
        act_min=args.act_min,
        act_max=args.act_max,
        min_dim=args.min_dim,
        max_dim=args.max_dim,
        dim_multiple=args.dim_multiple,
        out_dir=args.out_dir,
    )

    cfg = parse_config(os.path.join(args.out_dir, "config.txt"))
    header_path, c_path = emit_soc_case_files(args.out_dir, cfg, random_case=args.random)
    print(f"Generated AXI SoC case in {args.out_dir}")
    print(f"Generated {header_path}")
    print(f"Generated {c_path}")


if __name__ == "__main__":
    main()
