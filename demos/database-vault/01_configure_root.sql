-- demos/database-vault step 1 - CONFIGURE_DV in CDB$ROOT (as SYS), common owner and account manager
SET ECHO ON
CONNECT / AS SYSDBA
SHOW con_name
SELECT * FROM dba_dv_status ORDER BY name;
EXEC DVSYS.CONFIGURE_DV(dvowner_uname => 'C##DV_OWNER', dvacctmgr_uname => 'C##DV_ACCTMGR');
SET ECHO OFF TERMOUT OFF
@?/rdbms/admin/utlrp.sql
SET ECHO ON TERMOUT ON
SELECT * FROM dba_dv_status ORDER BY name;
