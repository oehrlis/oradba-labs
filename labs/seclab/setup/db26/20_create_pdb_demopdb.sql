-- oradba-labs hook (pattern: oracle-free-labs config/labdb)
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 256 PAGESIZE 1000
SET SERVEROUTPUT ON FEEDBACK ON ECHO OFF TERMOUT ON VERIFY OFF
DEFINE LOG_PREFIX = '20_create_pdb_demopdb'
DEFINE LOG_DIR    = '/opt/oracle/scripts/logs'
@/opt/oracle/common/scripts/define_logging_begin.sql
@/opt/oracle/common/scripts/require_cdb_root.sql
@/opt/oracle/common/scripts/create_pdb.sql DEMOPDB
@/opt/oracle/common/scripts/define_logging_end.sql
