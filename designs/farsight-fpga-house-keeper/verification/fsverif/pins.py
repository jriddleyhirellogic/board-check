"""The housekeeper device as the board sees it.

Every name here is a pin. A test that needs something not in this file is
either testing a requirement written about the boundary and reaching inside
anyway, or testing a claim the requirement does not make.

Reaching into the design is permitted where an item says why. That is a
deliberate obstacle rather than a prohibition: `HK-IMPL-10` is about upsets in
sequential logic and cannot be observed at the pins, so its item will state
what it reaches for. `HK-SRC-02` is about power enable outputs, and anything
it reaches for is a mistake.
"""

from __future__ import annotations

#: The asynchronous reset pin. Named here because the device also has an
#: internal `rstn` -- the synchronised version -- and cocotb's
#: `--public-flat-rw` will let a test write it without complaint. A test that
#: drives `rstn` bypasses the reset synchroniser and is verifying a device the
#: board cannot produce. The first run of test_hk_src_02 did exactly that and
#: failed, which is how this constant came to exist.
RESET_N = "arstn"

#: Every power enable the device drives. Named rather than pattern-matched:
#: a glob over `*_en` silently loses `step_down_en_4v0` the day somebody
#: renames it, and a test asserting "all enables are low" would then pass
#: while not looking at the one that mattered.
POWER_ENABLES = (
    "step_down_en_2v2", "step_down_en_3v0", "step_down_en_4v0",
    "ddr8_en_2v5", "ddr8_en_1v2", "ddr8_en_0v6",
    "ddr16_en_2v5", "ddr16_en_1v2", "ddr16_en_0v6",
    "fpga_en_1v0", "fpga_en_1v0a", "fpga_en_1v25a", "fpga_en_1v8",
    "fpga_en_1v8_imx", "fpga_en_2v5a", "fpga_en_3v3_b4", "fpga_en_3v3_b5",
    "lvds_en",
    "imx_en_1v1", "imx_en_1v8", "imx_en_2v9", "imx_en_3v3",
    "lvdt_en",
    "eth1_en_1v0", "eth1_en_1v0a", "eth1_en_2v5a", "eth1_en_3v3",
    "eth2_en_1v0", "eth2_en_1v0a", "eth2_en_2v5a", "eth2_en_3v3",
    "stepper_pri_en", "stepper_sec_en",
)

#: Power enables for the hardware-controlled regions, in boot order
#: (`HK-SEQ-02`: Step Down, DDR8, DDR16, FPGA, LVDS).
HARDWARE_REGIONS = (
    ("step_down", ("step_down_en_2v2", "step_down_en_3v0", "step_down_en_4v0")),
    ("ddr8", ("ddr8_en_2v5", "ddr8_en_1v2", "ddr8_en_0v6")),
    ("ddr16", ("ddr16_en_2v5", "ddr16_en_1v2", "ddr16_en_0v6")),
    ("fpga", ("fpga_en_1v0", "fpga_en_1v0a", "fpga_en_1v25a", "fpga_en_1v8",
              "fpga_en_1v8_imx", "fpga_en_2v5a", "fpga_en_3v3_b4",
              "fpga_en_3v3_b5")),
    ("lvds", ("lvds_en",)),
)

#: Power enables for the software-controlled regions, by control input.
SOFTWARE_REGIONS = (
    ("imx", "imx_ctrl",
     ("imx_en_1v1", "imx_en_1v8", "imx_en_2v9", "imx_en_3v3")),
    ("lvdt", "lvdt_ctrl", ("lvdt_en",)),
    ("eth1", "eth1_ctrl",
     ("eth1_en_1v0", "eth1_en_1v0a", "eth1_en_2v5a", "eth1_en_3v3")),
    ("eth2", "eth2_ctrl",
     ("eth2_en_1v0", "eth2_en_1v0a", "eth2_en_2v5a", "eth2_en_3v3")),
    ("stepper_pri", "stepper_pri_ctrl", ("stepper_pri_en",)),
    ("stepper_sec", "stepper_sec_ctrl", ("stepper_sec_en",)),
)

#: Inputs the board drives into the device. A test must set every one of
#: these, because an undriven input in simulation is X and an X that happens
#: to resolve favourably is a pass that means nothing.
PGOOD_INPUTS = (
    "step_down_pgood_2v2", "step_down_pgood_3v0", "step_down_pgood_4v0",
    "ddr8_pgood_2v5", "ddr8_pgood_1v2", "ddr8_pgood_0v6",
    "ddr16_pgood_2v5", "ddr16_pgood_1v2", "ddr16_pgood_0v6",
    "fpga_pgood_1v0", "fpga_pgood_1v0a", "fpga_pgood_1v25a",
    "fpga_pgood_1v8", "fpga_pgood_1v8_imx", "fpga_pgood_2v5a",
    "fpga_pgood_3v3_b4", "fpga_pgood_3v3_b5",
    "lvds_pgood",
    "imx_pgood_1v1", "imx_pgood_1v8", "imx_pgood_2v9", "imx_pgood_3v3",
    "lvdt_pgood",
    "eth1_pgood_1v0", "eth1_pgood_1v0a", "eth1_pgood_2v5a", "eth1_pgood_3v3",
    "eth2_pgood_1v0", "eth2_pgood_1v0a", "eth2_pgood_2v5a", "eth2_pgood_3v3",
    "stepper_pri_pgood", "stepper_sec_pgood",
    "eps_efuse_pgood",
)

#: nFAULT inputs, active low: a fault is a LOW.
NFAULT_INPUTS = (
    "step_down_nfault_2v2", "step_down_nfault_3v0", "step_down_nfault_4v0",
    "ddr8_nfault_2v5", "ddr8_nfault_1v2",
    "ddr16_nfault_2v5", "ddr16_nfault_1v2",
    "fpga_nfault_1v0",
    "imx_nfault_1v1",
    "stepper_pri_nfault", "stepper_sec_nfault",
)

#: Control inputs by which the PolarFire requests a software-controlled region.
CONTROL_INPUTS = tuple(ctrl for _, ctrl, _ in SOFTWARE_REGIONS)

#: Status outputs to the PolarFire, one per region (`HK-TLM-01`).
STATUS_OUTPUTS = (
    "step_down_status_to_pf", "ddr8_status_to_pf", "ddr16_status_to_pf",
    "lvds_status_to_pf", "imx_status_to_pf", "lvdt_status_to_pf",
    "eth1_status_to_pf", "eth2_status_to_pf",
    "stepper_pri_status_to_pf", "stepper_sec_status_to_pf",
    "pa3_status_to_pf", "pf_status_to_pf",
)


#: Every output the housekeeper drives towards the PolarFire, with the width
#: of each. `HK-OFFNOM-02` is about all of them, so the list has to be all of
#: them: a test that checked only the ten region status outputs would pass,
#: because those are the ones that are already correct.
#:
#: Checked against the schematic (CM-03545 export of 2026-09-15), tracing every
#: net from U2 to U1 through its series resistor: the twelve status outputs,
#: the sixteen failure metadata bits on `PA3_TO_PF_MISC0`-`15`, `fw_version[1]`
#: on `PF_TO_PA3_MISC0` and the RS-422 line to the PolarFire. `fw_version` is
#: listed at its full RTL width; bits 0 and 2 are unplaced, and checking them
#: costs nothing.
#:
#: Not here, because they do not reach the PolarFire: `heartbeat` drives LED
#: D12 through R921; `imx_nshort_1v1` and `imx_nshort_1v8` serve the IMX
#: sensor rails; `debug` goes to a header.
PF_OUTPUTS = (
    ("step_down_status_to_pf", 1), ("ddr8_status_to_pf", 1),
    ("ddr16_status_to_pf", 1), ("lvds_status_to_pf", 1),
    ("imx_status_to_pf", 1), ("lvdt_status_to_pf", 1),
    ("eth1_status_to_pf", 1), ("eth2_status_to_pf", 1),
    ("stepper_pri_status_to_pf", 1), ("stepper_sec_status_to_pf", 1),
    ("pa3_status_to_pf", 1), ("pf_status_to_pf", 1),
    ("fw_version", 3), ("rs422_ttl_bus_to_farsight_pf", 1),
    ("ddr8_failure_metadata", 2), ("ddr16_failure_metadata", 2),
    ("eth1_failure_metadata", 3), ("eth2_failure_metadata", 3),
    ("imx_failure_metadata", 3), ("lvdt_failure_metadata", 1),
    ("stepper_pri_failure_metadata", 1), ("stepper_sec_failure_metadata", 1),
)

#: The inactive state of every output to the PolarFire is LOW.
#:
#: Not assumed -- stated by the parent requirement FAR-PM_FPGA_L4REQ-3, "the
#: housekeeper FPGA shall only drive signals high to the PolarFire FPGA while
#: the PolarFire is booted". `VC-HK-0097` asks for the inactive state to be
#: taken from the interface definition rather than guessed, and this is it.
PF_INACTIVE = 0


#: The debug bus, on real pins (`io_constraints.pdc`, seven assignments).
#:
#: `debug[2:0]` encodes the first latchup or boot failure the housekeeper saw
#: (`health_monitor.sv:707-713`): 1-4 are step-down, DDR8, DDR16 and FPGA
#: latchups, 5-7 are step-down, FPGA and DDR8 boot failures. It is the only
#: place a *region* boot failure reaches the boundary at all -- the status
#: outputs report success, not the reason for its absence.
DEBUG = "debug"

#: The RS-422/TTL lines. Two pairs: one to the PolarFire, one to the bus.
#: Named here because they are pins and a test may legitimately observe them
#: -- `HK-UART-*` is written about this interface -- not because anything
#: currently does.
UART_LINES = (
    "rs422_ttl_bus_to_farsight_pa3", "rs422_ttl_farsight_to_bus_pa3",
    "rs422_ttl_bus_to_farsight_pf", "rs422_ttl_farsight_to_bus_pf",
)

#: Short-circuit indications for the IMX sensor rails, active low and pulled
#: up. Outputs, but not to the PolarFire: they drive the sensor board.
NSHORT_OUTPUTS = ("imx_nshort_1v1", "imx_nshort_1v8")

#: The housekeeper's liveness output. It drives LED D12 through R921 and does
#: not reach the PolarFire, so it is not in `PF_OUTPUTS`.
HEARTBEAT = "heartbeat"


def boundary(dut, name: str):
    """A handle to `name`, refusing anything that is not a pin of the device.

    cocotb builds with `--public-flat-rw`, so every internal signal is
    writable and `dut.rstn` resolves as readily as `dut.arstn`. The first run
    of `test_hk_src_02` drove `rstn` -- the synchronised reset inside the
    design -- and so tested a device the board cannot produce. It failed for an
    unrelated-looking reason and cost a sixteen-minute run to diagnose.

    Tests reach for pins through this, so that mistake fails at the first
    access with a message naming what happened.
    """
    if name not in ALL_PINS:
        raise AssertionError(
            "%r is not a pin of the housekeeper. Verification is at the FPGA "
            "boundary: the requirements are written about what the board can "
            "drive and observe. If an item states a reason to reach inside "
            "the design, use getattr(dut, %r) directly and say so in the "
            "test docstring." % (name, name))
    return getattr(dut, name)


#: Control the simulation wrapper exposes that is *not* a device pin: driving
#: it low stops the clock. `HK-OFFNOM-04` requires every power enable to go
#: inactive on loss of the input clock, which cannot be exercised otherwise.
#:
#: Deliberately outside `ALL_PINS`. It is environment control, not something
#: the board can drive, and a test reaching for it should say so plainly
#: rather than have it look like a pin.
CLOCK_ENABLE = "clk_enable"

#: Every pin this module knows about, for `boundary` to check against.
ALL_PINS = frozenset(
    (RESET_N, "clk", DEBUG, HEARTBEAT)
    + POWER_ENABLES + PGOOD_INPUTS + NFAULT_INPUTS + CONTROL_INPUTS
    + STATUS_OUTPUTS + tuple(name for name, _ in PF_OUTPUTS)
    + UART_LINES + NSHORT_OUTPUTS
)


def _device_ports(direction: str, top: "Path | None" = None) -> tuple:
    import re
    from pathlib import Path

    source = Path(top) if top else (
        Path(__file__).resolve().parent.parent.parent / "src" / "top.sv")
    return tuple(re.findall(
        r"^\s*%s\s+wire\s+(?:\[[^\]]*\]\s*)?(\w+)\s*,?\s*$" % direction,
        source.read_text(encoding="utf-8"), re.M))


def device_inputs(top: "Path | None" = None) -> tuple:
    """Every input port of the device, read from its own source.

    Read rather than listed, because the point of asking is usually "has an
    input appeared that nobody has accounted for" -- and a list maintained by
    hand cannot answer that about itself.
    """
    return _device_ports("input", top)


def device_enables(top: "Path | None" = None) -> tuple:
    """Every power enable output of the device, read from its own source.

    For claims about *every* enable (`HK-LAT-03`). `POWER_ENABLES` is the
    same set today, but a test of "all of them" that carried its own list
    would stop covering an enable added later and go on passing.
    """
    import re

    return tuple(name for name in _device_ports("output", top)
                 if re.search(r"_en(_|$)", name))
