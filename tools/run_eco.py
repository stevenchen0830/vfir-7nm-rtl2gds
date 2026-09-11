#!/usr/bin/env python3
"""Isolated, bounded DRV repair; original v4 checkpoints stay untouched."""
import argparse
import json
import os
import signal
import subprocess
import time
from pathlib import Path
from run_closure_matrix import sha

p=argparse.ArgumentParser()
p.add_argument('--orfs-root',type=Path,required=True)
p.add_argument('--result-dir',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--timeout',type=int,default=900)
p.add_argument('--script',choices=['eco_drv.tcl','eco_timing.tcl'],default='eco_drv.tcl')
p.add_argument('--eco-input',type=Path)
a=p.parse_args()
if a.script=='eco_timing.tcl' and a.eco_input is None: p.error('--eco-input required for timing cleanup')
if a.output.exists() and any(a.output.iterdir()): p.error('Use a fresh ECO output directory')
a.output.mkdir(parents=True,exist_ok=True)
repo=Path(__file__).resolve().parents[1]
manifest={'corner':'FF','target_period_ps':1000,'setup_uncertainty_ps':150,
          'hold_uncertainty_ps':30,'status':'RUNNING','post_repair_view':'placement_estimate',
          'inputs':{n:sha(a.result_dir/n) for n in ['6_final.odb','6_final.v','6_final.sdc','6_final.spef']},
          'scripts':{str(f.relative_to(repo)):sha(f) for f in (repo/'flow/closure').glob('*.tcl')}}
env=dict(os.environ,ORFS_ROOT=str(a.orfs_root),RESULT_DIR=str(a.result_dir),
         AUDIT_CORNER='FF',ECO_OUTPUT=str(a.output))
manifest['driver_sha256']=sha(Path(__file__))
if a.eco_input:
    env['ECO_INPUT']=str(a.eco_input)
    manifest['eco_inputs']={n:sha(a.eco_input/n) for n in ['2_legalized.odb','2_legalized.v','2_legalized.sdc']}
start=time.monotonic()
manifest_path=a.output/'manifest.json'; manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
with (a.output/'eco.log').open('w') as log:
    proc=subprocess.Popen([str(a.orfs_root/'tools/install/OpenROAD/bin/openroad'),'-exit','-no_init',
                           str(repo/'flow/closure'/a.script)],env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    manifest['pid']=proc.pid; manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    try: proc.wait(timeout=a.timeout)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid,signal.SIGTERM)
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: os.killpg(proc.pid,signal.SIGKILL); proc.wait()
        manifest['status']='TIMEOUT_NO_AUTORETRY'
    else:
        text=(a.output/'eco.log').read_text()
        manifest['status']='EXPERIMENT_COMPLETED_NOT_SIGNOFF' if proc.returncode==0 and 'ECO_DONE' in text and '[ERROR' not in text else 'FAILED_NO_AUTORETRY'
manifest['exit_code']=proc.returncode
manifest['wall_seconds']=time.monotonic()-start
manifest['outputs']={f.name:sha(f) for f in a.output.iterdir() if f.is_file() and f.name!='manifest.json'}
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest),flush=True)
if manifest['status']!='EXPERIMENT_COMPLETED_NOT_SIGNOFF': raise SystemExit(2)
