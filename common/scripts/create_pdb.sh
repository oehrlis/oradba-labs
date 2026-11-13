#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: create_pdb.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.1.0
# Purpose....: Create a PDB from PDB$SEED unless it exists, open it, save state.
# Notes......: Runs inside the DB container. Wraps common/sql/create_pdb.sql.
# Usage......: create_pdb.sh <pdb>
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-11-13  oes  Initial release                                    0.1.0
# ------------------------------------------------------------------------------
set -euo pipefail

main() {
    local pdb="${1:?PDB name missing}"
    "${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba <<SQL
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE
@/opt/oradba-labs/common/sql/create_pdb.sql ${pdb}
-- a PDB from PDB\$SEED has no USERS tablespace (Free) - create it as default
ALTER SESSION SET CONTAINER = ${pdb};
DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM dba_tablespaces WHERE tablespace_name = 'USERS';
  IF l_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE TABLESPACE users DATAFILE SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 4G';
    dbms_output.put_line('- tablespace USERS created in ${pdb}');
  END IF;
  EXECUTE IMMEDIATE 'ALTER DATABASE DEFAULT TABLESPACE users';
END;
/
EXIT
SQL
}

main "$@"
# --- EOF ----------------------------------------------------------------------
