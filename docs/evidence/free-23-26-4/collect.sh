#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: collect.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-25
# Version....: 0.1.0
# Purpose....: Collect the evidence for the Oracle Free 23.26.3.0 vs 23.26.4.0
#              container image comparison (docs/evidence/free-23-26-4).
#              Phases:
#                registry - manifests, compressed sizes, digests (needs network)
#                static   - image config, file system, du, start scripts
#                           (local, no database start)
#                runtime  - start tests with throwaway containers (local, no
#                           network, 1-2 h on arm64)
# Notes......: - Both images are pinned by index digest and must exist locally
#                (--pull never). Runtime tests run on the host architecture
#                only; amd64 under emulation is too slow and is not tested.
#              - Throwaway containers are named free-diff-*; no ports are
#                published, existing lab containers are never touched.
#              - Bind directories live in <repo>/.work/free-23-26-4 (gitignored)
#                and are removed at the end, the images are kept.
#              - A failing test is recorded and the run continues.
# Usage......: collect.sh [--phase registry|static|runtime|all] [--only t1,t5]
#                         [--dry-run] [--yes] [--delete] [--keep] [--help]
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-11-25  oes  Initial release                                    0.1.0
# ------------------------------------------------------------------------------
set -euo pipefail

# - Constants ------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
readonly REPO_DIR
export REPO_DIR_SAN="${REPO_DIR}"
readonly RAW_DIR="${SCRIPT_DIR}/raw"
readonly WORK_DIR="${REPO_DIR}/.work/free-23-26-4"
readonly REPO_IMG="container-registry.oracle.com/database/free"
readonly TAG_OLD="23.26.3.0"
readonly TAG_NEW="23.26.4.0"
readonly DIGEST_OLD="sha256:f988b0c04c4c386cd306a2a914c0d7a9702d83acc31b064a28ad8eb6278a8fba"
readonly DIGEST_NEW="sha256:f5a1791bf5628fd1a97e07584ff5ac5537da5021c23e70f5083f48c8fcd6476e"
readonly PREFIX="free-diff"
readonly TIMEOUT_CREATE="${TIMEOUT_CREATE:-3600}"   # dbca on an empty directory
readonly TIMEOUT_PREBUILT="${TIMEOUT_PREBUILT:-1200}"
readonly TIMEOUT_STARTUP_HOOK="${TIMEOUT_STARTUP_HOOK:-300}"
readonly CHARSET_TEST="WE8MSWIN1252"
readonly SID_TEST="LABSID"
readonly ALL_TESTS="t5 t6 t3 t4 t1 t2"

PHASE="runtime"
ONLY=""
DRY_RUN=false
ASSUME_YES=false
DELETE_ONLY=false
KEEP=false
SUMMARY=""

# - Helpers --------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: ${0##*/} [options]

Collect evidence for Oracle Free ${TAG_OLD} vs ${TAG_NEW} (arm64 runtime).

Options:
  --phase P    registry | static | runtime | all (default: runtime)
  --only LIST  runtime tests to run, comma separated (default: all)
  --dry-run    print what would run, start nothing
  --yes        no confirmation prompt (needed for an unattended run)
  --delete     only remove ${PREFIX}-* containers and the work directory
  --keep       keep containers and bind directories after the run
  --help       this text

Runtime tests (order of execution; t0 only with --only t0):
  t0  smoke test of this script, no database start       (${TAG_NEW})
  t5  no bind mount, setup + startup marker scripts      (both images)
  t6  no bind mount, failing startup SQL script          (both images)
  t3  empty bind dir, command runOracle.sh               (${TAG_NEW} only)
  t4  empty bind dir, ORACLE_SID=${SID_TEST}                (${TAG_NEW} only)
  t1  empty bind dir, setup + startup marker scripts     (both images)
  t2  empty bind dir, ORACLE_CHARACTERSET=${CHARSET_TEST}  (both images)

Output: ${RAW_DIR#"${REPO_DIR}"/}/rt-*.txt, runtime-summary.tsv
Env: TIMEOUT_CREATE=${TIMEOUT_CREATE} TIMEOUT_PREBUILT=${TIMEOUT_PREBUILT} (seconds)
EOF
}

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }
err() { printf '%s ERROR: %s\n' "$(date '+%F %T')" "$*" >&2; }

image_ref() {
    case "$1" in
        "${TAG_OLD}") printf '%s@%s' "${REPO_IMG}" "${DIGEST_OLD}" ;;
        "${TAG_NEW}") printf '%s@%s' "${REPO_IMG}" "${DIGEST_NEW}" ;;
        *) err "unknown tag $1"; return 1 ;;
    esac
}

image_digest() {
    if [[ "$1" == "${TAG_OLD}" ]]; then printf '%s' "${DIGEST_OLD}"; else printf '%s' "${DIGEST_NEW}"; fi
}

# Header of every evidence file: what, when, which image.
evidence_header() {
    local title="$1" tag="$2"
    printf '# %s\n' "${title}"
    printf '# date: %s\n' "$(date -u '+%FT%TZ')"
    printf '# image: %s:%s\n' "${REPO_IMG}" "${tag}"
    printf '# digest: %s\n' "$(image_digest "${tag}")"
    printf '# host: %s %s, docker %s\n' "$(uname -s)" "$(uname -m)" \
        "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '?')"
    printf '# ------------------------------------------------------------\n'
}

summary_add() {
    printf '%s\t%s\t%s\t%s\t%s\n' "$@" >> "${SUMMARY}"
}

# Remove a directory whose files may belong to the container's oracle user.
remove_dir() {
    local dir="$1"
    [[ -d "${dir}" ]] || return 0
    if ! rm -rf "${dir}" 2>/dev/null; then
        log "rm -rf ${dir} failed - removing via container as root"
        docker run --rm --pull never --network none --user root --entrypoint /bin/bash \
            -v "${dir}:/w" "$(image_ref "${TAG_NEW}")" -c 'rm -rf /w/* /w/.[!.]* 2>/dev/null; true' || true
        rm -rf "${dir}" || err "could not remove ${dir} - remove by hand"
    fi
}

cleanup() {
    if ${KEEP}; then
        log "--keep: containers and ${WORK_DIR} are kept"
        return 0
    fi
    local names
    names="$(docker ps -a --filter "name=^${PREFIX}-" --format '{{.Names}}' 2>/dev/null || true)"
    if [[ -n "${names}" ]]; then
        log "removing containers: ${names//$'\n'/ }"
        # shellcheck disable=SC2086
        docker rm -f ${names} >/dev/null || err "docker rm failed for: ${names}"
    fi
    if [[ -d "${WORK_DIR}" ]]; then
        local d
        for d in "${WORK_DIR}"/run-*; do
            [[ -e "${d}" ]] || continue
            remove_dir "${d}"
        done
    fi
}

# - Phase registry -------------------------------------------------------------
phase_registry() {
    local tag out
    for tag in "${TAG_OLD}" "${TAG_NEW}" latest; do
        out="${RAW_DIR}/manifest-${tag}.json"
        log "registry: manifest ${tag}"
        if ${DRY_RUN}; then continue; fi
        docker manifest inspect --verbose "${REPO_IMG}:${tag}" > "${out}" \
            || { err "manifest ${tag} failed"; continue; }
    done
    if ${DRY_RUN}; then return 0; fi
    {
        for tag in "${TAG_OLD}" "${TAG_NEW}" latest; do
            docker buildx imagetools inspect "${REPO_IMG}:${tag}" 2>&1 | sed -n '1,3p'
            echo
        done
    } > "${RAW_DIR}/index-digests.txt"
    {
        printf 'tag\tarch\tmanifest_digest\tlayers\tcompressed_bytes\n'
        for tag in "${TAG_OLD}" "${TAG_NEW}"; do
            jq -r --arg t "${tag}" '.[] | (.OCIManifest.layers // .SchemaV2Manifest.layers) as $l
                | "\($t)\t\(.Descriptor.platform.architecture)\t\(.Descriptor.digest)\t\($l|length)\t\([$l[].size]|add)"' \
                "${RAW_DIR}/manifest-${tag}.json"
        done
    } > "${RAW_DIR}/registry-sizes.tsv"
    {
        for tag in "${TAG_OLD}" "${TAG_NEW}"; do
            echo "== ${tag}: compressed layers > 50 MB"
            jq -r '.[] | .Descriptor.platform.architecture as $a
                | (.OCIManifest.layers // .SchemaV2Manifest.layers) | to_entries[]
                | select(.value.size > 50000000) | "\($a) layer#\(.key) \(.value.size/1048576|floor) MiB"' \
                "${RAW_DIR}/manifest-${tag}.json"
        done
    } > "${RAW_DIR}/layers-compressed.txt"
    # Registry documentation page: full text stays in the work directory
    # (Oracle content, not redistributed), the evidence quotes excerpts.
    # Only the text is kept: the HTML carries a public analytics key that gitleaks
    # (make check, --no-git) reports even in the gitignored work directory.
    mkdir -p "${WORK_DIR}"
    local jar html
    jar="$(mktemp)"
    html="$(mktemp)"
    if curl -sSL -m 60 -c "${jar}" -b "${jar}" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
        "https://container-registry.oracle.com/ords/ocr/ba/database/free" -o "${html}"; then
        python3 -I -c '
import html, re, sys
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
t = re.sub(r"(?s)<script.*?</script>|<style.*?</style>", "", t)
t = re.sub(r"<br\s*/?>|</p>|</li>|</h\d>|</tr>|</pre>", "\n", t)
t = html.unescape(re.sub(r"<[^>]+>", "", t))
sys.stdout.write(re.sub(r"\n\s*\n+", "\n\n", t))' "${html}" > "${WORK_DIR}/registry-page.txt"
        date -u '+%FT%TZ' > "${RAW_DIR}/fetch-date.txt"
    else
        err "registry page fetch failed"
    fi
    rm -f "${jar}" "${html}"
}

# - Phase static ---------------------------------------------------------------
phase_static() {
    local tag ref out c f
    for tag in "${TAG_OLD}" "${TAG_NEW}"; do
        ref="$(image_ref "${tag}")"
        log "static: ${tag}"
        if ${DRY_RUN}; then continue; fi
        out="${RAW_DIR}/inspect-${tag}.json"
        docker image inspect "${ref}" | jq '.[0] | {Id, RepoDigests, Created, Architecture, Os, Size,
            Cmd: .Config.Cmd, Entrypoint: .Config.Entrypoint, User: .Config.User,
            Healthcheck: .Config.Healthcheck, Labels: .Config.Labels, Env: .Config.Env,
            Layers: (.RootFS.Layers|length)}' > "${out}"
        docker history --no-trunc --format '{{.Size}}|{{.CreatedBy}}' "${ref}" \
            | cut -c1-240 > "${RAW_DIR}/history-${tag}.txt"
        { evidence_header "file system probe (no database start)" "${tag}"
          docker run --rm --pull never --network none --entrypoint /bin/bash "${ref}" -c '
            echo "--- ls -la /opt/oracle"; ls -la /opt/oracle
            echo "--- dbca templates"; ls -la "$ORACLE_HOME/assistants/dbca/templates"
            echo "--- oradata"; find /opt/oracle/oradata -maxdepth 2 | sort
            echo "--- README.md / Dockerfile"; ls -la /opt/oracle/README.md /opt/oracle/Dockerfile 2>&1
            echo "--- os"; cat /etc/oracle-release
            echo "--- sqlplus -v"; "$ORACLE_HOME/bin/sqlplus" -v
            echo "--- template use in /etc/init.d/oracle-free-26ai"
            grep -nE "TEMPLATE_NAME|templateName" /etc/init.d/oracle-free-26ai'
        } > "${RAW_DIR}/fs-probe-${tag}.txt" 2>&1 || err "fs probe ${tag} failed"
        docker run --rm --pull never --network none --entrypoint /bin/bash "${ref}" -c '
            for d in / /opt/oracle /opt/oracle/oradata /opt/oracle/product/26ai/dbhomeFree \
                     /opt/oracle/product/26ai/dbhomeFree/assistants \
                     /opt/oracle/product/26ai/dbhomeFree/assistants/dbca /var /var/cache /usr; do
                du -xk --max-depth=1 "$d" 2>/dev/null
            done' | sort -u -k2 > "${WORK_DIR}/du-${tag}.tsv"
        # start scripts (Oracle UPL code) go to the work directory, diffs to raw/
        mkdir -p "${WORK_DIR}/scripts-${tag}"
        c="$(docker create --pull never "${ref}")"
        for f in runOracle.sh startPrebuilt.sh scripts/base/runOracle.sh.orig \
                 scripts/base/createDB.sh scripts/base/runUserScripts.sh \
                 scripts/base/configurePrebuiltPdb.sh; do
            docker cp -L "${c}:/opt/oracle/${f}" "${WORK_DIR}/scripts-${tag}/${f//\//_}" 2>/dev/null \
                || echo "${tag}: /opt/oracle/${f} missing" >> "${RAW_DIR}/scripts-missing.txt"
        done
        docker rm "${c}" >/dev/null
    done
    if ${DRY_RUN}; then return 0; fi
    { printf 'path\tkb_%s\tkb_%s\tdiff_kb\n' "${TAG_OLD}" "${TAG_NEW}"
      join -t$'\t' -1 2 -2 2 -a1 -a2 -e0 -o 0,1.1,2.1 \
          <(sort -t$'\t' -k2 "${WORK_DIR}/du-${TAG_OLD}.tsv") \
          <(sort -t$'\t' -k2 "${WORK_DIR}/du-${TAG_NEW}.tsv") \
        | awk -F'\t' '{d=$2-$3; if (d>10000 || d<-10000) printf "%s\t%d\t%d\t%d\n",$1,$2,$3,d}' \
        | sort -t$'\t' -k4 -rn
    } > "${RAW_DIR}/du-diff-kb.tsv"
    for f in scripts_base_runOracle.sh.orig scripts_base_runUserScripts.sh; do
        diff -u "${WORK_DIR}/scripts-${TAG_OLD}/${f}" "${WORK_DIR}/scripts-${TAG_NEW}/${f}" \
            > "${RAW_DIR}/diff-${f}.txt" || true
    done
}

# - Phase runtime --------------------------------------------------------------
# Wait for READY / NOT SUCCESSFUL / exit / timeout; prints the outcome.
wait_db() {
    local name="$1" timeout="$2" start logs running
    start=${SECONDS}
    while :; do
        running="$(docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null || echo false)"
        logs="$(docker logs "${name}" 2>&1 || true)"
        if [[ "${logs}" == *"DATABASE IS READY TO USE"* ]]; then echo ready; return 0; fi
        if [[ "${logs}" == *"DATABASE SETUP WAS NOT SUCCESSFUL"* ]]; then echo setup-failed; return 0; fi
        if [[ "${running}" != "true" ]]; then echo exited; return 0; fi
        if (( SECONDS - start > timeout )); then echo timeout; return 0; fi
        sleep 10
    done
}

# Wait until a text shows up in the log or the container stops.
wait_log() {
    local name="$1" text="$2" timeout="$3" start logs running
    start=${SECONDS}
    while (( SECONDS - start <= timeout )); do
        logs="$(docker logs "${name}" 2>&1 || true)"
        if [[ "${logs}" == *"${text}"* ]]; then echo found; return 0; fi
        running="$(docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null || echo false)"
        if [[ "${running}" != "true" ]]; then echo exited; return 0; fi
        sleep 5
    done
    echo timeout
}

write_hooks() {
    local dir="$1" mode="$2"
    mkdir -p "${dir}/setup" "${dir}/startup"
    cat > "${dir}/setup/01_marker.sh" <<'EOF'
echo "MARKER-SETUP ran $(date -u +%FT%TZ)"
touch /opt/oracle/oradata/MARKER-SETUP 2>/dev/null || true
EOF
    if [[ "${mode}" == "fail" ]]; then
        cat > "${dir}/startup/01_fail.sql" <<'EOF'
PROMPT MARKER-STARTUP-FAIL running
WHENEVER SQLERROR EXIT FAILURE
SELECT * FROM free_diff_no_such_table;
EOF
    else
        cat > "${dir}/startup/01_marker.sh" <<'EOF'
echo "MARKER-STARTUP ran $(date -u +%FT%TZ)"
touch /opt/oracle/oradata/MARKER-STARTUP 2>/dev/null || true
EOF
    fi
    chmod -R a+rX "${dir}"
}

db_facts() {
    local name="$1" sid="${2:-FREE}"
    docker exec -i -e ORACLE_SID="${sid}" "${name}" bash -c '"$ORACLE_HOME/bin/sqlplus" -s / as sysdba' <<'SQL' 2>&1
SET PAGESIZE 100 LINESIZE 200 FEEDBACK OFF HEADING ON
COLUMN name FORMAT a20
COLUMN value FORMAT a30
COLUMN property_name FORMAT a25
COLUMN property_value FORMAT a25
COLUMN banner_full FORMAT a90
SELECT banner_full FROM v$version;
SELECT name, open_mode FROM v$pdbs;
PROMPT --- CDB$ROOT nls_database_parameters
SELECT parameter, value FROM nls_database_parameters
 WHERE parameter IN ('NLS_CHARACTERSET','NLS_NCHAR_CHARACTERSET');
ALTER SESSION SET CONTAINER = FREEPDB1;
PROMPT --- FREEPDB1 nls_database_parameters
SELECT parameter, value FROM nls_database_parameters
 WHERE parameter IN ('NLS_CHARACTERSET','NLS_NCHAR_CHARACTERSET');
EXIT
SQL
}

# Collect everything about one finished test container.
collect_container() {
    local name="$1" run_dir="$2" sid="$3"
    echo "--- docker inspect State"
    docker inspect -f 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Started={{.State.StartedAt}} Finished={{.State.FinishedAt}}' "${name}" 2>&1 || true
    echo "--- docker inspect Cmd / Mounts"
    docker inspect -f '{{json .Config.Cmd}} {{json .Mounts}}' "${name}" 2>&1 || true
    if [[ "$(docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null || echo false)" == "true" ]]; then
        echo "--- database facts (sqlplus / as sysdba, SID ${sid})"
        db_facts "${name}" "${sid}" || echo "(sqlplus failed)"
    else
        echo "--- database facts: container not running, no query"
    fi
    if [[ -d "${run_dir}/oradata" ]]; then
        echo "--- host bind directory (find -maxdepth 2, du -sh)"
        (cd "${run_dir}/oradata" && find . -maxdepth 2 | sort && du -sh .) 2>&1 || true
    fi
    echo "--- marker files in /opt/oracle/oradata"
    docker cp "${name}:/opt/oracle/oradata/MARKER-SETUP" "${run_dir}/" >/dev/null 2>&1 \
        && echo "MARKER-SETUP present" || echo "MARKER-SETUP absent"
    docker cp "${name}:/opt/oracle/oradata/MARKER-STARTUP" "${run_dir}/" >/dev/null 2>&1 \
        && echo "MARKER-STARTUP present" || echo "MARKER-STARTUP absent"
    echo "--- cfgtoollogs (dbca), last 60 lines per log"
    if docker cp "${name}:/opt/oracle/cfgtoollogs" "${run_dir}/cfgtoollogs" >/dev/null 2>&1; then
        local f
        while IFS= read -r f; do
            echo "### ${f#"${run_dir}"/}"
            tail -n 60 "${f}"
        done < <(find "${run_dir}/cfgtoollogs" -type f -name '*.log' -newer "${run_dir}/.started" | sort)
    else
        echo "(no cfgtoollogs)"
    fi
    echo "--- docker logs (complete)"
    docker logs "${name}" 2>&1 || true
}

# run_case <test> <tag> <description> <bind:yes|no> <hooks:marker|fail|none> <timeout> [extra docker args...]
run_case() {
    local test="$1" tag="$2" desc="$3" bind="$4" hooks="$5" timeout="$6"
    shift 6
    local name="${PREFIX}-${test}-${tag//./}" run_dir="${WORK_DIR}/run-${test}-${tag}"
    local out="${RAW_DIR}/rt-${test}-${tag}.txt" ref outcome hook_outcome="-" sid="FREE" a
    local -a args=(--pull never -d --name "${name}" --hostname "${name}" -e ORACLE_PWD)
    ref="$(image_ref "${tag}")"
    for a in "$@"; do
        if [[ "${a}" == ORACLE_SID=* ]]; then sid="${a#ORACLE_SID=}"; fi
    done
    if [[ "${bind}" == "yes" ]]; then args+=(-v "${run_dir}/oradata:/opt/oracle/oradata"); fi
    if [[ "${hooks}" != "none" ]]; then
        args+=(-v "${run_dir}/hooks/setup:/opt/oracle/scripts/setup:ro"
               -v "${run_dir}/hooks/startup:/opt/oracle/scripts/startup:ro")
    fi
    log "${test} ${tag}: ${desc}"
    if ${DRY_RUN}; then
        log "  dry-run: docker run ${args[*]} $* ${ref}"
        return 0
    fi
    local existing
    existing="$(docker ps -a --format '{{.Names}}')"
    if grep -qx "${name}" <<<"${existing}"; then
        docker rm -f "${name}" >/dev/null
    fi
    remove_dir "${run_dir}"
    mkdir -p "${run_dir}"
    touch "${run_dir}/.started"
    if [[ "${bind}" == "yes" ]]; then mkdir -p "${run_dir}/oradata"; chmod 0777 "${run_dir}/oradata"; fi
    if [[ "${hooks}" != "none" ]]; then write_hooks "${run_dir}/hooks" "${hooks}"; fi
    local t0=${SECONDS}
    {
        evidence_header "runtime ${test}: ${desc}" "${tag}"
        printf '# command: docker run %s %s %s\n' "${args[*]}" "$*" "${ref}"
        printf '# ORACLE_PWD: random, not logged\n'
        printf '# ------------------------------------------------------------\n'
    } > "${out}"
    # extra arguments: KEY=VALUE env pairs, or "cmd:<command>" to override CMD
    local -a envs=() cmd=()
    for a in "$@"; do
        case "${a}" in
            cmd:*) cmd=(/bin/bash -c "${a#cmd:}") ;;
            *=*) envs+=(-e "${a}") ;;
            *) err "unknown extra argument ${a}"; return 1 ;;
        esac
    done
    if ! docker run "${args[@]}" ${envs[@]+"${envs[@]}"} "${ref}" ${cmd[@]+"${cmd[@]}"} >/dev/null 2>>"${out}"; then
        echo "RESULT: docker run failed" >> "${out}"
        summary_add "${test}" "${tag}" "docker-run-failed" "$((SECONDS - t0))" "${desc}"
        return 1
    fi
    outcome="$(wait_db "${name}" "${timeout}")"
    if [[ "${outcome}" == "ready" && "${hooks}" == "marker" ]]; then
        hook_outcome="startup-marker:$(wait_log "${name}" "MARKER-STARTUP ran" "${TIMEOUT_STARTUP_HOOK}")"
    elif [[ "${outcome}" == "ready" && "${hooks}" == "fail" ]]; then
        # give the failing startup script time to run and the container time to react
        hook_outcome="startup-fail:$(wait_log "${name}" "MARKER-STARTUP-FAIL running" "${TIMEOUT_STARTUP_HOOK}")"
        sleep 60
        hook_outcome="${hook_outcome},state:$(docker inspect -f '{{.State.Status}}/{{.State.ExitCode}}' "${name}" 2>/dev/null || echo '?')"
    fi
    {
        printf 'RESULT: %s %s after %ss\n' "${outcome}" "${hook_outcome}" "$((SECONDS - t0))"
        collect_container "${name}" "${run_dir}" "${sid}"
    } >> "${out}" 2>&1
    # public repo: no local paths in the evidence
    perl -pi -e 's/\Q$ENV{REPO_DIR_SAN}\E/<repo>/g; s/\Q$ENV{HOME}\E/~/g' "${out}"
    summary_add "${test}" "${tag}" "${outcome} ${hook_outcome}" "$((SECONDS - t0))" "${desc}"
    log "  -> ${outcome} ${hook_outcome} ($((SECONDS - t0))s)"
    if ! ${KEEP}; then
        docker rm -f "${name}" >/dev/null 2>&1 || true
        remove_dir "${run_dir}"
    fi
}

selected() {
    [[ -z "${ONLY}" || ",${ONLY}," == *",$1,"* ]] || return 1
}

# The cmd: strings are expanded inside the container, not here.
# shellcheck disable=SC2016
run_test() {
    local test="$1"
    case "${test}" in
        t0) run_case t0 "${TAG_NEW}" "plumbing smoke test, no database (fake READY line)" yes marker 120 \
                'cmd:echo "DATABASE IS READY TO USE!"; $ORACLE_BASE/runUserScripts.sh $ORACLE_BASE/scripts/startup; sleep 600' ;;
        t5) run_case t5 "${TAG_OLD}" "no bind mount, setup+startup markers" no marker "${TIMEOUT_PREBUILT}"
            run_case t5 "${TAG_NEW}" "no bind mount, setup+startup markers" no marker "${TIMEOUT_PREBUILT}" ;;
        t6) run_case t6 "${TAG_OLD}" "no bind mount, failing startup SQL" no fail "${TIMEOUT_PREBUILT}"
            run_case t6 "${TAG_NEW}" "no bind mount, failing startup SQL" no fail "${TIMEOUT_PREBUILT}" ;;
        t3) run_case t3 "${TAG_NEW}" "empty bind dir, command runOracle.sh (no startPrebuilt.sh)" yes marker \
                "${TIMEOUT_CREATE}" 'cmd:exec $ORACLE_BASE/runOracle.sh' ;;
        t4) run_case t4 "${TAG_NEW}" "empty bind dir, ORACLE_SID=${SID_TEST}" yes marker "${TIMEOUT_CREATE}" \
                "ORACLE_SID=${SID_TEST}" ;;
        t1) run_case t1 "${TAG_NEW}" "empty bind dir, setup+startup markers" yes marker "${TIMEOUT_CREATE}"
            run_case t1 "${TAG_OLD}" "empty bind dir, setup+startup markers" yes marker "${TIMEOUT_CREATE}" ;;
        t2) run_case t2 "${TAG_NEW}" "empty bind dir, ORACLE_CHARACTERSET=${CHARSET_TEST}" yes none \
                "${TIMEOUT_CREATE}" "ORACLE_CHARACTERSET=${CHARSET_TEST}"
            run_case t2 "${TAG_OLD}" "empty bind dir, ORACLE_CHARACTERSET=${CHARSET_TEST}" yes none \
                "${TIMEOUT_CREATE}" "ORACLE_CHARACTERSET=${CHARSET_TEST}" ;;
        *) err "unknown test ${test}"; return 1 ;;
    esac
}

phase_runtime() {
    local test failed=0 skipped=""
    ORACLE_PWD="Lab$(openssl rand -hex 8)x1"
    export ORACLE_PWD
    SUMMARY="${RAW_DIR}/runtime-summary.tsv"
    if ! ${DRY_RUN}; then
        printf 'test\timage\toutcome\tseconds\tdescription\n' > "${SUMMARY}"
        { evidence_header "runtime environment" "${TAG_NEW}"
          docker version 2>&1
          docker info --format 'CPUs={{.NCPU}} Mem={{.MemTotal}} Driver={{.Driver}}' 2>&1
          echo "--- other containers (not touched)"
          docker ps --format '{{.Names}}\t{{.Status}}' 2>&1
        } > "${RAW_DIR}/rt-env.txt"
    fi
    for test in ${ALL_TESTS}; do
        if ! selected "${test}"; then skipped+="${skipped:+,}${test}"; fi
    done
    for test in ${ONLY//,/ }; do
        case " ${ALL_TESTS} t0 " in
            *" ${test} "*) ;;
            *) err "unknown test ${test} in --only"; exit 2 ;;
        esac
    done
    local run_list="${ALL_TESTS}"
    if [[ -n "${ONLY}" ]]; then run_list="${ONLY//,/ }"; fi
    for test in ${run_list}; do
        run_test "${test}" || { failed=$((failed + 1)); err "test ${test} failed - continuing"; }
    done
    if [[ -n "${skipped}" ]]; then log "not run (--only): ${skipped} - run: $0 --phase runtime --only ${skipped} --yes"; fi
    log "runtime: done, ${failed} test(s) with errors; summary ${SUMMARY#"${REPO_DIR}"/}"
}

# - Main -----------------------------------------------------------------------
parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --phase) PHASE="${2:?--phase needs a value}"; shift ;;
            --only) ONLY="${2:?--only needs a value}"; shift ;;
            --dry-run) DRY_RUN=true ;;
            --yes) ASSUME_YES=true ;;
            --delete) DELETE_ONLY=true ;;
            --keep) KEEP=true ;;
            -h|--help) usage; exit 0 ;;
            *) err "unknown option $1"; usage >&2; exit 2 ;;
        esac
        shift
    done
    case "${PHASE}" in
        registry|static|runtime|all) ;;
        *) err "unknown phase ${PHASE}"; exit 2 ;;
    esac
}

check_prereqs() {
    local tool tag
    for tool in docker jq openssl; do
        command -v "${tool}" >/dev/null || { err "${tool} not found"; exit 1; }
    done
    docker info >/dev/null 2>&1 || { err "docker daemon not reachable"; exit 1; }
    for tag in "${TAG_OLD}" "${TAG_NEW}"; do
        docker image inspect "$(image_ref "${tag}")" >/dev/null 2>&1 \
            || { err "image ${tag} ($(image_digest "${tag}")) not local - pull it first"; exit 1; }
    done
}

main() {
    parse_args "$@"
    check_prereqs
    mkdir -p "${RAW_DIR}" "${WORK_DIR}"
    if ${DELETE_ONLY}; then
        KEEP=false
        cleanup
        log "delete: done"
        return 0
    fi
    if ! ${ASSUME_YES} && ! ${DRY_RUN}; then
        printf 'Phase %s, tests %s - start? [y/N] ' "${PHASE}" "${ONLY:-${ALL_TESTS}}"
        local answer
        read -r answer
        [[ "${answer}" =~ ^[yYjJ] ]] || { log "aborted"; return 1; }
    fi
    trap cleanup EXIT
    trap 'err "interrupted"; exit 130' INT TERM
    case "${PHASE}" in
        registry) phase_registry ;;
        static) phase_static ;;
        runtime) phase_runtime ;;
        all) phase_registry; phase_static; phase_runtime ;;
    esac
}

main "$@"
