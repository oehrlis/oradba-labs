--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: setup.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 1 - starting point: three demo accounts in
--              DEMOPDB, two of them with legacy 10G password verifiers.
--  Notes.....: *** INTENTIONALLY INSECURE - lab use only ***
--              - Based on oracle-free-labs config/common/scripts/
--                seclab_s11_default_password.sql (parameter/default pattern) and
--                set_sqlnet_param.sh (sqlnet.ora editing, here sqlnet_alv.sh).
--              - Run as SYSDBA in CDB$ROOT of seclab-db19, from the demo
--                directory inside the container (README.md, section Run).
--              - &1 demo password, default HmbDemo_Lab_Only_19 (lab only,
--                letters/digits/underscore only - DEFINE takes the first word).
--              - Weakens the lab on purpose: SQLNET.ALLOWED_LOGON_VERSION_SERVER
--                = 11 in the server sqlnet.ora. That is a file: 'make reset'
--                (flashback) does NOT revert it - reset.sql does.
--              - Accounts: HMB_MODERN (11G 12C, release default), HMB_APP_OLD
--                (10G 11G 12C), HMB_LEGACY (10G only, "migrated from 10g").
--              - Rerunnable: drops and recreates the HMB_* accounts.
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

-- Fail fast: a half-built starting point is worse than none -------------------
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

SET FEEDBACK OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 100
COLUMN 1 NEW_VALUE 1 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
DEFINE hmb_pwd = &1 HmbDemo_Lab_Only_19

PROMPT - Pre-checks: CDB$ROOT, release
BEGIN
  IF sys_context('userenv', 'con_name') <> 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20100, 'run setup.sql in CDB$ROOT as SYSDBA, not in '
                            || sys_context('userenv', 'con_name'));
  END IF;
  IF dbms_db_version.version <> 19 THEN
    dbms_output.put_line('WARN: release ' || dbms_db_version.version
      || ' - this exercise is written for db19. Run on another release only as a probe:');
    dbms_output.put_line('WARN: the end of this script says whether a 10G verifier was generated at all.');
  END IF;
END;
/

PROMPT - Save the server sqlnet.ora once (reset.sql restores it)
HOST bash ./sqlnet_alv.sh backup
HOST bash ./sqlnet_alv.sh show

ALTER SESSION SET CONTAINER = DEMOPDB;
-- DBMS_OUTPUT state is per container: re-enable after every switch
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT - Drop HMB_* demo accounts from an earlier run
BEGIN
  FOR r IN (SELECT username FROM dba_users
             WHERE username IN ('HMB_MODERN', 'HMB_APP_OLD', 'HMB_LEGACY')) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || r.username || ' CASCADE';
    dbms_output.put_line('- dropped ' || r.username);
  END LOOP;
END;
/

PROMPT - HMB_MODERN: created under 12 (release default -> 11G 12C)
-- A rerun without reset.sql finds 11 in sqlnet.ora; set 12 explicitly and
-- reconnect so HMB_MODERN never gets a 10G verifier (reset.sql restores the
-- saved original file either way).
HOST bash ./sqlnet_alv.sh set 12
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = DEMOPDB;
SET SERVEROUTPUT ON SIZE UNLIMITED
CREATE USER hmb_modern IDENTIFIED BY "&&hmb_pwd" DEFAULT TABLESPACE users;
GRANT CREATE SESSION TO hmb_modern;

PROMPT - Lower SQLNET.ALLOWED_LOGON_VERSION_SERVER to 11 (the "old app server" setting)
HOST bash ./sqlnet_alv.sh set 11

PROMPT - Reconnect: only a new server process reads the changed sqlnet.ora
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = DEMOPDB;
SET SERVEROUTPUT ON SIZE UNLIMITED

-- verified 2026-11-13 on 19.27: a bequeath server process started with
-- ALLOWED_LOGON_VERSION_SERVER=11 generates 10G 11G 12C on CREATE USER.
PROMPT - HMB_APP_OLD and HMB_LEGACY: created under 11 (expected 10G 11G 12C)
CREATE USER hmb_app_old IDENTIFIED BY "&&hmb_pwd" DEFAULT TABLESPACE users;
CREATE USER hmb_legacy  IDENTIFIED BY "&&hmb_pwd" DEFAULT TABLESPACE users;
GRANT CREATE SESSION TO hmb_app_old, hmb_legacy;

PROMPT - HMB_LEGACY: keep only the 10G verifier (account carried over since 10g)
-- The 10G hash is in SYS.USER$.PASSWORD, the 11G/12C verifiers in SPARE4.
-- IDENTIFIED BY VALUES with only the 16-hex 10G hash leaves a 10G-only account.
-- verified 2026-11-13 on 19.27: IDENTIFIED BY VALUES '<16 hex>' is accepted,
-- DBA_USERS then shows PASSWORD_VERSIONS = '10G' for HMB_LEGACY.
DECLARE
  l_hash sys.user$.password%TYPE;
BEGIN
  SELECT password INTO l_hash FROM sys.user$ WHERE name = 'HMB_LEGACY';
  IF l_hash IS NULL THEN
    IF dbms_db_version.version = 19 THEN
      RAISE_APPLICATION_ERROR(-20101, 'no 10G verifier generated for HMB_LEGACY - check '
        || '"HOST bash ./sqlnet_alv.sh show" and that the reconnect above happened');
    END IF;
    dbms_output.put_line('RESULT: release ' || dbms_db_version.version
      || ' generated NO 10G verifier with ALLOWED_LOGON_VERSION_SERVER=11 - '
      || 'the exercise cannot be shown here. Run reset.sql now.');
  ELSE
    EXECUTE IMMEDIATE 'ALTER USER hmb_legacy IDENTIFIED BY VALUES ''' || l_hash || '''';
    dbms_output.put_line('RESULT: HMB_LEGACY reduced to its 10G verifier');
  END IF;
END;
/

PROMPT - Starting point (the audience sees the same with check.sql)
COLUMN username          FORMAT A14
COLUMN password_versions FORMAT A20
COLUMN account_status    FORMAT A16
SELECT username, password_versions, account_status
  FROM dba_users
 WHERE username LIKE 'HMB\_%' ESCAPE '\'
 ORDER BY username;

UNDEFINE hmb_pwd
-- EOF -------------------------------------------------------------------------
