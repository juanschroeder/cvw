// // wb_stub.sv
// module wb_stub #(
//   parameter int AW = 30
// ) (
//   input  logic         clk,
//   input  logic         rst,       // active high
//   input  logic [AW-1:0] adr_i,    // word address
//   input  logic [31:0]   dat_i,
//   output logic [31:0]   dat_o,
//   input  logic [3:0]    sel_i,
//   input  logic         we_i,
//   input  logic         cyc_i,
//   input  logic         stb_i,
//   output logic         ack_o,
//   output logic         err_o
// );

//   logic [31:0] reg0;

//   wire req = cyc_i & stb_i;

//   always_ff @(posedge clk) begin
//     if (rst) begin
//       reg0  <= 32'h1234_5678;
//       ack_o <= 1'b0;
//     end else begin
//       ack_o <= req; // 1-cycle response
//       if (req && we_i && adr_i == '0) begin
//         if (sel_i[0]) reg0[7:0]   <= dat_i[7:0];
//         if (sel_i[1]) reg0[15:8]  <= dat_i[15:8];
//         if (sel_i[2]) reg0[23:16] <= dat_i[23:16];
//         if (sel_i[3]) reg0[31:24] <= dat_i[31:24];
//       end
//     end
//   end

//   always_comb begin
//     err_o = 1'b0;
//     dat_o = 32'h0;
//     if (adr_i == '0) dat_o = reg0;
//   end

// endmodule
module wb_stub #(
  parameter int AW = 30
) (
  input  logic          clk,
  input  logic          rst,       // active high
  input  logic [AW-1:0] adr_i,     // word address (absolute)
  input  logic [31:0]   dat_i,
  output logic [31:0]   dat_o,
  input  logic [3:0]    sel_i,
  input  logic          we_i,
  input  logic          cyc_i,
  input  logic          stb_i,
  output logic          ack_o,
  output logic          err_o
);

  logic [31:0] id_reg, scratch;
  wire  req = cyc_i & stb_i;

  // respond same cycle (no state machine needed for stub)
  assign ack_o = req;
  assign err_o = 1'b0;

  // decode only low bits => offset inside island for quick test
  wire [1:0] ofs = adr_i[1:0];  // 0 => base, 1 => base+4, etc.

  always_ff @(posedge clk) begin
    if (rst) begin
      id_reg  <= 32'h5742_5F49;  // "WB_I"
      scratch <= 32'h1234_5678;
    end else if (req && we_i && (ofs == 2'd1)) begin
      if (sel_i[0]) scratch[7:0]   <= dat_i[7:0];
      if (sel_i[1]) scratch[15:8]  <= dat_i[15:8];
      if (sel_i[2]) scratch[23:16] <= dat_i[23:16];
      if (sel_i[3]) scratch[31:24] <= dat_i[31:24];
    end
  end

  always_comb begin
    unique case (ofs)
      2'd0: dat_o = id_reg;
      2'd1: dat_o = scratch;
      default: dat_o = 32'hDEAD_BEEF;
    endcase
  end
endmodule
