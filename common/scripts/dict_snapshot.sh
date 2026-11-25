#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: dict_snapshot.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-25
# Version....: 0.1.0
# Purpose....: Snapshot hook logic for the dictionary labs (dict26, dict19):
#              dictionary export (CDB root + first PDB) as oracle-check
#              snapshot JSON, parse smoke test as KBCHK_ scratch user,
#              lab-meta.json with version / RU / behind_current / resources.
# Notes......: - Called by labs/<lab>/hooks/snapshot.sh (via 'make snapshot').
#                Environment from labctl: LAB, LAB_CONTAINER, LAB_OUT,
#                LAB_DATA_DIR, REPO_ROOT, COMPOSE.
#              - ORACLE_CHECK_EXPORT set: that command does the export (it gets
#                LAB_ALIAS, LAB_CONTAINER, LAB_OUT, LAB_PDB in its environment),
#                otherwise the built-in export of common/sql/dict_snapshot.sql
#                writes <alias>-<version>.json (root) and
#                <alias>_pdb-<version>.json (PDB) in the oracle-check format.
#              - Read-only on the dictionary: SELECTs only, plus the scratch
#                user KBCHK_SCRATCH (created, used for DBMS_SQL.PARSE of SELECT
#                statements, dropped) in the PDB.
#              - Target levels: common/config/target-levels.env.
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

set -euo pipefail
SCRIPT_NAME=$(basename "$0")
COMPOSE=${COMPOSE:-"docker"}
IMAGE=""
EXPORT_BY=""

log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') INFO  $*"; }
die() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} <alias> <release 26AI|19C>

  Snapshot hook logic, called by labs/<lab>/hooks/snapshot.sh. Needs LAB,
  LAB_CONTAINER, LAB_OUT, LAB_DATA_DIR, REPO_ROOT in the environment.

Options:
  -h, --help      Show this help and exit

EOF
}

# ------------------------------------------------------------------------------
# Function: sq
# Purpose.: Run a SQL*Plus script (stdin) in the container, no login
# ------------------------------------------------------------------------------
sq() {
    # shellcheck disable=SC2016  # expands inside the container
    ${COMPOSE} exec -i "${LAB_CONTAINER}" bash -c 'export ORAENV_ASK=NO; "${ORACLE_HOME}/bin/sqlplus" -s -L /nolog'
}

# Function: q1 - one query as SYSDBA, result on one line
q1() {
    printf 'connect / as sysdba\nSET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500\n%s;\n' "$1" | sq |
        tr -s '[:space:]' ' ' | sed -e 's/^ //' -e 's/ $//'
}

# ------------------------------------------------------------------------------
# Function: export_one
# Purpose.: Dictionary export of root or one PDB into tagged lines + JSON
# Args....: $1 file name stem (alias or alias_pdb), $2 PDB name or empty (root)
# ------------------------------------------------------------------------------
export_one() {
    local stem="$1" pdb="$2" tagged codes version scope
    scope="${pdb:-CDB\$ROOT}"
    tagged=$(mktemp "${TMPDIR:-/tmp}/dict-tagged.XXXXXX")
    codes=$(mktemp "${TMPDIR:-/tmp}/dict-ora.XXXXXX")
    {
        echo "connect / as sysdba"
        [[ -n "${pdb}" ]] && echo "alter session set container = ${pdb};"
        cat "${REPO_ROOT}/common/sql/dict_snapshot.sql"
    } | sq >"${tagged}"
    # same source as 'oerr ora <n>'
    # shellcheck disable=SC2016  # expands inside the container
    ${COMPOSE} exec -i "${LAB_CONTAINER}" bash -c 'grep -oE "^[0-9]{5}," "$ORACLE_HOME/rdbms/mesg/oraus.msg" | tr -d ,' >"${codes}"
    version=$(sed -n 's/^V|//p' "${tagged}" | head -1)
    [[ -n "${version}" ]] || die "no version in the export of ${scope}"
    python3 -I "${REPO_ROOT}/common/scripts/dict_snapshot.py" "${tagged}" "${codes}" "${LAB_CONTAINER}${pdb:+/${pdb}}" \
        "${LAB_OUT}/${stem}-${version}.json" "container=${LAB_CONTAINER}" "image=${IMAGE}" "scope=${scope}"
    rm -f "${tagged}" "${codes}"
    log_info "export ${scope}: ${LAB_OUT}/${stem}-${version}.json ($(du -h "${LAB_OUT}/${stem}-${version}.json" | cut -f1))"
}

# ------------------------------------------------------------------------------
# Function: parse_check
# Purpose.: Scratch user KBCHK_SCRATCH in the PDB parses SELECTs (never executed):
#           one valid, one with a missing table (expects ORA-00942)
# Output..: "ok" or a failure text
# ------------------------------------------------------------------------------
parse_check() {
    local pdb="$1" pw domain svc out
    pw="Kb$(openssl rand -hex 8)x"
    # shellcheck disable=SC2016  # v$parameter is SQL
    domain=$(q1 'SELECT value FROM v$parameter WHERE name = '"'db_domain'")
    svc="$(printf '%s' "${pdb}" | tr '[:upper:]' '[:lower:]')${domain:+.${domain}}"
    out=$(
        sq 2>&1 <<SQL || true
connect / as sysdba
alter session set container = ${pdb};
create user KBCHK_SCRATCH identified by "${pw}" account unlock;
grant create session to KBCHK_SCRATCH;
connect KBCHK_SCRATCH/"${pw}"@//localhost:1521/${svc}
set serveroutput on
set transaction read only;
declare
  procedure chk(p_id varchar2, p_sql varchar2) is c integer;
  begin c := dbms_sql.open_cursor;
    begin dbms_sql.parse(c, p_sql, dbms_sql.native); dbms_output.put_line('Q|'||p_id||'|0');
    exception when others then dbms_output.put_line('Q|'||p_id||'|'||sqlcode); end;
    dbms_sql.close_cursor(c);
  end;
begin
  chk('ok', 'select object_name from all_objects where owner = ''SYS''');
  chk('bad', 'select * from no_such_table_kbchk');
end;
/
rollback;
connect / as sysdba
alter session set container = ${pdb};
drop user KBCHK_SCRATCH cascade;
SQL
    )
    if grep -q '^Q|ok|0' <<<"${out}" && grep -q '^Q|bad|-942' <<<"${out}"; then
        echo ok
    else
        echo "failed: $(tr '\n' ' ' <<<"${out}" | cut -c1-300)"
    fi
}

# ------------------------------------------------------------------------------
# Function: write_meta
# Purpose.: lab-meta.json: version and RU read from the DB, behind_current against
#           common/config/target-levels.env, measured figures, parse check
# Args....: $1 release, $2 alias, $3 pdb, $4 parse check, $5 export seconds
# ------------------------------------------------------------------------------
write_meta() {
    local rel="$1" alias="$2" pdb="$3" check="$4" export_s="$5" data_kb ram image_id image_bytes patches
    # peak figures right after the export (the heaviest step)
    data_kb=$(du -sk "${LAB_DATA_DIR}" | cut -f1)
    ram=$(${COMPOSE} stats --no-stream --format '{{.MemUsage}}' "${LAB_CONTAINER}")
    image_id=$(${COMPOSE} image inspect -f '{{.Id}}' "${IMAGE}")
    image_bytes=$(${COMPOSE} image inspect -f '{{.Size}}' "${IMAGE}")
    # shellcheck disable=SC2016  # v$instance is SQL
    patches=$(sq <<'SQL'
connect / as sysdba
set pages 0 feed off lines 500 trimspool on heading off
select 'V|'||version_full from v$instance;
select 'U|'||patch_id||'|'||action||'|'||status||'|'||to_char(action_time,'YYYY-MM-DD')||'|'||replace(replace(description,'|','/'),chr(10),' ') from dba_registry_sqlpatch order by action_time;
SQL
    )
    PATCHES="${patches}" python3 -I - "${LAB_OUT}/lab-meta.json" "${REPO_ROOT}/common/config/target-levels.env" \
        "${rel}" "${LAB}" "${alias}" "${pdb}" "${IMAGE}" "${image_id}" "${image_bytes}" "${data_kb}" "${ram}" \
        "${check}" "${EXPORT_BY}" "${export_s}" <<'PY'
import json, os, re, sys
from datetime import date

(meta, tfile, rel, lab, alias, pdb, image, image_id, image_bytes, data_kb, ram, check, export_by,
 export_s) = sys.argv[1:15]
tv = {}
for ln in open(tfile, encoding="utf-8"):
    if "=" in ln and not ln.lstrip().startswith("#"):
        k, v = ln.rstrip("\n").split("=", 1)
        tv[k] = v
version, patches = "", []
for ln in os.environ["PATCHES"].splitlines():
    f = ln.strip().split("|")
    if f[0] == "V":
        version = f[1].strip()
    elif f[0] == "U" and len(f) >= 6:
        patches.append(f[1:5] + ["|".join(f[5:])])


def tup(v):
    return tuple(int(x) for x in v.split(".") if x.isdigit())


target = tv.get(f"TARGET_{rel}_VERSION", "")
cspu_date = tv.get(f"TARGET_{rel}_CSPU_DATE", "")
ru_rows = [p for p in patches if "release update" in p[4].lower() and p[2].upper() == "SUCCESS"]
ru = ru_rows[-1][4] if ru_rows else ""
# CSPU/RU level from the build date in the patch description (e.g. 19.27.0.0.250415 -> 2025-04-15),
# never from the apply date: a freshly created lab applies its RU today, after every CSPU date.
def build_date(desc):
    mm = re.search(r"\d+\.\d+\.\d+\.\d+\.(\d{2})(\d{2})(\d{2})", desc)
    return f"20{mm.group(1)}-{mm.group(2)}-{mm.group(3)}" if mm else ""
builds = [build_date(p[4]) for p in patches if p[2].upper() == "SUCCESS"]
builds = [b for b in builds if b]
if not cspu_date:
    cspu_present = True
elif builds:
    cspu_present = max(builds) >= cspu_date
else:
    cspu_present = None  # not checkable: no build date in DBA_REGISTRY_SQLPATCH (e.g. Free images)
behind_version = bool(target) and tup(version) < tup(target)
behind = behind_version or cspu_present is False
reasons = []
if behind_version:
    reasons.append(f"version {version} < target {target}")
if cspu_present is False:
    reasons.append(f"newest patch build {max(builds)} is older than the CSPU date {cspu_date}")
if cspu_present is None and cspu_date:
    reasons.append(f"CSPU level not checkable (no patch build date) - CSPU {cspu_date} not verified")
m = {
    "lab": lab, "alias": alias, "release": rel, "image": image, "image_id": image_id,
    "version_full": version,
    "ru": ru or f"(no RU row in DBA_REGISTRY_SQLPATCH; version_full {version})",
    "ru_source": "dba_registry_sqlpatch" if ru else "version_full",
    "patch_rows": len(patches), "pdb": pdb,
    "target": target, "target_cspu_date": cspu_date, "target_levels_updated": tv.get("UPDATED", ""),
    "cspu_present": cspu_present,
    "behind_current": behind, "behind_reason": "; ".join(reasons),
    "behind_note": tv.get(f"BEHIND_NOTE_{rel}", "") if behind else "",
    "measured": {"export_s": int(export_s), "data_mb_peak": round(int(data_kb) / 1024),
                 "ram": ram, "image_gb": round(int(image_bytes) / 1e9, 2)},
    "parse_check": check, "export_by": export_by, "created": date.today().isoformat(),
    "cleanup": "pending",
}
with open(meta, "w", encoding="utf-8") as fh:
    json.dump(m, fh, indent=2)
    fh.write("\n")
state = f"BEHIND target {target} ({m['behind_reason']})" if behind else "current"
print(f"{lab}: {version} - {state}")
if behind and m["behind_note"]:
    print(f"  note: {m['behind_note']}")
PY
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
    local alias="$1" rel="${2:?release 26AI|19C missing}" pdb t_start check_result v
    for v in LAB LAB_CONTAINER LAB_OUT LAB_DATA_DIR REPO_ROOT; do
        [[ -n "${!v:-}" ]] || die "${v} not set - run via 'make snapshot LAB=${alias}'"
    done
    t_start=$(date +%s)
    mkdir -p "${LAB_OUT}"
    IMAGE=$(${COMPOSE} inspect --format '{{.Config.Image}}' "${LAB_CONTAINER}")
    # The container reports healthy while dbca and the setup hooks still run
    # (trivadis/ora_db: instance open READ WRITE early, PDB created by a setup
    # hook at the end) - wait for a PDB, bounded by SNAPSHOT_PDB_WAIT seconds.
    local waited=0 limit="${SNAPSHOT_PDB_WAIT:-2400}"
    while true; do
        # shellcheck disable=SC2016  # v$pdbs is SQL
        pdb=$(q1 'SELECT name FROM v$pdbs WHERE name <> '"'PDB\$SEED'"' AND open_mode = '"'READ WRITE'"' ORDER BY con_id FETCH FIRST 1 ROW ONLY')
        [[ "${pdb}" =~ ^[A-Z][A-Z0-9_]*$ ]] && break
        pdb=""
        ((waited >= limit)) && die "no open PDB in ${LAB_CONTAINER} after ${waited}s (SNAPSHOT_PDB_WAIT=${limit})"
        ((waited % 120 == 0)) && log_info "${LAB_CONTAINER}: waiting for an open PDB (dbca / setup hooks still running?) (${waited}s)"
        sleep 20
        waited=$((waited + 20))
    done
    log_info "${LAB_CONTAINER}: ${IMAGE}, PDB ${pdb}"

    if [[ -n "${ORACLE_CHECK_EXPORT:-}" ]]; then
        log_info "ORACLE_CHECK_EXPORT set - running it instead of the built-in export"
        LAB_ALIAS="${alias}" LAB_PDB="${pdb}" bash -c "${ORACLE_CHECK_EXPORT}"
        EXPORT_BY="ORACLE_CHECK_EXPORT"
    else
        export_one "${alias}" ""
        export_one "${alias}_pdb" "${pdb}"
        EXPORT_BY="built-in (common/sql/dict_snapshot.sql)"
    fi
    check_result=$(parse_check "${pdb}")
    log_info "parse check as KBCHK_SCRATCH in ${pdb}: ${check_result}"
    write_meta "${rel}" "${alias}" "${pdb}" "${check_result}" "$(($(date +%s) - t_start))"
}

main "$@"
# --- EOF ----------------------------------------------------------------------
