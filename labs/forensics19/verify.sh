#!/usr/bin/env bash
# oradba-labs - verify lab forensics19: health, connections, connect strings.
# Generic checks: common/scripts/lab_verify.sh; expected accounts as PDB:ACCOUNT,...
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common/scripts/lab_verify.sh" forensics19 FXPDB1:SCOTT,TVD_HR,HR
