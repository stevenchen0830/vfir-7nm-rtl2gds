#!/usr/bin/env python3
"""Independent min/max check of the same routed CNN candidate in three PVTs."""
import argparse
import json
import os
import subprocess
import time
from pathlib import Path
from run_closure_matrix import parse_report, sha

p=argparse.ArgumentParser()
p.add_argument('--orfs-root',type=Path,required=True)
p.add_argument('--result-dir',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(); a.output.mkdir(parents=True,exist_ok=True)
repo=Path(__file__).resolve().parents[1]
rows=[]
for corner in ['FF','TT','SS']:
    env=dict(os.environ,ORFS_ROOT=str(a.orfs_root),RESULT_DIR=str(a.result_dir),AUDIT_CORNER=corner)
    report=a.output/f'{corner}.rpt'; start=time.monotonic()
    with report.open('w') as stream:
        r=subprocess.run([str(a.orfs_root/'tools/install/OpenROAD/bin/sta'),'-no_splash',
                          str(repo/'experiments/cnn/flow/audit.tcl')],env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
    if r.returncode: raise RuntimeError(f'{corner} exit {r.returncode}')
    text=report.read_text(); metrics,passed=parse_report(text)
    rows.append({'corner':corner,'timing_drv_pass':passed,'metrics':metrics,
                 'constraint_check_pass':'CONSTRAINT_CHECK_PASS 1' in text,
                 'wall_seconds':time.monotonic()-start,'report_sha256':sha(report)})
    print(json.dumps(rows[-1]),flush=True)
summary={'scope':'1000ps, original CNN 100/30ps SDC, one extracted RC view; not foundry MMMC',
         'views':rows,'inputs':{n:sha(a.result_dir/n) for n in ['6_final.v','6_final.sdc','6_final.spef']},
         'script_sha256':sha(repo/'experiments/cnn/flow/audit.tcl')}
(a.output/'matrix.json').write_text(json.dumps(summary,indent=2)+'\n')
if not all(row['timing_drv_pass'] and row['constraint_check_pass'] for row in rows): raise SystemExit(2)
