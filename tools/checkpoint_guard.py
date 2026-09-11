#!/usr/bin/env python3
"""Do not relabel unidentified/stale ORFS checkpoints as current inputs."""
import argparse
import os
from pathlib import Path


def guard(roots, stamp):
    payload = Path(stamp).read_bytes()
    target = Path(roots[0])/'reproduction.inputs'
    if target.exists():
        if target.read_bytes() != payload:
            raise ValueError('Inputs changed: use a NEW FLOW_VARIANT; checkpoint reuse rejected')
        return
    # Results alone are insufficient: stale logs/reports can also satisfy Make.
    for root in map(Path, roots):
        if root.exists() and any(root.iterdir()):
            raise ValueError(f'Unstamped nonempty variant rejected: {root}; use a NEW FLOW_VARIANT')
    target.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation: never overwrite a concurrent runner's provenance.
    with target.open('xb') as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())


if __name__ == '__main__':
    p=argparse.ArgumentParser(); p.add_argument('--stamp', type=Path, required=True)
    p.add_argument('roots', nargs='+', type=Path); a=p.parse_args()
    try: guard(a.roots, a.stamp)
    except (ValueError, FileExistsError) as exc: p.exit(2, str(exc)+'\n')
