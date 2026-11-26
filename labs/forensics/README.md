# forensics - Oracle AI Database 26ai Free, CDB FREE + FXPDB1

Throwaway lab for Oracle forensics and data-recovery recipes (delphi-oradba
`topics/forensics/recipes/`). Free 23.26.3 with OraDBA (23.26.4 cannot create a new
database), `FREEPDB1` dropped, PDB `FXPDB1` with the `base26` configuration, archivelog
mode, minimal supplemental logging and a small tablespace `FX_DATA` (one datafile) as the
object of single-datafile extraction recipes.

**This lab may be destroyed, corrupted and rebuilt at any time.** Recipes copy, truncate
and patch datafiles and redo logs of this lab on purpose. Never point a recipe at another
lab (`base19`, `base26`, `seclab`, `audit26`).

<!-- markdownlint-disable MD013 MD060 -->
| Item | Value |
| --- | --- |
| Image | `oracle-free-labs:latest` (Free 23.26.3 + OraDBA, `make build` in oracle-free-labs) |
| Port | `127.0.0.1:1576` -> 1521 |
| PDB | `FXPDB1` (SCOTT, TVD_HR, tablespaces `USERS`, `FX_DATA`) |
| Logging | `ARCHIVELOG`, minimal supplemental logging (`02_supplemental_logging.sql`) |
| First start | database creation on empty data, a few minutes |
<!-- markdownlint-restore -->

```bash
make up LAB=forensics
make connect LAB=forensics
make rebuild LAB=forensics     # after a recipe broke the database on purpose
make down LAB=forensics PURGE=1   # stop and remove the data (free disk space)
```

The recipes create their own test objects and evidence at runtime; the lab ships no
scenario data. Setup and startup hooks are the `base26` ones plus
`02_supplemental_logging.sql` and `18_create_ts_fx_data_fxpdb1.sql`.
