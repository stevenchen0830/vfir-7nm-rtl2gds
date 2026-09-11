#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from run_closure_matrix import sha

p=argparse.ArgumentParser(); p.add_argument('directory',type=Path); a=p.parse_args()
repo=Path(__file__).resolve().parents[1]
cases=['c2','c4_relu','edge_1x1','edge_q31','reset_restart','bias_extremes_q31','bias_extremes_q0']
rows=[]
for name in cases:
    root=a.directory/name; data=json.loads((root/'results.json').read_text())
    if 'CNN PASS' not in data['simulation'] or not data['distinct_frames']: raise ValueError(name)
    rows.append({'case':name,'frames':data['frames'],'beats':data['pixel_beats'],
                 'comparisons':data['component_checks'],
                 'files':{str(f.relative_to(a.directory)):sha(f) for f in
                          [root/'results.json',root/'simulation.log',root/'tb.sv']}})
summary={'scope':'integer operator and protocol regression, not trained model accuracy',
         'frames':sum(r['frames'] for r in rows),'beats':sum(r['beats'] for r in rows),
         'comparisons':sum(r['comparisons'] for r in rows),'cases':rows,
         'sources':{str(f.relative_to(repo)):sha(f) for f in
                    [repo/'experiments/cnn/rtl/int8_dw3x1.sv',repo/'experiments/cnn/test_cnn.py',repo/'experiments/cnn/run_tests.sh']}}
(a.directory/'suite_manifest.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k not in ['cases','sources']}))
