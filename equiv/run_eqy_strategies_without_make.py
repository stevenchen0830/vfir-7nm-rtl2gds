#!/usr/bin/env python3
"""Run EQY-generated SAT/SBY jobs on hosts without GNU make."""

import argparse
import concurrent.futures
import json
import subprocess
from collections import Counter
from pathlib import Path


def classify_sat(text):
    if "model found for base case: FAIL!" in text:
        return "FAIL"
    if "Induction step proven: SUCCESS!" in text:
        return "PASS"
    if "Reached maximum number of time steps" in text or "TIMEOUT" in text:
        return "UNKNOWN"
    return "ERROR"


def run_sat(sat_dir):
    proc = subprocess.run(
        ["yosys", "-ql", "run.log", "run.ys"], cwd=sat_dir,
        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
    )
    log = sat_dir / "run.log"
    status = classify_sat(log.read_text(errors="replace") if log.exists() else "")
    (sat_dir / "status").write_text(status + "\n", encoding="ascii")
    return sat_dir.parent.name, status, proc.returncode, proc.stderr[-1000:]


def run_sby(strategy_dir):
    sby_dir = strategy_dir / "sby"
    try:
        configs = list(sby_dir.glob("*.sby"))
    except OSError as exc:
        return strategy_dir.name, "ERROR", -1, f"cannot enumerate SBY config: {exc}"
    if len(configs) != 1:
        return strategy_dir.name, "ERROR", -1, "missing SBY config"
    proc = subprocess.run(
        ["sby", "-f", configs[0].name], cwd=sby_dir,
        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
    )
    nested = sby_dir / configs[0].stem / "status"
    status = nested.read_text(errors="replace").split()[0] if nested.exists() else "ERROR"
    (sby_dir / "status").write_text(status + "\n", encoding="ascii")
    return strategy_dir.name, status, proc.returncode, proc.stderr[-1000:]


def run_jobs(items, fn, workers, label):
    rows = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(fn, item) for item in items]
        for index, future in enumerate(concurrent.futures.as_completed(futures), 1):
            try:
                rows.append(future.result())
            except Exception as exc:  # preserve the audit instead of aborting it
                rows.append((f"worker-{index}", "ERROR", -1, repr(exc)))
            if index % 25 == 0 or index == len(futures):
                print(f"{label}: {index}/{len(futures)} {dict(Counter(r[1] for r in rows))}", flush=True)
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("eqy_dir", type=Path)
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--fallback-only", action="store_true",
                        help="reuse existing SAT status files and run only SBY fallbacks")
    args = parser.parse_args()

    root = args.eqy_dir / "strategies"
    sat_dirs = sorted(path.parent for path in root.glob("*/sat/run.ys"))
    if args.fallback_only:
        sat_rows = []
        for sat_dir in sat_dirs:
            status_file = sat_dir / "status"
            status = status_file.read_text(errors="replace").strip() if status_file.exists() else "ERROR"
            sat_rows.append((sat_dir.parent.name, status, 0, "reused SAT status"))
        print(f"SAT: reused {len(sat_rows)} status files {dict(Counter(r[1] for r in sat_rows))}", flush=True)
    else:
        sat_rows = run_jobs(sat_dirs, run_sat, args.workers, "SAT")
    fallback = [root / name for name, status, _, _ in sat_rows if status not in {"PASS", "FAIL"}]
    sby_rows = run_jobs(fallback, run_sby, args.workers, "SBY") if fallback else []
    sby_by_name = {row[0]: row for row in sby_rows}

    final = []
    for name, status, rc, err in sat_rows:
        if status not in {"PASS", "FAIL"}:
            name, status, rc, err = sby_by_name.get(name, (name, "ERROR", -1, "fallback did not run"))
            strategy = "sby"
        else:
            strategy = "sat"
        final.append({"partition": name, "status": status, "strategy": strategy,
                      "returncode": rc, "stderr": err})

    summary = {
        "partition_count": len(final),
        "status_counts": dict(Counter(row["status"] for row in final)),
        "strategy_counts": dict(Counter(row["strategy"] for row in final)),
        "partitions": final,
    }
    out = args.eqy_dir / "manual_strategy_summary.json"
    out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items() if k != "partitions"}, indent=2))
    if any(row["status"] == "FAIL" for row in final):
        raise SystemExit(2)


if __name__ == "__main__":
    main()
