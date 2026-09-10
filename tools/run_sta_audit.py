#!/usr/bin/env python3
"""Bounded standalone audit with a completion marker and explicit raw inputs."""
import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--orfs-root',type=Path,required=True)
    p.add_argument('--result-dir',type=Path,required=True); p.add_argument('--output',type=Path,required=True)
    p.add_argument('--corner',choices=['FF','TT','SS'],default='FF'); p.add_argument('--u100',action='store_true')
    p.add_argument('--sdf',type=Path); a=p.parse_args()
    if a.u100 and a.corner!='FF': p.error('--u100 is the explicitly named FF sensitivity view')
    env=os.environ.copy(); env.update(ORFS_ROOT=str(a.orfs_root),RESULT_DIR=str(a.result_dir),AUDIT_CORNER=a.corner,AUDIT_U100='1' if a.u100 else '0')
    if a.sdf:
        a.sdf.parent.mkdir(parents=True,exist_ok=True)
        env['SDF_OUT']=str(a.sdf)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    with a.output.open('w') as log:
        r=subprocess.run([str(a.orfs_root/'tools/install/OpenROAD/bin/sta'),'-no_splash',str(Path(__file__).resolve().parents[1]/'flow/sta/run_candidate.tcl')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1200)
    text=a.output.read_text()
    if r.returncode or 'DONE_MARKER' not in text or any(line.startswith('Error') for line in text.splitlines()):
        raise RuntimeError(f'Audit did not complete: {a.output}')
    manifest={'corner':a.corner,'u100_override':a.u100,'parasitics':'single routed SPEF','checks':'timing and DRV; coverage not certified','inputs':{}}
    for name in ['6_final.v','6_final.spef','6_final.sdc']:
        manifest['inputs'][name]=sha(a.result_dir/name)
    manifest['liberty']={line[8:]:sha(Path(line[8:])) for line in text.splitlines() if line.startswith('LIBERTY ')}
    repo=Path(__file__).resolve().parents[1]
    manifest['scripts']={str(p.relative_to(repo)):sha(p) for p in [Path(__file__).resolve(),repo/'flow/sta/run_candidate.tcl',repo/'flow/asap7/audit_ff_u100.tcl']}
    manifest['sta_version']=subprocess.check_output([str(a.orfs_root/'tools/install/OpenROAD/bin/sta'),'-version'],text=True).strip()
    manifest['report_sha256']=sha(a.output)
    if a.sdf: manifest['derived_sdf']={'file':a.sdf.name,'sha256':sha(a.sdf),'scope':'newly exported single-corner audit artifact; not timing-simulation evidence'}
    a.output.with_suffix('.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('AUDIT COMPLETED',a.output)
