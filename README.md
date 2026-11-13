# oradba-labs

Oracle Database lab environments for talks, trainings and tests - one lab on push of a button.
Today on Docker, later (M5) the same labs on OCI.

Defensive scope: own, isolated lab databases for Oracle Database security work - hardening,
audit, detection and the countermeasure behind every demo.

**Start here:** [docs/architecture.md](docs/architecture.md) - which repository does what, how a lab
is built, and the decisions behind it ("I need ... -> decision -> build").

## Quick start

```bash
make list                      # base19, base26, seclab
make up LAB=seclab             # start, wait until healthy + baseline, verify
make verify LAB=seclab         # checks + connect strings
make connect LAB=seclab DB=db19
make reset LAB=seclab          # back to the baseline (FLASHBACK DATABASE), about 1 min
make rebuild LAB=seclab        # data gone, databases created again
make down LAB=seclab           # containers gone, data kept
make down LAB=seclab PURGE=1   # data gone too
```

Does a release carry a feature - without building the demo? `make probe P='mfa_|_mfa'
IMAGES="trivadis/ora_db:19.27.0.0 oracle-free-labs:latest"` reads error messages, binary and catalog
scripts of local images (no database start); `LAB=seclab` adds the data dictionary of the running
containers, `DIFF=1` shows what only one of two targets has.

The first `make up` creates `labs/<name>/lab.env` from `lab.env.example` and generates the
passwords. `lab.env` is git-ignored; image, version, ports, storage and passwords live only there.
Keys added to `lab.env.example` later are appended to an existing `lab.env` and named - existing
values are never changed.

## Layout

```text
oradba-labs/
  Makefile              # make list | up | down | reset | rebuild | status | connect | verify LAB=<name>
  catalogue.md          # Lab | purpose | images/versions | consumer
  docs/architecture.md  # big picture, repository boundaries, decisions
  common/scripts/       # shared SQL + scripts, once (from oracle-free-labs), labctl.sh, lab_verify.sh
  labs/<name>/
    lab.env.example     # image + version + ports + storage + password placeholders
    compose.yml         # Oracle container contract: oradata, scripts/setup, scripts/startup
    setup/<db>/         # hooks, once at database creation (run by the image)
    startup/<db>/       # hooks, at every start (run by the image), last: LAB_BASELINE
    verify.sh           # healthy + connection test, prints connect strings
    README.md
  demos/                # demos used more than once (requires: <lab>)
```

## How a lab works

- **Contract:** labs follow the Oracle container pattern ([oracle/docker-images
  SingleInstance](https://github.com/oracle/docker-images/tree/main/OracleDatabase/SingleInstance),
  container-registry.oracle.com): `ORACLE_PWD`, data under `/opt/oracle/oradata`, hooks under
  `/opt/oracle/scripts/setup` and `/opt/oracle/scripts/startup`, the image's healthcheck. The image
  creates the database (19c: dbca, Free: on an empty data directory) and runs the hooks - the lab
  only provides them. The pattern and the scripts come from oracle-free-labs (`labdb`).
- **Storage:** `LAB_STORAGE=bind` keeps the data under `LAB_DATA_BASE/<lab>/<db>` on the host
  (`~/oradba-labs-data`). The path does not contain the image version: the same data can be started
  with a newer image (tested: Free on the plain Oracle image, then on `oracle-free-labs:latest`).
  `LAB_STORAGE=volume` is not supported yet: a `nocopy` volume is owned by root, and without
  `nocopy` the Free image's prebuilt database is copied in and the setup hooks are skipped -
  planned with Podman / cloud hosts (M5).
- **Baseline and reset:** the last startup hook creates the guaranteed restore point
  `LAB_BASELINE` once. `make up` waits for healthy + baseline. `make reset` flashes every database
  of the lab back to it in parallel; `make rebuild` starts from empty data.
- Ports are bound to `127.0.0.1` only and never 1521 - each lab has its own ports in `lab.env`.
- Standard PDB `LABPDB1` with the core configuration of `labdb` (audit, profiles, `db_domain`);
  a lab with other content uses another PDB name (seclab: `DEMOPDB`).

## Requirements

- Docker Desktop or Docker Engine with compose v2; about 6 GB memory for `seclab`
- Images: `trivadis/ora_db:19.27.0.0` (own image, until M2), `oracle-free-labs:latest` (Free +
  OraDBA, built by oracle-free-labs) or `container-registry.oracle.com/database/free` - Oracle
  license terms apply. From M2 the images come from `oradba-docker`.
- For `make lint` / `make check`: shellcheck, markdownlint, gitleaks
- Podman: planned (`COMPOSE=podman`), not tested yet

## Rules for this public repo

- No binaries, no patches, no passwords (only `lab.env.example`), no customer or site data
- Images stay private (Oracle license); labs only know image name + version + connection
- No attack code: offensive demo SQL stays with its author at the consumer

## License

Apache License 2.0 - see [LICENSE](LICENSE). `common/scripts/create_scott.sql` and
`create_tvd_hr.sql` are under the Universal Permissive License as noted in their headers.
