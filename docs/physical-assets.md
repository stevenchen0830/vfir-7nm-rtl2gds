# Physical evidence and reproduction assets

The original v4 `6_final.v`, `6_final.def`, `6_final.sdc` and `6_final.spef`
were located in the historical ORFS `results/asap7/img_filter/v4` directory.
`tools/export_v4_assets.py` exports compressed copies plus both compressed
and uncompressed SHA-256 hashes. It also exports the original RVT Liberty
and cell-model views with their BSD 3-Clause copyright/license headers
unchanged. These upstream models are not relicensed under this repo's MIT
license and imply no endorsement by their authors.

Large files belong in a GitHub Release, not normal Git history.
**Availability (2026-09-10): uploaded and checksum-verified as an owner-visible
draft; public publication is pending explicit owner approval.** Repository
visitors cannot yet independently download this v4 set. The public source,
reports and input manifests are available, but that is not a complete public
STA reproduction bundle until the asset release is published.
The owner can inspect the draft through [GitHub Releases](https://github.com/stevenchen0830/vfir-7nm-rtl2gds/releases).
Its intended tag is `v4-reproduction-20260910`.
Use the asset manifest to distinguish v4 from the earlier
`signoff-evidence-v1` release containing v3/wc/sel inputs.

## Integrity versus reproduction

1. `reports/manifest_v4.sha256`: verifies six historical report files only.
2. Release `assets.sha256`: verifies the downloaded compressed assets.
3. `asset-manifest.json`: maps each original physical input to its raw hash.
4. Standalone STA additionally needs the pinned tool, exact Liberty versions,
   original final SDC and explicit uncertainty override.
5. Mapped GLS additionally needs compatible cell models and an SRAM/stream
   testbench. SDF GLS must check annotation coverage and simulator support.

The original run did **not** produce SDF. Any SDF newly exported from the
saved database is a derived audit artifact, labeled by date/corner, not
evidence that the original flow ran timing simulation. It does not replace
per-RC-corner extraction. The supplied TT-named Verilog models are functional
cell models; do not treat the name as an SS/FF timing characterization.

## Commands

The public download command below is for **after** the draft is published;
it is not currently available to unauthenticated repository visitors.

```bash
gh release download v4-reproduction-20260910 --repo stevenchen0830/vfir-7nm-rtl2gds --dir work/v4-assets
```

Or export from the preserved original workspace (do not run the exporter
over downloaded files expecting to manufacture a historical candidate):

```bash
python3 tools/export_v4_assets.py --orfs-root "$ORFS_ROOT" --repo "$PWD" --output work/v4-assets
cd work/v4-assets
sha256sum -c assets.sha256
gzip -dk 6_final.v.gz 6_final.sdc.gz 6_final.spef.gz 6_final.def.gz
```

Only extract the vendor archive into a clean, intended directory after
checking its paths. It preserves paths relative to ORFS; it is not a full
ASAP7 PDK distribution. Obtain the matching LEF/GDS/RC files from the pinned
upstream ORFS checkout when performing physical implementation.

```bash
python3 tools/run_sta_audit.py --orfs-root "$ORFS_ROOT" --result-dir /path/to/unpacked/v4 \
  --corner FF --u100 --output work/reproduced_ff.rpt --sdf work/v4_ff.sdf
```

The exact audit selects AO/OA/SIMPLE 211120, INVBUF 220122 and SEQ 220123
RVT Liberty files. A newer SIMPLE 250407 also exists in the platform and
must not accidentally replace or duplicate the historical 211120 library.
Warning 1212 comes from upstream timing-group declarations: retain it,
record the file hash and review affected arcs before any signoff claim.
These assets enable further inspection; LVS, EM, full MMMC and final LEC
are still not established by publishing files.

The release contains four original input archives, vendor views, a new FF SDF
archive, asset-manifest.json and assets.sha256 (about 277 MB compressed).
The fresh audit includes exact input, Liberty, script, tool-version and SDF
hashes in [its manifest](../reports/v4_reproduced_ff_u100.manifest.json).
