# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: Makefile
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-11-13
# Revision...: 0.2.0
# Purpose....: oradba-labs - one lab on push of a button:
#              make list | up | down | reset | rebuild | status | connect | verify LAB=<name>
# Notes......: The lab logic lives in common/scripts/labctl.sh; this file only
#              maps targets to it. Use 'make help' for all targets.
# Reference..: https://github.com/oehrlis/oradba-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

VERSION := $(shell cat VERSION 2>/dev/null || echo "0.0.0")
LABCTL := common/scripts/labctl.sh
LAB ?=
DB ?=
PURGE ?= 0
COMPOSE ?= docker
export COMPOSE
DRY_RUN ?=
DRY := $(if $(filter 1 true TRUE yes,$(DRY_RUN)),--dry-run,)

SHELL_FILES = $(shell find common labs -name '*.sh' -type f | sort)

# ==============================================================================
# Help
# ==============================================================================

.PHONY: help
help: ## Show this help
	@echo "oradba-labs $(VERSION)"
	@echo ""
	@echo "Usage: make <target> LAB=<name> [DB=db19|db26] [PURGE=1] [DRY_RUN=1] [COMPOSE=docker]"
	@echo ""
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[32m%-12s\033[0m %s\n", $$1, $$2}'

# ==============================================================================
# Lab lifecycle
# ==============================================================================

.PHONY: list up down reset rebuild status connect verify
list: ## List all labs
	@$(LABCTL) list

up: ## Start LAB, wait until ready, create baseline, verify
	@$(LABCTL) $(DRY) up $(LAB)

down: ## Remove LAB containers (data volumes only with PURGE=1)
	@PURGE=$(PURGE) $(LABCTL) $(DRY) down $(LAB)

reset: ## Flash LAB back to its baseline (restore point LAB_BASELINE)
	@$(LABCTL) $(DRY) reset $(LAB)

rebuild: ## Remove LAB containers and data, create the databases again
	@$(LABCTL) $(DRY) rebuild $(LAB)

status: ## Show LAB containers, health and restore points
	@$(LABCTL) status $(LAB)

connect: ## sqlplus / as sysdba into LAB (DB=db19|db26, default first)
	@$(LABCTL) connect $(LAB) $(DB)

verify: ## Check LAB and print connect strings
	@$(LABCTL) verify $(LAB)

# ==============================================================================
# Feature probe
# ==============================================================================

P ?=
IMAGES ?=
DIFF ?=
PROBE_TARGETS = $(foreach i,$(IMAGES),-i $(i)) $(if $(LAB),$(foreach c,$(shell docker ps --filter label=com.docker.compose.project=oradba-labs-$(LAB) --format '{{.Names}}' | sort),-c $(c)),)

.PHONY: probe
probe: ## Feature traces: make probe [P='mfa_|_mfa'] [LAB=seclab] [IMAGES="img1 img2"] [DIFF=1] - no P: everything
	@test -n "$(strip $(PROBE_TARGETS))" || { echo "ERROR: IMAGES=... or LAB=... missing" >&2; exit 1; }
	@common/scripts/feature_probe.sh $(if $(filter 1,$(DIFF)),--diff,) $(PROBE_TARGETS) '$(P)'

# ==============================================================================
# Quality
# ==============================================================================

.PHONY: lint lint-shell lint-markdown lint-compose secrets check
lint: lint-shell lint-markdown lint-compose ## Run all linters

lint-shell: ## shellcheck all shell scripts
	@shellcheck --shell=bash $(SHELL_FILES)
	@echo "shellcheck: $(words $(SHELL_FILES)) files clean"

lint-markdown: ## markdownlint all Markdown files
	@markdownlint '**/*.md'
	@echo "markdownlint: clean"

lint-compose: ## Validate every labs/*/compose.yml against its lab.env.example
	@for d in labs/*/; do \
		DB19_DATA=/tmp/x DB26_ORADATA=/tmp/x DB26_DBCONFIG=/tmp/x DB19_LOGS=/tmp/x DB26_LOGS=/tmp/x \
		LAB_SHARED=/tmp/x docker compose --env-file $$d/lab.env.example -f $$d/compose.yml config -q || exit 1; \
		echo "compose: $$d ok"; \
	done

secrets: ## gitleaks over the working tree and the git history
	@gitleaks detect --source . --no-banner --redact
	@gitleaks detect --source . --no-git --no-banner --redact

check: lint secrets ## Lint + secret scan (run before every tag)

# ==============================================================================
# Release
# ==============================================================================

.PHONY: tag
tag: check ## Tag v$(VERSION) and push branch + tag
	@git diff --quiet && git diff --cached --quiet || { echo "ERROR: working tree not clean" >&2; exit 1; }
	@git tag -a "v$(VERSION)" -m "oradba-labs v$(VERSION)"
	@git push origin "$$(git rev-parse --abbrev-ref HEAD)"
	@git push origin "v$(VERSION)"
	@echo "pushed branch and tag v$(VERSION)"
# --- EOF ----------------------------------------------------------------------
