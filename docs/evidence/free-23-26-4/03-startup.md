# Claim 3 - Startup behaviour, setup and startup scripts

Claim in the draft: the default command is now `startPrebuilt.sh`. It extracts `prebuilt-oradata.tar.gz` into an
empty `/opt/oracle/oradata`, including a mounted host directory. `runOracle.sh` then takes the existing-database
path, so `/opt/oracle/scripts/setup` never runs.

- Date: 2026-11-25 (gate: config + scripts), 2026-11-26 (runtime, arm64)
- Images: see `01-size.md` (digests)

## Image config (gate)

Command: `docker image inspect <image> | jq '.[0].Config'` (`raw/fs-probe-local.txt`, `raw/manifest-*.json`)

| | 23.26.3.0 | 23.26.4.0 |
| --- | --- | --- |
| Created | 2026-07-08 | 2026-10-19 |
| Base | Oracle Linux 8.10 | Oracle Linux 9.8 (`oraclelinux:9`) |
| `sqlplus -v` | 23.26.3.0.0 | 23.26.4.0.0 |
| Cmd | `/bin/bash -c $SCRIPT_BASE_DIR/$RUN_FILE` | `/bin/bash -c exec $ORACLE_BASE/startPrebuilt.sh` |
| Entrypoint | none | none |
| Healthcheck start period | 5 min | 1 min |
| Prebuilt DB | unpacked in `/opt/oracle/oradata`, created at build time (`runOracle.sh --nowait`, 4.23 GB layer) | `prebuilt-oradata.tar.gz` (470 MiB), `oradata` empty |
| `README.md`, `Dockerfile` in `/opt/oracle` | present | missing |
| New env | - | `MANAGE_PDB`, `DBCA_UTILS_SCRIPT`; `ORACLE_PDB` removed |

## Scripts (gate)

Extracted with `docker create` + `docker cp`; diffs in `raw/diff-*.txt`, new scripts as `raw/*-23.26.4.0.txt`.

- `startPrebuilt.sh` (new, header "Since: September, 2026"): if `oradata` is empty (or an extraction marker is
  left over) and `TRUE_CACHE` is not `true`, extract `prebuilt-oradata.tar.gz` into `$ORACLE_BASE`, then
  `exec runOracle.sh`. A mounted empty host directory counts as empty
- `runOracle.sh` (diff 80 lines):
  - existing-DB path: new call to `configurePrebuiltPdb.sh "$ORACLE_CHARACTERSET"` if `.prebuiltdb` exists and SID
    is `FREE` (see claim 4)
  - `ORACLE_CHARACTERSET` defaults to `AL32UTF8` only on the create path now
  - setup scripts: unchanged, run only after `createDB.sh` (create path)
  - startup scripts: now `runUserScripts.sh ... || exit $?` - "Failed startup scripts must fail container startup
    and image creation"
  - TCPS configuration runs on every start (was: create path only)
- `runUserScripts.sh`: now returns the first non-zero exit code of a `.sh`/`.sql` script (was: always 0)
- `createDB.sh`: 560 -> 1104 lines (TDE, standby, RMAN duplicate); DB creation still via
  `/etc/init.d/oracle-free-26ai configure` and the missing template

## Runtime (flight, `collect.sh`)

| Test | Setup | Expected (code reading) | Evidence |
| --- | --- | --- | --- |
| t1 | empty bind dir + marker scripts in `setup/` and `startup/` | 23.26.3: DBCA, setup + startup run. 23.26.4: extraction, only startup runs | `raw/rt-t1-*.txt` |
| t5 | no bind mount + marker scripts | both: prebuilt DB, only startup runs (documented) | `raw/rt-t5-*.txt` |
| t6 | no bind mount + failing startup SQL | 23.26.3: container keeps running. 23.26.4: container exits | `raw/rt-t6-*.txt` |

### Runtime results

Marker scripts write `MARKER-SETUP` / `MARKER-STARTUP` into `/opt/oracle/oradata` and print a line to the log.

<!-- markdownlint-disable MD013 MD060 -->
| Test | Image | Ready after | Setup marker | Startup marker | Container | Note |
| --- | --- | --- | --- | --- | --- | --- |
| t1 | 23.26.3.0 | 112 s | present | present | running | DBCA from template |
| t1 | 23.26.4.0 | 31 s | absent | present | running | "Expanding prebuilt database files.", `FREE/.prebuiltdb` in the bind dir |
| t5 | 23.26.3.0 | 10 s | absent | present | running | prebuilt DB, no bind mount |
| t5 | 23.26.4.0 | 21 s | absent | present | running | prebuilt DB extracted at start |
| t6 | 23.26.3.0 | 71 s | - | - | running, exit 0 | ORA-00942 in `01_fail.sql`, logged, start continues |
| t6 | 23.26.4.0 | 81 s | - | - | exited, exit 1 | same ORA-00942, container stops 18 s after start |
<!-- markdownlint-restore -->

t6 on 23.26.4.0 (`raw/rt-t6-23.26.4.0.txt`, end of `docker logs`): the log shows `DATABASE IS READY TO USE!`, the
failing script and `DONE: Executing user defined scripts`, then the container exits with code 1. Nothing in the
log says why the container stopped.

## Result

- Default command `startPrebuilt.sh`, extraction into an empty (also mounted) directory: **confirmed** (config,
  script and t1)
- Setup scripts never run on 23.26.4.0 with the default command: **confirmed** (t1). The documented prebuilt path
  (t5) behaves the same in both images
- `README.md` / `Dockerfile` missing: **confirmed**
- New, not in the draft: a failing startup script stops the container in 23.26.4.0 - **confirmed** (t6). This
  matters for the labs if setup moves to startup hooks: every hook must end with exit 0, also on a restart
