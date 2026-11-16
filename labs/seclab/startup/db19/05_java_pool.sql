--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: 05_java_pool.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026.11.16
--  Revision..: v1.0.0
--  Purpose...: Floor for the Java pool of seclab-db19 (java_pool_size 64M)
--  Notes.....: Must be executed as SYSDBA connected to CDB$ROOT.
--              The image's ASMM default (sga_target 768M) gives the Java pool
--              16M. The privesc demo (module m4b, DBMS_JAVA grants) fills it
--              over weak/reset cycles until stage.sh unweak fails with
--              ORA-04031 ("java pool"), 2026-11-16. Online growth is refused
--              (ORA-04033, buffer cache at its minimum), so the floor goes into
--              the spfile and takes effect at the next restart - a flashback
--              (make reset) restarts the instance. Never stops the startup.
--  Reference.: talks-privesc/talks/oracle-privesc/demos/m4b_java
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

-- A failing floor must not stop the startup hooks ------------------------------
WHENEVER SQLERROR CONTINUE

-- SQL*Plus formatting ---------------------------------------------------------
SET LINESIZE 256 PAGESIZE 1000
SET SERVEROUTPUT ON FEEDBACK ON ECHO OFF TERMOUT ON VERIFY OFF

-- Begin logging ---------------------------------------------------------------
DEFINE LOG_PREFIX = '05_java_pool'
DEFINE LOG_DIR    = '/opt/oracle/scripts/logs'
@/opt/oracle/common/scripts/define_logging_begin.sql

@/opt/oracle/common/scripts/require_cdb_root.sql

-- Main ------------------------------------------------------------------------
DECLARE
    l_spfile VARCHAR2(64);
    l_memory NUMBER;
BEGIN
    SELECT MAX(display_value) INTO l_spfile FROM v$spparameter WHERE name = 'java_pool_size';
    SELECT current_size / 1024 / 1024 INTO l_memory FROM v$sga_dynamic_components WHERE component = 'java pool';
    IF l_spfile IS NULL OR l_spfile IN ('0', '0M') THEN
        EXECUTE IMMEDIATE q'[ALTER SYSTEM SET java_pool_size = 64M SCOPE = SPFILE]';
        DBMS_OUTPUT.PUT_LINE('java_pool_size: spfile (not set) -> 64M, takes effect at the next restart (java pool now '
            || l_memory || 'M)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('java_pool_size: spfile ' || l_spfile || ', java pool now ' || l_memory || 'M - unchanged');
    END IF;
END;
/

-- End logging -----------------------------------------------------------------
@/opt/oracle/common/scripts/define_logging_end.sql
-- EOF -------------------------------------------------------------------------
