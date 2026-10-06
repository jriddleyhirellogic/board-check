//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
  MICROCHIP STANDARD SOFTWARE COPYRIGHT NOTICE & DISCLAIMER.

  WHEN TO USE: Use this standard notice in header files when there is a Microchip software license that will accompany this distribution of the same software/code.
  This notice requires users to use software subject to the Microchip software license and with Microchip products.

  If you have questions, please contact Brian Harlow, Managing Sr Counsel - Transactions, at brian.harlow@microchip.com or 480-577-2821.

  (C) [2026] Microchip Technology Inc. and its subsidiaries

  Subject to your compliance with the terms and conditions of the license agreement accompanying this software, you may use this Microchip software and any derivatives
  exclusively with Microchip products. You are responsible for complying with third party license terms applicable to your use of third party software (including open source software)
  that may accompany this Microchip software. SOFTWARE IS "AS IS." NO WARRANTIES, WHETHER EXPRESS, IMPLIED OR STATUTORY, APPLY TO THIS SOFTWARE, INCLUDING ANY IMPLIED WARRANTIES OF NON-INFRINGEMENT,
  MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT WILL MICROCHIP BE LIABLE FOR ANY INDIRECT, SPECIAL, PUNITIVE, INCIDENTAL OR CONSEQUENTIAL LOSS, DAMAGE, COST OR EXPENSE OF ANY KIND WHATSOEVER
  RELATED TO THE SOFTWARE, HOWEVER CAUSED, EVEN IF MICROCHIP HAS BEEN ADVISED OF THE POSSIBILITY OR THE DAMAGES ARE FORESEEABLE. TO THE FULLEST EXTENT ALLOWED BY LAW, MICROCHIP'S TOTAL LIABILITY ON ALL CLAIMS
  RELATED TO THE SOFTWARE WILL NOT EXCEED AMOUNT OF FEES, IF ANY, YOU PAID DIRECTLY TO MICROCHIP FOR THIS SOFTWARE.
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  File Name        : XCVR_DISPARITY_CORRECTION.v
  Description      : Multi-lane XCVR disparity error detection and first lock detection module
  Targeted device  : MICROCHIP - PolarFire and PolarFire SoC
  Author           : Modified for SLVS-EC ERM integration

  FUNCTIONAL DESCRIPTION:
  -----------------------
  This module provides unified disparity error monitoring and first lock detection
  for XCVR ERM configurations. A single instance handles multiple lanes (2/4/8).

  Key Features:
    1. Per-lane disparity error monitoring in each lane's clock domain
    2. CDC synchronization to bring error flags to common P_CLK domain
    3. Unified FSM for reset control and interrupt generation
    4. Optional first-lock detection for ERM mode (parameter controlled)
    5. Single interrupt output for both disparity errors and first lock
    6. Generates 32-cycle reset pulse to downstream logic

  MODULE HIERARCHY:
  -----------------
    XCVR_DISPARITY_CORRECTION (This Module)
      |-- Per-Lane Disparity Detectors (8 parallel, in LANEx_RX_CLK domains)
      |-- CDC Synchronizers (2-FF sync to P_CLK domain)
      |-- First Lock Detector (all lanes ready, one-shot)
      +-- Unified FSM (reset control + interrupt generation)

  PARAMETERS:
  -----------
    NUM_LANES             : Number of active lanes (2, 4, or 8)
    DISPARITY_ERR_WIDTH   : Error counter width (default: 4, threshold = 16)
    RST_CNT_CLKS          : Reset pulse duration in clocks (default: 32)
    ENABLE_ERM_FIRST_LOCK : Enable first lock detection (1=ERM, 0=Non-ERM)

  USAGE FOR DIFFERENT LANE CONFIGURATIONS:
  -----------------------------------------

  2-Lane Configuration (NUM_LANES = 2):
    Connect LANE0 and LANE1 to actual XCVR signals:
      - LANE0_RX_CLK_I         → PF_XCVR_ERM_Cx_0_LANE0_RX_CLK_R
      - LANE0_RX_VALID_I       → PF_XCVR_ERM_Cx_0_LANE0_RX_VAL
      - LANE0_RX_READY_I       → LANE0_RX_READY
      - LANE0_DISPARITY_ERR_I  → PF_XCVR_ERM_Cx_0_LANE0_RX_DISPARITY_ERROR[3:0]
      (Same for LANE1)

    Tie unused lanes (2-7) to safe defaults:
      - LANEx_RX_READY_I       → VCC_net (1'b1) - Indicates "ready"
      - LANEx_RX_VALID_I       → GND_net (1'b0) - No valid data
      - LANEx_DISPARITY_ERR_I  → 4'b0000       - No errors
      - LANEx_RX_CLK_I         → P_CLK_I       - Any stable clock

  4-Lane Configuration (NUM_LANES = 4):
    Connect LANE0-3 to actual XCVR signals
    Tie LANE4-7 as described above for 2-lane

  8-Lane Configuration (NUM_LANES = 8):
    Connect all LANE0-7 to actual XCVR signals
    No tie-offs needed

  INTERRUPT GENERATION:
  ---------------------
    RX_RST_CONTROL_INTERRUPT_O pulses HIGH for 1 cycle on:
      - Disparity error: Software should reset camera via I2C
      - First lock: Software should release camera from GPIO reset

  FIRST LOCK BEHAVIOR (ERM Mode):
  --------------------------------
    When ENABLE_ERM_FIRST_LOCK = 1:
      1. Module monitors RX_READY from all active lanes
      2. Detects rising edge when ALL lanes transition to ready
      3. Triggers reset sequence (same as disparity error)
      4. Generates interrupt to software
      5. Latches event - subsequent lane ready events are ignored
      6. Software releases camera from GPIO reset in response

    Purpose: Ensures camera SYNC codes are sent only after FPGA XCVR
             has completed calibration and is ready to receive.

    Camera Reset Handling:
      - Camera I2C reset stops data transmission temporarily
      - XCVR loses lock, RX_READY drops then rises again
      - First lock latch persists (RESET_N_I stays HIGH during camera reset)
      - Subsequent RX_READY posedge is blocked by latch
      - No false interrupts generated

  DISPARITY ERROR HANDLING:
  -------------------------
    - Each lane independently counts consecutive disparity errors
    - Threshold: 16 consecutive errors (configurable via DISPARITY_ERR_WIDTH)
    - Any lane exceeding threshold triggers reset + interrupt
    - Software should reset camera via I2C in response
    - Normal operation resumes after reset sequence completes

*/
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

`timescale 1ns / 100ps

module XCVR_DISPARITY_CORRECTION #(
    parameter NUM_LANES             = 8,    // Number of active lanes: 2, 4, or 8
    parameter DISPARITY_ERR_WIDTH   = 4,    // Error counter width (threshold = 2^4 = 16)
    parameter RST_CNT_CLKS          = 32,   // Reset pulse duration (32 clock cycles)
    parameter ENABLE_ERM_FIRST_LOCK = 1     // 1=Enable first lock (ERM), 0=Disable
)(
    //-------------------------------------------------------------------------
    // Clock and Reset
    //-------------------------------------------------------------------------
    input                               P_CLK_I,        // System clock (common domain)
    input                               RESET_N_I,      // Active-low reset (qualified by PLL lock)

    //-------------------------------------------------------------------------
    // Per-Lane RX Clocks (Independent clock domains)
    //-------------------------------------------------------------------------
    input                               LANE0_RX_CLK_I,
    input                               LANE1_RX_CLK_I,
    input                               LANE2_RX_CLK_I, // Tie to P_CLK_I if unused
    input                               LANE3_RX_CLK_I, // Tie to P_CLK_I if unused
    input                               LANE4_RX_CLK_I, // Tie to P_CLK_I if unused
    input                               LANE5_RX_CLK_I, // Tie to P_CLK_I if unused
    input                               LANE6_RX_CLK_I, // Tie to P_CLK_I if unused
    input                               LANE7_RX_CLK_I, // Tie to P_CLK_I if unused

    //-------------------------------------------------------------------------
    // Per-Lane RX Valid (Data valid indicators)
    //-------------------------------------------------------------------------
    input                               LANE0_RX_VALID_I,
    input                               LANE1_RX_VALID_I,
    input                               LANE2_RX_VALID_I, // Tie to GND_net if unused
    input                               LANE3_RX_VALID_I, // Tie to GND_net if unused
    input                               LANE4_RX_VALID_I, // Tie to GND_net if unused
    input                               LANE5_RX_VALID_I, // Tie to GND_net if unused
    input                               LANE6_RX_VALID_I, // Tie to GND_net if unused
    input                               LANE7_RX_VALID_I, // Tie to GND_net if unused

    //-------------------------------------------------------------------------
    // Per-Lane Calibrating Status (ERM calibration indicators)
    //-------------------------------------------------------------------------
    // HIGH = Calibration in progress, LOW = Calibration complete
    input                               LANE0_CALIBRATING_I,
    input                               LANE1_CALIBRATING_I,
    input                               LANE2_CALIBRATING_I, // Tie to GND_net if unused
    input                               LANE3_CALIBRATING_I, // Tie to GND_net if unused
    input                               LANE4_CALIBRATING_I, // Tie to GND_net if unused
    input                               LANE5_CALIBRATING_I, // Tie to GND_net if unused
    input                               LANE6_CALIBRATING_I, // Tie to GND_net if unused
    input                               LANE7_CALIBRATING_I, // Tie to GND_net if unused

    //-------------------------------------------------------------------------
    // Per-Lane Disparity Errors (4 bits per lane, one per byte)
    //-------------------------------------------------------------------------
    input [DISPARITY_ERR_WIDTH-1:0]     LANE0_DISPARITY_ERR_I,
    input [DISPARITY_ERR_WIDTH-1:0]     LANE1_DISPARITY_ERR_I,
    input [DISPARITY_ERR_WIDTH-1:0]     LANE2_DISPARITY_ERR_I, // Tie to 4'b0000 if unused
    input [DISPARITY_ERR_WIDTH-1:0]     LANE3_DISPARITY_ERR_I, // Tie to 4'b0000 if unused
    input [DISPARITY_ERR_WIDTH-1:0]     LANE4_DISPARITY_ERR_I, // Tie to 4'b0000 if unused
    input [DISPARITY_ERR_WIDTH-1:0]     LANE5_DISPARITY_ERR_I, // Tie to 4'b0000 if unused
    input [DISPARITY_ERR_WIDTH-1:0]     LANE6_DISPARITY_ERR_I, // Tie to 4'b0000 if unused
    input [DISPARITY_ERR_WIDTH-1:0]     LANE7_DISPARITY_ERR_I, // Tie to 4'b0000 if unused

    //-------------------------------------------------------------------------
    // Unified Outputs (Single outputs for all lanes)
    //-------------------------------------------------------------------------
    output reg                          RX_RST_CONTROL_O,           // Reset control (pulses LOW for 32 cycles)
    output reg                          RX_RST_CONTROL_INTERRUPT_O  // Interrupt pulse (HIGH for 1 cycle)
);

//=============================================================================
// LOCAL PARAMETERS
//=============================================================================
localparam DISPARITY_ERROR_COUNT_THRESHOLD = 1 << DISPARITY_ERR_WIDTH; // Threshold = 16 errors
localparam RST_CNT_WIDTH = $clog2(RST_CNT_CLKS);                        // Counter width for 32 cycles

//=============================================================================
// FSM STATE ENCODING
//=============================================================================
// FSM states to detect and handle ERM calibration sequence:
//   s_IDLE              - Initial state, wait for activity
//   s_DETECT_SEQUENCE   - Detect which signal comes first (CALIB or VALID)
//   s_WAIT_CALIB_DONE   - Detected CALIB HIGH, wait for CALIB LOW
//   s_WAIT_VALID_STABLE - Wait for RX_VALID stable
//   s_ERR_DETECT_CNT    - Normal operation, monitors disparity
//   s_RST_CNT           - Reset active, counting 32 cycles
//   s_REG_RST           - Reset complete, generate interrupt pulse
//=============================================================================
localparam s_IDLE              = 3'd0;
localparam s_DETECT_SEQUENCE   = 3'd1;
localparam s_WAIT_CALIB_DONE   = 3'd2;
localparam s_WAIT_VALID_STABLE = 3'd3;
localparam s_ERR_DETECT_CNT    = 3'd4;
localparam s_RST_CNT           = 3'd5;
localparam s_REG_RST           = 3'd6;

//=============================================================================
// PER-LANE DISPARITY ERROR DETECTION (In Each Lane's Clock Domain)
//=============================================================================
// Each lane independently monitors disparity errors in its own clock domain
// Error counters accumulate up to threshold (16 consecutive errors)
// Once threshold reached, error flag is set and synchronized to P_CLK domain
//=============================================================================

//-----------------------------------------------------------------------------
// Lane 0 Disparity Detection
//-----------------------------------------------------------------------------
reg [DISPARITY_ERR_WIDTH-1:0] lane0_err_cnt;
reg                           lane0_err_flag;

always @(posedge LANE0_RX_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        lane0_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
        lane0_err_flag <= 1'b0;
    end
    else if (LANE0_RX_VALID_I) begin
        if (|LANE0_DISPARITY_ERR_I) begin  // Any error bit set
            lane0_err_cnt  <= (lane0_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1) ?
                              {DISPARITY_ERR_WIDTH{1'b0}} : lane0_err_cnt + 1'b1;
            lane0_err_flag <= (lane0_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1);
        end
        else begin
            lane0_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
            lane0_err_flag <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------------------
// Lane 1 Disparity Detection
//-----------------------------------------------------------------------------
reg [DISPARITY_ERR_WIDTH-1:0] lane1_err_cnt;
reg                           lane1_err_flag;

always @(posedge LANE1_RX_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        lane1_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
        lane1_err_flag <= 1'b0;
    end
    else if (LANE1_RX_VALID_I) begin
        if (|LANE1_DISPARITY_ERR_I) begin
            lane1_err_cnt  <= (lane1_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1) ?
                              {DISPARITY_ERR_WIDTH{1'b0}} : lane1_err_cnt + 1'b1;
            lane1_err_flag <= (lane1_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1);
        end
        else begin
            lane1_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
            lane1_err_flag <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------------------
// Lane 2 Disparity Detection
// NOTE: Tie inputs to safe values if NUM_LANES < 3
//-----------------------------------------------------------------------------
reg [DISPARITY_ERR_WIDTH-1:0] lane2_err_cnt;
reg                           lane2_err_flag;

always @(posedge LANE2_RX_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        lane2_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
        lane2_err_flag <= 1'b0;
    end
    else if (LANE2_RX_VALID_I) begin
        if (|LANE2_DISPARITY_ERR_I) begin
            lane2_err_cnt  <= (lane2_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1) ?
                              {DISPARITY_ERR_WIDTH{1'b0}} : lane2_err_cnt + 1'b1;
            lane2_err_flag <= (lane2_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1);
        end
        else begin
            lane2_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
            lane2_err_flag <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------------------
// Lane 3 Disparity Detection
// NOTE: Tie inputs to safe values if NUM_LANES < 4
//-----------------------------------------------------------------------------
reg [DISPARITY_ERR_WIDTH-1:0] lane3_err_cnt;
reg                           lane3_err_flag;

always @(posedge LANE3_RX_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        lane3_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
        lane3_err_flag <= 1'b0;
    end
    else if (LANE3_RX_VALID_I) begin
        if (|LANE3_DISPARITY_ERR_I) begin
            lane3_err_cnt  <= (lane3_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1) ?
                              {DISPARITY_ERR_WIDTH{1'b0}} : lane3_err_cnt + 1'b1;
            lane3_err_flag <= (lane3_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1);
        end
        else begin
            lane3_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
            lane3_err_flag <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------------------
// Lane 4 Disparity Detection
// NOTE: Tie inputs to safe values if NUM_LANES < 5
//-----------------------------------------------------------------------------
reg [DISPARITY_ERR_WIDTH-1:0] lane4_err_cnt;
reg                           lane4_err_flag;

always @(posedge LANE4_RX_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        lane4_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
        lane4_err_flag <= 1'b0;
    end
    else if (LANE4_RX_VALID_I) begin
        if (|LANE4_DISPARITY_ERR_I) begin
            lane4_err_cnt  <= (lane4_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1) ?
                              {DISPARITY_ERR_WIDTH{1'b0}} : lane4_err_cnt + 1'b1;
            lane4_err_flag <= (lane4_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1);
        end
        else begin
            lane4_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
            lane4_err_flag <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------------------
// Lane 5 Disparity Detection
// NOTE: Tie inputs to safe values if NUM_LANES < 6
//-----------------------------------------------------------------------------
reg [DISPARITY_ERR_WIDTH-1:0] lane5_err_cnt;
reg                           lane5_err_flag;

always @(posedge LANE5_RX_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        lane5_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
        lane5_err_flag <= 1'b0;
    end
    else if (LANE5_RX_VALID_I) begin
        if (|LANE5_DISPARITY_ERR_I) begin
            lane5_err_cnt  <= (lane5_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1) ?
                              {DISPARITY_ERR_WIDTH{1'b0}} : lane5_err_cnt + 1'b1;
            lane5_err_flag <= (lane5_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1);
        end
        else begin
            lane5_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
            lane5_err_flag <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------------------
// Lane 6 Disparity Detection
// NOTE: Tie inputs to safe values if NUM_LANES < 7
//-----------------------------------------------------------------------------
reg [DISPARITY_ERR_WIDTH-1:0] lane6_err_cnt;
reg                           lane6_err_flag;

always @(posedge LANE6_RX_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        lane6_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
        lane6_err_flag <= 1'b0;
    end
    else if (LANE6_RX_VALID_I) begin
        if (|LANE6_DISPARITY_ERR_I) begin
            lane6_err_cnt  <= (lane6_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1) ?
                              {DISPARITY_ERR_WIDTH{1'b0}} : lane6_err_cnt + 1'b1;
            lane6_err_flag <= (lane6_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1);
        end
        else begin
            lane6_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
            lane6_err_flag <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------------------
// Lane 7 Disparity Detection
// NOTE: Tie inputs to safe values if NUM_LANES < 8
//-----------------------------------------------------------------------------
reg [DISPARITY_ERR_WIDTH-1:0] lane7_err_cnt;
reg                           lane7_err_flag;

always @(posedge LANE7_RX_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        lane7_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
        lane7_err_flag <= 1'b0;
    end
    else if (LANE7_RX_VALID_I) begin
        if (|LANE7_DISPARITY_ERR_I) begin
            lane7_err_cnt  <= (lane7_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1) ?
                              {DISPARITY_ERR_WIDTH{1'b0}} : lane7_err_cnt + 1'b1;
            lane7_err_flag <= (lane7_err_cnt == DISPARITY_ERROR_COUNT_THRESHOLD-1);
        end
        else begin
            lane7_err_cnt  <= {DISPARITY_ERR_WIDTH{1'b0}};
            lane7_err_flag <= 1'b0;
        end
    end
end

//=============================================================================
// CDC SYNCHRONIZERS - Bring Error Flags from Lane Clocks to P_CLK Domain
//=============================================================================
// 2-stage flip-flop synchronizers for metastability prevention
// Each lane's error flag crosses from LANEx_RX_CLK_I to P_CLK_I domain
//=============================================================================

reg lane0_err_sync1, lane0_err_sync2;
reg lane1_err_sync1, lane1_err_sync2;
reg lane2_err_sync1, lane2_err_sync2;
reg lane3_err_sync1, lane3_err_sync2;
reg lane4_err_sync1, lane4_err_sync2;
reg lane5_err_sync1, lane5_err_sync2;
reg lane6_err_sync1, lane6_err_sync2;
reg lane7_err_sync1, lane7_err_sync2;

always @(posedge P_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        // Reset all synchronizers
        lane0_err_sync1 <= 1'b0; lane0_err_sync2 <= 1'b0;
        lane1_err_sync1 <= 1'b0; lane1_err_sync2 <= 1'b0;
        lane2_err_sync1 <= 1'b0; lane2_err_sync2 <= 1'b0;
        lane3_err_sync1 <= 1'b0; lane3_err_sync2 <= 1'b0;
        lane4_err_sync1 <= 1'b0; lane4_err_sync2 <= 1'b0;
        lane5_err_sync1 <= 1'b0; lane5_err_sync2 <= 1'b0;
        lane6_err_sync1 <= 1'b0; lane6_err_sync2 <= 1'b0;
        lane7_err_sync1 <= 1'b0; lane7_err_sync2 <= 1'b0;
    end
    else begin
        // 2-stage synchronization (stage1 may be metastable, stage2 is stable)
        lane0_err_sync1 <= lane0_err_flag; lane0_err_sync2 <= lane0_err_sync1;
        lane1_err_sync1 <= lane1_err_flag; lane1_err_sync2 <= lane1_err_sync1;
        lane2_err_sync1 <= lane2_err_flag; lane2_err_sync2 <= lane2_err_sync1;
        lane3_err_sync1 <= lane3_err_flag; lane3_err_sync2 <= lane3_err_sync1;
        lane4_err_sync1 <= lane4_err_flag; lane4_err_sync2 <= lane4_err_sync1;
        lane5_err_sync1 <= lane5_err_flag; lane5_err_sync2 <= lane5_err_sync1;
        lane6_err_sync1 <= lane6_err_flag; lane6_err_sync2 <= lane6_err_sync1;
        lane7_err_sync1 <= lane7_err_flag; lane7_err_sync2 <= lane7_err_sync1;
    end
end

//=============================================================================
// COMBINE DISPARITY ERRORS FROM ALL ACTIVE LANES
//=============================================================================
// OR together error flags from all active lanes (based on NUM_LANES parameter)
// Unused lanes are ignored by the generate statement
//=============================================================================
wire any_lane_disparity_error;

generate
    if (NUM_LANES == 8) begin : GEN_8_LANE_ERROR_DETECT
        assign any_lane_disparity_error = lane0_err_sync2 | lane1_err_sync2 |
                                          lane2_err_sync2 | lane3_err_sync2 |
                                          lane4_err_sync2 | lane5_err_sync2 |
                                          lane6_err_sync2 | lane7_err_sync2;
    end
    else if (NUM_LANES == 4) begin : GEN_4_LANE_ERROR_DETECT
        assign any_lane_disparity_error = lane0_err_sync2 | lane1_err_sync2 |
                                          lane2_err_sync2 | lane3_err_sync2;
    end
    else if (NUM_LANES == 2) begin : GEN_2_LANE_ERROR_DETECT
        assign any_lane_disparity_error = lane0_err_sync2 | lane1_err_sync2;
    end
    else begin : GEN_1_LANE_ERROR_DETECT
        assign any_lane_disparity_error = lane0_err_sync2;
    end
endgenerate

//=============================================================================
// FIRST LOCK DETECTION - All Lanes Ready (ERM Mode Only)
//=============================================================================
// Detects when ALL active lanes have locked for the FIRST TIME
// Uses one-shot latch to prevent re-triggering on subsequent lock events
// Only enabled when ENABLE_ERM_FIRST_LOCK = 1 (for ERM configurations)
//
// Behavior:
//   - Monitors RX_READY signals from all active lanes
//   - Detects rising edge when all lanes transition to ready
//   - Latches the event (first_lock_latch) - never clears until FPGA reset
//   - Subsequent lane ready events are ignored (gated by latch)
//
// Purpose:
//   Generate interrupt to software to release camera from GPIO reset
//   at the optimal time (when FPGA XCVR is fully ready to receive SYNC)
//=============================================================================

wire all_lanes_valid;               // All lanes have valid data
wire all_lanes_not_calibrating;     // All lanes finished calibration
wire all_lanes_ready_for_trigger;   // Valid AND not calibrating
reg  all_lanes_ready_prev;          // Previous cycle value for edge detection
reg  first_lock_latch;              // One-shot latch (set once, never clears)
wire all_lanes_ready_posedge;       // Rising edge detector
wire first_lock_trigger;            // Qualified trigger (gated by enable and latch)

//-----------------------------------------------------------------------------
// Combine RX_READY and RX_VALID from All Active Lanes (Based on NUM_LANES)
//-----------------------------------------------------------------------------
generate
    if (NUM_LANES == 8) begin : GEN_8_LANE_VALID_DETECT
        // All 8 lanes must have valid data
        assign all_lanes_valid = LANE0_RX_VALID_I & LANE1_RX_VALID_I &
                                 LANE2_RX_VALID_I & LANE3_RX_VALID_I &
                                 LANE4_RX_VALID_I & LANE5_RX_VALID_I &
                                 LANE6_RX_VALID_I & LANE7_RX_VALID_I;
        // All lanes calibration complete
        assign all_lanes_not_calibrating = ENABLE_ERM_FIRST_LOCK ?
                                           (~LANE0_CALIBRATING_I & ~LANE1_CALIBRATING_I &
                                            ~LANE2_CALIBRATING_I & ~LANE3_CALIBRATING_I &
                                            ~LANE4_CALIBRATING_I & ~LANE5_CALIBRATING_I &
                                            ~LANE6_CALIBRATING_I & ~LANE7_CALIBRATING_I) :
                                           1'b1;
        // Any lane calibrating
        assign any_lane_calibrating = ENABLE_ERM_FIRST_LOCK ?
                                     (LANE0_CALIBRATING_I | LANE1_CALIBRATING_I |
                                      LANE2_CALIBRATING_I | LANE3_CALIBRATING_I |
                                      LANE4_CALIBRATING_I | LANE5_CALIBRATING_I |
                                      LANE6_CALIBRATING_I | LANE7_CALIBRATING_I) :
                                     1'b0;
    end
    else if (NUM_LANES == 4) begin : GEN_4_LANE_VALID_DETECT
        assign all_lanes_valid = LANE0_RX_VALID_I & LANE1_RX_VALID_I &
                                 LANE2_RX_VALID_I & LANE3_RX_VALID_I;
        assign all_lanes_not_calibrating = ENABLE_ERM_FIRST_LOCK ?
                                           (~LANE0_CALIBRATING_I & ~LANE1_CALIBRATING_I &
                                            ~LANE2_CALIBRATING_I & ~LANE3_CALIBRATING_I) :
                                           1'b1;
        assign any_lane_calibrating = ENABLE_ERM_FIRST_LOCK ?
                                     (LANE0_CALIBRATING_I | LANE1_CALIBRATING_I |
                                      LANE2_CALIBRATING_I | LANE3_CALIBRATING_I) :
                                     1'b0;
    end
    else if (NUM_LANES == 2) begin : GEN_2_LANE_VALID_DETECT
        assign all_lanes_valid = LANE0_RX_VALID_I & LANE1_RX_VALID_I;
        assign all_lanes_not_calibrating = ENABLE_ERM_FIRST_LOCK ?
                                           (~LANE0_CALIBRATING_I & ~LANE1_CALIBRATING_I) :
                                           1'b1;
        assign any_lane_calibrating = ENABLE_ERM_FIRST_LOCK ?
                                     (LANE0_CALIBRATING_I | LANE1_CALIBRATING_I) :
                                     1'b0;
    end
    else begin : GEN_1_LANE_VALID_DETECT
        assign all_lanes_valid = LANE0_RX_VALID_I;
        assign all_lanes_not_calibrating = ENABLE_ERM_FIRST_LOCK ?
                                           (~LANE0_CALIBRATING_I) :
                                           1'b1;
        assign any_lane_calibrating = ENABLE_ERM_FIRST_LOCK ?
                                     LANE0_CALIBRATING_I :
                                     1'b0;
    end
endgenerate

// Combine: Trigger when VALID=1 AND CALIBRATING=0
// If ERM disabled, CALIBRATING check returns 1'b1 (bypassed)
assign all_lanes_ready_for_trigger = all_lanes_valid & all_lanes_not_calibrating;

//-----------------------------------------------------------------------------
// Posedge Detection
//-----------------------------------------------------------------------------
assign all_lanes_ready_posedge = all_lanes_ready_for_trigger & ~all_lanes_ready_prev;

//-----------------------------------------------------------------------------
// Qualify First Lock Trigger with Enable Parameter and Latch
//-----------------------------------------------------------------------------
// first_lock_trigger = 1 only when:
//   1. ENABLE_ERM_FIRST_LOCK = 1 (ERM mode enabled)
//   2. all_lanes_ready_posedge = 1 (rising edge of READY & VALID)
//   3. first_lock_latch = 0 (not yet triggered)
//
// NOTE: Now requires BOTH RX_READY and RX_VALID to be HIGH
//       This ensures camera is ACTUALLY SENDING DATA before trigger
//-----------------------------------------------------------------------------
assign first_lock_trigger = ENABLE_ERM_FIRST_LOCK ?
                            (all_lanes_ready_posedge & ~first_lock_latch) :
                            1'b0;  // Disabled if not ERM mode

//-----------------------------------------------------------------------------
// First Lock Latch and Posedge Detection Logic
//-----------------------------------------------------------------------------
always @(posedge P_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        first_lock_latch <= 1'b0;
    end
    else begin
        // Set latch when entering s_ERR_DETECT_CNT for first time
        // This happens after proper sequence: READY → CAL=0 → VALID=1
        if (ENABLE_ERM_FIRST_LOCK && (fsm_state == s_ERR_DETECT_CNT) && !first_lock_latch) begin
            first_lock_latch <= 1'b1;  // Set once, stays set forever
        end
    end
end

// Removed: all_lanes_ready_prev (no longer needed)
// Removed: all_lanes_ready_posedge (no longer needed)
// Removed: first_lock_trigger wire (checked directly in FSM)

//=============================================================================
// UNIFIED FSM - Reset Control and Interrupt Generation
//=============================================================================
// Single FSM handles both disparity errors and first lock detection
//
// State Transitions:
//   s_IDLE → s_ERR_DETECT_CNT → (on trigger) → s_RST_CNT → s_REG_RST → s_IDLE
//
// Triggers:
//   - any_lane_disparity_error (from any active lane)
//   - first_lock_trigger (on first lock, one-time only)
//
// Reset Pulse:
//   RX_RST_CONTROL_O = 0 for 32 cycles in s_RST_CNT state
//   This resets downstream logic (PCS, CORERESET, SLVS_EC_RX)
//
// Interrupt:
//   RX_RST_CONTROL_INTERRUPT_O = 1 for 1 cycle in s_REG_RST state
//   Software uses this to:
//     - Release camera from GPIO reset (first lock)
//     - Reset camera via I2C (disparity error)
//=============================================================================

reg [2:0]              fsm_state;      // 3 bits for 7 states (0-6)
reg [RST_CNT_WIDTH-1:0] rst_counter;
reg                    calib_seen;   // Flag: calibration was observed
wire                   any_lane_calibrating; // Any lane currently calibrating

always @(posedge P_CLK_I or negedge RESET_N_I) begin
    if (!RESET_N_I) begin
        fsm_state                   <= s_IDLE;
        rst_counter                 <= {RST_CNT_WIDTH{1'b0}};
        RX_RST_CONTROL_O            <= 1'b0;
        RX_RST_CONTROL_INTERRUPT_O  <= 1'b0;
        calib_seen                  <= 1'b0;
    end
    else begin
        case (fsm_state)

            //------------------------------------------------------------------
            // s_IDLE: Initial state
            // Wait for any activity (CALIBRATING or RX_VALID)
            //------------------------------------------------------------------
            s_IDLE: begin
                rst_counter                 <= {RST_CNT_WIDTH{1'b0}};
                RX_RST_CONTROL_O            <= 1'b1;
                RX_RST_CONTROL_INTERRUPT_O  <= 1'b0;

                // Wait for any activity
                if (LANE0_RX_VALID_I || LANE1_RX_VALID_I ||
                    (NUM_LANES >= 3 && LANE2_RX_VALID_I) ||
                    (NUM_LANES >= 4 && LANE3_RX_VALID_I) ||
                    (NUM_LANES >= 5 && LANE4_RX_VALID_I) ||
                    (NUM_LANES >= 6 && LANE5_RX_VALID_I) ||
                    (NUM_LANES >= 7 && LANE6_RX_VALID_I) ||
                    (NUM_LANES >= 8 && LANE7_RX_VALID_I) ||
                    any_lane_calibrating) begin
                    // Activity detected
                    fsm_state <= ENABLE_ERM_FIRST_LOCK ? s_DETECT_SEQUENCE : s_ERR_DETECT_CNT;
                end
                else begin
                    fsm_state <= s_IDLE;
                end
            end

            //------------------------------------------------------------------
            // s_DETECT_SEQUENCE: Determine which comes first
            // Detects if CALIB or VALID came first, handles both cases
            //------------------------------------------------------------------
            s_DETECT_SEQUENCE: begin
                rst_counter                 <= {RST_CNT_WIDTH{1'b0}};
                RX_RST_CONTROL_O            <= 1'b1;
                RX_RST_CONTROL_INTERRUPT_O  <= 1'b0;

                if (any_lane_calibrating) begin
                    // Calibration detected (CALIB first or in progress)
                    calib_seen <= 1'b1;
                    fsm_state <= s_WAIT_CALIB_DONE;
                end
                else if (all_lanes_valid && all_lanes_not_calibrating) begin
                    // VALID already present and no calibration
                    // (VALID came first, or calibration already done)
                    fsm_state <= s_ERR_DETECT_CNT;
                end
                else begin
                    fsm_state <= s_DETECT_SEQUENCE;  // Keep detecting
                end
            end

            //------------------------------------------------------------------
            // s_WAIT_CALIB_DONE: Wait for calibration to complete
            // CALIBRATING detected HIGH, wait for it to go LOW
            //------------------------------------------------------------------
            s_WAIT_CALIB_DONE: begin
                rst_counter                 <= {RST_CNT_WIDTH{1'b0}};
                RX_RST_CONTROL_O            <= 1'b1;
                RX_RST_CONTROL_INTERRUPT_O  <= 1'b0;

                if (all_lanes_not_calibrating) begin
                    // Calibration complete, now wait for valid data
                    fsm_state <= s_WAIT_VALID_STABLE;
                end
                else begin
                    fsm_state <= s_WAIT_CALIB_DONE;
                end
            end

            //------------------------------------------------------------------
            // s_WAIT_VALID_STABLE: Wait for RX_VALID after calibration
            // Wait for all lanes to have stable valid data
            //------------------------------------------------------------------
            s_WAIT_VALID_STABLE: begin
                rst_counter                 <= {RST_CNT_WIDTH{1'b0}};
                RX_RST_CONTROL_O            <= 1'b1;
                RX_RST_CONTROL_INTERRUPT_O  <= 1'b0;

                if (all_lanes_valid) begin
                    // All lanes have valid data, proceed
                    fsm_state <= s_ERR_DETECT_CNT;
                end
                else begin
                    fsm_state <= s_WAIT_VALID_STABLE;
                end
            end

            //------------------------------------------------------------------
            // s_ERR_DETECT_CNT: Normal operation state
            // On FIRST entry (from s_WAIT_VALID): Trigger first lock if enabled
            // On subsequent cycles: Monitor disparity errors only
            // Triggers reset sequence if conditions met
            //------------------------------------------------------------------
            s_ERR_DETECT_CNT: begin
                rst_counter                 <= {RST_CNT_WIDTH{1'b0}};
                RX_RST_CONTROL_O            <= 1'b1;
                RX_RST_CONTROL_INTERRUPT_O  <= 1'b0;

                // Check for trigger conditions:
                // 1. Disparity error (ongoing monitoring)
                // 2. First lock (one-time: latch=0 means first time in this state)
                if (any_lane_disparity_error ||
                    (ENABLE_ERM_FIRST_LOCK && !first_lock_latch)) begin
                    // Set latch if first lock triggered
                    fsm_state <= s_RST_CNT;  // Start reset sequence
                end
                else begin
                    fsm_state <= s_ERR_DETECT_CNT;  // Stay in detection state
                end
            end

            //------------------------------------------------------------------
            // s_RST_CNT: Reset active state
            // Pulses RX_RST_CONTROL_O LOW for 32 clock cycles
            // This resets:
            //   - XCVR PCS (via AND2_0_Y → PCS_ARST_N)
            //   - CORERESET_PF_C3 (via AND2_0_Y → EXT_RST_N)
            //   - SLVS_EC_RX (via FABRIC_RESET_N)
            //------------------------------------------------------------------
            s_RST_CNT: begin
                RX_RST_CONTROL_INTERRUPT_O  <= 1'b0;

                if (rst_counter == (RST_CNT_CLKS - 1)) begin
                    // Reset duration complete
                    fsm_state        <= s_REG_RST;
                    rst_counter      <= rst_counter;  // Hold final count
                    RX_RST_CONTROL_O <= 1'b1;         // Release reset
                end
                else begin
                    // Continue reset, increment counter
                    fsm_state        <= s_RST_CNT;
                    rst_counter      <= rst_counter + 1'b1;
                    RX_RST_CONTROL_O <= 1'b0;         // Reset active
                end
            end

            //------------------------------------------------------------------
            // s_REG_RST: Reset complete, generate interrupt
            // Pulses interrupt HIGH for 1 cycle to notify software
            // Sets first_lock_latch if this was a first lock trigger
            // Then returns to s_IDLE to resume normal operation
            //------------------------------------------------------------------
            s_REG_RST: begin
                fsm_state                   <= s_IDLE;  // Return to idle
                rst_counter                 <= {RST_CNT_WIDTH{1'b0}};
                RX_RST_CONTROL_O            <= 1'b1;
                RX_RST_CONTROL_INTERRUPT_O  <= 1'b1;   // Interrupt pulse (1 cycle)
            end

            //------------------------------------------------------------------
            // Default: Safety state
            //------------------------------------------------------------------
            default: begin
                fsm_state                   <= s_IDLE;
                rst_counter                 <= {RST_CNT_WIDTH{1'b0}};
                RX_RST_CONTROL_O            <= 1'b1;
                RX_RST_CONTROL_INTERRUPT_O  <= 1'b0;
            end

        endcase
    end
end

//=============================================================================
// END OF MODULE
//=============================================================================

endmodule

//=============================================================================
// INSTANTIATION EXAMPLE - 2-Lane Configuration
//=============================================================================
/*

XCVR_DISPARITY_CORRECTION #(
    .NUM_LANES(2),                  // 2-lane mode
    .ENABLE_ERM_FIRST_LOCK(1)       // Enable first lock for ERM
) xcvr_disp_inst (
    // Clock and Reset
    .P_CLK_I                    ( P_CLK_I ),
    .RESET_N_I                  ( AND2_1_Y ),

    // Lane 0 - ACTIVE
    .LANE0_RX_CLK_I             ( PF_XCVR_ERM_C2_0_LANE0_RX_CLK_R ),
    .LANE0_RX_VALID_I           ( PF_XCVR_ERM_C2_0_LANE0_RX_VAL ),
    .LANE0_RX_READY_I           ( LANE0_RX_READY_net_0 ),
    .LANE0_DISPARITY_ERR_I      ( PF_XCVR_ERM_C2_0_LANE0_RX_DISPARITY_ERROR ),

    // Lane 1 - ACTIVE
    .LANE1_RX_CLK_I             ( PF_XCVR_ERM_C2_0_LANE1_RX_CLK_R ),
    .LANE1_RX_VALID_I           ( PF_XCVR_ERM_C2_0_LANE1_RX_VAL ),
    .LANE1_RX_READY_I           ( PF_XCVR_ERM_C2_0_LANE1_RX_READY ),
    .LANE1_DISPARITY_ERR_I      ( PF_XCVR_ERM_C2_0_LANE1_RX_DISPARITY_ERROR ),

    // Lanes 2-7 - UNUSED (Tie to safe defaults)
    .LANE2_RX_CLK_I             ( P_CLK_I ),
    .LANE2_RX_VALID_I           ( GND_net ),
    .LANE2_RX_READY_I           ( VCC_net ),
    .LANE2_DISPARITY_ERR_I      ( 4'b0000 ),

    .LANE3_RX_CLK_I             ( P_CLK_I ),
    .LANE3_RX_VALID_I           ( GND_net ),
    .LANE3_RX_READY_I           ( VCC_net ),
    .LANE3_DISPARITY_ERR_I      ( 4'b0000 ),

    .LANE4_RX_CLK_I             ( P_CLK_I ),
    .LANE4_RX_VALID_I           ( GND_net ),
    .LANE4_RX_READY_I           ( VCC_net ),
    .LANE4_DISPARITY_ERR_I      ( 4'b0000 ),

    .LANE5_RX_CLK_I             ( P_CLK_I ),
    .LANE5_RX_VALID_I           ( GND_net ),
    .LANE5_RX_READY_I           ( VCC_net ),
    .LANE5_DISPARITY_ERR_I      ( 4'b0000 ),

    .LANE6_RX_CLK_I             ( P_CLK_I ),
    .LANE6_RX_VALID_I           ( GND_net ),
    .LANE6_RX_READY_I           ( VCC_net ),
    .LANE6_DISPARITY_ERR_I      ( 4'b0000 ),

    .LANE7_RX_CLK_I             ( P_CLK_I ),
    .LANE7_RX_VALID_I           ( GND_net ),
    .LANE7_RX_READY_I           ( VCC_net ),
    .LANE7_DISPARITY_ERR_I      ( 4'b0000 ),

    // Outputs
    .RX_RST_CONTROL_O           ( disparity_reset_control ),
    .RX_RST_CONTROL_INTERRUPT_O ( disparity_interrupt )
);

*/

//=============================================================================
// END OF FILE
//=============================================================================
