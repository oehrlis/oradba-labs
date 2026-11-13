# oradba-labs hook: lab accounts in DEMOPDB, passwords from lab.env via stdin
bash /opt/oracle/common/scripts/run_sql_script.sh -p DEMOPDB -e LAB_ADMIN_PWD -e LAB_USER_PWD create_lab_users.sql
