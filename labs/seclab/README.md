# seclab - Default security lab, 19c EE + 26ai Free side by side

The default lab for Oracle Database security talks and trainings: the same starting point on
19c and 26ai, so a demo shows the difference between the releases in one go.

| Item | db19 | db26 |
| --- | --- | --- |
| Image (`lab.env`) | `trivadis/ora_db:19.27.0.0` | `oracle-free-labs:latest` (23.26.3) |
| CDB | `SECDB19` | `FREE` |
| PDBs | `LABPDB1`, `DEMOPDB` | `LABPDB1`, `DEMOPDB` |
| Port | `127.0.0.1:1562` | `127.0.0.1:1572` |
| Container | `seclab-db19` | `seclab-db26` |

Both databases:

- core configuration of `labdb` in `LABPDB1` (as base19 / base26)
- `DEMOPDB` with the sample schemas `SCOTT` and `TVD_HR` (schema-only, no login), audit
  tablespace, and the lab accounts `LAB_ADMIN` (DBA in the PDB, runs demo setup/reset) and
  `LAB_USER` (CREATE SESSION) - passwords in `lab.env`, generated at the first `make up`
- Unified Auditing pure mode; demos bring and remove their own policies (`AUDIT` always paired
  with `NOAUDIT`)
- ARCHIVELOG, guaranteed restore point `LAB_BASELINE`
- `demos/` of this repo mounted read-only at `/opt/oracle/demos`

```bash
make up LAB=seclab            # first start: dbca for 19c, about 15 min
make verify LAB=seclab        # checks + connect strings
make connect LAB=seclab DB=db26
make reset LAB=seclab         # FLASHBACK DATABASE to LAB_BASELINE, both DBs in parallel
make down LAB=seclab          # PURGE=1 also removes the data
```

Demos name this lab (`requires: seclab`) - see [../../demos/README.md](../../demos/README.md).
The intentionally insecure assessment baseline of oracle-free-labs (scenarios S01-S11) comes
later as an option (`PROFILE=insecure`, M3). Memory: both containers need about 6 GB.
