#!/usr/bin/env bash
# oradba-labs - verify lab base26: health, connections, connect strings.
# Generic checks: common/scripts/lab_verify.sh; expected accounts as PDB:ACCOUNT,...
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common/scripts/lab_verify.sh" base26
