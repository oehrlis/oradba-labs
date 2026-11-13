# base19 - Oracle Database 19c EE, CDB + 1 PDB, Unified Audit pure

Plain 19c base lab: one CDB (`CDB19`) with one PDB (`PDB1`), Unified Auditing in pure mode
(relinked `uniaud_on` at setup), ARCHIVELOG, restore point `LAB_BASELINE` for `make reset`.

| Item | Value |
| --- | --- |
| Image | `trivadis/ora_db:19.27.0.0` (variable in `lab.env`, M2: `oradba-docker`) |
| Port | `127.0.0.1:1561` -> 1521 |
| Services | `cdb19`, `pdb1` (see `make verify LAB=base19`) |
| First start | dbca, about 15-25 min; later starts about 1 min |

```bash
make up LAB=base19
make connect LAB=base19
make reset LAB=base19
make down LAB=base19          # PURGE=1 also removes the data volume
```

Init hooks: `setup/db19/` runs once, by `labctl.sh` after the first start - a failing hook stops
`make up`. `startup/db19/` runs at every start (image mechanism `INSTANCE_INIT`). The hooks only
call `common/scripts/` and `common/sql/`.
