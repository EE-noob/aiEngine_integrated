#!/usr/bin/env python3
import argparse
import gzip
import html
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path


METRIC_ALIASES = {
    "line": "line",
    "lines": "line",
    "cond": "cond",
    "condition": "cond",
    "conditions": "cond",
    "tgl": "toggle",
    "toggle": "toggle",
    "toggles": "toggle",
    "branch": "branch",
    "branches": "branch",
    "fsm": "fsm",
    "assert": "assert",
    "assertion": "assert",
    "group": "group",
    "covergroup": "group",
    "functional": "functional",
    "overall": "overall",
    "score": "overall",
}


def pct(value):
    try:
        if isinstance(value, str):
            match = re.search(r"[0-9]+(?:\.[0-9]+)?", value)
            if not match:
                return None
            value = match.group(0)
        return float(value)
    except (TypeError, ValueError):
        return None


def read_maybe_gzip(path):
    data = path.read_bytes()
    if data[:2] == b"\x1f\x8b":
        return gzip.decompress(data)
    return data


def parse_xml_maybe_gzip(path):
    return ET.fromstring(read_maybe_gzip(path))


def load_line_exclusion_rules(path):
    if not path:
        return []
    if not path.exists():
        raise SystemExit(f"line exclusion file not found: {path}")

    if path.suffix.lower() == ".json":
        doc = json.loads(path.read_text(encoding="utf-8"))
        raw_rules = doc.get("exclude", doc if isinstance(doc, list) else [])
        rules = []
        for item in raw_rules:
            if isinstance(item, str):
                rules.append({"pattern": item, "reason": ""})
            elif isinstance(item, dict) and item.get("pattern"):
                rules.append({"pattern": item["pattern"], "reason": item.get("reason", "")})
        return rules

    rules = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            rules.append({"pattern": line, "reason": ""})
    return rules


def compile_line_exclusion_rules(rules):
    compiled = []
    for item in rules:
        compiled.append(
            {
                "pattern": item["pattern"],
                "reason": item.get("reason", ""),
                "regex": re.compile(item["pattern"]),
            }
        )
    return compiled


def build_line_exclusions(vdb, rules):
    if not rules:
        return {}, {}

    source_path = vdb / "snps" / "coverage" / "db" / "auxiliary" / "verilog.sourceinfo.xml"
    shape_path = vdb / "snps" / "coverage" / "db" / "shape" / "line.verilog.shape.xml"
    if not source_path.exists() or not shape_path.exists():
        return {}, {}

    try:
        source_root = parse_xml_maybe_gzip(source_path)
        shape_root = parse_xml_maybe_gzip(shape_path)
    except (OSError, gzip.BadGzipFile, ET.ParseError):
        return {}, {}

    files = {item.attrib.get("id"): item.attrib.get("name", "") for item in source_root.iter("fileinfo")}
    excluded = {}
    reason_counts = {}
    for linedef in shape_root.iter("linedef"):
        chksum = linedef.attrib.get("chksum")
        if not chksum:
            continue
        for linebb in linedef.iter("linebb"):
            try:
                idx = int(linebb.attrib.get("index", "0"))
            except ValueError:
                continue
            filename = files.get(linebb.attrib.get("file_id"), "")
            basename = Path(filename).name
            line_num = linebb.attrib.get("line_num", "")
            bbsig = html.unescape(linebb.attrib.get("bbsig", ""))
            match_text = f"{filename}:{basename}:{line_num}:{bbsig}"
            for rule in rules:
                if rule["regex"].search(match_text):
                    excluded.setdefault(chksum, set()).add(idx)
                    label = rule.get("reason") or rule["pattern"]
                    reason_counts[label] = reason_counts.get(label, 0) + 1
                    break
    return excluded, reason_counts


def parse_urg_report(report_dir):
    metrics = {}
    evidence = []
    if not report_dir.exists():
        return metrics, evidence

    text_files = []
    for pattern in ("*.txt", "*.html", "*.htm"):
        text_files.extend(report_dir.rglob(pattern))

    row_re = re.compile(
        r"(line|lines|cond|condition|conditions|tgl|toggle|toggles|branch|branches|fsm|assert|assertion|group|covergroup|functional|overall|score)"
        r"[^0-9%]{0,80}([0-9]+(?:\.[0-9]+)?)\s*%",
        re.IGNORECASE,
    )
    table_re = re.compile(
        r"\b(LINE|COND|TGL|TOGGLE|BRANCH|FSM|ASSERT|GROUP|COVERGROUP)\b"
        r"(?:\s*\|[^%\n]*){0,8}?\s+([0-9]+(?:\.[0-9]+)?)\s*%",
        re.IGNORECASE,
    )
    dashboard_total_metrics = {}

    def parse_coverage_summary_table(text, title):
        lines = text.splitlines()
        for idx, line in enumerate(lines):
            if line.strip() != title:
                continue
            header_idx = None
            for cand in range(idx + 1, min(idx + 8, len(lines))):
                keys = [METRIC_ALIASES.get(item.lower()) for item in lines[cand].split()]
                if "line" in keys and ("overall" in keys or "score" in lines[cand].lower()):
                    header_idx = cand
                    break
            if header_idx is None:
                continue
            value_idx = None
            for cand in range(header_idx + 1, min(header_idx + 6, len(lines))):
                if re.search(r"[0-9]+(?:\.[0-9]+)?", lines[cand]):
                    value_idx = cand
                    break
            if value_idx is None:
                continue
            headers = lines[header_idx].split()
            values = lines[value_idx].split()
            parsed = {}
            for header, value in zip(headers, values):
                key = METRIC_ALIASES.get(header.lower())
                val = pct(value)
                if key and val is not None:
                    parsed[key] = val
            if parsed:
                return parsed
        return {}

    for path in sorted(text_files):
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if path.name.lower().startswith("dashboard"):
            preferred = parse_coverage_summary_table(text, "Total Coverage Summary")
            if not preferred:
                preferred = parse_coverage_summary_table(text, "Total Coverage Sunpury")
            if preferred:
                dashboard_total_metrics.update(preferred)
                for key, val in sorted(preferred.items()):
                    evidence.append(f"{path.relative_to(report_dir)}: Total Coverage Summary {key}={val:.2f}%")
        lines = text.splitlines()
        for idx, line in enumerate(lines):
            headers = line.split()
            header_keys = [METRIC_ALIASES.get(header.lower()) for header in headers]
            if idx + 1 < len(lines) and sum(1 for key in header_keys if key) >= 2:
                if idx + 1 < len(lines):
                    values = lines[idx + 1].split()
                    if len(values) >= len(headers):
                        for header, value in zip(headers, values):
                            key = METRIC_ALIASES.get(header.lower())
                            val = pct(value)
                            if key and val is not None:
                                if key not in metrics or path.name.lower().startswith("dashboard"):
                                    metrics[key] = val
                                evidence.append(f"{path.relative_to(report_dir)}: {header}={val:.2f}%")
        for rx in (row_re, table_re):
            for metric, value in rx.findall(text):
                key = METRIC_ALIASES.get(metric.lower())
                val = pct(value)
                if key and val is not None:
                    if key not in metrics or path.name.lower().startswith("dashboard"):
                        metrics[key] = val
                    evidence.append(f"{path.relative_to(report_dir)}: {metric}={val:.2f}%")

    if dashboard_total_metrics:
        metrics.update(dashboard_total_metrics)

    return metrics, evidence[:80]


def parse_urg_reports(report_dirs):
    combined = {}
    evidence = []
    per_report = []

    for report_dir in report_dirs:
        metrics, report_evidence = parse_urg_report(report_dir)
        per_report.append(
            {
                "report": str(report_dir),
                "metrics": metrics,
            }
        )
        for key, value in metrics.items():
            if key not in combined:
                combined[key] = value
            else:
                combined[key] = min(combined[key], value)
        for item in report_evidence:
            evidence.append(f"{report_dir}: {item}")

    return combined, evidence[:160], per_report


def parse_vdb_direct(vdbs, merge_mode="instance", line_exclusion_rules=None):
    metric_files = {
        "line": "line",
        "cond": "cond",
        "branch": "branch",
        "fsm": "fsm",
        "tgl": "toggle",
    }
    metrics = {}
    evidence = []
    per_metric = {}
    exclusion_reason_counts = {}
    compiled_line_rules = compile_line_exclusion_rules(line_exclusion_rules or [])

    for src_metric, dst_metric in metric_files.items():
        by_inst = {}
        excluded_by_key = {}
        for vdb in vdbs:
            inst_chksum = {}
            line_excluded_by_chksum = {}
            info_path = vdb / "snps" / "coverage" / "db" / "shape" / f"{src_metric}.verilog.info.xml"
            if info_path.exists():
                try:
                    info_root = parse_xml_maybe_gzip(info_path)
                    for inst_info in info_root.iter("instance_data"):
                        name = inst_info.attrib.get("name")
                        chksum = inst_info.attrib.get("chksum")
                        if name and chksum:
                            inst_chksum[name] = chksum
                except (OSError, gzip.BadGzipFile, ET.ParseError):
                    inst_chksum = {}
            if src_metric == "line" and compiled_line_rules:
                line_excluded_by_chksum, reason_counts = build_line_exclusions(vdb, compiled_line_rules)
                for reason, count in reason_counts.items():
                    exclusion_reason_counts[reason] = exclusion_reason_counts.get(reason, 0) + count
            testdata_root = vdb / "snps" / "coverage" / "db" / "testdata"
            if not testdata_root.exists():
                continue
            for path in sorted(testdata_root.glob(f"*/{src_metric}.verilog.data.xml")):
                try:
                    root = parse_xml_maybe_gzip(path)
                except (OSError, gzip.BadGzipFile, ET.ParseError):
                    continue
                test_name = path.parent.name
                for inst in root.iter("instance_data"):
                    name = inst.attrib.get("name")
                    value = inst.attrib.get("value", "").strip()
                    if not name or not value:
                        continue
                    chksum = inst_chksum.get(name)
                    if merge_mode == "definition":
                        key = chksum or name
                    else:
                        key = (str(vdb), name)
                    if src_metric == "line" and chksum:
                        excluded = line_excluded_by_chksum.get(chksum)
                        if excluded:
                            excluded_by_key.setdefault(key, set()).update(excluded)
                    old = by_inst.get(key)
                    if old is None:
                        by_inst[key] = list(value)
                        continue
                    if len(old) != len(value):
                        new_len = max(len(old), len(value))
                        old.extend(["0"] * (new_len - len(old)))
                        value = value + ("0" * (new_len - len(value)))
                    for idx, bit in enumerate(value):
                        if bit == "1":
                            old[idx] = "1"
                evidence.append(f"{path.relative_to(vdb.parent.parent.parent.parent.parent)}: parsed {src_metric} data for {test_name}")
        covered = 0
        total = 0
        excluded_total = 0
        for key, bits in by_inst.items():
            excluded = excluded_by_key.get(key, set())
            excluded_total += sum(1 for idx in excluded if idx < len(bits))
            for idx, bit in enumerate(bits):
                if idx in excluded:
                    continue
                total += 1
                if bit == "1":
                    covered += 1
        if total:
            metrics[dst_metric] = covered * 100.0 / total
            per_metric[dst_metric] = {
                "covered": covered,
                "total": total,
                "instances": len(by_inst),
                "excluded": excluded_total,
            }
            if dst_metric == "line" and excluded_total:
                per_metric[dst_metric]["exclusion_reasons"] = exclusion_reason_counts

    structural = [metrics[key] for key in ("line", "cond", "branch", "toggle", "fsm") if key in metrics]
    if structural:
        metrics["overall"] = sum(structural) / len(structural)
    return metrics, evidence[:160], per_metric


def parse_functional_from_logs(sim_root, cov_root):
    case_reports = []
    cov_re = re.compile(r"\[COV_RPT\]\s+([^:\n]+):\s*([0-9]+(?:\.[0-9]+)?)%")
    avg_re = re.compile(r"\[COV_RPT\]\s+AVERAGE COVERAGE:\s*([0-9]+(?:\.[0-9]+)?)%")

    coverage_cases = sim_root / cov_root / "cases"
    if coverage_cases.exists():
        logs = sorted(coverage_cases.rglob("sim.log"))
    else:
        logs = [log for log in sorted(sim_root.rglob("sim.log")) if "coverage" in str(log)]

    for log in logs:
        try:
            text = log.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        items = {}
        for name, value in cov_re.findall(text):
            key = re.sub(r"\s+", "_", name.strip().lower())
            items[key] = pct(value)
        avg_values = [pct(v) for v in avg_re.findall(text)]
        avg_values = [v for v in avg_values if v is not None]
        if items or avg_values:
            case_reports.append(
                {
                    "log": str(log.relative_to(sim_root)),
                    "average": avg_values[-1] if avg_values else None,
                    "items": items,
                }
            )

    avgs = [item["average"] for item in case_reports if item["average"] is not None]
    functional_average = sum(avgs) / len(avgs) if avgs else None
    return functional_average, case_reports


def normalize_metric_name(metric):
    return METRIC_ALIASES.get(metric.strip().lower(), metric.strip().lower())


def status_for(metrics, functional_average, goal, signoff_metrics):
    structural_keys = [key for key in ("line", "cond", "branch", "toggle", "fsm") if key in metrics]
    selected_structural_keys = [
        normalize_metric_name(item)
        for item in signoff_metrics
        if normalize_metric_name(item) in ("line", "cond", "branch", "toggle", "fsm")
    ]
    selected_structural_keys = [key for key in selected_structural_keys if key in metrics]
    if selected_structural_keys:
        code_score = min(metrics[key] for key in selected_structural_keys)
    elif structural_keys and "overall" in metrics:
        code_score = metrics["overall"]
    elif structural_keys:
        code_score = min(metrics[key] for key in structural_keys)
    else:
        code_score = None

    functional_pass = functional_average is not None and functional_average >= goal
    code_pass = code_score is not None and code_score >= goal

    checks = []
    for metric in signoff_metrics:
        key = normalize_metric_name(metric)
        source = "URG"
        if key in ("functional_log", "functional_average"):
            value = functional_average
            source = "simulation log"
        elif key == "functional":
            value = functional_average
            source = "simulation log"
            if value is None and "group" in metrics:
                value = metrics["group"]
                source = "URG group"
        elif key == "group":
            value = metrics.get(key)
            if value is None and functional_average is not None:
                value = functional_average
                source = "simulation log fallback"
        else:
            value = metrics.get(key)
        checks.append(
            {
                "metric": metric,
                "normalized": key,
                "value": value,
                "source": source,
                "passed": value is not None and value >= goal,
            }
        )

    signoff_pass = bool(checks) and all(item["passed"] for item in checks)
    return code_score, code_pass, functional_pass, checks, signoff_pass


def write_markdown(path, data):
    functional_requested = any(
        normalize_metric_name(item) in ("functional", "functional_log", "functional_average", "group")
        for item in data.get("signoff_metrics", [])
    )
    functional_status = "PASS" if data["functional_pass"] else "FAIL"
    if not functional_requested:
        functional_status = "not requested"
    lines = [
        "# Coverage Report Summary",
        "",
        f"- Goal: {data['goal']:.2f}%",
        f"- Sign-off status: {'PASS' if data['signoff_pass'] else 'FAIL'}",
        f"- Code coverage auxiliary status: {'PASS' if data['code_pass'] else 'FAIL'}",
        f"- Functional log coverage status: {functional_status}",
        f"- Code metric source: {data['code_metric_source']}",
        "",
        "## Code Coverage",
        "",
    ]
    if data["code_metrics"]:
        lines.append("| Metric | Coverage |")
        lines.append("|---|---:|")
        for key, value in sorted(data["code_metrics"].items()):
            lines.append(f"| {key} | {value:.2f}% |")
    else:
        lines.append("No URG code coverage metrics were parsed.")

    lines.extend(["", "## Sign-off Metrics", ""])
    lines.append("| Metric | Coverage | Source | Status |")
    lines.append("|---|---:|---|---|")
    for item in data["signoff_checks"]:
        value = item["value"]
        cov = f"{value:.2f}%" if value is not None else "n/a"
        lines.append(f"| {item['metric']} | {cov} | {item.get('source', 'n/a')} | {'PASS' if item['passed'] else 'FAIL'} |")

    lines.extend(["", "## Functional Coverage", ""])
    if data["functional_average"] is not None:
        lines.append(f"- Average covergroup coverage from simulation logs: {data['functional_average']:.2f}%")
    else:
        lines.append("- No covergroup coverage summary was found in coverage simulation logs.")
    if data["functional_cases"]:
        lines.append("")
        lines.append("| Log | Average |")
        lines.append("|---|---:|")
        for item in data["functional_cases"]:
            avg = item["average"]
            lines.append(f"| {item['log']} | {avg:.2f}% |" if avg is not None else f"| {item['log']} | n/a |")

    lines.extend(["", "## VDB Inputs", ""])
    for vdb in data["vdbs"]:
        lines.append(f"- `{vdb}`")

    if data["urg_evidence"]:
        evidence_title = "Parsed URG Evidence" if data["code_metric_source"] == "URG" else "Parsed Coverage Evidence"
        lines.extend(["", f"## {evidence_title}", ""])
        for item in data["urg_evidence"][:40]:
            lines.append(f"- {item}")

    if data.get("urg_reports"):
        lines.extend(["", "## URG Reports", ""])
        for item in data["urg_reports"]:
            lines.append(f"- `{item['report']}`")

    if data.get("vdb_direct_metrics"):
        lines.extend(["", "## VDB Direct Fallback", ""])
        lines.append(
            "URG was unavailable for this scope; metrics were computed directly from VCS VDB testdata bitmaps."
        )
        lines.append(f"Merge mode: `{data.get('vdb_merge_mode', 'instance')}`.")
        lines.append("")
        lines.append("| Metric | Covered Bins | Total Bins | Excluded Bins | Instances |")
        lines.append("|---|---:|---:|---:|---:|")
        for key, item in sorted(data["vdb_direct_metrics"].items()):
            lines.append(
                f"| {key} | {item['covered']} | {item['total']} | {item.get('excluded', 0)} | {item['instances']} |"
            )
        line_reasons = data["vdb_direct_metrics"].get("line", {}).get("exclusion_reasons", {})
        if line_reasons:
            lines.extend(["", "### Line Exclusion Rules", ""])
            lines.append("The line sign-off denominator excludes simulation-only tracing, defensive error arms, and parameter arms that are verified by directed configuration tests rather than by a single fixed elaboration.")
            lines.append("")
            lines.append("| Reason | Matched Bins |")
            lines.append("|---|---:|")
            for reason, count in sorted(line_reasons.items()):
                lines.append(f"| {reason} | {count} |")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--urg-report", type=Path, action="append", default=[])
    parser.add_argument("--sim-root", type=Path, default=Path("."))
    parser.add_argument("--cov-root", type=Path, default=Path("runs/coverage"))
    parser.add_argument("--goal", type=float, default=95.0)
    parser.add_argument("--signoff-metrics", default="functional,group")
    parser.add_argument("--vdb-merge-mode", choices=("instance", "definition"), default="instance")
    parser.add_argument("--line-exclude-file", type=Path)
    parser.add_argument("--out-md", type=Path, required=True)
    parser.add_argument("--out-json", type=Path, required=True)
    args = parser.parse_args()

    vdb_root = args.sim_root / args.cov_root / "vdb"
    vdbs = [path for path in sorted(vdb_root.glob("*.vdb"))]
    metrics, evidence, urg_reports = parse_urg_reports(args.urg_report)
    code_metric_source = "URG"
    vdb_direct_metrics = {}
    line_exclusion_rules = load_line_exclusion_rules(args.line_exclude_file) if args.line_exclude_file else []
    if line_exclusion_rules or not metrics or len(args.urg_report) != len(vdbs):
        metrics, evidence, vdb_direct_metrics = parse_vdb_direct(
            vdbs,
            args.vdb_merge_mode,
            line_exclusion_rules=line_exclusion_rules,
        )
        code_metric_source = "VCS VDB direct fallback"
    functional_average, functional_cases = parse_functional_from_logs(args.sim_root, args.cov_root)
    signoff_metrics = [item.strip() for item in args.signoff_metrics.split(",") if item.strip()]
    code_score, code_pass, functional_pass, signoff_checks, signoff_pass = status_for(
        metrics, functional_average, args.goal, signoff_metrics
    )
    if code_metric_source != "URG":
        for check in signoff_checks:
            if check.get("source") == "URG":
                check["source"] = code_metric_source
    vdbs = [str(path.relative_to(args.sim_root)) for path in sorted(vdb_root.glob("*.vdb"))]

    data = {
        "goal": args.goal,
        "code_metrics": metrics,
        "code_score": code_score,
        "code_pass": code_pass,
        "functional_average": functional_average,
        "functional_pass": functional_pass,
        "signoff_metrics": signoff_metrics,
        "signoff_checks": signoff_checks,
        "signoff_pass": signoff_pass,
        "combined_pass": code_pass and functional_pass,
        "functional_cases": functional_cases,
        "vdbs": vdbs,
        "urg_evidence": evidence,
        "urg_reports": urg_reports,
        "code_metric_source": code_metric_source,
        "vdb_direct_metrics": vdb_direct_metrics,
        "vdb_merge_mode": args.vdb_merge_mode,
    }

    args.out_md.parent.mkdir(parents=True, exist_ok=True)
    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    args.out_json.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(args.out_md, data)

    print(f"[COV] code_score={code_score if code_score is not None else 'n/a'} functional_average={functional_average if functional_average is not None else 'n/a'} goal={args.goal}")
    print(f"[COV] wrote {args.out_md} and {args.out_json}")
    return 0 if data["signoff_pass"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
