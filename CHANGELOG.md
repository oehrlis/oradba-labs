# Changelog

All notable changes to this project are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning per [SemVer](https://semver.org/).

## [0.1.0] - 2026-11-13

### Added

- Repository skeleton (M0 of the lab architecture): README, CLAUDE.md, LICENSE (Apache 2.0),
  `.gitignore`, `.markdownlint.json`, VERSION, Makefile
- `make list | up | down | reset | status | connect | verify LAB=<name>` on top of
  `common/scripts/labctl.sh`; `down` keeps data volumes unless `PURGE=1`
- `make up` waits for healthy + ready marker, runs pending setup hooks, creates the guaranteed
  restore point `LAB_BASELINE`; `make reset` flashes all lab databases back to it in parallel
- `lab.env` generated from `lab.env.example` with random passwords at the first `make up`
- Generic `lab_verify.sh`: health, ARCHIVELOG, Unified Auditing, restore point, listener login
  per PDB, expected accounts, connect strings - driven by `oradba.labs.*` compose labels
- Labs `base19` (`trivadis/ora_db:19.27.0.0`, CDB + PDB1), `base26` (26ai Free 23.26.3,
  FREEPDB1) and `seclab` (both side by side, `DEMOPDB` with SCOTT, TVD_HR, LAB_ADMIN, LAB_USER),
  all with Unified Auditing pure mode
- `common/sql/` with SCOTT, TVD_HR (trimmed: no passwords, no VPD part), PDB and lab-account
  scripts; `catalogue.md`; `demos/README.md` with the demo convention (`requires: <lab>`)
- `make lint`, `make check` (shellcheck, markdownlint, compose config, gitleaks), `make tag`
