# common

Shared building blocks for all labs - each exists once, here. The containers see
`common/scripts/` read-only at `/opt/oracle/common/scripts`, the same path as in oracle-free-labs,
so the `labdb` hooks run unchanged.

| Path | Runs | Purpose |
| --- | --- | --- |
| `scripts/labctl.sh` | host | lab lifecycle behind the Makefile (list, up, down, reset, rebuild, status, connect, verify) |
| `scripts/lab_verify.sh` | host | checks per lab container and connect strings |
| `scripts/create_lab_baseline.sh` | container | last startup hook: restore point `LAB_BASELINE` once |
| `scripts/run_sql_script.sh` | container | SQL as SYSDBA in CDB or PDB with logging; passwords by env name via stdin |
| `scripts/define_logging_*.sql`, `require_*.sql` | container | logging and container guards of every hook |
| `scripts/common_db_config.sql` | container | core instance configuration (`db_domain`, profiles, common users) |
| `scripts/create_pdb.sql`, `drop_pdb.sql`, `create_ts_users.sql` | container | PDB helpers |
| `scripts/init_audit_config.sql`, `create_audit_policies.sql`, `enable_audit_policies.sql` | container | audit tablespace, purge job, OraDBA policies |
| `scripts/setup_network_wallet.sh` | container (Free) | wallet directory on the persistent `dbconfig` |
| `scripts/create_scott.sql`, `create_tvd_hr.sql` | container | sample schemas (schema-only, no login) |
| `scripts/create_lab_users.sql` | container | `LAB_ADMIN` and `LAB_USER` |

Source: `oracle-free-labs/config/common/scripts` (copied 1:1, except `create_tvd_hr.sql`: no
passwords, no VPD part). The rest of that directory moves with M3.
