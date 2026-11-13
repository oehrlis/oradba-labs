# base26 - Oracle AI Database 26ai Free, CDB FREE + LABPDB1 (= labdb)

The oracle-free-labs `labdb`, moved here: Free 23.26.3 with OraDBA, `FREEPDB1` dropped, standard
PDB `LABPDB1` with audit configuration and policies, directory `COMMON_DATA`, network wallet.

| Item | Value |
| --- | --- |
| Image | `oracle-free-labs:latest` (Free + OraDBA, `make build` in oracle-free-labs); plain `container-registry.oracle.com/database/free` works as well |
| Port | `127.0.0.1:1571` -> 1521 |
| Services | `free.oradba.ch`, `labpdb1.oradba.ch` |
| First start | database creation on empty data, a few minutes |

```bash
make up LAB=base26
make connect LAB=base26
make reset LAB=base26
make down LAB=base26          # PURGE=1 also removes the data
```

`setup/db26/` and `startup/db26/` are the `labdb` hooks 1:1; the image runs them
(`/opt/oracle/scripts/setup|startup`). Demos written for `labdb` only change container
(`base26-db26`) and port (1571).
