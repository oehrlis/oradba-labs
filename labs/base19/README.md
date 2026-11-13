# base19 - Oracle Database 19c EE, CDB + LABPDB1, Unified Audit pure

Plain 19c base lab: CDB `CDB19` with the standard PDB `LABPDB1` and the core configuration of
oracle-free-labs `labdb` (`db_domain`, profiles, audit tablespace and policies, `USERS`).

| Item | Value |
| --- | --- |
| Image | `trivadis/ora_db:19.27.0.0` (`lab.env`, M2: `oradba-docker`) |
| Port | `127.0.0.1:1561` -> 1521 |
| Services | `cdb19.oradba.ch`, `labpdb1.oradba.ch` |
| First start | dbca, about 15 min; later starts about 1 min |

```bash
make up LAB=base19
make connect LAB=base19
make reset LAB=base19
make down LAB=base19          # PURGE=1 also removes the data
```

`trivadis/ora_db` predates the Oracle container contract; `compose.yml` maps it (data `/u01`,
hooks via `INSTANCE_INIT=/u01/config`). `setup/db19/` runs once after dbca, `startup/db19/` at
every start - both by the image. The hooks are the `labdb` hooks without the Free-only ones.
