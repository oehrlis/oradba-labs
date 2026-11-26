# Oracle Free 23.26.4.0 container image - evidence

This folder collects evidence for the draft mail to Oracle about `container-registry.oracle.com/database/free:23.26.4.0`.
It checks every claim in the draft against `23.26.3.0`. Without evidence, no mail is sent.

- Images, pinned by index digest:
  - `23.26.3.0` `sha256:f988b0c04c4c386cd306a2a914c0d7a9702d83acc31b064a28ad8eb6278a8fba`
  - `23.26.4.0` = `latest` `sha256:f5a1791bf5628fd1a97e07584ff5ac5537da5021c23e70f5083f48c8fcd6476e`
- Registry data is from both architectures. File system and runtime tests ran on arm64 only; amd64 under emulation
  is too slow and was **not** tested
- Status: gate (online, static) done on 2026-11-25; runtime tests t1-t6 done on 2026-11-26 (arm64, offline,
  10 runs, `raw/runtime-summary.tsv`)

## Results

<!-- markdownlint-disable MD013 MD060 -->
| # | Claim | Result | Evidence | Key figure |
| --- | --- | --- | --- | --- |
| 1 | Compressed size 3.53 -> 1.92 GB (arm64), 3.71 -> 2.11 GB (amd64) | confirmed | `01-size.md` | -1.61 GB arm64, -1.60 GB amd64 |
| 1a | "The 1.6 GB are the seed files" | refuted | `01-size.md` | seed files about 0.39 GB compressed; dnf cache 0.67 GB; prebuilt DB still in the image as tar.gz |
| 2 | `FREE_Database.dbc` + seed files missing | confirmed | `02-dbca-template.md` | templates dir 428 MB -> empty |
| 2a | `runOracle.sh` on an empty dir fails with DBT-10508 | confirmed (t3) | `02-dbca-template.md` | exit 1 after 2 s, `[FATAL] [DBT-10508]` |
| 2b | New: `ORACLE_SID` other than `FREE` cannot start | confirmed (t4) | `02-dbca-template.md` | `RELINK_BINARY_FILE` and `CONFIG_RSP` unset, exit 1 before DBCA |
| 3 | Default command `startPrebuilt.sh`, extracts into an empty (mounted) dir | confirmed (config + code) | `03-startup.md` | Cmd changed, new script "Since: September, 2026" |
| 3a | Setup scripts never run with an empty dir | confirmed (t1) | `03-startup.md` | 23.26.3: setup + startup ran (112 s); 23.26.4: only startup (31 s) |
| 3b | `README.md` / `Dockerfile` missing in the image | confirmed | `03-startup.md` | - |
| 3c | New: a failing startup script stops the container | confirmed (t6) | `03-startup.md` | ORA-00942 in startup SQL: 23.26.3 keeps running, 23.26.4 exits 1 |
| 4 | Other character set via empty dir no longer works | partly confirmed (t2) | `04-characterset.md` | 23.26.3: CDB + PDB `WE8MSWIN1252`; 23.26.4: CDB `AL32UTF8`, only `FREEPDB1` converted |
| 4a | Registry doc contradicts code on `ORACLE_CHARACTERSET` | confirmed | `04-characterset.md` | - |
| 5 | No release notes, behaviour not documented | confirmed (not found) | `05-docs-origin.md` | registry doc describes 23.26.3; GitHub has none of the new scripts |
<!-- markdownlint-restore -->

Assessment (after runtime): the 23.26.4 image is an intended redesign (prebuilt database as tar.gz, PDB-only
character set conversion, strict startup scripts), not a broken build. What is wrong is the documentation and the
leftover create path:

- the registry page still describes 23.26.3 (empty host directory -> new database, setup scripts run, character
  set for the whole database), and nothing documents the new behaviour
- the create path in `runOracle.sh`/`createDB.sh` is still there but has no inputs left: no DBCA template for SID
  `FREE` (t3), no relink script variable and no response template for any other SID (t4)
- the control run with the documented prebuilt path (t5, no bind mount) behaves the same in both images

Recommendation: send the mail as documentation feedback plus the two create-path defects (`mail-draft.md`), not as
"is the build incomplete?". The labs side is decided in `tasks/open-work.md`.

Timing (arm64, ready to use): empty bind dir 31 s on 23.26.4 (extraction) vs 112 s on 23.26.3 (DBCA from
template); no bind mount 21 s vs 10 s.

## Reproduce

```bash
docs/evidence/free-23-26-4/collect.sh --help
docs/evidence/free-23-26-4/collect.sh --phase registry --yes   # network: manifests, sizes, registry page
docs/evidence/free-23-26-4/collect.sh --phase static --yes     # local, no DB start
docs/evidence/free-23-26-4/collect.sh --phase runtime --yes    # local, offline, about 1-2 h on arm64
docs/evidence/free-23-26-4/collect.sh --delete                 # remove free-diff-* containers and the work dir
```

The runtime phase starts throwaway containers `free-diff-*` without published ports and does not touch other
containers. Bind directories live in `.work/free-23-26-4/` (gitignored) and are removed at the end; the images
stay. Each test writes `raw/rt-<test>-<tag>.txt` (command, digest, date, `docker logs`, dbca log tails,
`nls_database_parameters` for `CDB$ROOT` and `FREEPDB1`), plus a summary in `raw/runtime-summary.tsv`.
`--only t0` is a smoke test of the script without a database.

## Files

- `01-size.md` ... `05-docs-origin.md` - one file per claim: command, raw output (shortened, marked), result
- `mail-draft.md` - corrected mail, only evidenced statements
- `collect.sh` - reproduces the collection
- `raw/` - raw output: manifests, `du` diff, file system probe, script diffs, the two new 23.26.4 scripts as
  `.txt` (Oracle UPL, header kept), runtime results. Full script copies and the registry page stay in the work
  directory
