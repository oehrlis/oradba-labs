--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: setup.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 2 - starting point: a privileged account
--              (HMB_DBA, role DBA) and an app account (HMB_APP) in DEMOPDB
--              without any privileged-user audit policy, plus one traditional
--              AUDIT statement as the "it is already audited, isn't it?" decoy.
--  Notes.....: - Based on oracle-free-labs config/common/scripts/
--                seclab_s07_audit_gaps.sql (incomplete audit coverage as the
--                starting point, NOAUDIT-before-AUDIT pattern).
--              - Run as SYSDBA in CDB$ROOT of seclab-db19 or seclab-db26.
--              - &1 demo password for HMB_DBA / HMB_APP, default
--                HmbDemo_Lab_Only_UA (lab only, letters/digits/underscore).
--              - The decoy: AUDIT SELECT ANY TABLE BY hmb_dba is traditional
--                syntax. In Unified Auditing pure mode it writes no record.
--                It is paired with NOAUDIT in reset.sql.
--                verified 2026-11-13: 19.27 accepts the statement silently (it
--                shows up in DBA_STMT/PRIV_AUDIT_OPTS); 23.26.3 rejects it with
--                ORA-46401 - both are reported, neither stops the setup.
--              - Stops if an HMB_* audit policy still exists: run reset.sql.
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

WHENEVER SQLERROR EXIT SQL.SQLCODE

SET FEEDBACK OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 100
COLUMN 1 NEW_VALUE 1 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
DEFINE hmb_pwd = &1 HmbDemo_Lab_Only_UA

PROMPT - Pre-checks: CDB$ROOT, Unified Auditing pure mode
DECLARE
  l_ua v$option.value%TYPE;
BEGIN
  IF sys_context('userenv', 'con_name') <> 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20200, 'run setup.sql in CDB$ROOT as SYSDBA');
  END IF;
  SELECT value INTO l_ua FROM v$option WHERE parameter = 'Unified Auditing';
  IF l_ua <> 'TRUE' THEN
    RAISE_APPLICATION_ERROR(-20201, 'Unified Auditing pure mode is not active - seclab expects it');
  END IF;
END;
/

ALTER SESSION SET CONTAINER = DEMOPDB;
-- DBMS_OUTPUT state is per container: re-enable after every switch
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT - Leftovers from an earlier run?
DECLARE
  l_cnt PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM audit_unified_policies
   WHERE policy_name LIKE 'HMB\_%' ESCAPE '\';
  IF l_cnt > 0 THEN
    RAISE_APPLICATION_ERROR(-20202, l_cnt || ' HMB_* audit polic(y/ies) still exist - run reset.sql first');
  END IF;
  FOR r IN (SELECT username FROM dba_users WHERE username IN ('HMB_DBA', 'HMB_APP', 'HMB_TMP')) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || r.username || ' CASCADE';
    dbms_output.put_line('- dropped ' || r.username);
  END LOOP;
END;
/

PROMPT - HMB_DBA: the new colleague with role DBA (privileged user)
CREATE USER hmb_dba IDENTIFIED BY "&&hmb_pwd" DEFAULT TABLESPACE users;
GRANT dba TO hmb_dba;

PROMPT - HMB_APP: application account, CREATE SESSION + read on TVD_HR.EMPLOYEES
CREATE USER hmb_app IDENTIFIED BY "&&hmb_pwd" DEFAULT TABLESPACE users;
GRANT CREATE SESSION TO hmb_app;
GRANT SELECT ON tvd_hr.employees TO hmb_app;

PROMPT - Decoy: traditional AUDIT statement (no effect in pure mode, NOAUDIT in reset.sql)
BEGIN
  EXECUTE IMMEDIATE 'AUDIT SELECT ANY TABLE BY hmb_dba BY ACCESS';
  dbms_output.put_line('- AUDIT SELECT ANY TABLE BY hmb_dba accepted (traditional syntax, writes nothing)');
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('- traditional AUDIT rejected on this release: ' || SQLERRM);
END;
/

PROMPT - Starting point: enabled audit policies in DEMOPDB (Oracle defaults only)
COLUMN policy_name    FORMAT A32
COLUMN enabled_option FORMAT A16
COLUMN entity_name    FORMAT A20
SELECT policy_name, enabled_option, entity_name, success, failure
  FROM audit_unified_enabled_policies
 ORDER BY policy_name;

UNDEFINE hmb_pwd
-- EOF -------------------------------------------------------------------------
