# tde - TDE keystore with WALLET_ROOT

```yaml
requires: seclab
databases: db26
pdb: DEMOPDB
verified: no - LAB-CHECK open
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
  there; on 26ai it is gone (LAB-CHECK: desupported in 23ai), so an AI answer in the old syntax
  fails on the beamer instead of passing unnoticed
- The restart is the breaking point of this round; 26ai Free restarts faster than the 19c EE
  instance (LAB-CHECK: about 60-90 s)
- The reused oracle-free-labs TDE scripts were built and run on Oracle Free
- db19 stays untouched for round 1 - a restart that goes wrong in round 3 cannot break it

The scripts work on 19c the same way (setup.sql only warns); the old syntax would not fail there.

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
7. `ALTER TABLESPACE hmb_plain_ts ENCRYPTION ONLINE USING 'AES256' ENCRYPT FILE_NAME_CONVERT = (...)`
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
| Round 3, minute 1-2 | `SHUTDOWN IMMEDIATE` / `STARTUP` in `seclab-db26` only | 60-90 s (LAB-CHECK) - co-host talks |
| After the session | `reset.sql` (second restart), then `make reset LAB=seclab` | 3-5 min, not during the talk |

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

## Run

```bash
# from the repo root, lab running (make up LAB=seclab)
docker cp demos/tde/. seclab-db26:/tmp/hmb-tde
docker exec -it -w /tmp/hmb-tde seclab-db26 bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" / as sysdba'
```

```sql
@setup.sql
@check.sql
@solution.sql
@check.sql
@reset.sql
```

Then, outside SQL*Plus: `make reset LAB=seclab`.

## Reset

Order: `@reset.sql` first, then `make reset LAB=seclab`. reset.sql drops `HMB_TDE` and every
`HMB_*` tablespace with its datafiles (keystore still open), resets `TDE_CONFIGURATION` and
`WALLET_ROOT` in the spfile (old value printed), shuts down, removes the wallet directory (only if
the path ends in `/wallet`, otherwise it prints what to remove) and starts again. The flashback
afterwards removes the remaining key metadata from the database.

`make reset LAB=seclab` (flashback) does **not** revert:

- spfile parameters `WALLET_ROOT` and `TDE_CONFIGURATION` - the spfile is not part of the
  flashback; after a flashback alone the instance still points at the old keystore
- the keystore files under `WALLET_ROOT` (`ewallet.p12`, `cwallet.sso`, the `WITH BACKUP` copy) -
  files on a persistent mount, they survive `make down` / `make up` too
- datafiles created after `LAB_BASELINE` are left as orphans on disk - hence the `DROP TABLESPACE
  ... INCLUDING CONTENTS AND DATAFILES` before the flashback
- `/tmp/hmb-tde` in the container

No audit policy is created; `ADMINISTER KEY MANAGEMENT` is audited mandatorily and those records
are reverted by the flashback.

## LAB-CHECK

- `WALLET_ROOT` default `<diagnostic_dest>/dbconfig/FREE/wallet` (= `/opt/oracle/dbconfig/FREE/wallet`)
  lies on a persistent mount of `seclab-db26`
- `ENCRYPTION_WALLET_LOCATION` in sqlnet.ora is desupported (rejected / ignored) on 23.26.3
- `SHUTDOWN` / `STARTUP` inside the Free container keeps the container up; duration
- `CREATE LOCAL AUTO_LOGIN KEYSTORE FROM KEYSTORE` without a path, and online conversion with
  `FILE_NAME_CONVERT` on 23.26.3 Free
- CDB and PDBs open without keystore after reset.sql although master keys were set; a second full
  rehearsal (setup, solution, reset, make reset) runs clean - no ORA-28374 / ORA-46630
- `grep -a` present in the image
