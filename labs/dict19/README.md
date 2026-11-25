# dict19 - single-use dictionary lab, 19c EE, CDB CDB19 + PDB1

Throwaway lab for the 19c dictionary snapshot of `aitk oracle-check` (ai-toolkit), same lifecycle as
[`dict26`](../dict26/README.md): `make snapshot LAB=dict19` - up, export of `CDB$ROOT` and `PDB1`, parse smoke
test, purge, cleanup checks.

| Item | Value (measured 2026-11-25) |
| --- | --- |
| Image | `trivadis/ora_db:19.27.0.0` (9.05 GB) until the oradba-docker 19c EE image exists (M2) |
| Version / RU | 19.27.0.0.0, Database Release Update 19.27.0.0.250415 |
| Current? | **behind** target 19.33 + CSPU 2026-11 (newest patch build 2025-04-15) - waiting on oradba-docker |
| CDB / PDB | `CDB19` / `PDB1` (created by `setup/db19/10_create_pdb_pdb1.sql`; the image creates only the CDB), `NOARCHIVELOG` |
| Port | `127.0.0.1:1563` -> 1521 |
| RAM | 1.4 GB of `mem_limit` 3 GB |
| Data dir peak | 4.9 GB, 0 after the run |
| Run time | about 14 min in total: up and health check 103 s, then the hook waits about 11 min for dbca and the PDB hook, export and parse check under a minute, purge 4 s |
| Snapshot | `dict19-<version>.json` and `dict19_pdb-<version>.json`, about 4.3 MB each, plus `lab-meta.json` |

The container reports healthy and the instance is `READ WRITE` while dbca is still running; the setup hook
creates `PDB1` only at the end. The snapshot hook therefore waits for an open PDB (`SNAPSHOT_PDB_WAIT`, default
2400 s) instead of trusting the health check. Three failed runs on 2026-11-25 (missing environment, no PDB, too
early) all purged cleanly - every cleanup check PASS - which is the proof that a failure leaves no data behind.

```bash
make snapshot LAB=dict19 OUT=$TMPDIR/oradba-labs-snapshots/dict19
```
