--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: check.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 1 - what the audience sees: logon version
--              setting, password verifiers per account and a real login test
--              over the listener, before and after the solution.
--  Notes.....: - Based on oracle-free-labs config/common/scripts/
--                precheck_logon_version.sql (verifier classification).
--              - Run as SYSDBA in CDB$ROOT, from the demo directory inside the
--                container. Sections 1-2 are read-only and run on db19 and db26
--                (on db26 as the "what does 26ai show" contrast).
--              - Section 3 logs in as the HMB_* accounts through the listener
--                (EZConnect localhost:1521/DEMOPDB) - that is where
--                ALLOWED_LOGON_VERSION_SERVER is enforced. Errors are the result
--                here (ORA-01017 / ORA-28040), so no WHENEVER SQLERROR EXIT.
--                LAB-CHECK: service name DEMOPDB resolves without db_domain on
--                seclab-db19, and which error a 10G-only account gets under 12a.
--              - Each failed login counts against FAILED_LOGIN_ATTEMPTS
--                (DEFAULT profile: 10); setup.sql recreates the accounts.
--              - &1 setup password (default HmbDemo_Lab_Only_19),
--                &2 new HMB_LEGACY password (default HmbDemo_New_Lab_Only_19).
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

SET FEEDBACK OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 100
COLUMN 1 NEW_VALUE 1 NOPRINT
COLUMN 2 NEW_VALUE 2 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
SELECT '' "2" FROM dual WHERE ROWNUM = 0;
DEFINE hmb_pwd     = &1 HmbDemo_Lab_Only_19
DEFINE hmb_new_pwd = &2 HmbDemo_New_Lab_Only_19

COLUMN con_id            FORMAT 999
COLUMN username          FORMAT A14
COLUMN password_versions FORMAT A20
COLUMN account_status    FORMAT A16
COLUMN accounts          FORMAT 9999
COLUMN has_10g_hash      FORMAT A12
COLUMN login             FORMAT A40

PROMPT == 1. Server setting and release =======================================
SELECT banner_full FROM v$version;
HOST bash ./sqlnet_alv.sh show

PROMPT == 2a. Verifier mix of all non-Oracle password accounts per container ==
SELECT con_id, TRIM(password_versions) AS password_versions, COUNT(*) AS accounts
  FROM cdb_users
 WHERE oracle_maintained = 'N'
   AND authentication_type = 'PASSWORD'
 GROUP BY con_id, TRIM(password_versions)
 ORDER BY con_id, password_versions;

ALTER SESSION SET CONTAINER = DEMOPDB;

PROMPT == 2b. Demo accounts in DEMOPDB ========================================
SELECT u.username, u.password_versions, u.account_status,
       CASE WHEN s.password IS NOT NULL THEN 'YES' ELSE 'no' END AS has_10g_hash
  FROM dba_users u JOIN sys.user$ s ON s.name = u.username
 WHERE u.username LIKE 'HMB\_%' ESCAPE '\'
 ORDER BY u.username;

PROMPT == 3. Login test through the listener ==================================
PROMPT    expected after setup:    all three OK with the setup password
PROMPT    expected after solution: MODERN, APP_OLD OK (old password),
PROMPT                             LEGACY fails with the old, OK with the new one
WHENEVER SQLERROR CONTINUE

PROMPT - HMB_MODERN, setup password
CONNECT hmb_modern/"&&hmb_pwd"@//localhost:1521/DEMOPDB
SELECT user || ' - LOGIN OK' AS login FROM dual;

PROMPT - HMB_APP_OLD, setup password
CONNECT hmb_app_old/"&&hmb_pwd"@//localhost:1521/DEMOPDB
SELECT user || ' - LOGIN OK' AS login FROM dual;

PROMPT - HMB_LEGACY, setup password
CONNECT hmb_legacy/"&&hmb_pwd"@//localhost:1521/DEMOPDB
SELECT user || ' - LOGIN OK' AS login FROM dual;

PROMPT - HMB_LEGACY, new password from solution.sql
CONNECT hmb_legacy/"&&hmb_new_pwd"@//localhost:1521/DEMOPDB
SELECT user || ' - LOGIN OK' AS login FROM dual;

PROMPT - back to SYSDBA
CONNECT / AS SYSDBA
UNDEFINE hmb_pwd hmb_new_pwd
-- EOF -------------------------------------------------------------------------
