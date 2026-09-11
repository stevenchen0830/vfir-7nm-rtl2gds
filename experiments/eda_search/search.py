#!/usr/bin/env python3
"""Real ORFS placement trials: random vs online RBF-regression search.

Equal number of evaluations, fixed timing constraints; cache charges original
runtime to both algorithms. Placement metrics are not routed/signoff PPA.
"""
import argparse
import hashlib
import itertools
import json
import math
import os
import random
import signal
import subprocess
import time
from pathlib import Path


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()


def select(pool, seen):
    # Small-data kernel regression with distance-based exploration.
    def acquisition(x):
        distances=[sum((a-b)**2 for a,b in zip(x,r['point'])) for r in seen]
        weights=[math.exp(-d/0.08) for d in distances]
        predicted=sum(w*r['objective'] for w,r in zip(weights,seen))/(sum(weights)+1e-12)
        return predicted-0.1*math.sqrt(min(distances))
    return min(pool,key=acquisition)


def get_metric(data,suffix):
    matches=[v for k,v in data.items() if k.endswith(suffix)]
    if len(matches)!=1: raise ValueError(f'Expected one {suffix}, got {matches}')
    return float(matches[0])


def load_cached(cached, metrics):
    """Reject stale/tampered evidence instead of trusting a cache filename."""
    row = json.loads(cached.read_text())
    if not metrics.is_file() or sha(metrics) != row['metrics_sha256']:
        raise ValueError(f'Cache evidence mismatch: {metrics}')
    data = json.loads(metrics.read_text())
    for field, suffix in [('area_um2', 'design__instance__area__stdcell'),
                          ('setup_ws_ps', 'timing__setup__ws'),
                          ('hold_ws_ps', 'timing__hold__ws'), ('power_w', 'power__total')]:
        if row[field] != get_metric(data, suffix):
            raise ValueError(f'Cache metric mismatch: {cached}: {field}')
    return row


def main(a):
    root=a.orfs_root.resolve(); output=a.output.resolve(); output.mkdir(parents=True,exist_ok=True)
    design=root/f'flow/designs/asap7/{a.design}/config.mk'
    if not design.is_file(): raise FileNotFoundError(design)
    revision=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
    # Include the effective tool/platform/scripts, not only a Git revision:
    # a dirty ORFS hook or newer Liberty can otherwise silently reuse stale PPA.
    files=list((root/f'flow/designs/src/{a.design}').rglob('*'))+list(design.parent.glob('*'))
    files+=list((root/'flow/platforms/asap7').rglob('*'))
    files+=list((root/'flow/scripts').rglob('*'))+list((root/'flow/util').rglob('*'))
    files+=[root/'flow/Makefile',root/'tools/install/OpenROAD/bin/openroad',root/'tools/install/yosys/bin/yosys']
    hashes={str(p.relative_to(root)):sha(p) for p in sorted(set(files)) if p.is_file()}
    tool=root/'tools/install/OpenROAD/bin/openroad'
    version=subprocess.check_output([str(tool),'-version'],text=True).strip()
    yosys_version=subprocess.check_output([str(root/'tools/install/yosys/bin/yosys'),'-V'],text=True).strip()
    context={'orfs_commit':revision,'openroad':version,'yosys':yosys_version,
             'driver_sha256':sha(Path(__file__)),'input_hashes':hashes,'corner':'BC','stage':'place','threads':2}
    points=list(itertools.product([0.20,0.30,0.40],[0.45,0.55,0.65]))
    if not 3<=a.budget<=len(points): raise ValueError('budget must be 3..9')
    results={}
    for algorithm in ['random','rbf_surrogate']:
        rng=random.Random(a.seed); pool=points.copy(); rng.shuffle(pool); seen=[]
        for i in range(a.budget):
            point=pool[0] if algorithm=='random' or i<2 else select(pool,seen)
            pool.remove(point)
            key=hashlib.sha256(json.dumps([context,point],sort_keys=True).encode()).hexdigest()[:16]
            cached=output/f'{key}.json'; variant=f'ai_search_{key}'
            if cached.exists():
                row=load_cached(cached, output/f'{key}.metrics.json'); row['cache_hit']=True
            else:
                command=['make','-C',str(root/'flow'),f'DESIGN_CONFIG={design}',
                         f'FLOW_VARIANT={variant}','CORNER=BC','NUM_CORES=2',
                         f'CORE_UTILIZATION={int(point[0]*100)}',f'PLACE_DENSITY={point[1]}','place']
                env=os.environ.copy()
                bins=[root/'tools/install/OpenROAD/bin',root/'tools/install/yosys/bin']
                env['PATH']=os.pathsep.join(map(str,bins))+os.pathsep+env['PATH']
                start=time.perf_counter()
                with (output/f'{key}.log').open('w') as log:
                    proc=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
                    try: proc.wait(timeout=a.timeout)
                    except subprocess.TimeoutExpired:
                        # Stop only this owned trial's process group, including
                        # make's OpenROAD/Yosys children. Preserve disk checkpoints.
                        os.killpg(proc.pid,signal.SIGTERM)
                        try: proc.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            os.killpg(proc.pid,signal.SIGKILL); proc.wait()
                        raise RuntimeError(f'Trial timed out; group stopped. Inspect {key}.log before continuing')
                elapsed=time.perf_counter()-start
                if proc.returncode: raise RuntimeError(f'ORFS failed: inspect {key}.log; search stopped')
                metrics=root/f'flow/logs/asap7/{a.design}/{variant}/3_5_place_dp.json'
                data=json.loads(metrics.read_text())
                area=get_metric(data,'design__instance__area__stdcell')
                ws=get_metric(data,'timing__setup__ws')
                power=get_metric(data,'power__total')
                # Ranking only, not a signoff pass criterion. No SDC weakening.
                row={'point':point,'area_um2':area,'setup_ws_ps':ws,'power_w':power,
                     'setup_pass':ws>=0,'hold_ws_ps':get_metric(data,'timing__hold__ws'),
                     'objective':area/1000+max(0,-ws)/1000,
                     'wall_seconds':elapsed,'metrics_sha256':hashlib.sha256(metrics.read_bytes()).hexdigest(),
                     'variant':variant,'cache_hit':False}
                # Publish exactly the bytes hashed above. JSON reformatting
                # changes SHA256 even when every numerical value is identical.
                (output/f'{key}.metrics.json').write_bytes(metrics.read_bytes())
                cached.write_text(json.dumps(row,indent=2)+'\n')
            seen.append(row)
            print(json.dumps({'algorithm':algorithm,'iteration':i+1,**row}),flush=True)
        results[algorithm]={'trials':seen,'best_objective':min(r['objective'] for r in seen),
                            'charged_wall_seconds':sum(r['wall_seconds'] for r in seen)}
    summary={'benchmark':a.design,'scope':'real ORFS placement, not detailed-route PPA',
             'budget_evaluations_per_algorithm':a.budget,'seed':a.seed,'context':context,
             'fairness':'same initial 2 points; equal evaluations, not equal wall-time; cached trials charged original runtime',
             'algorithms':results}
    (output/'comparison.json').write_text(json.dumps(summary,indent=2)+'\n')


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--orfs-root',type=Path,required=True)
    p.add_argument('--design',default='gcd'); p.add_argument('--budget',type=int,default=4)
    p.add_argument('--seed',type=int,default=42); p.add_argument('--timeout',type=int,default=300)
    p.add_argument('--output',type=Path,default=Path('experiments/eda_search/results'))
    main(p.parse_args())
