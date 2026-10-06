.PHONY: all build-fpga no-tmr em fpga-build timing timing-check check-libero ip ip-check ip-import ip-vault board board-check setup test test-fast inspect inspect-build ip-ready check gui-web sarif coverage code-coverage clean clean-builds distclean help

# Configuration variables
TARGET_BOARD ?= a3pe3000l-fg484m
PROJECT_NAME ?= farsight_hk

# Plain text file holding all power sequencing times, in microseconds, and the
# script that writes those numbers into the RTL before every build.
PYTHON      ?= python3
TIMING_FILE := script/auto_coder/timing.txt
TIMING_GEN  := script/auto_coder/timing_gen.py

# The Libero executable, discovered rather than hardcoded.
#
# The previous default was /opt/microchip/Libero_v11.9/Libero/bin/libero, which
# on the machine it was written on is a symlink to a personal shim -- so it
# worked there and nowhere else, and the failure on any other machine was
# "executable not found" at a path nobody recognised.
#
# ProASIC3 is supported only up to Libero 11.9 -- later versions dropped the
# family -- so this must find an 11.x install and must refuse a newer one, even
# when the newer one is first on PATH.
#
# Refusing matters more than choosing. synth.tcl asks for `-min_version 11` and
# the check is `toolversion < min_version`, so Libero 2024.1 reports 2024,
# passes, and then fails somewhere deep in the flow with an error about the
# device rather than about the tool. A floor is the wrong shape of check for a
# family that was removed.
#
# Override with `make LIBERO=/path/to/libero` at any time.
#
# Searched by pattern, not by an enumerated list of paths. The list this
# replaced named four locations and missed /opt/microchip/Libero_SoC_v11.9 --
# vendor, "_SoC" and version are each spelled differently across installs,
# and a list of guesses is wrong on the first machine nobody guessed for.
LIBERO_ROOTS  ?= /opt /usr/local $(HOME)/opt $(HOME)/.local/opt
LIBERO_SEARCH := \
    $(wildcard $(addsuffix /*/Libero*v11*/Libero/bin/libero,$(LIBERO_ROOTS))) \
    $(wildcard $(addsuffix /Libero*v11*/Libero/bin/libero,$(LIBERO_ROOTS))) \
    $(wildcard $(HOME)/.local/bin/libero11*) \
    $(shell command -v libero 2>/dev/null)

LIBERO ?= $(firstword $(LIBERO_SEARCH))

# Synplify's license checkout performs a geographic-location check that compares
# the client timezone against the license server's. The license server runs in
# UTC, so building in a local timezone is rejected with:
#   "License checkout unsuccessful: synplifypro_actel"
#   "Based on your geographic location relative to your license server, ..."
# Forcing TZ=UTC for the build makes the check pass. Override with BUILD_TZ=.
BUILD_TZ ?= UTC

# Libero 11.9 on Linux opens an X connection even in SCRIPT: mode, and without
# one exits with "libero_bin: cannot connect to X server". With no DISPLAY --
# over ssh, in CI -- run it under a virtual one. Override with LIBERO_X=.
LIBERO_X ?= $(if $(DISPLAY),,$(if $(shell command -v xvfb-run 2>/dev/null),xvfb-run -a))

# `no-tmr` and `em` are modifiers rather than separate builds. Whichever ones
# appear on the command line are applied together to a single build, so
# `make em no-tmr` produces one EM board image with TMR disabled.
DISABLE_TMR := $(filter no-tmr,$(MAKECMDGOALS))
EM_PINOUT   := $(filter em,$(MAKECMDGOALS))

# Which programming_files/ subfolder this build's .pdb is filed under.
# The `_tmr` suffix means TMR is enabled; `em`/`fm` select the PA3 pinout.
#   (no modifiers) -> fm_tmr      no-tmr -> fm
#   em             -> em_tmr      em no-tmr -> em
BOARD_VARIANT := $(if $(EM_PINOUT),em,fm)
VARIANT       := $(if $(DISABLE_TMR),$(BOARD_VARIANT),$(BOARD_VARIANT)_tmr)

LIBERO_BUILD = TZ=$(BUILD_TZ) $(LIBERO_X) $(LIBERO) SCRIPT:./synth_farsight_hk.tcl SCRIPT_ARGS:"$(TARGET_BOARD) $(PROJECT_NAME) $(VARIANT)"

# Default target
all: build-fpga

help:
	@echo "Available targets:"
	@echo "  make [build-fpga]  - Build FPGA project with TMR targeting FM board (default)"
	@echo "  make no-tmr        - Build without TMR (must not be flown)"
	@echo "  make em            - Build with EM RS422/TTL PA3 pinout"
	@echo "                       (bus_to_farsight=AA15, farsight_to_bus=Y6)"
	@echo "  make em no-tmr     - Combine both in a single build"
	@echo "  make timing        - Apply $(TIMING_FILE) to the RTL without building"
	@echo "  make timing-check  - Report whether the RTL matches $(TIMING_FILE)"
	@echo "  make board         - Re-extract the board power topology from the schematic export"
	@echo "  make board-check   - Report what a schematic change obliges of the testbench"
	@echo "  make setup         - Build the verification virtualenv and install Verilator"
	@echo "  make test          - Run the verification suite (TEST=<file> for one module)"
	@echo "  make test-fast     - Run only the checks that need no simulator, and the inspections"
	@echo "  make inspect       - Check the design as built: RTL, pin constraints, schematic export"
	@echo "  make inspect-build - Check a Libero flight build (BUILD=<build dir>; default the newest)"
	@echo "  make check         - Report whether the results should block a merge"
	@echo "  make gui-web       - The review app in a browser tab -- inside VS Code, over Remote-SSH"
	@echo "  make sarif         - Failing tests and unreached lines, for VS Code's SARIF Viewer"
	@echo "  make coverage      - Show where each requirement stands (SIM=1 for yours only)"
	@echo "  make code-coverage - Report what the tests reached in the design"
	@echo "  make clean         - Remove simulation products and results"
	@echo "  make clean-builds  - Remove Libero project directories under build/"
	@echo "  make distclean     - clean + clean-builds + the virtualenv"
	@echo "  make help          - Show this help message"
	@echo ""
	@echo "no-tmr and em are modifiers, not separate builds. Naming both runs one"
	@echo "build with both applied; naming neither builds the FM TMR default."
	@echo ""
	@echo "The .pdb is filed under programming_files/<variant>/ so builds are"
	@echo "never mixed up. '_tmr' means TMR enabled; em/fm select the PA3 pinout:"
	@echo "  (default) -> fm_tmr    no-tmr -> fm    em -> em_tmr    em no-tmr -> em"
	@echo ""
	@echo "Power sequencing times (boot timeouts and retry delays) are set in"
	@echo "$(TIMING_FILE), in microseconds. Every build applies it automatically."
	@echo ""
	@echo "Configuration variables:"
	@echo "  TARGET_BOARD       - Target board (default: $(TARGET_BOARD))"
	@echo "  PROJECT_NAME       - Project name (default: $(PROJECT_NAME))"
	@echo "  LIBERO             - Libero executable (default: $(LIBERO))"
	@echo "  BUILD_TZ           - Timezone used for the build (default: $(BUILD_TZ))"
	@echo "                       Must match the license server's timezone or the"
	@echo "                       Synplify license checkout is refused."

# Write the values from $(TIMING_FILE) into the RTL. Runs before every build so
# that editing $(TIMING_FILE) is all that is needed to change the timing.
timing:
	@$(PYTHON) $(TIMING_GEN)

# Report whether the RTL is in sync with $(TIMING_FILE) without changing anything
timing-check:
	@$(PYTHON) $(TIMING_GEN) --check

# All three entry points funnel into one build. Because fpga-build is a shared
# prerequisite, make runs it only once even when several are named, so
# `make em no-tmr` is a single build with both modifiers applied.
build-fpga no-tmr em: fpga-build
	@:

# The real build. Nothing is patched: the variant selects the design's inputs.
# TMR comes from the generated src/build_variant.vh, and the pinout from
# constr/<board>/io/<fm|em>/. Both are chosen without editing a tracked file,
# which is what lets synth.tcl record a commit id that describes the image.
fpga-build: check-libero ip-vault timing
	$(PYTHON) script/build_variant.py $(VARIANT)
	$(LIBERO_BUILD)
	@$(PYTHON) script/record_build.py --variant $(VARIANT)

# Generated vendor IP for simulation.
#
# The design instantiates Microchip DirectCores that Libero generates from the
# component definitions in bd/<board>/components/. Synthesis produces them as
# a side effect into a timestamped build directory; simulation needs the same
# RTL without a place-and-route and without a Synplify licence.
#
# Every *.tcl in the definitions directory is generated, so adding a core is
# dropping a file in: no target, script or test names a particular one.
#
# Generated rather than committed. The definition is the source; a committed
# copy is a second one, and the two disagree the first time somebody edits the
# definition and does not regenerate. `ip-check` is what makes that failure
# loud, and it needs no Libero -- a checkout can always tell whether its IP
# matches its definitions even where it cannot produce any.
IP_DIR         := verification/ip
IP_DEFINITIONS := bd/$(TARGET_BOARD)/components

ip: check-libero ip-vault
	TZ=$(BUILD_TZ) $(LIBERO_X) $(LIBERO) SCRIPT:./gen_ip.tcl SCRIPT_ARGS:"$(TARGET_BOARD) $(IP_DIR)"
	@rm -rf .ip-build
	$(PYTHON) verification/record_ip.py \
		--definitions $(IP_DEFINITIONS) \
		--ip-root $(IP_DIR) \
		--libero $(LIBERO)

# Libero finds cores in an IP vault whose location is a per-user setting,
# ~/.actel/ipmgr.ini, outside this repository -- and Libero 11.9 has no Tcl
# command to set it. So a machine with the vault installed can still fail, with
# "Cannot find Spirit core configuration file" from inside a scratch project,
# because Libero is looking in the wrong place. This checks first and prints
# the line to change. Exit 2 means it could not tell, and lets Libero try.
ip-vault:
	@$(PYTHON) script/ip_vault.py --definitions $(IP_DEFINITIONS); \
	status=$$?; [ $$status -eq 1 ] && exit 1 || exit 0

# Take the generated IP from somewhere that has it, and prove it is the right
# one. Vendor RTL is proprietary and cannot be committed, but a digest of it
# can, so a copy is verifiable: `record_ip.py --check` compares what arrived
# against the component definitions in this repository. Without that the only
# options are "have Libero" or "trust a directory somebody sent you".
ip-import:
	@test -n "$(FROM)" || { \
		echo "Usage: make ip-import FROM=<path to a verification/ip directory>"; \
		echo ""; \
		echo "It may be a local path or anything scp understands:"; \
		echo "    make ip-import FROM=~/other-checkout/verification/ip"; \
		echo "    make ip-import FROM=host:~/checkout/verification/ip"; \
		exit 1; \
	}
	@rm -rf $(IP_DIR).incoming
	@mkdir -p $(IP_DIR).incoming
	@case "$(FROM)" in \
		*:*) scp -q -r "$(FROM)"/* $(IP_DIR).incoming/ ;; \
		*)   cp -r "$(FROM)"/* $(IP_DIR).incoming/ ;; \
	esac
	@$(PYTHON) verification/record_ip.py --check \
		--definitions $(IP_DEFINITIONS) --ip-root $(IP_DIR).incoming \
	&& { \
		rm -rf $(IP_DIR); mv $(IP_DIR).incoming $(IP_DIR); \
		echo "Imported and verified against $(IP_DEFINITIONS)."; \
	} || { \
		rm -rf $(IP_DIR).incoming; \
		echo ""; \
		echo "Not imported. What arrived does not match this repository's"; \
		echo "component definitions, so it is a different build of the core."; \
		exit 1; \
	}

ip-check:
	@$(PYTHON) verification/record_ip.py --check \
		--definitions $(IP_DEFINITIONS) --ip-root $(IP_DIR)

# The testbench cannot boot the device without a model of the board's power
# rails, and that model is derived from the schematic. The schematic is
# controlled elsewhere and re-issued for reasons the housekeeper never sees, so
# `board-check` compares the extracted *topology* and not the file: a re-export
# that moves a symbol reports nothing, and one that refits a regulator reports
# the rail, the change and what it obliges.
#
# The schematic export is committed, under a stable name, so that the check
# and the inspections that read it run anywhere, CI included, against a pinned
# revision. A new export replaces the file in one commit; `make board-check`
# then says what changed. SCHEMATIC=<export.json> checks a different one.
SCHEMATIC ?= verification/board/CM-03545.json
BOARD_TOPOLOGY := verification/board/topology.json

board: $(VENV_PYTHON)
	$(VENV_PYTHON) verification/extract_board.py "$(SCHEMATIC)" \
		--json $(BOARD_TOPOLOGY)

board-check: $(VENV_PYTHON)
	@$(VENV_PYTHON) verification/extract_board.py "$(SCHEMATIC)" \
		--check $(BOARD_TOPOLOGY)

# The verification environment. Everything below needs it, and nothing else in
# this Makefile does -- an FPGA build needs Libero and no Python at all.
VENV        := .venv-verif
VENV_PYTHON := $(VENV)/bin/python
EDA_PATH    := $$HOME/.local/opt/micromamba/envs/eda/bin

# From a fresh clone. Creates the virtualenv and installs Verilator without
# root; pass --skip-verilator if you already have 5.020 or later on PATH.
setup:
	./verification/setup-tools.sh $(SETUP_ARGS)

# Refuses rather than guessing. A suite run against a system python that
# happens to have cocotb is a run nobody can reproduce.
$(VENV_PYTHON):
	@echo "No verification virtualenv at $(VENV)."; \
	echo "Build it with:  make setup"; \
	exit 1

# The suite. Modules run in parallel and the suite costs its slowest module
# rather than the sum -- see verification/README.md.
#
#   make test                       everything, measuring code coverage
#   make test TEST=test_hk_src_02   one module
#   make test WAVES=1               with waveforms
#   make test FSVERIF_COVERAGE=0    without code coverage (about six times faster)
#
# Code coverage is measured by default. Each run starts by clearing the
# previous run's coverage, so the report describes this run alone, and writes
# the report after it whether or not tests failed -- this suite always has
# known failures -- keeping pytest's exit status. See `code-coverage` below.
FSVERIF_COVERAGE ?= 1
export FSVERIF_COVERAGE
test: $(VENV_PYTHON) ip-ready
	@cd verification && ../$(VENV_PYTHON) code_coverage.py --clear >/dev/null && \
		PATH="$(EDA_PATH):$$PATH" \
		../$(VENV_PYTHON) -m pytest $(if $(TEST),tests/$(TEST).py,tests/) $(PYTEST_ARGS); \
	status=$$?; \
	if [ "$(FSVERIF_COVERAGE)" != "0" ]; then \
		PATH="$(EDA_PATH):$$PATH" ../$(VENV_PYTHON) code_coverage.py || status=$$?; \
	fi; \
	exit $$status

# Every simulation module needs the vendor IP, because top.sv instantiates it.
# Without this check each module discovers that separately and reports it as
# its own failure, so one missing prerequisite reads as seven broken tests --
# forty lines of traceback each, saying the same thing.
ip-ready:
	@$(PYTHON) verification/record_ip.py --check \
		--definitions $(IP_DEFINITIONS) --ip-root $(IP_DIR) >/dev/null 2>&1 \
	|| { \
		echo "The vendor IP has not been generated, and every simulation"; \
		echo "needs it -- src/top.sv instantiates CoreUART."; \
		echo ""; \
		$(PYTHON) verification/record_ip.py --check \
			--definitions $(IP_DEFINITIONS) --ip-root $(IP_DIR) 2>&1 \
			| sed 's/^/    /'; \
		echo ""; \
		echo "    make ip        generate it (needs Libero; no synthesis licence)"; \
		echo ""; \
		echo "It is not committed: the RTL is marked Actel Proprietary and"; \
		echo "Confidential, so this repository holds only a digest of it."; \
		echo "Without Libero, copy verification/ip/ from a machine that has"; \
		echo "run 'make ip' -- 'make ip-check' will confirm it matches."; \
		echo ""; \
		echo "Checks that need no simulator run regardless:  make test-fast"; \
		exit 1; \
	}

# The checks that read the repository rather than simulating it: citations,
# muting, build variants, pin completeness. Seconds, and they catch the
# mistakes that are otherwise found by whoever runs a command next.
test-fast: $(VENV_PYTHON)
	@cd verification && ../$(VENV_PYTHON) -m pytest -n0 \
		tests/test_evidence_rules.py tests/test_build_variants.py \
		tests/test_results.py tests/test_web.py $(PYTEST_ARGS)
	@$(MAKE) -s inspect

# Inspections: structural claims checked by reading the design as built -- the
# RTL, the pin constraints and the schematic export -- without a simulator.
# Their results go beside the simulation's, where `make check`, `make coverage`
# and the app find them. See test/inspect/conftest.py.
#
# Judged as the gate judges the simulation: an inspection that fails where its
# item declares `expect: FAIL` is a known shortfall and does not fail this
# target; a new failure, a stale declaration, or no results at all does.
inspect: $(VENV_PYTHON)
	@mkdir -p verification/results
	@PATH="$(EDA_PATH):$$PATH" $(VENV_PYTHON) -m pytest test/inspect -q \
		--junitxml=verification/results/results-inspect.xml $(PYTEST_ARGS) || true
	@$(VENV_PYTHON) verification/check_results.py --only results-inspect.xml

# The flight build, as delivered: device, TMR, safe encoding, no test
# accommodations, variant identity and firmware version, read from a Libero
# build directory, the image and manifest filed beside it, and the sources at
# the commit it records. Run after `make build-fpga`; CI runs it in the flight
# build job. Judged as `inspect` is, into results-inspect-build.xml.
BUILD ?= $(lastword $(sort $(wildcard build/*_fm_tmr_*)))
inspect-build: $(VENV_PYTHON)
	@test -n "$(BUILD)" || { echo "No flight build to inspect: make build-fpga, or BUILD=<build dir>"; exit 1; }
	@mkdir -p verification/results
	@FSVERIF_BUILD="$(BUILD)" $(VENV_PYTHON) -m pytest test/inspect/build.py test/inspect/version.py -q \
		--junitxml=verification/results/results-inspect-build.xml $(PYTEST_ARGS) || true
	@$(VENV_PYTHON) verification/check_results.py --only results-inspect-build.xml

# Whether the last run's results should stop a merge. A failure an item
# declares does not block; a new one, or a declaration that has gone stale,
# does.
check: $(VENV_PYTHON)
	@$(VENV_PYTHON) verification/check_results.py

# The review app, in a browser tab: Jama traceability, every requirement test
# with what it checked and what happened, the requirements and findings behind
# them, and code coverage. Runs can be started, followed and cancelled from it,
# and a run made from a terminal is picked up on its own. Works where no window
# can open -- VS Code over Remote-SSH above all. Serves on 127.0.0.1 behind a
# token it prints; open the address in VS Code's Simple Browser. Standard
# library only: nothing to install.
gui-web: $(VENV_PYTHON)
	@cd verification && PATH="$(EDA_PATH):$$PATH" ../$(VENV_PYTHON) -m fsverif.web

# The last run and code coverage as SARIF, the way ts-rtl-check reports lint:
# open the files with VS Code's SARIF Viewer and each result jumps to its line.
sarif: $(VENV_PYTHON)
	@$(VENV_PYTHON) verification/sarif.py

# What the tests reached in the design. `make test` measures it and writes
# this report; run it on its own to rebuild the report from the data the last
# run left.
#
# Requirement coverage and code coverage answer different questions, and
# neither substitutes for the other: `make coverage` says whether a
# requirement has evidence, this says which lines ran.
code-coverage: $(VENV_PYTHON)
	@PATH="$(EDA_PATH):$$PATH" $(VENV_PYTHON) verification/code_coverage.py

# Removing generated things, in three steps rather than one, because they cost
# very different amounts to put back.
#
# `verification/ip/` is deliberately absent from all of them. It is generated,
# and it is the one generated thing that **needs Libero to restore** -- a
# `clean` that removed it would leave a developer without a synthesis licence
# unable to run any simulation at all, with no way back. `make ip` removes and
# regenerates it together, which is the only safe place to do it.
#
# `programming_files/` is absent too. Those are outputs somebody may still
# need, and they are not rebuildable from an arbitrary checkout: the tree has
# to be at the commit the image records.

#: Cheap to put back: a Verilator rebuild is seconds per module.
CLEAN_DIRS := verification/sim_build verification/results verification/coverage \
              verification/public verification/.pytest_cache

clean:
	@rm -rf $(CLEAN_DIRS)
	@find verification script -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
	@rm -f src/build_variant.vh
	@echo "Removed simulation products, results and coverage data."
	@echo "Rebuilt by the next 'make test' -- seconds per module."

#: Expensive to put back: each is a full Libero place-and-route.
clean-builds:
	@rm -rf build
	@echo "Removed Libero project directories."
	@echo "Rebuilt by 'make build-fpga' -- minutes, and needs a synthesis licence."
	@echo "Programming files under programming_files/ are untouched."

distclean: clean clean-builds
	@rm -rf $(VENV)
	@echo "Removed the virtualenv. Rebuild with 'make setup' -- needs network."
	@echo ""
	@echo "verification/ip/ was NOT removed: it needs Libero to regenerate,"
	@echo "and nothing else can restore it. 'make ip' replaces it in place."

# Where each requirement stands, read from this repository alone: the items,
# the tests, and whatever results the last run left behind. Needs no simulator
# and no governance checkout.
#
#   make coverage              every requirement
#   make coverage SIM=1        only the ones verified by simulation
#   make coverage GROUP=SEQ    one group
#   make coverage TODO=1       only what has no evidence yet
coverage:
	@$(PYTHON) verification/requirement_coverage.py \
		$(if $(SIM),--method SIM) $(if $(GROUP),--group $(GROUP)) \
		$(if $(TODO),--todo) $(if $(HTML),--html $(HTML))

#: Versions of Libero that can target this device. ProASIC3L support ends with
#: 11.9; every later release dropped the family.
LIBERO_SUPPORTED := 11

check-libero:
	@command -v $(LIBERO) > /dev/null 2>&1 || { \
		echo "No Libero found."; \
		echo ""; \
		echo "Looked for an 11.x install (ProASIC3 support ends with 11.9):"; \
		for r in $(LIBERO_ROOTS); do \
			echo "    $$r/*/Libero*v11*/Libero/bin/libero"; \
		done; \
		echo "    ~/.local/bin/libero11*"; \
		echo "    libero, on PATH"; \
		echo ""; \
		if [ -n "$(LIBERO)" ]; then \
			echo "Chose $(LIBERO), which is not executable."; \
		fi; \
		echo "Point at it explicitly if it is somewhere else:"; \
		echo "    make $(MAKECMDGOALS) LIBERO=/path/to/Libero/bin/libero"; \
		echo ""; \
		echo "For simulation only, Libero is needed once, to generate the"; \
		echo "vendor IP. If a colleague has already run 'make ip':"; \
		echo "    make ip-import FROM=<their-checkout>/verification/ip"; \
		exit 1; \
	}
	@case "$(LIBERO)" in \
		*[Ll]ibero*v$(LIBERO_SUPPORTED).*|*[Ll]ibero*_$(LIBERO_SUPPORTED).*|*libero$(LIBERO_SUPPORTED)*) ;; \
		*) \
			echo "This project targets ProASIC3L (A3PE3000L), which Libero"; \
			echo "supports only up to 11.9. Later versions dropped the family."; \
			echo ""; \
			echo "    chose: $(LIBERO)"; \
			echo ""; \
			echo "That does not look like an 11.x install. If it is, say so"; \
			echo "explicitly:"; \
			echo "    make $(MAKECMDGOALS) LIBERO_SUPPORTED=\$$(<major>)"; \
			echo ""; \
			echo "Otherwise point at an 11.x install:"; \
			echo "    make $(MAKECMDGOALS) LIBERO=/path/to/Libero_v11.9/Libero/bin/libero"; \
			exit 1 ;; \
	esac
