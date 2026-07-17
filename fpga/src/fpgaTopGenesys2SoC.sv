///////////////////////////////////////////
// fpgaTopGenesys2.sv
//
// Written: jcschroeder@gmail.com February 25, 2025
// Modified:
//
// Purpose: This is a top level for the fpga's implementation of wally.
//          Instantiates wallysoc, ddr3, abh lite to axi converters, pll, etc
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2025 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

`include "config.vh"
`include "axi/typedef.svh"
`include "axi_stream/typedef.svh"

import cvw::*;
import cvwsoc_pkg::*;
`include "parameter-defs.vh"

module fpgaTop #(parameter logic RVVI_SYNTH_SUPPORTED = 0)
  (input logic         default_200mhz_clk_p,
   input logic         default_200mhz_clk_n,
   input logic         resetn,
   input logic         south_reset,

   // GPIO signals
   input logic [3:0]   GPI,
   output logic [4:0]  GPO,

   // UART Signals
   input logic         UARTSin,
   output logic         UARTSout,

   // SDC Signals connecting to an SPI peripheral
   input logic         SDCIn,
   output logic         SDCCLK,
   output logic         SDCCmd,
   output logic         SDCCS,
   input logic         SDCCD,
   input logic         SDCWP,
`ifdef RVVI_SYNTH_SUPPORTED
 /*
     * Ethernet: 100BASE-T MII
     */
   //output logic         phy_ref_clk, // *** add back in when we add rvvi
   input logic         phy_rx_clk,
   input logic [3:0]   phy_rxd,
   input logic         phy_rxctl,
   input logic         phy_tx_clk,
   output logic [3:0]  phy_txd,
   output logic         phy_tx_en,
   //output logic         phy_reset_n,
`endif

   inout logic [31:0]  ddr3_dq,
   inout logic [3:0]   ddr3_dqs_n,
   inout logic [3:0]   ddr3_dqs_p,
   output logic [14:0] ddr3_addr,
   output logic [2:0]  ddr3_ba,
   output logic         ddr3_ras_n,
   output logic         ddr3_cas_n,
   output logic         ddr3_we_n,
   output logic         ddr3_reset_n,
   output logic [0:0]  ddr3_ck_p,
   output logic [0:0]  ddr3_ck_n,
   output logic [0:0]  ddr3_cke,
   output logic [0:0]  ddr3_cs_n,
   output logic [3:0]  ddr3_dm,
   output logic [0:0]  ddr3_odt

    // WB UART
    , input logic WB_UART_RX
    , output logic WB_UART_TX
`ifdef P_WISHBONE_ETH_SUPPORTED
    // WB Ethernet
    , output logic WB_RMII_REF_CLK,
    input logic WB_RMII_CRS_DV,
    input  logic [1:0]  WB_RMII_RX_DATA,
    output logic [1:0]  WB_RMII_TX_DATA,
    output logic        WB_RMII_TX_EN,
    output logic        WB_RMII_MDC,
    inout  wire         WB_RMII_MDIO,
    output logic        WB_RMII_RST_N,
    input logic        WB_RMII_PHY_IRQ
`endif
    , input  logic          rgmii_clocks_rx,
    output logic          rgmii_clocks_tx,
    input  logic          rgmii_int_n,
    output logic          rgmii_mdc,
    inout  logic          rgmii_mdio,
    output logic          rgmii_rst_n,
    input  logic          rgmii_rx_ctl,
    input  logic    [3:0] rgmii_rx_data,
    output logic          rgmii_tx_ctl,
    output logic    [3:0] rgmii_tx_data

    // VGA signals
    , output logic        vga_hsync,
    output logic        vga_vsync,
    output logic [4:0]  vga_r_5,
    output logic [5:0]  vga_g_6,
    output logic [4:0]  vga_b_5
    // USB OHCI (2 ports) D+/D- pins
    , inout wire        usb0_dp
    , inout wire        usb0_dm
    , inout wire        usb1_dp
    , inout wire        usb1_dm
    // SDHCI card pins
    , output logic      SD_CLK
    , input  logic      SD_CD_N
    , inout  wire       SD_CMD
    , inout  wire [3:0] SD_DAT
    // Pmod I2S2 TX pins
    , output logic      i2s_tx_mclk
    , output logic      i2s_tx_lrck
    , output logic      i2s_tx_sclk
    , output logic      i2s_tx_sdout
   );

  localparam int unsigned STRB_W = P.AHBW/8;

  logic CPUCLK;
  logic bus_struct_reset;
  logic peripheral_reset;
  logic peripheral_aresetn;
  logic interconnect_aresetn;
  logic mb_reset;
  logic [3:0] cpu_axi_irq;
  logic clk167, clk200, audio_clk, clk48MHz_raw, mmcm1_locked;
  logic rst_req, resetn_comb;

  // AHB signals between Wally and the bridge.
  logic HCLKOpen, HRESETnOpen;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] HRDATAEXT;
  (* mark_debug = "true" *) logic HREADYEXT, HRESPEXT;
  logic HSELEXT;
  (* mark_debug = "true" *) logic [55:0] HADDR;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] HWDATA;
  (* mark_debug = "true" *) logic [STRB_W-1:0] HWSTRB;
  (* mark_debug = "true" *) logic HWRITE;
  (* mark_debug = "true" *) logic [2:0] HSIZE, HBURST;
  (* mark_debug = "true" *) logic [1:0] HTRANS;
  (* mark_debug = "true" *) logic HREADY;
  (* mark_debug = "true" *) logic [3:0] HPROT;
  (* mark_debug = "true" *) logic HMASTLOCK;

  logic [31:0] GPIOIN, GPIOOUT, GPIOEN;
  logic [3:0] SDCCSin;
  (* mark_debug = "true" *) logic RVVIStall;

  // Flat AXI interface from the AHB-to-AXI bridge into cvwsoc_axi.
  (* mark_debug = "true" *) logic [3:0] m_axi_awid;
  (* mark_debug = "true" *) logic [7:0] m_axi_awlen;
  (* mark_debug = "true" *) logic [2:0] m_axi_awsize;
  (* mark_debug = "true" *) logic [1:0] m_axi_awburst;
  (* mark_debug = "true" *) logic [3:0] m_axi_awcache;
  (* mark_debug = "true" *) logic [31:0] m_axi_awaddr;
  (* mark_debug = "true" *) logic [2:0] m_axi_awprot;
  (* mark_debug = "true" *) logic m_axi_awvalid, m_axi_awready, m_axi_awlock;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] m_axi_wdata;
  (* mark_debug = "true" *) logic [STRB_W-1:0] m_axi_wstrb;
  (* mark_debug = "true" *) logic m_axi_wlast, m_axi_wvalid, m_axi_wready;
  (* mark_debug = "true" *) logic [3:0] m_axi_bid;
  (* mark_debug = "true" *) logic [1:0] m_axi_bresp;
  (* mark_debug = "true" *) logic m_axi_bvalid, m_axi_bready;
  (* mark_debug = "true" *) logic [3:0] m_axi_arid;
  (* mark_debug = "true" *) logic [7:0] m_axi_arlen;
  (* mark_debug = "true" *) logic [2:0] m_axi_arsize;
  (* mark_debug = "true" *) logic [1:0] m_axi_arburst;
  (* mark_debug = "true" *) logic [2:0] m_axi_arprot;
  (* mark_debug = "true" *) logic [3:0] m_axi_arcache;
  (* mark_debug = "true" *) logic m_axi_arvalid;
  (* mark_debug = "true" *) logic [31:0] m_axi_araddr;
  (* mark_debug = "true" *) logic m_axi_arlock, m_axi_arready;
  (* mark_debug = "true" *) logic [3:0] m_axi_rid;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] m_axi_rdata;
  (* mark_debug = "true" *) logic [1:0] m_axi_rresp;
  (* mark_debug = "true" *) logic m_axi_rvalid, m_axi_rlast, m_axi_rready;

`ifndef P_WISHBONE_ETH_SUPPORTED
  wire phy_ref_clk_raw;
  wire rmii_clk50;
  logic WB_RMII_REF_CLK;
  logic WB_RMII_CRS_DV;
  logic [1:0] WB_RMII_RX_DATA;
  logic [1:0] WB_RMII_TX_DATA;
  logic WB_RMII_TX_EN, WB_RMII_MDC;
  wire WB_RMII_MDIO;
  logic WB_RMII_RST_N, WB_RMII_PHY_IRQ;
`endif

  assign GPIOIN = {25'b0, SDCCD, SDCWP, 1'b0, GPI};
  assign GPO = GPIOOUT[4:0];
  assign SDCCS = SDCCSin[0];

  mmcm mmcm(
    .clk_out1(audio_clk), .clk_out2(clk167), .clk_out3(clk200),
    .clk_out4(CPUCLK), .clk_out5(clk48MHz_raw), .reset(1'b0),
    .locked(mmcm1_locked), .clk_in1_p(default_200mhz_clk_p),
    .clk_in1_n(default_200mhz_clk_n));

`ifndef P_WISHBONE_ETH_SUPPORTED
  BUFG u_bufg_rmii (.I(phy_ref_clk_raw), .O(rmii_clk50));
  assign WB_RMII_REF_CLK = rmii_clk50;
`endif

  assign rst_req = ~resetn | south_reset;
  assign resetn_comb = ~rst_req;

  sysrst sysrst (
    .slowest_sync_clk(CPUCLK), .ext_reset_in(rst_req), .aux_reset_in(1'b0),
    .mb_debug_sys_rst(1'b0), .dcm_locked(mmcm1_locked), .mb_reset(mb_reset),
    .bus_struct_reset(bus_struct_reset), .peripheral_reset(peripheral_reset),
    .interconnect_aresetn(interconnect_aresetn),
    .peripheral_aresetn(peripheral_aresetn));

  // Wally
  wallypipelinedsoc  #(P)
  wallypipelinedsoc(.clk(CPUCLK), .reset_ext(bus_struct_reset), .reset(),
                    .HRDATAEXT, .HREADYEXT, .HRESPEXT, .HSELEXT,
                    .HCLK(HCLKOpen), .HRESETn(HRESETnOpen),
                    .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT,
                    .HTRANS, .HMASTLOCK, .HREADY, .TIMECLK(1'b0),
                    .GPIOIN, .GPIOOUT, .GPIOEN,
                    .UARTSin, .UARTSout, .SDCIn, .SDCCmd, .SDCCS(SDCCSin), .SDCCLK, .ExternalStall(RVVIStall)
                    // WB UART
                    , .WB_UART_RX
                    , .WB_UART_TX
                    // WB Ethernet
                    //, .WB_RMII_REF_CLK,
                    , .WB_RMII_REF_CLK(rmii_clk50),
                    . WB_RMII_CRS_DV,
                    .WB_RMII_RX_DATA,
                    .WB_RMII_TX_DATA,
                    .WB_RMII_TX_EN,
                    .WB_RMII_MDC,
                    .WB_RMII_MDIO,
                    .WB_RMII_RST_N,
                    .WB_RMII_PHY_IRQ
                    , .AXI_DMAIntr(cpu_axi_irq[0])
                    //, .AXI_USBIntr(usb_irq)
                    , .AXI_USBIntr(cpu_axi_irq[1])
                    , .AXI_EthIntr(cpu_axi_irq[2])
                    , .AXI_SDHCIIntr(cpu_axi_irq[3])
                    // Dummy device disabled for now
                    , .AXI_DummyIntr(1'b0)
                    );

  if (P.XILINX_AXI_BR_SUPPORTED) begin
    // ahb lite to axi bridge
    ahbaxibridge ahbaxibridge
        (.s_ahb_hclk(CPUCLK),
        .s_ahb_hresetn(peripheral_aresetn),
        .s_ahb_hsel(HSELEXT),
        .s_ahb_haddr(HADDR[31:0]),
        .s_ahb_hprot(HPROT),
        .s_ahb_htrans(HTRANS),
        .s_ahb_hsize(HSIZE),
        .s_ahb_hwrite(HWRITE),
        .s_ahb_hburst(HBURST),
        .s_ahb_hwdata(HWDATA),
        .s_ahb_hready_out(HREADYEXT),
        .s_ahb_hready_in(HREADY),
        .s_ahb_hrdata(HRDATAEXT),
        .s_ahb_hresp(HRESPEXT),
        .m_axi_awid(m_axi_awid),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_arid(m_axi_arid),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arready(m_axi_arready),
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready));
  end else begin

    ahb_to_axi4_burst #(.AW(32), .DW(P.AHBW), .IW(4))
    ahbaxibridge
    (
        .clk(CPUCLK),
        .resetn(peripheral_aresetn),

        .HSEL(HSELEXT),
        .HADDR(HADDR[31:0]),
        .HPROT(HPROT),
        .HTRANS(HTRANS),
        .HSIZE(HSIZE),
        .HWRITE(HWRITE),
        .HBURST(HBURST),
        .HWDATA(HWDATA),
        .HREADY(HREADYEXT),
        .HREADYIN(HREADY),
        .HRDATA(HRDATAEXT),
        .HRESP(HRESPEXT),
        // not in ahbaxibridge
        .HMASTLOCK(HMASTLOCK),

        .AWID(m_axi_awid),
        .AWLEN(m_axi_awlen),
        .AWSIZE(m_axi_awsize),
        .AWBURST(m_axi_awburst),
        .AWCACHE(m_axi_awcache),
        .AWADDR(m_axi_awaddr),
        .AWPROT(m_axi_awprot),
        .AWVALID(m_axi_awvalid),
        .AWREADY(m_axi_awready),
        .AWLOCK(m_axi_awlock),
        // not in ahbaxibridge
        .AWQOS(4'b0000),

        .WDATA(m_axi_wdata),
        .WSTRB(m_axi_wstrb),
        .WLAST(m_axi_wlast),
        .WVALID(m_axi_wvalid),
        .WREADY(m_axi_wready),

        // ── AXI4 Master: Write Response ─────────────────────────────────────────────
        .BID(m_axi_bid),
        .BRESP(m_axi_bresp),
        .BVALID(m_axi_bvalid),
        .BREADY(m_axi_bready),

        // ── AXI4 Master: Read Address ───────────────────────────────────────────────
        .ARID(m_axi_arid),
        .ARLEN(m_axi_arlen),
        .ARSIZE(m_axi_arsize),
        .ARBURST(m_axi_arburst),
        .ARPROT(m_axi_arprot),
        .ARCACHE(m_axi_arcache),
        .ARVALID(m_axi_arvalid),
        .ARADDR(m_axi_araddr),
        .ARLOCK(m_axi_arlock),
        .ARREADY(m_axi_arready),
        // not in ahbaxibridge
        .ARQOS(4'b0000),

        // ── AXI4 Master: Read Data ──────────────────────────────────────────────────
        .RID(m_axi_rid),
        .RDATA(m_axi_rdata),
        .RRESP(m_axi_rresp),
        .RVALID(m_axi_rvalid),
        .RLAST(m_axi_rlast),
        .RREADY(m_axi_rready)

    );
  end;

  cvwsoc_axi #(.P(P)) u_cvwsoc_axi (
    .CPUCLK_i(CPUCLK),
    .clk167_i(clk167),
    .clk200_i(clk200),
    .clk48MHz_raw_i(clk48MHz_raw),
    .audio_clk_i(audio_clk),
    .mmcm1_locked_i(mmcm1_locked),
    .peripheral_reset_i(peripheral_reset),
    .peripheral_aresetn_i(peripheral_aresetn),
    .rst_req_i(rst_req),
    .resetn_comb_i(resetn_comb),

    .ddr3_dq,
    .ddr3_dqs_n,
    .ddr3_dqs_p,
    .ddr3_addr,
    .ddr3_ba,
    .ddr3_ras_n,
    .ddr3_cas_n,
    .ddr3_we_n,
    .ddr3_reset_n,
    .ddr3_ck_p,
    .ddr3_ck_n,
    .ddr3_cke,
    .ddr3_cs_n,
    .ddr3_dm,
    .ddr3_odt,

    .rgmii_clocks_rx,
    .rgmii_clocks_tx,
    .rgmii_int_n,
    .rgmii_mdc,
    .rgmii_mdio,
    .rgmii_rst_n,
    .rgmii_rx_ctl,
    .rgmii_rx_data,
    .rgmii_tx_ctl,
    .rgmii_tx_data,

    .vga_hsync,
    .vga_vsync,
    .vga_r_5,
    .vga_g_6,
    .vga_b_5,

    .usb0_dp,
    .usb0_dm,
    .usb1_dp,
    .usb1_dm,

    .SD_CLK,
    .SD_CD_N,
    .SD_CMD,
    .SD_DAT,

    .i2s_tx_mclk,
    .i2s_tx_lrck,
    .i2s_tx_sclk,
    .i2s_tx_sdout,

    .m_axi_awid_i(m_axi_awid),
    .m_axi_awlen_i(m_axi_awlen),
    .m_axi_awsize_i(m_axi_awsize),
    .m_axi_awburst_i(m_axi_awburst),
    .m_axi_awcache_i(m_axi_awcache),
    .m_axi_awaddr_i(m_axi_awaddr),
    .m_axi_awprot_i(m_axi_awprot),
    .m_axi_awvalid_i(m_axi_awvalid),
    .m_axi_awready_o(m_axi_awready),
    .m_axi_awlock_i(m_axi_awlock),
    .m_axi_wdata_i(m_axi_wdata),
    .m_axi_wstrb_i(m_axi_wstrb),
    .m_axi_wlast_i(m_axi_wlast),
    .m_axi_wvalid_i(m_axi_wvalid),
    .m_axi_wready_o(m_axi_wready),
    .m_axi_bid_o(m_axi_bid),
    .m_axi_bresp_o(m_axi_bresp),
    .m_axi_bvalid_o(m_axi_bvalid),
    .m_axi_bready_i(m_axi_bready),
    .m_axi_arid_i(m_axi_arid),
    .m_axi_arlen_i(m_axi_arlen),
    .m_axi_arsize_i(m_axi_arsize),
    .m_axi_arburst_i(m_axi_arburst),
    .m_axi_arprot_i(m_axi_arprot),
    .m_axi_arcache_i(m_axi_arcache),
    .m_axi_arvalid_i(m_axi_arvalid),
    .m_axi_araddr_i(m_axi_araddr),
    .m_axi_arlock_i(m_axi_arlock),
    .m_axi_arready_o(m_axi_arready),
    .m_axi_rid_o(m_axi_rid),
    .m_axi_rdata_o(m_axi_rdata),
    .m_axi_rresp_o(m_axi_rresp),
    .m_axi_rvalid_o(m_axi_rvalid),
    .m_axi_rlast_o(m_axi_rlast),
    .m_axi_rready_i(m_axi_rready),
    .cpu_axi_irq_o(cpu_axi_irq)
  );


  (* mark_debug = "true" *)  logic IlaTrigger;

  if(RVVI_SYNTH_SUPPORTED) begin : rvvi_synth
    localparam MAX_CSRS = 3;
    localparam TOTAL_CSRS = 36;
    localparam [31:0] RVVI_INIT_TIME_OUT = 32'd100000000;
    localparam [31:0] RVVI_PACKET_DELAY = 32'd400;

    // pipeline controls
    logic                                             StallE, StallM, StallW, FlushE, FlushM, FlushW;
    // required
    logic [P.XLEN-1:0]                                PCM;
    logic                                             InstrValidM;
    logic [31:0]                                      InstrRawD;
    logic [P.AHBW-1:0]                                Mcycle, Minstret;
    logic                                             TrapM;
    logic [1:0]                                       PrivilegeModeW;
    // registers gpr and fpr
    logic                                             GPRWen, FPRWen;
    logic [4:0]                                       GPRAddr, FPRAddr;
    logic [P.XLEN-1:0]                                GPRValue, FPRValue;
    logic [P.XLEN-1:0]                                CSRArray [TOTAL_CSRS-1:0];

    logic                                             valid;
    logic [72+(5*P.XLEN) + MAX_CSRS*(P.XLEN+16)-1:0] rvvi;

    assign StallE         = fpgaTop.wallypipelinedsoc.core.StallE;
    assign StallM         = fpgaTop.wallypipelinedsoc.core.StallM;
    assign StallW         = fpgaTop.wallypipelinedsoc.core.StallW;
    assign FlushE         = fpgaTop.wallypipelinedsoc.core.FlushE;
    assign FlushM         = fpgaTop.wallypipelinedsoc.core.FlushM;
    assign FlushW         = fpgaTop.wallypipelinedsoc.core.FlushW;
    assign InstrValidM    = fpgaTop.wallypipelinedsoc.core.ieu.InstrValidM;
    assign InstrRawD      = fpgaTop.wallypipelinedsoc.core.ifu.InstrRawD;
    assign PCM            = fpgaTop.wallypipelinedsoc.core.ifu.PCM;
    assign Mcycle         = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[0];
    assign Minstret       = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[2];
    assign TrapM          = fpgaTop.wallypipelinedsoc.core.TrapM;
    assign PrivilegeModeW = fpgaTop.wallypipelinedsoc.core.priv.priv.privmode.PrivilegeModeW;
    assign GPRAddr        = fpgaTop.wallypipelinedsoc.core.ieu.dp.regf.a3;
    assign GPRWen         = fpgaTop.wallypipelinedsoc.core.ieu.dp.regf.we3;
    assign GPRValue       = fpgaTop.wallypipelinedsoc.core.ieu.dp.regf.wd3;
    assign FPRAddr        = fpgaTop.wallypipelinedsoc.core.fpu.fpu.fregfile.a4;
    assign FPRWen         = fpgaTop.wallypipelinedsoc.core.fpu.fpu.fregfile.we4;
    assign FPRValue       = fpgaTop.wallypipelinedsoc.core.fpu.fpu.fregfile.wd4;

    assign CSRArray[0] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MSTATUS_REGW; // 12'h300
    assign CSRArray[1] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MSTATUSH_REGW; // 12'h310
    assign CSRArray[2] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MTVEC_REGW; // 12'h305
    assign CSRArray[3] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MEPC_REGW; // 12'h341
    assign CSRArray[4] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MCOUNTEREN_REGW; // 12'h306
    assign CSRArray[5] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MCOUNTINHIBIT_REGW; // 12'h320
    assign CSRArray[6] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MEDELEG_REGW; // 12'h302
    assign CSRArray[7] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIDELEG_REGW; // 12'h303
    assign CSRArray[8] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIP_REGW; // 12'h344
    assign CSRArray[9] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIE_REGW; // 12'h304
    assign CSRArray[10] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MISA_REGW; // 12'h301
    assign CSRArray[11] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MENVCFG_REGW; // 12'h30A
    assign CSRArray[12] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MHARTID_REGW; // 12'hF14
    assign CSRArray[13] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MSCRATCH_REGW; // 12'h340
    assign CSRArray[14] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MCAUSE_REGW; // 12'h342
    assign CSRArray[15] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MTVAL_REGW; // 12'h343
    assign CSRArray[16] = 0; // 12'hF11
    assign CSRArray[17] = 0; // 12'hF12
    assign CSRArray[18] = {{P.XLEN-12{1'b0}}, 12'h100}; // 12'hF13
    assign CSRArray[19] = 0; // 12'hF15
    assign CSRArray[20] = 0; // 12'h34A
    // supervisor CSRs
    assign CSRArray[21] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SSTATUS_REGW; // 12'h100
    assign CSRArray[22] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIE_REGW & 12'h222; // 12'h104
    assign CSRArray[23] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STVEC_REGW; // 12'h105
    assign CSRArray[24] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SEPC_REGW; // 12'h141
    assign CSRArray[25] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SCOUNTEREN_REGW; // 12'h106
    assign CSRArray[26] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SENVCFG_REGW; // 12'h10A
    assign CSRArray[27] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SATP_REGW; // 12'h180
    assign CSRArray[28] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SSCRATCH_REGW; // 12'h140
    assign CSRArray[29] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STVAL_REGW; // 12'h143
    assign CSRArray[30] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SCAUSE_REGW; // 12'h142
    assign CSRArray[31] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIP_REGW & 12'h222 & fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIDELEG_REGW; // 12'h144
    assign CSRArray[32] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STIMECMP_REGW; // 12'h14D
    // user CSRs
    assign CSRArray[33] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FFLAGS_REGW; // 12'h001
    assign CSRArray[34] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FRM_REGW; // 12'h002
    assign CSRArray[35] = {fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FRM_REGW, fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FFLAGS_REGW}; // 12'h003

    rvvisynth #(P, MAX_CSRS) rvvisynth(.clk(CPUCLK), .reset(bus_struct_reset), .StallE, .StallM, .StallW, .FlushE, .FlushM, .FlushW,
      .PCM, .InstrValidM, .InstrRawD, .Mcycle, .Minstret, .TrapM,
      .PrivilegeModeW, .GPRWen, .FPRWen, .GPRAddr, .FPRAddr, .GPRValue, .FPRValue, .CSRArray,
      .valid, .rvvi);

    // axi 4 write data channel
    logic [31:0]                                      RvviAxiWdata;
    logic [3:0]                                       RvviAxiWstrb;
    logic                                             RvviAxiWlast;
    logic                                             RvviAxiWvalid;
    logic                                             RvviAxiWready;

    logic [31:0] RvviAxiRdata;
    logic [3:0]                                       RvviAxiRstrb;
    logic RvviAxiRlast;
    logic RvviAxiRvalid;

    logic                                             tx_error_underflow, tx_fifo_overflow, tx_fifo_bad_frame, tx_fifo_good_frame, rx_error_bad_frame;
    logic                                             rx_error_bad_fcs, rx_fifo_overflow, rx_fifo_bad_frame, rx_fifo_good_frame;

    packetizer #(P, MAX_CSRS, RVVI_INIT_TIME_OUT, RVVI_PACKET_DELAY) packetizer(.rvvi, .valid, .m_axi_aclk(CPUCLK), .m_axi_aresetn(~bus_struct_reset), .RVVIStall,
      .RvviAxiWdata, .RvviAxiWstrb, .RvviAxiWlast, .RvviAxiWvalid, .RvviAxiWready);

    eth_mac_mii_fifo #(.TARGET("XILINX"), .CLOCK_INPUT_STYLE("BUFG"), .AXIS_DATA_WIDTH(32), .TX_FIFO_DEPTH(1024)) ethernet(.rst(bus_struct_reset), .logic_clk(CPUCLK), .logic_rst(bus_struct_reset),
      .tx_axis_tdata(RvviAxiWdata), .tx_axis_tkeep(RvviAxiWstrb), .tx_axis_tvalid(RvviAxiWvalid), .tx_axis_tready(RvviAxiWready),
      .tx_axis_tlast(RvviAxiWlast), .tx_axis_tuser('0), .rx_axis_tdata(RvviAxiRdata),
      .rx_axis_tkeep(RvviAxiRstrb), .rx_axis_tvalid(RvviAxiRvalid), .rx_axis_tready(1'b1),
      .rx_axis_tlast(RvviAxiRlast), .rx_axis_tuser(),

      .mii_rx_clk(phy_rx_clk),
      .mii_rxd(phy_rxd),
      .mii_rx_dv(phy_rx_dv),
      .mii_rx_er(phy_rx_er),
      .mii_tx_clk(phy_tx_clk),
      .mii_txd(phy_txd),
      .mii_tx_en(phy_tx_en),
      .mii_tx_er(),

      // status
      .tx_error_underflow, .tx_fifo_overflow, .tx_fifo_bad_frame, .tx_fifo_good_frame, .rx_error_bad_frame,
      .rx_error_bad_fcs, .rx_fifo_overflow, .rx_fifo_bad_frame, .rx_fifo_good_frame,
      .cfg_ifg(8'd12), .cfg_tx_enable(1'b1), .cfg_rx_enable(1'b1)
      );

    triggergen triggergen(.clk(CPUCLK), .reset(bus_struct_reset), .RvviAxiRdata,
      .RvviAxiRstrb, .RvviAxiRlast, .RvviAxiRvalid, .IlaTrigger);
  end else begin // if (P.RVVI_SYNTH_SUPPORTED)
    assign IlaTrigger = '0;
    assign RVVIStall = '0;
  end

`ifdef P_WISHBONE_ETH_SUPPORTED
  //assign phy_reset_n = ~bus_struct_reset;
  assign phy_reset_n = ~1'b0;
`endif

endmodule
