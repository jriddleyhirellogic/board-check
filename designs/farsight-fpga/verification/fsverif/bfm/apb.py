"""An APB3 requester, for driving a block's register interface from a test.

Drives on the falling clock edge and samples on the rising one, so every
change is settled a half-period before the DUT sees it and no transfer races
the clock. A transfer is one setup cycle and one or more access cycles,
ending on the first rising edge that shows PREADY. PSEL and PENABLE drop on
the falling edge after it, so the completer sees exactly one access cycle
with PREADY high -- a block that acts on every cycle of `psel && penable`
acts once per transfer, as it would under a real requester.

Registers are given as byte addresses. A block that decodes word addresses
(`paddr[5:2]`) is addressed as `4 * register`.
"""

from __future__ import annotations

from dataclasses import dataclass

from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge

_SIGNALS = ("psel", "penable", "pwrite", "paddr", "pwdata",
            "prdata", "pready", "pslverr")


class ApbTimeout(Exception):
    """The completer never raised PREADY."""


@dataclass
class Response:
    data: int
    slverr: bool


class Apb:
    """One APB requester, on the signals `<prefix>psel`, `<prefix>penable`...

    Signal names are matched case-insensitively, so one prefix serves both
    `apb_pps_psel` and a SmartDesign's `APB_PSEL`.
    """

    def __init__(self, dut, clk, prefix: str, timeout_cycles: int = 32):
        self.clk, self.timeout_cycles = clk, timeout_cycles
        names = {name.lower(): name for name in _names(dut)}
        self._s = {}
        for signal in _SIGNALS:
            key = (prefix + signal).lower()
            if key not in names:
                raise AttributeError("no APB signal %s%s on %s"
                                     % (prefix, signal, dut._name))
            self._s[signal] = getattr(dut, names[key])
        self.idle()

    def idle(self) -> None:
        for signal in ("psel", "penable", "pwrite", "paddr", "pwdata"):
            self._s[signal].value = 0

    async def write(self, addr: int, data: int) -> Response:
        return await self._transfer(addr, True, data)

    async def read(self, addr: int) -> Response:
        return await self._transfer(addr, False, 0)

    async def _transfer(self, addr: int, write: bool, data: int) -> Response:
        s = self._s
        await FallingEdge(self.clk)
        s["paddr"].value = addr
        s["pwrite"].value = int(write)
        s["pwdata"].value = data if write else 0
        s["psel"].value = 1
        s["penable"].value = 0
        await FallingEdge(self.clk)
        s["penable"].value = 1
        for _ in range(self.timeout_cycles):
            await RisingEdge(self.clk)
            await ReadOnly()
            if int(s["pready"].value):
                response = Response(int(s["prdata"].value),
                                    bool(int(s["pslverr"].value)))
                await FallingEdge(self.clk)
                self.idle()
                return response
        raise ApbTimeout("no PREADY within %d cycles of an access to 0x%x"
                         % (self.timeout_cycles, addr))


def _names(dut):
    # Iterating a handle discovers its children; with only the top module
    # public that is its ports and nets, which is all a requester needs.
    return [child._name for child in dut]
