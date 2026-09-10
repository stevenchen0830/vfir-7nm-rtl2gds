#!/usr/bin/env python3
"""Export original v4 physical inputs, unmodified vendor files, hashes and costs.

No tools are rerun and no legacy report is rewritten by this exporter.
"""
import argparse
import gzip
import hashlib
import json
import re
import shutil
import tarfile
from pathlib import Path


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''): h.update(chunk)
    return h.hexdigest()


def export(root, output, repo):
    result = root/'flow/results/asap7/img_filter/v4'
    output.mkdir(parents=True, exist_ok=True)
    manifest = {'source_variant': 'v4', 'files': [], 'sdf': 'not present in original run'}
    for name in ['6_final.v', '6_final.sdc', '6_final.spef', '6_final.def']:
        source = result/name
        dest = output/(name+'.gz')
        with source.open('rb') as src, dest.open('wb') as raw:
            with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as dst:
                shutil.copyfileobj(src, dst)
        manifest['files'].append({'file': dest.name, 'sha256': sha(dest),
                                  'uncompressed_sha256': sha(source), 'bytes': source.stat().st_size})
    vendor = []
    for family in ['AO','INVBUF','OA','SIMPLE','SEQ']:
        for corner in ['FF','TT','SS']:
            # Record all matching original views; the STA launcher selects an explicit list.
            vendor += sorted((root/'flow/platforms/asap7/lib/NLDM').glob(f'asap7sc7p5t_{family}_RVT_{corner}_nldm_*.lib*'))
    vendor += sorted((root/'flow/platforms/asap7/verilog/stdcell').glob('asap7*.v'))
    for path in vendor:
        opener = gzip.open if path.suffix == '.gz' else open
        with opener(path, 'rt') as f: header = f.read(4096)
        if 'BSD' not in header or 'Redistribution' not in header:
            raise RuntimeError(f'License header requires review: {path}')
    dest = output/'asap7_rvt_views.tar.gz'
    with tarfile.open(dest, 'w:gz') as tar:
        for path in vendor: tar.add(path, arcname=str(path.relative_to(root)))
    manifest['vendor_views'] = [{'path':str(p.relative_to(root)), 'sha256':sha(p)} for p in vendor]
    manifest['files'].append({'file':dest.name,'sha256':sha(dest)})
    (output/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (output/'assets.sha256').write_text(''.join(f"{sha(p)}  {p.name}\n" for p in sorted(output.iterdir()) if p.is_file() and p.name!='assets.sha256'))
    # Auditable wall-time snapshots; missing values stay unknown.
    rows=[]
    for log in sorted((root/'flow/logs/asap7/img_filter/v4').glob('*.log')):
        text=log.read_text(errors='replace')
        matches=re.findall(r'Elapsed time: (\S+)\[h:\]min:sec.*?Peak memory: (\d+)KB',text)
        if matches:
            t,mem=matches[-1]; parts=[float(v) for v in t.split(':')]
            seconds=sum(v*60**i for i,v in enumerate(reversed(parts)))
            rows.append({'stage':log.stem,'wall_seconds':seconds,'peak_memory_kib':int(mem), 'log_sha256':sha(log)})
    (repo/'reports/v4_stage_costs.json').write_text(json.dumps({'scope':'retained v4 stage logs; not cumulative failed/retried wall time','stages':rows},indent=2)+'\n')
    print(json.dumps({'output':str(output),'files':len(manifest['files']),'stage_costs':len(rows)}))


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--orfs-root',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True); p.add_argument('--repo',type=Path,required=True)
    a=p.parse_args(); export(a.orfs_root,a.output,a.repo)
