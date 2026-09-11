#!/usr/bin/env python3
"""Bounded, fail-closed 1 GHz audit; diagnostics do not imply tapeout signoff."""
import argparse
import hashlib
import json
import math
import os
import re
import signal
import subprocess
import time
from pathlib import Path

REQUIRED = {'setup_ws_ps', 'setup_tns_ps', 'setup_endpoints', 'hold_ws_ps',
            'hold_tns_ps', 'hold_endpoints', 'slew_violations', 'cap_violations', 'fanout_violations'}


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()


def parse_report(text):
    if text.count('CLOSURE_AUDIT_DONE') != 1 or re.search(r'(?m)^Error|\[ERROR', text):
        raise ValueError('Incomplete or failed STA execution')
    pairs = re.findall(r'(?m)^METRIC (\w+) (\S+)\s*$', text)
    if 'FANOUT_CHECK_BEGIN' in text:
        chunks = re.findall(r'FANOUT_CHECK_BEGIN\n(.*?)FANOUT_CHECK_END', text, re.S)
        if len(chunks) != 1: raise ValueError('Incomplete fanout check')
        pairs.append(('fanout_violations', str(chunks[0].count('(VIOLATED)'))))
    metrics = {key: float(value) for key, value in pairs}
    if set(metrics) != REQUIRED or len(pairs) != len(REQUIRED):
        raise ValueError('Missing, duplicate or unexpected metrics')
    if not all(math.isfinite(value) for value in metrics.values()):
        raise ValueError('Nonfinite metrics')
    for key in REQUIRED - {'setup_ws_ps', 'hold_ws_ps', 'setup_tns_ps', 'hold_tns_ps'}:
        if metrics[key] < 0 or not metrics[key].is_integer():
            raise ValueError('Invalid violation count')
    passed = all(value >= 0 if key.endswith('_ws_ps') else value == 0
                 for key, value in metrics.items())
    clocks=re.findall(r'CLOCK_CHECK_BEGIN\n(.*?)CLOCK_CHECK_END', text, re.S)
    if 'CLOCK_CHECK_BEGIN' in text and len(clocks)!=1: raise ValueError('Incomplete clock checks')
    if clocks and '(VIOLATED)' in clocks[0]: passed=False
    return metrics, passed


def main(a):
    repo = Path(__file__).resolve().parents[1]
    a.output.mkdir(parents=True, exist_ok=True)
    summary = {'target_period_ps': 1000, 'setup_uncertainty_ps': 150,
               'hold_uncertainty_ps': 30, 'parasitics': 'one v4 routed SPEF reused across PVT',
               'fanout_scope': 'counts checks present in Liberty/SDC, not an imposed global fanout bound',
               'full_signoff': 'NOT_CLOSED', 'views': [],
               'unverified': ['constraint coverage', 'reset recovery/removal contract',
                              'per-RC MMMC', 'LVS', 'EM', 'SRAM macro integration'],
               'inputs': {name: sha(a.result_dir/name) for name in
                          ['6_final.v', '6_final.sdc', '6_final.spef']},
               'scripts': {str(p.relative_to(repo)): sha(p) for p in
                           sorted((repo/'flow/closure').glob('*.tcl'))}}
    for corner in a.corners:
        env = dict(os.environ, ORFS_ROOT=str(a.orfs_root), RESULT_DIR=str(a.result_dir), AUDIT_CORNER=corner)
        report = a.output/f'{corner}.rpt'
        start = time.monotonic()
        with report.open('w') as stream:
            proc = subprocess.Popen([str(a.orfs_root/'tools/install/OpenROAD/bin/sta'), '-no_splash',
                                     str(repo/'flow/closure/audit_candidate.tcl')],
                                    env=env, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                proc.wait(timeout=a.timeout)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGTERM)
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid, signal.SIGKILL); proc.wait()
                raise RuntimeError(f'{corner} timed out; owned process stopped; preserved {report}')
        if proc.returncode:
            raise RuntimeError(f'{corner} STA exit {proc.returncode}: {report}')
        metrics, passed = parse_report(report.read_text())
        libs = re.findall(r'(?m)^LIBERTY (.+)$', report.read_text())
        if len(libs) != 5 or len(set(libs)) != 5: raise ValueError('Expected five unique libraries')
        row = {'corner': corner, 'timing_drv_pass': passed, 'metrics': metrics,
               'wall_seconds': time.monotonic()-start, 'report_sha256': sha(report),
               'liberty': {p: sha(p) for p in libs}}
        summary['views'].append(row)
        (a.output/'matrix.json').write_text(json.dumps(summary, indent=2)+'\n')
        print(json.dumps(row), flush=True)
    # Report creation succeeds independently of whether the design passes.
    # Strict verification is the default; --collect-only is explicitly diagnostic.
    if not a.collect_only and not all(row['timing_drv_pass'] for row in summary['views']):
        raise SystemExit(2)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--orfs-root', type=Path, required=True)
    p.add_argument('--result-dir', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--corners', nargs='+', choices=['FF','TT','SS'], default=['FF','TT','SS'])
    p.add_argument('--timeout', type=int, default=600)
    p.add_argument('--collect-only', action='store_true')
    main(p.parse_args())
