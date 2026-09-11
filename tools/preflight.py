#!/usr/bin/env python3
"""Read-only audit of pinned physical toolchain and public Liberty views."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

REPO=Path(__file__).resolve().parents[1]
PINS={'.':'8c009b0b663703fc3fe2f474eab918b12fffbaf6',
      'tools/OpenROAD':'46ab99414e396fbdd379a432ac664357355bd932',
      'tools/yosys':'a5af9d690a43744bf6b2cc3dea2717c16b54621c'}
VERSION_MARKERS={'openroad':'g46ab99414e','sta':'3.1.0','yosys':'a5af9d690'}


def version_matches(tool,version):
    return version.strip()=='3.1.0' if tool=='sta' else VERSION_MARKERS[tool] in version


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()


def main():
    p=argparse.ArgumentParser(); p.add_argument('--orfs-root',required=True,type=Path)
    p.add_argument('--output',required=True,type=Path); a=p.parse_args()
    if a.output.exists(): p.error('Use a new report filename; do not overwrite old provenance')
    report={'status':'CHECKING','source_commits':{},'tool_binaries':{},'missing_or_mismatched':[],
            'local_source_changes':{},'tracked_diff_sha256':{},'physical_signoff':'NOT_ESTABLISHED'}
    def command(args): return subprocess.check_output(args,text=True,stderr=subprocess.STDOUT,timeout=60).strip()
    for relative,expected in PINS.items():
        root=a.orfs_root/relative
        try:
            actual=command(['git','-C',str(root),'rev-parse','HEAD'])
            report['source_commits'][relative]=actual
            if actual!=expected: report['missing_or_mismatched'].append(relative+' commit')
            status=command(['git','-C',str(root),'status','--short','-uno'])
            report['local_source_changes'][relative]=status
            diff=subprocess.check_output(['git','-C',str(root),'diff','HEAD','--binary'])
            report['tracked_diff_sha256'][relative]=hashlib.sha256(diff).hexdigest()
            if status:
                report['missing_or_mismatched'].append(relative+' has local changes: archive/review diff before matched reproduction')
        except (subprocess.SubprocessError,OSError) as exc:
            report['missing_or_mismatched'].append(relative+': '+str(exc))
    for relative,args in [('tools/install/OpenROAD/bin/openroad',['-version']),
                          ('tools/install/OpenROAD/bin/sta',['-version']),
                          ('tools/install/yosys/bin/yosys',['-V'])]:
        path=a.orfs_root/relative
        try:
            version=command([str(path),*args])
            report['tool_binaries'][relative]={'sha256':sha(path),'version':version}
            if not version_matches(path.name,version):
                report['missing_or_mismatched'].append(relative+' binary version does not match pin')
        except (OSError,subprocess.SubprocessError) as exc: report['missing_or_mismatched'].append(relative+': '+str(exc))
    report['liberty_views']={}
    for row in json.loads((REPO/'reports/v4_asset_manifest.json').read_text())['vendor_views']:
        path=a.orfs_root/row['path']
        actual=sha(path) if path.is_file() else None
        report['liberty_views'][row['path']]=actual
        if actual!=row['sha256']: report['missing_or_mismatched'].append(row['path'])
    rc=a.orfs_root/'flow/platforms/asap7/rcx_patterns.rules'
    report['extraction_rules_sha256']=sha(rc) if rc.exists() else None
    if not rc.exists(): report['missing_or_mismatched'].append(str(rc))
    report['rc_scope']='one supplied calibrated model; not independently characterized min/max RC corners'
    report['status']='READY_FOR_PINNED_RESEARCH_RUN' if not report['missing_or_mismatched'] else 'REVIEW_REQUIRED'
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(report,indent=2)+'\n')
    print(report['status']+': '+str(a.output))
    if report['missing_or_mismatched']:
        for item in report['missing_or_mismatched']: print('CHECK '+item)
        raise SystemExit(2)


if __name__=='__main__': main()
