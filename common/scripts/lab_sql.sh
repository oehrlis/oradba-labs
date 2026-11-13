#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: lab_sql.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.1.0
# Purpose....: Run a SQL script as SYSDBA in a container (CDB$ROOT or a PDB).
# Notes......: Runs inside the DB container. Values for SQL*Plus DEFINEs come from
#              environment variables named on the command line and reach
#              sqlplus via stdin - never via argv, never echoed (VERIFY OFF).
# Usage......: lab_sql.sh <CDB$ROOT|pdb> <script.sql> [ENV_VAR ...]
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-11-13  oes  Initial release                                    0.1.0
# ------------------------------------------------------------------------------
set -euo pipefail

main() {
    local container="${1:?container (CDB\$ROOT or PDB name) missing}"
    local script="${2:?SQL script missing}"
    shift 2
    [[ -f "${script}" ]] || {
        echo "ERROR: ${script} not found" >&2
        return 1
    }
    local defines="" var
    for var in "$@"; do
        [[ -n "${!var:-}" ]] || {
            echo "ERROR: environment variable ${var} is empty - set it in lab.env" >&2
            return 1
        }
        defines+="DEFINE ${var,,} = \"${!var}\""$'\n'
    done
    echo "INFO: ${script##*/} in ${container}"
    "${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba <<SQL
WHENEVER SQLERROR EXIT FAILURE
SET VERIFY OFF ECHO OFF FEEDBACK ON SERVEROUTPUT ON
DECLARE
  l_mode v\$pdbs.open_mode%TYPE;
BEGIN
  IF UPPER('${container}') <> 'CDB\$ROOT' THEN
    SELECT open_mode INTO l_mode FROM v\$pdbs WHERE name = UPPER('${container}');
    IF l_mode <> 'READ WRITE' THEN
      EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ${container} OPEN READ WRITE';
      EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ${container} SAVE STATE';
    END IF;
  END IF;
END;
/
ALTER SESSION SET CONTAINER = ${container};
${defines}
@${script}
EXIT
SQL
}

main "$@"
# --- EOF ----------------------------------------------------------------------
