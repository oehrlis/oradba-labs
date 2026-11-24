-- demos/database-vault step 7 - DV_PATCH_ADMIN for SYS: what does it lift (roles, data realms, DDL) and what does the audit show
-- Needs the state after step 5/6. Adds data realms: RR_EMP_REG (regular, SCOTT.EMP) and RR_DEPT_MAND (mandatory, SCOTT.DEPT).
SET ECHO ON
COLUMN action_name FORMAT A18
COLUMN dbusername FORMAT A12
COLUMN object_name FORMAT A12
COLUMN unified_audit_policies FORMAT A40
COLUMN return_code FORMAT 99999
COLUMN dv_action_name FORMAT A20
COLUMN dv_object_name FORMAT A22
COLUMN dv_comment FORMAT A40
COLUMN sql_text FORMAT A50
WHENEVER SQLERROR CONTINUE
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/dvpdb1.oradba.ch
BEGIN
  DBMS_MACADM.CREATE_REALM('RR_EMP_REG', 'regular realm SCOTT.EMP', DBMS_MACUTL.G_YES, DBMS_MACUTL.G_REALM_AUDIT_OFF, 0);
  DBMS_MACADM.ADD_OBJECT_TO_REALM('RR_EMP_REG', 'SCOTT', 'EMP', '%');
  DBMS_MACADM.CREATE_REALM('RR_DEPT_MAND', 'mandatory realm SCOTT.DEPT', DBMS_MACUTL.G_YES, DBMS_MACUTL.G_REALM_AUDIT_OFF, 1);
  DBMS_MACADM.ADD_OBJECT_TO_REALM('RR_DEPT_MAND', 'SCOTT', 'DEPT', '%');
END;
/
PROMPT == T7: SYS without DV_PATCH_ADMIN
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = dvpdb1;
GRANT app_role_reg TO scott;
GRANT app_role_mand TO scott;
SELECT COUNT(*) FROM scott.emp;
SELECT COUNT(*) FROM scott.dept;
CREATE TABLE scott.t_sys_ddl (id NUMBER);

PROMPT == T8: grant DV_PATCH_ADMIN to SYS - first as SYS itself
GRANT dv_patch_admin TO sys CONTAINER=ALL;
ALTER SESSION SET CONTAINER = dvpdb1;
GRANT dv_patch_admin TO sys;
PROMPT == T8b: as the DV owner, in CDB$ROOT with CONTAINER=ALL
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/free.oradba.ch
GRANT dv_patch_admin TO sys CONTAINER=ALL;
PROMPT == T8c: as the DV account manager
CONNECT c##dv_acctmgr/"&dv_acctmgr_pwd"@//localhost:1521/free.oradba.ch
GRANT dv_patch_admin TO sys CONTAINER=ALL;
CONNECT / AS SYSDBA
SELECT con_id, grantee, granted_role FROM cdb_role_privs WHERE granted_role = 'DV_PATCH_ADMIN' ORDER BY 1, 2;
