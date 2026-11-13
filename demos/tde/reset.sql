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
--                  2. make reset LAB=seclab: flashback to LAB_BASELINE (not
--                     needed for the next rehearsal, see below).
--                'make reset' alone leaves WALLET_ROOT/TDE_CONFIGURATION in the
--                spfile and the keystore on disk (with keys the flashed-back
--                database no longer knows); setup.sql then refuses to start.
--              - The wallet directory is the one in the spfile/memory (the live
--                solution may have chosen another path). It is removed only if
--                it ends in /wallet - otherwise the command is printed.
--              - This demo creates no audit policy. ADMINISTER KEY MANAGEMENT
--                is audited mandatorily; those records stay (no purge).
--              - verified 2026-11-13 on 23.26.3: CDB and PDBs open without the
--                keystore once the encrypted tablespace is gone, although master
--                keys were set. The key references stay in the database
--                (V$DATABASE_KEY_INFO) - the next solution.sql run discards them
--                (lab only), so rehearsals work without 'make reset'.
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

PROMPT - 0. Guaranteed restore point vs. DROP TABLESPACE
-- verified 2026-11-13 on 23.26.3: with the lab's guaranteed restore point
-- LAB_BASELINE, DROP TABLESPACE fails with ORA-38881 - Oracle cannot know that
-- the tablespace did not exist at the restore point. The lab keeps LAB_BASELINE,
-- so the drop is allowed for this session's instance only (SCOPE = MEMORY,
-- underscore parameter, lab only) - and only if every HMB_* datafile was created
-- after the newest guaranteed restore point, so a flashback to it never needs
-- the dropped file. Reset to FALSE right after the drop; the restart below
-- clears it in any case. Otherwise the drop is skipped and reported.
DEFINE hmb_grp_override = 'NO'
COLUMN grp_override NEW_VALUE hmb_grp_override NOPRINT
SELECT CASE
         WHEN NOT EXISTS (SELECT 1 FROM v$restore_point WHERE guarantee_flashback_database = 'YES') THEN 'NOT_NEEDED'
         WHEN NOT EXISTS (SELECT 1 FROM v$tablespace t JOIN v$containers c ON c.con_id = t.con_id
                           WHERE c.name = 'DEMOPDB' AND t.name LIKE 'HMB\_%' ESCAPE '\') THEN 'NOT_NEEDED'
         WHEN (SELECT MIN(d.creation_change#)
                 FROM v$datafile d
                 JOIN v$tablespace t ON t.ts# = d.ts# AND t.con_id = d.con_id
                 JOIN v$containers c ON c.con_id = d.con_id
                WHERE c.name = 'DEMOPDB' AND t.name LIKE 'HMB\_%' ESCAPE '\')
              > (SELECT MAX(scn) FROM v$restore_point WHERE guarantee_flashback_database = 'YES') THEN 'YES'
         ELSE 'NO'
       END AS grp_override
  FROM dual;
PROMPT - drop override needed and safe: &hmb_grp_override
BEGIN
  IF '&hmb_grp_override' = 'YES' THEN
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET "_allow_drop_ts_with_grp" = TRUE SCOPE = MEMORY';
    dbms_output.put_line('- _allow_drop_ts_with_grp = TRUE (memory, until the restart below)');
  END IF;
END;
/

ALTER SESSION SET CONTAINER = DEMOPDB;
-- DBMS_OUTPUT state is per container: re-enable after every switch
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT - 1. Drop demo schema and tablespace (keystore still open)
BEGIN
  FOR r IN (SELECT username FROM dba_users WHERE username = 'HMB_TDE') LOOP
    EXECUTE IMMEDIATE 'DROP USER hmb_tde CASCADE';
    dbms_output.put_line('- dropped user HMB_TDE');
  END LOOP;
  FOR r IN (SELECT tablespace_name FROM dba_tablespaces WHERE tablespace_name LIKE 'HMB\_%' ESCAPE '\') LOOP
    IF '&hmb_grp_override' IN ('YES', 'NOT_NEEDED') THEN
      EXECUTE IMMEDIATE 'DROP TABLESPACE "' || r.tablespace_name || '" INCLUDING CONTENTS AND DATAFILES';
      dbms_output.put_line('- dropped tablespace ' || r.tablespace_name || ' including datafiles');
    ELSE
      dbms_output.put_line('WARN: ' || r.tablespace_name || ' NOT dropped - it existed before a guaranteed '
        || 'restore point (ORA-38881). make reset LAB=seclab (flashback) removes it.');
    END IF;
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
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
  IF '&hmb_grp_override' = 'YES' THEN
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET "_allow_drop_ts_with_grp" = FALSE SCOPE = MEMORY';
    dbms_output.put_line('- _allow_drop_ts_with_grp = FALSE again');
  END IF;
END;
/

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
HOST case "&wallet_root" in */wallet) rm -rf -- "&wallet_root"; rmdir -- "$(dirname -- "&wallet_root")" 2>/dev/null; echo "- removed &wallet_root (and its parent if empty)";; *) echo "WARN: &wallet_root does not end in /wallet - not removed, check and remove by hand";; esac
STARTUP
-- the restart ends the DBMS_OUTPUT state of this session as well
SET SERVEROUTPUT ON SIZE UNLIMITED
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

UNDEFINE hmb_grp_override wallet_root
PROMPT - Next: make reset LAB=seclab (flashback, clears the remaining key metadata)
-- EOF -------------------------------------------------------------------------
