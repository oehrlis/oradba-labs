#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: lab_verify.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.1.0
# Purpose....: Verify a running lab: container health, database state, Unified
#              Auditing, restore point, listener connection per PDB, expected
#              lab accounts - and print the connect strings.
# Notes......: - Called by labs/<name>/verify.sh. Reads the oradba.labs.* labels.
#              - The connection test logs in as SYSTEM through the listener
#                inside the container; the password comes from the container
#                environment via stdin, it never reaches argv.
#              - Exit 0 all checks passed, 1 at least one check failed.
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-11-13  oes  Initial release                                    0.1.0
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Default Values
# ------------------------------------------------------------------------------
set -euo pipefail
SCRIPT_NAME=$(basename "$0")
FAILED=0

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} <lab>

  Verify a running lab and print its connect strings.

Options:
  -h, --help      Show this help and exit

EOF
}

# lower-case without bash 4 (${var,,}): macOS ships bash 3.2
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

ok() { echo "  OK    $*"; }
fail() {
    echo "  FAIL  $*" >&2
    FAILED=1
}

# ------------------------------------------------------------------------------
# Function: q
# Purpose.: Run one SQL query as SYSDBA in a container, return trimmed result
# Args....: $1  container, $2  SQL statement (without terminator)
# Output..: query result, rows separated by blanks
# Depends.: docker
# Example.: q seclab-db19 "SELECT open_mode FROM v\$database"
# ------------------------------------------------------------------------------
q() {
    printf 'SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 200\n%s;\n' "$2" |
        docker exec -i "$1" bash -c '"${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba' |
        tr -s '[:space:]' ' ' | sed -e 's/^ //' -e 's/ $//'
}

# ------------------------------------------------------------------------------
# Function: listener_login
# Purpose.: Log in as SYSTEM through the container listener to a service
# Args....: $1  container, $2  service name
# Returns.: 0 login worked, 1 otherwise
# Depends.: docker
# Example.: listener_login seclab-db26 DEMOPDB
# ------------------------------------------------------------------------------
listener_login() {
    local out
    out=$(docker exec -i -e SVC="$2" "$1" bash -c \
        'printf "connect system/\"%s\"@//localhost:1521/%s\nSELECT '"'"'LOGIN_OK'"'"' FROM dual;\n" "${ORACLE_PWD}" "${SVC}" |
         "${ORACLE_HOME}/bin/sqlplus" -s -L /nolog' 2>&1 || true)
    [[ "${out}" == *LOGIN_OK* ]]
}

# ------------------------------------------------------------------------------
# Function: verify_container
# Purpose.: All checks for one lab database container
# Args....: $1  container
# Output..: OK/FAIL lines, connect strings
# Depends.: docker, nc
# ------------------------------------------------------------------------------
verify_container() {
    local c="$1" health port sid pdbs users pdb svc domain val
    port=$(docker inspect --format '{{index .Config.Labels "oradba.labs.port"}}' "${c}")
    sid=$(docker inspect --format '{{index .Config.Labels "oradba.labs.sid"}}' "${c}")
    pdbs=$(docker inspect --format '{{index .Config.Labels "oradba.labs.pdbs"}}' "${c}")
    users=$(docker inspect --format '{{index .Config.Labels "oradba.labs.users"}}' "${c}")
    echo "== ${c}"

    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${c}")
    if [[ "${health}" == "healthy" ]]; then ok "container healthy"; else fail "container health: ${health:-none}"; fi

    val=$(q "${c}" "SELECT version_full FROM v\$instance")
    ok "version ${val}"
    val=$(q "${c}" "SELECT open_mode || ' / ' || log_mode FROM v\$database")
    if [[ "${val}" == "READ WRITE / ARCHIVELOG" ]]; then ok "CDB ${sid}: ${val}"; else fail "CDB ${sid}: ${val}"; fi
    val=$(q "${c}" "SELECT value FROM v\$option WHERE parameter = 'Unified Auditing'")
    if [[ "${val}" == "TRUE" ]]; then ok "Unified Auditing pure mode"; else fail "Unified Auditing: ${val}"; fi
    val=$(q "${c}" "SELECT COUNT(*) FROM v\$restore_point WHERE name = 'LAB_BASELINE' AND guarantee_flashback_database = 'YES'")
    if [[ "${val}" == "1" ]]; then ok "restore point LAB_BASELINE (make reset)"; else fail "restore point LAB_BASELINE missing"; fi
    if nc -z 127.0.0.1 "${port}" 2>/dev/null; then ok "listener reachable on 127.0.0.1:${port}"; else fail "port 127.0.0.1:${port} not reachable"; fi

    domain=$(q "${c}" "SELECT value FROM v\$parameter WHERE name = 'db_domain'")
    for pdb in ${pdbs//,/ }; do
        val=$(q "${c}" "SELECT open_mode FROM v\$pdbs WHERE name = '${pdb}'")
        if [[ "${val}" == "READ WRITE" ]]; then ok "PDB ${pdb} READ WRITE"; else fail "PDB ${pdb}: ${val:-missing}"; fi
        svc="$(lower "${pdb}")${domain:+.${domain}}"
        if listener_login "${c}" "${svc}"; then ok "login SYSTEM@${svc} via listener"; else fail "login SYSTEM@${svc} via listener"; fi
    done
    if [[ -n "${users}" ]]; then
        pdb="${pdbs%%,*}"
        local u
        for u in ${users//,/ }; do
            val=$(q "${c}" "SELECT COUNT(*) FROM cdb_users u JOIN v\$pdbs p ON p.con_id = u.con_id WHERE p.name = '${pdb}' AND u.username = '${u}'")
            if [[ "${val}" == "1" ]]; then ok "account ${u} in ${pdb}"; else fail "account ${u} missing in ${pdb}"; fi
        done
    fi

    echo "  Connect (password in lab.env, never on the command line):"
    echo "    make connect LAB=${LAB} DB=${c#"${LAB}"-}    # sqlplus / as sysdba in the container"
    echo "    sql system@//localhost:${port}/$(lower "${sid}")${domain:+.${domain}}"
    for pdb in ${pdbs//,/ }; do
        echo "    sql system@//localhost:${port}/$(lower "${pdb}")${domain:+.${domain}}"
    done
}

main() {
    case "${1:-}" in
        -h | --help)
            usage
            exit 0
            ;;
        "")
            usage
            exit 1
            ;;
    esac
    LAB="$1"
    local list c
    list=$(docker ps --filter "label=com.docker.compose.project=oradba-labs-${LAB}" \
        --filter "label=oradba.labs.kind" --format '{{.Names}}' | sort)
    if [[ -z "${list}" ]]; then
        echo "ERROR: lab ${LAB} is not running - make up LAB=${LAB}" >&2
        exit 1
    fi
    for c in ${list}; do
        verify_container "${c}"
    done
    if ((FAILED)); then
        echo "RESULT: lab ${LAB} has failed checks (see FAIL above)" >&2
        exit 1
    fi
    echo "RESULT: lab ${LAB} ready"
}

main "$@"
# --- EOF ----------------------------------------------------------------------
