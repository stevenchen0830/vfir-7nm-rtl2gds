#!/usr/bin/env python3
"""Copy completed, verified small regression artifacts; never simulator builds."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

p=argparse.ArgumentParser(); p.add_argument('source',type=Path); p.add_argument('target',type=Path)
p.add_argument('--structure',action='store_true')
a=p.parse_args()
if a.structure:
    meta=json.loads((a.source/'structure.json').read_text())
    if meta['status']!='GENERIC_CHECK_PASS': raise SystemExit('Generic structure check did not pass')
    if hashlib.sha256((a.source/'yosys.log').read_bytes()).hexdigest()!=meta['log_sha256']:
        raise SystemExit('Structure log hash mismatch')
    if a.target.exists() and any(a.target.iterdir()): raise SystemExit('Use a fresh archive directory')
    a.target.mkdir(parents=True,exist_ok=True)
    for name in ['structure.json','yosys.log']: shutil.copyfile(a.source/name,a.target/name)
    print('ARCHIVED structure '+str(a.target)); raise SystemExit(0)
meta=json.loads((a.source/'verification.json').read_text())
if meta['status']!='FUNCTIONAL_PASS_NOT_PHYSICAL_SIGNOFF': raise SystemExit('Not a completed passing regression')
if a.target.exists() and any(a.target.iterdir()): raise SystemExit('Use a fresh archive directory')
for row in meta['commands']:
    f=a.source/row['log']
    if hashlib.sha256(f.read_bytes()).hexdigest()!=row['sha256']: raise SystemExit('Log hash mismatch')
a.target.mkdir(parents=True,exist_ok=True)
for row in meta['commands']: shutil.copyfile(a.source/row['log'],a.target/row['log'])
shutil.copyfile(a.source/'verification.json',a.target/'verification.json')
shutil.copyfile(a.source/'generated/source-manifest.json',a.target/'source-manifest.json')
print('ARCHIVED '+str(a.target))
