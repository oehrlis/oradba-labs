----------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
----------------------------------------------------------------------------
--  Name......: open_pdbs.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: Open all PDBs read write and save the state (startup hook).
--  Notes.....: Run as SYSDBA in CDB$ROOT. ORA-65019 (already open) is fine.
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
----------------------------------------------------------------------------
ALTER PLUGGABLE DATABASE ALL OPEN READ WRITE;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;
-- EOF ---------------------------------------------------------------------
