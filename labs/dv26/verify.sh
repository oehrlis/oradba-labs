#!/usr/bin/env bash
# oradba-labs - verify lab dv26: health, connections, connect strings.
# Generic checks: common/scripts/lab_verify.sh; expected accounts as PDB:ACCOUNT,...
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common/scripts/lab_verify.sh" dv26 DVPDB1:SCOTT,LAB_ADMIN,LAB_USER
