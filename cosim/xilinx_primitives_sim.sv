`timescale 1ns/1ps

/* verilator lint_off DECLFILENAME */
/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */

/*
 * Simplified behavioral models for Xilinx primitives.
 *
 * These are intended for RTL/Verilator integration testing only:
 * - no FPGA timing
 * - no I/O electrical behavior
 * - no calibrated input delays
 * - sufficient for elaboration, register access and basic datapath tests
 */

module IBUF #(
    parameter string CAPACITANCE      = "DONT_CARE",
    parameter string IBUF_LOW_PWR     = "TRUE",
    parameter string IOSTANDARD       = "DEFAULT",
    parameter string IBUF_DELAY_VALUE = "0",
    parameter string IFD_DELAY_VALUE  = "AUTO"
) (
    output logic O,
    input  logic I
);

    always_comb O = I;

endmodule


module IBUFDS #(
    parameter string DIFF_TERM    = "FALSE",
    parameter string IBUF_LOW_PWR = "TRUE",
    parameter string IOSTANDARD   = "DEFAULT"
) (
    output logic O,
    input  logic I,
    input  logic IB
);

    always_comb O = I;

endmodule


module BUFG (
    output logic O,
    input  logic I
);

    always_comb O = I;

endmodule


module BUFIO (
    output logic O,
    input  logic I
);

    always_comb O = I;

endmodule


module BUFR #(
    parameter string BUFR_DIVIDE = "BYPASS",
    parameter string SIM_DEVICE  = "7SERIES"
) (
    output logic O,
    input  logic CE,
    input  logic CLR,
    input  logic I
);

    /*
     * Sufficient when LiteEth uses BUFR as a clock buffer.
     * Clock division is intentionally not modeled.
     */
    always_comb O = (!CLR && CE) ? I : 1'b0;

endmodule


module OBUF #(
    parameter integer DRIVE       = 12,
    parameter string  IOSTANDARD  = "DEFAULT",
    parameter string  SLEW        = "SLOW"
) (
    output logic O,
    input  logic I
);

    always_comb O = I;

endmodule


module IOBUF #(
    parameter integer DRIVE       = 12,
    parameter string  IBUF_LOW_PWR = "TRUE",
    parameter string  IOSTANDARD  = "DEFAULT",
    parameter string  SLEW        = "SLOW"
) (
    inout  wire  IO,
    output logic O,
    input  logic I,
    input  logic T
);

    assign IO = T ? 1'bz : I;
    always_comb O = IO;

endmodule


module ODDR #(
    parameter string DDR_CLK_EDGE = "OPPOSITE_EDGE",
    parameter logic  INIT         = 1'b0,
    parameter string SRTYPE       = "SYNC"
) (
    output logic Q,
    input  logic C,
    input  logic CE,
    input  logic D1,
    input  logic D2,
    input  logic R,
    input  logic S
);

    initial Q = INIT;

    /*
     * Simplified DDR output:
     *   rising edge  -> D1
     *   falling edge -> D2
     *
     * This is enough for the generated RGMII clock/data outputs when the
     * external Ethernet interface itself is not being functionally tested.
     */
    always @(posedge C or negedge C or posedge R or posedge S) begin
        if (R)
            Q <= 1'b0;
        else if (S)
            Q <= 1'b1;
        else if (CE) begin
            if (C)
                Q <= D1;
            else
                Q <= D2;
        end
    end

endmodule


module IDDR #(
    parameter string DDR_CLK_EDGE = "OPPOSITE_EDGE",
    parameter logic  INIT_Q1      = 1'b0,
    parameter logic  INIT_Q2      = 1'b0,
    parameter string SRTYPE       = "SYNC"
) (
    output logic Q1,
    output logic Q2,
    input  logic C,
    input  logic CE,
    input  logic D,
    input  logic R,
    input  logic S
);

    initial begin
        Q1 = INIT_Q1;
        Q2 = INIT_Q2;
    end

    /*
     * Simplified DDR input:
     *   Q1 samples on rising edge
     *   Q2 samples on falling edge
     */
    always @(posedge C or negedge C or posedge R or posedge S) begin
        if (R) begin
            Q1 <= 1'b0;
            Q2 <= 1'b0;
        end else if (S) begin
            Q1 <= 1'b1;
            Q2 <= 1'b1;
        end else if (CE) begin
            if (C)
                Q1 <= D;
            else
                Q2 <= D;
        end
    end

endmodule


module IDELAYE2 #(
    parameter string  CINVCTRL_SEL          = "FALSE",
    parameter string  DELAY_SRC              = "IDATAIN",
    parameter string  HIGH_PERFORMANCE_MODE  = "FALSE",
    parameter string  IDELAY_TYPE            = "FIXED",
    parameter integer IDELAY_VALUE           = 0,
    parameter string  PIPE_SEL               = "FALSE",
    parameter real    REFCLK_FREQUENCY       = 200.0,
    parameter string  SIGNAL_PATTERN         = "DATA"
) (
    output logic       DATAOUT,
    output logic [4:0] CNTVALUEOUT,

    input logic       C,
    input logic       CE,
    input logic       CINVCTRL,
    input logic [4:0] CNTVALUEIN,
    input logic       DATAIN,
    input logic       IDATAIN,
    input logic       INC,
    input logic       LD,
    input logic       LDPIPEEN,
    input logic       REGRST
);

    /*
     * Input delay is not modeled. Pass the selected source straight through.
     */
    always_comb begin
        if (DELAY_SRC == "DATAIN")
            DATAOUT = DATAIN;
        else
            DATAOUT = IDATAIN;

        CNTVALUEOUT = CNTVALUEIN;
    end

endmodule


module IDELAYCTRL (
    output logic RDY,
    input  logic REFCLK,
    input  logic RST
);

    /*
     * Report the delay controller ready as soon as reset is released.
     */
    always_comb RDY = !RST;

endmodule


/*
 * D flip-flop with clock enable and asynchronous clear.
 */
module FDCE #(
    parameter logic INIT            = 1'b0,
    parameter logic IS_CLR_INVERTED = 1'b0,
    parameter logic IS_C_INVERTED   = 1'b0,
    parameter logic IS_D_INVERTED   = 1'b0
) (
    output logic Q,
    input  logic C,
    input  logic CE,
    input  logic CLR,
    input  logic D
);

    wire c_i   = C   ^ IS_C_INVERTED;
    wire clr_i = CLR ^ IS_CLR_INVERTED;
    wire d_i   = D   ^ IS_D_INVERTED;

    initial Q = INIT;

    always @(posedge c_i or posedge clr_i) begin
        if (clr_i)
            Q <= 1'b0;
        else if (CE)
            Q <= d_i;
    end

endmodule


/*
 * D flip-flop with clock enable and asynchronous preset.
 */
module FDPE #(
    parameter logic INIT            = 1'b1,
    parameter logic IS_C_INVERTED   = 1'b0,
    parameter logic IS_D_INVERTED   = 1'b0,
    parameter logic IS_PRE_INVERTED = 1'b0
) (
    output logic Q,
    input  logic C,
    input  logic CE,
    input  logic D,
    input  logic PRE
);

    wire c_i   = C   ^ IS_C_INVERTED;
    wire pre_i = PRE ^ IS_PRE_INVERTED;
    wire d_i   = D   ^ IS_D_INVERTED;

    initial Q = INIT;

    always @(posedge c_i or posedge pre_i) begin
        if (pre_i)
            Q <= 1'b1;
        else if (CE)
            Q <= d_i;
    end

endmodule


/*
 * Simplified PLLE2_ADV model for Verilator integration tests.
 *
 * This does NOT implement:
 * - multiplication/division
 * - phase shifting
 * - duty-cycle control
 * - DRP
 * - jitter
 * - accurate lock timing
 *
 * All output clocks follow the selected input clock.
 */
module PLLE2_ADV #(
    parameter string  BANDWIDTH          = "OPTIMIZED",
    parameter integer CLKFBOUT_MULT      = 5,
    parameter real    CLKFBOUT_PHASE     = 0.0,
    parameter real    CLKIN1_PERIOD      = 0.0,
    parameter real    CLKIN2_PERIOD      = 0.0,

    parameter integer CLKOUT0_DIVIDE     = 1,
    parameter real    CLKOUT0_DUTY_CYCLE = 0.5,
    parameter real    CLKOUT0_PHASE      = 0.0,

    parameter integer CLKOUT1_DIVIDE     = 1,
    parameter real    CLKOUT1_DUTY_CYCLE = 0.5,
    parameter real    CLKOUT1_PHASE      = 0.0,

    parameter integer CLKOUT2_DIVIDE     = 1,
    parameter real    CLKOUT2_DUTY_CYCLE = 0.5,
    parameter real    CLKOUT2_PHASE      = 0.0,

    parameter integer CLKOUT3_DIVIDE     = 1,
    parameter real    CLKOUT3_DUTY_CYCLE = 0.5,
    parameter real    CLKOUT3_PHASE      = 0.0,

    parameter integer CLKOUT4_DIVIDE     = 1,
    parameter real    CLKOUT4_DUTY_CYCLE = 0.5,
    parameter real    CLKOUT4_PHASE      = 0.0,

    parameter integer CLKOUT5_DIVIDE     = 1,
    parameter real    CLKOUT5_DUTY_CYCLE = 0.5,
    parameter real    CLKOUT5_PHASE      = 0.0,

    parameter string  COMPENSATION       = "ZHOLD",
    parameter integer DIVCLK_DIVIDE      = 1,

    parameter logic IS_CLKINSEL_INVERTED = 1'b0,
    parameter logic IS_PWRDWN_INVERTED   = 1'b0,
    parameter logic IS_RST_INVERTED      = 1'b0,

    parameter real   REF_JITTER1         = 0.01,
    parameter real   REF_JITTER2         = 0.01,
    parameter string STARTUP_WAIT        = "FALSE"
) (
    output wire        CLKFBOUT,
    output wire        CLKOUT0,
    output wire        CLKOUT1,
    output wire        CLKOUT2,
    output wire        CLKOUT3,
    output wire        CLKOUT4,
    output wire        CLKOUT5,
    output wire [15:0] DO,
    output wire        DRDY,
    output logic       LOCKED,

    input wire         CLKFBIN,
    input wire         CLKIN1,
    input wire         CLKIN2,
    input wire         CLKINSEL,
    input wire [6:0]   DADDR,
    input wire         DCLK,
    input wire         DEN,
    input wire [15:0]  DI,
    input wire         DWE,
    input wire         PWRDWN,
    input wire         RST
);

    wire clkinsel_i = CLKINSEL ^ IS_CLKINSEL_INVERTED;
    wire clkin_i    = clkinsel_i ? CLKIN1 : CLKIN2;
    wire rst_i      = RST        ^ IS_RST_INVERTED;
    wire pwrdwn_i   = PWRDWN     ^ IS_PWRDWN_INVERTED;

    logic [3:0] lock_count = '0;

    /*
     * Model PLL lock after eight selected-input-clock cycles.
     */
    always @(posedge clkin_i or posedge rst_i or posedge pwrdwn_i) begin
        if (rst_i || pwrdwn_i) begin
            lock_count <= '0;
            LOCKED     <= 1'b0;
        end else if (!LOCKED) begin
            if (lock_count == 4'd7)
                LOCKED <= 1'b1;
            else
                lock_count <= lock_count + 1'b1;
        end
    end

    /*
     * Keep feedback alive. Gate generated outputs until the model locks.
     */
    assign CLKFBOUT = clkin_i;

    assign CLKOUT0 = LOCKED ? clkin_i : 1'b0;
    assign CLKOUT1 = LOCKED ? clkin_i : 1'b0;
    assign CLKOUT2 = LOCKED ? clkin_i : 1'b0;
    assign CLKOUT3 = LOCKED ? clkin_i : 1'b0;
    assign CLKOUT4 = LOCKED ? clkin_i : 1'b0;
    assign CLKOUT5 = LOCKED ? clkin_i : 1'b0;

    assign DO   = 16'b0;
    assign DRDY = 1'b0;

endmodule

/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on UNUSEDPARAM */
/* verilator lint_on DECLFILENAME */

