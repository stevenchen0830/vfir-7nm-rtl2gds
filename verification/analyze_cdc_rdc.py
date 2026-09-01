#!/usr/bin/env python3
"""Generate a reproducible structural CDC/RDC report from Yosys JSON."""

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

SEQ_TYPES = {"$dff", "$adff", "$dffe", "$adffe", "$sdff", "$sdffe"}


def port_bits(module, name):
    return tuple(module.get("ports", {}).get(name, {}).get("bits", []))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("json_path", type=Path)
    parser.add_argument("report_path", type=Path)
    parser.add_argument("--top", default="IMG_FILTER")
    args = parser.parse_args()

    module = json.loads(args.json_path.read_text(encoding="utf-8"))["modules"][args.top]
    clk_bits = port_bits(module, "clk")
    rst_bits = port_bits(module, "rst_n")
    clock_groups, reset_groups = defaultdict(list), defaultdict(list)
    counts = Counter()
    reset_bits = unreset_bits = 0

    for name, cell in module.get("cells", {}).items():
        ctype = cell.get("type")
        if ctype not in SEQ_TYPES:
            continue
        conns = cell.get("connections", {})
        q = tuple(conns.get("Q", []))
        clk = tuple(conns.get("CLK", []))
        arst = tuple(conns.get("ARST", []))
        counts[ctype] += 1
        clock_groups[clk].append(name)
        if arst:
            reset_groups[arst].append(name)
            reset_bits += len(q)
        else:
            unreset_bits += len(q)

    foreign_clocks = [bits for bits in clock_groups if bits != clk_bits]
    foreign_resets = [bits for bits in reset_groups if bits != rst_bits]
    state_bits = reset_bits + unreset_bits
    cells = sum(counts.values())
    verdict = "PASS" if not foreign_clocks and not foreign_resets else "FAIL"

    lines = [
        "# v4 CDC/RDC structural audit", "",
        f"- Top module: `{args.top}`",
        f"- Source: `{args.json_path.as_posix()}`",
        f"- Sequential cells: {cells} ({', '.join(f'{k}={v}' for k, v in sorted(counts.items()))})",
        f"- Sequential state bits: {state_bits}",
        f"- Resettable state bits: {reset_bits}",
        f"- Unreset state bits: {unreset_bits}",
        f"- Distinct sequential clock nets: {len(clock_groups)}",
        f"- Distinct asynchronous reset nets: {len(reset_groups)}", "",
        "## Automated findings", "",
        ("- PASS: every sequential cell uses the sole top-level `clk`."
         if not foreign_clocks else f"- FAIL: unexpected clock nets: {foreign_clocks}."),
        ("- PASS: every asynchronous-reset cell uses the sole top-level `rst_n`."
         if not foreign_resets else f"- FAIL: unexpected reset nets: {foreign_resets}."),
        f"- INFO: {unreset_bits} of {state_bits} state bits are unreset datapath state.", "",
        "## Scope", "",
        "This is an RTL structural audit, not commercial CDC/RDC signoff. The module is single-clock, but safe reset deassertion remains conditional on the external synchronizer documented by the integration contract. Unreset payload state must remain isolated by reset control/valid state.", "",
    ]
    args.report_path.parent.mkdir(parents=True, exist_ok=True)
    args.report_path.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"verdict": verdict, "sequential_cells": cells,
                      "state_bits": state_bits, "resettable_bits": reset_bits,
                      "unreset_bits": unreset_bits,
                      "clock_domains": len(clock_groups),
                      "async_reset_domains": len(reset_groups)}, indent=2))
    if verdict != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
