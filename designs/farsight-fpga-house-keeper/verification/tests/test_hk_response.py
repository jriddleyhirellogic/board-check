"""How fast the housekeeper responds: HK-LAT-08, HK-REG-05 and HK-TLM-10.

Items: VC-HK-0008, VC-HK-0116, VC-HK-0083. Clause: VVP-HK-004.

  HK-LAT-08   A declared latchup shall deassert the affected power enables
              within 10 us of the fault first appearing at the input pin.
  HK-REG-05   (second clause) Within 10 us of a source in the region being
              declared failed, every enable in the region is deasserted.
  HK-TLM-10   A change in region boot status shall appear on the status
              outputs within 1 us of the change occurring.

**Where the bounds stand.** The 10 us was proposed on 2026-09-29 for
"immediately" in FAR-PM_FPGA_L4REQ-12, -14, -17 and -18, and the 1 us for the
reporting latency of -28 and -29. On 2026-10-01 avionics hardware confirmed
the 1 us and the 10 us for -14, measured from the nFAULT falling edge as
this test does; the 10 us for -12, -17 and -18 is still pending.

One timeline, recorded once (`_scenario`) and read by each test, because all
three are claims about the same few events:

1. DDR8's 1V2 rail held dead from reset, so its first attempt fails with the
   2V5 source already up. Released afterwards, so DDR8 boots on its retry and
   the chain carries on.
2. IMX requested and booted, then its 1V8 rail dropped: a latchup in a
   software-controlled region, which powers only IMX down.
3. DDR16's 1V2 nFAULT asserted: a latchup in a hardware-controlled region,
   which holds everything down. Last, because the device is spent after it.

**Where each clock starts.** `HK-LAT-08` measures from the pin, so the 5 us
input filter (`HK-IO-05`) is inside its 10 us. `HK-TLM-10` measures from the
change in status, which happens only once the filter has let the input
through; the test measures from the pin and takes off the filter's
pin-to-output latency, 252 clocks, measured on every filtered input by
`test_hk_io_filter`. `HK-REG-05`'s clock starts when the failed source is
declared failed, which is observable at the pins as that source's own enable
falling (`HK-SRC-04`).

Only the pins each step needs are watched, and only during that step:
`Edges` costs per watched pin on every evaluation.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import CLK_PERIOD_NS, advance, until
from fsverif.edges import Edges
from fsverif.pins import HARDWARE_REGIONS, SOFTWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: Proposed 2026-09-29; see the module docstring for which are confirmed.
RESPONSE_BOUND_US = 10.0
STATUS_BOUND_US = 1.0

#: Pin-to-filter-output latency of every filtered input, measured by
#: `test_hk_io_filter` (`HK-IO-05`).
FILTER_LATENCY_US = 252 * CLK_PERIOD_NS / 1000.0

#: How long to watch after each stimulus. Far longer than either bound, so an
#: enable that falls late is recorded as late rather than missed.
AFTER_US = 200.0

HARDWARE = dict(HARDWARE_REGIONS)
SOFTWARE = {r: enables for r, _, enables in SOFTWARE_REGIONS}
CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}

DDR8_DEAD, DDR8_FAILING, DDR8_EARLIER = "ddr8_pgood_1v2", "ddr8_en_1v2", "ddr8_en_2v5"
IMX_STATUS = "imx_status_to_pf"
IMX_PGOODS = ("imx_pgood_1v1", "imx_pgood_1v8", "imx_pgood_2v9", "imx_pgood_3v3")
IMX_DROPPED = "imx_pgood_1v8"
DDR16_FAULTED = "ddr16_pgood_1v2"   # the rail whose nFAULT the model asserts

_RECORD = {}


def _now_us() -> float:
    return get_sim_time("ns") / 1000.0


def _high(dut, name: str) -> bool:
    return int(boundary(dut, name).value) == 1


async def _stimulate(dut, **rails) -> float:
    """Apply a board change on a falling clock edge; return when, in us."""
    await FallingEdge(dut.clk)
    board.drive(dut, **rails)
    return _now_us()


def _last_fall_us(edges: Edges, names, since_us: float) -> dict:
    """For each of `names`, its first fall at or after `since_us`, in us."""
    out = {}
    for name in names:
        falls = [t * 1000.0 for t in edges.falls(name) if t * 1000.0 >= since_us]
        out[name] = falls[0] if falls else None
    return out


async def _scenario(dut) -> dict:
    if _RECORD:
        return _RECORD

    # 1. DDR8's second source fails its first attempt with the first up.
    ddr8 = HARDWARE["ddr8"]
    board.drive(dut, fail=(DDR8_DEAD,))
    await boot.release(dut)
    edges = Edges(dut, ddr8, origin_ns=0)
    await until(dut.clk, lambda: bool(edges.falls(DDR8_FAILING)), timeout_s=2.0,
                describe=lambda: "DDR8's 1V2 source was never declared failed")
    declared = edges.falls(DDR8_FAILING)[0] * 1000.0
    before = {e: [t * 1000.0 for t in edges.rises(e)] for e in ddr8}
    await advance(dut.clk, seconds=AFTER_US / 1e6)
    edges.stop()
    _RECORD["retry"] = {
        "declared_us": declared,
        "was_up": [e for e in ddr8 if any(t < declared for t in before[e])],
        "fell_us": _last_fall_us(edges, ddr8, declared),
    }
    board.drive(dut)
    await until(dut.clk, lambda: _high(dut, boot.LAST_HARDWARE_STATUS),
                timeout_s=3.0,
                describe=lambda: "the hardware regions never finished booting "
                                 "after DDR8's retry")

    # 2. IMX: booted, then latched up from its 1V8 rail.
    imx = SOFTWARE["imx"]
    edges = Edges(dut, imx + IMX_PGOODS + (IMX_STATUS,), origin_ns=0)
    boundary(dut, CONTROL["imx"]).value = 1
    await until(dut.clk, lambda: _high(dut, IMX_STATUS), timeout_s=0.1,
                poll_ms=0.1, describe=lambda: "IMX never booted")
    await advance(dut.clk, seconds=0.001)
    last_good = max(edges.rises(p)[-1] for p in IMX_PGOODS) * 1000.0
    booted_status = edges.rises(IMX_STATUS)[-1] * 1000.0
    up = [e for e in imx if _high(dut, e)]
    t0 = await _stimulate(dut, fail=(IMX_DROPPED,))
    await advance(dut.clk, seconds=AFTER_US / 1e6)
    edges.stop()
    fell = _last_fall_us(edges, imx + (IMX_STATUS,), t0)
    _RECORD["imx"] = {
        "last_good_us": last_good, "status_rose_us": booted_status,
        "t0_us": t0, "was_up": up,
        "fell_us": {e: fell[e] for e in imx},
        "status_fell_us": fell[IMX_STATUS],
    }
    boundary(dut, CONTROL["imx"]).value = 0
    board.drive(dut)
    await advance(dut.clk, seconds=0.005)

    # 3. DDR16: nFAULT on its 1V2 source, a hardware-region latchup.
    ddr16 = HARDWARE["ddr16"]
    up = [e for e in ddr16 if _high(dut, e)]
    edges = Edges(dut, ddr16, origin_ns=0)
    t0 = await _stimulate(dut, fault=(DDR16_FAULTED,))
    await advance(dut.clk, seconds=AFTER_US / 1e6)
    edges.stop()
    _RECORD["ddr16"] = {"t0_us": t0, "was_up": up,
                        "fell_us": _last_fall_us(edges, ddr16, t0)}
    return _RECORD


def _late(fell: dict, names, since_us: float, bound_us: float) -> list:
    problems = []
    for name in names:
        t = fell.get(name)
        if t is None:
            problems.append("%s never deasserted" % name)
        elif t - since_us > bound_us:
            problems.append("%s deasserted %.2f us after, beyond %g us"
                            % (name, t - since_us, bound_us))
    return problems


@cocotb.test()
async def test_HK_LAT_08_deassert_within_bound(dut):
    """VC-HK-0008: 10 us from the fault at the pin to the enables off."""
    record = await _scenario(dut)
    problems = []
    for region in ("imx", "ddr16"):
        r = record[region]
        assert r["was_up"], (
            "no %s enable was asserted when the fault was applied, so there "
            "was nothing to deassert and this would pass on nothing" % region)
        worst = max((t for t in r["fell_us"].values() if t is not None),
                    default=float("nan"))
        dut._log.info("%s latchup: %d enables up, last off %.2f us after the "
                      "pin", region, len(r["was_up"]), worst - r["t0_us"])
        problems += ["%s: %s" % (region, p) for p in
                     _late(r["fell_us"], r["was_up"], r["t0_us"], RESPONSE_BOUND_US)]
    assert not problems, (
        "a declared latchup did not deassert the affected enables within "
        "%g us of the fault appearing at the pin:\n  %s"
        % (RESPONSE_BOUND_US, "\n  ".join(problems)))


@cocotb.test()
async def test_HK_REG_05_enables_off_within_10us(dut):
    """VC-HK-0116: 10 us from a source declared failed to its region off."""
    r = (await _scenario(dut))["retry"]
    earlier = [e for e in r["was_up"] if e != DDR8_FAILING]
    assert DDR8_EARLIER in earlier, (
        "DDR8's 2V5 source was not up when the 1V2 source failed, so the "
        "failure had no other enable to take down and this would pass on "
        "nothing")
    worst = max(t for t in r["fell_us"].values() if t is not None)
    dut._log.info("DDR8 1V2 declared failed; last region enable off %.2f us "
                  "later", worst - r["declared_us"])
    problems = _late(r["fell_us"], r["was_up"], r["declared_us"], RESPONSE_BOUND_US)
    assert not problems, (
        "a source was declared failed and the region's enables were not all "
        "deasserted within %g us:\n  %s"
        % (RESPONSE_BOUND_US, "\n  ".join(problems)))


@cocotb.test()
async def test_HK_TLM_10_status_change_latency(dut):
    """VC-HK-0083: 1 us from the filtered change to the status output."""
    r = (await _scenario(dut))["imx"]
    assert r["status_fell_us"] is not None, (
        "IMX's status never fell after its latchup, so there is no change to "
        "time")
    rose = r["status_rose_us"] - r["last_good_us"] - FILTER_LATENCY_US
    fell = r["status_fell_us"] - r["t0_us"] - FILTER_LATENCY_US
    dut._log.info("IMX status: rose %.3f us and fell %.3f us after the filter "
                  "let the change through", rose, fell)
    problems = []
    for what, dt in (("booted", rose), ("latched up", fell)):
        if dt < 0:
            problems.append("%s: status moved %.3f us before the input was "
                            "filtered -- a measurement fault" % (what, -dt))
        elif dt > STATUS_BOUND_US:
            problems.append("%s: status moved %.3f us after the change, beyond "
                            "%g us" % (what, dt, STATUS_BOUND_US))
    assert not problems, (
        "a change in IMX's boot status did not reach imx_status_to_pf within "
        "%g us:\n  %s" % (STATUS_BOUND_US, "\n  ".join(problems)))


def test_hk_response():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_response",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
