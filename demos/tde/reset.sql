--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: reset.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 3 - remove everything setup.sql and
--              solution.sql created, including what 'make reset' cannot
--              revert: WALLET_ROOT and TDE_CONFIGURATION in the spfile and the
--              keystore files on disk. Restarts the instance.
--  Notes.....: - Based on oracle-free-labs config/common/scripts/
--                restart_instance.sql and ssenc_info.sql (parameter check).
--              - Run as SYSDBA in CDB$ROOT of seclab-db26, from the demo
--                directory inside the container. Order matters:
--                  1. reset.sql (this script): drop the encrypted tablespace
--                     while the keystore is still open, reset both parameters
--                     in the spfile, SHUTDOWN, remove the wallet, STARTUP.
--                  2. make reset LAB=seclab: flashback removes the remaining
--                     key metadata from the database (LAB-CHECK below).
--                'make reset' alone leaves WALLET_ROOT/TDE_CONFIGURATION in the
--                spfile and the keystore on disk (with keys the flashed-back
--                database no longer knows); setup.sql then refuses to start.
--              - The wallet directory is the one in the spfile/memory (the live
--                solution may have chosen another path). It is removed only if
--                it ends in /wallet - otherwise the command is printed.
--              - This demo creates no audit policy. ADMINISTER KEY MANAGEMENT
--                is audited mandatorily; those records stay (no purge).
--              - LAB-CHECK: CDB and PDBs open without the keystore once the
--                encrypted tablespace is gone, although master keys were set.
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
    RAISE_APPLICATION_ERROR(-20300, 'run reset.sql in CDB$ROOT as SYSDBA');
  END IF;
END;
/

-- wallet directory actually configured (spfile first, then memory, then the default)
COLUMN wallet_root NEW_VALUE wallet_root NOPRINT
SELECT COALESCE(
         (SELECT MAX(value) FROM v$spparameter WHERE name = 'wallet_root' AND isspecified = 'TRUE'),
         (SELECT value FROM v$parameter WHERE name = 'wallet_root'),
         (SELECT RTRIM(value, '/') || '/dbconfig/' || sys_context('userenv', 'instance_name') || '/wallet'
            FROM v$parameter WHERE name = 'diagnostic_dest')) AS wallet_root
  FROM dual;
PROMPT - wallet directory: &wallet_root

ALTER SESSION SET CONTAINER = DEMOPDB;

PROMPT - 1. Drop demo schema and tablespace (keystore still open)
BEGIN
  FOR r IN (SELECT username FROM dba_users WHERE username = 'HMB_TDE') LOOP
    EXECUTE IMMEDIATE 'DROP USER hmb_tde CASCADE';
    dbms_output.put_line('- dropped user HMB_TDE');
  END LOOP;
  FOR r IN (SELECT tablespace_name FROM dba_tablespaces WHERE tablespace_name LIKE 'HMB\_%' ESCAPE '\') LOOP
    EXECUTE IMMEDIATE 'DROP TABLESPACE "' || r.tablespace_name || '" INCLUDING CONTENTS AND DATAFILES';
    dbms_output.put_line('- dropped tablespace ' || r.tablespace_name || ' including datafiles');
  END LOOP;
  -- a live solution may have set TDE_CONFIGURATION in the PDB as well
  BEGIN
    EXECUTE IMMEDIATE 'ALTER SYSTEM RESET tde_configuration SCOPE = SPFILE';
    dbms_output.put_line('- DEMOPDB: tde_configuration reset');
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('- DEMOPDB: tde_configuration not set at PDB level (' || SQLCODE || ')');
  END;
  -- other encrypted tablespaces: report, never drop
  FOR r IN (SELECT tablespace_name FROM dba_tablespaces WHERE encrypted = 'YES') LOOP
    dbms_output.put_line('WARN: encrypted tablespace ' || r.tablespace_name
      || ' left in DEMOPDB - without the keystore it will not open; decrypt or drop it first');
  END LOOP;
END;
/

ALTER SESSION SET CONTAINER = CDB$ROOT;

PROMPT - 2. Reset WALLET_ROOT and TDE_CONFIGURATION in the spfile (old value shown)
DECLARE
  TYPE t_list IS TABLE OF VARCHAR2(30);
  l_params t_list := t_list('tde_configuration', 'wallet_root');
  l_old    v$spparameter.value%TYPE;
BEGIN
  FOR i IN 1 .. l_params.COUNT LOOP
    SELECT MAX(value) INTO l_old FROM v$spparameter
     WHERE name = l_params(i) AND isspecified = 'TRUE';
    IF l_old IS NULL THEN
      dbms_output.put_line('- ' || l_params(i) || ': not in spfile');
    ELSE
      EXECUTE IMMEDIATE 'ALTER SYSTEM RESET ' || l_params(i) || ' SCOPE = SPFILE';
      dbms_output.put_line('- ' || l_params(i) || ': ''' || l_old || ''' -> <not set> (spfile)');
    END IF;
  END LOOP;
END;
/

PROMPT - 3. Shutdown, remove the wallet, startup
SHUTDOWN IMMEDIATE
HOST case "&wallet_root" in */wallet) rm -rf -- "&wallet_root"; echo "- removed &wallet_root";; *) echo "WARN: &wallet_root does not end in /wallet - not removed, check and remove by hand";; esac
STARTUP
BEGIN
  FOR r IN (SELECT name FROM v$pdbs WHERE open_mode = 'MOUNTED' AND name <> 'PDB$SEED') LOOP
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE "' || r.name || '" OPEN';
    dbms_output.put_line('- opened ' || r.name);
  END LOOP;
END;
/

PROMPT - 4. State after reset (expected: both parameters '-', keystore NOT_AVAILABLE)
COLUMN name          FORMAT A20
COLUMN memory        FORMAT A50
COLUMN spfile        FORMAT A50
COLUMN con_id        FORMAT 999
COLUMN wrl_parameter FORMAT A45
COLUMN status        FORMAT A20
COLUMN pdb           FORMAT A12
COLUMN open_mode     FORMAT A12
SELECT p.name, NVL(p.value, '-') AS memory, NVL(s.value, '-') AS spfile
  FROM v$parameter p
  LEFT JOIN v$spparameter s ON s.name = p.name AND s.sid = '*'
 WHERE p.name IN ('wallet_root', 'tde_configuration');
SELECT con_id, wrl_parameter, status FROM v$encryption_wallet ORDER BY con_id;
SELECT name AS pdb, open_mode FROM v$pdbs ORDER BY con_id;

PROMPT - Next: make reset LAB=seclab (flashback, clears the remaining key metadata)
-- EOF -------------------------------------------------------------------------
