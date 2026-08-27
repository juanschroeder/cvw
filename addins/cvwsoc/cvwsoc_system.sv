// Retained AHB peripheral assembly.  CLINT and Wishbone are not part of this
// island: they live in cvwsoc_cpu and cvwsoc_wishbone respectively.
module cvwsoc_system import cvw::*; #(parameter cvw_t P) (
  input logic HCLK, HRESETn,
  input logic [P.PA_BITS-1:0] HADDR,
  input logic [P.AHBW-1:0] HWDATA,
  input logic [P.AHBW/8-1:0] HWSTRB,
  input logic HWRITE,
  input logic [2:0] HSIZE, HBURST,
  input logic [3:0] HPROT,
  input logic [1:0] HTRANS,
  input logic HMASTLOCK,
  output logic [P.AHBW-1:0] HRDATA,
  output logic HREADY, HRESP,
  output logic MExtInt, SExtInt,
  input logic [31:0] GPIOIN,
  output logic [31:0] GPIOOUT, GPIOEN,
  input logic UARTSin,
  output logic UARTSout,
  input logic SPIIn,
  output logic SPIOut,
  output logic [3:0] SPICS,
  output logic SPICLK,
  input logic SDCIn,
  output logic SDCCmd,
  output logic [3:0] SDCCS,
  output logic SDCCLK,
  input logic WBUartIntr, WBEthIntr,
  input logic AXI_DMAIntr, AXI_USBIntr, AXI_EthIntr, AXI_DummyIntr,
  input logic AXI_SDHCIIntr
);
  logic [7:0] hsel, hsel_q;
  logic [P.AHBW-1:0] ram_rdata, boot_rdata, apb_rdata;
  logic ram_resp, ram_ready, boot_resp, boot_ready, apb_resp, apb_ready;
  logic apb_sel, apb_sel_q;

  cvwsoc_adrdecs #(P) adrdecs (
    .PhysicalAddress(HADDR), .AccessRX(1'b1), .AccessRW(1'b1),
    .AccessRWXC(1'b1), .Size(HSIZE[1:0]), .SelRegions(hsel));

  cvwsoc_onchip_ram #(P) ram (
    .HCLK, .HRESETn, .HSEL(hsel[1]), .HADDR, .HWRITE, .HREADY, .HTRANS,
    .HWDATA, .HWSTRB, .HRDATA(ram_rdata), .HRESP(ram_resp),
    .HREADYOUT(ram_ready) );

  cvwsoc_bootrom #(P)
  bootrom (
    .HCLK, .HRESETn, .HSEL(hsel[0]), .HADDR, .HREADY, .HTRANS,
    .HRDATA(boot_rdata), .HRESP(boot_resp), .HREADYOUT(boot_ready) );

  assign apb_sel = |hsel[6:2];
  cvwsoc_apb #(P) apb (

    .HCLK, .HRESETn,
    .HSEL({hsel[5], hsel[6], hsel[3], hsel[4], hsel[2]}),
    .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HTRANS, .HREADY,
    .HRDATA(apb_rdata), .HRESP(apb_resp), .HREADYOUT(apb_ready),

    .GPIOIN, .GPIOOUT, .GPIOEN, .UARTSin, .UARTSout,
    .SPIIn, .SPIOut, .SPICS, .SPICLK, .SDCIn, .SDCCmd, .SDCCS, .SDCCLK,
    
    .MExtInt,
    .SExtInt,
    .WBUartIntr,
    .WBEthIntr,
    .AXI_DMAIntr,
    .AXI_USBIntr,
    .AXI_EthIntr,
    .AXI_DummyIntr,
    .AXI_SDHCIIntr);

  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      hsel_q <= 8'b1000_0000;
      apb_sel_q <= 1'b0;
    end else if (HREADY) begin
      hsel_q <= hsel;
      apb_sel_q <= apb_sel;
    end
  end

  always_comb begin
    HRDATA = '0;
    HRESP = 1'b0;
    HREADY = 1'b1;
    if (hsel_q[0]) begin
      HRDATA = boot_rdata; HRESP = boot_resp; HREADY = boot_ready;
    end else if (hsel_q[1]) begin
      HRDATA = ram_rdata; HRESP = ram_resp; HREADY = ram_ready;
    end else if (apb_sel_q) begin
      HRDATA = apb_rdata; HRESP = apb_resp; HREADY = apb_ready;
    end
  end

  // Accepted even though the slaves do not consume them.
  logic unused;
  assign unused = ^{HBURST, HPROT, HMASTLOCK};
endmodule
