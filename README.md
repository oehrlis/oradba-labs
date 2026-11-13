# oradba-labs

Oracle Database lab environments for talks, trainings and tests - one lab on push of a button.
Today on Docker, later (M5) the same labs on OCI.

Defensive scope: own, isolated lab databases for Oracle Database security work - hardening,
audit, detection and the countermeasure behind every demo.

## Quick start

```bash
make list                     # base19, base26, seclab
make up LAB=seclab            # start, wait until ready, take baseline, verify
make verify LAB=seclab        # checks + connect strings
make connect LAB=seclab DB=db19
make reset LAB=seclab         # back to the baseline (FLASHBACK DATABASE), < 5 min
make down LAB=seclab          # containers gone, data volumes kept
make down LAB=seclab PURGE=1  # data volumes gone too
```

The first `make up` creates `labs/<name>/lab.env` from `lab.env.example` and generates the
passwords. `lab.env` is git-ignored; image, version, ports and passwords live only there.

## Layout

```text
oradba-labs/
  Makefile              # make list | up | down | reset | status | connect | verify LAB=<name>
  catalogue.md          # Lab | purpose | images/versions | consumer
  common/sql/           # shared SQL, once (SCOTT, TVD_HR, PDB, lab accounts)
  common/scripts/       # labctl.sh (lifecycle), lab_verify.sh, in-container helpers
  labs/<name>/
    lab.env.example     # image + version + ports + password placeholders
    compose.yml         # services carry oradba.labs.* labels (kind, sid, pdbs, port)
    setup/<db>/         # init hooks, once at database creation
    startup/<db>/       # init hooks, at every start
    verify.sh           # healthy + connection test, prints connect strings
    README.md
  demos/README.md       # demo convention (requires: <lab>, setup/run/reset)
```

## Three levels

| Level | What | Where |
| --- | --- | --- |
| Base | image / container, base configuration | `oradba-docker` (M1/M2), today `trivadis/ora_db` and Oracle Free |
| Lab | reusable environment on one or more bases | `labs/` in this repo |
| Demo | 1-2 scripts (setup/run/reset) on a lab | at the consumer (talk repo), or `demos/` when reused |

A lab exists once, here. Talks and trainings call it, they never copy it.

## How a lab works

- `make up` runs `docker compose up -d`, waits until every container is healthy and its
  startup hooks have run (marker `/tmp/oradba-labs.ready`), runs pending setup hooks, then
  creates the guaranteed restore point `LAB_BASELINE` and runs `verify.sh`
- `make reset` flashes every database of the lab back to `LAB_BASELINE` (in parallel) and
  opens all PDBs - the lab is back at its starting point, including audit trail and users
- Ports are bound to `127.0.0.1` only and never 1521 - each lab has its own ports in `lab.env`

## Requirements

- Docker Desktop or Docker Engine with compose v2, about 6 GB memory for `seclab`
- The images: `trivadis/ora_db:19.27.0.0` (private, built from `oehrlis/docker`, until M2) and
  `container-registry.oracle.com/database/free` (Oracle license terms apply)
- For `make lint`/`make check`: shellcheck, markdownlint, gitleaks

## Rules for this public repo

- No binaries, no patches, no passwords (only `lab.env.example`), no customer or site data
- Images stay private (Oracle license); labs only know image name + version + connection
- No attack code: demos at the consumer bring their own scripts

## License

Apache License 2.0 - see [LICENSE](LICENSE). `common/sql/create_scott.sql` and
`create_tvd_hr.sql` are under the Universal Permissive License as noted in their headers.
