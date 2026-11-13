# verifier - Find and clean up 10G password verifiers

```yaml
requires: seclab
databases: db19          # db26 only as read-only contrast (check.sql) or probe, see below
pdb: DEMOPDB
verified: no - LAB-CHECK open
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

## Run

The demo directory is copied into the container, so `HOST` calls and `sqlnet_alv.sh` run there
(the helper edits the server `sqlnet.ora` inside the container):

```bash
# from the repo root, lab running (make up LAB=seclab)
docker cp demos/verifier/. seclab-db19:/tmp/hmb-verifier
docker exec -it -w /tmp/hmb-verifier seclab-db19 bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" / as sysdba'
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

`make reset LAB=seclab` (flashback to `LAB_BASELINE`) does **not** revert:

- `sqlnet.ora` (`SQLNET.ALLOWED_LOGON_VERSION_SERVER`) - a file, not database content.
  After a flashback alone the lab keeps `11` (after setup) or `12a` (after solution), and
  `sqlnet.ora.hmb-verifier.bak` stays next to it; `reset.sql` handles both
- `/tmp/hmb-verifier` in the container - remove with `docker exec seclab-db19 rm -rf /tmp/hmb-verifier`

## db26 (26ai Free)

Expected: 26ai does not create 10G verifiers at all, so the exercise cannot be shown there.
`check.sql` sections 1-2 run on db26 as read-only contrast. To answer the question once in a
rehearsal, run `setup.sql` on `seclab-db26`: it ends with a `RESULT:` line saying whether a 10G
verifier was generated, then run `reset.sql`.
LAB-CHECK: 26ai behaviour with `ALLOWED_LOGON_VERSION_SERVER=11` (ignored, error, or 10G).

## LAB-CHECK

- 19.27 generates `10G 11G 12C` with `ALLOWED_LOGON_VERSION_SERVER=11` in a reconnected
  bequeath session
- `IDENTIFIED BY VALUES '<16 hex>'` leaves a 10G-only account; `IDENTIFIED BY VALUES 'T:...'`
  leaves a 12C-only account with an unchanged password
- the `sqlnet.ora` that bequeath and listener-spawned processes read (`TNS_ADMIN` in the
  container); `awk` and `mktemp` present in the image; files from `docker cp` readable by `oracle`
- EZConnect `localhost:1521/DEMOPDB` works inside the container; the error a 10G-only account
  gets under `12a` (ORA-01017 or ORA-28040)
