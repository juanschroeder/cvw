`include "uart_defines.v"

module wb_uart16550 #(
  parameter int AW = 30,
  parameter logic [31:0] UART_BASE_B = 32'h1100_2000
)(
  input  logic          clk,
  input  logic          rst,        // active high

  // WB slave in (absolute word address)
  input  logic [AW-1:0] adr_i,
  input  logic [31:0]   dat_i,
  output logic [31:0]   dat_o,
  input  logic [3:0]    sel_i,      // ignored (we derive SEL for core)
  input  logic          we_i,
  input  logic          cyc_i,
  input  logic          stb_i,
  output logic          ack_o,
  output logic          err_o,

  output logic          irq_o,
  input  logic          rx_i,
  output logic          tx_o
);

  localparam logic [AW-1:0] UART_BASE_W = UART_BASE_B[AW+1:2];

  // In your current map: base + 4*reg  => word_off == reg_index (byte register number)
  wire [AW-1:0] reg_index_w = adr_i - UART_BASE_W;

  wire [1:0] lane      = reg_index_w[1:0];
  wire [2:0] core_word = reg_index_w[4:2];          // which 32-bit word inside the core

  // Core expects 5-bit address in 32-bit mode; zero-extend.
  wire [4:0] core_adr  = {2'b00, core_word};

  // One-hot lane select (little endian, since you define LITLE_ENDIAN in uart_defines.v)
  wire [3:0] core_sel  = 4'b0001 << lane;

  // Write: take low byte and place it into selected lane
  wire [7:0] wbyte = dat_i[7:0];
  wire [31:0] core_dat_i = (lane == 2'd0) ? {24'h0, wbyte} :
                           (lane == 2'd1) ? {16'h0, wbyte, 8'h0} :
                           (lane == 2'd2) ? {8'h0,  wbyte, 16'h0} :
                                            {wbyte, 24'h0};

  // Read: extract selected lane from core_dat_o and present in low byte
  wire [31:0] core_dat_o;
  wire [7:0]  rbyte = (lane == 2'd0) ? core_dat_o[7:0]   :
                      (lane == 2'd1) ? core_dat_o[15:8]  :
                      (lane == 2'd2) ? core_dat_o[23:16] :
                                       core_dat_o[31:24];

  always_comb dat_o = {24'h0, rbyte};

  assign err_o = 1'b0;

  uart_top u_uart (
    .wb_clk_i (clk),
    .wb_rst_i (rst),

    .wb_adr_i (core_adr),
    .wb_dat_i (core_dat_i),
    .wb_dat_o (core_dat_o),
    .wb_sel_i (core_sel),

    .wb_we_i  (we_i),
    .wb_cyc_i (cyc_i),
    .wb_stb_i (stb_i),
    .wb_ack_o (ack_o),

    .int_o    (irq_o),

    .stx_pad_o(tx_o),
    .srx_pad_i(rx_i),

    .rts_pad_o(),
    .dtr_pad_o(),
    .cts_pad_i(1'b1),
    .dsr_pad_i(1'b1),
    .ri_pad_i (1'b1),
    .dcd_pad_i(1'b1)
  );

endmodule
