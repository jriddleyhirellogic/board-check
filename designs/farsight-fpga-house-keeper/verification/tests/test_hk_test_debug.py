"""The first fault on the debug pins: HK-TEST-02.

Item: VC-HK-0101. Clause: VVP-HK-004.

  HK-TEST-02  The housekeeper shall expose the identity of the first critical
              fault on external pins observable without JTAG.

`debug[2:0]` is on real pins (`io_constraints.pdc:182-188`) and encodes the
fault: step-down latchup 1, DDR8 2, DDR16 3, FPGA 4, step-down boot failure
5, FPGA boot failure 6, DDR8 boot failure 7, and 0 for none
(`health_monitor.sv:707-713`). It is written by a priority chain with no
final `else`, so it holds the highest-priority condition *currently active*
-- not the first.

**Only one sequence of two faults is reachable at the pins**, and it is the
one tested. A critical fault shuts everything down -- a latchup holds every
region in reset, a step-down or FPGA boot failure powers the rest down --
so nothing can fault after it. A DDR8 boot failure does not: the chain
carries on past it (`HK-SEQ-09`). So DDR8 is left to fail to boot, the code
is read, then DDR16 latches up and it is read again. "First fault" is read
as the first code the field records, which is how the field itself presents
DDR8's boot failure; read strictly as "first *critical* fault", DDR16 would
be the first and the pins would be right.

The UART snapshot does not count DDR8's boot failure at all -- its trigger is
FPGA or step-down boot failure, or a hardware latchup (`health_monitor.sv:631`)
-- so here the beacon would name DDR16 as the first failure while the pins,
before the latchup, named DDR8. Two records of "the first fault" that are
built on different definitions of fault.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge, with_timeout

from fsverif import board, boot, sim
from fsverif.clkrst import advance
from fsverif.pins import DEBUG, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

CODES = {0: "none", 1: "step-down latchup", 2: "DDR8 latchup",
         3: "DDR16 latchup", 4: "FPGA latchup", 5: "step-down boot failure",
         6: "FPGA boot failure", 7: "DDR8 boot failure"}
FIRST_DEAD = "ddr8_pgood_1v2"
SECOND_RAIL, SECOND_ENABLE = "ddr16_pgood_1v2", "ddr16_en_1v2"


def _code(dut) -> int:
    return int(boundary(dut, DEBUG).value) & 0x7


@cocotb.test()
async def test_HK_TEST_02_first_fault_identity_on_pins(dut):
    """VC-HK-0101: the pins name the first fault, and keep naming it."""
    board.drive(dut, fail=(FIRST_DEAD,))
    await boot.hardware(dut, timeout_s=4.0)
    first = _code(dut)

    board.drive(dut, fail=(FIRST_DEAD,), fault=(SECOND_RAIL,))
    await with_timeout(FallingEdge(boundary(dut, SECOND_ENABLE)), 1, "ms")
    await advance(dut.clk, seconds=0.010)
    after = _code(dut)
    dut._log.info("debug[2:0] after DDR8 failed to boot: %d (%s); after DDR16 "
                  "then latched up: %d (%s)", first, CODES[first], after,
                  CODES[after])

    assert first == 7, (
        "DDR8 failed to boot and debug[2:0] read %d (%s), not 7, so the first "
        "fault was not on the pins at all" % (first, CODES[first]))
    assert after == first, (
        "debug[2:0] named the first fault, %s, until a later one -- a DDR16 "
        "latchup -- overwrote it with %d (%s). The field holds the highest-"
        "priority condition active, not the first (health_monitor.sv:707-713)."
        % (CODES[first], after, CODES[after]))


def test_hk_test_debug():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_test_debug",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
