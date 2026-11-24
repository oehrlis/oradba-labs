# dv26 - Database Vault test lab, 26ai Free, CDB FREE + DVPDB1

Throwaway lab for Database Vault tests on top of the `base26` mechanics: same image and core configuration, a PDB
`DVPDB1` with `SCOTT`, `LAB_ADMIN` (DBA in the PDB) and `LAB_USER`, and the common accounts `C##DV_OWNER` and
`C##DV_ACCTMGR`. **Database Vault is not configured** - `LAB_BASELINE` is the state before DV. The test itself
(CONFIGURE_DV, ENABLE_DV, CDB restart, realms) is the demo [`demos/database-vault`](../../demos/database-vault/README.md);
`make reset LAB=dv26` flashes back to the pre-DV state.

| Item | Value |
| --- | --- |
| Image (`lab.env`) | `oracle-free-labs:latest` (23.26.3), same as `audit26` |
| CDB / PDB | `FREE` / `DVPDB1` (`FREEPDB1` dropped) |
| Port | `127.0.0.1:1574` -> 1521 |
| Container | `dv26-db26` |
| Accounts | `SCOTT`, `LAB_ADMIN`, `LAB_USER` in `DVPDB1`; `C##DV_OWNER`, `C##DV_ACCTMGR` in the CDB |

```bash
make up LAB=dv26                # first start: database creation, a few minutes
make verify LAB=dv26
make reset LAB=dv26             # FLASHBACK DATABASE to LAB_BASELINE (DV not configured again)
make down LAB=dv26 PURGE=1      # containers and data; labs/dv26/lab.env stays (git-ignored)
```
