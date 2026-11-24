-- demos/database-vault step 6 - does ADMIN OPTION on a protected role bypass the realm? (regular vs mandatory)
-- Needs the state after step 5 (LAB_ADMIN is realm owner of both realms).
SET ECHO ON
COLUMN grantee FORMAT A12
COLUMN granted_role FORMAT A16
COLUMN admin_option FORMAT A5
WHENEVER SQLERROR CONTINUE
CONNECT lab_admin/"&lab_admin_pwd"@//localhost:1521/dvpdb1.oradba.ch
GRANT app_role_reg TO lab_user WITH ADMIN OPTION;
GRANT app_role_mand TO lab_user WITH ADMIN OPTION;
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/dvpdb1.oradba.ch
EXEC DBMS_MACADM.DELETE_AUTH_FROM_REALM('RR_ROLE_REG', 'LAB_ADMIN');
EXEC DBMS_MACADM.DELETE_AUTH_FROM_REALM('RR_ROLE_MAND', 'LAB_ADMIN');
SELECT realm_name, grantee, auth_options FROM dba_dv_realm_auth WHERE realm_name LIKE 'RR_ROLE%';
CONNECT lab_user/"&lab_user_pwd"@//localhost:1521/dvpdb1.oradba.ch
PROMPT == T5: LAB_USER holds the roles WITH ADMIN OPTION, no realm authorization, grants them to SCOTT
GRANT app_role_reg TO scott;
GRANT app_role_mand TO scott;
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/dvpdb1.oradba.ch
EXEC DBMS_MACADM.ADD_AUTH_TO_REALM('RR_ROLE_REG', 'LAB_USER', NULL, DBMS_MACUTL.G_REALM_AUTH_PARTICIPANT);
EXEC DBMS_MACADM.ADD_AUTH_TO_REALM('RR_ROLE_MAND', 'LAB_USER', NULL, DBMS_MACUTL.G_REALM_AUTH_PARTICIPANT);
CONNECT lab_user/"&lab_user_pwd"@//localhost:1521/dvpdb1.oradba.ch
PROMPT == T6: same, LAB_USER authorized as PARTICIPANT
GRANT app_role_reg TO scott;
GRANT app_role_mand TO scott;
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = dvpdb1;
SELECT grantee, granted_role, admin_option FROM dba_role_privs WHERE granted_role LIKE 'APP_ROLE%' ORDER BY 1, 2;
