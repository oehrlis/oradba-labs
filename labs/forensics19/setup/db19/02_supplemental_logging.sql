-- -----------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
-- -----------------------------------------------------------------------------
--  Name......: 02_supplemental_logging.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026.11.24
--  Revision..: v1.0.0
--  Purpose...: Enable minimal supplemental logging in CDB$ROOT so that
--              LogMiner shows complete row changes (artefact analysis recipes).
--  Notes.....: - Execute as SYSDBA (image setup hook).
--              - No schema and no test data - recipes create what they examine.
-- -----------------------------------------------------------------------------
WHENEVER SQLERROR EXIT SQL.SQLCODE

SET LINESIZE 256 PAGESIZE 1000
SET SERVEROUTPUT ON FEEDBACK ON ECHO OFF TERMOUT ON VERIFY OFF

DEFINE LOG_PREFIX = '02_supplemental_logging'
DEFINE LOG_DIR    = '/opt/oracle/scripts/logs'
@/opt/oracle/common/scripts/define_logging_begin.sql

@/opt/oracle/common/scripts/require_cdb_root.sql

PROMPT - Enable minimal supplemental logging
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

SELECT supplemental_log_data_min, log_mode FROM v$database;

@/opt/oracle/common/scripts/define_logging_end.sql
-- EOF -------------------------------------------------------------------------
