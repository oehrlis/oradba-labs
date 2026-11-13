#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: feature_probe.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.1.0
# Purpose....: Quick check whether an Oracle Database release carries a feature,
#              without building the demo - and what changed between releases
#              (--diff): traces in the home (error messages, oracle binary,
#              catalog scripts) and, for a running container, in the data
#              dictionary (parameters, hidden parameters, objects, columns).
# Notes......: - Image mode (-i) starts no database: it reads files of a LOCAL
#                image in a throwaway container (--pull never, --rm).
#              - Container mode (-c) adds read-only SQL as SYSDBA.
#              - --diff with exactly two targets: items only in A / only in B.
#                Compare like with like (image vs image, container vs container)
#                - an image has no dictionary categories.
#              - Traces prove the code is there, not that the feature works in
#                this edition - for "works" run the statement or the demo.
# Usage......: feature_probe.sh [-i IMAGE]... [-c CONTAINER]... [--diff] PATTERN
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
VERSION="0.1.0"
DRY_RUN=${DRY_RUN:-"FALSE"}
COMPOSE=${COMPOSE:-"docker"}
SAMPLES=5
DIFF="FALSE"
LIST="FALSE"
CATEGORIES="messages binary catalog parameters hidden objects columns"
TARGETS=()
WORK=""

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [-i IMAGE]... [-c CONTAINER]... [--diff] [-n N] PATTERN

  Check whether an Oracle Database release carries a feature, or what changed
  between two releases (${VERSION}). PATTERN: case-insensitive extended regex -
  be specific for the binary (e.g. 'mfa_|_mfa|multi.?factor', not 'mfa').

Options:
  -i, --image IMAGE       local image - files only, no database start
  -c, --container NAME    running container - files + data dictionary
      --diff              exactly two targets: items only in the first / second
  -l, --list              all items as sorted '<category> <item>' lines (for your own diff)
  -n, --samples N         sample lines per category (default ${SAMPLES})
  -d, --dry-run           show the targets, run nothing
  -y, --yes               accepted for consistency - never prompts
  -h, --help              show this help and exit

Examples:
  ${SCRIPT_NAME} -c base26-db26 'mfa'
  ${SCRIPT_NAME} --diff -i container-registry.oracle.com/database/free:23.26.2.0 \\
      -i container-registry.oracle.com/database/free:latest 'mfa|multi.?factor'
  ${SCRIPT_NAME} -c seclab-db19 -c seclab-db26 'sql_firewall'
  diff <(${SCRIPT_NAME} --list -i IMAGE_A 'mfa') <(${SCRIPT_NAME} --list -i IMAGE_B 'mfa')

EOF
}

log_error() { echo "ERROR: $*" >&2; }
cleanup() { if [[ -n "${WORK}" ]]; then rm -rf "${WORK}"; fi; }

# ------------------------------------------------------------------------------
# FILE_PROBE: runs inside image or container, prints "ITEM <category> <value>"
# for every match in oraus.msg, the oracle binary and rdbms/admin
# ------------------------------------------------------------------------------
# shellcheck disable=SC2016  # expands inside the container
FILE_PROBE='
set -u
p="${PROBE_PATTERN}"
oh="${ORACLE_HOME:-}"
if [ -z "$oh" ]; then echo "ERROR ORACLE_HOME unset in target"; exit 0; fi
echo "HOME $oh"
# 19c: line 1 "Release 19.0.0.0.0", line 2 "Version 19.27.0.0.0" - prefer Version
[ -x "$oh/bin/sqlplus" ] && "$oh/bin/sqlplus" -V 2>/dev/null | sed -nE "s/^Version ([0-9.]+).*/RELEASE \1/p; s/.*Release ([0-9.]+).*/RELEASE \1/p" | tail -1
msg="$oh/rdbms/mesg/oraus.msg"
# a message matches if its header line or its *Cause / *Action text matches
[ -f "$msg" ] && awk -v p="$p" '"'"'BEGIN { IGNORECASE = 1; lp = tolower(p) }
  /^[0-9]+,/ { if (hit && hdr != "") print hdr; hdr = $0; hit = 0 }
  { if (tolower($0) ~ lp) hit = 1 }
  END { if (hit && hdr != "") print hdr }'"'"' "$msg" | sed -E "s/[[:space:]]+/ /g; s/^/ITEM messages /"
[ -f "$oh/bin/oracle" ] && grep -aoiE "[a-z_\$#]*($p)[a-z_\$#]*" "$oh/bin/oracle" | tr "[:upper:]" "[:lower:]" | sort -u | sed "s/^/ITEM binary /"
[ -d "$oh/rdbms/admin" ] && grep -rliE --include="*.sql" --include="*.plb" "$p" "$oh/rdbms/admin" 2>/dev/null | sed "s|.*/||" | sort -u | sed "s/^/ITEM catalog /"
exit 0
'

# ------------------------------------------------------------------------------
# Function: sql_text
# Purpose.: Build the read-only dictionary probe for a pattern (host side)
# Output..: SQL*Plus script on stdout, printing "ITEM <category> <value>"
# ------------------------------------------------------------------------------
sql_text() {
    local p="${1//\'/\'\'}" # single quotes doubled for the SQL literal
    cat <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 400 TRIMSPOOL ON TAB OFF
SELECT 'VERSION '||version_full FROM v\$instance;
SELECT 'ITEM parameters '||name FROM v\$parameter WHERE REGEXP_LIKE(name, '${p}', 'i') ORDER BY 1;
SELECT 'ITEM hidden '||ksppinm FROM x\$ksppi WHERE SUBSTR(ksppinm, 1, 1) = '_' AND REGEXP_LIKE(ksppinm, '${p}', 'i') ORDER BY 1;
SELECT DISTINCT 'ITEM objects '||object_type||' '||object_name FROM dba_objects
 WHERE owner IN ('SYS', 'PUBLIC') AND object_type IN ('VIEW', 'PACKAGE', 'TABLE', 'SYNONYM', 'FUNCTION', 'PROCEDURE')
   AND REGEXP_LIKE(object_name, '${p}', 'i') ORDER BY 1;
SELECT 'ITEM columns '||table_name||'.'||column_name FROM dba_tab_columns
 WHERE owner = 'SYS' AND SUBSTR(table_name, 1, 4) = 'DBA_' AND REGEXP_LIKE(column_name, '${p}', 'i') ORDER BY 1;
EXIT
EOF
}

# ------------------------------------------------------------------------------
# Function: collect
# Purpose.: Probe one target, write its items to <dir>/<category> files
# Args....: $1 kind (image|container), $2 target, $3 pattern, $4 output dir
# ------------------------------------------------------------------------------
collect() {
    local kind="$1" target="$2" pattern="$3" dir="$4" out line rest cat
    mkdir -p "${dir}"
    if [[ "${kind}" == "image" ]]; then
        if ! out=$(${COMPOSE} run --rm --pull never --entrypoint bash -e PROBE_PATTERN="${pattern}" \
            "${target}" -c "${FILE_PROBE}" 2>&1); then
            log_error "cannot read image ${target} (local images only - pull it first)"
            return 1
        fi
    else
        if ! ${COMPOSE} inspect "${target}" >/dev/null 2>&1; then
            log_error "no container ${target}"
            return 1
        fi
        out=$(${COMPOSE} exec -i -e PROBE_PATTERN="${pattern}" "${target}" bash -c "${FILE_PROBE}" 2>&1 </dev/null)
        # shellcheck disable=SC2016  # expands inside the container
        out+=$'\n'$(sql_text "${pattern}" | ${COMPOSE} exec -i "${target}" \
            bash -c '"${ORACLE_HOME}/bin/sqlplus" -s -L / as sysdba' 2>&1 || true)
    fi
    : >"${dir}/version"
    for cat in ${CATEGORIES}; do : >"${dir}/${cat}"; done
    while IFS= read -r line; do
        case "${line}" in
            "ITEM "*)
                rest="${line#ITEM }"
                cat="${rest%% *}"
                printf '%s\n' "${rest#* }" >>"${dir}/${cat}"
                ;;
            "VERSION "*) printf '%s\n' "${line#VERSION }" >"${dir}/version" ;;
            "RELEASE "*) [[ -s "${dir}/version" ]] || printf '%s\n' "${line#RELEASE }" >"${dir}/version" ;;
            "HOME "*) ;;
            "ERROR "* | ORA-* | SP2-*) log_error "${target}: ${line}" ;;
        esac
    done <<<"${out}"
    for cat in ${CATEGORIES}; do sort -u -o "${dir}/${cat}" "${dir}/${cat}"; done
    # image mode has no dictionary - mark those categories as not applicable
    if [[ "${kind}" == "image" ]]; then
        for cat in parameters hidden objects columns; do printf 'n/a\n' >"${dir}/${cat}.na"; done
    fi
}

count_of() {
    local dir="$1" cat="$2"
    if [[ -f "${dir}/${cat}.na" ]]; then
        printf -- '-'
    else
        grep -c . "${dir}/${cat}" || true
    fi
}

report() {
    local label="$1" dir="$2" cat
    echo "== ${label} ($(cat "${dir}/version" 2>/dev/null || echo '?'))"
    for cat in ${CATEGORIES}; do
        [[ -f "${dir}/${cat}.na" ]] && continue
        printf '  %-10s %s\n' "${cat}" "$(count_of "${dir}" "${cat}")"
        head -"${SAMPLES}" "${dir}/${cat}" | sed 's/^/             - /'
    done
}

diff_report() {
    local a="$1" la="$2" b="$3" lb="$4" cat only_a only_b
    echo "== diff: A = ${la} ($(cat "${a}/version")), B = ${lb} ($(cat "${b}/version"))"
    for cat in ${CATEGORIES}; do
        if [[ -f "${a}/${cat}.na" || -f "${b}/${cat}.na" ]]; then continue; fi
        only_a=$(comm -23 "${a}/${cat}" "${b}/${cat}")
        only_b=$(comm -13 "${a}/${cat}" "${b}/${cat}")
        printf '  %-10s only A: %s, only B: %s\n' "${cat}" \
            "$(printf '%s' "${only_a}" | grep -c . || true)" "$(printf '%s' "${only_b}" | grep -c . || true)"
        if [[ -n "${only_a}" ]]; then printf '%s\n' "${only_a}" | sed 's/^/             - A /'; fi
        if [[ -n "${only_b}" ]]; then printf '%s\n' "${only_b}" | sed 's/^/             + B /'; fi
    done
}

main() {
    local pattern="" t i=0 dirs=() labels=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i | --image)
                TARGETS+=("image:${2:?missing image}")
                shift 2
                ;;
            -c | --container)
                TARGETS+=("container:${2:?missing container}")
                shift 2
                ;;
            --diff)
                DIFF="TRUE"
                shift
                ;;
            -l | --list)
                LIST="TRUE"
                shift
                ;;
            -n | --samples)
                SAMPLES="${2:?missing number}"
                shift 2
                ;;
            -d | --dry-run)
                DRY_RUN="TRUE"
                shift
                ;;
            -y | --yes) shift ;;
            -h | --help)
                usage
                exit 0
                ;;
            -*)
                log_error "unknown option $1"
                usage
                exit 1
                ;;
            *)
                pattern="$1"
                shift
                ;;
        esac
    done
    [[ -n "${pattern}" ]] || { log_error "PATTERN missing"; usage; exit 1; }
    [[ ${#TARGETS[@]} -gt 0 ]] || { log_error "no target - use -i IMAGE or -c CONTAINER"; exit 1; }
    if [[ "${DIFF}" == "TRUE" && ${#TARGETS[@]} -ne 2 ]]; then
        log_error "--diff needs exactly two targets"
        exit 1
    fi
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        echo "DRY-RUN: pattern '${pattern}' on: ${TARGETS[*]}"
        exit 0
    fi
    WORK=$(mktemp -d)
    trap cleanup EXIT
    for t in "${TARGETS[@]}"; do
        i=$((i + 1))
        dirs+=("${WORK}/${i}")
        labels+=("${t#*:}")
        collect "${t%%:*}" "${t#*:}" "${pattern}" "${WORK}/${i}" || exit 1
    done
    if [[ "${LIST}" == "TRUE" ]]; then
        for i in "${!dirs[@]}"; do
            echo "# ${labels[${i}]} ($(cat "${dirs[${i}]}/version"))"
            for t in ${CATEGORIES}; do
                [[ -f "${dirs[${i}]}/${t}.na" ]] && continue
                sed "s/^/${t} /" "${dirs[${i}]}/${t}"
            done
        done
        exit 0
    fi
    if [[ "${DIFF}" == "TRUE" ]]; then
        diff_report "${dirs[0]}" "${labels[0]}" "${dirs[1]}" "${labels[1]}"
        exit 0
    fi
    for i in "${!dirs[@]}"; do report "${labels[${i}]}" "${dirs[${i}]}"; done
    echo
    echo "| Target | Version | Messages | Binary | Catalog | Parameters | Hidden | Objects | Columns |"
    echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    for i in "${!dirs[@]}"; do
        printf '| %s | %s' "${labels[${i}]}" "$(cat "${dirs[${i}]}/version")"
        for t in ${CATEGORIES}; do printf ' | %s' "$(count_of "${dirs[${i}]}" "${t}")"; done
        printf ' |\n'
    done
}

main "$@"
# --- EOF ----------------------------------------------------------------------
