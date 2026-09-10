#!/usr/bin/env python3
"""Fast offline checks for public documentation and measured evidence."""
import hashlib
import json
import re
from pathlib import Path

repo=Path(__file__).resolve().parents[1]
errors=[]
docs=['README.md','docs/rtl-to-gds-walkthrough.md','docs/constraint-assumptions.md',
      'docs/physical-assets.md','docs/hold-study.md','docs/verification-status.md',
      'reports/README.md','verification/uvm/README.md','experiments/README.md']
for name in docs:
    p=repo/name; text=p.read_text(encoding='utf-8')
    for link in re.findall(r'\]\(([^)]+)\)',text)+re.findall(r'src="([^"]+)"',text):
        if '://' in link or link.startswith('#'): continue
        path=link.split('#')[0]
        if path and not (p.parent/path).exists(): errors.append(f'{name}: missing {path}')

audit=json.loads((repo/'reports/v4_reproduced_ff_u100.manifest.json').read_text())
report=repo/'reports/v4_reproduced_ff_u100.rpt'
if hashlib.sha256(report.read_bytes()).hexdigest()!=audit['report_sha256']: errors.append('New STA report hash mismatch')
if 'DONE_MARKER' not in report.read_text(): errors.append('New STA report incomplete')
for name,h in audit['scripts'].items():
    if hashlib.sha256((repo/name).read_bytes()).hexdigest()!=h: errors.append(f'Audit script hash mismatch: {name}')
if len(audit['liberty'])!=5: errors.append('Expected exactly five pinned audit libraries')

assets=json.loads((repo/'reports/v4_asset_manifest.json').read_text())
for name,h in audit['inputs'].items():
    row=next(f for f in assets['files'] if f['file']==name+'.gz')
    if row['uncompressed_sha256']!=h: errors.append(f'Release/STA input mismatch: {name}')

uvm=json.loads((repo/'docs/audit/uvm_functional/summary.json').read_text())
for row in uvm['tests']:
    p=repo/'docs/audit/uvm_functional'/row['log']
    if hashlib.sha256(p.read_bytes()).hexdigest()!=row['sha256']: errors.append(f'UVM log hash mismatch: {p.name}')
if len(uvm['tests'])!=19: errors.append('Expected 17 positive + 2 negative UVM logs')

learned=json.loads((repo/'experiments/learned_fir/results/results.json').read_text())
coef=learned['coefficients_full']
if coef!=coef[::-1] or sum(coef)!=128 or min(coef)<0: errors.append('Illegal learned coefficients')

comparison=json.loads((repo/'experiments/eda_search/results_matched/comparison.json').read_text())
if len(comparison['algorithms']['random']['trials'])!=len(comparison['algorithms']['rbf_surrogate']['trials']): errors.append('EDA budget mismatch')
if comparison['context']['driver_sha256']!=hashlib.sha256((repo/'experiments/eda_search/search.py').read_bytes()).hexdigest(): errors.append('EDA driver differs from measured run')
if errors: raise SystemExit('\n'.join(errors))
print('REPRODUCTION CHECKS PASSED: links, exact STA inputs/scripts, UVM logs, legal coefficients, EDA budget')
