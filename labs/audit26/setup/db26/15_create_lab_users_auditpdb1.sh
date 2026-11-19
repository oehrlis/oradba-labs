# oradba-labs hook: lab accounts in AUDITPDB1, passwords from lab.env via stdin
bash /opt/oracle/common/scripts/run_sql_script.sh -p AUDITPDB1 -e LAB_ADMIN_PWD -e LAB_USER_PWD create_lab_users.sql
