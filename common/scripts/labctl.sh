#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: labctl.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.1.0
# Purpose....: Lab lifecycle for oradba-labs: list, up, down, reset, status,
#              connect and verify a lab under labs/<name>.
# Notes......: - Called by the Makefile (make <cmd> LAB=<name>), usable directly.
#              - A lab is labs/<name>/compose.yml + lab.env. Every database
#                service carries the labels oradba.labs.* (kind, sid, pdbs,
#                port, datadir) - this script reads them, it knows no lab.
#              - Reset = FLASHBACK DATABASE to the guaranteed restore point
#                LAB_BASELINE, created by 'up' once the lab is ready.
#              - Passwords never go to argv: they reach sqlplus via stdin.
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LABS_DIR="${REPO_ROOT}/labs"
VERSION="0.1.0"
DRY_RUN=${DRY_RUN:-"FALSE"}
PURGE=${PURGE:-"0"}
RESTORE_POINT="LAB_BASELINE"
READY_TIMEOUT=${READY_TIMEOUT:-3600}   # first 19c start runs dbca, allow 60 min
READY_MARKER="/tmp/oradba-labs.ready"

# ------------------------------------------------------------------------------
# Function: log_info, log_warn, log_error, die
# Purpose.: Consistent logging to stdout/stderr
# ------------------------------------------------------------------------------
log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') INFO  $*"; }
log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') WARN  $*" >&2; }
log_error() { echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR $*" >&2; }
die() {
    log_error "$*"
    exit 1
}

# ------------------------------------------------------------------------------
# usage: show script usage
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} <command> [LAB] [OPTIONS]

  Lab lifecycle for oradba-labs (${VERSION}).

Commands:
  list                 List all labs with their purpose
  up <lab>             Start the lab, wait until ready, create baseline, verify
  down <lab>           Remove the lab containers (data volumes stay)
  reset <lab>          Flash all lab databases back to ${RESTORE_POINT}
  status <lab>         Show containers, health and restore points
  connect <lab> [db]   sqlplus / as sysdba into a lab database (default: first)
  verify <lab>         Health and connection check, prints connect strings

Options:
  -h, --help           Show this help and exit
  -d, --dry-run        Show what would be done, change nothing
      --purge|--delete down: remove the data volumes as well (same as PURGE=1)
  -y, --yes            Accepted for consistency - labctl never prompts

Examples:
  ${SCRIPT_NAME} up seclab
  ${SCRIPT_NAME} connect seclab db26
  PURGE=1 ${SCRIPT_NAME} down seclab

EOF
}

# ------------------------------------------------------------------------------
# Function: run
# Purpose.: Execute a state-changing command, or only print it in dry-run mode
# Args....: $@  command and arguments
# Returns.: exit code of the command (0 in dry-run)
# Output..: command output
# Depends.: -
# Example.: run docker compose down
# ------------------------------------------------------------------------------
run() {
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: $*"
    else
        "$@"
    fi
}

# ------------------------------------------------------------------------------
# Function: lab_dir
# Purpose.: Resolve and validate the directory of a lab
# Args....: $1  lab  lab name
# Returns.: 0 lab exists, exits otherwise
# Output..: absolute lab directory
# Depends.: -
# Example.: dir=$(lab_dir seclab)
# ------------------------------------------------------------------------------
lab_dir() {
    local lab="${1:-}"
    [[ -n "${lab}" ]] || die "no lab given - use: make <cmd> LAB=<name> (make list shows all)"
    [[ -f "${LABS_DIR}/${lab}/compose.yml" ]] || die "unknown lab '${lab}' - make list shows all labs"
    echo "${LABS_DIR}/${lab}"
}

# ------------------------------------------------------------------------------
# Function: gen_password
# Purpose.: Generate an Oracle-compatible lab password (upper, lower, digit)
# Args....: -
# Returns.: 0
# Output..: password on stdout
# Depends.: openssl
# Example.: pwd=$(gen_password)
# ------------------------------------------------------------------------------
gen_password() {
    printf 'Lab%s9x' "$(openssl rand -hex 7)"
}

# ------------------------------------------------------------------------------
# Function: ensure_env
# Purpose.: Create lab.env from lab.env.example with generated passwords,
#           if it does not exist yet. An existing lab.env is never touched.
# Args....: $1  lab  lab name
# Returns.: 0
# Output..: what was created
# Depends.: openssl, sed
# Example.: ensure_env seclab
# ------------------------------------------------------------------------------
ensure_env() {
    local dir
    dir=$(lab_dir "$1")
    local env="${dir}/lab.env" example="${dir}/lab.env.example"
    if [[ -f "${env}" ]]; then
        grep -qE '^[A-Za-z0-9_]+=CHANGE_ME' "${env}" && die "${env} still contains CHANGE_ME - set the passwords or delete the file"
        return 0
    fi
    [[ -f "${example}" ]] || die "missing ${example}"
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: would create ${env} from lab.env.example with generated passwords"
        return 0
    fi
    local line out=""
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == *=CHANGE_ME* ]]; then
            line="${line%%=*}=$(gen_password)"
        fi
        out+="${line}"$'\n'
    done <"${example}"
    (umask 077 && printf '%s' "${out}" >"${env}")
    log_info "created ${env} with generated passwords (mode 600, not tracked by git)"
}

# ------------------------------------------------------------------------------
# Function: compose
# Purpose.: docker compose for a lab with its project name and lab.env
# Args....: $1  lab  lab name, rest: compose arguments
# Returns.: exit code of docker compose
# Output..: docker compose output
# Depends.: docker compose v2
# Example.: compose seclab ps
# ------------------------------------------------------------------------------
compose() {
    local lab="$1"
    shift
    local dir
    dir=$(lab_dir "${lab}")
    docker compose --project-name "oradba-labs-${lab}" --project-directory "${dir}" \
        --env-file "${dir}/lab.env" -f "${dir}/compose.yml" "$@"
}

# ------------------------------------------------------------------------------
# Function: containers
# Purpose.: List the database containers of a running lab (label oradba.labs.kind)
# Args....: $1  lab  lab name
# Returns.: 0
# Output..: container names, one per line
# Depends.: docker
# Example.: for c in $(containers seclab); do ...; done
# ------------------------------------------------------------------------------
containers() {
    docker ps -a --filter "label=com.docker.compose.project=oradba-labs-$1" \
        --filter "label=oradba.labs.kind" --format '{{.Names}}' | sort
}

# ------------------------------------------------------------------------------
# Function: label
# Purpose.: Read one oradba.labs.* label of a container
# Args....: $1  container, $2  label suffix (kind, sid, pdbs, port, datadir)
# Returns.: 0
# Output..: label value
# Depends.: docker
# Example.: label seclab-db19 port
# ------------------------------------------------------------------------------
label() {
    docker inspect --format "{{index .Config.Labels \"oradba.labs.$2\"}}" "$1"
}

# ------------------------------------------------------------------------------
# Function: sql_sysdba
# Purpose.: Run SQL from stdin as SYSDBA inside a lab container
# Args....: $1  container
# Returns.: exit code of sqlplus
# Output..: sqlplus output
# Depends.: docker
# Example.: echo "select 1 from dual;" | sql_sysdba seclab-db19
# ------------------------------------------------------------------------------
sql_sysdba() {
    docker exec -i "$1" bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba'
}

# ------------------------------------------------------------------------------
# Function: wait_ready
# Purpose.: Wait until every lab container is healthy and its startup hooks ran
# Args....: $1  lab  lab name
# Returns.: 0 all ready, 1 timeout or container stopped
# Output..: progress lines
# Depends.: docker
# Example.: wait_ready seclab
# ------------------------------------------------------------------------------
wait_ready() {
    local lab="$1" c state health waited=0 pending
    [[ "${DRY_RUN}" == "TRUE" ]] && return 0
    while true; do
        pending=""
        for c in $(containers "${lab}"); do
            state=$(docker inspect --format '{{.State.Status}}' "${c}")
            [[ "${state}" == "running" ]] || {
                log_error "${c} is ${state} - last log lines:"
                docker logs --tail 30 "${c}" >&2 || true
                return 1
            }
            health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${c}")
            if [[ "${health}" != "healthy" ]] || ! docker exec "${c}" test -f "${READY_MARKER}"; then
                pending+=" ${c}(${health:-none})"
            fi
        done
        [[ -z "${pending}" ]] && return 0
        if ((waited >= READY_TIMEOUT)); then
            log_error "timeout after ${waited}s, not ready:${pending}"
            return 1
        fi
        ((waited % 60 == 0)) && log_info "waiting for${pending} (${waited}s, first start creates the databases)"
        sleep 10
        waited=$((waited + 10))
    done
}

# ------------------------------------------------------------------------------
# Function: provision
# Purpose.: Run the lab setup hooks (/opt/oradba-labs/setup) once, after the
#           container is ready. Done here and not by the image init: the Free
#           image skips setup hooks for its prebuilt database, ora_db runs them
#           with the PDB still mounted and ignores failures. Marker in the data
#           volume: survives down/up, disappears with PURGE=1.
# Args....: $1  container
# Returns.: 0 hooks ran or were not needed, 1 a hook failed
# Output..: hook output
# Depends.: docker
# Example.: provision seclab-db26
# ------------------------------------------------------------------------------
provision() {
    local c="$1" datadir marker
    datadir=$(label "${c}" datadir)
    marker="${datadir}/.oradba-labs.setup"
    if docker exec "${c}" test -f "${marker}"; then
        return 0
    fi
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: would run the setup hooks in ${c}"
        return 0
    fi
    log_info "${c}: running setup hooks (first start)"
    docker exec "${c}" bash -c '
        set -euo pipefail
        export ORAENV_ASK=NO
        for f in /opt/oradba-labs/setup/*; do
            case "${f}" in
                *.sh) echo "- running ${f}"; bash "${f}" ;;
                *.sql) echo "- running ${f}"; "${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba @"${f}" </dev/null ;;
                *) echo "- ignoring ${f}" ;;
            esac
        done' || {
        log_error "${c}: a setup hook failed - fix it, then 'make down LAB=... PURGE=1' and 'make up' again"
        return 1
    }
    docker exec "${c}" touch "${marker}"
    # a baseline from before the setup would reset the lab to an empty state
    sql_sysdba "${c}" <<EOF
SET FEEDBACK OFF
BEGIN
  FOR r IN (SELECT name FROM v\$restore_point WHERE name = '${RESTORE_POINT}') LOOP
    EXECUTE IMMEDIATE 'DROP RESTORE POINT ${RESTORE_POINT}';
  END LOOP;
END;
/
EOF
    log_info "${c}: setup hooks done"
}

# ------------------------------------------------------------------------------
# Function: baseline
# Purpose.: Create the guaranteed restore point LAB_BASELINE if it is missing.
#           Configures a recovery area under the data volume if none is set.
# Args....: $1  container
# Returns.: 0 restore point exists afterwards
# Output..: sqlplus output
# Depends.: docker, sqlplus in the container
# Example.: baseline seclab-db19
# ------------------------------------------------------------------------------
baseline() {
    local c="$1" datadir
    datadir=$(label "${c}" datadir)
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: would create restore point ${RESTORE_POINT} in ${c}"
        return 0
    fi
    docker exec "${c}" mkdir -p "${datadir}/fra"
    sql_sysdba "${c}" <<EOF
WHENEVER SQLERROR EXIT FAILURE
SET SERVEROUTPUT ON FEEDBACK OFF HEADING OFF
DECLARE
  l_log  v\$database.log_mode%TYPE;
  l_fra  v\$parameter.value%TYPE;
  l_rp   NUMBER;
BEGIN
  SELECT log_mode INTO l_log FROM v\$database;
  IF l_log <> 'ARCHIVELOG' THEN
    RAISE_APPLICATION_ERROR(-20001, 'database is not in ARCHIVELOG mode - required for the lab baseline');
  END IF;
  SELECT value INTO l_fra FROM v\$parameter WHERE name = 'db_recovery_file_dest';
  IF l_fra IS NULL THEN
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET db_recovery_file_dest_size = 20G SCOPE=BOTH';
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET db_recovery_file_dest = ''${datadir}/fra'' SCOPE=BOTH';
    dbms_output.put_line('- recovery area set to ${datadir}/fra (20G)');
  END IF;
  SELECT COUNT(*) INTO l_rp FROM v\$restore_point WHERE name = '${RESTORE_POINT}';
  IF l_rp = 0 THEN
    EXECUTE IMMEDIATE 'CREATE RESTORE POINT ${RESTORE_POINT} GUARANTEE FLASHBACK DATABASE';
    dbms_output.put_line('- restore point ${RESTORE_POINT} created');
  ELSE
    dbms_output.put_line('- restore point ${RESTORE_POINT} exists');
  END IF;
END;
/
EOF
}

# ------------------------------------------------------------------------------
# Function: flashback
# Purpose.: Flash a lab database back to LAB_BASELINE and open all PDBs
# Args....: $1  container
# Returns.: 0 success
# Output..: sqlplus output
# Depends.: docker, sqlplus in the container
# Example.: flashback seclab-db26
# ------------------------------------------------------------------------------
flashback() {
    local c="$1"
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: would flash ${c} back to ${RESTORE_POINT}"
        return 0
    fi
    local rp
    # shellcheck disable=SC2016  # v$restore_point is SQL, not a shell variable
    rp=$(printf 'SET HEADING OFF FEEDBACK OFF\nSELECT COUNT(*) FROM v$restore_point WHERE name = '\''%s'\'';\n' \
        "${RESTORE_POINT}" | sql_sysdba "${c}" | tr -d '[:space:]')
    [[ "${rp}" == "1" ]] || die "${c}: no restore point ${RESTORE_POINT} - run 'make up LAB=...' first"
    log_info "${c}: flashback database to ${RESTORE_POINT}"
    docker exec "${c}" rm -f "${READY_MARKER}"
    sql_sysdba "${c}" <<EOF
WHENEVER SQLERROR EXIT FAILURE
SHUTDOWN IMMEDIATE
STARTUP MOUNT
FLASHBACK DATABASE TO RESTORE POINT ${RESTORE_POINT};
ALTER DATABASE OPEN RESETLOGS;
ALTER PLUGGABLE DATABASE ALL OPEN;
EOF
    docker exec "${c}" touch "${READY_MARKER}"
}

# ------------------------------------------------------------------------------
# Commands
# ------------------------------------------------------------------------------
cmd_list() {
    local d name desc
    printf '%s\n' "LAB DESCRIPTION"
    for d in "${LABS_DIR}"/*/; do
        name=$(basename "${d}")
        [[ -f "${d}/compose.yml" ]] || continue
        desc=$(sed -n '1s/^# *[^ ]* *- *//p' "${d}/README.md" 2>/dev/null || true)
        printf '%s %s\n' "${name}" "${desc:-?}"
    done
}

cmd_up() {
    local lab="$1" c
    ensure_env "${lab}"
    log_info "starting lab ${lab}"
    run compose "${lab}" up -d
    wait_ready "${lab}" || die "lab ${lab} did not become ready - see 'make status LAB=${lab}' and docker logs"
    # all setups first: a baseline is only taken once every database is set up
    for c in $(containers "${lab}"); do
        provision "${c}" || die "setup of ${c} failed"
    done
    for c in $(containers "${lab}"); do
        baseline "${c}"
    done
    cmd_verify "${lab}"
}

cmd_down() {
    local lab="$1" dir
    dir=$(lab_dir "${lab}")
    [[ -f "${dir}/lab.env" ]] || die "no lab.env for ${lab} - nothing to take down"
    if [[ "${PURGE}" == "1" ]]; then
        log_warn "PURGE=1: removing containers AND data volumes of ${lab}"
        run compose "${lab}" down --volumes --remove-orphans
    else
        run compose "${lab}" down --remove-orphans
        log_info "data volumes of ${lab} kept - 'make down LAB=${lab} PURGE=1' removes them"
    fi
}

cmd_reset() {
    local lab="$1" c start
    lab_dir "${lab}" >/dev/null
    start=$(date +%s)
    local list
    list=$(containers "${lab}")
    [[ -n "${list}" ]] || die "lab ${lab} is not running - 'make up LAB=${lab}'"
    # parallel, but wait per PID: a bare 'wait' returns 0 even if a job failed
    local pids=() pid failed=0
    for c in ${list}; do
        flashback "${c}" &
        pids+=("$!")
    done
    for pid in "${pids[@]}"; do
        wait "${pid}" || failed=1
    done
    ((failed == 0)) || die "reset of ${lab} failed - see the sqlplus output above"
    wait_ready "${lab}" || die "lab ${lab} not ready after reset"
    log_info "reset of ${lab} done in $(($(date +%s) - start))s"
    cmd_verify "${lab}"
}

cmd_status() {
    local lab="$1" c
    compose "${lab}" ps
    for c in $(containers "${lab}"); do
        [[ "$(docker inspect --format '{{.State.Status}}' "${c}")" == "running" ]] || continue
        echo "--- ${c}: restore points"
        # shellcheck disable=SC2016  # v$restore_point is SQL, not a shell variable
        printf 'SET LINESIZE 120 FEEDBACK OFF\nCOLUMN name FORMAT A20\nSELECT name, guarantee_flashback_database gfd, time FROM v$restore_point;\n' |
            sql_sysdba "${c}" || true
    done
}

cmd_connect() {
    local lab="$1" db="${2:-}" c
    if [[ -n "${db}" ]]; then
        c="${lab}-${db}"
    else
        c=$(containers "${lab}" | head -1)
    fi
    if [[ -z "${c}" ]] || ! docker inspect "${c}" >/dev/null 2>&1; then
        die "no container ${c:-for ${lab}} - running: $(containers "${lab}" | tr '\n' ' ')"
    fi
    exec docker exec -it "${c}" bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" / as sysdba'
}

cmd_verify() {
    local lab="$1"
    local dir
    dir=$(lab_dir "${lab}")
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: would run ${dir}/verify.sh"
        return 0
    fi
    "${dir}/verify.sh"
}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
main() {
    local cmd="" args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            -d | --dry-run)
                DRY_RUN="TRUE"
                shift
                ;;
            --purge | --delete)
                PURGE="1"
                shift
                ;;
            -y | --yes) shift ;;
            -*) die "unknown option $1" ;;
            *)
                if [[ -z "${cmd}" ]]; then cmd="$1"; else args+=("$1"); fi
                shift
                ;;
        esac
    done
    case "${cmd}" in
        list) cmd_list ;;
        up | down | reset | status | verify) "cmd_${cmd}" "${args[@]:-}" ;;
        connect) cmd_connect "${args[@]:-}" ;;
        "")
            usage
            exit 1
            ;;
        *) die "unknown command '${cmd}' - see ${SCRIPT_NAME} --help" ;;
    esac
}

main "$@"
# --- EOF ----------------------------------------------------------------------
