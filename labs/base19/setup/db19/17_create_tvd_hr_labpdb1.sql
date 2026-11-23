-- -----------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
-- -----------------------------------------------------------------------------
--  Name......: 17_create_tvd_hr_labpdb1.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026.11.23
--  Revision..: v1.0.0
--  Purpose...: Create the TVD_HR sample schema (and TVD_HR_SEC) in PDB LABPDB1
--              (common script create_tvd_hr.sql) - the HR sample on both versions.
--  Notes.....: - Execute as SYSDBA.
--              - Shows runtime messages (e.g. "Session altered.") and PROMPTs,
--                but does not echo SQL or inline comments.
--              - Logs are written to /opt/oracle/scripts/log (mounted writable).
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
-- -----------------------------------------------------------------------------

-- Fail fast in automation ------------------------------------------------------
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- SQL*Plus formatting ----------------------------------------------------------
-- Show results + PROMPTs, but do not echo SQL text or comments.
SET LINESIZE 256 PAGESIZE 1000
SET SERVEROUTPUT ON FEEDBACK ON ECHO OFF TERMOUT ON VERIFY OFF

PROMPT - Switch to PDB LABPDB1
ALTER SESSION SET CONTAINER=LABPDB1;

-- Begin logging ---------------------------------------------------------------
DEFINE LOG_PREFIX = '17_create_tvd_hr_labpdb1'
DEFINE LOG_DIR    = '/opt/oracle/scripts/logs'
@/opt/oracle/common/scripts/define_logging_begin.sql

-- Require we are in a PDB (not CDB$ROOT) -------------------------------------
@/opt/oracle/common/scripts/require_pdb.sql

-- Create TVD_HR -------------------------------------------------------------
@/opt/oracle/common/scripts/create_tvd_hr.sql

-- End logging -----------------------------------------------------------------
@/opt/oracle/common/scripts/define_logging_end.sql
-- EOF -------------------------------------------------------------------------
