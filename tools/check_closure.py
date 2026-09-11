#!/usr/bin/env python3
"""Read-only promotion gate: all requested corners, exact report hashes, zero violations.

This validates timing/DRV evidence, not missing foundry physical signoff.
"""
import argparse
import json
from pathlib import Path
from run_closure_matrix import parse_report, sha


def check(path, corners=('FF','TT','SS')):
    data=json.loads(Path(path).read_text())
    rows=data.get('views',[])
    if len(rows)!=len(corners) or {row['corner'] for row in rows}!=set(corners):
        raise ValueError('Missing or duplicate required PVT views')
    errors=[]
    for row in rows:
        report=Path(path).parent/f"{row['corner']}.rpt"
        if sha(report)!=row['report_sha256']: raise ValueError(f'Report hash mismatch: {report}')
        metrics,passed=parse_report(report.read_text())
        if metrics!=row['metrics'] or passed!=row['timing_drv_pass']:
            raise ValueError(f'Summary/report mismatch: {report}')
        if not passed: errors.append(f"{row['corner']}: nonzero timing/DRV violations")
    return errors


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('matrix',type=Path)
    a=p.parse_args()
    try: problems=check(a.matrix)
    except (ValueError,KeyError,OSError) as exc: p.exit(2,str(exc)+'\n')
    if problems: p.exit(2,'NOT CLOSED\n'+'\n'.join(problems)+'\n')
    print('REQUESTED TIMING/DRV MATRIX PASS; not a foundry-signoff certificate')
