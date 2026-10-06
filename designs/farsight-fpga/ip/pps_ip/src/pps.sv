/*
 * @file      pps.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      11/18/2025
 *
 * @brief     PPS Module implementation
 *
 * @section changelog
 * - 11/20/2025: Chase Whyte - Initial implementation
 *
 */

module pps # (
    parameter CLOCK_PER              = 20, // clock period in ns,
    parameter APB_DATA_WIDTH         = 32,
    parameter APB_ADDR_WIDTH         = 32
) (
    input  logic                       pps_in,
    output logic                       pps_out,
    input  logic                       extrn_pps_in,
    output logic                       pps_irq,
    output logic [31:0]                seconds,
    output logic [31:0]                nanoseconds,
    output logic                       en_local_pps,
    input  logic                       pclk,     // APB clock
    input  logic                       presetn,  // APB resetn
    input  logic                       penable,  // APB enable
    input  logic                       psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]  paddr,    // APB address bus
    input  logic                       pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]  pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]  prdata,   // APB read data
    output logic                       pready,   // APB ready signal
    output logic                       pslverr   // APB error signal
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam ADDR_TRIGGER_TIME_JAM      = 'h0;
localparam ADDR_LOAD_SECONDS          = 'h1;
localparam ADDR_PPS_RX_DELAY          = 'h2;
localparam ADDR_EN_LOCAL_PPS_SOURCE   = 'h3;
localparam ADDR_FREQUENCY_ERROR       = 'h4;
localparam ADDR_PHASE_ERROR           = 'h5;
localparam ADDR_SECONDS               = 'h6;
localparam ADDR_NANOSECONDS           = 'h7;
localparam ADDR_CLEAR_PPS_IRQ         = 'h8;

localparam NS_PER_SEC          = 32'd1_000_000_000;
localparam DEFAULT_PPS_PERIOD  = NS_PER_SEC/CLOCK_PER;
localparam MIN_CLOCK_RATE      = DEFAULT_PPS_PERIOD - (DEFAULT_PPS_PERIOD >> 3);
localparam MAX_CLOCK_RATE      = DEFAULT_PPS_PERIOD + (DEFAULT_PPS_PERIOD >> 3);
localparam NUM_SAMPLES_TO_SMOOTH_LOG2 = 3;

//------------------------------------------------------------------------------
// State definition
//------------------------------------------------------------------------------
typedef enum logic [1:0] {
    IDLE                             = 'd0,
    CALCULATE_SMOOTHED_PPS_IN_PERIOD = 'd1,
    CALCULATE_FREQUENCY_ERROR        = 'd2,
    CALCULATE_CLOCK_RATE             = 'd3
} pps_calc_state_enum;

pps_calc_state_enum pps_calc_state;
pps_calc_state_enum pps_calc_state_nxt;

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic [31:0] ticks;
logic [31:0] pps_in_cntr;
logic [2:0]  pps_in_sync;
logic        pps_in_posedge;
logic [31:0] load_seconds;
logic [31:0] pps_rx_delay;
logic [31:0] remainder_cntr;
logic [31:0] phase_error;
logic [31:0] frequency_error;
logic [31:0] clock_rate;
logic [31:0] smoothed_pps_in_period;
logic [31:0] ticks_sum;
logic [31:0] ticks_sum_nxt;
logic [31:0] intermediate_reg;
logic [31:0] adjusted_clock_rate;
logic        set_time;
logic [31:0] last_pps_in_period;
logic        div_start;
logic        div_valid;
logic [31:0] nanoseconds_per_tick;
logic [31:0] nanoseconds_per_tick_nxt;
logic [31:0] remainder_per_tick;
logic [31:0] remainder_per_tick_nxt;
logic        pps_irq_clear;
logic [2:0]  extrn_pps_in_sync;

//------------------------------------------------------------------------------
// PPS
//------------------------------------------------------------------------------
always_comb begin
    pps_in_posedge      = pps_in_sync[2:1] == 2'b01;
    adjusted_clock_rate = clock_rate + phase_error + frequency_error;
    ticks_sum_nxt       = intermediate_reg + last_pps_in_period;
end

always_ff @(posedge pclk) begin
    if(!presetn) begin
        smoothed_pps_in_period <= 'd0;
        clock_rate             <= DEFAULT_PPS_PERIOD;
        frequency_error        <= 'd0;
        phase_error            <= 'd0;
        ticks_sum              <= DEFAULT_PPS_PERIOD << NUM_SAMPLES_TO_SMOOTH_LOG2;
        smoothed_pps_in_period <= DEFAULT_PPS_PERIOD;
        pps_calc_state         <= IDLE;
        intermediate_reg       <= 'd0;
        last_pps_in_period     <= DEFAULT_PPS_PERIOD;

    end else begin

        case(pps_calc_state)

        //only register pps positive edges with a reasonable period, if period is too large
        //then we must have missed a PPS pulse, if too small then there was a glitch
            IDLE: begin
                if(pps_in_posedge &&
                    (pps_in_cntr < DEFAULT_PPS_PERIOD + (DEFAULT_PPS_PERIOD >> 1)) &&
                    (pps_in_cntr > DEFAULT_PPS_PERIOD - (DEFAULT_PPS_PERIOD >> 1))) begin

                    pps_calc_state     <= CALCULATE_SMOOTHED_PPS_IN_PERIOD;

                    last_pps_in_period <= pps_in_cntr + 'd1;
                    //phase error is measured from the closest expected PPS pulse
                    //phase error is calculated based on true PPS time which happened
                    //pps_rx_delay clock cycles before pps positive edge detection
                    //need to use signed arithmetic in case ticks < pps_recv_delay
                    if ($signed($signed(ticks) - $signed(pps_rx_delay)) <= $signed(clock_rate >> 1)) begin
                        phase_error   <=  ticks - pps_rx_delay;
                    end else begin
                        phase_error   <=  ticks - pps_rx_delay - clock_rate;
                    end

                    intermediate_reg  <= ticks_sum - (ticks_sum >> NUM_SAMPLES_TO_SMOOTH_LOG2);
                end
            end

            // 2^(LOG2_NUM_SAMPLES_TO_SMOOTH) moving average to filter out noise
            // on input 1PPS
            CALCULATE_SMOOTHED_PPS_IN_PERIOD: begin
                smoothed_pps_in_period <= ticks_sum_nxt >> NUM_SAMPLES_TO_SMOOTH_LOG2;
                ticks_sum              <= ticks_sum_nxt;
                pps_calc_state         <= CALCULATE_FREQUENCY_ERROR;
            end

            // frequency error is difference between smoothed input pps period
            // and internal pps period
            CALCULATE_FREQUENCY_ERROR: begin
                frequency_error <= smoothed_pps_in_period - clock_rate;
                pps_calc_state  <= CALCULATE_CLOCK_RATE;
            end

            CALCULATE_CLOCK_RATE: begin
                if(adjusted_clock_rate > MAX_CLOCK_RATE) begin
                    clock_rate <= MAX_CLOCK_RATE;
                end else if(adjusted_clock_rate < MIN_CLOCK_RATE) begin
                    clock_rate <= MIN_CLOCK_RATE;
                end else begin
                    clock_rate <= adjusted_clock_rate;
                end
                pps_calc_state <= IDLE;
            end

            default: begin
                pps_calc_state <= IDLE;
            end
        endcase
    end
end

//------------------------------------------------------------------------------
// APB
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        prdata               <= 'b0;
        pready               <= 'b0;
        pslverr              <= 'b0;
        seconds              <= 'd0;
        nanoseconds          <= 'd0;
        set_time             <= 'd0;
        load_seconds         <= 'd0;
        pps_in_sync          <= 'd0;
        pps_rx_delay <= 'd0;
        div_start            <= 'd0;
        nanoseconds_per_tick <= CLOCK_PER;
        remainder_per_tick   <= 'd0;
        remainder_cntr       <= 'd0;
        pps_in_cntr          <= 'd0;
        ticks                <= 'd0;
        en_local_pps         <= 'b0;
        pps_out              <= 'd0;
        pps_irq_clear        <= 'b0;
    end else begin

        pps_in_sync    <= {pps_in_sync[1:0], pps_in};
        pps_irq_clear  <= 'b0;

        if(pps_in_posedge && set_time) begin
            seconds            <= load_seconds;
            nanoseconds        <= pps_rx_delay * CLOCK_PER;
            set_time           <= 'b0;
            ticks              <= pps_rx_delay + 'd1;
            remainder_cntr     <= 'd0;
            pps_out            <= 'd1;
        end else if(ticks >= clock_rate - 'd1) begin
            pps_out            <= 'd1;
            ticks              <= 'd0;
            nanoseconds        <= 'd0;
            seconds            <= seconds + 'd1;
            remainder_cntr     <= 'd0;

        end else begin
            if(ticks >= (clock_rate >> 1)) begin
                pps_out <= 'd0;
            end
            ticks <= ticks + 'd1;

            if(remainder_cntr + remainder_per_tick >= clock_rate) begin
                remainder_cntr <= remainder_cntr + remainder_per_tick - clock_rate;
                nanoseconds    <= nanoseconds + nanoseconds_per_tick + 'd1;
            end else begin
                remainder_cntr <= remainder_cntr + remainder_per_tick;
                nanoseconds    <= nanoseconds + nanoseconds_per_tick;
            end
        end

        if(pps_in_posedge) begin
            pps_in_cntr <= 'd0;
        end else begin
            pps_in_cntr <= pps_in_cntr + 'd1;
        end

        div_start <= (pps_calc_state == CALCULATE_CLOCK_RATE);

        if(div_valid) begin
            nanoseconds_per_tick <= nanoseconds_per_tick_nxt;
            remainder_per_tick   <= remainder_per_tick_nxt;
        end

        // APB Write operation
        if(psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata <= 'b0;
            pready <= 'b1;  // Indicate done

            case(paddr[5:2])

                ADDR_TRIGGER_TIME_JAM: begin
                    pslverr              <= 'b0;
                    set_time             <= 'b1;
                end

                ADDR_LOAD_SECONDS: begin
                    pslverr             <= 'b0;
                    load_seconds        <= pwdata;
                end

                ADDR_PPS_RX_DELAY: begin  // Read only
                    pslverr              <= 'b0;
                    pps_rx_delay <= pwdata;
                end

                ADDR_EN_LOCAL_PPS_SOURCE: begin
                    pslverr             <= 'b0;
                    en_local_pps        <= pwdata[0:0];
                end

                ADDR_CLEAR_PPS_IRQ: begin
                    pslverr             <= 'b0;
                    pps_irq_clear       <= pwdata[0:0];
                end

                default: begin
                    pslverr            <= 'b0;
                end
            endcase

        // APB READ operation
        end else if(psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready             <= 'b1; // Indicate done

            case(paddr[5:2])

                ADDR_LOAD_SECONDS: begin
                    prdata     <= load_seconds;
                    pslverr    <= 'b0;
                end

                ADDR_PPS_RX_DELAY: begin
                    prdata     <= pps_rx_delay;
                    pslverr    <= 'b0;
                end

                ADDR_EN_LOCAL_PPS_SOURCE: begin
                    prdata     <= {31'b0, en_local_pps};
                    pslverr    <= 'b0;
                end

                ADDR_FREQUENCY_ERROR: begin
                    prdata     <= frequency_error;
                    pslverr    <= 'b0;
                end

                ADDR_PHASE_ERROR: begin
                    prdata     <=  phase_error;
                    pslverr    <= 'b0;
                end

                ADDR_SECONDS: begin
                    prdata     <= seconds;
                    pslverr    <= 'b0;
                end

                ADDR_NANOSECONDS: begin
                    prdata     <=  nanoseconds;
                    pslverr    <= 'b0;
                end

                ADDR_CLEAR_PPS_IRQ: begin
                    prdata     <= {31'b0, pps_irq_clear};
                    pslverr    <= 'b0;
                end

                default: begin
                    pslverr    <= 'b0;
                    prdata     <= 'hDEADBEEF;
                end

            endcase

        end else begin
            pready             <= 'b0;
            prdata             <= 'b0;
            pslverr            <= 'b0;
        end
    end
end

//------------------------------------------------------------------------------
// PPS interrupt generation
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        extrn_pps_in_sync <= 3'b0;
        pps_irq           <= 1'b0;
    end else begin
        extrn_pps_in_sync <= {extrn_pps_in_sync[1:0], extrn_pps_in};

        if(extrn_pps_in_sync[2:1] == 2'b01) begin
            pps_irq <= 1'b1;
        end else if(pps_irq_clear) begin
            pps_irq <= 1'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Divider module
//------------------------------------------------------------------------------
divider_with_remainder nanoseconds_per_tick_i (
   .clk         (pclk                    ),
   .rst_n       (presetn                 ),
   .start       (div_start               ),
   .dividend    (NS_PER_SEC              ),
   .divisor     (clock_rate              ),
   .quotient    (nanoseconds_per_tick_nxt),
   .remainder   (remainder_per_tick_nxt  ),
   .valid       (div_valid               ),
   .ready       ( /* NC */               ),
   .div_by_zero ( /* NC */               )
);

endmodule