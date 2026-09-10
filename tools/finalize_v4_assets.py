#!/usr/bin/env python3
"""Finalize a release only after the standalone STA/SDF export completed."""
import argparse
import gzip
import json
import shutil
from pathlib import Path
from export_v4_assets import sha


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--assets',type=Path,required=True)
    p.add_argument('--repo',type=Path,required=True); a=p.parse_args()
    report=a.repo/'reports/v4_reproduced_ff_u100.rpt'
    audit=json.loads(report.with_suffix('.manifest.json').read_text())
    if 'DONE_MARKER' not in report.read_text() or sha(report)!=audit['report_sha256']:
        raise RuntimeError('STA report incomplete or changed')
    sdf=a.assets/'v4_ff.sdf'
    if sha(sdf)!=audit['derived_sdf']['sha256']: raise RuntimeError('SDF hash mismatch')
    dest=a.assets/'v4_ff_derived_20260910.sdf.gz'
    with sdf.open('rb') as src, dest.open('wb') as raw:
        with gzip.GzipFile(filename='',mode='wb',fileobj=raw,mtime=0) as dst: shutil.copyfileobj(src,dst)
    manifest=json.loads((a.assets/'asset-manifest.json').read_text())
    manifest['files']=[f for f in manifest['files'] if f['file']!=dest.name]
    manifest['files'].append({'file':dest.name,'sha256':sha(dest),'uncompressed_sha256':sha(sdf),
                              'bytes':sdf.stat().st_size,'provenance':'new FF audit export, 2026-09-10; not original flow SDF, no SDF GLS claim'})
    manifest['audit']=audit
    manifest['sdf']='original run had no SDF; new derived single-FF export supplied separately'
    (a.assets/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    release_names=[f['file'] for f in manifest['files']]+['asset-manifest.json']
    (a.assets/'assets.sha256').write_text(''.join(f'{sha(a.assets/n)}  {n}\n' for n in sorted(release_names)))
    # The checkout work/ directory is ignored. Large release assets never enter Git.
    win=a.repo/'work/v4-release'; win.mkdir(parents=True,exist_ok=True)
    for name in release_names+['assets.sha256']: shutil.copy2(a.assets/name,win/name)
    shutil.copy2(a.assets/'asset-manifest.json',a.repo/'reports/v4_asset_manifest.json')
    shutil.copy2(a.assets/'assets.sha256',a.repo/'reports/v4_release_assets.sha256')
    print(json.dumps({'files':len(release_names)+1,'release_dir':str(win),'bytes':sum((win/n).stat().st_size for n in release_names)}))
