#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: sqlnet_alv.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.1.0
# Purpose....: Show, back up, set and restore SQLNET.ALLOWED_LOGON_VERSION_SERVER
#              in the server sqlnet.ora for the verifier demo.
# Notes......: - Based on oracle-free-labs config/common/scripts/set_sqlnet_param.sh
#                (awk parameter parsing, inode-preserving write).
#              - Runs inside the DB container as oracle, called via SQL*Plus HOST
#                from setup.sql, solution.sql, check.sql and reset.sql.
#              - File: $SQLNET_FILE, else $TNS_ADMIN/sqlnet.ora, else
#                $ORACLE_HOME/network/admin/sqlnet.ora.
#                verified 2026-11-13 on 19.27 / 23.26.3: bequeath and listener-spawned
#                server processes read the same file ($ORACLE_HOME/network/admin
#                is a symlink to the TNS_ADMIN/dbconfig copy in both images).
#              - sqlnet.ora is a file: 'make reset' (flashback) does not revert it.
#                'backup' saves it once, 'restore' puts it back (or removes it if
#                it did not exist before) - every change prints old -> new.
# Usage......: sqlnet_alv.sh [-n|--dry-run] show | backup | set <11|12|12a> | restore
#              -h|--help usage; -y|--yes accepted (never prompts); --delete n/a
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-11-13  oes  Initial release                                    0.1.0
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_NAME="${0##*/}"
PARAM="SQLNET.ALLOWED_LOGON_VERSION_SERVER"
SQLNET_FILE="${SQLNET_FILE:-${TNS_ADMIN:-${ORACLE_HOME:?ORACLE_HOME not set}/network/admin}/sqlnet.ora}"
BACKUP="${SQLNET_FILE}.hmb-verifier.bak"
ABSENT="${SQLNET_FILE}.hmb-verifier.absent"
DRY_RUN="FALSE"

# ------------------------------------------------------------------------------
# Function: usage
# Purpose.: Print usage
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [-n|--dry-run] [-y|--yes] show | backup | set <11|12|12a> | restore

  Manage ${PARAM} in ${SQLNET_FILE}
  (override with SQLNET_FILE=...) for the hold-my-beer verifier demo.

  -n, --dry-run   show what would change, write nothing
  -y, --yes       accepted for consistency - never prompts
  -h, --help      this help
EOF
}

# ------------------------------------------------------------------------------
# Function: dry
# Purpose.: Return 0 (and print) when in dry-run mode
# ------------------------------------------------------------------------------
dry() {
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        echo "DRY-RUN: $*"
        return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# Function: die
# Purpose.: Print an error and exit 1
# ------------------------------------------------------------------------------
die() {
    echo "ERROR: ${SCRIPT_NAME}: $*" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Function: current_value
# Purpose.: Print the current value of PARAM (empty if not set or no file)
# ------------------------------------------------------------------------------
current_value() {
    [[ -f "${SQLNET_FILE}" ]] || return 0
    awk -v key="${PARAM}" '
        BEGIN { key = toupper(key) }
        /^[[:space:]]*#/ { next }
        {
            split($0, kv, "=")
            name = toupper(kv[1]); gsub(/[[:space:]]/, "", name)
            if (name == key) {
                value = substr($0, index($0, "=") + 1)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                found = value
            }
        }
        END { print found }' "${SQLNET_FILE}"
}

# ------------------------------------------------------------------------------
# Function: write_value
# Purpose.: Replace PARAM with value $1, or append it; keeps inode and mode
# ------------------------------------------------------------------------------
write_value() {
    local tmp
    tmp="$(mktemp)"
    [[ -f "${SQLNET_FILE}" ]] || touch "${SQLNET_FILE}"
    awk -v key="${PARAM}" -v val="$1" '
        BEGIN { key = toupper(key); done = 0 }
        /^[[:space:]]*#/ { print; next }
        {
            split($0, kv, "=")
            name = toupper(kv[1]); gsub(/[[:space:]]/, "", name)
            if (name == key) {
                if (!done) { print key " = " val; done = 1 }
                next
            }
            print
        }
        END { if (!done) print key " = " val }' "${SQLNET_FILE}" >"${tmp}"
    cat "${tmp}" >"${SQLNET_FILE}"
    rm -f "${tmp}"
}

# ------------------------------------------------------------------------------
# Function: show_value
# Purpose.: Print file and current value
# ------------------------------------------------------------------------------
show_value() {
    local v
    v="$(current_value)"
    echo "INFO: ${SQLNET_FILE}: ${PARAM} = ${v:-<not set> (release default 12)}"
}

cmd_backup() {
    if [[ -e "${BACKUP}" || -e "${ABSENT}" ]]; then
        echo "INFO: backup from an earlier setup kept (${BACKUP##*/} or ${ABSENT##*/}) - reset.sql restores it"
    elif dry "would back up ${SQLNET_FILE}"; then
        return 0
    elif [[ -f "${SQLNET_FILE}" ]]; then
        cp -p "${SQLNET_FILE}" "${BACKUP}"
        echo "INFO: saved ${SQLNET_FILE} -> ${BACKUP}"
    else
        mkdir -p "$(dirname "${SQLNET_FILE}")"
        touch "${ABSENT}"
        echo "INFO: ${SQLNET_FILE} does not exist - marker ${ABSENT##*/} written, restore removes the file"
    fi
}

cmd_set() {
    local new="${1:-}" old
    case "${new}" in
        11 | 12 | 12a) ;;
        *) die "value must be 11, 12 or 12a, got '${new}'" ;;
    esac
    [[ -e "${BACKUP}" || -e "${ABSENT}" ]] || die "no backup of ${SQLNET_FILE} - run '${SCRIPT_NAME} backup' first"
    old="$(current_value)"
    if [[ "${old}" == "${new}" ]]; then
        echo "INFO: ${PARAM} = ${new} (unchanged)"
        return 0
    fi
    if dry "would set ${PARAM}: '${old:-<not set>}' -> '${new}'"; then
        return 0
    fi
    write_value "${new}"
    echo "INFO: ${PARAM}: '${old:-<not set>}' -> '${new}' in ${SQLNET_FILE}"
    echo "INFO: new server processes read it at connect - reconnect before the next ALTER USER"
}

cmd_restore() {
    local old new
    old="$(current_value)"
    if dry "would restore ${SQLNET_FILE} (current '${old:-<not set>}')"; then
        return 0
    elif [[ -e "${BACKUP}" ]]; then
        cat "${BACKUP}" >"${SQLNET_FILE}"
        rm -f "${BACKUP}"
        new="$(current_value)"
        echo "INFO: restored ${SQLNET_FILE} from ${BACKUP##*/}: '${old:-<not set>}' -> '${new:-<not set>}'"
    elif [[ -e "${ABSENT}" ]]; then
        rm -f "${SQLNET_FILE}" "${ABSENT}"
        echo "INFO: removed ${SQLNET_FILE} (did not exist before setup): '${old:-<not set>}' -> '<not set>'"
    else
        echo "WARN: no backup/marker for ${SQLNET_FILE} - nothing restored, value '${old:-<not set>}'" >&2
        echo "WARN: edit ${PARAM} in ${SQLNET_FILE} by hand if it is not what the lab expects" >&2
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n | --dry-run)
                DRY_RUN="TRUE"
                shift
                ;;
            -y | --yes) shift ;;
            -h | --help)
                usage
                return 0
                ;;
            -*) die "unknown option $1 - see --help" ;;
            *) break ;;
        esac
    done
    case "${1:-}" in
        show) show_value ;;
        backup) cmd_backup ;;
        set) cmd_set "${2:-}" ;;
        restore) cmd_restore ;;
        *) die "usage: ${SCRIPT_NAME} show | backup | set <11|12|12a> | restore" ;;
    esac
}

main "$@"
# --- EOF ----------------------------------------------------------------------
