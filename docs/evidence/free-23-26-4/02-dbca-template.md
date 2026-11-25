# Claim 2 - DBCA template missing

Claim in the draft: `FREE_Database.dbc` and the seed files are missing from `$ORACLE_HOME/assistants/dbca/templates`;
`runOracle.sh` on an empty data directory fails with `[DBT-10508] Invalid template file specified`.

- Date: 2026-11-25 (gate: listing; flight: runtime)
- Images: see `01-size.md` (digests)

## Listing (gate)

Command: `docker run --rm --network none --entrypoint /bin/bash <image> -c 'ls -la $ORACLE_HOME/assistants/dbca/templates'`
(`raw/fs-probe-local.txt`, shortened):

```text
== 23.26.3.0
-rw-r----- 1 oracle oinstall      5849 Jul  8 21:02 FREE_Database.dbc
-rw-r----- 1 oracle oinstall  18792448 Jul  8 21:02 FREE_Seed_Database.ctl
-rw-r----- 1 oracle oinstall 277610496 Jul  8 21:02 FREE_Seed_Database.dfb1
... dfb2 - dfb7 (41.9 MB, 1.2 MB, 1.1 MB, 31.0 MB, 65.9 MB, 1.1 MB)
== 23.26.4.0
total 8
drwxr-xr-x 2 oracle oinstall 4096 Oct 19 13:22 .
drwxr-xr-x 2 oracle oinstall 4096 Oct 19 13:19 ..
```

The template is still referenced in 23.26.4.0: `/etc/init.d/oracle-free-26ai` sets `TEMPLATE_NAME=FREE_Database.dbc`
and calls `dbca -silent -createDatabase -templateName $TEMPLATE_NAME -characterSet $CHARSET ...`.
`createDB.sh` calls `/etc/init.d/oracle-free-26ai configure` for `ORACLE_SID=FREE` (lines 535-600). For any other
SID it copies a DBCA response template `${SCRIPT_BASE_DIR}/${CONFIG_RSP}` (line 1029); `CONFIG_RSP` is not set in
the 23.26.4.0 environment and no `dbca.rsp.tmpl` exists in the image, so that path stops before DBCA (code reading).

## When is `createDB.sh` reached in 23.26.4.0 (code reading)

`runOracle.sh` creates a database if `oradata/.<SID>.created` or `oradata/<SID>` is missing. `startPrebuilt.sh`
extracts the prebuilt database (SID `FREE`) into every empty `oradata`. `createDB.sh` therefore runs only:

- if `runOracle.sh` is started directly (compose `command:`), without `startPrebuilt.sh`
- with an `ORACLE_SID` other than `FREE` (the extracted DB has SID `FREE`, `.LABSID.created` is missing)
- with `TRUE_CACHE=true` (separate dbca path, not tested)

## Runtime (flight, `collect.sh`)

| Test | Setup | Expected (code reading) | Evidence |
| --- | --- | --- | --- |
| t3 | 23.26.4.0, empty bind dir, command `runOracle.sh` | DBT-10508, container stops | `raw/rt-t3-23.26.4.0.txt` |
| t4 | 23.26.4.0, empty bind dir, `ORACLE_SID=LABSID` | extraction, then create path fails (missing response template) | `raw/rt-t4-23.26.4.0.txt` |
| t1 | 23.26.3.0, empty bind dir (control) | DBCA from template, setup runs | `raw/rt-t1-23.26.3.0.txt` |

## Result

- Template and seed files missing: **confirmed** (listing)
- DBT-10508 when `runOracle.sh` is run on an empty directory: **open** until `raw/rt-t3-23.26.4.0.txt` is in
  (observed 2026-11-23 on seclab-db26, no log kept)
- New: a non-default `ORACLE_SID` probably cannot create a database either (other cause) - **open** (t4)
