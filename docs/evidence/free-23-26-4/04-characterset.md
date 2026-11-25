# Claim 4 - Character set

Claim in the draft: the documented way to use another character set (a new empty directory with
`ORACLE_CHARACTERSET`) no longer works.

- Date: 2026-11-25 (gate: code; flight: runtime)
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

Assumption (to be checked in t2): `WE8MSWIN1252` is not a superset of `AL32UTF8`; the internal conversion may
fail (ORA-12712) and then stop the container.

## Result

- "No longer works": **open** - the documented mechanism (new database with this character set) is gone
  (confirmed by code reading), but there is a replacement (PDB-only conversion) that is not documented. The result
  depends on t2
- Registry documentation and code disagree on `ORACLE_CHARACTERSET`: **confirmed** (quote + code)
