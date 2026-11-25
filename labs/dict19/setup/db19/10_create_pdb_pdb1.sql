--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: 10_create_pdb_pdb1.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026.11.25
--  Revision..: v1.0.0
--  Purpose...: dict19 - create PDB1 from PDB$SEED (the trivadis/ora_db image
--              creates only the CDB), so the snapshot covers root + one PDB
--  Notes.....: Must be executed as SYSDBA connected to CDB$ROOT; no logging
--              include (single-use lab, no log volume)
--  Reference.: labs/base19/setup/db19/10_create_pdb_labpdb1.sql
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 256 PAGESIZE 1000 SERVEROUTPUT ON FEEDBACK ON ECHO OFF VERIFY OFF
@/opt/oracle/common/scripts/require_cdb_root.sql
@/opt/oracle/common/scripts/create_pdb.sql PDB1
-- EOF -------------------------------------------------------------------------
