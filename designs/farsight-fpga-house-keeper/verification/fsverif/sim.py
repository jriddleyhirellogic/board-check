"""Shared simulation plumbing: source lists, simulator selection, runner helper."""

from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path
from typing import Sequence

from cocotb_tools.runner import Verilator, get_runner


class _LeanVerilator(Verilator):
    """Verilator, without every signal forced public.

    cocotb's runner adds `--public-flat-rw` unconditionally, and its own
    documentation says the flag is optional and carries a performance penalty.
    On this design it costs a factor of ten, so it is dropped here and the
    signals cocotb actually needs are declared in a generated config file
    instead.

    This reaches into a private method, which is why `requirements.txt` pins
    cocotb exactly. `test_visibility.py` fails if the flag ever comes back.
    """

    def _build_command(self):
        return [[arg for arg in command if arg != "--public-flat-rw"]
                for command in super()._build_command()]


def _runner(name: str, seeing: str):
    """The runner for this simulator at this visibility."""
    if name == "verilator" and seeing != visibility.ALL:
        return _LeanVerilator()
    return get_runner(name)

from fsverif import board
from fsverif.ip import compilable_sources, components, verify
from fsverif import visibility, wrapper

#: The board being verified. One board per checkout today; an environment
#: variable rather than a constant so that a second target does not need a
#: code change.
TARGET_BOARD = os.environ.get("FSVERIF_TARGET_BOARD", "a3pe3000l-fg484m")

VERIF_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = VERIF_ROOT.parent
RTL_DIR = REPO_ROOT / "src"

# The build's own variant generator, shared rather than reimplemented. Two
# copies would differ the first time one was changed, and the difference would
# be which design was simulated against which was built. Imported here rather
# than above because it is found through REPO_ROOT.
sys.path.insert(0, str(REPO_ROOT / "script"))
import build_variant  # noqa: E402
TESTS_DIR = VERIF_ROOT / "tests"
BUILD_DIR = VERIF_ROOT / "sim_build"

#: Raw coverage data, one file per test module. Merged by `coverage_code.py`.
COVERAGE_DIR = VERIF_ROOT / "coverage"

#: Generated vendor IP, and the definitions it is generated from. One fixed
#: location: a search finds whatever is newest, which is not the same as
#: whatever this design specifies.
#:
#: Neither path names a core. Components are whatever definitions exist, so
#: adding one is dropping a `*.tcl` into the components directory.
IP_DIR = VERIF_ROOT / "ip"
COMPONENTS_DIR = REPO_ROOT / "bd" / TARGET_BOARD / "components"

#: Where cocotb writes its JUnit XML. This is the only output this environment
#: produces, and it is deliberately the only one: a result is evidence, and
#: deciding what that evidence means about closure belongs to the checkers in
#: farsight-verification. An environment that computed its own trace matrix
#: would be a second data path to the same conclusion, and the two would
#: eventually disagree (framework VI.1).
RESULTS_DIR = VERIF_ROOT / "results"

#: Default simulator. Override globally with ``SIM=<name>``. Individual DUTs can
#: pin a different simulator via ``sim.run(simulator=...)``; see ``resolve_sim``.
SIM = os.environ.get("SIM", "verilator")

#: Simulators this environment knows how to drive, in fallback preference order.
KNOWN_SIMULATORS = ("verilator", "icarus", "questa", "nvc", "dsim", "xcelium", "vcs")

#: Executable that indicates each simulator is installed.
_SIM_EXECUTABLES = {
    "verilator": "verilator",
    "icarus": "iverilog",
    "questa": "vsim",
    "nvc": "nvc",
    "dsim": "dsim",
    "xcelium": "xrun",
    "vcs": "vcs",
}


class SimulatorUnavailable(Exception):
    """A DUT pinned a simulator that cannot be used here."""


def available_simulators() -> list[str]:
    """Return the known simulators that are installed *and* actually usable."""
    _ensure_toolchain_on_path()
    return [
        name
        for name in KNOWN_SIMULATORS
        if shutil.which(_SIM_EXECUTABLES.get(name, name)) and not simulator_problem(name)
    ]


def simulator_problem(name: str) -> str | None:
    """Return why ``name`` cannot be used with cocotb, or ``None`` if it is fine.

    The important case is bitness. cocotb loads its VPI/VHPI shared library into
    the simulator's own process, so the simulator must match the Python
    interpreter's architecture. The ModelSim/ModelSimPro bundled with Libero is
    a 32-bit x86 build, which cannot load 64-bit cocotb, and Ubuntu 24.04 has no
    32-bit Python to build a matching cocotb against.
    """
    executable = shutil.which(_SIM_EXECUTABLES.get(name, name))
    if executable is None:
        return "not installed"
    target = _resolve_real_binary(Path(executable))
    if target is None:
        return None  # a wrapper we cannot resolve; let the runner try
    if _is_32bit(target):
        return f"32-bit binary ({target}); cocotb is 64-bit and cannot load into it"
    return None


def resolve_sim(preferred: str | None = None) -> str:
    """Pick the simulator to use for one DUT.

    Precedence:

    1. An explicit ``SIM`` environment variable always wins, so a whole run can
       be forced onto one simulator for comparison.
    2. Otherwise the DUT's own ``preferred`` simulator, if it is installed.
    3. Otherwise the global default.

    Pinning a simulator per DUT is what keeps a single unsupported block from
    dictating the simulator for the entire suite: if some future vendor IP
    cannot be handled by the default simulator, only that DUT switches.

    A DUT that asks for a simulator it cannot have does **not** quietly get
    another one. A testbench pins a simulator because the default cannot
    handle it -- encrypted IP, device hard macros -- so substituting the
    default produces either a confusing failure about a missing module, or
    worse, a pass against something that is not the design. The caller may
    catch this and skip; it may not ignore it.
    """
    if os.environ.get("SIM"):
        return os.environ["SIM"]
    if preferred:
        if preferred in available_simulators():
            return preferred
        raise SimulatorUnavailable(
            "this DUT is pinned to %s, which is %s. It is pinned because the "
            "default simulator (%s) cannot handle it, so running on the "
            "default instead would not be the same test."
            % (preferred, simulator_problem(preferred) or "unavailable", SIM))
    return SIM


#: Locations of vendor simulators that are not normally on PATH. Only 64-bit
#: builds are usable: cocotb loads its VPI library into the simulator process,
#: so the simulator must match the Python interpreter's architecture. Libero's
#: ModelSim/ModelSimPro are 32-bit and therefore unusable; the QuestaSim shipped
#: with Libero SoC 2021+ is 64-bit and works.
_VENDOR_SIM_DIRS = (
    "/usr/local/microchip/Libero_SoC_v2024.1/QuestaSim/bin",
    "/opt/microchip/Libero_SoC_v2024.1/QuestaSim/bin",
    "/opt/microsemi/Libero_SoC_v2024.1/QuestaSim/bin",
)


def _ensure_toolchain_on_path() -> None:
    """Make the rootless and vendor toolchains usable without the Makefile.

    Anything already on PATH wins, so a system-wide install is preferred. The
    shim directory must stay ahead of the conda environment: Verilator's build
    step shells out to ``python3``, and the conda Python picks up the system
    standard library and dies with "SRE module mismatch".
    """
    home = Path.home()
    current = os.environ.get("PATH", "").split(os.pathsep)
    prefix = [
        str(p)
        for p in (home / ".local/opt/eda-shim", home / ".local/opt/micromamba/envs/eda/bin")
        if p.is_dir() and str(p) not in current
    ]
    # Usable (64-bit) vendor simulators. These are prepended rather than
    # appended, because the user's PATH frequently already contains a broken
    # 32-bit ModelSim that would otherwise shadow a working QuestaSim.
    usable_vendor = [
        d
        for d in _VENDOR_SIM_DIRS
        if Path(d).is_dir() and d not in current and not _is_32bit(Path(d) / "vsim")
    ]
    if prefix or usable_vendor:
        os.environ["PATH"] = os.pathsep.join([*prefix, *usable_vendor, *current])


def _is_32bit(path: Path) -> bool:
    """True if ``path`` (or the real binary a vendor wrapper points at) is 32-bit."""
    target = _resolve_real_binary(path)
    if target is None:
        return False
    try:
        header = target.read_bytes()[:5]
    except OSError:
        return False
    return header[:4] == b"\x7fELF" and header[4] == 1


def _resolve_real_binary(path: Path) -> Path | None:
    """Follow vendor shell-script launchers to the actual ELF binary."""
    if not path.exists():
        return None
    try:
        if path.read_bytes()[:4] == b"\x7fELF":
            return path
    except OSError:
        return None
    for sibling in (
        path.parent.parent / "linux_x86_64" / path.name,
        path.parent.parent / "linuxacoem" / path.name,
    ):
        if sibling.exists():
            return sibling
    return None


_ensure_toolchain_on_path()

#: Emit VCD waveforms when set (``WAVES=1``).
WAVES = os.environ.get("WAVES", "0") not in ("0", "", "no", "false")

#: Measure code coverage over the design. On by default, so that every run
#: says what it reached; ``FSVERIF_COVERAGE=0`` for a quick run without it.
#:
#: Instrumentation costs about six times the run: one module took 349 s with
#: coverage against 60 s without (`test_hk_lat_sw_region`, 2026-10-02, warm
#: build). Toggle coverage is kept despite being the costly kind, because it
#: is what shows a bit that never moves.
#:
#: **Not** `COVERAGE`, which cocotb already reads to mean something else
#: entirely: collecting Python coverage of the testbench code. Setting that
#: made cocotb import the `coverage` package mid-run and the simulation exited
#: without producing results, reporting only `SystemExit: 0`.
FSVERIF_COVERAGE = os.environ.get("FSVERIF_COVERAGE", "1") not in (
    "0", "", "no", "false")

#: What "measure coverage" means here, and one deliberate omission.
#:
#: `--coverage-fsm` is **not** included, and adding it would be worse than
#: leaving it out. It was tried on this design and produced **zero** points on
#: these enum state machines -- so a run would report FSM coverage as complete
#: while measuring nothing at all, which is the most dangerous shape a metric
#: can take. State and transition coverage has to be *authored* as cover
#: properties; `HK-F-01` was an unreachable transition on a line that executes
#: every cycle, and line coverage called it covered.
#:
#: `--coverage-per-instance` costs nothing: builds are byte-identical with and
#: without it, because the hierarchy is already in the model. It only changes
#: how points are reported, and `VENV-03` asks for per-instance reporting.
_COVERAGE_ARGS = [
    "--coverage-line",
    "--coverage-toggle",
    "--coverage-expr",
    "--coverage-per-instance",
]

#: Verilator warnings downgraded for the existing RTL. These are pre-existing
#: lint findings in the design, waived here so they do not mask new errors:
#:
#:   WIDTHEXPAND/WIDTHTRUNC  counter comparisons mix an 8-bit counter with
#:                           32-bit parameters.
#:   UNSIGNED                `cntr >= (TIME >> CNTR_PRECISION)` is constant when
#:                           the parameter is smaller than 2**CNTR_PRECISION, so
#:                           the corresponding delay rounds down to zero. See
#:                           "Known lint findings" in verif/README.md.
#:   UNOPTFLAT               combinational loop reported through the carry chain
#:                           in proasic3_counter.
_VERILATOR_WAIVERS = [
    "-Wno-WIDTHEXPAND",
    "-Wno-WIDTHTRUNC",
    "-Wno-UNSIGNED",
    "-Wno-UNOPTFLAT",
]

#: Per-simulator build arguments. Adding a new backend means adding one entry
#: here; the tests themselves are simulator-independent.
_BUILD_ARGS: dict[str, list[str]] = {
    "verilator": ["--timing", *_VERILATOR_WAIVERS],
    # -g2012 selects SystemVerilog-2012, which Icarus needs for always_ff and
    # the packed multidimensional arrays in dff_sync.sv.
    "icarus": ["-g2012"],
    "questa": [],
    "nvc": [],
}


def build_args_for(simulator: str) -> list[str]:
    """Build arguments for ``simulator``, empty if it needs no special flags."""
    return list(_BUILD_ARGS.get(simulator, []))


def rtl(*names: str) -> list[Path]:
    """Resolve RTL file names relative to the repo ``src/`` directory."""
    paths = []
    for name in names:
        path = RTL_DIR / name
        if not path.exists():
            raise FileNotFoundError(f"RTL source not found: {path}")
        paths.append(path)
    return paths


def device_sources() -> list[Path]:
    """Every source needed to elaborate the housekeeper as a whole device.

    Verification is at the FPGA boundary: a test drives pins and observes pins,
    which is what the requirements are written about. `HK-SRC-05` says a source
    is declared booted on a rising edge of its filtered PGOOD -- a test on
    `pwr_src_bootseq` shows the module does that, not that the device does.
    Reaching inside needs a reason stated in the item.

    Raises rather than falling back to a subset, because a source list that
    quietly loses a file produces a design that elaborates and is not the one
    under test.
    """
    return [*rtl("top.sv"), *ip_sources()]


#: The device under verification, and the clock period it runs at.
DEVICE = "top"

#: The variant the simulation exercises. `top.sv` includes a generated file
#: that decides whether TMR is enabled, so without one written here the device
#: does not compile at all.
#:
#: The flight variant, deliberately. `VENV-02` requires the environment to
#: exercise the design at its synthesis configuration, and TMR is part of that
#: configuration -- it triples every register. A simulation of the plain build
#: is a simulation of an article that must not be flown.
VARIANT = "fm_tmr"
WRAPPER = "tb_top"
CLK_PERIOD_NS = 20          # 50 MHz, `HK-CLK-01`


def run_device(*, test_module: str, parameters: dict | None = None,
               testcase: Sequence[str] | None = None,
               run_id: str | None = None, simulator: str | None = None,
               internal: Sequence[tuple] = ()) -> Path:
    """Build and run the whole housekeeper, clock included, at its pins.

    The wrapper carrying the clock is generated here from the device's own
    port list, into the build directory, on every run. It is never stored: it
    restates 115 port declarations, and a copy would describe a device that
    had gained or lost a pin the moment one changed.

    `internal` names signals inside the design to make addressable as well,
    as `(module, signal)` pairs -- every instance of that module. It is the
    narrow alternative to `FSVERIF_VISIBILITY=all`, which costs a factor of
    ten: a test that must see one internal signal, and whose item says why,
    names it here and pays for that signal alone.
    """
    label = run_id or test_module
    generated = BUILD_DIR / ("%s.generated" % label)
    device_rtl = RTL_DIR / ("%s.sv" % DEVICE)

    # The same generator the Libero build uses, so the simulation cannot be
    # compiling a variant the build never produces. Written before anything
    # reads `top.sv`, because `top.sv` includes it.
    build_variant.write(RTL_DIR, VARIANT)
    # The board's power rails, derived from the schematic and the regulator
    # datasheets. Without them the device cannot boot at all: every region of
    # the sequence waits for the rails it just enabled to report good, and
    # holding the power-good inputs at a constant level reached one enable of
    # thirty-three either way.
    rail_list = board.model()
    board_sv = board.write(rail_list, generated, CLK_PERIOD_NS)
    tb = wrapper.write(device_rtl, generated, CLK_PERIOD_NS,
                       module=WRAPPER, device=DEVICE, board=rail_list)

    # The config naming what cocotb may reach is generated from the same port
    # list as the wrapper. Two lists would disagree the first time a pin was
    # added, and the symptom would be a signal that simply does not exist.
    pins = [name for _, _, name in
            wrapper.ports(device_rtl.read_text(encoding="utf-8"))]
    vlt = visibility.config_file(
        generated, WRAPPER,
        pins + [wrapper.CLOCK_ENABLE, wrapper.RAIL_FAIL, wrapper.RAIL_FAULT,
                wrapper.RAIL_FORCE],
        internal=internal)

    return run(
        hdl_toplevel=WRAPPER,
        sources=[tb, vlt, board_sv, *device_sources()],
        test_module=test_module,
        parameters=parameters,
        testcase=testcase,
        run_id=run_id,
        simulator=simulator,
    )


def ip_sources() -> list[Path]:
    """Every generated vendor core the design defines, verified as current.

    One location, checked, rather than a search. The previous version took
    whichever build directory sorted last across any sibling checkout, which
    answers "the most recent core somebody generated" -- a different question
    from "the core this design specifies", and a different answer the moment
    anyone builds a branch.

    Sources come from the manifest Libero writes beside each component, so
    adding a core is dropping a definition into the components directory.
    """
    ip_root = Path(os.environ.get("FSVERIF_IP_DIR") or IP_DIR)
    verify(COMPONENTS_DIR, ip_root)       # raises StaleIP with the reason

    sources, held_back = [], {}
    for name in sorted(components(COMPONENTS_DIR)):
        usable, excluded = compilable_sources(ip_root / name, name)
        sources.extend(usable)
        held_back.update(excluded)

    for path, macro in sorted(held_back.items()):
        # Reported, never silent. A file dropped without saying so is a design
        # compiled without a block somebody believes is present.
        print("note: not compiling %s -- instantiates the %s hard macro, "
              "which a software simulator has no model for. If the design "
              "needs it, elaboration will fail with a missing module and this "
              "DUT should be pinned to Icarus or Questa."
              % (path.name, macro))
    return sources


def pa3_primitives() -> Path | None:
    """Locate the ProASIC3 behavioural primitive library, or ``None``.

    Needed only by DUTs that instantiate ProASIC3 hard macros (``FIFO4K18``,
    ``RAM4K9``, PLLs, or a core with its FIFOs enabled). The library is plain
    unencrypted Verilog shipped with Libero.

    Verilator cannot currently build this library under the ``--public-flat-rw``
    flag cocotb requires: it fails C++ code generation on the models' ``string``
    parameters (``LibName``, ``MacroType``) and ``specify`` timing variables.
    Icarus and Questa both compile it cleanly, so pin one of those on any DUT
    that needs it via ``sim.run(..., simulator="questa")``.
    """
    override = os.environ.get("FSVERIF_PA3_LIB")
    if override:
        path = Path(override)
        return path if path.exists() else None
    for root in ("/opt/microsemi", "/opt/microchip", "/usr/local/microchip"):
        for candidate in sorted(Path(root).glob("Libero*/Libero/lib/modelsim/precompiled/vlog/src/proasic3.v")):
            return candidate
    return None


def run(
    *,
    hdl_toplevel: str,
    sources: Sequence[Path],
    test_module: str,
    parameters: dict | None = None,
    includes: Sequence[Path] = (),
    testcase: Sequence[str] | None = None,
    run_id: str | None = None,
    simulator: str | None = None,
    timescale: tuple[str, str] = ("1ns", "100ps"),
) -> Path:
    """Build and run one DUT, returning the path to cocotb's ``results.xml``.

    Args:
        testcase: Restrict the run to these cocotb test names. Defaults to all.
        run_id: Unique label for this run's build directory and results file.
            Required when one test module is launched more than once, so the
            runs do not overwrite each other's results.
        simulator: Preferred simulator for this DUT. Used only when it is
            installed and ``SIM`` is not set, so one DUT that needs a specific
            simulator does not force the rest of the suite onto it.
    """
    active_sim = resolve_sim(simulator)
    seeing = visibility.requested()
    label = run_id or test_module
    # The simulator and the visibility are both part of the build directory
    # name. Switching backends must never reuse another simulator's products,
    # and rerunning a failure with more visibility must not silently reuse the
    # lean build -- a debugging session that starts by showing nothing.
    # Coverage is part of the directory name for the same reason visibility
    # is: an instrumented build and a lean one are different binaries, and
    # reusing one for the other either loses the measurement or pays for it
    # when nobody asked.
    flavour = f"{seeing.replace(':', '')}{'.cov' if FSVERIF_COVERAGE else ''}"
    build_dir = BUILD_DIR / f"{label}.{hdl_toplevel}.{active_sim}.{flavour}"
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    # Verilator's generated makefile builds incrementally. If the toolchain has
    # moved since the last build, the stale object files fail to link with a
    # bare "ld returned 1 exit status", so wipe the directory instead.
    stamp_file = build_dir / ".toolchain-stamp"
    stamp = json.dumps(
        {"sim": active_sim, "path": shutil.which(active_sim),
         "cxx": shutil.which("c++"), "visibility": seeing,
         "coverage": FSVERIF_COVERAGE},
        sort_keys=True,
    )
    if stamp_file.exists() and stamp_file.read_text() != stamp:
        shutil.rmtree(build_dir, ignore_errors=True)

    runner = _runner(active_sim, seeing)
    runner.build(
        sources=list(sources),
        includes=[RTL_DIR, *includes],
        hdl_toplevel=hdl_toplevel,
        parameters=parameters or {},
        build_args=(build_args_for(active_sim) + visibility.build_args(seeing)
                    + (_COVERAGE_ARGS if FSVERIF_COVERAGE and active_sim == "verilator"
                       else [])),
        build_dir=build_dir,
        timescale=timescale,
        waves=WAVES,
        always=True,
    )
    build_dir.mkdir(parents=True, exist_ok=True)
    stamp_file.write_text(stamp)

    # The simulator runs cocotb in its own process, which must be able to import
    # both the test modules and the fsverif support package.
    extra_env = dict(os.environ)
    extra_env["PYTHONPATH"] = os.pathsep.join(
        p for p in (str(VERIF_ROOT), str(TESTS_DIR), os.environ.get("PYTHONPATH", "")) if p
    )
    # Kept beside the results so a pass carries what it measured (`runlog`).
    extra_env["FSVERIF_RUN_LOG"] = str(RESULTS_DIR / f"log-{label}.txt")

    # Each module writes its own coverage file, named for the module. cocotb's
    # Verilator main calls VerilatedCov::write() and honours this plusarg; the
    # default is `coverage.dat` in the working directory, which every module
    # would then overwrite in turn -- leaving the coverage of whichever
    # happened to finish last, reported as the coverage of the suite.
    test_args, plusargs = [], []
    if FSVERIF_COVERAGE and active_sim == "verilator":
        COVERAGE_DIR.mkdir(parents=True, exist_ok=True)
        test_args = ["--coverage-per-instance"]
        plusargs = ["+verilator+coverage+file+%s"
                    % (COVERAGE_DIR / f"{label}.dat")]

    results = runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_module,
        testcase=list(testcase) if testcase else None,
        build_dir=build_dir,
        extra_env=extra_env,
        results_xml=str(RESULTS_DIR / f"results-{label}.xml"),
        test_args=test_args,
        plusargs=plusargs,
        waves=WAVES,
    )
    return Path(results)