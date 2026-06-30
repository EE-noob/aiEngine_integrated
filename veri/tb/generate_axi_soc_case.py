import argparse
import os
import re

import numpy as np

from generate_test_case_complex_mem import generate_test_case

RUNTIME_MAGIC = 0x4D4D4152  # "MMAR"
RUNTIME_VERSION = 1
RUNTIME_BASE_ADDR = 0x00080000
RUNTIME_HEADER_BYTES = 256


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


def align_up(value, alignment):
    return (value + alignment - 1) // alignment * alignment


def to_u32(value):
    return int(value) & 0xFFFFFFFF


def write_mem_words(path, data_bytes):
    with open(path, "w", encoding="utf-8") as f:
        for start in range(0, len(data_bytes), 4):
            chunk = data_bytes[start:start + 4]
            if len(chunk) < 4:
                chunk += b"\x00" * (4 - len(chunk))
            word = int.from_bytes(chunk, byteorder="little", signed=False)
            f.write(f"{word:08x}\n")


def emit_runtime_mem(out_dir, cfg, lhs, rhs, bias, expected, dtype_value,
                     random_case=False, unaligned_layout=False):
    base_addr = RUNTIME_BASE_ADDR
    cursor = RUNTIME_HEADER_BYTES
    rng = np.random.default_rng(int(cfg.get("seed", 0)) ^ 0x5A17)

    def place(data):
        nonlocal cursor
        cursor = align_up(cursor, 16)
        if unaligned_layout:
            cursor += int(rng.integers(0, 4))
        offset = cursor
        cursor += len(data)
        return offset

    lhs_dtype = np.int16 if dtype_value == 2 else np.int8
    lhs_bytes = np.asarray(lhs, dtype=lhs_dtype).tobytes()
    rhs_bytes = np.asarray(rhs, dtype=np.int8).tobytes()
    bias_bytes = np.asarray(bias, dtype=np.int32).tobytes()
    expected_bytes = np.asarray(expected, dtype=np.int8).tobytes()

    lhs_offset = place(lhs_bytes)
    rhs_offset = place(rhs_bytes)
    bias_offset = place(bias_bytes)

    dst_mult_bytes = b""
    dst_shift_bytes = b""
    if cfg["quant_mode"] == 1:
        dst_mult = read_vector(os.path.join(out_dir, "dst_mult.txt"), cfg["M"])
        dst_shift = read_vector(os.path.join(out_dir, "dst_shift.txt"), cfg["M"])
        dst_mult_bytes = np.asarray(dst_mult, dtype=np.int32).tobytes()
        dst_shift_bytes = np.asarray(dst_shift, dtype=np.int32).tobytes()
        dst_mult_offset = place(dst_mult_bytes)
        dst_shift_offset = place(dst_shift_bytes)
    else:
        dst_mult_offset = 0
        dst_shift_offset = 0

    output_bytes = b"\x00" * (cfg["K"] * cfg["M"])
    output_offset = place(output_bytes)
    expected_offset = place(expected_bytes)

    total_bytes = align_up(cursor, 4)
    blob = bytearray(total_bytes)
    blob[lhs_offset:lhs_offset + len(lhs_bytes)] = lhs_bytes
    blob[rhs_offset:rhs_offset + len(rhs_bytes)] = rhs_bytes
    blob[bias_offset:bias_offset + len(bias_bytes)] = bias_bytes
    if dst_mult_bytes:
        blob[dst_mult_offset:dst_mult_offset + len(dst_mult_bytes)] = dst_mult_bytes
        blob[dst_shift_offset:dst_shift_offset + len(dst_shift_bytes)] = dst_shift_bytes
    blob[output_offset:output_offset + len(output_bytes)] = output_bytes
    blob[expected_offset:expected_offset + len(expected_bytes)] = expected_bytes

    dataflow_mode = cfg.get("dataflow_mode", 0)
    is_mode = dataflow_mode == 1
    lhs_elem_bytes = 2 if dtype_value == 2 else 1
    lhs_row_stride = cfg["K"] * lhs_elem_bytes if is_mode else cfg["lhs_row_stride"]
    rhs_row_stride = cfg["N"] if is_mode else cfg["rhs_row_stride"]

    layout_flags = 1 if unaligned_layout else 0

    words = [
        RUNTIME_MAGIC,
        RUNTIME_VERSION,
        RUNTIME_HEADER_BYTES,
        total_bytes,
        cfg.get("seed", 0),
        1 if random_case else 0,
        cfg["K"],
        cfg["N"],
        cfg["M"],
        dtype_value,
        cfg["quant_mode"],
        dataflow_mode,
        cfg.get("ia_reuse_num", 0),
        cfg.get("w_reuse_num", 0),
        base_addr + lhs_offset,
        base_addr + rhs_offset,
        base_addr + bias_offset,
        base_addr + output_offset,
        base_addr + expected_offset,
        (base_addr + dst_mult_offset) if dst_mult_offset else 0,
        (base_addr + dst_shift_offset) if dst_shift_offset else 0,
        lhs_row_stride,
        rhs_row_stride,
        cfg["dst_row_stride"],
        cfg["K"] * cfg["M"],
        cfg["K"] * cfg["M"],
        cfg.get("lhs_offset", 0),
        cfg.get("rhs_offset", 0),
        cfg.get("dst_offset", 0),
        cfg.get("dst_mult", 0),
        cfg.get("dst_shift", 0),
        cfg.get("act_min", -128),
        cfg.get("act_max", 127),
        len(lhs_bytes),
        len(rhs_bytes),
        len(bias_bytes),
        len(dst_mult_bytes),
        len(dst_shift_bytes),
        layout_flags,
    ]

    for idx, value in enumerate(words):
        start = idx * 4
        blob[start:start + 4] = to_u32(value).to_bytes(4, byteorder="little")

    runtime_mem_path = os.path.join(out_dir, "runtime_data.mem")
    write_mem_words(runtime_mem_path, bytes(blob))
    return runtime_mem_path


def emit_soc_case_files(out_dir, cfg, random_case=False, unaligned_layout=False):
    dtype = cfg.get("lhs_dtype", "DSA_DTYPE_S8")
    if isinstance(dtype, str):
        dtype_value = 2 if dtype == "DSA_DTYPE_S16" else 1
    else:
        dtype_value = dtype

    k = cfg["K"]
    n = cfg["N"]
    m = cfg["M"]
    dataflow_mode = cfg.get("dataflow_mode", 0)
    is_mode = dataflow_mode == 1
    lhs_c_type = "int16_t" if dtype_value == 2 else "int8_t"
    lhs_matrix = read_matrix(os.path.join(out_dir, "lhs.txt"), (k, n))
    rhs_matrix = read_matrix(os.path.join(out_dir, "rhs.txt"), (n, m))
    if is_mode:
        lhs = lhs_matrix.T.reshape(k * n)
        rhs = rhs_matrix.T.reshape(n * m)
        lhs_row_stride = k * (2 if dtype_value == 2 else 1)
        rhs_row_stride = n
    else:
        lhs = lhs_matrix.reshape(k * n)
        rhs = rhs_matrix.reshape(n * m)
        lhs_row_stride = cfg["lhs_row_stride"]
        rhs_row_stride = cfg["rhs_row_stride"]
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
        "SOC_LHS_ROW_STRIDE": lhs_row_stride,
        "SOC_RHS_ROW_STRIDE": rhs_row_stride,
        "SOC_DST_ROW_STRIDE": cfg["dst_row_stride"],
        "SOC_LHS_DTYPE": "DSA_DTYPE_S16" if dtype_value == 2 else "DSA_DTYPE_S8",
        "SOC_QUANT_MODE": cfg["quant_mode"],
        "SOC_DATAFLOW_MODE": dataflow_mode,
        "SOC_IA_REUSE_NUM": cfg.get("ia_reuse_num", 0),
        "SOC_W_REUSE_NUM": cfg.get("w_reuse_num", 0),
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
        emit_c_array(f, lhs_c_type, "lhs_data", lhs, per_line=(k if is_mode else n))
        emit_c_array(f, "int8_t", "rhs_data", rhs, per_line=(n if is_mode else m))
        emit_c_array(f, "int32_t", "bias_data", bias, per_line=m)
        emit_c_array(f, "int8_t", "expected_dst_data", expected, per_line=m, qualifiers="const")
        emit_zero_array(f, "int8_t", "dst_data", k * m, qualifiers="volatile")
        if cfg["quant_mode"] == 1:
            dst_mult = read_vector(os.path.join(out_dir, "dst_mult.txt"), m)
            dst_shift = read_vector(os.path.join(out_dir, "dst_shift.txt"), m)
            emit_c_array(f, "int32_t", "dst_mult_data", dst_mult, per_line=m)
            emit_c_array(f, "int32_t", "dst_shift_data", dst_shift, per_line=m)

    runtime_mem_path = emit_runtime_mem(out_dir, cfg, lhs, rhs, bias, expected,
                                        dtype_value,
                                        random_case=random_case,
                                        unaligned_layout=unaligned_layout)

    return header_path, c_path, runtime_mem_path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--K", type=int, default=None)
    parser.add_argument("--N", type=int, default=None)
    parser.add_argument("--M", type=int, default=None)
    parser.add_argument("--lhs_dtype", type=int, choices=[1, 2], default=None)
    parser.add_argument("--quant_mode", type=int, choices=[0, 1], default=None)
    parser.add_argument("--dataflow_mode", type=int, choices=[0, 1], default=0,
                        help="0=WS layout, 1=IS layout with pre-transposed LHS/RHS")
    parser.add_argument("--ia_reuse_num", type=int, default=0)
    parser.add_argument("--w_reuse_num", type=int, default=0)
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
    parser.add_argument("--unaligned_layout", action="store_true",
                        help="place runtime data sections at deterministic byte offsets")
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
    cfg["dataflow_mode"] = args.dataflow_mode
    cfg["ia_reuse_num"] = args.ia_reuse_num
    cfg["w_reuse_num"] = args.w_reuse_num
    header_path, c_path, runtime_mem_path = emit_soc_case_files(
        args.out_dir, cfg, random_case=args.random,
        unaligned_layout=args.unaligned_layout)
    print(f"Generated AXI SoC case in {args.out_dir}")
    print(f"Generated {header_path}")
    print(f"Generated {c_path}")
    print(f"Generated {runtime_mem_path}")


if __name__ == "__main__":
    main()
