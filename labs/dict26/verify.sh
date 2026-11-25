#!/usr/bin/env bash
# oradba-labs - verify lab dict26: health, connections (snapshot profile: no baseline, no audit requirement).
# Generic checks: common/scripts/lab_verify.sh
set -euo pipefail
export VERIFY_PROFILE=snapshot
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common/scripts/lab_verify.sh" dict26
