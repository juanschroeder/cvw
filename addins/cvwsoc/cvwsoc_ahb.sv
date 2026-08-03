`include "axi/typedef.svh"

// AXI target for the AHB peripherals. The downstream adapter and AHB
// system are strictly single transfer at a time.
module cvwsoc_ahb import cvw::*; #(
    parameter cvw_t P,
    parameter int unsigned AXI_ID_W = 2,
    parameter type axi_req_t = logic,
    parameter type axi_resp_t = logic
  ) (
    input logic clk_i, rst_ni,
    input axi_req_t axi_req_i,
    output axi_resp_t axi_resp_o,
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
    input logic AXI_DMAIntr, AXI_USBIntr, AXI_EthIntr, AXI_DummyIntr, AXI_SDHCIIntr
  );

  localparam int unsigned ADDR_W = 32;
  localparam int unsigned DATA_W = P.AHBW;
  typedef logic [ADDR_W-1:0] addr_t;

  // Keep the AXI-Lite datapath as wide as the source AXI datapath.  PULP's
  // axi_to_axi_lite splits bursts but does not perform data-width conversion.
  typedef logic [DATA_W-1:0] axil_data_t;
  typedef logic [DATA_W/8-1:0] axil_strb_t;
  `AXI_LITE_TYPEDEF_ALL(ahb_axil, addr_t, axil_data_t, axil_strb_t)
  ahb_axil_req_t axil_req;
  ahb_axil_resp_t axil_resp;

  logic [ADDR_W-1:0] HADDR;
  logic [DATA_W-1:0] HWDATA, HRDATA;
  logic [DATA_W/8-1:0] HWSTRB;
  logic HWRITE, HREADY, HRESP;
  logic [2:0] HSIZE, HBURST;
  logic [3:0] HPROT;
  logic [1:0] HTRANS;
  logic HMASTLOCK;
  logic [2:0] axil_awsize, axil_arsize;
  logic [P.PA_BITS-1:0] system_haddr;
  assign system_haddr = {{(P.PA_BITS-ADDR_W){1'b0}}, HADDR};

  // Keep PULP's burst splitter, and retain AXI SIZE on local wires for the
  // AXI-Lite-to-AHB bridge.  SIZE is not part of the AXI-Lite protocol.
  axi_to_axi_lite_with_size #(
    .AxiAddrWidth(ADDR_W), .AxiDataWidth(DATA_W), .AxiIdWidth(AXI_ID_W),
    .AxiUserWidth(1), .AxiMaxWriteTxns(1), .AxiMaxReadTxns(1),
    .full_req_t(axi_req_t), .full_resp_t(axi_resp_t),
    .lite_req_t(ahb_axil_req_t), .lite_resp_t(ahb_axil_resp_t)
  ) i_axi_to_axi_lite (
    .clk_i, .rst_ni, .test_i(1'b0),
    .slv_req_i(axi_req_i), .slv_resp_o(axi_resp_o),
    .mst_req_o(axil_req), .mst_resp_i(axil_resp),
    .mst_awsize_o(axil_awsize), .mst_arsize_o(axil_arsize)
  );

  axi_lite_to_ahb_with_size #(
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .AHB_DATA_W(DATA_W),
    .axi_lite_req_t(ahb_axil_req_t), .axi_lite_resp_t(ahb_axil_resp_t)
  ) i_axil_to_ahb (
    .clk_i, .rst_ni, .axi_req_i(axil_req), .axi_resp_o(axil_resp), .awsize_i(axil_awsize), .arsize_i(axil_arsize),
    .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT, .HTRANS, .HMASTLOCK,
    .HRDATA, .HREADY, .HRESP);

  // cvwsoc_system with AHB peripherals
  cvwsoc_system #(P) system (
    .HCLK(clk_i), .HRESETn(rst_ni), .HADDR(system_haddr), .HWDATA, .HWSTRB,
    .HWRITE, .HSIZE, .HBURST, .HPROT, .HTRANS, .HMASTLOCK,
    .HRDATA, .HREADY, .HRESP,

    .GPIOIN, .GPIOOUT, .GPIOEN,
    .UARTSin, .UARTSout,
    .SPIIn, .SPIOut, .SPICS, .SPICLK,
    .SDCIn, .SDCCmd, .SDCCS, .SDCCLK,
    // PLIC outputs
    .MExtInt,
    .SExtInt,
    // PLIC inputs
    .WBUartIntr,
    .WBEthIntr,
    .AXI_DMAIntr,
    .AXI_USBIntr,
    .AXI_EthIntr,
    .AXI_DummyIntr,
    .AXI_SDHCIIntr );
endmodule
