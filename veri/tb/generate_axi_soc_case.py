import argparse
import os
import re

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


def emit_soc_case_header(out_dir, cfg):
    dtype = cfg.get("lhs_dtype", "DSA_DTYPE_S8")
    if isinstance(dtype, str):
        dtype_value = 2 if dtype == "DSA_DTYPE_S16" else 1
    else:
        dtype_value = dtype

    values = {
        "SOC_K": cfg["K"],
        "SOC_N": cfg["N"],
        "SOC_M": cfg["M"],
        "SOC_LHS_ADDR": cfg["lhs_addr"],
        "SOC_RHS_ADDR": cfg["rhs_addr"],
        "SOC_BIAS_ADDR": cfg["bias_addr"],
        "SOC_OUTPUT_BASE_ADDR": cfg["output_base_addr"],
        "SOC_DST_MULT_ADDR": cfg.get("dst_mult_addr", 0),
        "SOC_DST_SHIFT_ADDR": cfg.get("dst_shift_addr", 0),
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
        "SOC_OUTPUT_SIZE": cfg.get("output_size", cfg.get("expected_dst_size", 0)),
        "SOC_EXPECTED_DST_SIZE": cfg.get("expected_dst_size", 0),
    }

    header_path = os.path.join(out_dir, "soc_case.h")
    with open(header_path, "w", encoding="utf-8") as f:
        f.write("#ifndef SOC_CASE_H\n#define SOC_CASE_H\n\n")
        for key, value in values.items():
            f.write(f"#define {key} {value}\n")
        f.write("\n#endif\n")
    return header_path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--K", type=int, default=24)
    parser.add_argument("--N", type=int, default=32)
    parser.add_argument("--M", type=int, default=16)
    parser.add_argument("--lhs_dtype", type=int, choices=[1, 2], default=1)
    parser.add_argument("--quant_mode", type=int, choices=[0, 1], default=0)
    parser.add_argument("--fix_mode", action="store_true")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--lhs_offset", type=int, default=0)
    parser.add_argument("--rhs_offset", type=int, default=0)
    parser.add_argument("--dst_offset", type=int, default=0)
    parser.add_argument("--dst_mult", type=int, default=None)
    parser.add_argument("--dst_shift", type=int, default=None)
    parser.add_argument("--act_min", type=int, default=-128)
    parser.add_argument("--act_max", type=int, default=127)
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
        out_dir=args.out_dir,
    )

    cfg = parse_config(os.path.join(args.out_dir, "config.txt"))
    header_path = emit_soc_case_header(args.out_dir, cfg)
    print(f"Generated AXI SoC case in {args.out_dir}")
    print(f"Generated {header_path}")


if __name__ == "__main__":
    main()
