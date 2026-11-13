--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: solution.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 1 - reference solution: find 10G password
--              verifiers, check who would be locked out, clean them up and
--              raise SQLNET.ALLOWED_LOGON_VERSION_SERVER to 12a.
--  Notes.....: - Based on oracle-free-labs config/common/scripts/
--                precheck_logon_version.sql (lock-out pre-check, inlined here).
--              - Run as SYSDBA in CDB$ROOT of seclab-db19, from the demo
--                directory inside the container, after setup.sql.
--              - &1 new password for the 10G-only account HMB_LEGACY, default
--                HmbDemo_New_Lab_Only_19 (lab only). In real life: hand it over
--                and add PASSWORD EXPIRE - not done here so check.sql can log in.
--              - Order matters: an ALTER USER ... IDENTIFIED BY under
--                ALLOWED_LOGON_VERSION_SERVER=11 creates a new 10G verifier.
--                So: raise the parameter, reconnect, then reset passwords.
--              - Accounts that already have a 12C verifier are cleaned without
--                knowing the password: IDENTIFIED BY VALUES with only the T:
--                part of SYS.USER$.SPARE4 drops the 10G and 11G verifiers.
--              - Minimal answer to the task is target 12 (no new 10G); this
--                script goes to 12a (12C only). 12a locks out clients older than
--                11.2.0.3 / without the O5L_NP capability - check them first.
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

SET FEEDBACK OFF
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 160 PAGESIZE 100
COLUMN 1 NEW_VALUE 1 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
DEFINE hmb_new_pwd = &1 HmbDemo_New_Lab_Only_19

COLUMN con_id            FORMAT 999
COLUMN username          FORMAT A14
COLUMN password_versions FORMAT A20
COLUMN account_status    FORMAT A16
COLUMN has_10g_hash      FORMAT A12

PROMPT == Step 1: find - which accounts carry a 10G verifier (all containers) ==
-- PASSWORD_VERSIONS is a space-separated list ('10G 11G 12C '), LIKE, not =.
SELECT con_id, username, password_versions, account_status
  FROM cdb_users
 WHERE password_versions LIKE '%10G%'
 ORDER BY con_id, username;

ALTER SESSION SET CONTAINER = DEMOPDB;
-- DBMS_OUTPUT state is per container: re-enable after every switch
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT == Step 2: pre-check for target 12a - who would be locked out? =========
DECLARE
  l_lock   PLS_INTEGER := 0;
  l_legacy PLS_INTEGER := 0;
BEGIN
  FOR r IN (SELECT username, account_status, password_versions
              FROM dba_users
             WHERE authentication_type = 'PASSWORD'
               AND oracle_maintained = 'N'   -- SYS, SYSTEM, XS$NULL ... are a separate topic
               AND password_versions IS NOT NULL
             ORDER BY username) LOOP
    IF r.password_versions NOT LIKE '%12C%' THEN
      l_lock := l_lock + 1;
      dbms_output.put_line('WOULD LOCK OUT: ' || r.username || ' (' || TRIM(r.password_versions)
                           || ') - needs a new password after the switch');
    ELSIF r.password_versions LIKE '%10G%' OR r.password_versions LIKE '%11G%' THEN
      l_legacy := l_legacy + 1;
      dbms_output.put_line('LEGACY VERIFIER: ' || r.username || ' (' || TRIM(r.password_versions)
                           || ') - 12C present, strip the old verifiers');
    END IF;
  END LOOP;
  dbms_output.put_line('Result: ' || l_lock || ' would be locked out, '
                       || l_legacy || ' keep a legacy verifier.');
END;
/

PROMPT == Step 3: raise SQLNET.ALLOWED_LOGON_VERSION_SERVER to 12a ============
HOST bash ./sqlnet_alv.sh set 12a
PROMPT - reconnect: the next ALTER USER must run in a process that read 12a
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = DEMOPDB;
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT == Step 4: strip 10G/11G where a 12C verifier exists (no password needed)
-- verified 2026-11-13 on 19.27: IDENTIFIED BY VALUES 'T:<hex>' is accepted, the
-- account keeps its password (listener login OK), PASSWORD_VERSIONS = '12C'.
-- Lab scope: HMB_* only. Without the filter the step also strips the 11G
-- verifier of the lab baseline accounts (LAB_ADMIN, LAB_USER, PDBADMIN), which
-- reset.sql cannot restore without their passwords. In real life: drop the filter.
DECLARE
  l_t VARCHAR2(4000);
BEGIN
  FOR r IN (SELECT u.username, s.spare4
              FROM dba_users u JOIN sys.user$ s ON s.name = u.username
             WHERE u.oracle_maintained = 'N'
               AND u.authentication_type = 'PASSWORD'
               AND u.username LIKE 'HMB\_%' ESCAPE '\'
               AND u.password_versions LIKE '%12C%'
               AND (u.password_versions LIKE '%10G%' OR u.password_versions LIKE '%11G%')) LOOP
    l_t := REGEXP_SUBSTR(r.spare4, 'T:[0-9A-F]+');
    IF l_t IS NULL THEN
      dbms_output.put_line('SKIPPED: ' || r.username || ' - no T: verifier found in SPARE4, reset its password');
    ELSE
      EXECUTE IMMEDIATE 'ALTER USER "' || r.username || '" IDENTIFIED BY VALUES ''' || l_t || '''';
      dbms_output.put_line('- ' || r.username || ': legacy verifiers removed, password unchanged');
    END IF;
  END LOOP;
END;
/

PROMPT == Step 5: 10G-only account - only a new password helps ================
ALTER USER hmb_legacy IDENTIFIED BY "&&hmb_new_pwd";
-- real life: ALTER USER hmb_legacy PASSWORD EXPIRE; and tell the owner.

PROMPT == Step 6: verify ======================================================
SELECT u.username, u.password_versions, u.account_status,
       CASE WHEN s.password IS NOT NULL THEN 'YES' ELSE 'no' END AS has_10g_hash
  FROM dba_users u JOIN sys.user$ s ON s.name = u.username
 WHERE u.oracle_maintained = 'N'
   AND u.authentication_type = 'PASSWORD'
 ORDER BY u.username;
HOST bash ./sqlnet_alv.sh show

UNDEFINE hmb_new_pwd
-- EOF -------------------------------------------------------------------------
