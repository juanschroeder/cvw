///////////////////////////////////////////
// ram1p1rwbe_xc7
//
// OpenXC7/Yosys-slang replacement for Wally's data RAM preload path.
// yosys-slang is currently run with --ignore-initial, so the normal
// $readmemh("data.mem") preload does not reliably survive synthesis.
// The Makefile generates dataram_init_xc7.svh from fpga/src/data.mem.
///////////////////////////////////////////

module ram1p1rwbe import cvw::*; #(parameter USE_SRAM=0, DEPTH=64, WIDTH=44, PRELOAD_ENABLED=0) (
  input  logic                     clk,
  input  logic                     ce,
  input  logic [$clog2(DEPTH)-1:0] addr,
  input  logic [WIDTH-1:0]         din,
  input  logic                     we,
  input  logic [(WIDTH-1)/8:0]     bwe,
  output logic [WIDTH-1:0]         dout
);

  if ((USE_SRAM == 1) & (WIDTH == 128) & (DEPTH == 64)) begin
    genvar index;
    logic [WIDTH-1:0] BitWriteMask;
    for (index = 0; index < WIDTH; index++)
      assign BitWriteMask[index] = bwe[index/8];
    ram1p1rwbe_64x128 sram1A (.CLK(clk), .CEB(~ce), .WEB(~we),
      .A(addr), .D(din), .BWEB(~BitWriteMask), .Q(dout));

  end else if ((USE_SRAM == 1) & (WIDTH == 44) & (DEPTH == 64)) begin
    genvar index;
    logic [WIDTH-1:0] BitWriteMask;
    for (index = 0; index < WIDTH; index++)
      assign BitWriteMask[index] = bwe[index/8];
    ram1p1rwbe_64x44 sram1B (.CLK(clk), .CEB(~ce), .WEB(~we),
      .A(addr), .D(din), .BWEB(~BitWriteMask), .Q(dout));

  end else if ((USE_SRAM == 1) & (WIDTH == 22) & (DEPTH == 64)) begin
    genvar index;
    logic [WIDTH-1:0] BitWriteMask;
    for (index = 0; index < WIDTH; index++)
      assign BitWriteMask[index] = bwe[index/8];
    ram1p1rwbe_64x22 sram1B (.CLK(clk), .CEB(~ce), .WEB(~we),
      .A(addr), .D(din), .BWEB(~BitWriteMask), .Q(dout));

  end else if (PRELOAD_ENABLED && WIDTH == 64) begin : ram
    logic [WIDTH-1:0] RAM [0:DEPTH-1] = '{
      `include "dataram_init_xc7.svh"
      default: '0
    };

    logic [$clog2(DEPTH)-1:0] addrd;
    flopen #($clog2(DEPTH)) adrreg(clk, ce, addr, addrd);
    assign dout = RAM[addrd];

    integer i;
    always @(posedge clk)
      if (ce & we)
        for (i = 0; i < WIDTH/8; i++)
          if (bwe[i]) RAM[addr][i*8 +: 8] <= din[i*8 +: 8];

  end else begin : ram
    logic [WIDTH-1:0] RAM [0:DEPTH-1];

    logic [$clog2(DEPTH)-1:0] addrd;
    flopen #($clog2(DEPTH)) adrreg(clk, ce, addr, addrd);
    assign dout = RAM[addrd];

    if (WIDTH >= 8) begin
      integer i;
      always @(posedge clk)
        if (ce & we)
          for (i = 0; i < WIDTH/8; i++)
            if (bwe[i]) RAM[addr][i*8 +: 8] <= din[i*8 +: 8];
    end

    if (WIDTH%8 != 0)
      always @(posedge clk)
        if (ce & we & bwe[WIDTH/8])
          RAM[addr][WIDTH-1:WIDTH-WIDTH%8] <= din[WIDTH-1:WIDTH-WIDTH%8];
  end

endmodule
