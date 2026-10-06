"""LVDT readout: how much of the 2f mixing product reaches the I/Q outputs.

Item: VC-PF-0138 (DRV-PF-12).

**The DUT is `LVDT_READOUT` as the build generates it**: the ADC128S102 driver,
the COREDDS that makes the excitation's sine and cosine, and the two
`LOCK_IN_CHAIN`s, one per coil, each a band-pass, the I/Q mixer, the decimator
and the band-stop and low-pass sections. The test plays the ADC on its SPI
pins, so every sample enters at the instant the driver takes it, and is mixed
with the DDS's own sine and cosine at that instant.

**The ADC is modelled from its datasheet** (TI ADC128S102, "Serial Interface"):
each frame begins with CS falling; DOUT changes on SCLK's falling edges and
carries four leading zeros then DB11..DB0, MSB first; DIN is sampled on the
rising edges, ADD2..ADD0 on the third to fifth, and selects the channel the
*next* frame converts; the input is held at the fourth falling edge. The model
checks the driver against it as it goes: a frame that is not 16 clocks fails
the test.

**What is applied.** Each coil's channel (3 primary, 7 secondary, as
`LVDT_READOUT.tcl` wires them; the board ties IN0-IN3 and IN4-IN7 to the two
coils) carries a sine at exactly the excitation frequency, about mid-scale,
with an arbitrary phase to the excitation. Mixing it with the excitation gives
each output a DC term and a 2f term of equal size; the filters after the mixer
are what separate them.

**What is measured.** After the filters settle, a sinusoid at exactly 2f is
fitted to each output's samples by least squares. Its amplitude, against the
coil's DC response (the I and Q DC terms together, which do not depend on the
phase chosen), is the attenuation DRV-PF-12 bounds.

**It can measure a pass.** With `DECIMATOR.sv` corrected as `PF-F-38`
recommends (one output per five inputs, the current input), the same test
measured 112 to 128 dB on the four outputs on 2026-10-05, against 62.6 to 62.7 dB
as built. The floor is the outputs' quantisation, well below the bound.
"""

from __future__ import annotations

import math

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer, ValueChange
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.clkrst import start_clock

CLK_NS = 20
F_EXC = 50e6 / 2 ** 14              # SIN_COS_GEN.tcl: 14-bit accumulator, increment 1
BOUND_DB = 90.0                     # DRV-PF-12 (TBR)
SETTLE_S = 8e-3
MEASURE_S = 20e-3
#: Each coil's ADC input: amplitude and phase to the excitation, about mid-scale.
COILS = {3: (1500.0, 0.6), 7: (1100.0, 2.1)}
OUTPUTS = {"primary I": ("LOCK_IN_CHAIN_PRIMARY_COIL_o_data_i", 3),
           "primary Q": ("LOCK_IN_CHAIN_PRIMARY_COIL_o_data_q", 3),
           "secondary I": ("LOCK_IN_CHAIN_SECONDARY_COIL_o_data_i", 7),
           "secondary Q": ("LOCK_IN_CHAIN_SECONDARY_COIL_o_data_q", 7)}


def _code(channel: int, t_s: float) -> int:
    """The 12-bit result for a channel held at time t."""
    coil = 3 if channel < 4 else 7
    amp, phase = COILS[coil]
    v = 2048 + amp * math.cos(2 * math.pi * F_EXC * t_s + phase)
    return max(0, min(4095, int(round(v))))


async def _adc(dut, frames: list) -> None:
    """The ADC128S102 on the driver's SPI pins, to the datasheet."""
    sclk, cs, din, dout = dut.o_spi_clk, dut.o_spi_cs, dut.o_spi_mosi, dut.lvdt_adc_spi_miso
    channel = 0                      # the first frame after power-up converts IN0
    dout.value = 0
    while True:
        await FallingEdge(cs)
        result, nxt = 0, 0
        for n in range(1, 17):
            if n > 1:
                await FallingEdge(sclk)
                if int(cs.value):
                    raise AssertionError("CS rose after %d SCLK cycles, not 16" % (n - 1))
            if n == 4:
                result = _code(channel, get_sim_time("ns") * 1e-9)
            dout.value = 0 if n <= 4 else (result >> (16 - n)) & 1
            if n in (3, 4, 5):
                await RisingEdge(sclk)
                nxt = (nxt << 1) | int(din.value)
        frames.append((channel, result))
        channel = nxt


def _fit(samples: list, f: float) -> tuple:
    """(dc, amplitude) of y = c + a cos(2 pi f t) + b sin(2 pi f t), least squares."""
    rows = [(1.0, math.cos(2 * math.pi * f * t), math.sin(2 * math.pi * f * t), y) for t, y in samples]
    n = 3
    ata = [[sum(r[i] * r[j] for r in rows) for j in range(n)] for i in range(n)]
    aty = [sum(r[i] * r[3] for r in rows) for i in range(n)]
    for i in range(n):                                   # Gauss-Jordan on the 3x3 system
        p = max(range(i, n), key=lambda k: abs(ata[k][i]))
        ata[i], ata[p], aty[i], aty[p] = ata[p], ata[i], aty[p], aty[i]
        for k in range(n):
            if k != i:
                m = ata[k][i] / ata[i][i]
                ata[k] = [x - m * y for x, y in zip(ata[k], ata[i])]
                aty[k] -= m * aty[i]
    c, a, b = (aty[i] / ata[i][i] for i in range(n))
    return c, math.hypot(a, b)


def _signed(handle) -> int:
    v = int(handle.value)
    bits = len(handle)
    return v - (1 << bits) if v >> (bits - 1) else v


async def _watch(dut, name: str, out: list) -> None:
    h = getattr(dut, name)
    while True:
        await ValueChange(h)
        out.append((get_sim_time("ns") * 1e-9, _signed(h)))


@cocotb.test()
async def test_DRV_PF_12_2f_attenuated_90db(dut):
    """VC-PF-0138: the 2f product at least 90 dB below DC in each I/Q output, as built."""
    start_clock(dut.i_clk, CLK_NS)
    for port in ("PRI_I", "PRI_Q", "SEC_I", "SEC_Q"):
        for sig in ("PSEL", "PENABLE", "PWRITE", "PADDR", "PWDATA"):
            getattr(dut, "APB_%s_%s" % (port, sig)).value = 0
    dut.i_res.value = 0
    frames = []
    cocotb.start_soon(_adc(dut, frames))
    await ClockCycles(dut.i_clk, 20)
    dut.i_res.value = 1

    seen = {k: [] for k in OUTPUTS}
    for label, (name, _) in OUTPUTS.items():
        cocotb.start_soon(_watch(dut, name, seen[label]))
    await Timer(int((SETTLE_S + MEASURE_S) * 1e9), unit="ns")

    problems = []
    converted = {}
    for ch, _ in frames:
        converted[ch] = converted.get(ch, 0) + 1
    run_s = SETTLE_S + MEASURE_S
    dut._log.info("ADC frames %d in %.0f ms: %s per channel (%.1f kS/s per coil)",
                  len(frames), run_s * 1e3, dict(sorted(converted.items())),
                  converted.get(3, 0) / run_s / 1e3)
    if converted.get(3, 0) == 0 or converted.get(7, 0) == 0:
        problems.append("the driver never converted channels 3 and 7: %s" % converted)

    dc = {}
    fits = {}
    for label, samples in seen.items():
        window = [(t, y) for t, y in samples if t >= SETTLE_S]
        if len(window) < 50:
            problems.append("%s: %d output updates after settling" % (label, len(window)))
            continue
        rate = len(window) / MEASURE_S
        c, ripple = _fit(window, 2 * F_EXC)
        fits[label] = (c, ripple, rate)
        coil = OUTPUTS[label][1]
        dc[coil] = dc.get(coil, 0.0) + c * c
    for label, (c, ripple, rate) in fits.items():
        coil = OUTPUTS[label][1]
        m = math.sqrt(dc[coil])
        att = 20 * math.log10(m / ripple) if ripple else float("inf")
        # Value changes, not updates: equal consecutive outputs are not seen. While the
        # ripple is many LSBs every update changes the value, so this is the output
        # rate -- the decimation as built (PF-F-38).
        dut._log.info("%-11s %5.0f output changes/s; DC %+.4g, coil DC response %.4g, 2f "
                      "ripple %.4g: %.1f dB below DC", label, rate, c, m, ripple, att)
        if m == 0:
            problems.append("%s: no DC response, so nothing to measure against" % label)
        elif att < BOUND_DB:
            problems.append("%s: the 2f product is %.1f dB below DC, not %.0f"
                            % (label, att, BOUND_DB))
    assert not problems, "\n  ".join(["DRV-PF-12:"] + problems)


# -----------------------------------------------------------------------------

def test_pf_lvdt():
    lvdt = "focus_mech_ip/hw/ip/lvdt_ip"
    top = "LVDT_READOUT"
    sources = (sim.block(lvdt, "ADC128S102_DRIVER.sv", "DECIMATOR.sv", "DELTA_SIGMA.v",
                         "IIR_BIQUAD.sv", "IQ_MIXER.sv", "MIXER_READY_VALID_HANDLER.v",
                         "RST_HANDLER.v", "SINE_SCALER.v")
               + sim.vendor("FOCUS_MECH_CoreGPIO_C0", "SIN_COS_GEN", "LOCK_IN_CHAIN", top)
               + [sim.polarfire_source()])
    sim.run(hdl_toplevel=top, sources=sources, test_module="test_pf_lvdt")
