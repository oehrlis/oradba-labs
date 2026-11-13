# Feature probe - does this release carry the feature?

Before building a demo, check whether a release has the feature at all, and what changed between two
releases. `common/scripts/feature_probe.sh` (`make probe`) looks for traces of a feature:

<!-- markdownlint-disable MD013 MD060 -->
| Category | Source | Needs a database? | Shows |
| --- | --- | --- | --- |
| `messages` | `$ORACLE_HOME/rdbms/mesg/oraus.msg` - a message counts if its text, `*Cause` or `*Action` matches | no | error messages shipped with the code |
| `binary` | tokens in `$ORACLE_HOME/bin/oracle` | no | parameter names, kernel functions, dictionary tables |
| `catalog` | `*.sql` / `*.plb` in `$ORACLE_HOME/rdbms/admin` | no | catalog scripts, packages, bug fix scripts |
| `parameters` | `v$parameter` | yes | documented parameters |
| `hidden` | `x$ksppi` (underscore parameters) | yes | hidden parameters |
| `objects` | `dba_objects` (SYS, PUBLIC) | yes | views, packages, tables |
| `columns` | `dba_tab_columns` of `DBA_*` views | yes | new columns |
<!-- markdownlint-restore -->

Image mode (`-i` / `IMAGES=`) reads a local image in a throwaway container - no database start, 2-4 s per
image. Container mode (`-c` / `LAB=`) adds the dictionary of a running lab.

Traces prove that the code is there, not that the feature works in this edition or configuration. For
"it works" run the statement (a syntax error such as `ORA-00922` means "unknown", a functional error
means "known, not configured"), for "it works right" run the demo.

## Usage

```bash
# one or more releases side by side (table at the end)
make probe P='mfa_|_mfa|multi.?factor' IMAGES="container-registry.oracle.com/database/free:23.26.1.0 container-registry.oracle.com/database/free:23.26.2.0 container-registry.oracle.com/database/free:latest"
# what changed between two releases
make probe P='mfa_|_mfa|multi.?factor' IMAGES="container-registry.oracle.com/database/free:23.26.2.0 container-registry.oracle.com/database/free:latest" DIFF=1
# running lab, files + dictionary
make probe P='mfa_|_mfa' LAB=seclab
# sorted list for your own diff
diff <(common/scripts/feature_probe.sh --list -i IMAGE_A 'mfa') <(common/scripts/feature_probe.sh --list -i IMAGE_B 'mfa')
```

`P` is a case-insensitive extended regex. Be specific for the binary: `mfa` alone also matches kernel
symbols like `ksfdomfat`; `mfa_|_mfa|multi.?factor` does not.

## Example - MFA across 26ai Free releases (2026-11-13)

<!-- markdownlint-disable MD013 MD060 -->
| Release | Messages | Binary | Catalog | Reading |
| --- | --- | --- | --- | --- |
| 23.26.1.0 | 7 | 16 | 0 | messages and kernel parts present, PL/SQL layer missing (`catmfa.sql`, `DBMS_MFA*`, `mfa_config$`) - an attempt ends in an error, not in a working setup |
| 23.26.2.0 | 7 | 22 | 14 | MFA complete: `DBMS_MFA`, `DBMS_MFA_ADMIN`, `DBMS_MFA_UTL`, `mfa_user$`, `mfa_config$` |
| 23.26.3.0 (`latest`) | 7 | 25 | 16 | extended: `mfa_server_certificate`, `mfa_wallet_location` |
| 19.23 / 19.27 (`trivadis/ora_db`) | 0 | 6 | 0 | no MFA |
<!-- markdownlint-restore -->

On 23.26.3 with a running lab the dictionary adds 6 `mfa_*` parameters and the packages
`DBMS_MFA`, `DBMS_MFA_ADMIN`, `DBMS_MFA_UTL`.

## Example diff - 23.26.2.0 against `latest` (23.26.3.0)

MFA:

```text
== diff: A = container-registry.oracle.com/database/free:23.26.2.0 (23.26.2.0.0), B = container-registry.oracle.com/database/free:latest (23.26.3.0.0)
  messages   only A: 0, only B: 0
  binary     only A: 0, only B: 3
             + B kzfdpupdatemultifactorauth
             + B mfa_server_certificate
             + B mfa_wallet_location
  catalog    only A: 0, only B: 2
             + B bug_39281758_apply.sql
             + B rxsviews.sql
```

Deep Data Security (`P='data.?grant|end.?user|deep.?sec'`), shortened:

```text
  messages   only A: 1, only B: 6
             - A 52554, 00000, "The predicate for the data grant %s.%s is invalid."
             + B 52542, 00000, "The end user with same external name already exists"
             + B 52543, 00000, "End user with second factor requires password authentication."
             + B 52544, 00000, "Cannot add second factor without password authentication."
             + B 52554, 00000, "The predicate for the data grant %s.%s is invalid.\n%s"
             + B 52571, 00000, "ALL COLUMNS EXCEPT is not supported for the parent privilege list"
             + B 52608, 00000, "The end-user name was invalid or missing."
  binary     only A: 1, only B: 9
             + B kzxdhandledeepseccolumnpriv
             + B kzxsfsplsqlattachendusersession
             + B kzxsfsplsqldetachendusersession
             ...
  catalog    only A: 0, only B: 13
```

Reading: 23.26.3 adds end-user second factor, column-level Deep Sec privileges and end-user session
attach/detach; message 52554 gains a detail line - a demo that shows error texts must run on the
release of the talk. SQL Firewall (`P='sql_firewall'`) is identical in both - the diff does not invent
differences.
