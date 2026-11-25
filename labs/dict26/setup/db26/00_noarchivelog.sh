#!/usr/bin/env bash
# oradba-labs dict26 setup hook: switch the database to NOARCHIVELOG - a single-use
# snapshot lab needs no archived redo (the Free image's prebuilt database has it on).
set -euo pipefail
sqlplus -s -L / as sysdba <<'SQL'
WHENEVER SQLERROR EXIT FAILURE
SHUTDOWN IMMEDIATE
STARTUP MOUNT
ALTER DATABASE NOARCHIVELOG;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;
SQL
