# Claim 2 - DBCA template missing

Claim in the draft: `FREE_Database.dbc` and the seed files are missing from `$ORACLE_HOME/assistants/dbca/templates`;
`runOracle.sh` on an empty data directory fails with `[DBT-10508] Invalid template file specified`.

- Date: 2026-11-25 (gate: listing), 2026-11-26 (runtime, arm64)
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

### Runtime output

t3 (`raw/rt-t3-23.26.4.0.txt`, `docker logs`, password prompt lines removed): listener configured, then

```text
Configuring Oracle AI Database FREE.
[FATAL] [DBT-10508] Invalid template file specified (/opt/oracle/product/26ai/dbhomeFree/assistants/dbca/templates/FREE_Database.dbc).
   CAUSE: The given template path is not a valid file path or the template file is not accessible in the local file system.
   ACTION: Verify the presence of the template file (/opt/oracle/product/26ai/dbhomeFree/assistants/dbca/templates/FREE_Database.dbc) and ensure it is accessible.

Database configuration failed. Check logs under '/opt/oracle/cfgtoollogs/dbca'.
```

Container state `exited`, exit code 1, 2 s after start; bind directory stays empty.

t4 (`raw/rt-t4-23.26.4.0.txt`, `docker logs` complete):

```text
Expanding prebuilt database files.
/opt/oracle/scripts/base/runOracle.sh.orig: line 435: source: /opt/oracle/: is a directory
Response file template  not found in /opt/oracle or /opt/oracle/scripts/base.
```

Exit code 1 after 21 s. The bind directory now holds the extracted `FREE` database (4.0 GB, `.FREE.created`,
`FREE/.prebuiltdb`), so a second start with the same directory and `ORACLE_SID=LABSID` takes the same path again.
Cause (code, `runOracle.sh.orig` lines 430-436 and `createDB.sh` lines 1029-1034): for any SID other than `FREE`,
`runOracle.sh` sources `${SCRIPT_BASE_DIR}/${RELINK_BINARY_FILE}` and `createDB.sh` needs
`${SCRIPT_BASE_DIR}/${CONFIG_RSP}`. Neither variable is set in the 23.26.4.0 image, so the first `source` hits the
directory (non-fatal) and `createDB.sh` stops before DBCA.

## Result

- Template and seed files missing: **confirmed** (listing)
- DBT-10508 when `runOracle.sh` is run on an empty directory: **confirmed** (t3)
- New, not in the draft: an `ORACLE_SID` other than `FREE` cannot start - **confirmed** (t4). Different cause from
  t3: `RELINK_BINARY_FILE` and `CONFIG_RSP` are not set in the image, `createDB.sh` stops before DBCA
