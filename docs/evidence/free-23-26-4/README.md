# Oracle Free 23.26.4.0 container image - evidence

This folder collects evidence for the draft mail to Oracle about `container-registry.oracle.com/database/free:23.26.4.0`.
It checks every claim in the draft against `23.26.3.0`. Without evidence, no mail is sent.

- Images, pinned by index digest:
  - `23.26.3.0` `sha256:f988b0c04c4c386cd306a2a914c0d7a9702d83acc31b064a28ad8eb6278a8fba`
  - `23.26.4.0` = `latest` `sha256:f5a1791bf5628fd1a97e07584ff5ac5537da5021c23e70f5083f48c8fcd6476e`
- Registry data is from both architectures. File system and runtime tests ran on arm64 only; amd64 under emulation
  is too slow and was **not** tested
- Status: gate (online, static) done on 2026-11-25. Runtime tests (t1-t6) are still to run, offline

## Results

<!-- markdownlint-disable MD013 MD060 -->
| # | Claim | Result | Evidence | Key figure |
| --- | --- | --- | --- | --- |
| 1 | Compressed size 3.53 -> 1.92 GB (arm64), 3.71 -> 2.11 GB (amd64) | confirmed | `01-size.md` | -1.61 GB arm64, -1.60 GB amd64 |
| 1a | "The 1.6 GB are the seed files" | refuted | `01-size.md` | seed files about 0.39 GB compressed; dnf cache 0.67 GB; prebuilt DB still in the image as tar.gz |
| 2 | `FREE_Database.dbc` + seed files missing | confirmed | `02-dbca-template.md` | templates dir 428 MB -> empty |
| 2a | `runOracle.sh` on an empty dir fails with DBT-10508 | open (t3) | `02-dbca-template.md` | - |
| 3 | Default command `startPrebuilt.sh`, extracts into an empty (mounted) dir | confirmed (config + code) | `03-startup.md` | Cmd changed, new script "Since: September, 2026" |
| 3a | Setup scripts never run with an empty dir | confirmed by code, runtime open (t1) | `03-startup.md` | - |
| 3b | `README.md` / `Dockerfile` missing in the image | confirmed | `03-startup.md` | - |
| 3c | New: a failing startup script stops the container | confirmed by code, runtime open (t6) | `03-startup.md` | `runUserScripts.sh ... \|\| exit $?` |
| 4 | Other character set via empty dir no longer works | open (t2) | `04-characterset.md` | replaced by undocumented PDB-only `INTERNAL_CONVERT` |
| 4a | Registry doc contradicts code on `ORACLE_CHARACTERSET` | confirmed | `04-characterset.md` | - |
| 5 | No release notes, behaviour not documented | confirmed (not found) | `05-docs-origin.md` | registry doc describes 23.26.3; GitHub has none of the new scripts |
<!-- markdownlint-restore -->

Interim assessment (before runtime): the 23.26.4 image is an intended redesign (prebuilt database as tar.gz,
PDB character set conversion, strict startup scripts) with incomplete documentation and a create path that has
no template left. The draft's question "is the build incomplete?" should become "documentation and
`createDB.sh` no longer match the image". The mail draft follows once the runtime results are in.

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
- `collect.sh` - reproduces the collection
- `raw/` - raw output: manifests, `du` diff, file system probe, script diffs, the two new 23.26.4 scripts as
  `.txt` (Oracle UPL, header kept), runtime results. Full script copies and the registry page stay in the work
  directory
