# Claim 5 - Documentation and origin

Question: is the new behaviour announced or documented anywhere? If yes, it is not a bug, and the mail becomes
documentation feedback or is dropped.

- Date: 2026-11-25, registry page fetched 2026-11-25T13:28:03Z and again 13:36:25Z (quoted lines unchanged)
- URL: <https://container-registry.oracle.com/ords/ocr/ba/database/free> (fetched with curl and a cookie jar; the
  full text stays out of the repo, line numbers refer to the text version in the work directory)

## Registry page - relevant sentences (verbatim)

- Line 18: "Both images use Oracle Linux as their base and include a prebuilt database."
- Line 403: "`ORACLE_CHARACTERSET` is applied only when the Full image creates a fresh database. It has no effect
  when `/opt/oracle/oradata` already contains a database. Use a new empty data volume for a different character
  set."
- Line 433: "To use a character set other than the default, start Full with a new empty host directory. The empty
  directory causes a new database setup, so startup can take approximately ten minutes or longer."
- Line 484: "A named volume survives container removal. It is populated with the image's prebuilt database when
  first mounted, so startup is normally fast."
- Line 503: "An existing host directory containing database files is reused. An empty host directory hides the
  prebuilt database at `/opt/oracle/oradata` and starts a new database setup, which can take approximately ten
  minutes or longer depending on the host."
- Line 552: "Setup scripts do not run when the image reuses its prebuilt database. They run when an empty data
  directory causes a new database setup. Startup scripts run after startup in both cases."

The page describes the 23.26.3 behaviour (empty host directory -> new database). It does not mention
`startPrebuilt.sh`, `prebuilt-oradata.tar.gz`, the PDB character set conversion or failing startup scripts. It has
no release notes or change history section.

## Tag list (registry page, first page of the table)

| Tag | arm64 | amd64 | Pushed |
| --- | --- | --- | --- |
| `latest`, `23.26.4.0`, `23.26.4.0-<arch>` | 1.78 GB | 1.96 GB | 5 weeks ago |
| `latest-lite`, `23.26.4.0-lite`, `23.26.4.0-lite-<arch>` | 813.55 MB | 844.94 MB | 5 weeks ago |
| `23.26.3.0`, `23.26.3.0-lite` | 3.28 GB / 819.38 MB | (next page) | 5 months ago |

Sizes as shown by the registry (GiB/MiB). `-lite` is the documented small variant: PDB name configurable, no
character set change, several features unsupported (page section "Lite image limitations"). It is not an
alternative for the labs. There is no 23.26.4 Full tag other than `23.26.4.0` / `latest`. Index digest of
`23.26.4.0` = `latest` = `sha256:f5a1791b...` (`raw/index-digests.txt`).

## Image content

`/opt/oracle/README.md` and `/opt/oracle/Dockerfile`: present in 23.26.3.0, missing in 23.26.4.0
(`raw/fs-probe-local.txt`).

## oracle/docker-images on GitHub (2026-11-25, `gh api`)

- Code search `startPrebuilt`, `configurePrebuiltPdb`, `prebuilt-oradata`: 0 results each
- Issues with `23.26.4` or `prebuilt free` since 2026-09-01: 0 results
- Last commits under `OracleDatabase/SingleInstance`: 2026-10-20 "Remove Retired Versions (#3148)", 2026-09-18,
  2026-09-16, 2026-09-09, 2026-09-02 "Sync GDD CMAN RAC SIDB latest (#3119)"
- `dockerfiles/23.26.0/Containerfile.free`: `FROM oraclelinux:8`, `CMD ... $SCRIPT_BASE_DIR/$RUN_FILE` - the public
  build is still the 23.26.3 design
- `dockerfiles/23.26.0/runOracle.sh` and `runUserScripts.sh` (last change 2026-09-02) do not contain the
  23.26.4 changes (`configurePrebuiltPdb.sh`, startup `|| exit $?`)

## Web search (2026-11-25)

Searches for release notes of the 23.26.4 container image and for posts by Gerald Venzl found the RU 23.26.4
feature notes (database, not the image) and the Oracle Free download page with 23.26.4 RPMs. No note on the
container image, `startPrebuilt.sh` or the removed template was found. Not searched: Oracle forums, X/LinkedIn
posts.

## Result

- New behaviour announced or documented: **not found** - registry documentation describes the old behaviour, the
  public sources on GitHub do not contain the new scripts, no release notes
- The scripts are deliberate work (new files with author and "Since: September, 2026", character set
  conversion, startup failure handling) - a pure build accident is unlikely. More likely: an intended redesign
  whose documentation and template cleanup are incomplete (assumption)
- Consequence for the mail: not "is the build incomplete?", but "the registry documentation and the
  `createDB.sh` path no longer match the new image" - documentation feedback plus the broken create path
