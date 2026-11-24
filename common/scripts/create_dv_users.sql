--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: create_dv_users.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-24
--  Revision..: v0.1.0
--  Purpose...: Create the common Database Vault accounts C##DV_OWNER and
--              C##DV_ACCTMGR in CDB$ROOT (idempotent). Does NOT configure DV.
--  Notes.....: Run as SYSDBA in CDB$ROOT. Args: &1 owner password, &2 account
--              manager password (run_sql_script.sh -e DV_OWNER_PWD -e DV_ACCTMGR_PWD)
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET VERIFY OFF
DEFINE dv_owner_pwd = "&1"
DEFINE dv_acctmgr_pwd = "&2"

BEGIN
  FOR u IN (SELECT username FROM dba_users WHERE username IN ('C##DV_OWNER','C##DV_ACCTMGR')) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
  END LOOP;
END;
/
CREATE USER c##dv_owner IDENTIFIED BY "&&dv_owner_pwd" CONTAINER=ALL;
GRANT CREATE SESSION, SET CONTAINER TO c##dv_owner CONTAINER=ALL;
CREATE USER c##dv_acctmgr IDENTIFIED BY "&&dv_acctmgr_pwd" CONTAINER=ALL;
GRANT CREATE SESSION, SET CONTAINER TO c##dv_acctmgr CONTAINER=ALL;

UNDEFINE dv_owner_pwd dv_acctmgr_pwd
-- EOF -------------------------------------------------------------------------
