-- demos/database-vault step 8 - SYS with DV_PATCH_ADMIN (CONTAINER=ALL): same actions as T7, then the audit
SET ECHO ON
COLUMN event_timestamp FORMAT A27
COLUMN dbusername FORMAT A8
COLUMN action_name FORMAT A14
COLUMN object_name FORMAT A12
COLUMN object_schema FORMAT A8
COLUMN unified_audit_policies FORMAT A28
COLUMN return_code FORMAT 99999
COLUMN sql_text FORMAT A48
COLUMN policy_name FORMAT A32
COLUMN enabled_option FORMAT A12
COLUMN dv_action_name FORMAT A22
COLUMN dv_action_object_name FORMAT A24
COLUMN dv_comment FORMAT A40
COLUMN ts FORMAT A8
WHENEVER SQLERROR CONTINUE
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = dvpdb1;
PROMPT == T9: SYS with DV_PATCH_ADMIN, DV_PATCH_ADMIN audit still off
GRANT app_role_reg TO scott;
GRANT app_role_mand TO scott;
SELECT COUNT(*) FROM scott.emp;
SELECT COUNT(*) FROM scott.dept;
INSERT INTO scott.emp (empno, ename) VALUES (9999, 'DVTEST');
ROLLBACK;
CREATE TABLE scott.t_sys_ddl (id NUMBER);
DROP TABLE scott.t_sys_ddl PURGE;
REVOKE app_role_reg FROM scott;
REVOKE app_role_mand FROM scott;

PROMPT == T10: ENABLE_DV_PATCH_ADMIN_AUDIT in CDB$ROOT and DVPDB1 (as DV owner), then the same actions as SYS
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/free.oradba.ch
EXEC DBMS_MACADM.ENABLE_DV_PATCH_ADMIN_AUDIT;
CONNECT c##dv_owner/"&dv_owner_pwd"@//localhost:1521/dvpdb1.oradba.ch
EXEC DBMS_MACADM.ENABLE_DV_PATCH_ADMIN_AUDIT;
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = dvpdb1;
SELECT policy_name, enabled_option FROM audit_unified_enabled_policies WHERE policy_name LIKE '%DV%' OR policy_name LIKE '%PATCH%';
EXEC DBMS_SESSION.SLEEP(2)
COLUMN marker NEW_VALUE marker NOPRINT
SELECT TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS marker FROM dual;
EXEC DBMS_SESSION.SLEEP(2)
GRANT app_role_reg TO scott;
SELECT COUNT(*) FROM scott.emp;
SELECT COUNT(*) FROM scott.dept;
CREATE TABLE scott.t_sys_ddl (id NUMBER);
DROP TABLE scott.t_sys_ddl PURGE;
REVOKE app_role_reg FROM scott;
PROMPT == T11: what lands in UNIFIED_AUDIT_TRAIL for SYS in DVPDB1 (since the marker of T10)
SELECT TO_CHAR(event_timestamp, 'HH24:MI:SS') AS ts, dbusername, action_name, object_schema, object_name, return_code,
       unified_audit_policies, dv_action_name AS dv_action, SUBSTR(sql_text, 1, 48) AS sql_text
  FROM unified_audit_trail
 WHERE dbusername = 'SYS' AND event_timestamp >= TO_TIMESTAMP('&marker', 'YYYY-MM-DD HH24:MI:SS')
 ORDER BY event_timestamp;
PROMPT == T11b: DV-specific audit columns (DV_ACTION_NAME is set for DV events)
SELECT TO_CHAR(event_timestamp, 'HH24:MI:SS') AS ts, dv_action_name, dv_action_object_name, dv_comment, dv_return_code
  FROM unified_audit_trail WHERE dv_action_name IS NOT NULL AND event_timestamp >= TO_TIMESTAMP('&marker', 'YYYY-MM-DD HH24:MI:SS') ORDER BY event_timestamp;
PROMPT == T11c: DV audit records of the realm violations and of the audit switch (CDB views, all containers)
COLUMN con_id FORMAT 99
COLUMN dbusername FORMAT A12
COLUMN dv_return_code FORMAT 99999
SELECT con_id, TO_CHAR(event_timestamp, 'HH24:MI:SS') AS ts, dbusername, dv_action_name, dv_return_code
  FROM cdb_unified_audit_trail
 WHERE dv_action_name IN ('Realm Violation Audit', 'Enable DV_PATCH_ADMIN_AUDIT Audit')
 ORDER BY event_timestamp DESC FETCH FIRST 14 ROWS ONLY;
