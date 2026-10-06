<!--
Generated from farsight-doc/04-section-sdd/00-imx531-detailed-spec.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/00-imx531-detailed-spec.tex > 00-imx531-detailed-spec.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

## IMX531 Detailed Overview

This document describes the IMX531 CMOS sensor used on FARSIGHT payload.

### Camera Sensor Features

#### Camera Sensor Embedded Clock Frequency

The FARSIGHT SLVS-EC camera sensor uses 74.25MHz clock frequency with
50% duty cycle which is driven by an on board oscillator on the camera module board.
In this document this clock frequency is referred to as f_{INCK}.

#### Camera Sensor Data Rate

The IMX531 SLVS-EC camera sensor consists of 8 SERDES lane that can be used to transfer
images out. The data transfer rate supported by the Farsight Avionics is 4.752 Gbps.

The frame rate (frame/s) of the camera is dictated by the number of SERDES lanes,
ADC resolution, and readout mode and sensor clock frequency.

#### Camera Sensor Digital Control Pins

This camera uses 18 digital pins to receive control signals and provide feedback
pulses. Some of the pins are fixed to a constant value since FARSIGHT will only use
SLVS-EC functionality and SPI interface of the camera sensor.
the table below shows camera sensor's digital control pin description.

| # | Pin Name | IO | Description |
| --- | --- | --- | --- |
| 1 | INCK | I | Fixed to 0. Not used by FARSIGHT |
| 2 | SLAMODE0 | I | Fixed to 0. Not used by FARSIGHT |
| 3 | SLAMODE1 | I | Fixed to 0. Not used by FARSIGHT |
| 4 | SLAMODE2 | I | Fixed to 0. Not used by FARSIGHT |
| 5 | OMODE | I | Fixed to 1 to indicate SLVS-EC mode. |
| 6 | XCLR | I | System Clear signal. (Normal: High, Clear: Low) |
| 7 | XMASTER | I | Master / Slave select. (Slave: High, Master: Low) |
| 8 | XCE | I | SPI chip select |
| 9 | SCK | I | SPI serial clock |
| 10 | SDI | I | SPI serail input |
| 11 | XTRIG1 | I | Trigger input 1 |
| 12 | XTRIG2 | I | Trigger input 2. Not used by FARSIGHT |
| 13 | XHS | IO | Horizontal sync signal |
| 14 | XVS | IO | Vertical sync signal |
| 15 | SDO | O | SPI serail output |
| 16 | TOUT0 | O | Pulse0 output pin |
| 17 | TOUT1 | O | Pulse1 output pin. Not used by FARSIGHT |
| 18 | TOUT2 | O | Pulse2 output pin. Not used by FARSIGHT |

_Table: IMX531 Pin Description_

#### Camera Sensor Serial Data Output Pin Description

The camera sensor in SLVS-EC mode supports up to 8 differential high speed data out lanes.
The number of used lanes can be controlled via register setting:

| Pin Name | IO | Description |
| --- | --- | --- |
| DOP0 | O | SLVS-EC Data Output |
| DOM0 | O | SLVS-EC Data Output |
| DOP1 | O | SLVS-EC Data Output |
| DOM1 | O | SLVS-EC Data Output |
| DOP2 | O | SLVS-EC Data Output |
| DOM2 | O | SLVS-EC Data Output |
| DOP3 | O | SLVS-EC Data Output |
| DOM3 | O | SLVS-EC Data Output |
| DOP4 | O | SLVS-EC Data Output |
| DOM4 | O | SLVS-EC Data Output |
| DOP5 | O | SLVS-EC Data Output |
| DOM5 | O | SLVS-EC Data Output |
| DOP6 | O | SLVS-EC Data Output |
| DOM6 | O | SLVS-EC Data Output |
| DOP7 | O | SLVS-EC Data Output |
| DOM7 | O | SLVS-EC Data Output |
| DCKM | O | Not used. Set to Hi-Z |
| DCKP | O | Not used. Set to Hi-Z |

_Table: IMX531 Data output Pin Description_

### Camera Sensor ADC Resolution

The image sensor has two A/D Converters (hereinafter called ADC) on the upper side and the lower side as shown in the figure below.
The ADC resolution can be set to **8-bit**, **10-bit**
or **12-bit** pixel resolution. In the current version of the Farsight only the
**12-bit** pixel resolution is supported.

![IMX531 SLVS-EC Upper and Lower ADC [sony-imx531-camera]](figures/adc-upper-lower.png)

_Figure: IMX531 SLVS-EC Upper and Lower ADC [sony-imx531-camera]_

### Camera Sensor Readout Modes

The IMX532 image sensor supports four different Readout modes.
The readout modes are:

1. All Pixel scan
2. Vertical/Horizontal 1/2 subsampling
3. 2x2 FD binning
4. Region of interest (ROI) and Overlapped ROI

Readout modes are only valid during Operation modes. Meaning there won't be any
reading during Standby mode. The pixel array structure of the above modes are described in this section.

In the current version of Farsight only the All Pixel scan mode is supported.

#### All-pixel Scan Mode Description

All-pixel scan mode is a sensor readout mode in which all pixels of the image sensor are read out simultaneously or nearly simultaneously during each frame capture. the figure below shows image sensor all-pixel scan array.

![IMX531 SLVS-EC Pixel Array Image Drawing in All-pixel scan Mode [sony-imx531-camera]](figures/pixel-array-image-drawing-all-pixel-scan-mode.png)

_Figure: IMX531 SLVS-EC Pixel Array Image Drawing in All-pixel scan Mode [sony-imx531-camera]_

#### Vertical/Horizontal 1/2 Subsampling Mode Description

Vertical/Horizontal 1/2 Subsampling Mode can be used to reduce the resolution of captured images by selectively skipping rows and/or columns of pixels during the readout process while increasing the frame rate.
By setting Vertical / Horizontal 1/2 Subsampling mode, the frame rate becomes faster than All-pixel mode. the figure below shows image sensor 1/2 subsampling pixel array.

![IMX531 SLVS-EC Pixel Array Image Drawing in Vertical / Horizontal 1/2 subsampling mode [sony-imx531-camera]](figures/pixel-array-image-drawing-in-vertical-horizontal-one-half-subsampling-mode.png)

_Figure: IMX531 SLVS-EC Pixel Array Image Drawing in Vertical / Horizontal 1/2 subsampling mode [sony-imx531-camera]_

#### 2x2 Full Digital (FD) Binning Mode Description

Binning is the procedure of combining clusters of adjacent pixels, throughout an image, into single pixels. In 2x2 binning, an array of 4 pixels becomes a single larger pixel, reducing the number of pixels to 1/4 and halving the image resolution in each dimension.
By setting 2x2 FD binning mode, the frame rate becomes faster than All-pixel mode.
the figure below shows the camera sensor 2x2 FD binning pixl array.

![Pixel Array Image Drawing in 2 × 2 FD binning mode [sony-imx531-camera]](figures/pixel-array-image-drawing-in-2-by-2-fd-binning-mode.png)

_Figure: Pixel Array Image Drawing in 2 × 2 FD binning mode [sony-imx531-camera]_

#### Region of Interest (ROI) mode Description

This Sensor has ROI function that signals are cut out and read out in multi arbitrary positions.
Cropping position can set maximum 64 areas that specified by horizontal 8 points and vertical 8 points, regarding effective pixel start position as origin (0, 0) in all pixel scan mode. Cropping is available from All-pixel scan mode and horizontal period are fixed to the value for this mode. In case of Vertical / Horizontal 1/2 subsampling mode, this sensor doesn't support ROI mode. This sensor supports ROI + 2 × 2 FD binning mode [sony-imx531-camera]. the figure below shows the IMX531 SLVS-EC Image Drawing of Designated Areas in ROI Mode.

![IMX531 SLVS-EC Image Drawing of Designated Areas in ROI Mode [sony-imx531-camera]](figures/image-drawing-of-designated-areas-in-roi-mode.png)

_Figure: IMX531 SLVS-EC Image Drawing of Designated Areas in ROI Mode [sony-imx531-camera]_

**ROI Overlaped Mode Description**
This Sensor has ROI function that signals are cut out and read out in multi arbitrary positions.
Cropping position can set maximum 8 areas, regarding effective pixel start position as origin (0, 0) in all pixel scan mode. Cropping is available from All-pixel scan mode and horizontal period are fixed to the value for this mode.

![IMX531 SLVS-EC Image Drawing of Designated Areas in Overlap ROI Mod [sony-imx531-camera]](figures/image-drawing-of-designated-areas-in-overlap-roi-mod.png)

_Figure: IMX531 SLVS-EC Image Drawing of Designated Areas in Overlap ROI Mod [sony-imx531-camera]_

### Camera Sensor Operation Modes

The camera image sensor can be in either standby mode or in operation mode.
In the operation mode the camera can be in one of the following operation sub-modes:

- Standby Mode
- Operation Mode \begin{itemize}
- Master Mode \begin{itemize}
- Normal Mode
- Sequential Trigger Mode
- Fast Trigger Mode \end{itemize}
- Slave Mode \begin{itemize}
- Normal Mode
- Sequential Trigger Mode
- Fast Trigger Mode \end{itemize} \end{itemize}

The transition between each mode is shown in the figure below.
After the Power-on sequence the camera will be in Standby Mode. The camera sensor can transition
to all Operation modes from the Standby mode. All Operation modes can also return back to Standby mode whenever is needed. A direct transition from Operating Slave mode to Operating Sequential Trigger mode and vise versa is possible with consideration that there will be one single invalid frame after the transition.
Transition between modes other than the Slave Mode to Sequential Trigger Mode must be via Standby mode.
The description of each mode is provided in this section.

![IMX531 SLVS-EC Mode Transition Diagram](figures/cam-operation-modes.png)

_Figure: IMX531 SLVS-EC Mode Transition Diagram_

#### Standby Mode

This sensor stops its operation and goes into standby mode which reduces the
power consumption by writing "1" to the standby control register STANDBY.
Standby mode is also established after power-on or other system
reset operation. Some time is required for sensor
internal circuit stabilization after standby mode is canceled [sony-imx531-camera].
If the operation mode after the standby mode is Master mode it will take 6.8 ms
for the initial regulator to stabilize the frames. If transitioning to Slave mode after
standby mode the SLVS-EC training sequence time should be used. The formula for the
SLVS-EC training mode is shown in Equation .

![IMX531 SLVS-EC Required transition time from Standby to Operation](figures/slvs-ec-standby-cancel.png)

_Figure: IMX531 SLVS-EC Required transition time from Standby to Operation_

```
SLVS-EC Training Sequence = ((S x 4) x ((D + 4) x C )) x ((10)/(B)) + (2^{(I + 1)} x ((10)/(B))) + T ms
```

Where
S = SYNCCODE_LEN
D = DESKEWCODE_INTVL
C = DESKEWCODE_LEN
B = Baudrate
I = INIT_LENGTH
T = 1.35

An example SLVS–EC training sequence calculation is shown below:

B = Baudrate = 4752 Mbps
I = INIT_LENGTH = 10 (Initial value)
S = SYNCCODE_LEN = 11412
D = DESKEWCODE_INTVL = 64
C = DESKEWCODE_LEN = 64

```
((11412 x 4) + ((64 + 4) x 64)) x ((10)/(4752000000)) x 2^{(10 + 1)} x ((10)/(4752000000)) + 1.35 ms = 1.46 ms
```

The serial communication block operates even in standby mode, so standby mode can be
canceled by setting the STANDBY register to "0".

#### Operation

This sensor has a global shutter function that integrates to all line collectively by using memory in each pixel.
This sensor has a variable electronic shutter function that can control the exposure time in line units for adjust the
exposure time. This sensor transferred signal to memory in pixel after the exposure (memory transfer), then this
sensor performs output in which readout operation is performed sequentially for each line in sync with the XHS
signal. This sensor has trigger mode that can be controlled exposure start timing and memory transfer timing by
trigger [sony-imx531-camera].

#### Master Mode Operation

In the master mode the camera sensor will generate the XVS and XHS signals internally
and won't require external inputs of these sync signals to the sensor.
The XVS and XHS signals can be set to output for external usage in the Master mode.
Note the XVS and XHS output will be asynchronous with other input or output signals
with a undefined latency time (system delay). Refer to the sync codes output from the sensor and
perform synchronization [sony-imx531-camera].

#### Slave Mode Operation

In the slave mode the camera needs to receive a vertical sync signal to XVS and
a horizontal sync signal to XHS to operate.
XVS and XVH work as vertical and horizontal sync by the camera sensor.

#### Normal (Master or Slave) Mode Operation

In the Normal mode of operation (Master or Slave mode) the camera uses XVS and
XHS signals to stabilize captured image in the pixel memories, transfer frame lines
to the output source, expose the camera sensor via the global shutter based on the
configured time, and repeat the task again. A diagram of the process is shown in the
the figure below.

![IMX531 SLVS-EC Image Drawing of Global Shutter (Normal mode) Operation [sony-imx531-camera]](figures/normal-operation.png)

_Figure: IMX531 SLVS-EC Image Drawing of Global Shutter (Normal mode) Operation [sony-imx531-camera]_

#### Trigger (Master or Slave) Mode Operation

This sensor has trigger mode that can be controlled exposure start timing and memory transfer timing by trigger. In the trigger mode the XVS signal will be ignored and
the XTRIG signal provided from the external source will be used for starting
the exposure time of the global shutter. The diagram of the trigger mode process is
shown in the figure below

![IMX531 SLVS-EC Image Drawing of Global Shutter (Trigger mode) Operation [sony-imx531-camera]](figures/trigger-operation.png)

_Figure: IMX531 SLVS-EC Image Drawing of Global Shutter (Trigger mode) Operation [sony-imx531-camera]_

### Changing Readout mode during Operation Modes

Changing Readout mode from All-Pixel scan to ROI and vise versa during
Normal Master Operation Mode,  Normal Slave Operation Mode, and
Sequential Trigger Mode does not require transition to Standby mode and will not
have any invalid frame after the Readout mode transition.
No Readout transitions should take place during Fast Trigger Operation Mode **(NEED-REQ)**. Changing Readout mode to 1/2 Subsampling or
2x2 FD binning should only happen during Standby mode **(NEED-REQ)**.
the figure below shows Readout modes transition diagram.

![IMX531 SLVS-EC Readout Modes Transition Diagram [sony-imx531-camera]](figures/cam-readout-modes.png)

_Figure: IMX531 SLVS-EC Readout Modes Transition Diagram [sony-imx531-camera]_

### Camera Sensor Register Space Address Map Structure

The camera sensor has a total of 5888 registers with each register being 8 bit wide.

Each register write can have different affect on the image frame depending on type of the register reflection. There are three different register reflection timings.

- "**I**" registers are reflected immediately after writing to register.
- "**V**" registers are reflected at "Frame reflection register reflection timing".
- "**S**" registers are set during standby mode and reflected after standby canceled.

Note: All registers noted as "S" type should be only changed during the Standby mode **(NEED-REQ)**.

### Camera Sensor Serial Communication Interface

This sensor can write and read the setting values of the various registers shown in the Register Map by 4-wire serial SPI interface [sony-imx531-camera]. The sensor also provides option for
I2C communication which is not used in the FARSIGHT architecture. The XCE pin is shared between
4-wire SPI and I2C interface and acts as chip select in SPI mode. The XCE pin shall not be fixed to
a permanent fixed value in the SPI mode **(NEED-REQ)**.
The details of SPI timing address space is described in this section.

#### Camera Sensor SPI Communication Structure

The data is transferred in LSB-first order. the table below shows the SPI serial data transfer order.

| Chip ID | Start Address | Data | Data | Data | ... |
| --- | --- | --- | --- | --- | --- |
| (8 bit) | (8 bit) | (8 bit) | (8 bit) | (8 bit) | ... |

_Table: SPI Data Transfer Order_

When using a communication method
that designates continuous addresses, the address is automatically incremented from the
previously transmitted address [sony-imx531-camera] as shown in the figure below.

![SPI Communication Continuous Addresses](figures/spi-serial-communication-continuous-addr.png)

_Figure: SPI Communication Continuous Addresses_

When writing data to multiple registers with discontinuous addresses, access to undesired registers
can be avoided by initiating a new write to the SPI interface as shown in the figure below.

![SPI Communication Discontinuous Addresses](figures/spi-serial-communication-discontinuous-addr.png)

_Figure: SPI Communication Discontinuous Addresses_

The register address space is divided into 23 Chip ID values. Each Chip ID value maps to 256 registers with address value between 00h to ffh. The SPI read and write Chip ID values
are shown in the table below.

| # | **Write Chip ID** | **Read Chip ID** |
| --- | --- | --- |
| 1 | 02h | 82h |
| 2 | 03h | 83h |
| 3 | 04h | 84h |
| 4 | 05h | 85h |
| 5 | 06h | 86h |
| 6 | 07h | 87h |
| 7 | 08h | 88h |
| 8 | 09h | 89h |
| 9 | 0Ah | 8Ah |
| 10 | 0Bh | 8Bh |
| 11 | 0Ch | 8Ch |
| 12 | 0Dh | 8Dh |
| 13 | 10h | 90h |
| 14 | 11h | 91h |
| 15 | 12h | 92h |
| 16 | 13h | 93h |
| 17 | 14h | 94h |
| 18 | 15h | 95h |
| 19 | 16h | 96h |
| 20 | 17h | 97h |
| 21 | 18h | 98h |
| 22 | 19h | 99h |
| 23 | 1Ah | 9Ah |

_Table: SPI Memory Address Structure_

#### Camera Sensor SPI Register Write Process

The following is procedure for writing to registers using SPI interface:

1. Set XCE Low to enable the chip's communication function. Serial data input is executed using SCK and SDI.
2. Transmit data in sync with SCK 1 bit at a time from the LSB using SDI. Transfer SDI in sync with the falling edge of SCK. (The data is loaded at the rising edge of SCK.)
3. Input the Chip ID (CID = 02h to 0Dh, 10h to 1Ah) to the first byte. If the Chip ID differs, subsequent data is ignored.
4. Input the start address to the second byte. The address is automatically incremented.
5. Input the data to the third and subsequent bytes. The data in the third byte is written to the register address designated by the second byte, and the register address is automatically incremented thereafter when writing the data for the fourth and subsequent bytes. Normal register data is loaded to the inside of the sensor and established in 8-bit units.
6. The register values starting from the register address designated by the second byte are output from the SDO pin. The register values before the write operation are output. The actual register values are the input data.
7. Set XCE High to end communication.

#### Camera Sensor SPI Register Read Process

The following is procedure for reading registers using SPI interface:

1. Set XCE Low to enable the chip's communication function. Serial data input is executed using SCK and SDI.
2. Transmit data in sync with SCK 1 bit at a time from the LSB using SDI. Transfer SDI in sync with the falling edge of SCK. (The data is loaded at the rising edge of SCK.)
3. Input Chip ID (CID = 82h to 8Dh, 90h to 9Ah) to the first byte. If the Chip ID differs, subsequent data is ignored.
4. Input the start address to the second byte. The address is automatically incremented.
5. Input data to the third and subsequent bytes. Input dummy data in order to read the registers. The dummy data is not written to the registers. To read continuous data, input the necessary number of bytes of dummy data.
6. The register values starting from the register address designated by the second byte are output from the SDO pin. The input data is not written, so the actual register values are output.
7. Set XCE High to end communication.

### Camera Sensor Functions

#### Gain Adjustment Function

The Programmable Gain Control (PGC) of this device consists of the analog block
and digital block. The total of analog gain and digital gain can be set up to
48 dB by the GAIN [8:0] register setting. The value which is ten times the gain
is set to register (0.1 dB step) [sony-imx531-camera].

For example when need to set the gain to 6 dB:

6 x 10 = 60d

GAIN = 03Ch (60d = 03Ch)

#### Calibration Function

This image sensor has two A/D Converters (hereinafter called ADC) on the upper
side and the lower side. The difference of performance due to manufacturing
variations may occur between the upper ADC and the lower ADC and this may appear
at the output level of the column.
For this reason, this image sensor has a correction value and performs correction
processing [sony-imx531-camera].

#### Balck Level Adjustment Function

Black Level Adjustment allows adjusting the signal baseline to let the darkest parts
of an image be represented correctly, without residual offsets that might cause
incorrect brightness levels.
The black level offset (offset variable range: 000h to FFFh) can be added
relative to the data in which the digital gain modulation was
performed [sony-imx531-camera].

### Camera Sensor Shutter and Exposure time

This sensor has a global shutter function that integrates to all line collectively by using memory in each pixel.
This sensor has a variable electronic shutter function that can control the exposure time in line units for adjust the
exposure time. This sensor transferred signal to memory in pixel after the exposure (memory transfer), then this
sensor performs output in which readout operation is performed sequentially for each line in sync with the XHS
signal. This sensor has trigger mode that can be controlled exposure start timing and memory transfer timing by
trigger [sony-imx531-camera].

#### Global Shutter Normal Execution

The exposure time can be controlled by varying the electronic shutter timing. In the electronic shutter settings, the exposure time is controlled by the SHS [23:0] register. When the sensor is operating in slave mode, the number of lines per frame is determined by the
XVS interval (number of lines), using the input XHS interval as the line unit.
When the sensor is operating in master
mode, the number of lines per frame is determined by the VMAX [23:0] register. The number of lines per frame
differs according to the readout mode [sony-imx531-camera]. the figure below shows image drawing of global shutter in normal mode.

**Calculation Formula of Exposure Time**

```
Exposure time [us] = (1H period [us]) x (Number of lines per frame - SHS) + t_{OFFSET} [us]
```

Where {t_OFFSET} = 2.46 u{s} is the exposure time error.

**TBD: Create exposure value lookup table per page 166 of IMX531 user guide**

![Image Drawing of Global Shutter (Normal Mode) [sony-imx531-camera]](figures/global-shutter-normal-mode.png)

_Figure: Image Drawing of Global Shutter (Normal Mode) [sony-imx531-camera]_

#### Global Shutter Normal Execution with Interrupt

In case of "VINT_EN_NOR = 1h", the image drawing when the interrupt operation is generated is shown below.
When the next XVS is input during read of the frame (Frame 1 in the figure below), Frame 1 becomes an invalid
frame. XVS input timing of interrupt generating corresponds to recommended setting value of VMAX [23:0] in each
readout mode.
In case of "VINT_EN_NOR = 0h", XVS input at intervals shorter than the recommended setting value of VMAX [23:0] is invalid [sony-imx531-camera].

![Image Drawing of Global Shutter (Normal Mode) with Interrupt [sony-imx531-camera]](figures/global-shutter-normal-mode-with-interrupt.png)

_Figure: Image Drawing of Global Shutter (Normal Mode) with Interrupt [sony-imx531-camera]_

#### Global Shutter Sequential Trigger Execution

The exposure time can be controlled by varying the pulse width that is input to XTRIG1 pin, the figure below. The pulse width
designated in XHS unit [H]. For the transition from normal mode to Sequential trigger mode, set 1 to the register
TRIGMODE[2:0]. The XVS input signal is ignored during Sequential trigger mode operating.
In case of inputting trigger continuously, the figure below, there are periods which prohibit the trigger rise input (t_{TGPD}) and fall input (t_{TGES}) based on the
previous trigger rise.
The number of lines per frame differs according to the operating mode.
XTRIG2 pin is set Open (Hi-Z) or fixed to High after power-on sequence **(NEED-REQ)**.

```
Exposure time [us] = (1H period [us]) x (XTRIG low level pulse width [H] - SHS) + t_{OFFSET} [us]
```

Where {t_OFFSET} = 2.46 u{s} is the exposure time error.

The Low level pulse width is counted by XHS pulse.

![Single shutter Image Drawing of Global Shutter (Sequential Trigger Mode) [sony-imx531-camera]](figures/global-shutter-single-seq-trigger-mode.png)

_Figure: Single shutter Image Drawing of Global Shutter (Sequential Trigger Mode) [sony-imx531-camera]_

![Multi shutter image Drawing of Global Shutter (Sequential Trigger Mode) [sony-imx531-camera]](figures/global-shutter-multiple-seq-trigger-mode.png)

_Figure: Multi shutter image Drawing of Global Shutter (Sequential Trigger Mode) [sony-imx531-camera]_

#### Global Shutter Sequential Trigger Execution with Interrupt

When the trigger rise is input before the rise input prohibited period (t_{TGPD}), interrupt operation starts. This function is only in slave mode.
In case of "VINT_EN = 1h", the image drawing when the interrupt operation is generated is shown below. When the
trigger is raised again and the next frame is output during read of the frame for which read was started by a trigger
rise (Frame 1 in the figure below), Frame 1 becomes an invalid frame. Trigger timing of interrupt generating
corresponds to t_{TGPD} in Parameter List of Global Shutter (Trigger Mode)
In case of "VINT_EN = 0h", both of the rising edge and the falling edge of the trigger signal are ignored in t_{TGPD}
(Prohibit period).

![Image Drawing of Interrupt Operation in Global Shutter (Sequential Trigger Mode) [sony-imx531-camera]](figures/global-shutter-seq-trigger-mode-with-interrupt.png)

_Figure: Image Drawing of Interrupt Operation in Global Shutter (Sequential Trigger Mode) [sony-imx531-camera]_

FARSIGHT will not support Seq Trigger with Interrupt mode as slave mode functionality will be implemented.
**(NEED-REQ)**

#### Global Shutter Fast Trigger Execution

Fast trigger mode is the trigger mode that starts exposure at fall of XTRIG1 immediately the figure below.
In the Fast trigger mode, set the register TRIGMODE [2:0] to 2h at standby state, and then release standby. In the
Fast trigger mode, the image size can not be changed during the operation.
This mode supports Master mode only. **(NEED-REQ**
XTRIG2 pin is set Open (Hi-Z) or fixed to High after power-on sequence.

```
Exposure time [us] = (XTRIG low level pulse width [us] + (GMRWT [H] x 1 H period [us]) + t_{OFFSET} [us]
```

Where {t_OFFSET} = 2.46 u{s} is the exposure time error.

![Image Drawing of Global Shutter (Fast Trigger Mode) [sony-imx531-camera]](figures/global-shutter-fast-trigger-mode.png)

_Figure: Image Drawing of Global Shutter (Fast Trigger Mode) [sony-imx531-camera]_

### Pulse Output Function

**TBD**

### Camera Sensor Power Sequence Procedure

The following section describes camera sensor power sequence procedures controlled
by the FARSIGHT Avionic Computer (FAV).
To see power on flow diagram see the figure below.
To see the timing diagram of the power-on sequence see Appendix the figure below.
To see power off flow diagram see the figure below.
To see the flow diagram of the power-off sequence see Appendix the figure below.

#### Power-on Sequence

> Figure not available: IMX531 SLVS-EC Power-on Sequence Flow. The image `power-on-seq.png` is referenced by the LaTeX source but was never committed to farsight-doc.

_Figure: IMX531 SLVS-EC Power-on Sequence Flow_

#### Power-off Sequence

> Figure not available: IMX531 SLVS-EC Power-off Sequence Flow. The image `power-off-seq.png` is referenced by the LaTeX source but was never committed to farsight-doc.

_Figure: IMX531 SLVS-EC Power-off Sequence Flow_

### Camera Sensor Setting and Operation Flow

The camera sensor can be in one of the following modes:

- **power-off mode** (no power consumption)
- **Standby mode** (low power consumption)
- **Operation mode** (normal power consumption)

The operation mode can be in one of the following operation sub-modes:

- **Normal** operation
- **Sequential trigger** operation
- **Fast trigger** operation

The camera operation can be controlled in one of the following settings:

- **Master** setting
- **Slave** setting

The Master control setting will use the on board circuitry of the camera sensor
to generate XVS (Vertical Sync) and XHS (Horizontal Sync) signals to determine
frame boundary, memory wait, data transfer, and global shutter start and stop exposure.

The Slave control setting requires user to provide the XVS and XHS signals per
requirements defined in the camera sensor user manual (see  [sony-imx531-camera]).

![IMX531 SLVS-EC Camera Sensor Setting and Operation Flow Diagram](figures/cam-sensor-setting-flow.png)

_Figure: IMX531 SLVS-EC Camera Sensor Setting and Operation Flow Diagram_
