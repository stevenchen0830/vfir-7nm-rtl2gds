#!/usr/bin/env python3
"""Collect measured extension logs without inventing simulation or PPA results."""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()


def uvm(source, repo):
    dest=repo/'docs/audit/uvm_functional'; dest.mkdir(parents=True,exist_ok=True)
    files=sorted(source.glob('k*_w*.log'))+[source/'learned.log',source/'FAULT_DATA.log',source/'FAULT_SRAM.log']
    rows=[]
    for p in files:
        text=p.read_text()
        negative=p.name.startswith('FAULT_')
        if negative:
            if 'MISMATCH' not in text: raise RuntimeError(f'Negative test not detected: {p}')
        elif 'UVM FILTER PASSED' not in text or re.search(r'UVM_(?:ERROR|FATAL)\s*:\s*[1-9]',text):
            raise RuntimeError(f'Missing clean UVM pass: {p}')
        shutil.copy2(p,dest/p.name)
        rows.append({'log':p.name,'sha256':sha(p),'expected_failure':negative,
                     'evidence_lines':[line for line in text.splitlines() if any(s in line for s in ['UVM FILTER PASSED','COVERAGE','SRAM COVERAGE','MISMATCH','UVM_ERROR :','UVM_FATAL :'])]})
    (dest/'summary.json').write_text(json.dumps({'scope':'17 single-frame functional tests, 2 injected-fault negative controls; no coverage-closure claim','tests':rows},indent=2)+'\n')
    print('UVM logs collected',len(rows))


def placement(root, repo):
    logs=root/'flow/logs/asap7/int8_dw3x1/cnn_pilot_20260910'
    dest=repo/'experiments/cnn/results/placement'; dest.mkdir(parents=True,exist_ok=True)
    for name in ['1_2_yosys.log','3_5_place_dp.log','3_5_place_dp.json']:
        shutil.copy2(logs/name,dest/name)
    data=json.loads((logs/'3_5_place_dp.json').read_text())
    def metric(s):
        m=[v for k,v in data.items() if k.endswith(s)]
        if len(m)!=1: raise ValueError(s)
        return m[0]
    costs=[]
    for p in sorted(logs.glob('*.log')):
        m=re.findall(r'Elapsed time: (\S+)\[h:\]min:sec.*?Peak memory: (\d+)KB',p.read_text())
        if m:
            t,mem=m[-1]; seconds=sum(float(v)*60**i for i,v in enumerate(reversed(t.split(':'))))
            costs.append({'stage':p.stem,'wall_seconds':seconds,'peak_memory_kib':int(mem),'log_sha256':sha(p)})
    result={'scope':'ASAP7 BC, placement estimate, ideal clocks, not routed or signed off',
            'configuration':'WIDTH=8 HEIGHT=8 CHANNELS=2 QSHIFT=7 RELU=0',
            'period_ps':1000,'uncertainty_setup_hold_ps':[100,30],
            'stdcell_area_um2':metric('design__instance__area__stdcell'),
            'setup_ws_ps':metric('timing__setup__ws'),'hold_ws_ps':metric('timing__hold__ws'),
            'vectorless_power_w':metric('power__total'),'stage_costs':costs,
            'source_hashes':{str(p.relative_to(repo)):sha(p) for p in (repo/'experiments/cnn').glob('rtl/*.sv')},
            'metrics_sha256':sha(logs/'3_5_place_dp.json')}
    (dest/'summary.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result))


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--repo',type=Path,required=True)
    p.add_argument('--uvm-build',type=Path); p.add_argument('--orfs-root',type=Path)
    a=p.parse_args()
    if a.uvm_build: uvm(a.uvm_build,a.repo)
    if a.orfs_root: placement(a.orfs_root,a.repo)
