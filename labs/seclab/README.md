# seclab - Default security lab, 19c EE + 26ai Free side by side

The default lab for Oracle Database security talks and trainings: the same starting point on
19c and 26ai, so a demo shows the difference between the releases in one go.

| Item | db19 | db26 |
| --- | --- | --- |
| Image (`lab.env`) | `trivadis/ora_db:19.27.0.0` | `container-registry.oracle.com/database/free:latest` (23.26.3) |
| CDB | `SECDB19` | `FREE` |
| PDBs | `DEMOPDB` | `DEMOPDB`, `FREEPDB1` |
| Port | `127.0.0.1:1562` | `127.0.0.1:1572` |
| Container | `seclab-db19` | `seclab-db26` |

Both databases:

- Unified Auditing pure mode, default policies only - demos bring and remove their own
  (`AUDIT` always paired with `NOAUDIT`)
- ARCHIVELOG, guaranteed restore point `LAB_BASELINE` taken after the first start
- `DEMOPDB` with the sample schemas `SCOTT` and `TVD_HR` (schema-only, no login) and the lab
  accounts `LAB_ADMIN` (DBA in the PDB, runs demo setup/reset) and `LAB_USER` (CREATE SESSION)
- Passwords: `lab.env`, generated at the first `make up`
- Setup hooks (`setup/db19/`, `setup/db26/`) run once via `labctl.sh` after the first start

```bash
make up LAB=seclab            # first start: dbca for 19c, about 15-25 min
make verify LAB=seclab        # checks + connect strings
make connect LAB=seclab DB=db26
make reset LAB=seclab         # FLASHBACK DATABASE to LAB_BASELINE, both DBs in parallel
make down LAB=seclab          # PURGE=1 also removes the data volumes
```

Demos run on this lab and name it (`requires: seclab`) - see [../../demos/README.md](../../demos/README.md).
Demo-specific accounts such as `LOWPRIV_DEMO` come from the demo's own setup script, not from
the lab. Memory: both containers together need about 6 GB in the Docker VM.
