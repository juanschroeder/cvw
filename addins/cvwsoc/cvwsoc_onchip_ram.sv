module cvwsoc_onchip_ram import cvw::*; #(parameter cvw_t P) (
  input  logic                 HCLK,
  input  logic                 HRESETn,
  input  logic                 HSEL,
  input  logic [P.PA_BITS-1:0] HADDR,
  input  logic                 HWRITE,
  input  logic                 HREADY,
  input  logic [1:0]           HTRANS,
  input  logic [P.AHBW-1:0]    HWDATA,
  input  logic [P.AHBW/8-1:0]  HWSTRB,
  output logic [P.AHBW-1:0]    HRDATA,
  output logic                 HRESP,
  output logic                 HREADYOUT
);

  if (P.UNCORE_RAM_SUPPORTED) begin : ramgen
    ram_ahb #(.P(P), .RANGE(P.UNCORE_RAM_RANGE), .PRELOAD(P.UNCORE_RAM_PRELOAD))
    ram (
      .HCLK, .HRESETn, .HSELRam(HSEL), .HADDR, .HWRITE, .HREADY,
      .HTRANS, .HWDATA, .HWSTRB,
      .HREADRam(HRDATA), .HRESPRam(HRESP), .HREADYRam(HREADYOUT)
    );
  end else begin : no_ram
    assign {HRDATA, HRESP, HREADYOUT} = '0;
  end
endmodule
