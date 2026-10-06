# ProASIC3 Housekeeper -- Requirements

Low-level requirements for the FARSIGHT ProASIC3 (PA3) housekeeper FPGA, derived
from the as-built RTL in [`src/`](../../src) and cross-checked against the
avionics schematic netlist.

| Document | Contents |
| --- | --- |
| [`pa3-housekeeper-requirements.md`](pa3-housekeeper-requirements.md) | The requirement set: `HK-*` requirements, each traced to a parent system requirement and to a design artefact. |
| [`pa3-housekeeper-findings.md`](pa3-housekeeper-findings.md) | Every point where the Flow system requirements, the design documentation, and the RTL disagree. Read this first. |

## Source of truth

The RTL is the source of truth. Where [`docs/design/pa3-housekeeper.md`](../design/pa3-housekeeper.md)
or the Flow requirement export disagrees with the RTL, the RTL was followed and
the disagreement is recorded in the findings document rather than silently
resolved.

## Requirement identifiers

`HK-<AREA>-<NN>`, where `<AREA>` is:

| Area | Scope |
| --- | --- |
| `IMPL` | Device, build configuration, mitigation |
| `CLK` | Clock and reset |
| `IO` | Pin mapping, input conditioning, synchronisation |
| `SRC` | Per-power-source state machine |
| `REG` | Per-power-region state machine |
| `SEQ` | Inter-region boot sequencing |
| `SW` | Software-controlled region enable/disable |
| `LAT` | Latchup detection and response |
| `PDN` | Power-down sequencing |
| `TLM` | Status and failure reporting to the PolarFire |
| `UART` | RS-422 pass-through and failure broadcast |
| `PROT` | Discrete protection outputs |

Identifiers are permanent. A withdrawn requirement keeps its identifier and is
marked `WITHDRAWN` rather than being reused.

## Trace fields

Every requirement carries:

- **Parent** -- the Flow system requirement it decomposes, or `DERIVED` when the
  requirement comes from the design and has no parent. `DERIVED` requirements
  are candidates to be promoted into Flow.
- **Design** -- the `file:line` the requirement was read from. This is the
  evidence the requirement is real, and the thing to re-check when the RTL moves.
- **Verify** -- the intended verification method:
  `SIM` (simulation), `INSP` (inspection/static analysis), `ANA` (analysis),
  `HW` (hardware test).
- **Status** -- `OK` where design and parent agree, `GAP` where the design does
  not meet the parent, `AMBIG` where the parent is unclear, `DEFECT` where the
  design is internally inconsistent. Anything other than `OK` is written up in
  the findings document.
