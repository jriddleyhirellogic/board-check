"""FPGA image identification: PF-VER-01.

Item: VC-PF-0069. Clause: VVP-PF-001.

  PF-VER-01  The hardware-version APB registers shall expose the build version
             and the source control commit identifier of the image.

**The DUT is `hw_version_apb_reg` as the build generates it.** Its values are
not in the repository: `synth.tcl` copies
`ip/hw_version_ip/template/hw_version_apb_reg.sv.template` and patches the
version, commit and build time into it with `proj::copy_template` and
`proj::update_build_params` (`script/common/proj_util.tcl`). The test runs
those same procs, under `tclsh`, with the arguments `synth.tcl:170-175` passes
-- the commit as `synth.tcl:88` derives it, the first 8 hex digits of
`git rev-parse HEAD` -- and simulates what they produce. So what is tested is
the path from build inputs to register, not a hand-edited copy.

Each case is a separate generation and build, because the values are
localparams. Firmware reads the registers over APB at `0x00` (version,
major.minor.fix.build, one byte each from the top), `0x04` (commit) and `0x08`
(build time).
"""

from __future__ import annotations

import json
import os

import cocotb
from cocotb.triggers import ClockCycles

from fsverif import hw_version, sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import start_clock

EXPECT = "FSVERIF_PF_VER_EXPECT"


@cocotb.test()
async def test_PF_VER_01_registers_expose_version_and_commit(dut):
    """VC-PF-0069: the registers read back the version and commit the build was given."""
    want = json.loads(os.environ[EXPECT])
    start_clock(dut.pclk, 20)
    apb = Apb(dut, dut.pclk, "")
    dut.presetn.value = 1
    await ClockCycles(dut.pclk, 2)
    dut.presetn.value = 0
    await ClockCycles(dut.pclk, 5)
    dut.presetn.value = 1
    await ClockCycles(dut.pclk, 5)

    version = (await apb.read(0x00)).data
    commit = (await apb.read(0x04)).data
    built = (await apb.read(0x08)).data
    expected_version = ((want["major"] << 24) | (want["minor"] << 16)
                        | (want["fix"] << 8) | want["build"])
    dut._log.info("%s: version 0x%08x (%d.%d.%d.%d), commit %08x, build time %d; "
                  "given %d.%d.%d.%d and %s", want["case"], version, version >> 24,
                  (version >> 16) & 0xFF, (version >> 8) & 0xFF, version & 0xFF,
                  commit, built, want["major"], want["minor"], want["fix"],
                  want["build"], want["commit"])
    problems = []
    if version != expected_version:
        problems.append("version reads 0x%08x, not 0x%08x" % (version, expected_version))
    if commit != int(want["commit"], 16):
        problems.append("commit reads %08x, not %s" % (commit, want["commit"]))
    if version == 0 or commit == 0:
        problems.append("a field reads zero")

    # Read-only: a write changes nothing.
    await apb.write(0x00, ~expected_version & 0xFFFF_FFFF)
    await apb.write(0x04, ~commit & 0xFFFF_FFFF)
    if (await apb.read(0x00)).data != version or (await apb.read(0x04)).data != commit:
        problems.append("a write changed a read-only register")
    assert not problems, "\n  ".join(["PF-VER-01 (%s):" % want["case"]] + problems)


# -----------------------------------------------------------------------------

def _run(case: str, major: int, minor: int, fix: int, build: int, commit: str) -> None:
    source = hw_version.generate(sim.BUILD_DIR / ("test_pf_ver.%s.src" % case),
                                 major, minor, fix, build, commit, 1_790_000_000)
    os.environ[EXPECT] = json.dumps({"case": case, "major": major, "minor": minor,
                                     "fix": fix, "build": build, "commit": commit})
    try:
        sim.run(hdl_toplevel="hw_version_apb_reg", sources=[source],
                test_module="test_pf_ver", run_id="test_pf_ver.%s" % case)
    finally:
        del os.environ[EXPECT]


def test_pf_ver_01_this_commit():
    """This checkout's HEAD, with the version of the last flight build (2.0.1.4)."""
    _run("head", 2, 0, 1, 4, hw_version.head_commit())


def test_pf_ver_01_field_limits():
    """Every version field at its maximum, and a commit with leading zeros."""
    _run("limits", 255, 255, 255, 255, "00a1b2c3")


def test_pf_ver_01_low_values():
    """Every version field at its minimum but the last, and a commit whose top bit is set."""
    _run("low", 0, 0, 0, 1, "fedcba98")
