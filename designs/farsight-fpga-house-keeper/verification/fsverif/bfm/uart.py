"""UART bus functional model: drives and samples an async serial line."""

from __future__ import annotations

from cocotb.triggers import ClockCycles, RisingEdge


class UartMonitor:
    """Recovers bytes from a UART TX line by oversampling at the bit centre.

    The housekeeper's CoreUART is configured for 8 data bits, no parity, 1 stop
    bit. ``bit_clocks`` is the bit period expressed in ``clk`` cycles, which for
    CoreUART is ``(BAUD_VAL + 1) * 16``.
    """

    def __init__(self, clk, line, bit_clocks: int, bits: int = 8):
        self.clk = clk
        self.line = line
        self.bit_clocks = bit_clocks
        self.bits = bits

    async def recv(self, timeout_bits: int = 40) -> int:
        """Wait for a start bit and return the next received byte."""
        # Wait for the falling edge that starts a frame.
        for _ in range(self.bit_clocks * timeout_bits):
            await RisingEdge(self.clk)
            if int(self.line.value) == 0:
                break
        else:
            raise TimeoutError("no UART start bit observed")

        # Move to the centre of the start bit, then step one bit at a time.
        await ClockCycles(self.clk, self.bit_clocks // 2)
        if int(self.line.value) != 0:
            raise ValueError("false start bit")

        value = 0
        for i in range(self.bits):
            await ClockCycles(self.clk, self.bit_clocks)
            value |= int(self.line.value) << i

        await ClockCycles(self.clk, self.bit_clocks)
        if int(self.line.value) != 1:
            raise ValueError(f"framing error: stop bit low after byte 0x{value:02X}")
        return value

    async def recv_many(self, count: int, timeout_bits: int = 40) -> list[int]:
        """Receive ``count`` consecutive bytes."""
        return [await self.recv(timeout_bits=timeout_bits) for _ in range(count)]


async def uart_send(clk, line, value: int, bit_clocks: int, bits: int = 8) -> None:
    """Transmit one byte onto ``line`` (8N1) synchronised to ``clk``."""
    line.value = 0  # start bit
    await ClockCycles(clk, bit_clocks)
    for i in range(bits):
        line.value = (value >> i) & 1
        await ClockCycles(clk, bit_clocks)
    line.value = 1  # stop bit
    await ClockCycles(clk, bit_clocks)


# ---------------------------------------------------------------------------
# Edge-driven versions, for runs at the flight timing parameters.
#
# The two above wake cocotb on every clock edge -- 432 of them per bit at
# 115,200 baud -- which is the cost that made the first runs of this suite
# sixteen minutes long. These wake on the line's own transitions and on timed
# waits, so a 14-byte beacon costs a few hundred wake-ups rather than sixty
# thousand. They also do not assume the clock is running, which matters to a
# test that stops it.

import cocotb as _cocotb
from cocotb.triggers import FallingEdge as _FallingEdge
from cocotb.triggers import Timer as _Timer
from cocotb.triggers import ValueChange as _ValueChange
from cocotb.utils import get_sim_time as _now

#: The nominal 115,200 baud bit, in picoseconds so that a byte's worth of
#: rounding does not accumulate into a whole nanosecond.
BIT_PS_115200 = round(1e12 / 115_200)


async def drive_bytes(line, data, bit_ps: int = BIT_PS_115200) -> None:
    """Send `data` on `line`, 8N1, back to back, idle high afterwards."""
    start = _now("ps")
    n = 0
    for value in data:
        for level in [0] + [(value >> i) & 1 for i in range(8)] + [1]:
            line.value = level
            n += 1
            await _Timer(start + n * bit_ps - _now("ps"), unit="ps", round_mode="round")
    line.value = 1


class Receiver:
    """Every character on a line, decoded 8N1, with its timing.

    Samples at the centre of each bit of the nominal period, from the start
    bit's falling edge, and records every transition inside the character so
    that the bit period actually used can be measured rather than assumed.
    """

    def __init__(self, line, bit_ps: int = BIT_PS_115200):
        self.line, self.bit_ps = line, bit_ps
        self.chars = []          # (start_ns, value, stop_ok, bit_ps_measured)
        self._edges = []
        self._tasks = [_cocotb.start_soon(self._transitions()),
                       _cocotb.start_soon(self._run())]

    async def _transitions(self):
        while True:
            await _ValueChange(self.line)
            self._edges.append((_now("ps"), int(self.line.value)))

    async def _run(self):
        while True:
            await _FallingEdge(self.line)
            start = _now("ps")
            await _Timer(self.bit_ps // 2, unit="ps", round_mode="round")
            if int(self.line.value):
                continue                          # glitch, not a start bit
            value = 0
            for i in range(8):
                await _Timer(self.bit_ps, unit="ps", round_mode="round")
                value |= int(self.line.value) << i
            await _Timer(self.bit_ps, unit="ps", round_mode="round")
            stop_ok = bool(int(self.line.value))
            inside = [t for t, _ in self._edges if start < t <= _now("ps")]
            measured = None
            if inside:
                last = inside[-1]
                bits = round((last - start) / self.bit_ps)
                if bits:
                    measured = (last - start) / bits
            self.chars.append((start / 1000.0, value, stop_ok, measured))

    def values(self) -> list:
        return [v for _, v, _, _ in self.chars]

    def stop(self) -> None:
        for task in self._tasks:
            task.cancel()
