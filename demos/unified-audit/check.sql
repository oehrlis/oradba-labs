--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: check.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 2 - what the audience sees: audit config,
--              traditional leftovers, fresh activity of HMB_DBA and HMB_APP,
--              and what the unified audit trail recorded for it.
--  Notes.....: - Based on ora-db-audit-eng sql/aud_policies_show_aud.sql
--                (policy view join) and aud_critprivs_show_aud.sql (trail query).
--              - Run as SYSDBA in CDB$ROOT of seclab-db19 or seclab-db26.
--              - Run it before and after solution.sql: before, the SELECT on
--                TVD_HR.EMPLOYEES by HMB_DBA leaves no record (only the Oracle
--                default ORA_SECURECONFIG catches CREATE/DROP USER); after, the
--                HMB_* policies show up in UNIFIED_AUDIT_POLICIES.
--              - Section 3 logs in through the listener (EZConnect
--                localhost:1521/demopdb.<db_domain>). verified 2026-11-13: both DBs
--                register only demopdb.oradba.ch, plain DEMOPDB gives ORA-12514 -
--                the service is derived from db_domain below.
--              - No WHENEVER SQLERROR EXIT: a failing section must not hide the
--                rest (e.g. traditional audit views on 26ai).
--              - &1 demo password, default HmbDemo_Lab_Only_UA (lab only).
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

SET FEEDBACK OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
SET LINESIZE 200 PAGESIZE 100
COLUMN 1 NEW_VALUE 1 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
DEFINE hmb_pwd = &1 HmbDemo_Lab_Only_UA

COLUMN policy_name     FORMAT A32
COLUMN enabled_option  FORMAT A16
COLUMN entity_name     FORMAT A20
COLUMN user_name       FORMAT A10
COLUMN audit_option    FORMAT A20
COLUMN privilege       FORMAT A20
COLUMN event_time      FORMAT A19
COLUMN dbusername      FORMAT A10
COLUMN action_name     FORMAT A16
COLUMN object          FORMAT A20
COLUMN sys_priv        FORMAT A18
COLUMN policies        FORMAT A80
COLUMN rc              FORMAT 99999
COLUMN records         FORMAT 99999
COLUMN hmb_svc         NEW_VALUE hmb_svc NOPRINT

-- listener service of DEMOPDB: the service name carries db_domain (oradba.ch)
SELECT 'demopdb' || NVL2(value, '.' || value, '') AS hmb_svc
  FROM v$parameter WHERE name = 'db_domain';

ALTER SESSION SET CONTAINER = DEMOPDB;
-- DBMS_OUTPUT state is per container: re-enable after every switch
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT == 1. Enabled audit policies in DEMOPDB (expected: BY GRANTED ROLE, not ALL USERS for DBA)
SELECT policy_name, enabled_option, entity_name, success, failure
  FROM audit_unified_enabled_policies
 ORDER BY CASE WHEN policy_name LIKE 'HMB\_%' ESCAPE '\' THEN 0 ELSE 1 END, policy_name;

PROMPT == 2. Traditional audit options - configured, but pure mode ignores them
-- verified 2026-11-13: both views exist on 19.27 and 23.26.3; on 23.26.3 they
-- stay empty because setup.sql's traditional AUDIT is rejected (ORA-46401)
SELECT user_name, audit_option, success, failure FROM dba_stmt_audit_opts WHERE user_name LIKE 'HMB\_%' ESCAPE '\';
SELECT user_name, privilege, success, failure FROM dba_priv_audit_opts WHERE user_name LIKE 'HMB\_%' ESCAPE '\';

PROMPT == 3. Fresh activity: HMB_DBA (privileged) and HMB_APP (application)
PROMPT - HMB_DBA: read HR data via SELECT ANY TABLE, create and drop an account
CONNECT hmb_dba/"&&hmb_pwd"@//localhost:1521/&&hmb_svc
SELECT COUNT(*) AS employees FROM tvd_hr.employees;
CREATE USER hmb_tmp NO AUTHENTICATION;
DROP USER hmb_tmp;
PROMPT - HMB_APP: read HR data via object grant (no privileged-user policy applies)
CONNECT hmb_app/"&&hmb_pwd"@//localhost:1521/&&hmb_svc
SELECT COUNT(*) AS employees FROM tvd_hr.employees;
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = DEMOPDB;
SET SERVEROUTPUT ON SIZE UNLIMITED

-- 19c writes immediately; the flush is harmless there.
-- verified 2026-11-13 on 23.26.3: FLUSH_UNIFIED_AUDIT_TRAIL is gone from
-- DBMS_AUDIT_MGMT (PLS-00302 at compile time), so it is called dynamically and
-- the error is reported, not raised. The records are there without a flush.
BEGIN
  IF dbms_db_version.version < 23 THEN
    EXECUTE IMMEDIATE 'BEGIN dbms_audit_mgmt.flush_unified_audit_trail; END;';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('- flush skipped: ' || SQLERRM);
END;
/

PROMPT == 4. Unified audit trail: last 30 records of HMB_DBA / HMB_APP ========
SELECT TO_CHAR(event_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS event_time,
       dbusername,
       action_name,
       CASE WHEN object_schema IS NULL THEN object_name
            ELSE object_schema || '.' || object_name END AS object,
       system_privilege_used AS sys_priv,
       unified_audit_policies AS policies,
       return_code AS rc
  FROM unified_audit_trail
 WHERE dbusername IN ('HMB_DBA', 'HMB_APP')
 ORDER BY event_timestamp DESC
 FETCH FIRST 30 ROWS ONLY;

PROMPT == 5. Records per policy for the HMB accounts ==========================
SELECT dbusername, NVL(unified_audit_policies, '(none)') AS policies, COUNT(*) AS records
  FROM unified_audit_trail
 WHERE dbusername IN ('HMB_DBA', 'HMB_APP')
 GROUP BY dbusername, unified_audit_policies
 ORDER BY dbusername, policies;

ALTER SESSION SET CONTAINER = CDB$ROOT;
SET SERVEROUTPUT ON SIZE UNLIMITED
UNDEFINE hmb_pwd hmb_svc
-- EOF -------------------------------------------------------------------------
