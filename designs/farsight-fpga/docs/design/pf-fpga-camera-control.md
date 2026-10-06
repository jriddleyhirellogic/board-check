<!--
Generated from farsight-doc/04-section-sdd/pf-fpga-camera-control.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/pf-fpga-camera-control.tex > pf-fpga-camera-control.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

### Camera Control and Data Receving Architecture

![Farsight Avionics Camera Control Architecture](figures/farsight-pf-xcvr.png)

_Figure: Farsight Avionics Camera Control Architecture_

The camera control architecture is depicted in
the figure below. This subsystem handles high-speed
image data reception from the camera sensor using the SLVS-EC
(Scalable Low Voltage Signaling with Embedded Clock) interface.

#### High-Speed Transceiver Interface

The design utilizes two PolarFire XCVR (transceiver) instances, each supporting
4 lanes, for a total of 8 differential SLVS-EC lanes. The transceivers are
configured with the following parameters:

- CDR reference clock: 148.5 MHz
- RX data rate: 4.752 Gbps per lane
- PCS fabric interface width: 40 bits
- Rx Clock Out Freq: 118.8 MHz

The transceivers operate in PMA (Physical Medium Attachment) mode, providing
raw serialization deserialization. Each transceiver lane outputs 40-bit encoded
data to a CorePCS instance that performs 8B/10B decoding and word alignment
using K28.5 comma detection (single comma required for alignment). The CorePCS
decodes the 40-bit input (4 x 10-bit symbols) into 32-bit data
(4 x 8-bit bytes).
The decoded data then passes through a `word_alignment` module that
performs byte-order swapping to correct endianness.
The SLVS-EC RX IP aggregates data from all 8 lanes into a 384-bit output
bus (8 lanes x 12-bit pixel depth x 4 pixels per lane)
along with frame and line valid signals.

#### Clock Domains

The camera control subsystem operates across multiple clock domains:

- **APB Clock (50 MHz)**: Used for register configuration and control interfaces.
- **CDR Reference Clock (148.5 MHz)**: Provides the reference for the transceiver CDR (Clock and Data Recovery) circuits.
- **Pixel Reference Clock (118.8 MHz)**: Recovered clock from Lane 0, used as the reference for downstream pixel processing.
- **Pixel Fabric Clock (79.2 Mhz)**: Clock domain for the SLVS-EC RX IP and the camera MUX logic. See below for the clock caluclation formula.

**PLL for Pixel Clock Generation**

The pixel fabric clock is derived from the recovered lane clock using the
following formula [polarfire-fpga-slvs-ec-user-guide]:

```
f_{pixel} = \frac{f_{LANE0_RX_CLK} x NUM_LANES}{PIXEL_WIDTH}
```

For this design:

```
f_{pixel} = (118.8 MHz x 8)/(12) = 79.2 MHz
```

#### Camera MUX

The `cam_mux` module routes the received camera data to one of two
DDR4 memory spaces (8 GB or 16 GB). It operates in the pixel clock domain
and uses a state machine to ensure frame-aligned switching between destinations.
This means if the IMX is already streaming data and the MUX is enabled in the
middle of a frame transfer the MUX won't allow the data to move out until the
start of the next valid camera frame.
The MUX is controlled via APB-accessible GPIO registers that set the enable and
select signals.

#### Camera MUX APB Register

The camera MUX is controlled through a CoreGPIO instance accessible via the APB
bus. the table below describes the GPIO output bits used for MUX control.

| **Bit** | **Name** | **Default** | **Description** |
| --- | --- | --- | --- |
| 0 | MUX_ENABLE | 0 | MUX enable control (0 = disabled, 1 = enabled) |
| 1 | MUX_OUTPUT_SELECT | 0 | Memory destination select (0 = DDR4 8GB, 1 = DDR4 16GB) |

_Table: Camera MUX GPIO Control Bits_

#### Camera GPIO Interface

Camera GPIO interface consists of 3 main signals:

- **XCLRn**: IMX sensor active low reset.
- **XTRIG**: Signal to the camera sensor for frame capture control and exposure time.
- **TOUT**: Signal from IMX sensor indicating the on going exposure duration signal.

Each of these signals are specified in the next sections.

#### Camera Reset (XCLRn)

This signal resets the IMX register to the default values.
Hold XCLR at Low level for 500 ns or more after all the power supplies have
finished rising [sony-imx531-camera].

#### Camera Trigger (XTRIG)

The `cam_trig` module generates the XTRIG signal to the camera sensor
for frame capture control signaling and exposure time.
It is software-configurable via an APB register interface and allows control
over trigger timing and frame capture count.

**Camera Trigger Functional Overview**

The camera trigger IP operates as a finite state machine with the following states:

- **OFF**: Initial state, waiting for enable signal
- **IDLE**: Enabled and ready to accept configuration, waiting for start command
- **XTRIG_LOW_PERIOD**: Driving XTRIG low for the configured duration
- **XTRIG_HIGH_PERIOD**: Driving XTRIG high for the remainder of the frame period
- **DONE**: Capture sequence complete, returns to IDLE

The XTRIG signal timing is controlled by three parameters: the low pulse duration,
the total frame capture period, and the number of frames to capture.
Setting `frame_capture_amount` to 0 enables continuous (infinite)
triggering until the module is disabled.

**Camera Trigger Timing Configuration**

All timing parameters are specified in microseconds and internally converted to
clock cycles based on the `CLOCK_FREQ_MHZ` parameter (default: 50 MHz).
The frame period defines the time between consecutive trigger pulses:

```
T_{high} = T_{frame} - T_{low}
```

![Farsight Avionics Camera Trigger Waveform](figures/imx-xtrig-waveform.png)

_Figure: Farsight Avionics Camera Trigger Waveform_

**Camera Trigger Usage Example**

To capture 100 frames at 50 fps with a 10 us trigger pulse:

1. Write 10 to `XTRIG_LOW_TIME` Reg (0x00)
2. Write 20000 to `FRAME_CAPTURE_TIME` Reg (0x04) for \sim50 fps
3. Write 100 to `FRAME_CAPTURE_AMOUNT` Reg (0x08)
4. Write 1 to `START` (0x0C) Reg to begin capture

#### Camera Trigger APB Register Map

the table below shows the APB register interface for the camera trigger module.

| **Offset** | **Name** | **Width** | **Access** | **Description** |
| --- | --- | --- | --- | --- |
| 0x00 | XTRIG_LOW_TIME | 15 bits | R/W | Duration of XTRIG low pulse in microseconds (0-32767 us) |
| 0x04 | FRAME_CAPTURE_TIME | 20 bits | R/W | Total frame capture period in microseconds (0-1048575 us) |
| 0x08 | FRAME_CAPTURE_AMOUNT | 10 bits | R/W | Number of frames to capture (0 = infinite, 1-1023 = finite count) |
| 0x0C | START | 1 bit | R/W | Write 1 to start capture sequence; auto-clears on completion |

_Table: Camera Trigger APB Register Map_

#### Camera Exposure ACK Signal (TOUT)

The IMX TOUT signal is an acknowledgement signal for the period of the current
running global shutter exposure.

![IMX TOUT Timing Diagram. See [sony-imx531-camera]](figures/imx-tout-timing-diagram.png)

_Figure: IMX TOUT Timing Diagram. See [sony-imx531-camera]_

The parameters in the the figure below are described in
the following:

1. TGST: Global Shutter Start Delay
2. TGED: Global Shutter End Delay
3. TGSE: Global Shutter Pulse width
4. TGPD: Global Shutter Next trigger rise prohibited period
5. TGDLY: Global Shutter Data output delay
6. TGES: Global Shutter Next trigger fall prohibited period

#### Camera SPI

The camera SPI interface provides register access to the IMX sensor for configuration and status readback. The design uses a Microchip CoreSPI instance configured as an SPI master with an APB slave interface.

**SPI Configuration**

All the SPI output signals are kept in High-Z until the Housekeeper
`cam_pwr_status` is high.
the table below summarizes the CoreSPI configuration parameters.

| **Parameter** | **Value** |
| --- | --- |
| APB Data Width | 32 bits |
| SPI Mode | Motorola |
| Frame Size | 8 bits |
| FIFO Depth | 32 entries |
| Clock Divider | 124 |
| Motorola Mode | Mode 3 (CPOL=1, CPHA=0) |
| Bit Order | MSB first |
| SSEL Behavior | Keep active between frames |
| SSEL Polarity | Active low |

_Table: Camera SPI Configuration Parameters_

**Timing Characteristics**

In Motorola Mode 3, the SPI clock (SCK) idles high and data is sampled on the leading (falling) edge of the clock. The SPI clock frequency is derived from the APB clock divided by the clock divider value:

```
f_{SPI} = \frac{f_{APB}}{2 x CLK_DIV} = (50 MHz)/(2 x 124) \approx 201.6 kHz
```

### Camera Data Pipeline Architecture

![Farsight Avionics Data Pipeline Architecture](figures/farsight-data-pipeline-structure.png)

_Figure: Farsight Avionics Data Pipeline Architecture_

FARSIGHT Hardware consists of 2 DDR4 banks of 8 GB and 16 GB. To interface with
DDR4 banks the following 4 main components depicted in the figure below are used:

1. DDR4 MIG (Memory Interface Generator) (8 GB and 16 GB)
2. Arbiter
3. DMA Write
4. DMA Read
