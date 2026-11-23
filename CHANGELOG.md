# Changelog

All notable changes to this project are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning per [SemVer](https://semver.org/).

## [Unreleased]

### Added

- `make reset` deletes the archived logs of every orphaned incarnation after the flashback (RMAN),
  keeping those of the `LAB_BASELINE` incarnation and the current one. Tested 2026-11-23 with two resets
  in a row on seclab (db19 54 % -> 36 %, db26 65 % -> 18 %) and on base19; the second flashback works
- `make verify` reports the recovery area usage per database and warns from 80 %. Every `make reset`
  (flashback + RESETLOGS) starts a new incarnation; the archived logs of the old ones stay in the
  recovery area (no backups, nothing reclaimable). seclab-db19 reached 100 % of its 6400M after nine
  days and 21 resets and stopped at startup with ORA-19809 / ORA-16038 (2026-11-22)
- `make up` names per database whether the image starts existing data or creates the database
  (same test as the image: `oradata/<SID>/` for `trivadis/ora_db`, `oradata/.<SID>.created` for Free;
  a running dbca - `make up` again during the first start - counts as creating)
- Lab `audit26`: Unified Auditing lab on top of `base26` (26ai Free, CDB `FREE` + `AUDITPDB1`, port 1573) with
  `SCOTT`, `TVD_HR`, `LAB_ADMIN`, `LAB_USER` and no lab-owned audit policies - demos bring their own and measure
  from a start timestamp. Database part of the M3 migration of `ora-db-audit-eng/lab`, pulled forward; the
  application simulator and the remaining setup steps stay in M3
- `base19` / `base26`: sample schemas `SCOTT` and `TVD_HR` in `LABPDB1` (setup hooks `16_create_scott_labpdb1.sql`,
  `17_create_tvd_hr_labpdb1.sql`, common scripts as in `audit26`); `base19` keeps the 19c template `HR`. Only a
  new database gets them - `make rebuild LAB=<lab>`. Tested 2026-11-23: base19 rebuild (dbca about 15 min), verify
  with `SCOTT`, `TVD_HR`, `HR` OK; base26 follows after the MFA demo (verify expects them only then)

### Changed

- `make up` / `make reset` abort on a failed start instead of waiting up to `READY_TIMEOUT` (3600 s):
  with the container name, the last 20 lines of the alert log (read in the container - the image tails
  it to `docker logs` only once its start script is done) and a pointer to `make verify` /
  `v$recovery_area_usage`. Abort when the image reports `WAS NOT SUCCESSFUL` (both images, also a failed
  dbca), and for existing data when the container is `unhealthy` or not healthy after `START_TIMEOUT`
  (default 300 s = image StartPeriod; a start takes 11-61 s). A database being created waits up to
  `READY_TIMEOUT`: during the 19c dbca (about 15 min) the container is `unhealthy` from about 8 min
  (StartPeriod 300 s, 3 x 60 s checks). Tested 2026-11-23 on base26 with a provoked ORA-16038 (recovery
  area below its usage, archiver stuck, container killed): abort after 11 s with ORA-16038 / ORA-19809
  in the tail

- Demo READMEs `verifier`, `unified-audit`, `tde`: timings of the full rerun on 2026-11-22

### Fixed

- `labctl.sh`: `DRY_RUN` accepted only `TRUE`; any other spelling (`DRY_RUN=1` called directly) ran
  live. Now `TRUE|1|yes` / `FALSE|0|no` (case-insensitive), anything else is an error

- `demos/tde`: `reset.sql` claimed that `make reset` clears the remaining master key metadata. Tested
  2026-11-22 on 23.26.3: `V$DATABASE_KEY_INFO.MASTERKEY_ACTIVATED` stays `YES` after the flashback
  (control file); only `make rebuild LAB=seclab` returns to a database without keys. README updated

- seclab db19: Java pool floor `java_pool_size = 64M` (spfile, new startup hook
  `labs/seclab/startup/db19/05_java_pool.sql`). With the image default (16M under ASMM) repeated privesc
  weak/reset cycles filled the pool and `stage.sh unweak` (m4b, `DBMS_JAVA`) failed with ORA-04031; online
  growth is refused with ORA-04033, so it takes effect at the next restart. Set on the running lab 2026-11-16

## [0.2.0] - 2026-11-13

### Changed

- Mechanics follow oracle-free-labs and the Oracle container contract (decisions E8-E11 in
  `docs/architecture.md`): data under `/opt/oracle/oradata` (19c `trivadis/ora_db` mapped to
  `/u01` + `INSTANCE_INIT`), configuration only through the image's `setup/` and `startup/`
  hooks, the image's own healthcheck
- Storage per lab in `lab.env`: `LAB_STORAGE=bind` (`LAB_DATA_BASE/<lab>/<db>`); the data path
  carries no image version. `volume` is rejected with a message for now (nocopy volume owned by
  root, without nocopy the prebuilt Free DB skips the setup hooks) - planned with M5
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
- `common/scripts/feature_probe.sh` / `make probe`: feature traces per release in home and
  dictionary, `--diff` and `--list` between two releases (image mode needs no database)
- `docs/architecture.md`: start here, process overview, repository boundaries, decisions E8-E14
- Demos `demos/verifier`, `demos/unified-audit`, `demos/tde` (`requires: seclab`), mounted
  read-only at `/opt/oracle/demos` in seclab

### Removed

- `common_db_config.sql`: legacy common profiles, password verify function and common users
  (project-specific names from oracle-free-labs, not needed by any lab)
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
