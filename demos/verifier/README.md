# verifier - Find and clean up 10G password verifiers

```yaml
requires: seclab
databases: db19          # db26 only as read-only contrast (check.sql) or probe, see below
pdb: DEMOPDB
verified: yes (2026-11-13, 19.27 / 23.26.3)
```

hold-my-beer round 1 (warm-up), DOAG AK 2026. Pool entry: `10G-Passwort-Verifier finden und
bereinigen` / "Find and clean up 10G password verifiers" (owner Stefan, Security, easy, low risk).

## Task as the audience sees it

> Some accounts in DEMOPDB still carry 10G password verifiers (DES-based, case-insensitive,
> crackable in minutes). Find them, find out who would be locked out, clean them up and make
> sure the database does not create new ones. You have 5 minutes.

AI pitfalls named in the pool: wrong columns, imprecise `PASSWORD_VERSIONS` handling.

## Starting point (`setup.sql`)

`setup.sql` weakens the lab on purpose - that is the exercise:

| Account | Verifiers | Story |
| --- | --- | --- |
| `HMB_MODERN` | `11G 12C` | created with the 19c default (`ALLOWED_LOGON_VERSION_SERVER` 12) |
| `HMB_APP_OLD` | `10G 11G 12C` | created while the server allowed 11 |
| `HMB_LEGACY` | `10G` | carried over since 10g, no newer verifier |

and leaves `SQLNET.ALLOWED_LOGON_VERSION_SERVER = 11` in the server `sqlnet.ora` (old app server
setting). The helper `sqlnet_alv.sh` saves the file first; every change prints old and new value.

## Expected solution (`solution.sql`)

1. Find: `CDB_USERS` / `DBA_USERS` with `PASSWORD_VERSIONS LIKE '%10G%'` (a list, not a value).
2. Pre-check before raising the parameter: `HMB_LEGACY` has no 12C verifier and would be locked
   out; `HMB_APP_OLD` and `HMB_MODERN` keep working (based on `precheck_logon_version.sql`).
3. Raise `SQLNET.ALLOWED_LOGON_VERSION_SERVER` to `12a` (minimum answer: `12`) and reconnect -
   a password reset under 11 would just create a new 10G verifier.
4. Accounts with a 12C verifier: drop the old verifiers without knowing the password
   (`IDENTIFIED BY VALUES` with only the `T:` part of `SYS.USER$.SPARE4`). Alternative: expire
   the password so the owner sets a new one.
5. 10G-only account: new password (real life: plus `PASSWORD EXPIRE`, hand-over to the owner).
6. Verify with `check.sql`: no `10G`, `SYS.USER$.PASSWORD` empty, logins as expected.

DBA-instinct points: the order (parameter, reconnect, reset), the lock-out pre-check, the fact
that 10G was case-insensitive (apps that send the password in upper case break after the
switch), and old clients without `O5L_NP` that `12a` locks out.

## Timing

| Step | Target |
| --- | --- |
| Find + pre-check | 1.5 min |
| sqlnet.ora + reconnect | 1 min |
| Strip / reset | 1.5 min |
| `check.sql` on the beamer | 1 min |

5 minutes hard. Before the session: `setup.sql` and one `check.sql` run (about 1 min).

Measured 2026-11-13 on 19.27 (three runs): `setup.sql` 1 s, `solution.sql` 1 s,
`check.sql` 1-2 s, `reset.sql` 1 s - the 5 minutes are thinking time, not run time.

## Run

The repo's `demos/` is mounted read-only in both containers at `/opt/oracle/demos`. Start
SQL*Plus in the demo directory, so `HOST bash ./sqlnet_alv.sh` runs there (the helper edits the
server `sqlnet.ora` inside the container; its backup lives next to that file, not in the mount):

```bash
# lab running (make up LAB=seclab)
docker exec -it -w /opt/oracle/demos/verifier seclab-db19 bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" / as sysdba'
```

```sql
@setup.sql
@check.sql
@solution.sql
@check.sql
@reset.sql
```

Passwords: `&1` of `setup.sql` / `solution.sql` / `check.sql`, defaults `HmbDemo_Lab_Only_19`
and `HmbDemo_New_Lab_Only_19` - lab-only demo values, letters, digits and underscore only.

## Reset

`@reset.sql` drops the `HMB_*` accounts and restores `sqlnet.ora` from the saved copy (or
removes it if it did not exist before). Run it after every rehearsal and after the session.
Verified 2026-11-13: after `reset.sql` the `sqlnet.ora` is byte-identical to the baseline on
both databases. `setup.sql` is rerunnable without a reset in between (it sets `12` and reconnects
before it creates `HMB_MODERN`).

`make reset LAB=seclab` (flashback to `LAB_BASELINE`) does **not** revert:

- `sqlnet.ora` (`SQLNET.ALLOWED_LOGON_VERSION_SERVER`) - a file, not database content.
  After a flashback alone the lab keeps `11` (after setup) or `12a` (after solution), and
  `sqlnet.ora.hmb-verifier.bak` stays next to it; `reset.sql` handles both

## db26 (26ai Free)

26ai does not create 10G verifiers at all, so the exercise cannot be shown there.
`check.sql` sections 1-2 run on db26 as read-only contrast. To answer the question once in a
rehearsal, run `setup.sql` on `seclab-db26`: it ends with a `RESULT:` line saying whether a 10G
verifier was generated, then run `reset.sql`.
Verified 2026-11-13 on 23.26.3: `ALLOWED_LOGON_VERSION_SERVER=11` is accepted without error
or warning, `CREATE USER` still generates `11G 12C` only (`RESULT: ... generated NO 10G
verifier`), so the `IDENTIFIED BY VALUES` step is skipped and all three accounts log in.

## Verified (2026-11-13, 19.27 / 23.26.3)

- 19.27 generates `10G 11G 12C` with `ALLOWED_LOGON_VERSION_SERVER=11` in a reconnected
  bequeath session
- `IDENTIFIED BY VALUES '<16 hex>'` leaves a 10G-only account; `IDENTIFIED BY VALUES 'T:...'`
  leaves a 12C-only account with an unchanged password (listener login with the old password OK)
- `sqlnet.ora`: `TNS_ADMIN` is unset in `docker exec`, so the helper edits
  `$ORACLE_HOME/network/admin/sqlnet.ora`. On db19 that is a symlink into the directory that
  listener and instance have as `TNS_ADMIN`, on db26 a symlink into `dbconfig/FREE` (no
  `TNS_ADMIN`) - bequeath and listener-spawned processes read the same file. `awk` and
  `mktemp` are in both images
- EZConnect needs the service with `db_domain`: `localhost:1521/DEMOPDB` gives ORA-12514,
  `check.sql` derives `demopdb.oradba.ch` from `db_domain`. A 10G-only account under `12a` gets
  ORA-01017 (not ORA-28040) - indistinguishable from a wrong password, which is the trap
- `DBMS_OUTPUT` is per container: the scripts re-enable `SERVEROUTPUT` after every
  `ALTER SESSION SET CONTAINER`, otherwise the pre-check prints nothing
- `solution.sql` strips legacy verifiers of `HMB_*` accounts only; unfiltered it also strips the
  `11G` verifier of `LAB_ADMIN`, `LAB_USER` and `PDBADMIN`, which `reset.sql` cannot restore
