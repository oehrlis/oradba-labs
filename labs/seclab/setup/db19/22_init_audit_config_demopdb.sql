-- oradba-labs hook (pattern: oracle-free-labs config/labdb)
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 256 PAGESIZE 1000
SET SERVEROUTPUT ON FEEDBACK ON ECHO OFF TERMOUT ON VERIFY OFF
PROMPT - Switch to PDB DEMOPDB
ALTER SESSION SET CONTAINER=DEMOPDB;
DEFINE LOG_PREFIX = '22_init_audit_config_demopdb'
DEFINE LOG_DIR    = '/opt/oracle/scripts/logs'
@/opt/oracle/common/scripts/define_logging_begin.sql
@/opt/oracle/common/scripts/require_pdb.sql
@/opt/oracle/common/scripts/init_audit_config.sql
@/opt/oracle/common/scripts/define_logging_end.sql
