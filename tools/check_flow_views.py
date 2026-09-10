#!/usr/bin/env python3
"""Parse each config with GNU Make without invoking an implementation stage."""
from pathlib import Path
import subprocess
repo=Path(__file__).resolve().parents[1]
for config,sdc in [('config.mk','constraint_v4.sdc'),('config_v4.mk','constraint_v4.sdc'),('config_historical.mk','constraint_reported.sdc')]:
    make=f'include {repo}/flow/asap7/{config}\nprint:\n\t@echo $(SDC_FILE)\n'
    actual=subprocess.check_output(['make','--no-print-directory','-f','-','print'],input=make,text=True).strip()
    expected=str(repo/'flow/asap7'/sdc)
    if actual!=expected: raise RuntimeError(f'{config}: expected {expected}, got {actual}')
    print(f'FLOW VIEW PASS {config} -> {sdc}')
