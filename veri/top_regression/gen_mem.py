#!/usr/bin/env python3
import argparse
from host_tiling import apply_words
import json
import math
import os
import random

WORD_BYTES = 4
SIZE = 4
SRAM_WORDS = 131072


def align_up(value, align):
    return ((value + align - 1) // align) * align


def signed32(value):
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def sat_s8(value):
    return max(-128, min(127, value))


def sat_s16(value):
    return max(-32768, min(32767, value))


def round_divide_by_power_of_two(value, rshift):
    if rshift == 0:
        return value
    shifted = value >> rshift
    mask = (1 << rshift) - 1
    remainder = value & mask
    threshold = mask >> 1
    if value < 0:
        threshold += 1
    return shifted + (1 if remainder > threshold else 0)


def cmsis_nn_requantize(acc, multiplier, shift):
    lshift = shift if shift > 0 else 0
    rshift = -shift if shift < 0 else 0
    acc_ext = acc << lshift
    prod = acc_ext * multiplier
    result = (prod + (1 << 30)) >> 31
    if rshift > 0:
        result = round_divide_by_power_of_two(result, rshift)
    return result


def nmsis_nn_requantize_s64(acc, multiplier, shift):
    reduced_multiplier = ((multiplier + (1 << 15)) >> 16
                          if multiplier < 0x7FFF0000 else 0x7FFF)
    result = (acc * reduced_multiplier) >> (14 - shift)
    return (result + 1) >> 1


def pack_words_le(bytearr):
    pad = (-len(bytearr)) % WORD_BYTES
    bytearr = bytearr + bytes([0] * pad)
    words = []
    for off in range(0, len(bytearr), WORD_BYTES):
        words.append(int.from_bytes(bytearr[off:off + WORD_BYTES], "little", signed=False))
    return words


def write_mem_hex(path, words, total_words):
    with open(path, "w", encoding="utf-8") as f:
        for idx in range(total_words):
            word = words[idx] if idx < len(words) else 0
            f.write(f"{word:08x}\n")


def put_s8(img, addr, value):
    img[addr] = value & 0xFF


def put_s16(img, addr, value):
    img[addr:addr + 2] = (value & 0xFFFF).to_bytes(2, "little", signed=False)


def put_s32(img, addr, value):
    img[addr:addr + 4] = (value & 0xFFFFFFFF).to_bytes(4, "little", signed=False)


def pick_dim(rng, min_dim, max_dim, multiple):
    edge_pool = [1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 23, 31, 32]
    edge_pool = [x for x in edge_pool if min_dim <= x <= max_dim]
    if edge_pool and rng.random() < 0.55:
        value = rng.choice(edge_pool)
    else:
        value = rng.randint(min_dim, max_dim)

    if multiple > 1:
        value = max(multiple, (value // multiple) * multiple)
        value = min(value, max_dim - (max_dim % multiple))
    return max(min_dim, value)


def choose_case(args):
    rng = random.Random(args.seed)
    dataflow_mode = args.dataflow_mode
    if args.random_dataflow:
        dataflow_mode = rng.choice([0, 1])

    max_stream_cols = args.ps_frame_count * SIZE
    max_k = min(args.max_dim, max_stream_cols) if dataflow_mode else args.max_dim
    max_m = min(args.max_dim, max_stream_cols) if not dataflow_mode else args.max_dim

    if args.random:
        k = args.K if args.K is not None else pick_dim(rng, args.min_dim, max_k, args.dim_multiple)
        n = args.N if args.N is not None else pick_dim(rng, args.min_dim, args.max_dim, args.dim_multiple)
        m = args.M if args.M is not None else pick_dim(rng, args.min_dim, max_m, args.dim_multiple)
        lhs_dtype = args.lhs_dtype if args.lhs_dtype else rng.choice([1, 2])
    else:
        k = args.K if args.K is not None else 4
        n = args.N if args.N is not None else 16
        m = args.M if args.M is not None else 16
        lhs_dtype = args.lhs_dtype if args.lhs_dtype else 2

    stream_cols = k if dataflow_mode else m
    if stream_cols > args.ps_frame_count * SIZE:
        raise ValueError(f"stream_cols={stream_cols} needs {math.ceil(stream_cols / SIZE)} PS frames, "
                         f"but --ps_frame_count={args.ps_frame_count}")

    output_col_tiles = max(1, math.ceil(stream_cols / SIZE))
    ia_reuse_max = max(1, args.ia_cache_blocks // 2)
    ia_options = [x for x in [1, 2, 4, 8, 16] if x <= ia_reuse_max]
    if not ia_options:
        ia_options = [1]
    w_options = [x for x in [1, 2, 4, 8, 16] if x <= output_col_tiles]
    if not w_options:
        w_options = [1]

    if args.ia_reuse_num is not None:
        ia_reuse_num = args.ia_reuse_num
    elif args.random:
        ia_reuse_num = rng.choice(ia_options)
    else:
        ia_reuse_num = 2

    if args.w_reuse_num is not None:
        w_reuse_num = args.w_reuse_num
    elif args.random:
        w_reuse_num = rng.choice(w_options)
    else:
        w_reuse_num = min(2, output_col_tiles)

    use_per_channel = bool(args.per_channel)
    if args.random_per_channel:
        use_per_channel = bool(rng.randint(0, 1))

    int16_output = bool(args.int16_output)
    if int16_output:
        if lhs_dtype != 2:
            raise ValueError("--int16_output requires --lhs_dtype 2")
        if use_per_channel or dataflow_mode != 0:
            raise ValueError("int16 output regression currently supports per-tensor WS only")

    if args.random_quant:
        if use_per_channel:
            q_mult_by_col = [signed32(rng.randint(0x40000000, 0x7FFFFFFF)) for _ in range(m)]
            q_shift_by_col = [rng.randint(-3, 1) for _ in range(m)]
            q_mult = 0
            q_shift = 0
        else:
            q_mult = rng.randint(0x40000000, 0x7FFFFFFF)
            q_shift = rng.randint(-3, 1)
            q_mult_by_col = []
            q_shift_by_col = []
        dst_zp = 0 if int16_output else rng.randint(-16, 16)
        act_min = rng.randint(-32768, -1024) if int16_output else rng.randint(-128, -16)
        act_max = rng.randint(1024, 32767) if int16_output else rng.randint(16, 127)
    else:
        q_mult = 0x7FFFFFFF
        q_shift = 0
        q_mult_by_col = [signed32(q_mult) for _ in range(m)] if use_per_channel else []
        q_shift_by_col = [q_shift for _ in range(m)] if use_per_channel else []
        dst_zp = 0
        act_min = -32768 if int16_output else -128
        act_max = 32767 if int16_output else 127

    return {
        "seed": args.seed,
        "k": k,
        "n": n,
        "m": m,
        "lhs_dtype": lhs_dtype,
        "int16_output": int16_output,
        "no_bias": bool(args.no_bias),
        "lhs_zp": args.lhs_zp,
        "rhs_zp": args.rhs_zp,
        "dst_zp": dst_zp,
        "q_mult": signed32(q_mult),
        "q_shift": q_shift,
        "use_per_channel": use_per_channel,
        "q_mult_by_col": q_mult_by_col,
        "q_shift_by_col": q_shift_by_col,
        "act_min": act_min,
        "act_max": act_max,
        "ia_reuse_num": ia_reuse_num,
        "w_reuse_num": w_reuse_num,
        "dataflow_mode": dataflow_mode,
        "ps_frame_count": args.ps_frame_count,
        "ps_pool_bytes": getattr(args,"ps_pool_bytes",0),
        "ia_cache_blocks": args.ia_cache_blocks,
        "random": args.random,
        "random_quant": args.random_quant,
    }


def build_matrices(case, args):
    rng = random.Random(args.seed ^ 0x5EED1234)
    k = case["k"]
    n = case["n"]
    m = case["m"]
    lhs_dtype = case["lhs_dtype"]

    if args.fix_mode or not args.random:
        lhs = [[((row * 5 + col * 3 + 1) % 31) - 15 for col in range(n)] for row in range(k)]
        rhs = [[((col * 7 - row * 3 + 2) % 17) - 8 for col in range(m)] for row in range(n)]
        bias = [((col * 11 + 13) % 257) - 128 for col in range(m)]
    else:
        lhs_low, lhs_high = (-8, 7) if lhs_dtype == 1 else (-16, 15)
        lhs = [[rng.randint(lhs_low, lhs_high) for _ in range(n)] for _ in range(k)]
        rhs = [[rng.randint(-8, 7) for _ in range(m)] for _ in range(n)]
        bias = [rng.randint(-512, 511) for _ in range(m)]

    return lhs, rhs, bias


def compute_layout(case, args, rng):
    lhs_elem_bytes = 2 if case["lhs_dtype"] == 2 else 1
    k = case["k"]
    n = case["n"]
    m = case["m"]
    def stride(min_bytes):
        if args.tight_strides:
            return min_bytes
        if args.random_unaligned_strides:
            return min_bytes + rng.randint(0, 3)
        extra_words = rng.randint(0, 2) if args.random else 0
        return align_up(min_bytes, WORD_BYTES) + extra_words * WORD_BYTES

    # Both WS and IS consume the external LHS as K row-major rows.  In IS mode
    # the RTL swaps the internal roles (RHS becomes IA, LHS becomes kernel) and
    # transposes the writeback, so the case image must not pre-transpose LHS.
    lhs_row_stride_b = stride(n * lhs_elem_bytes)
    rhs_row_stride_b = stride(n)
    dst_elem_bytes = 2 if case["int16_output"] else 1
    dst_row_stride_b = stride(m * dst_elem_bytes)

    cur = 0x100
    lhs_base = cur
    lhs_end = lhs_base + (k - 1) * lhs_row_stride_b + n * lhs_elem_bytes

    cur = align_up(lhs_end, 0x100)
    rhs_base = cur
    rhs_end = rhs_base + (m - 1) * rhs_row_stride_b + n

    cur = align_up(rhs_end, 0x100)
    bias_data_base = cur
    bias_end = bias_data_base + m * 4
    bias_base = 0 if case["no_bias"] else bias_data_base

    cur = align_up(bias_end, 0x100)
    if case["use_per_channel"]:
        q_mult_base = cur
        q_mult_end = q_mult_base + m * 4
        cur = align_up(q_mult_end, 0x100)
        q_shift_base = cur
        q_shift_end = q_shift_base + m * 4
        cur = align_up(q_shift_end, 0x100)
    else:
        q_mult_base = 0
        q_shift_base = 0
        q_mult_end = bias_end
        q_shift_end = bias_end

    dst_base = cur
    dst_end = dst_base + (k - 1) * dst_row_stride_b + m * dst_elem_bytes

    compare_words = align_up(max(lhs_end, rhs_end, bias_end, q_mult_end, q_shift_end, dst_end), WORD_BYTES) // WORD_BYTES + 16
    mem_words = max(args.mem_words, 4096, compare_words)
    if mem_words > SRAM_WORDS:
        raise ValueError(f"case needs {mem_words} words, SRAM model has {SRAM_WORDS}")

    return {
        "lhs_base": lhs_base,
        "rhs_base": rhs_base,
        "bias_base": bias_base,
        "bias_data_base": bias_data_base,
        "dst_base": dst_base,
        "q_mult_base": q_mult_base,
        "q_shift_base": q_shift_base,
        "lhs_row_stride_b": lhs_row_stride_b,
        "rhs_row_stride_b": rhs_row_stride_b,
        "dst_row_stride_b": dst_row_stride_b,
        "compare_words": compare_words,
        "mem_words": mem_words,
    }


def fill_images(case, layout, lhs, rhs, bias):
    img_init = bytearray(layout["mem_words"] * WORD_BYTES)
    img_golden = bytearray(layout["mem_words"] * WORD_BYTES)
    lhs_elem_bytes = 2 if case["lhs_dtype"] == 2 else 1
    for row in range(case["k"]):
        row_base = layout["lhs_base"] + row * layout["lhs_row_stride_b"]
        for col in range(case["n"]):
            off = row_base + col * lhs_elem_bytes
            if lhs_elem_bytes == 2:
                put_s16(img_init, off, lhs[row][col])
            else:
                put_s8(img_init, off, lhs[row][col])

    # RHS/W is stored as column-flattened rows: one output column per DMA row,
    # with contiguous reduction-axis elements in memory.  IS reuses this layout
    # as the IA stream and transposes writeback internally.
    for row in range(case["m"]):
        row_base = layout["rhs_base"] + row * layout["rhs_row_stride_b"]
        for col in range(case["n"]):
            put_s8(img_init, row_base + col, rhs[col][row])

    if not case["no_bias"]:
        for col in range(case["m"]):
            put_s32(img_init, layout["bias_base"] + 4 * col, bias[col])

    if case["use_per_channel"]:
        for col in range(case["m"]):
            put_s32(img_init, layout["q_mult_base"] + 4 * col, case["q_mult_by_col"][col])
            put_s32(img_init, layout["q_shift_base"] + 4 * col, case["q_shift_by_col"][col])

    img_golden[:] = img_init

    for row in range(case["k"]):
        dst_row = layout["dst_base"] + row * layout["dst_row_stride_b"]
        for col in range(case["m"]):
            acc = 0 if case["no_bias"] else bias[col]
            for red in range(case["n"]):
                acc += (lhs[row][red] + case["lhs_zp"]) * (rhs[red][col] + case["rhs_zp"])
            if case["int16_output"]:
                out = nmsis_nn_requantize_s64(acc, case["q_mult"], case["q_shift"])
            elif case["use_per_channel"]:
                out = cmsis_nn_requantize(acc, case["q_mult_by_col"][col], case["q_shift_by_col"][col])
            else:
                out = cmsis_nn_requantize(acc, case["q_mult"], case["q_shift"])
            if not case["int16_output"]:
                out += case["dst_zp"]
            out = max(case["act_min"], min(case["act_max"], out))
            if case["int16_output"]:
                put_s16(img_golden, dst_row + 2 * col, sat_s16(out))
            else:
                put_s8(img_golden, dst_row + col, sat_s8(out))

    return img_init, img_golden


def sv_signed(value):
    value = int(value)
    if value < 0:
        return f"-32'sd{-value}"
    return f"32'sd{value}"


def write_params_svh(path, case, layout):
    with open(path, "w", encoding="utf-8") as f:
        f.write("`ifndef TEST_PARAMS_SVH\n")
        f.write("`define TEST_PARAMS_SVH\n")
        f.write(f"`define TC_SIZE_VALUE {SIZE}\n")
        f.write(f"`define TC_IA_CACHE_BLOCKS_VALUE {case['ia_cache_blocks']}\n")
        f.write(f"localparam int unsigned TC_SIZE = {SIZE};\n")
        f.write(f"localparam int unsigned TC_IA_CACHE_BLOCKS = {case['ia_cache_blocks']};\n")
        f.write(f"localparam int unsigned TC_K = {case['k']};\n")
        f.write(f"localparam int unsigned TC_N = {case['n']};\n")
        f.write(f"localparam int unsigned TC_M = {case['m']};\n")
        f.write(f"localparam int unsigned TC_IA_REUSE_NUM = {case['ia_reuse_num']};\n")
        f.write(f"localparam int unsigned TC_W_REUSE_NUM = {case['w_reuse_num']};\n")
        f.write(f"localparam bit TC_DATAFLOW_MODE = 1'b{case['dataflow_mode']};\n")
        f.write(f"localparam int unsigned TC_PS_FRAME_COUNT = {case['ps_frame_count']};\n")
        f.write(f"localparam int unsigned TC_COMPARE_WORDS = {layout['compare_words']};\n")
        f.write(f"localparam int unsigned TC_MEM_WORDS = {layout['mem_words']};\n")
        f.write(f"localparam bit TC_CFG_16BITS_IA = 1'b{1 if case['lhs_dtype'] == 2 else 0};\n")
        f.write(f"localparam bit TC_USE_PER_CHANNEL = 1'b{1 if case['use_per_channel'] else 0};\n")
        for name in ["lhs_base", "rhs_base", "bias_base", "dst_base",
                     "lhs_row_stride_b", "rhs_row_stride_b", "dst_row_stride_b"]:
            f.write(f"localparam logic [31:0] TC_{name.upper()} = 32'h{layout[name]:08x};\n")
        f.write(f"localparam logic signed [31:0] TC_LHS_ZP = {sv_signed(case['lhs_zp'])};\n")
        f.write(f"localparam logic signed [31:0] TC_RHS_ZP = {sv_signed(case['rhs_zp'])};\n")
        f.write(f"localparam logic signed [31:0] TC_DST_ZP = {sv_signed(case['dst_zp'])};\n")
        qmul_cfg = layout["q_mult_base"] if case["use_per_channel"] else case["q_mult"]
        qshift_cfg = layout["q_shift_base"] if case["use_per_channel"] else case["q_shift"]
        f.write(f"localparam logic signed [31:0] TC_QMUL = {sv_signed(qmul_cfg)};\n")
        f.write(f"localparam logic signed [31:0] TC_QSHIFT = {sv_signed(qshift_cfg)};\n")
        f.write(f"localparam logic signed [31:0] TC_ACT_MIN = {sv_signed(case['act_min'])};\n")
        f.write(f"localparam logic signed [31:0] TC_ACT_MAX = {sv_signed(case['act_max'])};\n")
        f.write("`endif\n")


def write_config_mem(path, case, layout):
    # Keep this index order in sync with tb_npu_top.sv CFG_*_IDX.
    words = [0] * 32

    def put(idx, value):
        words[idx] = int(value) & 0xFFFFFFFF

    put(0, 0x4E505531)  # "NPU1"
    put(1, SIZE)
    put(2, case["ia_cache_blocks"])
    put(3, case["k"])
    put(4, case["n"])
    put(5, case["m"])
    put(6, case["ia_reuse_num"])
    put(7, case["w_reuse_num"])
    put(8, case["dataflow_mode"])
    put(9, case["ps_frame_count"])
    put(10, layout["compare_words"])
    put(11, layout["mem_words"])
    put(12, 1 if case["lhs_dtype"] == 2 else 0)
    put(13, 1 if case["use_per_channel"] else 0)
    put(14, layout["lhs_base"])
    put(15, layout["rhs_base"])
    put(16, layout["bias_base"])
    put(17, layout["dst_base"])
    put(18, layout["lhs_row_stride_b"])
    put(19, layout["rhs_row_stride_b"])
    put(20, layout["dst_row_stride_b"])
    put(21, case["lhs_zp"])
    put(22, case["rhs_zp"])
    put(23, case["dst_zp"])
    put(24, layout["q_mult_base"] if case["use_per_channel"] else case["q_mult"])
    put(25, layout["q_shift_base"] if case["use_per_channel"] else case["q_shift"])
    put(26, case["act_min"])
    put(27, case["act_max"])
    put(28, 1 if case["int16_output"] else 0)

    words, host_tiling = apply_words(words,case.get("ps_pool_bytes",0))
    case["ia_reuse_num"]=host_tiling["ia_reuse"]
    case["w_reuse_num"]=host_tiling["w_reuse"]
    with open(path, "w", encoding="utf-8") as f:
        for word in words:
            f.write(f"{word:08x}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out_dir", default="out")
    parser.add_argument("--mem_words", type=int, default=0)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--size", type=int, default=4)
    parser.add_argument("--ia_cache_blocks", type=int, default=4)
    parser.add_argument("--random", action="store_true")
    parser.add_argument("--random_quant", action="store_true")
    parser.add_argument("--per_channel", action="store_true")
    parser.add_argument("--random_per_channel", action="store_true")
    parser.add_argument("--tight_strides", action="store_true")
    parser.add_argument("--random_unaligned_strides", action="store_true")
    parser.add_argument("--fix_mode", action="store_true")
    parser.add_argument("--K", type=int)
    parser.add_argument("--N", type=int)
    parser.add_argument("--M", type=int)
    parser.add_argument("--lhs_dtype", type=int, choices=[0, 1, 2], default=0,
                        help="0=random/default, 1=s8, 2=s16")
    parser.add_argument("--int16_output", action="store_true",
                        help="TFLM 16x8 mode: s16 lhs, s8 rhs, s32 bias, s16 output")
    parser.add_argument("--no_bias", action="store_true",
                        help="set bias_base to zero and use zero bias")
    parser.add_argument("--min_dim", type=int, default=1)
    parser.add_argument("--max_dim", type=int, default=32)
    parser.add_argument("--dim_multiple", type=int, default=1)
    parser.add_argument("--lhs_zp", type=int, default=0)
    parser.add_argument("--rhs_zp", type=int, default=0)
    parser.add_argument("--ia_reuse_num", type=int)
    parser.add_argument("--w_reuse_num", type=int)
    parser.add_argument("--dataflow_mode", type=int, choices=[0, 1], default=0,
                        help="0=WS, 1=IS internal role swap with transposed writeback")
    parser.add_argument("--random_dataflow", action="store_true")
    parser.add_argument("--ps_frame_count", type=int, default=8)
    parser.add_argument("--ps_pool_bytes", type=int, default=0, help="sector payload pool; nonzero enables guaranteed capacity planning")
    args = parser.parse_args()

    global SIZE
    SIZE = args.size
    if SIZE <= 0 or (SIZE & (SIZE - 1)) != 0:
        raise ValueError("--size must be a positive power of two")
    if args.ia_cache_blocks < 2 or (args.ia_cache_blocks & (args.ia_cache_blocks - 1)) != 0:
        raise ValueError("--ia_cache_blocks must be a power of two and >= 2")

    os.makedirs(args.out_dir, exist_ok=True)

    case = choose_case(args)
    rng = random.Random(args.seed ^ 0xC0FFEE)
    layout = compute_layout(case, args, rng)
    lhs, rhs, bias = build_matrices(case, args)
    img_init, img_golden = fill_images(case, layout, lhs, rhs, bias)

    init_words = pack_words_le(bytes(img_init))
    golden_words = pack_words_le(bytes(img_golden))
    write_mem_hex(os.path.join(args.out_dir, "init.mem"), init_words, layout["mem_words"])
    write_mem_hex(os.path.join(args.out_dir, "golden.mem"), golden_words, layout["mem_words"])
    write_config_mem(os.path.join(args.out_dir, "config.mem"), case, layout)
    write_params_svh(os.path.join(args.out_dir, "test_params.svh"), case, layout)

    config = {"size": SIZE, **case, **layout}
    with open(os.path.join(args.out_dir, "config.json"), "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, sort_keys=True)

    print("[gen_mem] case="
          f"K={case['k']} N={case['n']} M={case['m']} "
          f"lhs={'s16' if case['lhs_dtype'] == 2 else 's8'} "
          f"mode={'IS' if case['dataflow_mode'] else 'WS'} "
          f"SIZE={SIZE} CACHE={case['ia_cache_blocks']} "
          f"R={case['ia_reuse_num']} W={case['w_reuse_num']} "
          f"seed={case['seed']} per_channel={int(case['use_per_channel'])} "
          f"bias={'none' if case['no_bias'] else 's32'} "
          f"out={'s16' if case['int16_output'] else 's8'} "
          f"qmul={layout['q_mult_base'] if case['use_per_channel'] else case['q_mult']} "
          f"qshift={layout['q_shift_base'] if case['use_per_channel'] else case['q_shift']} "
          f"compare_words={layout['compare_words']}")


if __name__ == "__main__":
    main()
