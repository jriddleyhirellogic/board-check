"""Focus mechanism: PF-FOCUS-01, -08, -09, -10, -12 and -13.

Items: VC-PF-0055, VC-PF-0057, VC-PF-0060, VC-PF-0063, VC-PF-0066, VC-PF-0067.
Clause: VVP-PF-001.

  PF-FOCUS-01  The focus mechanism interface shall suppress both physical step
               outputs while the watchdog is inactive.
  PF-FOCUS-08  The stepper pin interface shall provide at least 3.0 us between
               step assertions.
  PF-FOCUS-09  The stepper pin interface shall hold each step-low interval for
               at least 1.5 us.
  PF-FOCUS-10  The stepper pin interface shall provide at least 0.3 us of
               direction setup before a step pulse.
  PF-FOCUS-12  The focus watchdog shall reload its timeout when firmware clears
               or refreshes it.
  PF-FOCUS-13  The focus watchdog shall report inactive when its programmed
               timeout expires.

**The DUT is `focus_mech`**, as the build generates it: two `STEPPER_DRIVER`s
(`STEP_DIR` with its GPIO and PWM cores), the focus watchdog, the LVDT readout,
and the `AND2`s and `OUTBUF`s between them and the pins. It is clocked at
50 MHz (`sys_clk_50mhz`) and driven over its APB ports as flight software
drives it (`farsight-avionics-sw/Camera/src/hal/hal_stepper.c`):

- **Arm:** CLEAR = 1, TIMEOUT_MS = t, CLEAR = 0 (`v_Arm_Stepper_Watchdog`).
- **Refresh:** TIMEOUT_MS = t (`v_Refresh_Stepper_Watchdog`).
- **Motion:** the step overflow is 4,882,813 (`hw_init.c`), and a velocity v
  written to STEPPER_OUT steps at v / 4,882,813 x 50 MHz, clamped by the
  design's minimum spacing.

Timing is measured at the pads (`pri_stp_motor_step` and its siblings), past
the watchdog's AND gates. Commanded motion is observed before them, on the
nets from each `STEPPER_DRIVER`, which are top-level nets of the SmartDesign.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import ClockCycles, Timer, ValueChange
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import start_clock

CLK_NS = 20
OVERFLOW = 4_882_813                   # hw_init.c, both motors
FULL = OVERFLOW                        # a step every clock, before the clamp
GPIO_OUT = 0xA0
WD_CLEAR, WD_TIMEOUT_MS, WD_STATUS = 0x0, 0x4, 0x8
FLIGHT_TIMEOUT_MS = 100                # hal_stepper.h WATCHDOG_TIMEOUT_MS
MOTORS = {
    "pri": ("PRI_STP_APB_STEPPER_OUT_", "PRI_STP_APB_STEPPER_OVERFLOW_",
            "STEPPER_DRIVER_1_STEPPER_STEP"),
    "sec": ("SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_",
            "SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_",
            "STEPPER_DRIVER_2_STEPPER_STEP"),
}


def _now_us() -> float:
    return get_sim_time("ns") / 1000


class Trace:
    """Every change of one signal, as (time in us, new value)."""

    def __init__(self, sig):
        self.sig, self.changes = sig, []
        self.task = cocotb.start_soon(self._run())

    async def _run(self):
        while True:
            await ValueChange(self.sig)
            v = self.sig.value
            self.changes.append((_now_us(), int(v) if v.is_resolvable else None))

    def rises(self, after: float = 0.0, before: float = float("inf")):
        return [t for t, v in self.changes if v == 1 and after <= t < before]

    def falls(self, after: float = 0.0, before: float = float("inf")):
        return [t for t, v in self.changes if v == 0 and after <= t < before]


class Focus:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.sys_clk_50mhz

    async def start(self) -> None:
        dut = self.dut
        start_clock(self.clk, CLK_NS)
        # Every APB port idle; the tests drive only the ones they name.
        for handle in dut:
            if handle._name.upper().endswith(("_PSEL", "_PENABLE", "_PWRITE")):
                handle.value = 0
        dut.lvdt_adc_spi_miso.value = 0
        dut.pri_stp_motor_fault_n.value = 1
        dut.sec_stp_motor_fault_n.value = 1
        self.wd = Apb(dut, self.clk, "apb_stepper_wd_")
        self.out = {m: Apb(dut, self.clk, p[0]) for m, p in MOTORS.items()}
        self.ovf = {m: Apb(dut, self.clk, p[1]) for m, p in MOTORS.items()}
        dut.sys_rst_n.value = 1
        await ClockCycles(self.clk, 2)
        dut.sys_rst_n.value = 0
        await ClockCycles(self.clk, 10)
        dut.sys_rst_n.value = 1
        await ClockCycles(self.clk, 10)
        self.pin = {m: Trace(getattr(dut, "%s_stp_motor_step" % m)) for m in MOTORS}
        self.dir = {m: Trace(getattr(dut, "%s_stp_motor_dir" % m)) for m in MOTORS}
        self.cmd = {m: Trace(getattr(dut, p[2])) for m, p in MOTORS.items()}
        self.active = Trace(dut.watchdog_top_inst_wd_active)
        for m in MOTORS:
            await self.ovf[m].write(GPIO_OUT, OVERFLOW)

    async def velocity(self, v: int) -> None:
        for m in MOTORS:
            await self.out[m].write(GPIO_OUT, v & 0xFFFF_FFFF)

    async def arm(self, ms: int) -> float:
        """Flight software's arming sequence; returns when CLEAR = 0 is written."""
        await self.wd.write(WD_CLEAR, 1)
        await self.wd.write(WD_TIMEOUT_MS, ms)
        await self.wd.write(WD_CLEAR, 0)
        return _now_us()

    async def refresh(self, ms: int) -> float:
        await self.wd.write(WD_TIMEOUT_MS, ms)
        return _now_us()

    async def status(self) -> int:
        return (await self.wd.read(WD_STATUS)).data & 1

    async def until(self, t_us: float) -> None:
        if t_us > _now_us():
            await Timer(round((t_us - _now_us()) * 1000), unit="ns")


async def _exercise(f: Focus) -> None:
    """Commanded motion that stresses the pin timing, under an armed watchdog."""
    await f.arm(50)
    for v, us in ((FULL, 100), (-FULL, 100), (OVERFLOW // 300, 60),
                  (-OVERFLOW // 300, 60)):
        await f.velocity(v)
        await Timer(us, unit="us")
    # Direction reversals as fast as the bus allows, at full speed.
    for n in range(24):
        await f.velocity(FULL if n % 2 else -FULL)
        await Timer(2 + n % 5, unit="us")
    # Reversals timed against the steps: each just after a step leaves.
    for n in range(12):
        await f.velocity(-FULL if n % 2 else FULL)
        before = len(f.pin["pri"].rises())
        while len(f.pin["pri"].rises()) == before:
            await ClockCycles(f.clk, 1)
        await ClockCycles(f.clk, n)
    await f.velocity(0)
    await Timer(20, unit="us")


def _pin_problems(f: Focus, check: str) -> list[str]:
    problems = []
    for m in MOTORS:
        rises, falls = f.pin[m].rises(), f.pin[m].falls()
        dirs = [t for t, _ in f.dir[m].changes]
        gaps = [b - a for a, b in zip(rises, rises[1:])]
        highs = [next(x for x in falls if x > r) - r for r in rises if any(x > r for x in falls)]
        lows = [next(r for r in rises if r > x) - x for x in falls if any(r > x for r in rises)]
        setups = [r - max((d for d in dirs if d <= r), default=float("-inf")) for r in rises]
        holds = [min((d for d in dirs if d > r), default=float("inf")) - r for r in rises]
        f.dut._log.info(
            "%s: %d steps, %d direction changes. Between assertions min %.3f us; "
            "low min %.3f us; high min %.3f us; direction setup min %.3f us; "
            "direction change after a step min %.3f us", m, len(rises), len(dirs),
            min(gaps), min(lows), min(highs), min(setups), min(holds))
        if len(rises) < 50 or len(dirs) < 20:
            problems.append("%s: only %d steps and %d direction changes were exercised"
                            % (m, len(rises), len(dirs)))
        if check == "08" and min(gaps) < 3.0:
            problems.append("%s: step assertions %.3f us apart, under 3.0 us (%d of %d)"
                            % (m, min(gaps), sum(g < 3.0 for g in gaps), len(gaps)))
        if check == "09" and min(lows) < 1.5:
            problems.append("%s: a step-low interval of %.3f us, under 1.5 us (%d of %d)"
                            % (m, min(lows), sum(x < 1.5 for x in lows), len(lows)))
        if check == "10" and min(setups) < 0.3:
            problems.append("%s: a step %.3f us after a direction change, under 0.3 us "
                            "(%d of %d)" % (m, min(setups), sum(s < 0.3 for s in setups),
                                            len(setups)))
    return problems


# -----------------------------------------------------------------------------

@cocotb.test()
async def test_PF_FOCUS_01_watchdog_inactive_suppresses_steps(dut):
    """VC-PF-0055: no step at either pin while the watchdog is inactive."""
    f = Focus(dut)
    await f.start()
    problems = []

    async def window(label, us, expect_pins):
        t0 = _now_us()
        await Timer(us, unit="us")
        t1 = _now_us()
        for m in MOTORS:
            cmd, pin = len(f.cmd[m].rises(t0, t1)), len(f.pin[m].rises(t0, t1))
            dut._log.info("%s, %s: %d steps commanded, %d at the pin", label, m, cmd, pin)
            if cmd < 20:
                problems.append("%s, %s: only %d steps were commanded" % (label, m, cmd))
            if expect_pins and pin != cmd:
                problems.append("%s, %s: %d of %d commanded steps reached the pin"
                                % (label, m, pin, cmd))
            if not expect_pins and pin:
                problems.append("%s, %s: %d steps reached the pin with the watchdog "
                                "inactive" % (label, m, pin))

    await f.velocity(FULL)
    await window("never armed", 200, False)
    armed = await f.arm(1)
    await window("armed", 200, True)
    await f.until(armed + 1000 + 5)
    expired = f.active.falls()
    dut._log.info("armed at %.3f us, inactive at %s us",
                  armed, ", ".join("%.3f" % t for t in expired))
    if await f.status():
        problems.append("the status register still reads active after the timeout")
    await window("expired", 200, False)
    # A step in flight when the lease ends is cut short at the pin.
    if expired:
        for m in MOTORS:
            last = [r for r in f.pin[m].rises() if r < expired[0]]
            if last:
                end = min(x for x in f.pin[m].falls() if x > last[-1])
                dut._log.info("%s: last step before expiry rose at %.3f us and fell "
                              "at %.3f us, %.3f us wide", m, last[-1], end, end - last[-1])
    assert not problems, "\n  ".join(["PF-FOCUS-01:"] + problems)


@cocotb.test()
async def test_PF_FOCUS_08_step_assertions_at_least_3us(dut):
    """VC-PF-0057: at least 3.0 us between step assertions at the pin."""
    f = Focus(dut)
    await f.start()
    await _exercise(f)
    problems = _pin_problems(f, "08")
    assert not problems, "\n  ".join(["PF-FOCUS-08:"] + problems)


@cocotb.test()
async def test_PF_FOCUS_09_step_low_at_least_1_5us(dut):
    """VC-PF-0060: every step-low interval at the pin at least 1.5 us."""
    f = Focus(dut)
    await f.start()
    await _exercise(f)
    problems = _pin_problems(f, "09")
    assert not problems, "\n  ".join(["PF-FOCUS-09:"] + problems)


@cocotb.test()
async def test_PF_FOCUS_10_direction_setup_at_least_0_3us(dut):
    """VC-PF-0063: direction stable at least 0.3 us before each step."""
    f = Focus(dut)
    await f.start()
    await _exercise(f)
    problems = _pin_problems(f, "10")
    assert not problems, "\n  ".join(["PF-FOCUS-10:"] + problems)


@cocotb.test()
async def test_PF_FOCUS_12_watchdog_reload_on_clear_or_refresh(dut):
    """VC-PF-0066: a refresh or a clear restarts the full timeout."""
    f = Focus(dut)
    await f.start()
    problems = []
    await f.velocity(FULL)

    async def lease_after(label, t_cmd, ms, t_from):
        """The watchdog must stay active until t_cmd + ms, then expire."""
        before = len(f.active.falls())
        await f.until(t_cmd + ms * 1000 + 5)
        falls = f.active.falls()[before:]
        dut._log.info("%s at %.3f us: inactive at %s us, %.3f ms after it",
                      label, t_cmd, ", ".join("%.3f" % t for t in falls) or "never",
                      (falls[0] - t_cmd) / 1000 if falls else float("nan"))
        if not falls:
            problems.append("%s: still active %.3f ms after it" % (label, ms + 0.005))
        elif falls[0] < t_cmd + ms * 1000 - 0.1:
            problems.append("%s at %.3f us: inactive at %.3f us, %.3f ms after it -- %.3f "
                            "ms after the lease before it" % (label, t_cmd, falls[0],
                                                              (falls[0] - t_cmd) / 1000,
                                                              (falls[0] - t_from) / 1000))

    armed = await f.arm(2)
    await f.until(armed + 1500)
    refreshed = await f.refresh(2)
    await lease_after("refresh", refreshed, 2, armed)

    armed = await f.arm(2)
    await f.until(armed + 1500)
    await f.wd.write(WD_CLEAR, 1)
    await Timer(50, unit="us")
    cleared = _now_us()
    await f.wd.write(WD_CLEAR, 0)
    await lease_after("clear", cleared, 2, armed)

    # A refresh after expiry does not restore the lease: only an arm does.
    await f.refresh(2)
    await Timer(100, unit="us")
    dut._log.info("refresh after expiry: status %d", await f.status())
    if await f.status():
        problems.append("a refresh after expiry made the watchdog active again")
    assert not problems, "\n  ".join(["PF-FOCUS-12:"] + problems)


@cocotb.test()
async def test_PF_FOCUS_13_inactive_after_timeout(dut):
    """VC-PF-0067: inactive at the status output once the timeout elapses."""
    f = Focus(dut)
    await f.start()
    problems = []
    for ms in (1, 2, 5, FLIGHT_TIMEOUT_MS):
        armed = await f.arm(ms)
        await Timer(10, unit="us")
        active = await f.status()
        await f.until(armed + ms * 1000 + 5)
        falls = [t for t in f.active.falls() if t > armed]
        after = await f.status()
        dut._log.info("%d ms lease: status %d after arming, %d after; inactive %s",
                      ms, active, after, "%.4f ms after arming" % ((falls[0] - armed) / 1000)
                      if falls else "never")
        if not active:
            problems.append("%d ms: the status register did not read active after "
                            "arming" % ms)
        if after or not falls:
            problems.append("%d ms: still active %.3f ms after arming" % (ms, ms + 0.005))
        elif not ms * 1000 - 0.1 <= falls[0] - armed <= ms * 1000 + 0.1:
            problems.append("%d ms: inactive %.4f ms after arming"
                            % (ms, (falls[0] - armed) / 1000))

    # Characterisation, not the requirement: the programmed count is 27 bits.
    reg = dut.watchdog_top_inst.watchdog_apb_reg_inst
    for ms in (2684, 2685, 3000):
        await f.wd.write(WD_TIMEOUT_MS, ms)
        await ClockCycles(f.clk, 4)
        cycles = int(reg.wd_timeout_val.value)
        dut._log.info("TIMEOUT_MS %d programs %d cycles, %.1f ms", ms, cycles,
                      cycles / 50_000)
    assert not problems, "\n  ".join(["PF-FOCUS-13:"] + problems)


# -----------------------------------------------------------------------------

def test_pf_focus():
    top = "focus_mech"
    stepper = "focus_mech_ip/hw/ip/stepper_ip"
    lvdt = "focus_mech_ip/hw/ip/lvdt_ip"
    watchdog = "focus_mech_ip/hw/ip/watchdog_ip"
    sources = (sim.block(stepper, "STEP_DIR.sv")
               + sim.block(watchdog, "watchdog.sv", "watchdog_apb_reg.sv",
                           "watchdog_top.sv")
               + sim.block(lvdt, "ADC128S102_DRIVER.sv", "DECIMATOR.sv", "DELTA_SIGMA.v",
                           "IIR_BIQUAD.sv", "IQ_MIXER.sv", "MIXER_READY_VALID_HANDLER.v",
                           "RST_HANDLER.v", "SINE_SCALER.v")
               + sim.vendor("FOCUS_MECH_CoreGPIO_C0", "FOCUS_MECH_CoreGPIO_C2",
                            "FOCUS_MECH_CoreGPIO_C3", "FOCUS_MECH_CoreGPIO_C4",
                            "corepwm_C0", "SIN_COS_GEN", "LVDT_Gain", "STEPPER_DRIVER",
                            "LOCK_IN_CHAIN", "LVDT_READOUT", top)
               + [sim.polarfire_source()])
    sim.run(hdl_toplevel=top, sources=sources, test_module="test_pf_focus",
            internal=[("watchdog_apb_reg", "wd_timeout_val")])
