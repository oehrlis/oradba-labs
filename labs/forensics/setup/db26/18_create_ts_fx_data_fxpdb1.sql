-- -----------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
-- -----------------------------------------------------------------------------
--  Name......: 18_create_ts_fx_data_fxpdb1.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026.11.24
--  Revision..: v1.0.0
--  Purpose...: Create the small tablespace FX_DATA (one datafile) in PDB
--              FXPDB1 as object of single-datafile extraction recipes.
--  Notes.....: - Execute as SYSDBA (image setup hook).
--              - No schema and no test data - recipes create what they examine.
-- -----------------------------------------------------------------------------
WHENEVER SQLERROR EXIT SQL.SQLCODE

SET LINESIZE 256 PAGESIZE 1000
SET SERVEROUTPUT ON FEEDBACK ON ECHO OFF TERMOUT ON VERIFY OFF

PROMPT - Switch to PDB FXPDB1
ALTER SESSION SET CONTAINER=FXPDB1;

DEFINE LOG_PREFIX = '18_create_ts_fx_data_fxpdb1'
DEFINE LOG_DIR    = '/opt/oracle/scripts/logs'
@/opt/oracle/common/scripts/define_logging_begin.sql

@/opt/oracle/common/scripts/require_pdb.sql

@/opt/oracle/common/scripts/create_ts_users.sql FX_DATA 10240K

@/opt/oracle/common/scripts/define_logging_end.sql
-- EOF -------------------------------------------------------------------------
