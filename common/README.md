# common

Shared building blocks for all labs - each exists once, here.

| Path | Runs | Purpose |
| --- | --- | --- |
| `scripts/labctl.sh` | host | lab lifecycle behind the Makefile (list, up, down, reset, status, connect, verify) |
| `scripts/lab_verify.sh` | host | generic checks per lab container, driven by the `oradba.labs.*` labels |
| `scripts/enable_unified_audit.sh` | container | Unified Auditing pure mode (relink `uniaud_on` if needed) |
| `scripts/lab_sql.sh` | container | run a SQL script as SYSDBA in a PDB, DEFINEs from env via stdin |
| `scripts/create_pdb.sh` | container | create a PDB from `PDB$SEED` (wraps `sql/create_pdb.sql`) |
| `scripts/lab_ready.sh` | container | ready marker for healthcheck and `labctl.sh` |
| `sql/create_scott.sql`, `sql/create_tvd_hr.sql` | container | sample schemas (schema-only, no login) |
| `sql/create_lab_users.sql` | container | `LAB_ADMIN` and `LAB_USER` |
| `sql/create_pdb.sql`, `sql/open_pdbs.sql` | container | PDB helpers |

Lab hooks stay one-liners that call a script here with `bash`. `labs/<name>/setup/<db>/` runs
once via `labctl.sh` after the first start (a failure stops `make up`, marker
`.oradba-labs.setup` in the data volume); `startup/<db>/` is sourced by the image init at every
start - calling `bash` keeps `set -euo pipefail` out of the image init. The containers see this directory read-only at
`/opt/oradba-labs/common`.

Sources: `oracle-free-labs/config/common/scripts` (SQL) and `docker/samples/common` (hook
pattern), copied once - M3 consolidates the rest.
