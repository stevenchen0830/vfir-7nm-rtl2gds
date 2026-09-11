#!/usr/bin/env python3
"""Conservative content stamp for a named physical-flow checkpoint set."""
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


root=Path(os.environ['ORFS_ROOT']).resolve()
repo=Path(__file__).resolve().parents[1]
files={}
for directory in ['rtl','flow/asap7']:
    for p in sorted((repo/directory).rglob('*')):
        if p.is_file(): files['repo/'+str(p.relative_to(repo))]=sha(p)
for p in [repo/'flow/run_stage.sh',repo/'tools/checkpoint_guard.py',Path(__file__).resolve()]: files['repo/'+str(p.relative_to(repo))]=sha(p)
for directory in ['flow/scripts','flow/util','flow/platforms/asap7']:
    for p in sorted((root/directory).rglob('*')):
        if p.is_file(): files['orfs/'+str(p.relative_to(root))]=sha(p)
for name in ['flow/Makefile','tools/install/OpenROAD/bin/openroad','tools/install/yosys/bin/yosys']:
    files['orfs/'+name]=sha(root/name)
print(json.dumps({'files':files,
                  'orfs_commit':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(),
                  'view':os.environ['VFIR_VIEW'],'corner':os.environ.get('CORNER','BC'),
                  'threads':os.environ.get('NUM_CORES','4')},sort_keys=True,indent=2))
