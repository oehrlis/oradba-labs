#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: enable_unified_audit.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.1.0
# Purpose....: Switch the database to Unified Auditing pure mode (uniaud_on).
# Notes......: Runs inside the DB container as oracle. Idempotent: relinks and
#              restarts only if v$option 'Unified Auditing' is FALSE.
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-11-13  oes  Initial release                                    0.1.0
# ------------------------------------------------------------------------------
set -euo pipefail

# ------------------------------------------------------------------------------
# Function: ua_value
# Purpose.: Current value of v$option 'Unified Auditing'
# Output..: TRUE or FALSE
# ------------------------------------------------------------------------------
ua_value() {
    "${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba <<'SQL' | tr -d '[:space:]'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT value FROM v$option WHERE parameter = 'Unified Auditing';
SQL
}

main() {
    local before
    before=$(ua_value)
    if [[ "${before}" == "TRUE" ]]; then
        echo "INFO: Unified Auditing pure mode already active in ${ORACLE_SID}"
        return 0
    fi
    command -v make >/dev/null || {
        echo "ERROR: Unified Auditing is ${before} and 'make' is missing - cannot relink ${ORACLE_SID}" >&2
        return 1
    }
    echo "INFO: relink ${ORACLE_SID} with uniaud_on (was ${before})"
    "${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba <<<"SHUTDOWN IMMEDIATE"
    make -C "${ORACLE_HOME}/rdbms/lib" -f ins_rdbms.mk uniaud_on ioracle >/dev/null
    "${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba <<<"STARTUP"
    echo "INFO: Unified Auditing in ${ORACLE_SID}: $(ua_value)"
}

main "$@"
# --- EOF ----------------------------------------------------------------------
