#!/usr/bin/env python3
"""Content-guarded, time-bounded CNN flow; no silent stale-checkpoint reuse."""
import argparse
import hashlib
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(REPO/'tools'))
from checkpoint_guard import guard
from run_closure_matrix import sha

p=argparse.ArgumentParser()
p.add_argument('--orfs-root',type=Path,required=True)
p.add_argument('--variant',required=True)
p.add_argument('--stage',choices=['synth','floorplan','place','cts','route','finish'],default='place')
p.add_argument('--timeout',type=int,default=900)
p.add_argument('--threads',type=int,default=2)
a=p.parse_args()
if not a.variant or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in a.variant): p.error('Invalid variant')
if a.threads<1 or a.timeout<1: p.error('Positive threads and timeout required')
root=a.orfs_root.resolve()
files=[REPO/'experiments/cnn/rtl/int8_dw3x1.sv',REPO/'experiments/cnn/flow/config.mk',
       REPO/'experiments/cnn/flow/constraint.sdc',Path(__file__).resolve(),REPO/'tools/checkpoint_guard.py']
for folder in ['flow/scripts','flow/util','flow/platforms/asap7']:
    files += [f for f in (root/folder).rglob('*') if f.is_file()]
files += [root/n for n in ['flow/Makefile','tools/install/OpenROAD/bin/openroad','tools/install/yosys/bin/yosys']]
inputs={'corner':'BC','threads':a.threads,'files':{str(f):sha(f) for f in sorted(set(files))}}
roots=[root/f'flow/{kind}/asap7/int8_dw3x1/{a.variant}' for kind in ['results','logs','reports']]
with tempfile.NamedTemporaryFile() as tmp:
    tmp.write((json.dumps(inputs,sort_keys=True,indent=2)+'\n').encode()); tmp.flush()
    guard(roots,Path(tmp.name))
out=roots[0]; log_path=out/f'bounded_{a.stage}.log'
env=dict(os.environ)
env['PATH']=str(root/'tools/install/OpenROAD/bin')+':'+str(root/'tools/install/yosys/bin')+':'+env['PATH']
cmd=['make','-C',str(root/'flow'),f'DESIGN_CONFIG={REPO}/experiments/cnn/flow/config.mk',
     f'FLOW_VARIANT={a.variant}',f'NUM_CORES={a.threads}','CORNER=BC',a.stage]
start=time.monotonic(); timed_out=False
with log_path.open('w') as log:
    proc=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    try: proc.wait(timeout=a.timeout)
    except subprocess.TimeoutExpired:
        timed_out=True; os.killpg(proc.pid,signal.SIGTERM)
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: os.killpg(proc.pid,signal.SIGKILL); proc.wait()
state={'stage':a.stage,'variant':a.variant,'exit_code':proc.returncode,'timeout':timed_out,
       'wall_seconds':time.monotonic()-start,'log_sha256':sha(log_path),
       'input_stamp_sha256':sha(out/'reproduction.inputs'),'command':cmd}
(out/f'bounded_{a.stage}.json').write_text(json.dumps(state,indent=2)+'\n')
print(json.dumps(state),flush=True)
if timed_out or proc.returncode: raise SystemExit(2)
