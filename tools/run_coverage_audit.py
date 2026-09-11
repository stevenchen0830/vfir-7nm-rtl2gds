#!/usr/bin/env python3
"""Run timing-coverage diagnostics separately, with a hard timeout."""
import argparse
import json
import os
import subprocess
import time
from pathlib import Path
from run_closure_matrix import sha

p=argparse.ArgumentParser(); p.add_argument('--orfs-root',type=Path,required=True)
p.add_argument('--result-dir',type=Path,required=True); p.add_argument('--output',type=Path,required=True)
p.add_argument('--timeout',type=int,default=120); a=p.parse_args()
a.output.parent.mkdir(parents=True,exist_ok=True)
repo=Path(__file__).resolve().parents[1]
env=dict(os.environ,ORFS_ROOT=str(a.orfs_root),RESULT_DIR=str(a.result_dir),AUDIT_CORNER='FF')
start=time.monotonic()
with a.output.open('w') as log:
    try:
        r=subprocess.run([str(a.orfs_root/'tools/install/OpenROAD/bin/sta'),'-no_splash',
                          str(repo/'flow/closure/coverage.tcl')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=a.timeout)
        text=a.output.read_text()
        status='TOOL_CHECK_PASS_WITH_EXISTING_EXCEPTIONS' if r.returncode==0 and 'COVERAGE_TOOL_PASS 1' in text and 'COVERAGE_DONE' in text and 'Error' not in text else 'FAILED_OR_INCOMPLETE'
    except subprocess.TimeoutExpired:
        status='TIMEOUT_UNKNOWN'
summary={'status':status,'wall_seconds':time.monotonic()-start,'report_sha256':sha(a.output),
         'limitations':'Does not validate that false paths/reset assumptions are physically justified; no new exception added',
         'script_sha256':sha(repo/'flow/closure/coverage.tcl')}
a.output.with_suffix('.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary))
if status!='TOOL_CHECK_PASS_WITH_EXISTING_EXCEPTIONS': raise SystemExit(2)
