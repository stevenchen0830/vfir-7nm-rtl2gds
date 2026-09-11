#!/usr/bin/env python3
"""Bounded, recorded candidate validation. No physical result is inherited."""
import argparse
import hashlib
import json
import os
import re
import signal
import subprocess
import time
from pathlib import Path

REPO=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--verilator',default='verilator')
    p.add_argument('--suite',choices=['smoke','full'],default='smoke')
    p.add_argument('--engine',choices=['iverilog','verilator'],default='iverilog')
    p.add_argument('--timeout',type=int,default=1200,help='Per command wall limit, seconds')
    a=p.parse_args(); a.output=a.output.resolve()
    if a.output.exists() and any(a.output.iterdir()): p.error('Use a fresh output directory')
    a.output.mkdir(parents=True)
    meta={'status':'RUNNING','suite':a.suite,'engine':a.engine,
          'simulation_semantics':'four-state' if a.engine=='iverilog' else 'two-state; does not prove X behavior',
          'physical_status':'NOT_RUN','commands':[], 'sources':{}}
    inputs=[Path(__file__),REPO/'experiments/fir_pipeline/build_variant.py',
            REPO/'rtl/img_filter.v',REPO/'rtl/img_filter_def.v',REPO/'verification/img_filter_tb.v',
            REPO/'experiments/fir_pipeline/rtl/fir_mac_pipeline.v',
            REPO/'experiments/fir_pipeline/verification/mac_tb.sv']
    for f in inputs: meta['sources'][str(f.relative_to(REPO))]=hashlib.sha256(f.read_bytes()).hexdigest()
    def save(): (a.output/'verification.json').write_text(json.dumps(meta,indent=2)+'\n')
    def run(name,cmd,marker=None,expected_failure=False):
        row={'name':name,'argv':[str(x) for x in cmd]}; meta['commands'].append(row); save()
        print('RUN '+name,flush=True); start=time.monotonic()
        log=a.output/(name+'.log')
        with log.open('w') as f:
            proc=subprocess.Popen(row['argv'],cwd=REPO,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
            try: proc.wait(timeout=a.timeout)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid,signal.SIGTERM)
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired: os.killpg(proc.pid,signal.SIGKILL); proc.wait()
                row['timeout']=True
        row.update(exit_code=proc.returncode,wall_seconds=time.monotonic()-start,
                   log=log.name,sha256=hashlib.sha256(log.read_bytes()).hexdigest())
        output=log.read_text(errors='replace')
        row['pass']=((proc.returncode!=0) if expected_failure else (proc.returncode==0)) and not row.get('timeout',False)
        if marker: row['pass']=row['pass'] and marker in output
        save()
        if not row['pass']: raise RuntimeError('Failed '+name+'; see '+str(log))
        print('PASS '+name+' '+str(round(row['wall_seconds'],2))+'s',flush=True)
        return output
    save()
    try:
        run('tools',['iverilog','-V'])
        run('generate',['python3',REPO/'experiments/fir_pipeline/build_variant.py',a.output/'generated'])
        mac=REPO/'experiments/fir_pipeline/rtl/fir_mac_pipeline.v'
        run('mac_compile',['iverilog','-g2012','-s','mac_tb','-o',a.output/'mac.vvp',mac,
                          REPO/'experiments/fir_pipeline/verification/mac_tb.sv'])
        run('mac_test',['vvp',a.output/'mac.vvp'],'MAC PASS')
        run('mac_negative',['vvp',a.output/'mac.vvp','+FAULT'],'MAC MISMATCH',True)
        top=a.output/'generated/img_filter.v'
        run('lint',[a.verilator,'--lint-only','-I'+str(REPO/'rtl'),'-Wno-UNSIGNED',
                    '--top-module','IMG_FILTER',top,mac])
        files=[REPO/'rtl/img_filter_def.v',top,mac,REPO/'verification/img_filter_tb.v']
        if a.engine=='iverilog':
            run('compile',['iverilog','-g2012','-s','img_filter_tb','-o',a.output/'frame.vvp',*files])
            executable=['vvp',a.output/'frame.vvp']
        else:
            run('verilator_version',[a.verilator,'--version'])
            run('compile',[a.verilator,'--binary','--timing','-j','2','-Wno-fatal',
                           '-I'+str(REPO/'rtl'),'--top-module','img_filter_tb',
                           '--Mdir',a.output/'obj_dir',*files])
            executable=[a.output/'obj_dir/Vimg_filter_tb']
        args=['+SEED=12345678']+(['+SMOKE'] if a.suite=='smoke' else [])
        output=run('frames',executable+args,'TEST PASSED')
        match=re.search(r'== (\d+) frames, (\d+) component checks, (\d+) errors',output)
        if not match or int(match[1])!=(13 if a.suite=='smoke' else 54) or int(match[3])!=0:
            raise ValueError('Frame count/error gate failed')
        meta['frames']=int(match[1]); meta['component_checks']=int(match[2])
        meta['status']='FUNCTIONAL_PASS_NOT_PHYSICAL_SIGNOFF'; save()
    except BaseException:
        meta['status']='FAILED_NO_AUTORETRY'; save(); raise


if __name__=='__main__': main()
