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
      'reports/README.md','verification/uvm/README.md','experiments/README.md','docs/closure-progress.md',
      'docs/reproduce-from-scratch.md','docs/sram-interface-contract.md','experiments/fir_pipeline/README.md']
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
# Preserve the measured driver rather than rewriting historical provenance
# to pretend new fixes were present during the September 10 experiment.
if comparison['context']['driver_sha256']!=hashlib.sha256((repo/'experiments/eda_search/history/search_20260910.py').read_bytes()).hexdigest(): errors.append('EDA archived driver differs from measured run')
for algorithm in comparison['algorithms'].values():
    for row in algorithm['trials']:
        key=row['variant'].removeprefix('ai_search_')
        metric=repo/f'experiments/eda_search/results_matched/{key}.metrics.json'
        cache=repo/f'experiments/eda_search/results_matched/{key}.json'
        if not metric.is_file() or hashlib.sha256(metric.read_bytes()).hexdigest()!=row['metrics_sha256']:
            errors.append(f'EDA raw metrics hash mismatch: {key}'); continue
        data=json.loads(metric.read_text())
        cached=json.loads(cache.read_text())
        if cached['metrics_sha256']!=row['metrics_sha256']: errors.append(f'EDA cache/summary hash mismatch: {key}')
        for field,suffix in [('area_um2','design__instance__area__stdcell'), ('setup_ws_ps','timing__setup__ws'),
                             ('hold_ws_ps','timing__hold__ws'), ('power_w','power__total')]:
            values=[float(v) for k,v in data.items() if k.endswith(suffix)]
            if len(values)!=1 or values[0]!=row[field] or cached[field]!=row[field]:
                errors.append(f'EDA raw/cache/summary metric mismatch: {key}: {field}')
suite_path=repo/'experiments/cnn/results/final_20260911/suite_manifest.json'
suite=json.loads(suite_path.read_text())
for name,h in suite['sources'].items():
    if hashlib.sha256((repo/name).read_bytes()).hexdigest()!=h: errors.append(f'CNN suite source mismatch: {name}')
for case in suite['cases']:
    for name,h in case['files'].items():
        if hashlib.sha256((suite_path.parent/name).read_bytes()).hexdigest()!=h: errors.append(f'CNN test artifact mismatch: {name}')
for relative in ['reports/closure_20260911/matrix/matrix.json',
                 'experiments/cnn/results/final_20260911/audit/matrix.json']:
    matrix=repo/relative
    for row in json.loads(matrix.read_text())['views']:
        if hashlib.sha256((matrix.parent/(row['corner']+'.rpt')).read_bytes()).hexdigest()!=row['report_sha256']:
            errors.append(f'Closure report hash mismatch: {relative} {row["corner"]}')
physical=repo/'experiments/cnn/results/final_20260911/physical'
for name,h in json.loads((physical/'summary.json').read_text())['evidence_files'].items():
    if hashlib.sha256((physical/name).read_bytes()).hexdigest()!=h: errors.append(f'CNN physical evidence mismatch: {name}')
for meta_path in (repo/'experiments/fir_pipeline/results').glob('*/verification.json'):
    meta=json.loads(meta_path.read_text())
    if meta['status']!='FUNCTIONAL_PASS_NOT_PHYSICAL_SIGNOFF': errors.append(f'Incomplete FIR regression: {meta_path}')
    for name,h in meta['sources'].items():
        if hashlib.sha256((repo/name).read_bytes()).hexdigest()!=h: errors.append(f'FIR candidate source hash mismatch: {name}')
    for row in meta['commands']:
        if hashlib.sha256((meta_path.parent/row['log']).read_bytes()).hexdigest()!=row['sha256']:
            errors.append(f'FIR candidate log hash mismatch: {row["log"]}')
public_dir=repo/'reports/public_reproduction_20260911'
structure_dir=repo/'experiments/fir_pipeline/results/structure'
structure=json.loads((structure_dir/'structure.json').read_text())
if hashlib.sha256((structure_dir/'yosys.log').read_bytes()).hexdigest()!=structure['log_sha256']:
    errors.append('FIR generic structure log hash mismatch')
for name,h in structure['sources'].items():
    if hashlib.sha256((repo/name).read_bytes()).hexdigest()!=h: errors.append('FIR generic source mismatch: '+name)
public=json.loads((public_dir/'FF_u100.manifest.json').read_text())
if hashlib.sha256((public_dir/'FF_u100.rpt').read_bytes()).hexdigest()!=public['report_sha256']:
    errors.append('Anonymous-public-input STA report hash mismatch')
for name,h in public['inputs'].items():
    if h!=audit['inputs'][name]: errors.append('Public download / original candidate mismatch: '+name)
inventory=json.loads((repo/'reports/toolchain_inventory_20260911.json').read_text())
if hashlib.sha256((repo/'flow/toolchain/clockgate-min-net-size.patch').read_bytes()).hexdigest()!=inventory['tracked_diff_sha256']['.']:
    errors.append('Archived ORFS patch differs from measured toolchain diff')
if errors: raise SystemExit('\n'.join(errors))
print('REPRODUCTION CHECKS PASSED: links, exact STA inputs/scripts, UVM logs, legal coefficients, EDA raw hashes/cache/summary/budget')
