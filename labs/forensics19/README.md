# forensics19 - Oracle Database 19c EE, CDB FX19 + FXPDB1

Throwaway 19c counterpart of the `forensics` lab for the delphi-oradba verification of the legacy security and
forensics capture (parse runs, detection and recipe tests on 19c). Core configuration as `base19` (Unified Audit
pure, archivelog via the 19c template), plus minimal supplemental logging (`02_supplemental_logging.sql`) and a
small tablespace `FX_DATA` (`18_create_ts_fx_data_fxpdb1.sql`).

**This lab may be destroyed, corrupted and rebuilt at any time.** Never point its tests at `base19` or `seclab`.

<!-- markdownlint-disable MD013 MD060 -->
| Item | Value |
| --- | --- |
| Image | `trivadis/ora_db:19.27.0.0` (`lab.env`, M2: `oradba-docker`) |
| Port | `127.0.0.1:1577` -> 1521 |
| Services | `fx19.oradba.ch`, `fxpdb1.oradba.ch` |
| First start | dbca, about 15 min; later starts about 1 min |
<!-- markdownlint-restore -->

```bash
make up LAB=forensics19
make connect LAB=forensics19
make rebuild LAB=forensics19        # after a test broke the database on purpose
make down LAB=forensics19 PURGE=1   # stop and remove the data
```

`trivadis/ora_db` predates the Oracle container contract; `compose.yml` maps it (data `/u01`, hooks via
`INSTANCE_INIT=/u01/config`). The hooks are the `base19` hooks with `FXPDB1` plus the two forensics hooks.
