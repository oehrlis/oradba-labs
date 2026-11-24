# oradba-labs hook: common Database Vault accounts in CDB$ROOT, passwords from lab.env via stdin
bash /opt/oracle/common/scripts/run_sql_script.sh -e DV_OWNER_PWD -e DV_ACCTMGR_PWD create_dv_users.sql
