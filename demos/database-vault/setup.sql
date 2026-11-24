-- demos/database-vault setup - guard: DV must not be configured yet (make reset LAB=dv26 otherwise)
SET ECHO OFF SERVEROUTPUT ON
CONNECT / AS SYSDBA
DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM dba_dv_status WHERE name = 'DV_CONFIGURE_STATUS' AND status = 'TRUE';
  IF l_cnt > 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Database Vault already configured - run: make reset LAB=dv26');
  END IF;
END;
/
PROMPT OK - DV not configured
