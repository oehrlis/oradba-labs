-- demos/database-vault step 4 - role-protection realms in DVPDB1: regular (RR_ROLE_REG) vs mandatory (RR_ROLE_MAND)
-- Roles are created by LAB_ADMIN first (DV enabled, no realm yet), then the DV owner protects them.
SET ECHO ON
WHENEVER SQLERROR CONTINUE
CONNECT lab_admin/"&lab_admin_pwd"@//localhost:1521/dvpdb1.oradba.ch
CREATE ROLE app_role_reg;
CREATE ROLE app_role_mand;
CREATE ROLE app_role_free;
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/dvpdb1.oradba.ch
BEGIN
  DBMS_MACADM.CREATE_REALM(realm_name => 'RR_ROLE_REG', description => 'regular realm on role APP_ROLE_REG',
    enabled => DBMS_MACUTL.G_YES, audit_options => DBMS_MACUTL.G_REALM_AUDIT_OFF, realm_type => 0);
  DBMS_MACADM.ADD_OBJECT_TO_REALM('RR_ROLE_REG', '%', 'APP_ROLE_REG', 'ROLE');
  DBMS_MACADM.CREATE_REALM(realm_name => 'RR_ROLE_MAND', description => 'mandatory realm on role APP_ROLE_MAND',
    enabled => DBMS_MACUTL.G_YES, audit_options => DBMS_MACUTL.G_REALM_AUDIT_OFF, realm_type => 1);
  DBMS_MACADM.ADD_OBJECT_TO_REALM('RR_ROLE_MAND', '%', 'APP_ROLE_MAND', 'ROLE');
END;
/
COLUMN name FORMAT A14
COLUMN realm_name FORMAT A14
COLUMN owner FORMAT A8
COLUMN object_name FORMAT A16
COLUMN object_type FORMAT A12
COLUMN mandatory FORMAT A12
SELECT name, enabled, realm_type AS mandatory FROM dba_dv_realm WHERE name LIKE 'RR_ROLE%';
SELECT realm_name, owner, object_name, object_type FROM dba_dv_realm_object WHERE realm_name LIKE 'RR_ROLE%';
