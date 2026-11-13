--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: reset.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 2 - remove everything setup.sql, solution.sql
--              and the live solution created: NOAUDIT + DROP AUDIT POLICY for
--              every HMB_* policy, NOAUDIT for the traditional decoy, accounts.
--  Notes.....: - Based on oracle-free-labs config/common/scripts/
--                seclab_s07_audit_gaps.sql (NOAUDIT with the matching BY clause
--                derived from AUDIT_UNIFIED_ENABLED_POLICIES).
--              - Run as SYSDBA in CDB$ROOT of seclab-db19 or seclab-db26.
--              - Pairs: solution.sql enables
--                  AUDIT POLICY hmb_loc_priv_usr_act_pol BY USERS WITH GRANTED ROLES dba
--                  AUDIT POLICY hmb_loc_crit_priv_use_pol
--                this script runs the matching NOAUDIT and DROP AUDIT POLICY
--                explicitly, then sweeps any other HMB_* policy the live solution
--                created (other names, other BY clauses).
--              - Policies NOT named HMB_* that are not Oracle-supplied are only
--                reported (with the commands), never dropped blindly.
--              - Audit records stay in the trail on purpose (no purge of
--                evidence). 'make reset' (flashback) removes them with the rest
--                of the database content.
--              - Ends with an assertion: no HMB_* policy may remain.
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

WHENEVER SQLERROR EXIT SQL.SQLCODE

SET FEEDBACK OFF
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 160 PAGESIZE 100

BEGIN
  IF sys_context('userenv', 'con_name') <> 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20200, 'run reset.sql in CDB$ROOT as SYSDBA');
  END IF;
END;
/

ALTER SESSION SET CONTAINER = DEMOPDB;

PROMPT - NOAUDIT + DROP AUDIT POLICY for the policies of solution.sql
DECLARE
  PROCEDURE run(p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    dbms_output.put_line('- ' || p_sql);
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('- ' || p_sql || ' -> ' || SQLERRM);
  END run;
BEGIN
  run('NOAUDIT POLICY hmb_loc_priv_usr_act_pol BY USERS WITH GRANTED ROLES dba');
  run('NOAUDIT POLICY hmb_loc_crit_priv_use_pol');
  run('DROP AUDIT POLICY hmb_loc_priv_usr_act_pol');
  run('DROP AUDIT POLICY hmb_loc_crit_priv_use_pol');
END;
/

PROMPT - Sweep: NOAUDIT every remaining HMB_* enablement with its own BY clause
DECLARE
  l_sql VARCHAR2(512);
BEGIN
  FOR r IN (SELECT policy_name, enabled_option, entity_name
              FROM audit_unified_enabled_policies
             WHERE policy_name LIKE 'HMB\_%' ESCAPE '\') LOOP
    l_sql := 'NOAUDIT POLICY ' || r.policy_name;
    IF r.enabled_option = 'BY USER' AND r.entity_name <> 'ALL USERS' THEN
      l_sql := l_sql || ' BY "' || r.entity_name || '"';
    ELSIF r.enabled_option = 'BY GRANTED ROLE' THEN
      l_sql := l_sql || ' BY USERS WITH GRANTED ROLES "' || r.entity_name || '"';
    END IF;
    -- EXCEPT USER and BY USER 'ALL USERS': the plain NOAUDIT removes the enablement
    BEGIN
      EXECUTE IMMEDIATE l_sql;
      dbms_output.put_line('- ' || l_sql);
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('- FAILED: ' || l_sql || ' -> ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT - Sweep: DROP AUDIT POLICY for every remaining HMB_* policy
BEGIN
  FOR r IN (SELECT DISTINCT policy_name FROM audit_unified_policies
             WHERE policy_name LIKE 'HMB\_%' ESCAPE '\') LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP AUDIT POLICY ' || r.policy_name;
      dbms_output.put_line('- DROP AUDIT POLICY ' || r.policy_name);
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('- FAILED: DROP AUDIT POLICY ' || r.policy_name || ' -> ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT - Other custom policies (not HMB_*, not Oracle-supplied): report only
-- LAB-CHECK: AUDIT_UNIFIED_POLICIES.ORACLE_SUPPLIED exists on 19.27 and 23.26.3
BEGIN
  FOR r IN (SELECT DISTINCT policy_name FROM audit_unified_policies
             WHERE oracle_supplied = 'NO'
               AND policy_name NOT LIKE 'HMB\_%' ESCAPE '\') LOOP
    dbms_output.put_line('WARN: custom policy ' || r.policy_name || ' left in place - if the live '
      || 'solution created it: NOAUDIT POLICY ' || r.policy_name || ' <same BY clause>; DROP AUDIT POLICY '
      || r.policy_name || ';');
  END LOOP;
END;
/

PROMPT - NOAUDIT for the traditional decoy of setup.sql
BEGIN
  EXECUTE IMMEDIATE 'NOAUDIT SELECT ANY TABLE BY hmb_dba';
  dbms_output.put_line('- NOAUDIT SELECT ANY TABLE BY hmb_dba');
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('- NOAUDIT SELECT ANY TABLE BY hmb_dba -> ' || SQLERRM);
END;
/

PROMPT - Drop the demo accounts
BEGIN
  FOR r IN (SELECT username FROM dba_users WHERE username IN ('HMB_DBA', 'HMB_APP', 'HMB_TMP')) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || r.username || ' CASCADE';
    dbms_output.put_line('- dropped ' || r.username);
  END LOOP;
END;
/

PROMPT - Assertion: no HMB_* policy left
DECLARE
  l_cnt PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM audit_unified_policies WHERE policy_name LIKE 'HMB\_%' ESCAPE '\';
  IF l_cnt > 0 THEN
    RAISE_APPLICATION_ERROR(-20203, l_cnt || ' HMB_* audit policy row(s) left - see the FAILED lines above');
  END IF;
  dbms_output.put_line('- OK: no HMB_* audit policy in DEMOPDB');
END;
/

ALTER SESSION SET CONTAINER = CDB$ROOT;

PROMPT - CDB$ROOT: custom policies (a live solution may have used CONTAINER=ALL) - report only
BEGIN
  FOR r IN (SELECT DISTINCT policy_name, common FROM audit_unified_policies
             WHERE oracle_supplied = 'NO') LOOP
    dbms_output.put_line('WARN: CDB$ROOT policy ' || r.policy_name || ' (common=' || r.common
      || ') - if the live solution created it: NOAUDIT POLICY ' || r.policy_name
      || ' <same BY clause>; DROP AUDIT POLICY ' || r.policy_name || ';');
  END LOOP;
END;
/
-- EOF -------------------------------------------------------------------------
