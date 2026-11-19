# audit26 - Unified Auditing lab, 26ai Free, CDB FREE + AUDITPDB1

The Unified Auditing lab on top of `base26`: same image and core configuration, plus a PDB `AUDITPDB1` with sample
schemas and lab accounts but **no lab-owned audit policies**. Demos bring and remove their own policies, so every
measurement (record counts per policy, user, action) starts from a known state. This is the database part of the
planned migration of `ora-db-audit-eng/lab` (M3, see [../../docs/architecture.md](../../docs/architecture.md)); the
application simulator follows in M3.

| Item | Value |
| --- | --- |
| Image (`lab.env`) | `oracle-free-labs:latest` (23.26.3); plain `container-registry.oracle.com/database/free` works as well |
| CDB / PDB | `FREE` / `AUDITPDB1` (`FREEPDB1` dropped) |
| Port | `127.0.0.1:1573` -> 1521 |
| Container | `audit26-db26` |
| Accounts in `AUDITPDB1` | `SCOTT`, `TVD_HR` (schema-only), `LAB_ADMIN` (DBA in the PDB), `LAB_USER` (CREATE SESSION) |

What the lab sets up:

- core configuration as in `base26` (`common_db_config.sql`), ARCHIVELOG, guaranteed restore point `LAB_BASELINE`
- Unified Auditing pure mode, audit tablespace in `AUDITPDB1` and the audit housekeeping of `init_audit_config.sql`:
  a daily job sets the archive timestamp to `sysdate - 30`, a daily purge job removes what is older. Demos that
  set the archive timestamp themselves restore it by running `DAILY_UNIFIED_AUDIT_TIMESTAMP`
- no own audit policies, only what the image enables by default (Oracle-supplied, for example
  `ORA_LOGON_FAILURES`, `ORA_SECURECONFIG`). Demos measure from a start timestamp, not from an empty trail
- directory `COMMON_DATA` (`/opt/oracle/data/dpdump`), `demos/` of this repository mounted read-only at
  `/opt/oracle/demos`

```bash
make up LAB=audit26           # first start: database creation, a few minutes
make verify LAB=audit26       # checks + connect strings
make connect LAB=audit26
make reset LAB=audit26        # FLASHBACK DATABASE to LAB_BASELINE (removes demo policies and records)
make down LAB=audit26         # PURGE=1 also removes the data
```

Three client sources without an extra container are enough for `WHEN` conditions on `IP_ADDRESS`:

| Source | How | `SYS_CONTEXT('USERENV','IP_ADDRESS')` |
| --- | --- | --- |
| IPC inside the container | `docker exec` + `sqlplus` with `(ADDRESS=(PROTOCOL=IPC)(KEY=EXTPROC1521))` | `NULL` |
| Listener inside the container | `docker exec` + `sqlplus user@//localhost:1521/auditpdb1.oradba.ch` | `127.0.0.1` |
| Listener from the host | `sqlplus user@//127.0.0.1:1573/auditpdb1.oradba.ch` | Docker gateway address (e.g. `172.24.0.1`) |

Bequeath does not work for local PDB accounts: `ORACLE_PDB_SID` only applies to SYS, a local user gets ORA-01017.
Use IPC when a session without IP address is needed (verified on 23.26.3, 2026-11-19).

Demos name this lab (`requires: audit26`) - see [../../demos/README.md](../../demos/README.md). Policy definitions
stay with their consumer (for example `ora-db-audit-eng/sql/`) and are not copied here.
