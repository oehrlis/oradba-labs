# oradba-labs init hook - sourced by the image init, keep it to one call.
bash /opt/oradba-labs/common/scripts/lab_sql.sh DEMOPDB /opt/oradba-labs/common/sql/create_lab_users.sql LAB_ADMIN_PWD LAB_USER_PWD
