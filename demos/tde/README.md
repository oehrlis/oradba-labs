# tde - TDE keystore with WALLET_ROOT

```yaml
requires: seclab
databases: db26
pdb: DEMOPDB
verified: yes (2026-11-13, 23.26.3 - db26 only, not run on 19.27)
```

hold-my-beer round 3 (breaking point), DOAG AK 2026. Pool entry: `TDE-Keystore mit WALLET_ROOT` /
"TDE keystore with WALLET_ROOT" (owner Stefan, Security, medium, medium risk).

## Task as the audience sees it

> DEMOPDB stores card numbers in clear text - you can read them in the datafile with `grep`.
> Set up a TDE software keystore the current way (WALLET_ROOT, no sqlnet.ora), create the master
> keys and encrypt the tablespace. The data must stay readable for the application, the file must
> not. You have 5 minutes.

AI pitfall named in the pool: the old `sqlnet.ora` `ENCRYPTION_WALLET_LOCATION` syntax.

## Why db26

- The pitfall becomes visible: `ENCRYPTION_WALLET_LOCATION` is deprecated in 19c and still works
  there; on 26ai it is gone: with `ENCRYPTION_WALLET_LOCATION` in `sqlnet.ora` and no
  `WALLET_ROOT`, `V$ENCRYPTION_WALLET` fails with ORA-46693 (verified on 23.26.3), so an AI
  answer in the old syntax fails on the beamer instead of passing unnoticed
- The restart is the breaking point of this round; 26ai Free restarts fast (verified: about
  5 s for `SHUTDOWN IMMEDIATE` + `STARTUP` in `seclab-db26`)
- The reused oracle-free-labs TDE scripts were built and run on Oracle Free
- db19 stays untouched for round 1 - a restart that goes wrong in round 3 cannot break it

The scripts are written to work on 19c the same way (setup.sql only warns; not run on db19 -
round 1 keeps it untouched); the old syntax would not fail there.

## Starting point (`setup.sql`)

No `WALLET_ROOT`, no keystore. Tablespace `HMB_PLAIN_TS` (unencrypted) with
`HMB_TDE.CUSTOMER_CARDS`: 2000 rows, marker `HMB-TDE-CANARY` and test card numbers (4111...).
`grep -a -c HMB-TDE-CANARY` on the datafile counts > 0. setup.sql refuses to run if `WALLET_ROOT`
is set, the wallet directory exists or `HMB_PLAIN_TS` exists.

## Expected solution (`solution.sql`)

1. `mkdir -p <WALLET_ROOT>/tde`, `ALTER SYSTEM SET wallet_root = ... SCOPE = SPFILE`
2. **Restart** (`SHUTDOWN IMMEDIATE`, `STARTUP`, open the PDBs) - `WALLET_ROOT` is static
3. `ALTER SYSTEM SET tde_configuration = 'KEYSTORE_CONFIGURATION=FILE' SCOPE = BOTH` - dynamic,
   but only accepted once `WALLET_ROOT` is active, so it comes after the restart
4. `ADMINISTER KEY MANAGEMENT CREATE KEYSTORE` (no path - WALLET_ROOT/tde), `SET KEYSTORE OPEN
   ... CONTAINER = ALL`
5. `SET KEY ... WITH BACKUP ... CONTAINER = ALL` - united mode, keys for root and every PDB
6. `CREATE LOCAL AUTO_LOGIN KEYSTORE FROM KEYSTORE` - lab only; production: password keystore
   with external store or OKV/HSM
7. `ALTER TABLESPACE hmb_plain_ts ENCRYPTION ONLINE USING 'AES256' ENCRYPT` - `DEMOPDB` uses OMF,
   `FILE_NAME_CONVERT` is rejected there (ORA-28437); the script adds it only without OMF
8. `check.sql`: parameters set (memory = spfile), keystore `OPEN`, `ENCRYPTED = YES`, scan 0,
   rows still readable

Keystore password: `ACCEPT ... HIDE` at the start of solution.sql (lab-only value, typed live,
8+ characters). It is never in a script.

DBA-instinct points: the restart is planned, not discovered; keys need `CONTAINER = ALL` in united
mode; `WITH BACKUP`; clear text from before the encryption stays in archived redo and flashback
logs - encryption is not a wipe.

## Restart plan

| When | What | Who / how long |
| --- | --- | --- |
| Before the session | `setup.sql`, one `check.sql` (before picture) | 2 min |
| Round 3, minute 1 | `WALLET_ROOT` SCOPE=SPFILE, announce the restart | speaker |
| Round 3, minute 1-2 | `SHUTDOWN IMMEDIATE` / `STARTUP` in `seclab-db26` only | about 5 s (measured) - co-host talks |
| After the session | `reset.sql` (second restart), optionally `make reset LAB=seclab` | 6-7 s plus the flashback, not during the talk |

The restart ends every session on `seclab-db26`, nothing on `seclab-db19`. If `STARTUP` fails:
`docker exec -it seclab-db26 bash`, check the alert log, `STARTUP` again - a wrong `WALLET_ROOT`
path does not stop the instance from starting, a missing keystore only shows as `NOT_AVAILABLE`.
Fallback for the round: show `check.sql` and the solution steps without the restart.

## Timing

| Step | Target |
| --- | --- |
| WALLET_ROOT + restart | 2 min |
| TDE_CONFIGURATION, keystore, keys, auto-login | 1.5 min |
| Online encryption | 0.5 min |
| `check.sql` on the beamer | 1 min |

5 minutes hard - tight. If the voting picks TDE, pre-stage nothing: the restart is the point.

Measured 2026-11-13 on 23.26.3 (three runs): `setup.sql` 0-3 s, `check.sql` under 1 s,
`solution.sql` 8-11 s including the restart (after the password prompt), `reset.sql` 5.5-7 s
including the restart.

## Run

The repo's `demos/` is mounted read-only in both containers at `/opt/oracle/demos`. Run it with
`-it`: the `ACCEPT ... HIDE` password prompt of `solution.sql` needs a terminal - with stdin
piped it reads an empty password and `CREATE KEYSTORE` fails with ORA-01741 after the restart.

```bash
# lab running (make up LAB=seclab)
docker exec -it -w /opt/oracle/demos/tde seclab-db26 bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" / as sysdba'
```

```sql
@setup.sql
@check.sql
@solution.sql
@check.sql
@reset.sql
```

`setup.sql` can follow `reset.sql` directly for the next rehearsal - no `make reset` needed.

## Reset

`@reset.sql` drops `HMB_TDE` and every `HMB_*` tablespace with its datafiles (keystore still
open), resets `TDE_CONFIGURATION` and `WALLET_ROOT` in the spfile (old value printed), shuts down,
removes the wallet directory (only if the path ends in `/wallet`, otherwise it prints what to
remove; an empty parent directory goes too) and starts again. The database opens without a
keystore, `LAB_BASELINE` stays.

Two lab-only workarounds, both `SCOPE = MEMORY`, both printed when used:

- the lab's guaranteed restore point `LAB_BASELINE` blocks `DROP TABLESPACE` (ORA-38881).
  `reset.sql` sets `_allow_drop_ts_with_grp` for the drop only, and only if every `HMB_*`
  datafile was created after the newest guaranteed restore point - a flashback to it never needs
  the dropped file. Otherwise it skips the drop with a WARN
- after `reset.sql` the database still references the deleted master keys
  (`V$DATABASE_KEY_INFO`). The next `SET KEY` fails with ORA-46665 for the PDBs; `solution.sql`
  detects that case and sets `_db_discard_lost_masterkey` for that one statement (`LAB:` lines)

`make reset LAB=seclab` (flashback) does **not** revert:

- possibly the activation of the master key in the control file - open, check after a reset:
  `SELECT con_id, masterkey_activated FROM v$database_key_info` must show `NO` for every container,
  as on a freshly built lab. Note: `MASTERKEYID` is non-zero on every fresh database too (the internal
  per-container database key exists without TDE) - it is not an indicator. `solution.sql` handles lost
  master keys; for a database that has never seen a keystore use `make rebuild LAB=seclab`
- spfile parameters `WALLET_ROOT` and `TDE_CONFIGURATION` - the spfile is not part of the
  flashback; after a flashback alone the instance still points at the old keystore
- the keystore files under `WALLET_ROOT` (`ewallet.p12`, `cwallet.sso`, the `WITH BACKUP` copy) -
  files on a persistent mount, they survive `make down` / `make up` too
- datafiles created after `LAB_BASELINE` are left as orphans on disk - hence the `DROP TABLESPACE
  ... INCLUDING CONTENTS AND DATAFILES` in `reset.sql`

Whether the flashback also removes the master key references was not tested (the lab lifecycle
is owned elsewhere); `solution.sql` works either way.

No audit policy is created; `ADMINISTER KEY MANAGEMENT` is audited mandatorily and those records
stay in the trail.

## Verified (2026-11-13, 23.26.3)

- `WALLET_ROOT` = `<diagnostic_dest>/dbconfig/FREE/wallet` (= `/opt/oracle/dbconfig/FREE/wallet`)
  lies on a persistent bind mount of `seclab-db26`
- `ENCRYPTION_WALLET_LOCATION` in `sqlnet.ora` without `WALLET_ROOT`: ORA-46693 on
  `V$ENCRYPTION_WALLET` (tested with a temporary entry, `sqlnet.ora` restored byte-identical)
- `SHUTDOWN` / `STARTUP` inside the Free container keeps the container up, about 5 s
- `CREATE LOCAL AUTO_LOGIN KEYSTORE FROM KEYSTORE` without a path writes `cwallet.sso` into
  `WALLET_ROOT/tde`; online conversion works, but without `FILE_NAME_CONVERT` (OMF, ORA-28437);
  the old clear-text datafile is removed, the scan of the new one finds 0 markers
- CDB and PDBs open without keystore after `reset.sql` although master keys were set; two full
  rehearsals in a row without `make reset` ran clean with the two workarounds above (plus
  two runs aborted while fixing the scripts, cleaned up by the same `reset.sql`)
- `DBMS_OUTPUT` is per container and lost after `STARTUP`: the scripts re-enable `SERVEROUTPUT`
- `grep -a` (GNU grep 3.1) is in the image
- not run on db19 (19.27): the task says db26 only, round 1 keeps db19 untouched
