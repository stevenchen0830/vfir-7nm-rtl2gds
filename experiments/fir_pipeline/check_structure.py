#!/usr/bin/env python3
"""Bounded generic Yosys elaboration/check, explicitly not technology PPA."""
import argparse
import hashlib
import json
import os
import signal
import subprocess
import time
from pathlib import Path
from build_variant import REPO, generate

p=argparse.ArgumentParser(); p.add_argument('--yosys',required=True,type=Path)
p.add_argument('--output',required=True,type=Path); a=p.parse_args()
a.output=a.output.resolve()
if a.output.exists() and any(a.output.iterdir()): p.error('Use a fresh output directory')
a.output.mkdir(parents=True)
top=a.output/'img_filter.v'; top.write_bytes(generate())
inputs=[REPO/'rtl/img_filter_def.v',top,REPO/'experiments/fir_pipeline/rtl/fir_mac_pipeline.v']
if any('"' in str(x) or '\n' in str(x) for x in inputs): p.error('Unsupported path characters')
script='read_verilog -sv '+ ' '.join('"'+str(x)+'"' for x in inputs)
script+='; hierarchy -check -top IMG_FILTER; proc; opt; check -assert; stat; write_json "'+str(a.output/'generic.json')+'"'
start=time.monotonic()
with (a.output/'yosys.log').open('w') as log:
    proc=subprocess.Popen([str(a.yosys),'-p',script],stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    try: proc.wait(timeout=180)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid,signal.SIGTERM)
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: os.killpg(proc.pid,signal.SIGKILL); proc.wait()
meta={'status':'GENERIC_CHECK_PASS' if proc.returncode==0 else 'FAILED',
      'exit_code':proc.returncode,'wall_seconds':time.monotonic()-start,
      'scope':'generic elaboration and netlist checks only; no technology mapping or timing',
      'sources':{str(f.relative_to(REPO)):hashlib.sha256(f.read_bytes()).hexdigest() for f in
                 [Path(__file__),Path(__file__).with_name('build_variant.py'),REPO/'rtl/img_filter.v',inputs[0],inputs[2]]},
      'yosys_version':subprocess.check_output([str(a.yosys),'-V'],text=True).strip(),
      'generated_sha256':hashlib.sha256(top.read_bytes()).hexdigest(),
      'log_sha256':hashlib.sha256((a.output/'yosys.log').read_bytes()).hexdigest()}
if proc.returncode==0:
    design=json.loads((a.output/'generic.json').read_text())
    meta['modules']={}
    for name,module in design['modules'].items():
        cells=list(module.get('cells',{}).values())
        meta['modules'][name]={'cells':len(cells),
            'flop_bits':sum(len(c['connections'].get('Q',[])) for c in cells if 'dff' in c['type'].lower()),
            'latches':sum(1 for c in cells if 'latch' in c['type'].lower())}
        if meta['modules'][name]['latches']: meta['status']='FAILED_LATCH'
(a.output/'structure.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps(meta),flush=True)
if meta['status']!='GENERIC_CHECK_PASS': raise SystemExit(2)
