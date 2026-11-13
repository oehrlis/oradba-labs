# oradba-labs - Claude Code Context

## Kontext

Defensive Oracle Database security work (Oracle ACE Director): hardening, Unified Auditing,
detection and countermeasures, delivered as talks, trainings and tests. Every lab in this repo
is an own, isolated test environment on a local Docker host (later OCI); the goal of every
demo that runs on it is the countermeasure. Offensive demo SQL is written by Stefan at the
consumer (talk repo) - never here. This repo is **public**.

## Role in the lab architecture

Layer S3 (labs + use cases) of the four-layer model - source: `~/notes/prompts/lab-architecture.md`.

- Base: images (`oradba-docker` from M1/M2, until then `trivadis/ora_db` and Oracle Free)
- **Lab: `labs/<name>/` here** - exists once, consumers call it (`make up LAB=<name>`)
- Demo: 1-2 scripts at the consumer, naming its lab (`requires: seclab`), see `demos/README.md`

New labs only here; do not build a parallel variant in another repo. A conflict becomes a
decision E8+ in `lab-architecture.md`.

## Rules

- Image name and version **only** in `labs/<name>/lab.env.example` (M2 switch = one line)
- No binaries, no passwords (only `.env.example` with `CHANGE_ME`), no customer/site data
  (no private domains, hostnames, OCIDs)
- Ports bound to `127.0.0.1`, never 1521 (other labs run there) - one port range per lab
- Shared SQL only in `common/sql/`, shared scripts only in `common/scripts/`
- Init hooks are one line calling `bash common/scripts/...`; `setup/` runs via `labctl.sh`
  (never rely on the image to run setup hooks: Free skips them, ora_db ignores failures)
- Every `AUDIT` paired with `NOAUDIT`
- `make check` (shellcheck, markdownlint, compose config, gitleaks) before every commit/tag
- Do not change `docker`, `oracle-free-labs`, `oracle-database-docker*` from here (read only)

## Commands

```bash
make list | up | down | reset | status | connect | verify LAB=<name> [DB=db19|db26] [PURGE=1]
make lint      # shellcheck + markdownlint + compose config
make check     # lint + gitleaks (tree + history)
make tag       # check, tag v$(cat VERSION), push branch + tag
```

## Task management

`tasks/open-work.md` is the one checkbox file of this repo.
