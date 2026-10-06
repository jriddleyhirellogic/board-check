"""HK-SRC-07 for the first four FPGA sources.

Item: VC-HK-0112. Clause: VVP-HK-004.

  HK-SRC-07  A power source that has been declared successfully booted shall
             be declared latched up if its filtered nFAULT input goes low or
             its filtered PGOOD input goes low.

One of six modules that between them cover all 33 sources, split so that
they run side by side: a hardware-region latchup is global, so every source here needs a boot of its own. The FPGA region's eight are split
in two to keep either half from being the slowest module. The logic is shared, in `fsverif.latchup`,
and so is the reasoning.
"""

from __future__ import annotations

import cocotb

from fsverif import latchup, sim
from fsverif.pins import HARDWARE_REGIONS

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

SOURCES = dict(HARDWARE_REGIONS)["fpga"][:4]


@cocotb.test()
async def test_HK_SRC_07_latchup_after_boot(dut):
    """VC-HK-0112: each source latches on each route it has."""
    problems = await latchup.hardware(dut, SOURCES)
    assert not problems, (
        "these booted sources were not declared latched up -- their enable "
        "did not fall -- on a route HK-SRC-07 requires:\n  "
        + "\n  ".join(problems))


def test_hk_src_07_fpga_a():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_src_07_fpga_a",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
