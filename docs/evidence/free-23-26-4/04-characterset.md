# Claim 4 - Character set

Claim in the draft: the documented way to use another character set (a new empty directory with
`ORACLE_CHARACTERSET`) no longer works.

- Date: 2026-11-25 (gate: code), 2026-11-26 (runtime, arm64)
- Images: see `01-size.md` (digests)

## Code (gate)

`runOracle.sh` in 23.26.4.0 calls on the existing-DB path, for SID `FREE` with a `.prebuiltdb` marker:
`configurePrebuiltPdb.sh "${ORACLE_CHARACTERSET:-}"` (`raw/diff-scripts_base_runOracle.sh.orig.txt`).
`configurePrebuiltPdb.sh` (new, `raw/configurePrebuiltPdb.sh-23.26.4.0.txt`) does, if the requested character
set differs from the one in `FREEPDB1`:

```sql
ALTER PLUGGABLE DATABASE "FREEPDB1" CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE "FREEPDB1" OPEN READ WRITE RESTRICTED;
ALTER SESSION SET CONTAINER = "FREEPDB1";
ALTER PLUGGABLE DATABASE CHARACTER SET INTERNAL_USE INTERNAL_CONVERT <charset>;
```

The image therefore does not ignore `ORACLE_CHARACTERSET` - it converts only the PDB `FREEPDB1` in place.
`CDB$ROOT` stays `AL32UTF8`. A failing conversion ends the container start (`|| exit 1`).

Registry page (fetched 2026-11-25): "`ORACLE_CHARACTERSET` is applied only when the Full image creates a fresh
database. It has no effect when `/opt/oracle/oradata` already contains a database." This contradicts the code in
both directions: no fresh database is created, and the variable does take effect on the prebuilt database.

## Runtime (flight, `collect.sh`)

| Test | Setup | Expected | Evidence |
| --- | --- | --- | --- |
| t2 | 23.26.3.0, empty bind dir, `ORACLE_CHARACTERSET=WE8MSWIN1252` | DBCA, CDB and PDB `WE8MSWIN1252` | `raw/rt-t2-23.26.3.0.txt` |
| t2 | 23.26.4.0, same | extraction, CDB `AL32UTF8`; PDB converted or start fails | `raw/rt-t2-23.26.4.0.txt` |

Assumption before t2: `WE8MSWIN1252` is not a superset of `AL32UTF8`; the internal conversion may fail
(ORA-12712) and then stop the container. **Refuted** by t2: the conversion of the freshly extracted `FREEPDB1`
succeeded.

### Runtime results (`nls_database_parameters`)

| Image | Ready after | `CDB$ROOT` | `FREEPDB1` |
| --- | --- | --- | --- |
| 23.26.3.0 | 143 s | `WE8MSWIN1252` | `WE8MSWIN1252` |
| 23.26.4.0 | 31 s | `AL32UTF8` | `WE8MSWIN1252` |

23.26.4.0 log (`raw/rt-t2-23.26.4.0.txt`): `Expanding prebuilt database files.`, then
`Converting FREEPDB1 character set to WE8MSWIN1252.`; the alert log tail shows `FREEPDB1` closed, opened and
`SAVE STATE`.

## Result

- "No longer works": **partly confirmed** (t2). An empty directory with `ORACLE_CHARACTERSET` no longer creates a
  database with that character set; `CDB$ROOT` stays `AL32UTF8`. The undocumented replacement converts only
  `FREEPDB1`, and it works for `WE8MSWIN1252` on the prebuilt PDB. Not tested: other character sets, a second
  start with a different value, PDBs with application data
- Registry documentation and code disagree on `ORACLE_CHARACTERSET`: **confirmed** (quote + code)
