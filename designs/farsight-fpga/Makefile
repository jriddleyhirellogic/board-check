.PHONY: all build-fpga no-synth no-riscv-init check-libero check-version help

# Configuration variables
TARGET_BOARD ?= mpf500ts-fc1152m
PROJECT_NAME ?= farsight_avionics
NO_SYNTH     ?= 0
RISCV_INIT   ?= 1

# Hardware version (required): VERSION=<major>.<minor>.<fix>, BUILD=<build>
# Each field is one byte (0-255).
VERSION      ?=
BUILD        ?=

HW_MAJOR = $(word 1,$(subst ., ,$(VERSION)))
HW_MINOR = $(word 2,$(subst ., ,$(VERSION)))
HW_FIX   = $(word 3,$(subst ., ,$(VERSION)))
HW_BUILD = $(BUILD)

# Default target
all: build-fpga

help:
	@echo "Available targets:"
	@echo "  make [build-fpga]  - Build FPGA project with RISC-V sNVM initialization (default)"
	@echo "  make no-synth      - Create project only"
	@echo "  make no-riscv-init - Build without RISC-V sNVM initialization"
	@echo "  make help          - Show this help message"
	@echo ""
	@echo "Required variables:"
	@echo "  VERSION            - Hardware version as <major>.<minor>.<fix>, e.g. 2.0.1 (each field 0-255)"
	@echo "  BUILD              - Build number, e.g. 4 (0-255)"
	@echo ""
	@echo "Configuration variables:"
	@echo "  TARGET_BOARD       - Target board (default: $(TARGET_BOARD))"
	@echo "  PROJECT_NAME       - Project name (default: $(PROJECT_NAME))"
	@echo ""
	@echo "Example usage:"
	@echo "  make VERSION=2.0.1 BUILD=4"
	@echo "  make build-fpga VERSION=2.0.1 BUILD=4 TARGET_BOARD=custom-board PROJECT_NAME=my_project"
	@echo "  make no-synth VERSION=2.0.1 BUILD=4"

build-fpga: check-libero check-version
	libero SCRIPT:./synth_farsight_avionics.tcl SCRIPT_ARGS:"$(TARGET_BOARD) $(PROJECT_NAME) $(NO_SYNTH) $(RISCV_INIT) $(HW_MAJOR) $(HW_MINOR) $(HW_FIX) $(HW_BUILD)"

no-synth: check-libero
	$(MAKE) build-fpga NO_SYNTH=1

no-riscv-init: check-libero
	$(MAKE) build-fpga RISCV_INIT=0

# Check that VERSION/BUILD are provided and each field is a valid byte
check-version:
	@usage="Usage: make VERSION=<major>.<minor>.<fix> BUILD=<build>, e.g. make VERSION=2.0.1 BUILD=4"; \
	if [ -z "$(strip $(VERSION))" ]; then \
		echo "Error: VERSION is required. $$usage"; exit 1; \
	fi; \
	if [ -z "$(strip $(BUILD))" ]; then \
		echo "Error: BUILD is required. $$usage"; exit 1; \
	fi; \
	if [ "$(words $(subst ., ,$(VERSION)))" != "3" ]; then \
		echo "Error: invalid VERSION '$(VERSION)'. Expected <major>.<minor>.<fix>, e.g. 2.0.1"; exit 1; \
	fi; \
	for pair in "major:$(HW_MAJOR)" "minor:$(HW_MINOR)" "fix:$(HW_FIX)" "build:$(HW_BUILD)"; do \
		name=$${pair%%:*}; value=$${pair#*:}; \
		echo "$$value" | grep -Eq '^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$$' || { \
			echo "Error: invalid $$name value '$$value'. Must be an integer in the range 0-255"; exit 1; \
		}; \
	done; \
	echo "Building hardware version $(HW_MAJOR).$(HW_MINOR).$(HW_FIX) build $(HW_BUILD)"

# Check if libero is in PATH
check-libero:
	@which libero > /dev/null 2>&1 || { \
		echo "Error: 'libero' not found in PATH"; \
		echo "Please add Libero to your PATH or specify its location"; \
		exit 1; \
	}

# =============================================================================
# Verification
#
# Everything below is the simulation environment, and nothing above depends on
# it: an FPGA build needs Libero and no Python at all. See verification/README.md.
#
#   make setup          once per clone: virtualenv and Verilator, no root
#   make ip             once per clone: vendor IP for simulation (needs Libero)
#   make test           the suite
#   make test-fast      the checks that need no simulator
#   make check          whether the results should block a merge
#   make coverage       where each requirement stands
#   make gui-web        the app, in a browser tab inside VS Code
# =============================================================================
.PHONY: setup test test-fast check coverage code-coverage clean ip ip-check ip-import ip-ready \
	gui-web sarif

VENV        := .venv-verif
VENV_PYTHON := $(VENV)/bin/python
EDA_PATH    := $(CURDIR)/.tools/micromamba/envs/eda/bin

# Libero for `make ip`. Found by pattern rather than a list of guesses: vendor,
# "_SoC" and version are each spelled differently across installs. Override with
# `make ip LIBERO_SIM=/path/to/libero`.
LIBERO_SIM ?= $(firstword $(shell command -v libero 2>/dev/null) \
                  $(wildcard /opt/microchip/Libero_SoC_v2024*/Libero/bin/libero) \
                  $(wildcard /usr/local/microchip/Libero_SoC_v2024*/Libero/bin/libero))

# Libero opens an X connection even in SCRIPT: mode, and without one exits with
# "cannot connect to X server". With no DISPLAY -- over ssh, in CI -- run it
# under a virtual one. Override with LIBERO_X=.
LIBERO_X ?= $(if $(DISPLAY),,$(if $(shell command -v xvfb-run 2>/dev/null),xvfb-run -a))

IP_DIR  := verification/ip
IP_WORK := .ip-build

# The IP vault Libero generates from. Libero reads its vault location from the
# per-user ~/.actel/ipmgr.ini, which every project on the machine shares. So
# `make ip` does not use it: Libero runs with HOME pointed at a scratch
# directory whose ipmgr.ini names this vault, for that one invocation, and the
# user's own setting is never read or changed.
#
# The vault is this checkout's own, under .tools/, and nothing else writes to
# it. It holds the cores script/common/download.tcl names -- the build's own
# list -- fetched by Libero on the first `make ip` and again whenever that list
# changes. That needs network access to microchip-ip.com. A vault named with
# LIBERO_VAULT= is used as it is, and never written to.
TOOLS_VAULT  := $(CURDIR)/.tools/vault
LIBERO_VAULT ?= $(TOOLS_VAULT)
IP_HOME      := .ip-home

# HOME for one Libero invocation: a scratch directory whose ipmgr.ini names the vault.
ip_home = rm -rf $(IP_HOME) && mkdir -p $(IP_HOME)/.actel && \
	printf '[VAULTS]\nLOCATION=%s\n' "$(abspath $(LIBERO_VAULT))" > $(IP_HOME)/.actel/ipmgr.ini

setup:
	./verification/setup-tools.sh $(SETUP_ARGS)

# Refuses rather than guessing. A suite run against a system python that
# happens to have cocotb is a run nobody can reproduce.
$(VENV_PYTHON):
	@echo "No verification virtualenv at $(VENV)."; \
	echo "Build it with:  make setup"; \
	exit 1

# Vendor IP for simulation: the components verification/ip.yaml lists, generated
# into a scratch project and collected with a lockfile each. Generated rather
# than committed -- the RTL is Microchip's -- and the lockfile is what makes a
# copy from elsewhere verifiable (`make ip-import`).
ip: $(VENV_PYTHON) $(if $(filter $(TOOLS_VAULT),$(LIBERO_VAULT)),$(TOOLS_VAULT)/.fetched)
	@test -n "$(LIBERO_SIM)" || { echo "No Libero 2024 found; set LIBERO_SIM=/path/to/libero"; exit 1; }
	@test -d "$(LIBERO_VAULT)/Components" || { \
		echo "No IP vault at $(LIBERO_VAULT). Leave LIBERO_VAULT unset to have make ip"; \
		echo "fetch this checkout's own, or name a vault that holds the cores."; exit 1; }
	@$(VENV_PYTHON) verification/record_ip.py --list > .ip-build.list
	@$(ip_home)
	HOME=$(abspath $(IP_HOME)) TZ=UTC $(LIBERO_X) $(LIBERO_SIM) SCRIPT:./gen_ip.tcl \
		SCRIPT_ARGS:"$(TARGET_BOARD) .ip-build.list $(IP_WORK)"
	$(VENV_PYTHON) verification/record_ip.py --collect $(IP_WORK)/component --libero $(LIBERO_SIM)
	@rm -rf $(IP_WORK) $(IP_HOME) .ip-build.list

# This checkout's vault: the cores the build's download.tcl names.
$(TOOLS_VAULT)/.fetched: script/common/download.tcl
	@test -n "$(LIBERO_SIM)" || { echo "No Libero 2024 found; set LIBERO_SIM=/path/to/libero"; exit 1; }
	@mkdir -p $(TOOLS_VAULT) && rm -f $@
	@$(ip_home)
	HOME=$(abspath $(IP_HOME)) TZ=UTC $(LIBERO_X) $(LIBERO_SIM) SCRIPT:./script/common/download.tcl
	@rm -rf $(IP_HOME)
	@test -d "$(TOOLS_VAULT)/Components" || { echo "Libero fetched nothing into $(TOOLS_VAULT)"; exit 1; }
	@touch $@

ip-check: $(VENV_PYTHON)
	@$(VENV_PYTHON) verification/record_ip.py --check

# Take the generated IP from somewhere that has it, and prove it is the right
# one: the committed lockfiles are checked against what arrives.
ip-import: $(VENV_PYTHON)
	@test -n "$(FROM)" || { echo "Usage: make ip-import FROM=<path or host:path to a verification/ip directory>"; exit 1; }
	@rm -rf $(IP_DIR).incoming && mkdir -p $(IP_DIR).incoming
	@case "$(FROM)" in *:*) scp -q -r "$(FROM)"/* $(IP_DIR).incoming/ ;; *) cp -r "$(FROM)"/* $(IP_DIR).incoming/ ;; esac
	@cp $(IP_DIR)/*.lock.json $(IP_DIR).incoming/ 2>/dev/null || true
	@$(VENV_PYTHON) verification/record_ip.py --check --ip-root $(IP_DIR).incoming \
	&& { for d in $(IP_DIR).incoming/*/; do rm -rf $(IP_DIR)/$$(basename $$d); mv $$d $(IP_DIR)/; done; \
	     rm -rf $(IP_DIR).incoming; echo "Imported and verified against the committed lockfiles."; } \
	|| { rm -rf $(IP_DIR).incoming; echo "Not imported: it does not match the committed lockfiles."; exit 1; }

# Every test that compiles vendor IP needs it generated and current. Checked
# once here, so one missing prerequisite reads as one message rather than as a
# failure in every module that compiles a core.
ip-ready: $(VENV_PYTHON)
	@$(VENV_PYTHON) verification/record_ip.py --check >/dev/null 2>&1 || { \
		echo "The vendor IP simulation compiles is missing or stale:"; \
		$(VENV_PYTHON) verification/record_ip.py --check 2>&1 | sed 's/^/    /'; \
		echo ""; echo "    make ip        generate it (needs Libero; no synthesis licence)"; \
		echo "    make ip-import FROM=<another checkout's verification/ip>"; \
		echo ""; echo "Checks that need no simulator run regardless:  make test-fast"; \
		exit 1; }

# The suite: the simulations under verification/tests and the analyses under
# verification/analysis. Modules run in parallel, and the suite costs its
# slowest module.
#
#   make test                       everything
#   make test TEST=test_pf_pps      one module, simulation or analysis
#   make test WAVES=1               with waveforms
#
# Code coverage is measured by default -- by Verilator, and by QuestaSim for the
# modules pinned to it -- and the report is rebuilt after the run from all the
# data in hand (`make code-coverage`). COV=0 skips both, for a quick rerun:
#
#   make test TEST=test_pf_pps COV=0
#
# Not COVERAGE=0: cocotb reads COVERAGE as "measure the testbench's Python".
FSVERIF_COV := $(if $(filter 0 no false,$(COV)),0,1)
test: $(VENV_PYTHON) ip-ready
	@cd verification && FSVERIF_COVERAGE=$(FSVERIF_COV) PATH="$(EDA_PATH):$$PATH" \
		../$(VENV_PYTHON) -m pytest $(if $(TEST),$(patsubst verification/%,%,$(wildcard \
		verification/tests/$(TEST).py verification/analysis/$(TEST).py)),tests/ analysis/) $(PYTEST_ARGS); \
	status=$$?; \
	if [ "$(FSVERIF_COV)" = 1 ] && ls coverage 2>/dev/null | grep -q -E "\.(dat|ucdb)$$"; then \
		echo; PATH="$(EDA_PATH):$$PATH" ../$(VENV_PYTHON) code_coverage.py; \
	fi; \
	exit $$status

test-fast: $(VENV_PYTHON)
	@cd verification && ../$(VENV_PYTHON) -m pytest -n0 \
		tests/test_evidence_rules.py tests/test_visibility.py \
		tests/test_results.py tests/test_dispositions.py tests/test_web.py $(PYTEST_ARGS)

# Whether the last run's results should stop a merge. A failure an item declares
# with `expect: FAIL` is reported and does not block; any other failure blocks,
# and so does a pass where a failure was declared -- the declaration is stale.
check: $(VENV_PYTHON)
	@$(VENV_PYTHON) verification/check_results.py

#   make coverage             every requirement
#   make coverage SIM=1       simulation items only
#   make coverage GROUP=UDP   one area
#   make coverage TODO=1      only what is not yet passing
coverage: $(VENV_PYTHON)
	@$(VENV_PYTHON) verification/requirement_coverage.py \
		$(if $(SIM),--method SIM) $(if $(GROUP),--group $(GROUP)) \
		$(if $(TODO),--todo) $(if $(HTML),--html $(HTML))

# The app: Jama traceability, every requirement test -- simulation or
# analysis -- with what it checked and what happened, the requirements and
# findings behind them, and code coverage. Runs can be started, followed and cancelled from it, and a run
# made from a terminal is picked up on its own.
#
# In a browser tab, so it runs where no window can open -- VS Code over
# Remote-SSH above all. Serves on 127.0.0.1 behind a token it prints; open the address in
# VS Code's Simple Browser. Standard library only: nothing to install.
gui-web: $(VENV_PYTHON)
	@cd verification && PATH="$(EDA_PATH):$$PATH" ../$(VENV_PYTHON) -m fsverif.web

# The last run and code coverage as SARIF: open the files with VS Code's SARIF
# Viewer and each result jumps to its line.
sarif: $(VENV_PYTHON)
	@$(VENV_PYTHON) verification/sarif.py

# The coverage report again, from the data the last runs left: what `make test`
# prints at its end.
code-coverage: $(VENV_PYTHON)
	@PATH="$(EDA_PATH):$$PATH" $(VENV_PYTHON) verification/code_coverage.py

clean:
	rm -rf verification/sim_build verification/results verification/coverage verification/public
