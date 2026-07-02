#!/usr/bin/env python3
"""Generate plots for the SIZE/cache and TFLM HW/SW performance report."""

from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
from dataclasses import dataclass
from pathlib import Path

import matplotlib.pyplot as plt


RE_TOTAL = re.compile(
    r"\[tflm_perf\]\s+(?P<name>\w+)\s+total_invoke_cycles=(?P<total>\d+)\s+"
    r"avg=(?P<avg>\d+)\s+min=(?P<min>\d+)\s+max=(?P<max>\d+)\s+samples=(?P<samples>\d+)"
)
RE_SOC = re.compile(r"soc_finish asserted after (?P<cycles>\d+) cycles")
RE_MMA_UTIL = re.compile(r"\[MMA_UTIL\]\s+(?P<body>.*)")
RE_MMA_UTIL_SUMMARY = re.compile(r"\[MMA_UTIL_SUMMARY\]\s+(?P<body>.*)")


@dataclass(frozen=True)
class TflmRun:
    name: str
    path: Path
    total_invoke_cycles: int
    avg_invoke_cycles: int
    samples: int
    soc_cycles: int
    mma_active_cycles: int
    mma_axi_r: int
    mma_axi_w: int
    mma_ops_count: int
    int8_ops_per_sample: int

    @property
    def total_int8_ops(self) -> int:
        return self.int8_ops_per_sample * self.samples

    @property
    def invoke_gops_200m(self) -> float:
        return self.total_int8_ops / self.total_invoke_cycles * 0.2

    @property
    def mma_active_gops_200m(self) -> float:
        if self.mma_active_cycles <= 0:
            return 0.0
        return self.total_int8_ops / self.mma_active_cycles * 0.2

    @property
    def read_beat_per_active_cycle(self) -> float:
        if self.mma_active_cycles <= 0:
            return 0.0
        return self.mma_axi_r / self.mma_active_cycles

    @property
    def write_beat_per_active_cycle(self) -> float:
        if self.mma_active_cycles <= 0:
            return 0.0
        return self.mma_axi_w / self.mma_active_cycles


def parse_key_values(body: str) -> dict[str, int]:
    values: dict[str, int] = {}
    for item in body.split():
        if "=" not in item:
            continue
        key, value = item.split("=", 1)
        try:
            values[key] = int(value)
        except ValueError:
            pass
    return values


def parse_tflm_log(path: Path, name: str, int8_ops_per_sample: int) -> TflmRun:
    text = path.read_text(errors="replace")
    total = avg = samples = soc_cycles = 0
    active = axi_r = axi_w = mma_ops_count = 0

    for line in text.splitlines():
        match = RE_TOTAL.search(line)
        if match:
            total = int(match.group("total"))
            avg = int(match.group("avg"))
            samples = int(match.group("samples"))
        match = RE_SOC.search(line)
        if match:
            soc_cycles = int(match.group("cycles"))
        match = RE_MMA_UTIL_SUMMARY.search(line)
        if match:
            values = parse_key_values(match.group("body"))
            active += values.get("active", 0)
            axi_r += values.get("axi_r", 0)
            axi_w += values.get("axi_w", 0)
            mma_ops_count += values.get("ops", 0)
        match = RE_MMA_UTIL.search(line)
        if match:
            values = parse_key_values(match.group("body"))
            active += values.get("active", 0)
            axi_r += values.get("axi_r", 0)
            axi_w += values.get("axi_w", 0)
            mma_ops_count += 1 if values else 0

    return TflmRun(
        name=name,
        path=path,
        total_invoke_cycles=total,
        avg_invoke_cycles=avg,
        samples=samples,
        soc_cycles=soc_cycles,
        mma_active_cycles=active,
        mma_axi_r=axi_r,
        mma_axi_w=axi_w,
        mma_ops_count=mma_ops_count,
        int8_ops_per_sample=int8_ops_per_sample,
    )


def read_fixed_capacity_csv(path: Path) -> list[dict[str, float | int | str]]:
    rows: list[dict[str, float | int | str]] = []
    with path.open(newline="") as f:
        for raw in csv.DictReader(f):
            size = int(raw["size"])
            k = int(raw["K"])
            cycles = int(raw["cycles"])
            active = int(raw["mma_active"])
            ops = 2 * k * k * k
            theoretical_gops = 2 * size * size * 0.2
            active_gops = ops / active * 0.2
            rows.append(
                {
                    "label": f"S{size}/C{int(raw['cache_blocks'])}",
                    "size": size,
                    "cache_blocks": int(raw["cache_blocks"]),
                    "dim": k,
                    "cycles": cycles,
                    "active": active,
                    "gops": ops / cycles * 0.2,
                    "active_gops": active_gops,
                    "active_util": active_gops / theoretical_gops * 100.0,
                    "read_util": int(raw["mma_axi_r"]) / active,
                    "write_util": int(raw["mma_axi_w"]) / active,
                }
            )
    return rows


def style_axes(ax, title: str, ylabel: str) -> None:
    ax.set_title(title, fontsize=12, pad=8)
    ax.set_ylabel(ylabel)
    ax.grid(True, axis="y", alpha=0.25)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)


def plot_hw_sw(runs: dict[str, TflmRun], out_dir: Path) -> None:
    names = ["MNIST MLP", "MNIST CNN"]
    hw = [runs["mlp_hw"].avg_invoke_cycles, runs["cnn_hw"].avg_invoke_cycles]
    sw = [runs["mlp_sw"].avg_invoke_cycles, runs["cnn_sw"].avg_invoke_cycles]
    speedup = [sw[i] / hw[i] for i in range(len(names))]

    fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(11.5, 4.3), constrained_layout=True)
    x = range(len(names))
    width = 0.34
    ax0.bar([i - width / 2 for i in x], hw, width, label="HW accel", color="#2563eb")
    ax0.bar([i + width / 2 for i in x], sw, width, label="SW reference", color="#dc2626")
    ax0.set_xticks(list(x), names)
    ax0.set_yscale("log")
    style_axes(ax0, "Invoke cycles, log scale", "cycles")
    ax0.legend(frameon=False)
    for i, value in enumerate(speedup):
        ax0.text(i, max(hw[i], sw[i]) * 1.08, f"{value:.1f}x", ha="center", fontsize=9)

    gops_hw = [runs["mlp_hw"].invoke_gops_200m, runs["cnn_hw"].invoke_gops_200m]
    gops_sw = [runs["mlp_sw"].invoke_gops_200m, runs["cnn_sw"].invoke_gops_200m]
    ax1.bar([i - width / 2 for i in x], gops_hw, width, label="HW accel", color="#16a34a")
    ax1.bar([i + width / 2 for i in x], gops_sw, width, label="SW reference", color="#f97316")
    ax1.set_xticks(list(x), names)
    style_axes(ax1, "200MHz effective inference throughput", "GOPS")
    ax1.legend(frameon=False)
    fig.savefig(out_dir / "hw_sw_inference_cycles_gops.png", dpi=180)
    plt.close(fig)


def plot_size_cache(rows: list[dict[str, float | int | str]], out_dir: Path) -> None:
    labels = sorted({str(row["label"]) for row in rows}, key=lambda item: int(item.split("/")[0][1:]))
    dims = sorted({int(row["dim"]) for row in rows})
    by_key = {(str(row["label"]), int(row["dim"])): row for row in rows}

    def line_plot(filename: str, metric: str, title: str, ylabel: str) -> None:
        fig, ax = plt.subplots(figsize=(8.6, 4.6), constrained_layout=True)
        for dim in dims:
            y = [float(by_key[(label, dim)][metric]) for label in labels]
            ax.plot(labels, y, marker="o", linewidth=2, label=f"{dim}^3")
        style_axes(ax, title, ylabel)
        ax.set_xlabel("SIZE/CACHE_BLOCKS")
        ax.legend(title="matrix", frameon=False)
        fig.savefig(out_dir / filename, dpi=180)
        plt.close(fig)

    line_plot(
        "size_cache_effective_gops_by_dim.png",
        "gops",
        "SoC end-to-end compute throughput by fixed IA cache capacity",
        "200MHz equivalent GOPS",
    )
    line_plot(
        "size_cache_active_gops_by_dim.png",
        "active_gops",
        "MMA active throughput by fixed IA cache capacity",
        "200MHz equivalent GOPS",
    )
    line_plot(
        "size_cache_active_util_by_dim.png",
        "active_util",
        "Systolic array active utilization",
        "active utilization (%)",
    )

    fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(12.0, 4.5), constrained_layout=True)
    for dim in dims:
        ax0.plot(
            labels,
            [float(by_key[(label, dim)]["read_util"]) * 100.0 for label in labels],
            marker="o",
            linewidth=2,
            label=f"{dim}^3",
        )
        ax1.plot(
            labels,
            [float(by_key[(label, dim)]["write_util"]) * 100.0 for label in labels],
            marker="o",
            linewidth=2,
            label=f"{dim}^3",
        )
    style_axes(ax0, "AXI read channel beat occupancy during MMA active", "read beat / active cycle (%)")
    style_axes(ax1, "AXI write channel beat occupancy during MMA active", "write beat / active cycle (%)")
    for ax in (ax0, ax1):
        ax.set_xlabel("SIZE/CACHE_BLOCKS")
        ax.legend(title="matrix", frameon=False)
    fig.savefig(out_dir / "size_cache_bus_beat_util_by_dim.png", dpi=180)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mirror-dir", action="append", type=Path, default=[])
    args = parser.parse_args()

    doc_dir = Path(__file__).resolve().parent
    root = doc_dir.parents[1]
    runs_dir = root / "veri" / "sim" / "runs"
    tflm_dir = root / "drivers" / "tflm" / "my_tflm" / "tflite-micro"
    out_dir = doc_dir / "perf_plots"
    out_dir.mkdir(parents=True, exist_ok=True)

    mlp_ops = json.loads((tflm_dir / "mnist_mlp" / "metadata.json").read_text())[
        "int8_ops_per_sample"
    ]
    cnn_ops = json.loads((tflm_dir / "mnist_cnn" / "metadata.json").read_text())[
        "int8_ops_per_sample"
    ]
    runs = {
        "mlp_hw": parse_tflm_log(
            runs_dir / "mnist_mlp_hw_sw" / "mnist_mlp_big_hw_s16_c4_p16.log",
            "MNIST MLP HW",
            mlp_ops,
        ),
        "mlp_sw": parse_tflm_log(
            runs_dir / "mnist_mlp_hw_sw" / "mnist_mlp_big_sw_s16_c4_p16.log",
            "MNIST MLP SW",
            mlp_ops,
        ),
        "cnn_hw": parse_tflm_log(
            runs_dir / "mnist_cnn_hw_sw" / "mnist_cnn_hw_s16_c4_p16_batch32_sample1_summary.log",
            "MNIST CNN HW",
            cnn_ops,
        ),
        "cnn_sw": parse_tflm_log(
            runs_dir / "mnist_cnn_hw_sw" / "mnist_cnn_sw_s16_c4_p16_sample1.log",
            "MNIST CNN SW",
            cnn_ops,
        ),
    }
    fixed_rows = read_fixed_capacity_csv(
        runs_dir / "fixed_capacity_size_cache_sweep_burst8_fix" / "perf.csv"
    )

    plot_hw_sw(runs, out_dir)
    plot_size_cache(fixed_rows, out_dir)

    for mirror in args.mirror_dir:
        mirror.mkdir(parents=True, exist_ok=True)
        for image in [
            "hw_sw_inference_cycles_gops.png",
            "size_cache_effective_gops_by_dim.png",
            "size_cache_active_gops_by_dim.png",
            "size_cache_active_util_by_dim.png",
            "size_cache_bus_beat_util_by_dim.png",
        ]:
            shutil.copy2(out_dir / image, mirror / image)


if __name__ == "__main__":
    main()
