# Watchdog Timer IP

APB-accessible watchdog timer that counts down from a software-programmed timeout value. When the counter reaches zero without being refreshed, the `wd_active` output deasserts to signal expiry. The timer stays in the expired state until explicitly cleared by software.

## Architecture

The IP consists of three modules:

| Module | Description |
|---|---|
| `watchdog_top` | Top-level wrapper connecting APB registers to the watchdog core |
| `watchdog_apb_reg` | APB slave register interface; converts millisecond timeout to clock cycles |
| `watchdog` | Watchdog core with a 2-state Moore FSM (`RUNNING` / `EXPIRED`) |

### State Machine

```
          wd_clear=1            counter reaches 0
EXPIRED ─────────────► RUNNING ─────────────────► EXPIRED
   ▲                      │
   │                      │ wd_clear=1 or wd_refresh
   │                      ▼ (reload counter, stay RUNNING)
   │                   RUNNING
   └───────────────────────┘
         counter=0
```

- **EXPIRED** (reset default) -- `wd_active = 0`. Asserting `wd_clear` loads the timeout and transitions to RUNNING.
- **RUNNING** -- `wd_active = 1`. Counter decrements each clock cycle. Writing a new timeout value refreshes the counter. Reaches EXPIRED when the counter hits zero.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `APB_DATA_WIDTH` | 32 | APB data bus width |
| `APB_ADDR_WIDTH` | 32 | APB address bus width |
| `CLOCK_FREQ_MHZ` | 50 | Clock frequency in MHz (used for ms-to-cycles conversion) |
| `TIMER_COUNT_WIDTH` | 27 | Bit width of the internal counter (27 bits @ 50 MHz ~ 2.68 s max) |

## Register Map

Registers are word-aligned. The register index is decoded from `paddr[6:2]`.

| Address | Name | R/W | Description |
|---|---|---|---|
| `0x00` | `WD_CLEAR` | R/W | Bit 0: write `1` to clear expired state and transition to RUNNING; write `0` to release (start countdown) |
| `0x04` | `WD_TIMEOUT_MS` | R/W | Timeout value in milliseconds. Writing also triggers a refresh (counter reload) |
| `0x08` | `WD_ACTIVE_STAT` | R | Bit 0: `1` = watchdog is running, `0` = watchdog has expired |

## Typical Software Usage

1. **Arm the watchdog:**
   - Write `1` to `WD_CLEAR` (exit expired state)
   - Write desired timeout (ms) to `WD_TIMEOUT_MS`
   - Write `0` to `WD_CLEAR` (start countdown)

2. **Refresh (kick) the watchdog** before it expires:
   - Write the timeout value to `WD_TIMEOUT_MS` (reloads counter)

3. **Check status:**
   - Read `WD_ACTIVE_STAT`; bit 0 = `1` means the watchdog is still running

4. **After expiry:**
   - `wd_active` goes low and stays low until software repeats the arm sequence

## Port List (watchdog_top)

| Port | Direction | Width | Description |
|---|---|---|---|
| `pclk` | input | 1 | APB / system clock |
| `presetn` | input | 1 | Active-low asynchronous reset |
| `penable` | input | 1 | APB enable |
| `psel` | input | 1 | APB peripheral select |
| `paddr` | input | APB_ADDR_WIDTH | APB address |
| `pwrite` | input | 1 | APB write strobe |
| `pwdata` | input | APB_DATA_WIDTH | APB write data |
| `prdata` | output | APB_DATA_WIDTH | APB read data |
| `pready` | output | 1 | APB ready |
| `pslverr` | output | 1 | APB slave error |
| `wd_active` | output | 1 | `1` = running, `0` = expired |

## Simulation

A ModelSim testbench is provided in `sim/tb/watchdog_tb.sv` with 7 test cases covering reset state, arming, status readback, expiry, refresh mid-count, and re-arm after expiry.

```
cd sim
vsim -do run.do
```

## File Structure

```
watchdog_ip/
├── src/
│   ├── watchdog_top.sv         # Top-level module
│   ├── watchdog_apb_reg.sv     # APB register interface
│   └── watchdog.sv             # Watchdog timer core
├── sim/
│   ├── tb/watchdog_tb.sv       # Testbench
│   ├── run.do                  # ModelSim run script
│   └── wave.do                 # Waveform configuration
├── components/                 # Quartus component .tcl files
│   ├── watchdog_top.tcl
│   ├── watchdog_apb_reg.tcl
│   └── watchdog.tcl
└── watchdog_ip.tcl             # IP package script
```
