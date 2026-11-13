#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: create_lab_baseline.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.2.0
# Purpose....: Create the guaranteed restore point LAB_BASELINE once, as the
#              last startup hook - after the setup hooks of the first start.
#              'make reset' flashes the database back to it.
# Notes......: - Idempotent: does nothing if LAB_BASELINE exists.
#              - Needs ARCHIVELOG (19c template, Free ENABLE_ARCHIVELOG=true).
#                Sets a recovery area if none is configured.
#              - Called from a sourced startup hook: separate process, its exit
#                does not end the image init.
# Usage......: create_lab_baseline.sh <recovery_area_dir>
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-11-13  oes  Initial release                                    0.2.0
# ------------------------------------------------------------------------------
set -euo pipefail

main() {
    local fra="${1:?recovery area directory missing}"
    mkdir -p "${fra}"
    "${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba <<SQL
WHENEVER SQLERROR EXIT FAILURE
SET SERVEROUTPUT ON FEEDBACK OFF
DECLARE
  l_log v\$database.log_mode%TYPE;
  l_fra v\$parameter.value%TYPE;
  l_rp  NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_rp FROM v\$restore_point WHERE name = 'LAB_BASELINE';
  IF l_rp > 0 THEN
    dbms_output.put_line('INFO: restore point LAB_BASELINE exists');
    RETURN;
  END IF;
  SELECT log_mode INTO l_log FROM v\$database;
  IF l_log <> 'ARCHIVELOG' THEN
    RAISE_APPLICATION_ERROR(-20001, 'NOARCHIVELOG - no LAB_BASELINE, make reset will not work');
  END IF;
  SELECT value INTO l_fra FROM v\$parameter WHERE name = 'db_recovery_file_dest';
  IF l_fra IS NULL THEN
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET db_recovery_file_dest_size = 20G SCOPE=BOTH';
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET db_recovery_file_dest = ''${fra}'' SCOPE=BOTH';
    dbms_output.put_line('INFO: recovery area set to ${fra} (20G)');
  END IF;
  EXECUTE IMMEDIATE 'CREATE RESTORE POINT LAB_BASELINE GUARANTEE FLASHBACK DATABASE';
  dbms_output.put_line('INFO: restore point LAB_BASELINE created');
END;
/
SQL
}

main "$@"
# --- EOF ----------------------------------------------------------------------
