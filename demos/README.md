# Demos

A demo is one or two scripts that run on a lab - not a lab of its own.

## Where a demo lives

- At its consumer (talk or training repo) as long as one consumer uses it
- Here in `demos/<name>/` once it is used more than once (talk + training)

## Convention

Every demo directory carries a short `README.md` with a front block:

```yaml
requires: seclab          # the lab from labs/ - make up LAB=seclab
databases: db19, db26     # which lab databases it runs on
pdb: DEMOPDB
```

and up to three scripts:

| Script | Runs as | Does |
| --- | --- | --- |
| `setup.sql` | `LAB_ADMIN` or SYSDBA in the PDB | creates what the demo needs (demo accounts, objects, audit policies) |
| `run.sql` / `detect.sql` / `fix.sql` | as named in the README | the demo itself, detection and countermeasure |
| `reset.sql` | SYSDBA | removes everything `setup.sql` created; `AUDIT` is always paired with `NOAUDIT` |

If a demo cannot clean up after itself, `make reset LAB=<lab>` returns the whole lab to its
baseline (restore point `LAB_BASELINE`).

## Rules

- No attack code in this public repo. Offensive demo SQL stays with its author at the consumer
- Demo-specific accounts (e.g. `LOWPRIV_DEMO`) are created by the demo's `setup.sql`
- A demo states the lab and the release it was verified on (e.g. `19.27`, `23.26.3`)

## Known demos

<!-- markdownlint-disable MD013 MD060 -->
| Demo | Lives in | requires | Notes |
| --- | --- | --- | --- |
| oracle-privesc module 4 (external table preprocessor) | talk repository | `seclab` | `detect.sql`, `fix.sql` there; `DEMOPDB` exists on both databases |
| `verifier` - password verifiers, 10G hashes | `demos/verifier/` | `seclab` (db19) | changes `sqlnet.ora`: run `reset.sql`, `make reset` does not revert files |
| `unified-audit` - policy with paired NOAUDIT | `demos/unified-audit/` | `seclab` (db19, db26) | no restart |
| `tde` - WALLET_ROOT, keystore, encrypted tablespace | `demos/tde/` | `seclab` (db26) | restart in the solution and in `reset.sql` |
| deep-data security demos | talk repository | `base26` (`LABPDB1`) | until DOAG on `labdb`; change: container `base26-db26`, port 1571 |
<!-- markdownlint-restore -->
