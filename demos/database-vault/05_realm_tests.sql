-- demos/database-vault step 5 - who may GRANT a realm-protected role (LAB_ADMIN = DBA with GRANT ANY ROLE)
SET ECHO ON
COLUMN grantee FORMAT A12
COLUMN granted_role FORMAT A16
WHENEVER SQLERROR CONTINUE
CONNECT lab_admin/"&lab_admin_pwd"@//localhost:1521/dvpdb1.oradba.ch
PROMPT == T1: no authorization - LAB_ADMIN (DBA, GRANT ANY ROLE) grants the protected roles
GRANT app_role_reg TO scott;
GRANT app_role_mand TO scott;
PROMPT == T1b: unprotected role as control (CONNECT is protected by the default DV realm, so not usable as control)
GRANT app_role_free TO scott;
REVOKE app_role_free FROM scott;

CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/dvpdb1.oradba.ch
EXEC DBMS_MACADM.ADD_AUTH_TO_REALM('RR_ROLE_REG', 'LAB_ADMIN', NULL, DBMS_MACUTL.G_REALM_AUTH_PARTICIPANT);
EXEC DBMS_MACADM.ADD_AUTH_TO_REALM('RR_ROLE_MAND', 'LAB_ADMIN', NULL, DBMS_MACUTL.G_REALM_AUTH_PARTICIPANT);
CONNECT lab_admin/"&lab_admin_pwd"@//localhost:1521/dvpdb1.oradba.ch
PROMPT == T2: LAB_ADMIN authorized as PARTICIPANT
GRANT app_role_reg TO scott;
GRANT app_role_mand TO scott;

CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/dvpdb1.oradba.ch
EXEC DBMS_MACADM.DELETE_AUTH_FROM_REALM('RR_ROLE_REG', 'LAB_ADMIN');
EXEC DBMS_MACADM.DELETE_AUTH_FROM_REALM('RR_ROLE_MAND', 'LAB_ADMIN');
EXEC DBMS_MACADM.ADD_AUTH_TO_REALM('RR_ROLE_REG', 'LAB_ADMIN', NULL, DBMS_MACUTL.G_REALM_AUTH_OWNER);
EXEC DBMS_MACADM.ADD_AUTH_TO_REALM('RR_ROLE_MAND', 'LAB_ADMIN', NULL, DBMS_MACUTL.G_REALM_AUTH_OWNER);
CONNECT lab_admin/"&lab_admin_pwd"@//localhost:1521/dvpdb1.oradba.ch
PROMPT == T3: LAB_ADMIN authorized as OWNER
GRANT app_role_reg TO scott;
GRANT app_role_mand TO scott;
SELECT grantee, granted_role FROM dba_role_privs WHERE granted_role LIKE 'APP_ROLE%' ORDER BY 1, 2;
REVOKE app_role_reg FROM scott;
REVOKE app_role_mand FROM scott;

PROMPT == T4: SYS (SYSDBA) in the PDB, no DV_PATCH_ADMIN, LAB_ADMIN still realm owner
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = dvpdb1;
GRANT app_role_reg TO scott;
GRANT app_role_mand TO scott;
PROMPT == T4b: SYS reads and changes data of SCOTT? (no data realm yet - control: DV does not block it)
SELECT COUNT(*) FROM scott.emp;
