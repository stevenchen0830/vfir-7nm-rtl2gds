#!/usr/bin/env python3
"""Collect exact bytes/hashes from completed runs; never invent pass results."""
import argparse
import json
import re
import shutil
from pathlib import Path
from run_closure_matrix import sha

p=argparse.ArgumentParser()
p.add_argument('--orfs-root',type=Path,required=True)
p.add_argument('--cnn-variant')
p.add_argument('--cnn-dest',type=Path)
p.add_argument('--eco-dir',type=Path)
p.add_argument('--eco-dest',type=Path)
a=p.parse_args()
repo=Path(__file__).resolve().parents[1]
if a.cnn_variant:
    logs=a.orfs_root/f'flow/logs/asap7/int8_dw3x1/{a.cnn_variant}'
    reports=a.orfs_root/f'flow/reports/asap7/int8_dw3x1/{a.cnn_variant}'
    results=a.orfs_root/f'flow/results/asap7/int8_dw3x1/{a.cnn_variant}'
    dest=a.cnn_dest; dest.mkdir(parents=True,exist_ok=True)
    for source,name in [(logs/'6_report.json','6_metrics.json'), (reports/'6_finish.rpt','6_finish.rpt'),
                        (reports/'5_route_drc.rpt','5_route_drc.rpt'),(logs/'5_2_route.log','5_2_route.rpt'),
                        (results/'6_final.sdc','6_final.sdc'),(results/'reproduction.inputs','reproduction.inputs'),
                        (results/'bounded_finish.json','bounded_finish.json')]:
        shutil.copyfile(source,dest/name)
    data=json.loads((logs/'6_report.json').read_text())
    finish=(reports/'6_finish.rpt').read_text()
    drc_text=(logs/'5_2_route.log').read_text()
    drcs=re.findall(r'Number of violations\s*[=:]\s*(\d+)',drc_text,re.I)
    if not drcs: raise ValueError('No explicit final DRT violation count')
    timing_counts={key:int(re.search(rf'{key} violation count (\d+)',finish)[1])
                   for key in ['setup','hold','max slew','max cap','max fanout']}
    (dest/'drc_summary.json').write_text(json.dumps({'geometric_drt_violations':int(drcs[-1]),
        'source':'5_2_route.rpt','sha256':sha(dest/'5_2_route.rpt')},indent=2)+'\n')
    summary={'variant':a.cnn_variant,'view':'BC/FF; 1000ps; 100/30ps; extracted final SPEF',
       'timing_electrical_counts':timing_counts,'routing_drc':int(drcs[-1]),
       'stage_metrics':{k:v for k,v in data.items() if any(s in k for s in ['__ws','__tns','instance__area__stdcell','power__total'])},
       'power_scope':'vectorless default activity, NOT workload inference energy',
       'final_inputs':{n:sha(results/n) for n in ['6_final.v','6_final.odb','6_final.def','6_final.spef','6_final.sdc']},
       'evidence_files':{f.name:sha(f) for f in dest.iterdir() if f.is_file() and f.name!='summary.json'}}
    (dest/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))
if a.eco_dir:
    a.eco_dest.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((a.eco_dir/'manifest.json').read_text())
    if manifest['status']!='EXPERIMENT_COMPLETED_NOT_SIGNOFF': raise ValueError('ECO not completed')
    if sha(a.eco_dir/'eco.log')!=manifest['outputs']['eco.log']: raise ValueError('ECO log hash mismatch')
    shutil.copyfile(a.eco_dir/'eco.log',a.eco_dest/'eco.rpt')
    shutil.copyfile(a.eco_dir/'manifest.json',a.eco_dest/'manifest.json')
    print('Collected ECO evidence',a.eco_dest)
