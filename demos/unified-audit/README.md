# unified-audit - Unified Audit policy for privileged users, including NOAUDIT

```yaml
requires: seclab
databases: db19, db26
pdb: DEMOPDB
verified: yes (2026-11-13, 19.27 / 23.26.3)
```

hold-my-beer round 2 (everyday DBA work), DOAG AK 2026. Pool entry: `Unified Audit Policy fuer
privilegierte User inklusive NOAUDIT` / "Unified Audit policy for privileged users, including
NOAUDIT" (owner Stefan, Security, medium, low risk).

## Task as the audience sees it

> A new colleague got the DBA role in DEMOPDB. Audit everything privileged users do - but not
> the application account - and deliver the way back (NOAUDIT) with it. Prove it in the audit
> trail. You have 5 minutes.

AI pitfalls named in the pool: traditional/unified syntax mix, forgotten NOAUDIT.

## Starting point (`setup.sql`)

- `HMB_DBA` with role `DBA`, `HMB_APP` with `CREATE SESSION` and `SELECT` on `TVD_HR.EMPLOYEES`
- only the Oracle default policies enabled (seclab baseline)
- decoy: `AUDIT SELECT ANY TABLE BY hmb_dba BY ACCESS` - traditional syntax. On 19c it is
  accepted and shows up in `DBA_PRIV_AUDIT_OPTS`, but pure mode writes no record. That is what
  an AI answer in traditional syntax produces: it looks configured and audits nothing. 26ai
  rejects it (ORA-46401, traditional auditing desupported) - `setup.sql` reports that and goes on

## Expected solution (`solution.sql`)

1. Local policy in DEMOPDB: `CREATE AUDIT POLICY hmb_loc_priv_usr_act_pol ACTIONS ALL ONLY TOPLEVEL`
   (based on `oradba_loc_all_act_priv_usr`)
2. Enable by role: `AUDIT POLICY ... BY USERS WITH GRANTED ROLES dba` - not `BY ALL USERS`,
   which would audit every statement of the application account as well
3. Bonus: `hmb_loc_crit_priv_use_pol` for the use of critical system privileges (subset of
   `oradba_loc_critical_db_act`)
4. Verify `ENABLED_OPTION` in `AUDIT_UNIFIED_ENABLED_POLICIES` (`BY GRANTED ROLE` / `DBA`)
5. Deliver the way back: `NOAUDIT POLICY ... BY USERS WITH GRANTED ROLES dba` (same BY clause
   as the AUDIT), then `DROP AUDIT POLICY` - a drop fails while the policy is enabled
6. `check.sql`: new sessions as `HMB_DBA` and `HMB_APP`, the trail shows the `SELECT` of
   `HMB_DBA` with `HMB_LOC_PRIV_USR_ACT_POL` (and `SELECT ANY TABLE` with the bonus policy),
   `HMB_APP` reads the same table without a privileged-user record

DBA-instinct points: policy changes apply to new sessions only; `BY USERS WITH GRANTED ROLES
dba` also covers `SYS` and `LAB_ADMIN`; traditional `AUDIT` statements do nothing in pure mode.

## Timing

| Step | Target |
| --- | --- |
| Policy + AUDIT | 2 min |
| Verify enablement + NOAUDIT statement | 1 min |
| `check.sql` (activity + trail) on the beamer | 1.5 min |
| Buffer | 0.5 min |

5 minutes hard. Before the session: `setup.sql` and one `check.sql` run (the "before" picture).

Measured 2026-11-13 (three runs on 19.27, two on 23.26.3):

<!-- markdownlint-disable MD013 MD060 -->
| Script | 19.27 | 23.26.3 |
| --- | --- | --- |
| `setup.sql` | 6 s | 1 s |
| `solution.sql` | 5-6.5 s | 0.3 s |
| `check.sql` | 1 s | 1 s |
| `reset.sql` | 17 s | 0.2-0.8 s |
<!-- markdownlint-restore -->

On 19.27 every query on `AUDIT_UNIFIED_POLICIES` takes about 5 s - that is the whole difference.
Start `reset.sql` right after the round, not while the next team is waiting.

## Run

The repo's `demos/` is mounted read-only in both containers at `/opt/oracle/demos`:

```bash
# lab running (make up LAB=seclab); seclab-db19 or seclab-db26
docker exec -it -w /opt/oracle/demos/unified-audit seclab-db19 bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" / as sysdba'
```

```sql
@setup.sql
@check.sql
@solution.sql
@check.sql
@reset.sql
```

Password: `&1` of `setup.sql` / `check.sql`, default `HmbDemo_Lab_Only_UA` - lab-only demo
value, letters, digits and underscore only. Same scripts on `seclab-db26`.

## Reset

`@reset.sql` runs `NOAUDIT` and `DROP AUDIT POLICY` for both policies of `solution.sql`, sweeps
every other `HMB_*` policy (NOAUDIT with the BY clause read from
`AUDIT_UNIFIED_ENABLED_POLICIES`), runs `NOAUDIT` for the traditional decoy, drops the accounts
and fails if an `HMB_*` policy is left. Custom policies with other names - in DEMOPDB or as
common policy in `CDB$ROOT` - are reported with the commands, not dropped. Name live policies
`HMB_*` so the sweep catches them.

`make reset LAB=seclab` (flashback) reverts policies, accounts and the audit trail - this demo
changes no spfile parameter and no file. Without `make reset` the trail keeps the records of
earlier rehearsals for the same user names; `check.sql` shows the newest first.

Verified 2026-11-13: after `reset.sql` the enabled policies in `CDB$ROOT`, `DEMOPDB` and
`LABPDB1` equal the baseline on both databases. The sweep was tested with two extra live-style
policies (`BY hmb_app` and `EXCEPT hmb_app`): both were disabled and dropped.

## Verified (2026-11-13, 19.27 / 23.26.3)

- 26ai rejects the traditional `AUDIT SELECT ANY TABLE BY ...` with ORA-46401; `NOAUDIT` of it
  is still accepted. `DBA_STMT_AUDIT_OPTS` / `DBA_PRIV_AUDIT_OPTS` exist on both releases
- `DBMS_AUDIT_MGMT.FLUSH_UNIFIED_AUDIT_TRAIL` no longer exists on 23.26.3 (PLS-00302 at
  compile time); `check.sql` calls it dynamically on 19c only. The records are there without it
- `AUDIT_UNIFIED_POLICIES.ORACLE_SUPPLIED` and `COMMON` exist on both releases
- the fresh `HMB_DBA` session after the `AUDIT POLICY` is audited on both releases; `HMB_APP`
  reading the same table via object grant leaves no record
- EZConnect needs the service with `db_domain`: `localhost:1521/DEMOPDB` gives ORA-12514,
  `check.sql` derives `demopdb.oradba.ch` from `db_domain`
- `DBMS_OUTPUT` is per container: the scripts re-enable `SERVEROUTPUT` after every
  `ALTER SESSION SET CONTAINER`
