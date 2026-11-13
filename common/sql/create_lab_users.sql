----------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
----------------------------------------------------------------------------
--  Name......: create_lab_users.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: Create the standard lab accounts in the current PDB:
--              LAB_ADMIN (DBA in the PDB, runs demo setup/reset scripts)
--              LAB_USER  (CREATE SESSION only - the low-privileged start)
--  Notes.....: - Run as SYSDBA with the container set to the PDB
--                (common/scripts/lab_sql.sh).
--              - Expects DEFINE lab_admin_pwd and lab_user_pwd (from lab.env).
--              - Rerunnable: existing accounts are dropped and recreated.
--              - Demo-specific accounts (e.g. LOWPRIV_DEMO) belong to the
--                demo's own setup script, not to the lab.
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
----------------------------------------------------------------------------
SET VERIFY OFF
BEGIN
  FOR u IN (SELECT username FROM dba_users WHERE username IN ('LAB_ADMIN','LAB_USER')) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
  END LOOP;
END;
/
CREATE USER lab_admin IDENTIFIED BY "&&lab_admin_pwd"
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
GRANT dba TO lab_admin;

CREATE USER lab_user IDENTIFIED BY "&&lab_user_pwd"
  DEFAULT TABLESPACE users;
GRANT CREATE SESSION TO lab_user;

UNDEFINE lab_admin_pwd lab_user_pwd
-- EOF ---------------------------------------------------------------------
