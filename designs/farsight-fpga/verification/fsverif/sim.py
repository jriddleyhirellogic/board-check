"""Shared simulation plumbing: source lists, simulator selection, runner helper.

Two simulators, each for what it can do. Verilator is the default: it is fast,
and it compiles our own IP blocks and the soft vendor cores (CoreGPIO,
COREFIFO, the APB/AHB/AXI fabric, MIV_RV32 and so on), which Libero generates
as plain Verilog. It cannot compile what Microchip ships encrypted --
SLVS_EC_RX, CORETSE, PF_DDR4 -- nor the hard blocks that have no source model
at all: IOD, LANECTRL, DLL, XCVR, PCIE, TX_PLL. A DUT that needs any of those
pins itself to QuestaSim, which has Libero's precompiled PolarFire library.
See `resolve_sim`.
"""

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
    It costs a factor of ten on a design of any size, so it is dropped here and the
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


from fsverif import visibility
from fsverif.ip import compilable_sources, verify_named

#: The board being verified. One board per checkout today; an environment
#: variable rather than a constant so that a second target does not need a
#: code change.
TARGET_BOARD = os.environ.get("FSVERIF_TARGET_BOARD", "mpf500ts-fc1152m")

VERIF_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = VERIF_ROOT.parent
#: Our own fabric IP: one directory per block, sources under `src/`.
IP_BLOCKS_DIR = REPO_ROOT / "ip"
TESTS_DIR = VERIF_ROOT / "tests"
BUILD_DIR = VERIF_ROOT / "sim_build"

#: Raw coverage data, one file per test module. Merged by `code_coverage.py`.
COVERAGE_DIR = VERIF_ROOT / "coverage"

#: Generated vendor IP: one directory per component, each with a lockfile
#: recording what it was generated from. Which components are generated is
#: `verification/ip.yaml`; their definitions stay where the build keeps them,
#: under `bd/<board>/` and `ip/`.
IP_DIR = VERIF_ROOT / "ip"

#: Where cocotb writes its JUnit XML. This is the only output this environment
#: produces, and it is deliberately the only one: a result is evidence, and
#: deciding what that evidence means about closure belongs to the checkers.
#: An environment that computed its own trace matrix would be a second data
#: path to the same conclusion, and the two would eventually disagree.
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


def _python_shim() -> Path:
    """A directory whose ``python3`` is the interpreter running the tests.

    Verilator's build step shells out to ``python3`` for `verilator_includer`,
    with cocotb's ``PYTHONPATH`` set to this interpreter's ``sys.path``. Any
    other Python -- the conda environment's own, found next to Verilator --
    loads this one's standard library and dies with "SRE module mismatch",
    leaving an empty ``Vtop__ALL.cpp`` that fails to link. So the build gets
    this interpreter, from a directory this checkout owns. Nothing here is
    shared with another checkout: a shared shim under ``$HOME`` was rewritten
    by another checkout's setup script, and every Verilator build broke.
    """
    shim = BUILD_DIR / ".python-shim"
    link = shim / "python3"
    target = os.path.realpath(sys.executable)
    if not (link.is_symlink() and os.readlink(link) == target):
        shim.mkdir(parents=True, exist_ok=True)
        # Atomic, as xdist workers import this module concurrently.
        staging = shim / ("python3.%d" % os.getpid())
        staging.unlink(missing_ok=True)
        staging.symlink_to(target)
        os.replace(staging, link)
    return shim


def _ensure_toolchain_on_path() -> None:
    """Make the rootless and vendor toolchains usable without the Makefile.

    The checkout's own Verilator environment, which `setup-tools.sh` builds
    under ``<repo>/.tools``, is used when present; otherwise anything already
    on PATH. The Python shim goes first, ahead of the conda environment even
    when the Makefile has put that first (`_python_shim`).
    """
    shim = str(_python_shim())
    current = [p for p in os.environ.get("PATH", "").split(os.pathsep) if p != shim]
    prefix = [
        str(p)
        for p in (REPO_ROOT / ".tools/micromamba/envs/eda/bin",)
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
    os.environ["PATH"] = os.pathsep.join([shim, *prefix, *usable_vendor, *current])


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

#: Measure code coverage over the design: on unless ``FSVERIF_COVERAGE=0``
#: (``make test COV=0``).
#:
#: On by default, so every run says what it reached; instrumentation costs
#: several times the run, which is why it can be switched off for a quick
#: rerun of one module. Both simulators measure: Verilator writes
#: `<run>.dat`, QuestaSim `<run>.ucdb`, and `code_coverage.py` merges them.
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
#: leaving it out. Tried on the PA3 housekeeper, it produced **zero** points on
#: enum state machines -- so a run would report FSM coverage as complete while
#: measuring nothing at all, which is the most dangerous shape a metric can
#: take. State and transition coverage has to be *authored* as cover
#: properties; an unreachable transition sits on a line that executes every
#: cycle, and line coverage calls it covered.
#:
#: `--coverage-per-instance` costs nothing: builds are byte-identical with and
#: without it, because the hierarchy is already in the model. It only changes
#: how points are reported.
_COVERAGE_ARGS = [
    "--coverage-line",
    "--coverage-toggle",
    "--coverage-expr",
    "--coverage-per-instance",
]

#: Verilator's lint and style warnings are switched off, and the rest are made
#: non-fatal. A simulation is not the lint flow: whether a width mismatch or an
#: incomplete case is acceptable is a finding the lint flow owns and
#: dispositions, and a test that failed on one would be deciding it -- or,
#: worse, be edited to silence it. Functional warnings (multiple drivers,
#: timing constructs) still print, and a reader of the log still sees them.
_VERILATOR_WAIVERS = [
    "-Wno-fatal",
    "-Wno-lint",
    "-Wno-style",
]

#: Per-simulator build arguments. Adding a new backend means adding one entry
#: here; the tests themselves are simulator-independent.
#: QuestaSim's equivalent: statement, branch, condition, expression and toggle,
#: compiled in by `vlog` and collected by `vsim -coverage`. Its FSM coverage
#: (`f`) is left out for the reason Verilator's is.
_QUESTA_COVERAGE_BUILD = ["+cover=sbcet"]
_QUESTA_COVERAGE_TEST = ["-coverage"]

_BUILD_ARGS: dict[str, list[str]] = {
    "verilator": ["--timing", *_VERILATOR_WAIVERS],
    # -g2012 selects SystemVerilog-2012, which Icarus needs for always_ff.
    "icarus": ["-g2012"],
    "questa": [],
    "nvc": [],
}


def _coverage_build_args(simulator: str) -> list[str]:
    """What instruments a build for coverage, if coverage is being measured."""
    if not FSVERIF_COVERAGE:
        return []
    return {"verilator": _COVERAGE_ARGS, "questa": _QUESTA_COVERAGE_BUILD}.get(simulator, [])


def build_args_for(simulator: str) -> list[str]:
    """Build arguments for ``simulator``, empty if it needs no special flags."""
    return list(_BUILD_ARGS.get(simulator, []))




def block(name: str, *files: str) -> list[Path]:
    """Sources of one of our IP blocks, `ip/<name>/src/<file>`.

    Named file by file rather than globbed, so a test states exactly what it
    compiles, and a file added to the block that the test does not know about
    is not silently swept into it. Raises on a name that does not exist: a
    source list that quietly loses a file elaborates a design that is not the
    one under test.
    """
    root = IP_BLOCKS_DIR / name / "src"
    paths = []
    for f in files:
        path = root / f
        if not path.is_file():
            raise FileNotFoundError("IP block source not found: %s" % path)
        paths.append(path)
    return paths


def vendor(*components: str) -> list[Path]:
    """Sources of generated vendor components, verified as current.

    One location, checked, rather than a search: a search finds whatever
    somebody generated most recently, which is not the same as what this
    design specifies. Each component must be listed in `verification/ip.yaml`,
    generated by `make ip`, and still match its definition -- `verify_named`
    raises `StaleIP` with the reason otherwise.
    """
    ip_root = Path(os.environ.get("FSVERIF_IP_DIR") or IP_DIR)
    verify_named(components, ip_root)
    sources, held_back = [], {}
    for name in components:
        usable, excluded = compilable_sources(ip_root / name, name)
        sources.extend(usable)
        held_back.update(excluded)
    for path, macro in sorted(held_back.items()):
        # Reported, never silent. A file dropped without saying so is a design
        # compiled without a block somebody believes is present.
        print("note: not compiling %s -- it instantiates the %s hard block, "
              "which Verilator has no model for. If the DUT needs it, "
              "elaboration fails with a missing module, and the DUT should be "
              "pinned to questa." % (path.name, macro))
    return sources


#: Libero's PolarFire primitive library: plain Verilog for the primitives it
#: models (PLL, OSC, INIT, the clock mux and divider, the RAM blocks), and a
#: precompiled QuestaSim library that also has the hard blocks it does not.
_LIBERO_ROOTS = ("/opt/microchip", "/usr/local/microchip", "/opt/microsemi")


def polarfire_source() -> Path | None:
    """The PolarFire primitive library as source, or ``None``.

    Verilator compiles it, and it is a real model rather than a shell:
    `RAM1K20` wraps `RAM1K20_IP`, some 2,500 lines of behaviour. So a vendor
    core built from block RAM -- every COREFIFO in this design -- runs on the
    fast simulator with this file added. What it does not contain is the hard
    blocks listed in `fsverif.ip.HARD_MACROS`; those need questa.
    """
    override = os.environ.get("FSVERIF_PF_LIB")
    if override:
        return Path(override) if Path(override).is_file() else None
    for root in _LIBERO_ROOTS:
        for candidate in sorted(Path(root).glob("Libero_SoC_v2024*/Libero/lib/vlog/polarfire.v")):
            return candidate
    return None


def polarfire_questa() -> Path | None:
    """The precompiled PolarFire library for QuestaSim, or ``None``."""
    for root in _LIBERO_ROOTS:
        for candidate in sorted(Path(root).glob(
                "Libero_SoC_v2024*/Libero/lib/questasim/precompiled/vlog/polarfire")):
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
    timescale: tuple[str, str] = ("1ns", "1ps"),
    internal: Sequence[tuple] = (),
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
        internal: ``(module, signal)`` pairs inside the design to make
            addressable -- every instance of that module. The narrow
            alternative to ``FSVERIF_VISIBILITY=all``, which costs a factor of
            ten: a test that must see one internal signal, and whose item says
            why, names it here and pays for that signal alone.
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
    # A build whose `verilator_includer` failed leaves an empty Vtop__ALL.cpp
    # that make then treats as up to date, so every later build fails to link
    # until the directory goes.
    all_cpp = build_dir / "Vtop__ALL.cpp"
    if all_cpp.exists() and all_cpp.stat().st_size == 0:
        shutil.rmtree(build_dir, ignore_errors=True)

    sources = list(sources)
    if active_sim == "verilator":
        # The top module's own signals -- its ports, and in a SmartDesign the
        # nets between its instances -- are always reachable; nothing below
        # it is unless a test names it. A PolarFire DUT has no generated
        # device wrapper to take a port list from, and the top of a block is
        # small enough that "all of it" costs nothing measurable. First in the
        # list: cocotb takes the language of the top from the *last* source.
        sources.insert(0, visibility.config_file(
            BUILD_DIR / f"{label}.generated", hdl_toplevel, ["*"],
            internal=internal))

    runner = _runner(active_sim, seeing)
    runner.build(
        sources=sources,
        includes=list(includes),
        hdl_toplevel=hdl_toplevel,
        parameters=parameters or {},
        build_args=(build_args_for(active_sim) + visibility.build_args(seeing)
                    + _coverage_build_args(active_sim)),
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
    # QuestaSim saves its database when vsim exits, which a `-do` ahead of
    # cocotb's own run script arranges.
    test_args, plusargs, pre_cmd = [], [], None
    if FSVERIF_COVERAGE and active_sim == "verilator":
        COVERAGE_DIR.mkdir(parents=True, exist_ok=True)
        test_args = ["--coverage-per-instance"]
        plusargs = ["+verilator+coverage+file+%s"
                    % (COVERAGE_DIR / f"{label}.dat")]
    elif FSVERIF_COVERAGE and active_sim == "questa":
        COVERAGE_DIR.mkdir(parents=True, exist_ok=True)
        test_args = list(_QUESTA_COVERAGE_TEST)
        pre_cmd = ["coverage save -onexit %s" % (COVERAGE_DIR / f"{label}.ucdb").as_posix()]

    results = runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_module,
        testcase=list(testcase) if testcase else None,
        build_dir=build_dir,
        extra_env=extra_env,
        results_xml=str(RESULTS_DIR / f"results-{label}.xml"),
        test_args=test_args,
        plusargs=plusargs,
        pre_cmd=pre_cmd,
        waves=WAVES,
    )
    return Path(results)