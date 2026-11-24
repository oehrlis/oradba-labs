# database-vault - CONFIGURE_DV / ENABLE_DV, role realms, DV_PATCH_ADMIN

```yaml
requires: dv26
databases: db26
pdb: DVPDB1
verified: yes (2026-11-24, 23.26.3 Free - db26 only)
```

Test of Database Vault in a CDB: configure and enable DV in `CDB$ROOT` (needs a CDB restart), then in `DVPDB1`, with the
common accounts `C##DV_OWNER` / `C##DV_ACCTMGR` created by the `dv26` setup. Then role-protection realms (regular vs
mandatory), a DBA with `GRANT ANY ROLE` (`LAB_ADMIN`), and `DV_PATCH_ADMIN` for `SYS`.

Run from the repo root, one script at a time (passwords come from the container environment, never from argv):

```bash
make up LAB=dv26
demos/database-vault/run.sh setup.sql            # guard: DV not configured yet
demos/database-vault/run.sh 01_configure_root.sql
demos/database-vault/run.sh 02_enable_root.sql   # includes SHUTDOWN IMMEDIATE / STARTUP
demos/database-vault/run.sh 03_pdb.sql
# 04_realms.sql ... 08_patch_admin_effect.sql the same way, then check.sql
make reset LAB=dv26                              # real reset: flashback, DV not configured again
```

| Script | Does |
| --- | --- |
| `setup.sql` | refuses to run if DV is already configured |
| `01_configure_root.sql` | `DVSYS.CONFIGURE_DV` in root (as SYS), `utlrp` |
| `02_enable_root.sql` | `DBMS_MACADM.ENABLE_DV` as the common DV owner, then restart the CDB |
| `03_pdb.sql` | `CONFIGURE_DV` + `ENABLE_DV` in `DVPDB1` with the common owner and account manager, PDB close/open |
| `04_realms.sql` | roles `APP_ROLE_REG` / `APP_ROLE_MAND`, regular and mandatory realm on them |
| `05_realm_tests.sql` | `LAB_ADMIN` without authorization / participant / owner, then `SYS` |
| `06_admin_option.sql` | does `WITH ADMIN OPTION` bypass the realm? (`LAB_USER`) |
| `07_patch_admin.sql` | data realms on `SCOTT.EMP` / `SCOTT.DEPT`, `SYS` without patch role, who may grant `DV_PATCH_ADMIN` |
| `08_patch_admin_effect.sql` | `SYS` with `DV_PATCH_ADMIN`, `ENABLE_DV_PATCH_ADMIN_AUDIT`, what is in `UNIFIED_AUDIT_TRAIL` |
| `check.sql` | `CDB_DV_STATUS` of root and PDB |
| `reset.sql` | removes steps 4-8 (realms, roles, patch role, `DISABLE_DV_PATCH_ADMIN_AUDIT` as counterpart); DV stays enabled |

Results (23.26.3, 2026-11-24) are in the knowledge base: `delphi-oradba`, topic Database Vault, separation of duty.
`run.sh` is for this demo only; the scripts connect with `CONNECT`, they are not meant for another lab.
