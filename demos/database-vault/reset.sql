-- demos/database-vault reset - undo steps 4-8 (realms, roles, DV_PATCH_ADMIN, patch admin audit).
-- DV itself stays configured and enabled: 'make reset LAB=dv26' (flashback to LAB_BASELINE) is the real reset.
SET ECHO ON
WHENEVER SQLERROR CONTINUE
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/dvpdb1.oradba.ch
EXEC DBMS_MACADM.DISABLE_DV_PATCH_ADMIN_AUDIT;
BEGIN
  FOR r IN (SELECT name FROM dba_dv_realm WHERE name LIKE 'RR\_%' ESCAPE '\') LOOP
    DBMS_MACADM.DELETE_REALM_CASCADE(r.name);
  END LOOP;
END;
/
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/free.oradba.ch
EXEC DBMS_MACADM.DISABLE_DV_PATCH_ADMIN_AUDIT;
REVOKE dv_patch_admin FROM sys CONTAINER=ALL;
CONNECT lab_admin/"&lab_admin_pwd"@//localhost:1521/dvpdb1.oradba.ch
DROP ROLE app_role_reg;
DROP ROLE app_role_mand;
DROP ROLE app_role_free;
