-- demos/database-vault step 3 - CONFIGURE_DV and ENABLE_DV in DVPDB1 with the common owner / account manager
SET ECHO ON
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = dvpdb1;
SHOW con_name
SELECT * FROM dba_dv_status ORDER BY name;
EXEC DVSYS.CONFIGURE_DV(dvowner_uname => 'C##DV_OWNER', dvacctmgr_uname => 'C##DV_ACCTMGR');
SET ECHO OFF TERMOUT OFF
@?/rdbms/admin/utlrp.sql
SET ECHO ON TERMOUT ON
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/dvpdb1.oradba.ch
SHOW con_name
EXEC DBMS_MACADM.ENABLE_DV;
CONNECT / AS SYSDBA
ALTER PLUGGABLE DATABASE dvpdb1 CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE dvpdb1 OPEN;
ALTER SESSION SET CONTAINER = dvpdb1;
SELECT * FROM dba_dv_status ORDER BY name;
