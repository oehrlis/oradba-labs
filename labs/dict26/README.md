# dict26 - single-use dictionary lab, 26ai Free, CDB FREE + FREEPDB1

Throwaway lab for the dictionary snapshot of the `aitk oracle-check` tool (ai-toolkit): it exists only for the
duration of one run. `make snapshot LAB=dict26` starts it, exports the dictionary of `CDB$ROOT` and `FREEPDB1`,
runs a parse smoke test, purges the lab and checks that nothing is left. No lab users, no baseline, no reset.

| Item | Value (measured 2026-11-25) |
| --- | --- |
| Image | `container-registry.oracle.com/database/free:23.26.3.0` (13.1 GB), pinned by tag - not `oracle-free-labs` |
| Version / RU | 23.26.3.0.0 (no RU row in `DBA_REGISTRY_SQLPATCH`) |
| Current? | **behind** target 23.26.4 - the Free 23.26.4 image has a container issue (no dbca template, setup does not run) |
| CDB / PDB | `FREE` / `FREEPDB1`, `NOARCHIVELOG` (setup hook) |
| Port | `127.0.0.1:1575` -> 1521 |
| RAM | 2.2 GB of `mem_limit` 3 GB |
| Data dir peak | 4.0 GB, 0 after the run |
| Run time | up 113 s, snapshot 20 s, down 1 s - about 2:15 in total |
| Snapshot | `dict26-<version>.json` (root) and `dict26_pdb-<version>.json` (PDB), about 5.1 MB each, plus `lab-meta.json` |

```bash
make snapshot LAB=dict26 OUT=$TMPDIR/oradba-labs-snapshots/dict26
# with the ai-toolkit export instead of the built-in one:
ORACLE_CHECK_EXPORT="aitk oracle-check-export --alias dict26" make snapshot LAB=dict26 OUT=...
```

Cleanup checks at the end of every run (also after a failure, EXIT trap): data directory gone, no container by
compose label or name, no volume, no network, `lab.env` removed, nothing named `dict26*` below `LAB_DATA_BASE`.
Target levels: [`common/config/target-levels.env`](../../common/config/target-levels.env); `lab-meta.json` carries
`behind_current` and the reason. Host: Mac today (lid open, on power); apollon later.
