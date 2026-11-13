#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: lab_ready.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Version....: 0.1.0
# Purpose....: Mark the lab container as ready (all init hooks have run).
# Notes......: Runs inside the DB container as last setup/startup hook. labctl.sh
#              and the compose healthcheck wait for this marker.
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-11-13  oes  Initial release                                    0.1.0
# ------------------------------------------------------------------------------
set -euo pipefail

touch /tmp/oradba-labs.ready
echo "INFO: lab container ready (/tmp/oradba-labs.ready)"
# --- EOF ----------------------------------------------------------------------
