# Changelog

All notable changes to this project are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning per [SemVer](https://semver.org/).

## [0.2.0] - 2026-11-13

### Changed

- Mechanics follow oracle-free-labs and the Oracle container contract (decisions E8-E11 in
  `docs/architecture.md`): data under `/opt/oracle/oradata` (19c `trivadis/ora_db` mapped to
  `/u01` + `INSTANCE_INIT`), configuration only through the image's `setup/` and `startup/`
  hooks, the image's own healthcheck
- Storage per lab in `lab.env`: `LAB_STORAGE=bind` (default, `LAB_DATA_BASE/<lab>/<db>`) or
  `volume` (named volumes with `nocopy`); the data path carries no image version
- Hooks and shared scripts taken 1:1 from oracle-free-labs `labdb` and `config/common/scripts`,
  mounted at the same path `/opt/oracle/common/scripts`; `common/sql/` merged into
  `common/scripts/`
- Standard PDB `LABPDB1` with the `labdb` core configuration in all labs (E14); `base26` is the
  `labdb` (image `oracle-free-labs:latest`); `seclab` adds `DEMOPDB`
- `LAB_BASELINE` is created by the last startup hook; `make up` waits for healthy + baseline
- An existing `lab.env` is completed with new keys from `lab.env.example`, existing values are
  never changed (named in the output)
- `verify.sh` reads ports, PDBs and services from the running containers

### Added

- `make rebuild LAB=<name>` (data gone, databases created again), `COMPOSE=` selector
- `docs/architecture.md`: start here, process overview, repository boundaries, decisions E8-E14
- Demos `demos/verifier`, `demos/unified-audit`, `demos/tde` (`requires: seclab`), mounted
  read-only at `/opt/oracle/demos` in seclab

### Removed

- Own setup layer of 0.1.0: `labctl` running setup hooks, marker files `.oradba-labs.setup` and
  `/tmp/oradba-labs.ready`, own healthcheck, `oradba.labs.*` compose labels, `lab_sql.sh`,
  `lab_ready.sh`, `create_pdb.sh`, `enable_unified_audit.sh` - all of it worked around named
  volumes being pre-filled by the Free image's prebuilt database (see `tasks/lessons.md`);
  last content in `v0.1.0`
- Docker named volumes as the only storage

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
