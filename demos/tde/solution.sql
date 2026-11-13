--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: solution.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 3 - reference solution: TDE software keystore
--              with WALLET_ROOT (united mode), master keys for CDB$ROOT and all
--              PDBs, online encryption of HMB_PLAIN_TS in DEMOPDB.
--  Notes.....: - Based on oracle-free-labs config/common/scripts/
--                idenc_wroot.sql (WALLET_ROOT, folders), restart_instance.sql,
--                csenc_swkeystore.sql (TDE_CONFIGURATION, keystore, auto-login),
--                csenc_master.sql (SET KEY WITH BACKUP) and ssenc_info.sql.
--              - Run as SYSDBA in CDB$ROOT of seclab-db26, from the demo
--                directory inside the container, after setup.sql.
--              - RESTART: WALLET_ROOT is static (SCOPE=SPFILE + restart).
--                TDE_CONFIGURATION is dynamic, but only accepted once WALLET_ROOT
--                is active - so it comes after the restart, SCOPE=BOTH.
--                The restart closes every session of this CDB (round 3 only).
--              - Not sqlnet.ora ENCRYPTION_WALLET_LOCATION: deprecated in 19c,
--                LAB-CHECK desupported in 23ai/26ai.
--              - Keystore password: ACCEPT ... HIDE, never in the script. Lab
--                only: LOCAL AUTO_LOGIN keystore. Production: password keystore
--                with external store or OKV/HSM, never auto-login alone.
--              - Rollback: reset.sql (drops the tablespace, resets both
--                parameters, removes the wallet files, restarts).
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

SET FEEDBACK ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 100

COLUMN name          FORMAT A20
COLUMN value         FORMAT A50
COLUMN wrl_parameter FORMAT A45
COLUMN status        FORMAT A20
COLUMN wallet_type   FORMAT A16
COLUMN con_id        FORMAT 999

-- same derivation as setup.sql / define_wallet_root_base.sql
COLUMN wallet_root NEW_VALUE wallet_root NOPRINT
SELECT RTRIM(value, '/') || '/dbconfig/' || sys_context('userenv', 'instance_name') || '/wallet' AS wallet_root
  FROM v$parameter WHERE name = 'diagnostic_dest';

-- Asked first, so a typo is not discovered after the restart. Deliberately no
-- PL/SQL length check: that would put the password unredacted into V$SQL.
ACCEPT keystore_pwd CHAR PROMPT 'Keystore password (lab only, not echoed, 8+ chars): ' HIDE

PROMPT == Step 1: WALLET_ROOT folders and parameter (SPFILE only) =============
HOST mkdir -p "&wallet_root/tde"
ALTER SYSTEM SET wallet_root = '&wallet_root' SCOPE = SPFILE;

PROMPT == Step 2: restart - WALLET_ROOT is static ==============================
-- LAB-CHECK: SHUTDOWN/STARTUP inside seclab-db26 keeps the container running
-- and takes about 60-90 s
SHUTDOWN IMMEDIATE
STARTUP
BEGIN
  FOR r IN (SELECT name FROM v$pdbs WHERE open_mode = 'MOUNTED' AND name <> 'PDB$SEED') LOOP
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE "' || r.name || '" OPEN';
    dbms_output.put_line('- opened ' || r.name);
  END LOOP;
END;
/
SELECT name, value FROM v$parameter WHERE name IN ('wallet_root', 'tde_configuration');

PROMPT == Step 3: TDE_CONFIGURATION (dynamic once WALLET_ROOT is active) ======
ALTER SYSTEM SET tde_configuration = 'KEYSTORE_CONFIGURATION=FILE' SCOPE = BOTH;

PROMPT == Step 4: software keystore in WALLET_ROOT/tde, open for all containers
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE IDENTIFIED BY "&&keystore_pwd";
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "&&keystore_pwd" CONTAINER = ALL;

PROMPT == Step 5: master encryption keys for CDB$ROOT and all PDBs, with backup
ADMINISTER KEY MANAGEMENT SET KEY USING TAG 'hmb_initial'
  IDENTIFIED BY "&&keystore_pwd" WITH BACKUP USING 'hmb_initial' CONTAINER = ALL;

PROMPT == Step 6: local auto-login keystore (lab only) ========================
-- LAB-CHECK: FROM KEYSTORE without a path resolves to WALLET_ROOT/tde on 23.26.3
ADMINISTER KEY MANAGEMENT CREATE LOCAL AUTO_LOGIN KEYSTORE FROM KEYSTORE
  IDENTIFIED BY "&&keystore_pwd";
UNDEFINE keystore_pwd

SELECT con_id, wrl_parameter, status, wallet_type FROM v$encryption_wallet ORDER BY con_id;

PROMPT == Step 7: encrypt HMB_PLAIN_TS online (new file, old one removed) =====
ALTER SESSION SET CONTAINER = DEMOPDB;
-- LAB-CHECK: online conversion with FILE_NAME_CONVERT on 23.26.3 Free
ALTER TABLESPACE hmb_plain_ts ENCRYPTION ONLINE USING 'AES256' ENCRYPT
  FILE_NAME_CONVERT = ('hmb_plain_ts01.dbf', 'hmb_plain_ts01_enc.dbf');

COLUMN tablespace_name FORMAT A16
COLUMN encrypted       FORMAT A9
SELECT tablespace_name, encrypted FROM dba_tablespaces WHERE tablespace_name = 'HMB_PLAIN_TS';
ALTER SESSION SET CONTAINER = CDB$ROOT;

PROMPT == Done - run check.sql: datafile scan must find 0 markers ==============
-- EOF -------------------------------------------------------------------------
