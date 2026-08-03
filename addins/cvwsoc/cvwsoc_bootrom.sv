module cvwsoc_bootrom import cvw::*; #(parameter cvw_t P) (
  input  logic                 HCLK,
  input  logic                 HRESETn,
  input  logic                 HSEL,
  input  logic [P.PA_BITS-1:0] HADDR,
  input  logic                 HREADY,
  input  logic [1:0]           HTRANS,
  output logic [P.AHBW-1:0]    HRDATA,
  output logic                 HRESP,
  output logic                 HREADYOUT
);

  if (P.BOOTROM_SUPPORTED) begin : romgen
    rom_ahb #(.P(P), .RANGE(P.BOOTROM_RANGE), .PRELOAD(P.BOOTROM_PRELOAD))
    bootrom (
      .HCLK, .HRESETn, .HSELRom(HSEL), .HADDR, .HREADY, .HTRANS,
      .HREADRom(HRDATA), .HRESPRom(HRESP), .HREADYRom(HREADYOUT)
    );
  end else begin : no_rom
    assign {HRDATA, HRESP, HREADYOUT} = '0;
  end
endmodule
