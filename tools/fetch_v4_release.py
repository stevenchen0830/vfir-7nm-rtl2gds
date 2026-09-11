#!/usr/bin/env python3
"""Anonymous, hash-pinned download of published v4 inputs. No GitHub login."""
import argparse
import gzip
import hashlib
import json
import shutil
import urllib.request
from pathlib import Path

REPO=Path(__file__).resolve().parents[1]
BASE='https://github.com/stevenchen0830/vfir-7nm-rtl2gds/releases/download/v4-reproduction-20260910/'


def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda:f.read(1024*1024),b''): h.update(part)
    return h.hexdigest()


def check_name(name):
    if Path(name).name!=name or '/' in name or '\\' in name or name in ('.','..'):
        raise ValueError('Unsafe asset name')


def fetch(output,row):
    name=row['file']; check_name(name); target=output/name
    if target.exists():
        if digest(target)!=row['sha256']: raise ValueError('Existing asset hash mismatch: '+name)
        return target
    part=output/(name+'.part')
    request=urllib.request.Request(BASE+name,headers={'User-Agent':'vfir-public-reproduction/1.0'})
    with urllib.request.urlopen(request,timeout=60) as response, part.open('xb') as stream:
        shutil.copyfileobj(response,stream,1024*1024)
    if digest(part)!=row['sha256']: raise ValueError('Downloaded hash mismatch; preserved '+str(part))
    part.rename(target)
    return target


def unpack(source,row):
    if 'uncompressed_sha256' not in row: return  # Do not auto-extract vendor tar.
    target=source.with_suffix('')
    if target.exists():
        if digest(target)!=row['uncompressed_sha256']: raise ValueError('Existing raw asset hash mismatch')
        return
    part=Path(str(target)+'.part')
    with gzip.open(source,'rb') as inp,part.open('xb') as out:
        shutil.copyfileobj(inp,out,1024*1024)
    if digest(part)!=row['uncompressed_sha256']: raise ValueError('Uncompressed asset hash mismatch')
    if part.stat().st_size!=row['bytes']: raise ValueError('Uncompressed asset size mismatch')
    part.rename(target)


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--selection',choices=['sta','all'],default='sta')
    p.add_argument('--unpack',action='store_true')
    a=p.parse_args(); a.output.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((REPO/'reports/v4_asset_manifest.json').read_text())
    sta={'6_final.v.gz','6_final.sdc.gz','6_final.spef.gz'}
    for row in manifest['files']:
        if a.selection=='sta' and row['file'] not in sta: continue
        target=fetch(a.output,row)
        if a.unpack: unpack(target,row)
        print('VERIFIED '+target.name,flush=True)
    print('Assets verified against the committed manifest; no STA/GLS pass is implied.')


if __name__=='__main__': main()
