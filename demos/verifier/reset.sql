--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: reset.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 1 - remove everything setup.sql and
--              solution.sql created: HMB_* accounts and the sqlnet.ora change.
--  Notes.....: - Run as SYSDBA in CDB$ROOT, from the demo directory inside the
--                container (sqlnet_alv.sh must be next to this script).
--              - The sqlnet.ora change is a file: 'make reset' (flashback)
--                drops the accounts too, but it leaves sqlnet.ora at whatever
--                setup/solution wrote. This script restores the saved copy
--                (or removes the file if there was none) - run it in any case.
--              - No audit policies in this demo, so nothing to NOAUDIT.
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

SET FEEDBACK OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 100

BEGIN
  IF sys_context('userenv', 'con_name') <> 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20100, 'run reset.sql in CDB$ROOT as SYSDBA');
  END IF;
END;
/

ALTER SESSION SET CONTAINER = DEMOPDB;
-- DBMS_OUTPUT state is per container: re-enable after every switch
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT - Drop HMB_* demo accounts
DECLARE
  l_found BOOLEAN := FALSE;
BEGIN
  FOR r IN (SELECT username FROM dba_users
             WHERE username IN ('HMB_MODERN', 'HMB_APP_OLD', 'HMB_LEGACY')) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || r.username || ' CASCADE';
    dbms_output.put_line('- dropped ' || r.username);
    l_found := TRUE;
  END LOOP;
  IF NOT l_found THEN
    dbms_output.put_line('- no HMB_* demo accounts present');
  END IF;
  -- accounts the live solution may have added under another HMB_ name: report, do not drop blindly
  FOR r IN (SELECT username FROM dba_users WHERE username LIKE 'HMB\_%' ESCAPE '\') LOOP
    dbms_output.put_line('WARN: ' || r.username || ' left in DEMOPDB - drop it with: DROP USER '
                         || r.username || ' CASCADE;');
  END LOOP;
END;
/

ALTER SESSION SET CONTAINER = CDB$ROOT;
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT - Restore the server sqlnet.ora (old -> new value is printed)
HOST bash ./sqlnet_alv.sh restore
HOST bash ./sqlnet_alv.sh show
-- EOF -------------------------------------------------------------------------
