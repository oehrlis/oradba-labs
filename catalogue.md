# Lab catalogue

One line per lab. A demo names its lab (`requires: <lab>`), it does not bring its own.

<!-- markdownlint-disable MD013 MD060 -->
| Lab | Purpose | Images / versions | Ports | Consumer |
| --- | --- | --- | --- | --- |
| `base19` | 19c EE: CDB `CDB19` + `LABPDB1` (core config of `labdb`), Unified Audit pure | `trivadis/ora_db:19.27.0.0` | 1561 | tests, base for 19c-only demos |
| `base26` | 26ai Free = oracle-free-labs `labdb`: CDB `FREE` + `LABPDB1` | `oracle-free-labs:latest` (23.26.3) | 1571 | deep-data demos, base for 26ai-only demos |
| `seclab` | Default security lab: 19c + 26ai side by side, `LABPDB1` + `DEMOPDB` (SCOTT, TVD_HR, LAB_ADMIN, LAB_USER) | both of the above | 1562, 1572 | security talks (privilege escalation, hold my beer exercises), trainings |
<!-- markdownlint-restore -->

## Planned (not in M0)

- M0b: assign hold-my-beer and deep-data demos to a lab (`seclab` or `base26`)
- M3: migrate the use cases from `docker/samples` (audit, tde, dbv, cmu, eus, pdb, rman,
  patch), the `oracle-free-labs` profiles (incl. its intentionally insecure assessment
  baseline) and `ora-db-audit-eng/lab` - each becomes a lab here or is dropped on purpose
- M2: all labs on `oradba-docker` images (one line per lab in `lab.env`)
