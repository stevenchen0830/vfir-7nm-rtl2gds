# Verification evidence index

Files without a `_v4` suffix are the independent 2026-08-30 audit of commit
`cc60e8a` and are retained as historical evidence.  Current v4 evidence is
identified explicitly below; the timing source files are in `reports/` and
are pinned by `reports/manifest_v4.sha256`.

| Evidence | Scope |
| --- | --- |
| `rtl_regression_v4.log` | Complete 54-frame self-checking RTL regression |
| `dynamic_verification_v4.md` | Directed, multiseed and coverage summary |
| `formal_control_bmc_v4.log` | 40-cycle control/PREP bounded model check |
| `cdc_rdc_structural_v4.md` | Single-clock/reset structural census |
| `equivalence_v4_report.md` | RTL-to-generic-synthesis EQY result and limits |
| `generic_gls_v4.log` | Zero-delay generic-synthesis public-interface smoke |
| `tool_environment_v4.md` | Host-specific Yosys/Verilator execution notes |

These artifacts are verification evidence, not silicon/tapeout signoff.
