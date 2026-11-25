-- Dictionary export for the oracle-check snapshot (tagged lines, one sqlplus run).
-- Same queries as aitk oracle-check (oradba_aitk/oracle_check/dictionary.py SNAPSHOT_SQL).
-- Read-only: SELECTs on the dictionary only.
set pages 0 feed off lines 32767 trimspool on trimout on heading off verify off echo off
set tab off define off sqlprefix off sqlblanklines on serveroutput on size unlimited
select 'V|'||version_full from v$instance;
select 'O|'||owner||'|'||object_name||'|'||object_type from dba_objects
 where object_type in ('VIEW','TABLE','PACKAGE','SYNONYM','TYPE','FUNCTION','PROCEDURE','SEQUENCE')
   and owner in (select username from dba_users where oracle_maintained = 'Y')
   and object_name not like 'BIN$%' and object_name not like 'SYS\_%' escape '\';
select 'S|'||owner||'|'||synonym_name||'|'||table_owner||'|'||table_name
  from dba_synonyms where owner = 'PUBLIC';
select 'P|'||owner||'|'||object_name||'|'||procedure_name from dba_procedures
 where object_type = 'PACKAGE' and procedure_name is not null;
select distinct 'M|'||owner||'|'||name||'|'||
       regexp_substr(upper(text),'^\s*([A-Z][A-Z0-9_$#]*)\s+(CONSTANT|EXCEPTION)',1,1,null,1)
  from dba_source where type = 'PACKAGE'
   and regexp_like(upper(text),'^\s*[A-Z][A-Z0-9_$#]*\s+(CONSTANT|EXCEPTION)');
select distinct 'M|'||owner||'|'||name||'|'||
       regexp_substr(upper(text),'^\s*(SUB)?TYPE\s+([A-Z][A-Z0-9_$#]*)',1,1,null,2)
  from dba_source where type = 'PACKAGE' and regexp_like(upper(text),'^\s*(SUB)?TYPE\s+[A-Z]');
select 'C|'||owner||'|'||table_name||'|'||column_name from dba_tab_columns
 where owner in (select username from dba_users where oracle_maintained = 'Y') and table_name not like 'BIN$%';
select 'F|'||name from v$fixed_table;
select 'R|'||name from v$parameter;
select 'X|'||name from v$obsolete_parameter;
select 'B|'||replace(banner_full, chr(10), ' ') from v$version;
select 'U|'||patch_id||'|'||action||'|'||status||'|'||to_char(action_time,'YYYY-MM-DD')||'|'||
       replace(replace(description, '|', '/'), chr(10), ' ')
  from dba_registry_sqlpatch order by action_time;
exit
