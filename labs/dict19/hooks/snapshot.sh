#!/usr/bin/env bash
# oradba-labs hook for 'make snapshot LAB=dict19' - environment from labctl.sh
set -euo pipefail
exec "${REPO_ROOT}/common/scripts/dict_snapshot.sh" dict19 19C
