# v4 reproduction inputs — 2026-09-10

This release adds **evidence**, not a new timing-closed implementation.

- Original v4 final netlist, final SDC, routed SPEF and DEF, gzip-compressed;
  asset-manifest.json records raw and compressed SHA-256 hashes.
- Exact available ASAP7 RVT timing and functional cell views, preserving
  upstream BSD 3-Clause license/copyright headers. These files are not
  relicensed under the project's MIT license; no upstream endorsement implied.
- Newly derived FF SDF (2026-09-10), clearly separate from the original run,
  which did not generate SDF. This does not establish SDF simulation coverage.
- A fresh standalone OpenSTA audit reproduced +34.31 ps setup / +4.88 ps hold
  with the explicitly named FF 100/30 ps uncertainty sensitivity view.

Verify `assets.sha256` before extraction. The vendor archive is a partial
set of Liberty/functional models, not a complete PDK. The documented STA
launcher selects the pinned 211120 SIMPLE Liberty, not the additional 250407
version also present in the saved platform.

Remaining limits: 243 max-slew violations; SS hold failure in the archived
150/150 ps view; single-SPEF cross-corner audit; no full MMMC, final mapped
equivalence, LVS or EM signoff. No SRAM macros are integrated. This research
ASAP7 design is not tapeout-ready and no safe SS 500 MHz claim is made.

Full instructions: `docs/physical-assets.md` and `docs/rtl-to-gds-walkthrough.md`.
