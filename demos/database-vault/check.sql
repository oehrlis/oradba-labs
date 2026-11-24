-- demos/database-vault check - DV state in root and DVPDB1 (as SYS)
SET ECHO OFF
CONNECT / AS SYSDBA
COLUMN name FORMAT A22
COLUMN con FORMAT A10
SELECT con_id, name, status FROM cdb_dv_status ORDER BY con_id, name;
