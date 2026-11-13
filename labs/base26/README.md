# base26 - Oracle AI Database 26ai Free, CDB FREE + FREEPDB1

Plain 26ai Free base lab: CDB `FREE` with `FREEPDB1`, Unified Auditing pure (default in 26ai),
ARCHIVELOG (`ENABLE_ARCHIVELOG=true`), restore point `LAB_BASELINE` for `make reset`.

| Item | Value |
| --- | --- |
| Image | `container-registry.oracle.com/database/free:latest` (23.26.3), local alternative `oracle-free-labs:latest` - variable in `lab.env` |
| Port | `127.0.0.1:1571` -> 1521 |
| Services | `free`, `freepdb1` (no `db_domain`) |
| First start | about 3-5 min |

```bash
make up LAB=base26
make connect LAB=base26
make reset LAB=base26
make down LAB=base26          # PURGE=1 also removes the data volume
```

Init hooks: `setup/db26/` runs once, by `labctl.sh` after the first start (the Free image starts
a prebuilt database and would skip it; marker `.oradba-labs.setup` in the data volume).
`startup/db26/` runs at every start (image mechanism `/opt/oracle/scripts/startup`).
