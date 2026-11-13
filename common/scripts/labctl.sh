#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: labctl.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.2.0
# Purpose....: Lab lifecycle behind the Makefile: list, up, down, reset,
#              rebuild, status, connect, verify for labs/<name>.
# Notes......: - Thin wrapper around docker compose (podman later, COMPOSE=).
#                The image does the database work: create or start, setup/
#                and startup/ hooks (Oracle container pattern, E8).
#              - Storage (E9): LAB_STORAGE=bind -> <LAB_DATA_BASE>/<lab>/<db>,
#                volume -> named volumes with nocopy. Sets the DB*_DATA
#                variables used in compose.yml.
#              - reset = FLASHBACK DATABASE to LAB_BASELINE (created by the
#                startup hook 90_lab_baseline.sh); rebuild = data gone, new.
#              - Passwords never go to argv: sqlplus reads them from stdin.
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-11-13  oes  Initial release                                    0.1.0
# 2026-11-13  oes  Mechanics per E8-E11: no own setup layer, storage  0.2.0
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Default Values
# ------------------------------------------------------------------------------
set -euo pipefail
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LABS_DIR="${REPO_ROOT}/labs"
VERSION="0.2.0"
DRY_RUN=${DRY_RUN:-"FALSE"}
PURGE=${PURGE:-"0"}
COMPOSE=${COMPOSE:-"docker"}
RESTORE_POINT="LAB_BASELINE"
READY_TIMEOUT=${READY_TIMEOUT:-3600} # first 19c start runs dbca

log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') INFO  $*"; }
log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') WARN  $*" >&2; }
log_error() { echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR $*" >&2; }
die() {
    log_error "$*"
    exit 1
}

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} <command> [LAB] [DB] [OPTIONS]

  Lab lifecycle for oradba-labs (${VERSION}).

Commands:
  list                 List all labs
  up <lab>             Start the lab, wait until healthy + baseline, verify
  down <lab>           Remove the containers (data stays; --purge removes it)
  reset <lab>          Flash all lab databases back to ${RESTORE_POINT}
  rebuild <lab>        Remove containers and data, start again (new databases)
  status <lab>         Containers, health, restore points, storage
  connect <lab> [db]   sqlplus / as sysdba into a lab database (db19|db26)
  verify <lab>         Checks and connect strings

Options:
  -h, --help           Show this help and exit
  -d, --dry-run        Show what would be done, change nothing
      --purge|--delete down: remove the data as well (same as PURGE=1)
  -y, --yes            Accepted for consistency - labctl never prompts

Environment:
  COMPOSE=docker (podman: second priority, untested), PURGE=1, DRY_RUN=TRUE

EOF
}

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
# Output..: absolute lab directory
# ------------------------------------------------------------------------------
lab_dir() {
    local lab="${1:-}"
    [[ -n "${lab}" ]] || die "no lab given - use: make <cmd> LAB=<name> (make list shows all)"
    [[ -f "${LABS_DIR}/${lab}/compose.yml" ]] || die "unknown lab '${lab}' - make list shows all labs"
    echo "${LABS_DIR}/${lab}"
}

gen_password() {
    printf 'Lab%s9x' "$(openssl rand -hex 7)"
}

# ------------------------------------------------------------------------------
# Function: ensure_env
# Purpose.: Create lab.env from lab.env.example (CHANGE_ME -> generated
#           password). An existing lab.env is never changed - keys missing in
#           it are appended from the example and named.
# Depends.: openssl
# ------------------------------------------------------------------------------
ensure_env() {
    local dir env example line key added=""
    dir=$(lab_dir "$1")
    env="${dir}/lab.env"
    example="${dir}/lab.env.example"
    [[ -f "${example}" ]] || die "missing ${example}"
    if [[ -f "${env}" ]] && grep -qE '^[A-Za-z0-9_]+=CHANGE_ME' "${env}"; then
        die "${env} still contains CHANGE_ME - set the passwords or delete the file"
    fi
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: would create or complete ${env}"
        return 0
    fi
    if [[ ! -f "${env}" ]]; then
        (umask 077 && : >"${env}")
        log_info "creating ${env} with generated passwords (mode 600, git-ignored)"
    fi
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ "${line}" =~ ^([A-Za-z0-9_]+)= ]] || continue
        key="${BASH_REMATCH[1]}"
        grep -qE "^${key}=" "${env}" && continue
        [[ "${line}" == *=CHANGE_ME* ]] && line="${key}=$(gen_password)"
        printf '%s\n' "${line}" >>"${env}"
        added+=" ${key}"
    done <"${example}"
    if [[ -n "${added}" ]]; then
        log_info "lab.env: added${added} (existing values unchanged)"
    fi
}

# ------------------------------------------------------------------------------
# Function: env_value
# Purpose.: Read one key from lab.env (no sourcing - values are not executed)
# Output..: value, a leading '~' expanded to $HOME
# ------------------------------------------------------------------------------
env_value() {
    local dir value
    dir=$(lab_dir "$1")
    value=$(grep -E "^$2=" "${dir}/lab.env" | tail -1 || true)
    value="${value#*=}"
    if [[ "${value}" == "~"* ]]; then
        value="${HOME}${value#\~}"
    fi
    printf '%s' "${value}"
}

# ------------------------------------------------------------------------------
# Function: storage_env
# Purpose.: Export the storage variables compose.yml uses (E9) and create the
#           host directories for bind mounts
# ------------------------------------------------------------------------------
storage_env() {
    local lab="$1" storage base
    storage=$(env_value "${lab}" LAB_STORAGE)
    base=$(env_value "${lab}" LAB_DATA_BASE)
    storage="${storage:-bind}"
    base="${base:-${HOME}/oradba-labs-data}/${lab}"
    export LAB_DATA_DIR="${base}"
    export LAB_SHARED="${base}/shared" DB19_LOGS="${base}/db19/logs" DB26_LOGS="${base}/db26/logs"
    case "${storage}" in
        bind)
            export DB19_DATA="${base}/db19/u01" DB26_ORADATA="${base}/db26/oradata"
            export DB26_DBCONFIG="${base}/db26/dbconfig" LAB_VOLOPT=""
            ;;
        volume)
            export DB19_DATA="db19data" DB26_ORADATA="db26oradata" DB26_DBCONFIG="db26dbconfig"
            export LAB_VOLOPT=":nocopy"
            ;;
        *) die "LAB_STORAGE=${storage} in lab.env - use bind or volume" ;;
    esac
    export LAB_STORAGE="${storage}"
    if [[ "${DRY_RUN}" != "TRUE" ]]; then
        mkdir -p "${LAB_SHARED}/dpdump" "${DB19_LOGS}" "${DB26_LOGS}"
        if [[ "${storage}" == "bind" ]]; then
            mkdir -p "${DB19_DATA}" "${DB26_ORADATA}" "${DB26_DBCONFIG}"
        fi
    fi
}

compose() {
    local lab="$1" dir
    shift
    dir=$(lab_dir "${lab}")
    storage_env "${lab}"
    ${COMPOSE} compose --project-name "oradba-labs-${lab}" --project-directory "${dir}" \
        --env-file "${dir}/lab.env" -f "${dir}/compose.yml" "$@"
}

# ------------------------------------------------------------------------------
# Function: containers
# Purpose.: Containers of a lab (compose project label), one per line
# ------------------------------------------------------------------------------
containers() {
    ${COMPOSE} ps -a --filter "label=com.docker.compose.project=oradba-labs-$1" \
        --format '{{.Names}}' | sort
}

sql_sysdba() {
    # shellcheck disable=SC2016  # expands inside the container
    ${COMPOSE} exec -i "$1" bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba'
}

has_baseline() {
    local n
    # shellcheck disable=SC2016  # v$restore_point is SQL, not a shell variable
    n=$(printf 'SET HEADING OFF FEEDBACK OFF\nSELECT COUNT(*) FROM v$restore_point WHERE name = '\''%s'\'';\n' \
        "${RESTORE_POINT}" | sql_sysdba "$1" 2>/dev/null | tr -d '[:space:]' || true)
    [[ "${n}" == "1" ]]
}

# ------------------------------------------------------------------------------
# Function: wait_ready
# Purpose.: Wait until every container is healthy (image healthcheck) and has
#           its LAB_BASELINE (last startup hook - setup and startup are done)
# ------------------------------------------------------------------------------
wait_ready() {
    local lab="$1" c state health waited=0 pending
    [[ "${DRY_RUN}" == "TRUE" ]] && return 0
    while true; do
        pending=""
        for c in $(containers "${lab}"); do
            state=$(${COMPOSE} inspect --format '{{.State.Status}}' "${c}")
            if [[ "${state}" != "running" ]]; then
                log_error "${c} is ${state} - last log lines:"
                ${COMPOSE} logs --tail 30 "${c}" >&2 || true
                return 1
            fi
            health=$(${COMPOSE} inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${c}")
            if [[ "${health}" != "healthy" ]]; then
                pending+=" ${c}(${health:-no healthcheck})"
            elif ! has_baseline "${c}"; then
                pending+=" ${c}(no ${RESTORE_POINT} yet)"
            fi
        done
        [[ -z "${pending}" ]] && return 0
        if ((waited >= READY_TIMEOUT)); then
            log_error "timeout after ${waited}s, not ready:${pending}"
            return 1
        fi
        if ((waited % 60 == 0)); then
            log_info "waiting for${pending} (${waited}s; first start creates the databases)"
        fi
        sleep 10
        waited=$((waited + 10))
    done
}

# ------------------------------------------------------------------------------
# Function: flashback
# Purpose.: Flash one database back to LAB_BASELINE and open all PDBs
# ------------------------------------------------------------------------------
flashback() {
    local c="$1"
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: would flash ${c} back to ${RESTORE_POINT}"
        return 0
    fi
    has_baseline "${c}" || die "${c}: no restore point ${RESTORE_POINT} - 'make rebuild LAB=...' creates a new lab"
    log_info "${c}: flashback database to ${RESTORE_POINT}"
    sql_sysdba "${c}" <<EOF
WHENEVER SQLERROR EXIT FAILURE
SHUTDOWN IMMEDIATE
STARTUP MOUNT
FLASHBACK DATABASE TO RESTORE POINT ${RESTORE_POINT};
ALTER DATABASE OPEN RESETLOGS;
ALTER PLUGGABLE DATABASE ALL OPEN;
EOF
}

# ------------------------------------------------------------------------------
# Function: purge_data
# Purpose.: Remove the data of a lab - named volumes or the bind directory.
#           Only ever below <LAB_DATA_BASE>/<lab>.
# ------------------------------------------------------------------------------
purge_data() {
    local lab="$1"
    storage_env "${lab}"
    log_warn "removing containers AND data of ${lab} (${LAB_STORAGE}: ${LAB_DATA_DIR})"
    run compose "${lab}" down --volumes --remove-orphans
    if [[ "${LAB_DATA_DIR}" == */"${lab}" && -d "${LAB_DATA_DIR}" ]]; then
        run rm -rf "${LAB_DATA_DIR}"
    fi
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
    local lab="$1"
    ensure_env "${lab}"
    storage_env "${lab}"
    log_info "starting lab ${lab}"
    run compose "${lab}" up -d
    log_info "storage: ${LAB_STORAGE} (${LAB_DATA_DIR})"
    wait_ready "${lab}" || die "lab ${lab} did not become ready - 'make status LAB=${lab}', logs under ${LAB_DATA_DIR}"
    cmd_verify "${lab}"
}

cmd_down() {
    local lab="$1" dir
    dir=$(lab_dir "${lab}")
    [[ -f "${dir}/lab.env" ]] || die "no lab.env for ${lab} - nothing to take down"
    storage_env "${lab}"
    if [[ "${PURGE}" == "1" ]]; then
        purge_data "${lab}"
    else
        run compose "${lab}" down --remove-orphans
        log_info "data of ${lab} kept (${LAB_DATA_DIR}) - 'make down LAB=${lab} PURGE=1' removes it"
    fi
}

cmd_rebuild() {
    local lab="$1"
    ensure_env "${lab}"
    purge_data "${lab}"
    cmd_up "${lab}"
}

cmd_reset() {
    local lab="$1" c start list pids=() pid failed=0
    ensure_env "${lab}"
    storage_env "${lab}"
    start=$(date +%s)
    list=$(containers "${lab}")
    [[ -n "${list}" ]] || die "lab ${lab} is not running - 'make up LAB=${lab}'"
    # parallel, but wait per PID: a bare 'wait' returns 0 even if a job failed
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
    ensure_env "${lab}"
    compose "${lab}" ps
    log_info "storage: ${LAB_STORAGE} (${LAB_DATA_DIR})"
    for c in $(containers "${lab}"); do
        [[ "$(${COMPOSE} inspect --format '{{.State.Status}}' "${c}")" == "running" ]] || continue
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
    if [[ -z "${c}" ]] || ! ${COMPOSE} inspect "${c}" >/dev/null 2>&1; then
        die "no container ${c:-for ${lab}} - running: $(containers "${lab}" | tr '\n' ' ')"
    fi
    # shellcheck disable=SC2016  # expands inside the container
    exec ${COMPOSE} exec -it "${c}" bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" / as sysdba'
}

cmd_verify() {
    local lab="$1" dir
    dir=$(lab_dir "${lab}")
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: would run ${dir}/verify.sh"
        return 0
    fi
    COMPOSE="${COMPOSE}" "${dir}/verify.sh"
}

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
        up | down | reset | rebuild | status | verify) "cmd_${cmd}" "${args[@]:-}" ;;
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
