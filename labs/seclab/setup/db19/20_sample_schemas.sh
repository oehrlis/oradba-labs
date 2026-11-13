# oradba-labs init hook - sourced by the image init, keep it to one call.
bash /opt/oradba-labs/common/scripts/lab_sql.sh DEMOPDB /opt/oradba-labs/common/sql/create_scott.sql && bash /opt/oradba-labs/common/scripts/lab_sql.sh DEMOPDB /opt/oradba-labs/common/sql/create_tvd_hr.sql
