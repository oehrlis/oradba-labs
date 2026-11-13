--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: solution.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
--  Editor....: Stefan Oehrli
--  Date......: 2026-11-13
--  Revision..: 0.1.0
--  Purpose...: hold-my-beer round 2 - reference solution: a local Unified Audit
--              policy for privileged users in DEMOPDB, enabled by granted role,
--              plus a critical-privilege policy, and the matching NOAUDIT.
--  Notes.....: - Based on oracle-free-labs config/common/scripts/
--                create_audit_policies.sql / enable_audit_policies.sql
--                (oradba_loc_all_act_priv_usr, oradba_loc_critical_db_act) and
--                ora-db-audit-eng sql/aud_policies_show_aud.sql (verification).
--              - Run as SYSDBA in CDB$ROOT of seclab-db19 or seclab-db26.
--                Scope: local policies in DEMOPDB (no CONTAINER=ALL).
--              - Enable by role, never BY ALL USERS: ACTIONS ALL for every
--                session would audit the application account as well.
--              - BY USERS WITH GRANTED ROLES dba also covers SYS and LAB_ADMIN
--                (both hold DBA) - intended, it is a privileged-user policy.
--              - A policy change applies to sessions started afterwards:
--                check.sql logs in fresh as HMB_DBA.
--                LAB-CHECK: same behaviour on 19.27 and 23.26.3.
--              - The way back (run by reset.sql) - NOAUDIT needs the same BY
--                clause as the AUDIT, DROP fails while the policy is enabled:
--                  NOAUDIT POLICY hmb_loc_priv_usr_act_pol BY USERS WITH GRANTED ROLES dba;
--                  NOAUDIT POLICY hmb_loc_crit_priv_use_pol;
--                  DROP AUDIT POLICY hmb_loc_priv_usr_act_pol;
--                  DROP AUDIT POLICY hmb_loc_crit_priv_use_pol;
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

WHENEVER SQLERROR EXIT SQL.SQLCODE

SET FEEDBACK ON
SET VERIFY OFF
SET LINESIZE 160 PAGESIZE 100

ALTER SESSION SET CONTAINER = DEMOPDB;

PROMPT == Step 1: all top-level actions of privileged users ===================
CREATE AUDIT POLICY hmb_loc_priv_usr_act_pol
    ACTIONS ALL
    ONLY TOPLEVEL;

COMMENT ON AUDIT POLICY hmb_loc_priv_usr_act_pol IS
    'hold-my-beer: all top-level actions of users with role DBA';

AUDIT POLICY hmb_loc_priv_usr_act_pol BY USERS WITH GRANTED ROLES dba;

PROMPT == Step 2 (bonus): use of critical system privileges, every user =======
-- subset of oradba_loc_critical_db_act - recorded only when the privilege is
-- actually needed (e.g. SELECT ANY TABLE on a table without an object grant)
CREATE AUDIT POLICY hmb_loc_crit_priv_use_pol
    PRIVILEGES
        ALTER SYSTEM,
        ALTER USER, CREATE USER, DROP USER,
        GRANT ANY ROLE, GRANT ANY PRIVILEGE, GRANT ANY OBJECT PRIVILEGE,
        SELECT ANY TABLE, SELECT ANY DICTIONARY,
        EXEMPT ACCESS POLICY
    ONLY TOPLEVEL;

COMMENT ON AUDIT POLICY hmb_loc_crit_priv_use_pol IS
    'hold-my-beer: use of critical system privileges';

AUDIT POLICY hmb_loc_crit_priv_use_pol;

PROMPT == Step 3: verify - expected BY GRANTED ROLE / DBA and BY USER / ALL USERS
COLUMN policy_name    FORMAT A28
COLUMN enabled_option FORMAT A16
COLUMN entity_name    FORMAT A12
COLUMN entity_type    FORMAT A6
COLUMN audit_option   FORMAT A28
COLUMN option_type    FORMAT A18
SELECT policy_name, enabled_option, entity_name, entity_type, success, failure
  FROM audit_unified_enabled_policies
 WHERE policy_name LIKE 'HMB\_%' ESCAPE '\'
 ORDER BY policy_name;

SELECT policy_name, audit_option, audit_option_type AS option_type
  FROM audit_unified_policies
 WHERE policy_name LIKE 'HMB\_%' ESCAPE '\'
 ORDER BY policy_name, audit_option;

PROMPT == The way back (reset.sql runs it) ====================================
PROMPT NOAUDIT POLICY hmb_loc_priv_usr_act_pol BY USERS WITH GRANTED ROLES dba;
PROMPT NOAUDIT POLICY hmb_loc_crit_priv_use_pol;
PROMPT DROP AUDIT POLICY hmb_loc_priv_usr_act_pol;
PROMPT DROP AUDIT POLICY hmb_loc_crit_priv_use_pol;
-- EOF -------------------------------------------------------------------------
