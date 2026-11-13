--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: check.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 3 - what the audience sees: TDE parameters
--              (memory vs spfile), keystore status per container, master keys,
--              tablespace encryption and a clear-text scan of the datafile.
--  Notes.....: - Based on oracle-free-labs config/common/scripts/ssenc_info.sql
--                (pending parameters, wallet and key views) and ssenc_canary.sql
--                (readability verdict).
--              - Run as SYSDBA in CDB$ROOT of seclab-db26, from the demo
--                directory inside the container. Read-only apart from a
--                checkpoint (so the scan sees the current blocks).
--              - Before solution: WALLET_ROOT empty, NOT_AVAILABLE, scan > 0.
--                After solution: WALLET_ROOT set, OPEN, encrypted YES, scan 0,
--                the table still readable through SQL (TDE is transparent).
--              - The scan covers the datafile only. Clear text from before the
--                encryption stays in archived redo and flashback logs.
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

SET FEEDBACK OFF
SET VERIFY OFF
SET LINESIZE 180 PAGESIZE 100

COLUMN name            FORMAT A20
COLUMN memory          FORMAT A50
COLUMN spfile          FORMAT A50
COLUMN con_id          FORMAT 999
COLUMN wrl_parameter   FORMAT A45
COLUMN status          FORMAT A20
COLUMN wallet_type     FORMAT A16
COLUMN keystore_mode   FORMAT A8
COLUMN keys            FORMAT 999
COLUMN tablespace_name FORMAT A16
COLUMN encrypted       FORMAT A9
COLUMN encryptionalg   FORMAT A8
COLUMN file_name       FORMAT A70
COLUMN verdict         FORMAT A50

PROMPT == 1. TDE parameters: memory vs spfile (spfile != memory = restart pending)
SELECT p.name,
       NVL(p.value, '-')  AS memory,
       NVL(s.value, '-')  AS spfile
  FROM v$parameter p
  LEFT JOIN v$spparameter s ON s.name = p.name AND s.sid = '*'
 WHERE p.name IN ('wallet_root', 'tde_configuration')
 ORDER BY p.name;

PROMPT == 2. Keystore per container ===========================================
SELECT con_id, wrl_parameter, status, wallet_type, keystore_mode
  FROM v$encryption_wallet ORDER BY con_id;

PROMPT == 3. Master encryption keys per container =============================
SELECT con_id, COUNT(*) AS keys FROM v$encryption_keys GROUP BY con_id ORDER BY con_id;

ALTER SESSION SET CONTAINER = DEMOPDB;

PROMPT == 4. HMB_PLAIN_TS in DEMOPDB ===========================================
SELECT t.tablespace_name, t.encrypted, e.encryptionalg
  FROM dba_tablespaces t
  LEFT JOIN v$tablespace v ON v.name = t.tablespace_name
  LEFT JOIN v$encrypted_tablespaces e ON e.ts# = v.ts# AND e.con_id = v.con_id
 WHERE t.tablespace_name = 'HMB_PLAIN_TS';

-- current datafile (after the online conversion it is the _enc file)
DEFINE hmb_df = '/nonexistent/no_hmb_datafile'
COLUMN df NEW_VALUE hmb_df NOPRINT
SELECT file_name AS df FROM dba_data_files WHERE tablespace_name = 'HMB_PLAIN_TS';
SELECT '&hmb_df' AS file_name FROM dual;

PROMPT == 5. Readable through SQL? (TDE is transparent for authorised sessions)
SELECT CASE WHEN COUNT(*) = 0 THEN 'NO ROWS - setup.sql not run?'
            ELSE 'READABLE - ' || COUNT(*) || ' rows' END AS verdict
  FROM hmb_tde.customer_cards WHERE marker = 'HMB-TDE-CANARY';

ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER SYSTEM CHECKPOINT;

PROMPT == 6. Clear text on disk: lines with HMB-TDE-CANARY in the datafile (0 = encrypted)
HOST grep -a -c HMB-TDE-CANARY "&hmb_df" || true

PROMPT == 7. Wallet files ======================================================
COLUMN wallet_root NEW_VALUE wallet_root NOPRINT
SELECT NVL(MAX(value), '/nonexistent/no_wallet_root') AS wallet_root FROM v$parameter WHERE name = 'wallet_root';
HOST if [ -d "&wallet_root/tde" ]; then ls -l "&wallet_root/tde"; else echo "- no &wallet_root/tde"; fi
-- EOF -------------------------------------------------------------------------
