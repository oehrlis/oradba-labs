#!/usr/bin/env bash
# oradba-labs - verify lab seclab: health, connections, connect strings.
# Generic checks: common/scripts/lab_verify.sh (driven by the oradba.labs.* labels).
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common/scripts/lab_verify.sh" seclab
