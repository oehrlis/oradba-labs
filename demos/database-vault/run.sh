#!/usr/bin/env bash
# demos/database-vault - run one SQL script inside the dv26 container.
# Passwords come from the container environment (set from lab.env), never from argv.
# Usage: run.sh <script.sql> [container]   (default container: dv26-db26)
set -euo pipefail
script="${1:?script missing}"
c="${2:-dv26-db26}"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2016  # expands inside the container
{ cat "${dir}/${script}"; } | ${COMPOSE:-docker} exec -i "${c}" bash -c '
export ORAENV_ASK=NO
{
  printf "DEFINE dv_owner_pwd=\"%s\"\nDEFINE dv_acctmgr_pwd=\"%s\"\nDEFINE lab_admin_pwd=\"%s\"\nDEFINE lab_user_pwd=\"%s\"\n" \
    "${DV_OWNER_PWD}" "${DV_ACCTMGR_PWD}" "${LAB_ADMIN_PWD}" "${LAB_USER_PWD}"
  printf "SET SQLBLANKLINES ON LINESIZE 200 PAGESIZE 100 VERIFY OFF TRIMSPOOL ON\n"
  cat
} | "${ORACLE_HOME}/bin/sqlplus" -L /nolog'
