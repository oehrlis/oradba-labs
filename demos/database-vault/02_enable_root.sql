-- demos/database-vault step 2 - ENABLE_DV in CDB$ROOT (as DV owner), then restart the CDB
SET ECHO ON
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/free.oradba.ch
SHOW con_name
EXEC DBMS_MACADM.ENABLE_DV;
SELECT * FROM dba_dv_status ORDER BY name;
-- not yet effective: the next lines are the restart
CONNECT / AS SYSDBA
SHUTDOWN IMMEDIATE
STARTUP
ALTER PLUGGABLE DATABASE ALL OPEN;
SELECT * FROM dba_dv_status ORDER BY name;
SELECT con_id, name, open_mode FROM v$pdbs;
