--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: setup.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 3 - starting point: no WALLET_ROOT, no
--              keystore, and a table with clear-text "card numbers" in the
--              unencrypted tablespace HMB_PLAIN_TS in DEMOPDB.
--  Notes.....: - Based on oracle-free-labs config/common/scripts/
--                define_wallet_root_base.sql (WALLET_ROOT location) and
--                csenc_canary.sql (canary table, marker in every row).
--              - Run as SYSDBA in CDB$ROOT of seclab-db26, from the demo
--                directory inside the container (HOST grep runs there).
--              - Stops if WALLET_ROOT is set (memory or spfile), if the wallet
--                directory exists or HMB_PLAIN_TS exists: run reset.sql first.
--                'make reset' alone does not clear WALLET_ROOT, TDE_CONFIGURATION
--                or the wallet files - this guard catches that.
--              - Card numbers are test numbers (4111...), no real data.
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

SET FEEDBACK OFF
SET VERIFY OFF
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 100

-- WALLET_ROOT location, as define_wallet_root_base.sql derives it:
-- <diagnostic_dest>/dbconfig/<instance_name>/wallet (Free: /opt/oracle/dbconfig/FREE/wallet)
-- LAB-CHECK: /opt/oracle/dbconfig is a persistent mount in seclab-db26
COLUMN wallet_root NEW_VALUE wallet_root NOPRINT
SELECT RTRIM(value, '/') || '/dbconfig/' || sys_context('userenv', 'instance_name') || '/wallet' AS wallet_root
  FROM v$parameter WHERE name = 'diagnostic_dest';

PROMPT - Pre-checks: CDB$ROOT, release, no TDE configuration yet
DECLARE
  l_mem v$parameter.value%TYPE;
  l_spf v$spparameter.value%TYPE;
BEGIN
  IF sys_context('userenv', 'con_name') <> 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20300, 'run setup.sql in CDB$ROOT as SYSDBA');
  END IF;
  IF dbms_db_version.version < 23 THEN
    dbms_output.put_line('WARN: release ' || dbms_db_version.version || ' - the exercise is written for db26');
  END IF;
  SELECT value INTO l_mem FROM v$parameter WHERE name = 'wallet_root';
  SELECT MAX(value) INTO l_spf FROM v$spparameter WHERE name = 'wallet_root' AND isspecified = 'TRUE';
  IF l_mem IS NOT NULL OR l_spf IS NOT NULL THEN
    RAISE_APPLICATION_ERROR(-20301, 'WALLET_ROOT already set (memory: ' || NVL(l_mem, '-') || ', spfile: '
      || NVL(l_spf, '-') || ') - run reset.sql first');
  END IF;
  dbms_output.put_line('- WALLET_ROOT not set, solution will use &wallet_root');
END;
/

PROMPT - Wallet directory must not exist yet
-- A HOST exit status does not stop SQL*Plus, hence the loud STOP line. If it
-- is ignored, CREATE KEYSTORE in solution.sql fails (keystore exists).
HOST if [ -e "&wallet_root" ]; then echo "STOP: &wallet_root exists - run reset.sql, then setup.sql again"; else echo "- OK: &wallet_root does not exist"; fi

ALTER SESSION SET CONTAINER = DEMOPDB;

PROMPT - Leftover HMB_PLAIN_TS?
DECLARE
  l_cnt PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM dba_tablespaces WHERE tablespace_name = 'HMB_PLAIN_TS';
  IF l_cnt > 0 THEN
    RAISE_APPLICATION_ERROR(-20302, 'HMB_PLAIN_TS exists - run reset.sql first');
  END IF;
END;
/

-- datafile directory of the PDB (no OMF assumption)
COLUMN pdb_dir NEW_VALUE pdb_dir NOPRINT
SELECT SUBSTR(file_name, 1, INSTR(file_name, '/', -1)) AS pdb_dir
  FROM dba_data_files WHERE tablespace_name = 'SYSTEM';

PROMPT - HMB_PLAIN_TS in &pdb_dir (unencrypted on purpose)
CREATE TABLESPACE hmb_plain_ts DATAFILE '&pdb_dir.hmb_plain_ts01.dbf' SIZE 20M AUTOEXTEND OFF;

PROMPT - HMB_TDE.CUSTOMER_CARDS with marker HMB-TDE-CANARY in every row
CREATE USER hmb_tde NO AUTHENTICATION
  DEFAULT TABLESPACE hmb_plain_ts QUOTA UNLIMITED ON hmb_plain_ts;

CREATE TABLE hmb_tde.customer_cards (
    id       NUMBER        NOT NULL,
    marker   VARCHAR2(32)  NOT NULL,
    card_no  VARCHAR2(19)  NOT NULL,
    CONSTRAINT customer_cards_pk PRIMARY KEY (id)
) TABLESPACE hmb_plain_ts;

INSERT INTO hmb_tde.customer_cards (id, marker, card_no)
SELECT LEVEL, 'HMB-TDE-CANARY', '4111-1111-' || TO_CHAR(MOD(LEVEL, 10000), 'FM0000') || '-1111'
  FROM dual CONNECT BY LEVEL <= 2000;
COMMIT;

ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER SYSTEM CHECKPOINT;

PROMPT - Clear text in the datafile (lines with the marker, > 0 = readable on disk)
HOST grep -a -c HMB-TDE-CANARY "&pdb_dir.hmb_plain_ts01.dbf" || true
-- EOF -------------------------------------------------------------------------
