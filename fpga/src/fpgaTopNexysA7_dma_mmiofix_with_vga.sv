///////////////////////////////////////////
// fpgaTop.sv
//
// Written: rose@rosethompson.net November 17, 2021
// Modified:
//
// Purpose: This is a top level for the fpga's implementation of wally.
//          Instantiates wallysoc, ddr4, abh lite to axi converters, pll, etc
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
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

import cvw::*;

module fpgaTop #(parameter logic RVVI_SYNTH_SUPPORTED = 0)
  (input logic           default_100mhz_clk,
   input logic           resetn,
   //input logic           south_reset,

   // GPIO signals
   input logic [3:0]   GPI,
   output logic [4:0]  GPO,

   // UART Signals
   input logic         UARTSin,
   output logic        UARTSout,

   // SDC Signals connecting to an SPI peripheral
   input logic         SDCIn,
   output logic        SDCCLK,
   output logic        SDCCmd,
   output logic        SDCCS,
   input logic         SDCCD,
   //input logic         SDCWP, // No WP pin

`ifdef RVVI_SYNTH_SUPPORTED
 /*
     * Ethernet: 100BASE-T MII
     */
    output logic       phy_ref_clk,
    input logic        phy_rx_clk,
    input logic  [3:0] phy_rxd,
    input logic        phy_rx_dv,
    input logic        phy_rx_er,
    input logic        phy_tx_clk,
    output logic [3:0] phy_txd,
    output logic       phy_tx_en,
    input logic        phy_col, // nc
    input logic        phy_crs, // nc
    output logic       phy_reset_n,
`endif

   inout logic [15:0]    ddr2_dq,
   inout logic [1:0]     ddr2_dqs_n,
   inout logic [1:0]     ddr2_dqs_p,
   output logic [12:0]   ddr2_addr,
   output logic [2:0]    ddr2_ba,
   output logic          ddr2_ras_n,
   output logic          ddr2_cas_n,
   output logic          ddr2_we_n,
   //output logic          ddr2_reset_n,
   output logic [0:0]    ddr2_ck_p,
   output logic [0:0]    ddr2_ck_n,
   output logic [0:0]    ddr2_cke,
   output logic [0:0]    ddr2_cs_n,
   output logic [1:0]    ddr2_dm,
   output logic [0:0]    ddr2_odt

    // WB UART
    , input logic WB_UART_RX
    , output logic WB_UART_TX
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
    // VGA signals
    , output logic        vga_hsync,
    output logic        vga_vsync,
    output logic [3:0]  vga_r_4,
    output logic [3:0]  vga_g_4,
    output logic [3:0]  vga_b_4
   );

  // MMCM Signals
  logic          CPUCLK;
  logic          cpuclk_raw;
  logic          c0_ddr4_ui_clk_sync_rst;
  logic          bus_struct_reset;
  logic          peripheral_reset;
  logic          interconnect_aresetn;
  logic          peripheral_aresetn;
  logic          mb_reset;

  // AHB Signals from Wally
  logic            HCLKOpen;
  logic            HRESETnOpen;
  logic [63:0]     HRDATAEXT;
  logic            HREADYEXT;
  logic            HRESPEXT;
  logic            HSELEXT;
  logic [55:0]     HADDR;
  logic [63:0]     HWDATA;
  logic [64/8-1:0] HWSTRB;
  logic            HWRITE;
  logic [2:0]      HSIZE;
  logic [2:0]      HBURST;
  logic [1:0]      HTRANS;
  logic            HREADY;
  logic [3:0]      HPROT;
  logic            HMASTLOCK;

  // GPIO Signals
  logic [31:0]    GPIOIN, GPIOOUT, GPIOEN;

  // AHB to AXI Bridge Signals
  logic [3:0]      m_axi_awid;
  logic [7:0]      m_axi_awlen;
  logic [2:0]      m_axi_awsize;
  logic [1:0]      m_axi_awburst;
  logic [3:0]      m_axi_awcache;
  logic [31:0]     m_axi_awaddr;
  logic [2:0]      m_axi_awprot;
  logic            m_axi_awvalid;
  logic            m_axi_awready;
  logic            m_axi_awlock;
  logic [63:0]     m_axi_wdata;
  logic [7:0]      m_axi_wstrb;
  logic            m_axi_wlast;
  logic            m_axi_wvalid;
  logic            m_axi_wready;
  logic [3:0]      m_axi_bid;
  logic [1:0]      m_axi_bresp;
  logic            m_axi_bvalid;
  logic            m_axi_bready;
  logic [3:0]      m_axi_arid;
  logic [7:0]      m_axi_arlen;
  logic [2:0]      m_axi_arsize;
  logic [1:0]      m_axi_arburst;
  logic [2:0]      m_axi_arprot;
  logic [3:0]      m_axi_arcache;
  logic            m_axi_arvalid;
  logic [31:0]     m_axi_araddr;
  logic            m_axi_arlock;
  logic            m_axi_arready;
  logic [3:0]      m_axi_rid;
  logic [63:0]     m_axi_rdata;
  logic [1:0]      m_axi_rresp;
  logic            m_axi_rvalid;
  logic            m_axi_rlast;
  logic            m_axi_rready;

  // AXI Signals going out of Clock Converter
  logic [3:0]      BUS_axi_arregion;
  logic [3:0]      BUS_axi_arqos;
  logic [3:0]      BUS_axi_awregion;
  logic [3:0]      BUS_axi_awqos;
  logic [3:0]      BUS_axi_awid;
  logic [7:0]      BUS_axi_awlen;
  logic [2:0]      BUS_axi_awsize;
  logic [1:0]      BUS_axi_awburst;
  logic [3:0]      BUS_axi_awcache;
  logic [31:0]     BUS_axi_awaddr;
  logic [2:0]      BUS_axi_awprot;
  logic            BUS_axi_awvalid;
  logic            BUS_axi_awready;
  logic            BUS_axi_awlock;
  logic [63:0]     BUS_axi_wdata;
  logic [7:0]      BUS_axi_wstrb;
  logic            BUS_axi_wlast;
  logic            BUS_axi_wvalid;
  logic            BUS_axi_wready;
  logic [3:0]      BUS_axi_bid;
  logic [1:0]      BUS_axi_bresp;
  logic            BUS_axi_bvalid;
  logic            BUS_axi_bready;
  logic [3:0]      BUS_axi_arid;
  logic [7:0]      BUS_axi_arlen;
  logic [2:0]      BUS_axi_arsize;
  logic [1:0]      BUS_axi_arburst;
  logic [2:0]      BUS_axi_arprot;
  logic [3:0]      BUS_axi_arcache;
  logic            BUS_axi_arvalid;
  logic [31:0]     BUS_axi_araddr;
  logic            BUS_axi_arlock;
  logic            BUS_axi_arready;
  logic [3:0]      BUS_axi_rid;
  logic [63:0]     BUS_axi_rdata;
  logic [1:0]      BUS_axi_rresp;
  logic            BUS_axi_rvalid;
  logic            BUS_axi_rlast;
  logic            BUS_axi_rready;

  // AXI master Signals going out of Clock Converter (MIG-facing, M00 slice)
  logic [3:0]      BUS_cb_axi_arregion;
  logic [3:0]      BUS_cb_axi_arqos;
  logic [3:0]      BUS_cb_axi_awregion;
  logic [3:0]      BUS_cb_axi_awqos;
  logic [3:0]      BUS_cb_axi_awid;
  logic [7:0]      BUS_cb_axi_awlen;
  logic [2:0]      BUS_cb_axi_awsize;
  logic [1:0]      BUS_cb_axi_awburst;
  logic [3:0]      BUS_cb_axi_awcache;
  logic [31:0]     BUS_cb_axi_awaddr;
  logic [2:0]      BUS_cb_axi_awprot;
  logic            BUS_cb_axi_awvalid;
  logic            BUS_cb_axi_awready;
  logic            BUS_cb_axi_awlock;
  logic [63:0]     BUS_cb_axi_wdata;
  logic [7:0]      BUS_cb_axi_wstrb;
  logic            BUS_cb_axi_wlast;
  logic            BUS_cb_axi_wvalid;
  logic            BUS_cb_axi_wready;
  logic [3:0]      BUS_cb_axi_bid;
  logic [1:0]      BUS_cb_axi_bresp;
  logic            BUS_cb_axi_bvalid;
  logic            BUS_cb_axi_bready;
  logic [3:0]      BUS_cb_axi_arid;
  logic [7:0]      BUS_cb_axi_arlen;
  logic [2:0]      BUS_cb_axi_arsize;
  logic [1:0]      BUS_cb_axi_arburst;
  logic [2:0]      BUS_cb_axi_arprot;
  logic [3:0]      BUS_cb_axi_arcache;
  logic            BUS_cb_axi_arvalid;
  logic [31:0]     BUS_cb_axi_araddr;
  logic            BUS_cb_axi_arlock;
  logic            BUS_cb_axi_arready;
  logic [3:0]      BUS_cb_axi_rid;
  logic [63:0]     BUS_cb_axi_rdata;
  logic [1:0]      BUS_cb_axi_rresp;
  logic            BUS_cb_axi_rvalid;
  logic            BUS_cb_axi_rlast;
  logic            BUS_cb_axi_rready;

  // Crossbar packed M_AXI ports (M00/M01 concatenated)
  wire [11:0]  cb_m_axi_awid;
  // Crossbar uses ADDR_WIDTH=32, NUM_MI=3 => packed [95:0] (M00=[31:0], M01=[63:32], M02=[95:64])
  wire [95:0]   cb_m_axi_awaddr;
  wire [23:0]   cb_m_axi_awlen;
  wire [8:0]    cb_m_axi_awsize;
  wire [5:0]    cb_m_axi_awburst;
  wire [2:0]    cb_m_axi_awlock;
  wire [11:0]   cb_m_axi_awcache;
  wire [8:0]    cb_m_axi_awprot;
  wire [11:0]   cb_m_axi_awregion;
  wire [11:0]   cb_m_axi_awqos;
  wire [2:0]    cb_m_axi_awvalid;
  wire [2:0]    cb_m_axi_awready;

  wire [191:0]  cb_m_axi_wdata;
  wire [23:0]   cb_m_axi_wstrb;
  wire [2:0]    cb_m_axi_wlast;
  wire [2:0]    cb_m_axi_wvalid;
  wire [2:0]    cb_m_axi_wready;

  wire [11:0]   cb_m_axi_bid;
  wire [5:0]    cb_m_axi_bresp;
  wire [2:0]    cb_m_axi_bvalid;
  wire [2:0]    cb_m_axi_bready;

  wire [11:0]   cb_m_axi_arid;
  wire [95:0]   cb_m_axi_araddr;
  wire [23:0]   cb_m_axi_arlen;
  wire [8:0]    cb_m_axi_arsize;
  wire [5:0]    cb_m_axi_arburst;
  wire [2:0]    cb_m_axi_arlock;
  wire [11:0]   cb_m_axi_arcache;
  wire [8:0]    cb_m_axi_arprot;
  wire [11:0]   cb_m_axi_arregion;
  wire [11:0]   cb_m_axi_arqos;
  wire [2:0]    cb_m_axi_arvalid;
  wire [2:0]    cb_m_axi_arready;

  wire [11:0]   cb_m_axi_rid;
  wire [191:0]  cb_m_axi_rdata;
  wire [5:0]    cb_m_axi_rresp;
  wire [2:0]    cb_m_axi_rlast;
  wire [2:0]    cb_m_axi_rvalid;
  wire [2:0]    cb_m_axi_rready;

  // Crossbar packed S_AXI ports for NUM_SI=3 (S00=CPU, S01=CDMA, S02=VGA)
  wire [11:0]  cb_s_axi_awid;
  wire [95:0]  cb_s_axi_awaddr;
  wire [23:0]  cb_s_axi_awlen;
  wire [8:0]   cb_s_axi_awsize;
  wire [5:0]   cb_s_axi_awburst;
  wire [2:0]   cb_s_axi_awlock;
  wire [11:0]  cb_s_axi_awcache;
  wire [8:0]   cb_s_axi_awprot;
  wire [11:0]  cb_s_axi_awqos;
  wire [2:0]   cb_s_axi_awvalid;
  wire [2:0]   cb_s_axi_awready;

  wire [191:0] cb_s_axi_wdata;
  wire [23:0]  cb_s_axi_wstrb;
  wire [2:0]   cb_s_axi_wlast;
  wire [2:0]   cb_s_axi_wvalid;
  wire [2:0]   cb_s_axi_wready;

  wire [11:0]  cb_s_axi_bid;
  wire [5:0]   cb_s_axi_bresp;
  wire [2:0]   cb_s_axi_bvalid;
  wire [2:0]   cb_s_axi_bready;

  wire [11:0]  cb_s_axi_arid;
  wire [95:0]  cb_s_axi_araddr;
  wire [23:0]  cb_s_axi_arlen;
  wire [8:0]   cb_s_axi_arsize;
  wire [5:0]   cb_s_axi_arburst;
  wire [2:0]   cb_s_axi_arlock;
  wire [11:0]  cb_s_axi_arcache;
  wire [8:0]   cb_s_axi_arprot;
  wire [11:0]  cb_s_axi_arqos;
  wire [2:0]   cb_s_axi_arvalid;
  wire [2:0]   cb_s_axi_arready;

  wire [11:0]  cb_s_axi_rid;
  wire [191:0] cb_s_axi_rdata;
  wire [5:0]   cb_s_axi_rresp;
  wire [2:0]   cb_s_axi_rlast;
  wire [2:0]   cb_s_axi_rvalid;
  wire [2:0]   cb_s_axi_rready;

  // AXI CDMA M_AXI (master into crossbar S01)
  logic [3:0]  cdma_m_axi_awid;
  logic [31:0] cdma_m_axi_awaddr;
  logic [7:0]  cdma_m_axi_awlen;
  logic [2:0]  cdma_m_axi_awsize;
  logic [1:0]  cdma_m_axi_awburst;
  logic        cdma_m_axi_awlock;
  logic [3:0]  cdma_m_axi_awcache;
  logic [2:0]  cdma_m_axi_awprot;
  logic        cdma_m_axi_awvalid;
  logic        cdma_m_axi_awready;
  logic [63:0] cdma_m_axi_wdata;
  logic [7:0]  cdma_m_axi_wstrb;
  logic        cdma_m_axi_wlast;
  logic        cdma_m_axi_wvalid;
  logic        cdma_m_axi_wready;
  logic [3:0]  cdma_m_axi_bid;
  logic [1:0]  cdma_m_axi_bresp;
  logic        cdma_m_axi_bvalid;
  logic        cdma_m_axi_bready;
  logic [3:0]  cdma_m_axi_arid;
  logic [31:0] cdma_m_axi_araddr;
  logic [7:0]  cdma_m_axi_arlen;
  logic [2:0]  cdma_m_axi_arsize;
  logic [1:0]  cdma_m_axi_arburst;
  logic        cdma_m_axi_arlock;
  logic [3:0]  cdma_m_axi_arcache;
  logic [2:0]  cdma_m_axi_arprot;
  logic        cdma_m_axi_arvalid;
  logic        cdma_m_axi_arready;
  logic [3:0]  cdma_m_axi_rid;
  logic [63:0] cdma_m_axi_rdata;
  logic [1:0]  cdma_m_axi_rresp;
  logic        cdma_m_axi_rlast;
  logic        cdma_m_axi_rvalid;
  logic        cdma_m_axi_rready;


  // AXI VGA scanout M_AXI (master into crossbar S02)
  logic [3:0]  vga_m_axi_awid;
  logic [31:0] vga_m_axi_awaddr;
  logic [7:0]  vga_m_axi_awlen;
  logic [2:0]  vga_m_axi_awsize;
  logic [1:0]  vga_m_axi_awburst;
  logic        vga_m_axi_awlock;
  logic [3:0]  vga_m_axi_awcache;
  logic [2:0]  vga_m_axi_awprot;
  logic        vga_m_axi_awvalid;
  logic        vga_m_axi_awready;

  logic [63:0] vga_m_axi_wdata;
  logic [7:0]  vga_m_axi_wstrb;
  logic        vga_m_axi_wlast;
  logic        vga_m_axi_wvalid;
  logic        vga_m_axi_wready;

  logic [3:0]  vga_m_axi_bid;
  logic [1:0]  vga_m_axi_bresp;
  logic        vga_m_axi_bvalid;
  logic        vga_m_axi_bready;

  logic [3:0]  vga_m_axi_arid;
  logic [31:0] vga_m_axi_araddr;
  logic [7:0]  vga_m_axi_arlen;
  logic [2:0]  vga_m_axi_arsize;
  logic [1:0]  vga_m_axi_arburst;
  logic        vga_m_axi_arlock;
  logic [3:0]  vga_m_axi_arcache;
  logic [2:0]  vga_m_axi_arprot;
  logic        vga_m_axi_arvalid;
  logic        vga_m_axi_arready;

  logic [3:0]  vga_m_axi_rid;
  logic [63:0] vga_m_axi_rdata;
  logic [1:0]  vga_m_axi_rresp;
  logic        vga_m_axi_rlast;
  logic        vga_m_axi_rvalid;
  logic        vga_m_axi_rready;

  // VGA pins (internal for now)
//   logic        vga_hsync;
//   logic        vga_vsync;
//   logic [4:0]  vga_r;
//   logic [5:0]  vga_g;
//   logic [4:0]  vga_b;


  // Regs window path (M01) signals from dwidth converter back to crossbar
  wire        reg_awready;
  wire        reg_wready;
  wire        reg_arready;
  wire        reg_bvalid;
  wire [1:0]  reg_bresp;
  wire [3:0]  reg_bid;
  wire        reg_rvalid;
  wire        reg_rlast;
  wire [1:0]  reg_rresp;
  wire [3:0]  reg_rid;
  wire [63:0] reg_rdata;

  // VGA regs window path (M02) signals back to crossbar
  wire        vga_reg_awready;
  wire        vga_reg_wready;
  wire        vga_reg_arready;
  wire        vga_reg_bvalid;
  wire [1:0]  vga_reg_bresp;
  wire [3:0]  vga_reg_bid;
  wire        vga_reg_rvalid;
  wire        vga_reg_rlast;
  wire [1:0]  vga_reg_rresp;
  wire [3:0]  vga_reg_rid;
  wire [63:0] vga_reg_rdata;

  logic [4:0] vga_r_5_internal;
  logic [5:0] vga_g_6_internal;
  logic [4:0] vga_b_5_internal;

  //truncate (easiest way to handle 5-6-5 in a 4-4-4 output)
  assign vga_r_4 = vga_r_5_internal[4:1];
  assign vga_g_4 = vga_g_6_internal[5:2];
  assign vga_b_4 = vga_b_5_internal[4:1];

  // AXI4-Lite to CDMA regs (driven by MMIO bridge)
  wire [31:0] pc_lite_awaddr;
  wire [2:0]  pc_lite_awprot;
  wire        pc_lite_awvalid;
  wire        pc_lite_awready;
  wire [31:0] pc_lite_wdata;
  wire [3:0]  pc_lite_wstrb;
  wire        pc_lite_wvalid;
  wire        pc_lite_wready;
  wire [1:0]  pc_lite_bresp;
  wire        pc_lite_bvalid;
  wire        pc_lite_bready;
  wire [31:0] pc_lite_araddr;
  wire [2:0]  pc_lite_arprot;
  wire        pc_lite_arvalid;
  wire        pc_lite_arready;
  wire [31:0] pc_lite_rdata;
  wire [1:0]  pc_lite_rresp;
  wire        pc_lite_rvalid;
  wire        pc_lite_rready;

  wire        dma_introut;

  // IMPORTANT: the generated AXI CDMA instance in this project is an ID-less / lock-less AXI master.
  // It does not expose m_axi_awid/arid/bid/rid nor m_axi_awlock/arlock ports.
  // To satisfy the crossbar (ID_WIDTH=4, THREAD_ID_WIDTH=3) we drive those missing sidebands to 0.
  assign cdma_m_axi_awid   = 4'b0000;
  assign cdma_m_axi_arid   = 4'b0000;
  assign cdma_m_axi_awlock = 1'b0;
  assign cdma_m_axi_arlock = 1'b0;
  // Crossbar M00 -> MIG (BUS_cb_*)
  assign BUS_cb_axi_awid    = cb_m_axi_awid[3:0];
  assign BUS_cb_axi_awaddr  = cb_m_axi_awaddr[26:0]; // DDR size dependent
  assign BUS_cb_axi_awlen   = cb_m_axi_awlen[7:0];
  assign BUS_cb_axi_awsize  = cb_m_axi_awsize[2:0];
  assign BUS_cb_axi_awburst = cb_m_axi_awburst[1:0];
  assign BUS_cb_axi_awlock  = cb_m_axi_awlock[0];
  assign BUS_cb_axi_awcache = cb_m_axi_awcache[3:0];
  assign BUS_cb_axi_awprot  = cb_m_axi_awprot[2:0];
  assign BUS_cb_axi_awqos   = cb_m_axi_awqos[3:0];
  assign BUS_cb_axi_awvalid = cb_m_axi_awvalid[0];

  assign BUS_cb_axi_wdata   = cb_m_axi_wdata[63:0];
  assign BUS_cb_axi_wstrb   = cb_m_axi_wstrb[7:0];
  assign BUS_cb_axi_wlast   = cb_m_axi_wlast[0];
  assign BUS_cb_axi_wvalid  = cb_m_axi_wvalid[0];

  assign BUS_cb_axi_bready  = cb_m_axi_bready[0];

  assign BUS_cb_axi_arid    = cb_m_axi_arid[3:0];
  assign BUS_cb_axi_araddr  = cb_m_axi_araddr[26:0]; // DDR size dependent
  assign BUS_cb_axi_arlen   = cb_m_axi_arlen[7:0];
  assign BUS_cb_axi_arsize  = cb_m_axi_arsize[2:0];
  assign BUS_cb_axi_arburst = cb_m_axi_arburst[1:0];
  assign BUS_cb_axi_arlock  = cb_m_axi_arlock[0];
  assign BUS_cb_axi_arcache = cb_m_axi_arcache[3:0];
  assign BUS_cb_axi_arprot  = cb_m_axi_arprot[2:0];
  assign BUS_cb_axi_arqos   = cb_m_axi_arqos[3:0];
  assign BUS_cb_axi_arvalid = cb_m_axi_arvalid[0];

  assign BUS_cb_axi_rready  = cb_m_axi_rready[0];

  // Crossbar SI packing: S00=CPU (BUS_axi_*), S01=CDMA (cdma_m_axi_*), S02=VGA (vga_m_axi_*)
  // Crossbar is configured with S00/S01/S02_THREAD_ID_WIDTH=2, so we force upper 2 bits of each 4-bit ID to 0.
  assign cb_s_axi_awid    = { {2'b00, vga_m_axi_awid[1:0]}, {2'b00, cdma_m_axi_awid[1:0]}, {2'b00, BUS_axi_awid[1:0]} };
  assign cb_s_axi_awaddr  = { vga_m_axi_awaddr,  cdma_m_axi_awaddr,  BUS_axi_awaddr };
  assign cb_s_axi_awlen   = { vga_m_axi_awlen,   cdma_m_axi_awlen,   BUS_axi_awlen };
  assign cb_s_axi_awsize  = { vga_m_axi_awsize,  cdma_m_axi_awsize,  BUS_axi_awsize };
  assign cb_s_axi_awburst = { vga_m_axi_awburst, cdma_m_axi_awburst, BUS_axi_awburst };
  assign cb_s_axi_awlock  = { vga_m_axi_awlock,  cdma_m_axi_awlock,  BUS_axi_awlock };
  assign cb_s_axi_awcache = { vga_m_axi_awcache, cdma_m_axi_awcache, BUS_axi_awcache };
  assign cb_s_axi_awprot  = { vga_m_axi_awprot,  cdma_m_axi_awprot,  BUS_axi_awprot };
  assign cb_s_axi_awqos   = { 4'b0,              4'b0,               BUS_axi_awqos };
  assign cb_s_axi_awvalid = { vga_m_axi_awvalid, cdma_m_axi_awvalid, BUS_axi_awvalid };

  assign cb_s_axi_wdata   = { vga_m_axi_wdata,   cdma_m_axi_wdata,   BUS_axi_wdata };
  assign cb_s_axi_wstrb   = { vga_m_axi_wstrb,   cdma_m_axi_wstrb,   BUS_axi_wstrb };
  assign cb_s_axi_wlast   = { vga_m_axi_wlast,   cdma_m_axi_wlast,   BUS_axi_wlast };
  assign cb_s_axi_wvalid  = { vga_m_axi_wvalid,  cdma_m_axi_wvalid,  BUS_axi_wvalid };

  assign cb_s_axi_bready  = { vga_m_axi_bready,  cdma_m_axi_bready,  BUS_axi_bready };

  assign cb_s_axi_arid    = { {2'b00, vga_m_axi_arid[1:0]}, {2'b00, cdma_m_axi_arid[1:0]}, {2'b00, BUS_axi_arid[1:0]} };
  assign cb_s_axi_araddr  = { vga_m_axi_araddr,  cdma_m_axi_araddr,  BUS_axi_araddr };
  assign cb_s_axi_arlen   = { vga_m_axi_arlen,   cdma_m_axi_arlen,   BUS_axi_arlen };
  assign cb_s_axi_arsize  = { vga_m_axi_arsize,  cdma_m_axi_arsize,  BUS_axi_arsize };
  assign cb_s_axi_arburst = { vga_m_axi_arburst, cdma_m_axi_arburst, BUS_axi_arburst };
  assign cb_s_axi_arlock  = { vga_m_axi_arlock,  cdma_m_axi_arlock,  BUS_axi_arlock };
  assign cb_s_axi_arcache = { vga_m_axi_arcache, cdma_m_axi_arcache, BUS_axi_arcache };
  assign cb_s_axi_arprot  = { vga_m_axi_arprot,  cdma_m_axi_arprot,  BUS_axi_arprot };
  assign cb_s_axi_arqos   = { 4'b0,              4'b0,               BUS_axi_arqos };
  assign cb_s_axi_arvalid = { vga_m_axi_arvalid, cdma_m_axi_arvalid, BUS_axi_arvalid };

  assign cb_s_axi_rready  = { vga_m_axi_rready,  cdma_m_axi_rready,  BUS_axi_rready };

  // Split back to CPU master (S00)
  assign BUS_axi_awready = cb_s_axi_awready[0];
  assign BUS_axi_wready  = cb_s_axi_wready[0];
  assign BUS_axi_bvalid  = cb_s_axi_bvalid[0];
  assign BUS_axi_bresp   = cb_s_axi_bresp[1:0];
  assign BUS_axi_bid     = cb_s_axi_bid[3:0];
  assign BUS_axi_arready = cb_s_axi_arready[0];
  assign BUS_axi_rvalid  = cb_s_axi_rvalid[0];
  assign BUS_axi_rlast   = cb_s_axi_rlast[0];
  assign BUS_axi_rresp   = cb_s_axi_rresp[1:0];
  assign BUS_axi_rid     = cb_s_axi_rid[3:0];
  assign BUS_axi_rdata   = cb_s_axi_rdata[63:0];

  // Split back to CDMA master (S01)
  assign cdma_m_axi_awready = cb_s_axi_awready[1];
  assign cdma_m_axi_wready  = cb_s_axi_wready[1];
  assign cdma_m_axi_bvalid  = cb_s_axi_bvalid[1];
  assign cdma_m_axi_bresp   = cb_s_axi_bresp[3:2];
  assign cdma_m_axi_bid     = cb_s_axi_bid[7:4];
  assign cdma_m_axi_arready = cb_s_axi_arready[1];
  assign cdma_m_axi_rvalid  = cb_s_axi_rvalid[1];
  assign cdma_m_axi_rlast   = cb_s_axi_rlast[1];
  assign cdma_m_axi_rresp   = cb_s_axi_rresp[3:2];
  assign cdma_m_axi_rid     = cb_s_axi_rid[7:4];
  assign cdma_m_axi_rdata   = cb_s_axi_rdata[127:64];

  // Split back to VGA master (S02)
  assign vga_m_axi_awready = cb_s_axi_awready[2];
  assign vga_m_axi_wready  = cb_s_axi_wready[2];
  assign vga_m_axi_bvalid  = cb_s_axi_bvalid[2];
  assign vga_m_axi_bresp   = cb_s_axi_bresp[5:4];
  assign vga_m_axi_bid     = cb_s_axi_bid[11:8];
  assign vga_m_axi_arready = cb_s_axi_arready[2];
  assign vga_m_axi_rvalid  = cb_s_axi_rvalid[2];
  assign vga_m_axi_rlast   = cb_s_axi_rlast[2];
  assign vga_m_axi_rresp   = cb_s_axi_rresp[5:4];
  assign vga_m_axi_rid     = cb_s_axi_rid[11:8];
  assign vga_m_axi_rdata   = cb_s_axi_rdata[191:128];

  // M01 (second MI) is used for CDMA registers via dwidth+protocol converters.
  // M02 (third MI) is used for VGA registers (AXI4/64 slave on BUSCLK).
  // Provide crossbar MI return channels from MIG (M00) and both regs paths (M01/M02).
  assign cb_m_axi_awready = {vga_reg_awready, reg_awready, BUS_cb_axi_awready};
  assign cb_m_axi_wready  = {vga_reg_wready,  reg_wready,  BUS_cb_axi_wready};
  assign cb_m_axi_arready = {vga_reg_arready, reg_arready, BUS_cb_axi_arready};

  assign cb_m_axi_bvalid  = {vga_reg_bvalid,  reg_bvalid,  BUS_cb_axi_bvalid};
  assign cb_m_axi_bresp   = {vga_reg_bresp,   reg_bresp,   BUS_cb_axi_bresp};
  assign cb_m_axi_bid     = {vga_reg_bid,     reg_bid,     BUS_cb_axi_bid};

  assign cb_m_axi_rvalid  = {vga_reg_rvalid,  reg_rvalid,  BUS_cb_axi_rvalid};
  assign cb_m_axi_rlast   = {vga_reg_rlast,   reg_rlast,   BUS_cb_axi_rlast};
  assign cb_m_axi_rresp   = {vga_reg_rresp,   reg_rresp,   BUS_cb_axi_rresp};
  assign cb_m_axi_rid     = {vga_reg_rid,     reg_rid,     BUS_cb_axi_rid};
  assign cb_m_axi_rdata   = {vga_reg_rdata,   reg_rdata,   BUS_cb_axi_rdata};

  ///////////////////////////////////////////////////////////

  logic            BUSCLK;
  logic            sdio_reset_open;

  logic            c0_init_calib_complete;
  logic            dbg_clk;
  logic [511 : 0]  dbg_bus;
  logic            ui_clk_sync_rst;

  logic            CLK208;
  logic            clk167;
  logic            clk200, clk200_b;

  logic            app_sr_active;
  logic            app_ref_ack;
  logic            app_zq_ack;
  logic            mmcm_locked;
  logic [11:0]     device_temp;
  logic            mmcm1_locked;

  (* mark_debug = "true" *)  logic              RVVIStall;

  logic SDCWP; // No WP pin
  assign SDCWP  = 1'b0;
  assign GPIOIN = {25'b0, SDCCD, SDCWP, 1'b0, GPI};
  assign GPO = GPIOOUT[4:0];

  logic [3:0] SDCCSin;
  assign SDCCS = SDCCSin[0];

  // active high reset
  logic reset = ~resetn;
  logic south_reset = ~resetn;


  wire phy_ref_clk_raw;   // 50 MHz from MMCM
  wire rmii_clk50;
  
  // mmcm
  mmcm mmcm(.clk_out1(clk200),
            .clk_out2(clk200_b),
            .clk_out3(cpuclk_raw),
            //.clk_out4(phy_ref_clk),
            .clk_out4(phy_ref_clk_raw),
            .reset(1'b0),
            .locked(mmcm1_locked),
            .clk_in1(default_100mhz_clk));

  BUFG u_bufg_cpuclk (
    .I(cpuclk_raw),
    .O(CPUCLK)
  );

  // WB Ethernet PHY / MAC 50 MHz clock generation => FIXME: This should be using MMCM output
    // wire clk200In = clk200_b;   // your unused 200 MHz
    // wire rmii_clk50;

    // BUFGCE_DIV #(.BUFGCE_DIVIDE(4)) u_rmii_div (
    //     .I   (clk200In),
    //     .CE  (1'b1),
    //     .CLR (1'b0),
    //     .O   (rmii_clk50)
    // );
    // BUFR #(
    //     .BUFR_DIVIDE("4"),
    //     .SIM_DEVICE("7SERIES")
    // ) u_rmii_div (
    //     .I   (clk200In),
    //     .CE  (1'b1),
    //     .CLR (1'b0),
    //     .O   (rmii_clk50)
    // );

    BUFG u_bufg_rmii (
    .I(phy_ref_clk_raw),
    .O(rmii_clk50)
    );    

    // drive PHY + LiteEth
    //assign rmii_ref_clk = rmii_clk50;
    //assign WB_RMII_REF_CLK = rmii_clk50;
    assign WB_RMII_REF_CLK = rmii_clk50;  // goes to pin D5 via XDC


  // reset controller XILINX IP
  sysrst sysrst
    (.slowest_sync_clk(CPUCLK),
     .ext_reset_in(1'b0),
     .aux_reset_in(south_reset),
     .mb_debug_sys_rst(1'b0),
     .dcm_locked(c0_init_calib_complete),
     .mb_reset(mb_reset),  //open
     .bus_struct_reset(bus_struct_reset),
     .peripheral_reset(peripheral_reset), //open
     .interconnect_aresetn(interconnect_aresetn), //open
     .peripheral_aresetn(peripheral_aresetn));

  `include "parameter-defs.vh"

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
                    , .AXI_DMAIntr(dma_introut)
                    );

  // ahb lite to axi bridge
  ahbaxibridge ahbaxibridge
    (.s_ahb_hclk(CPUCLK),
     .s_ahb_hresetn(peripheral_aresetn),
     .s_ahb_hsel(HSELEXT),
     .s_ahb_haddr(HADDR[31:0]),
     .s_ahb_hprot(HPROT),
     .s_ahb_htrans(HTRANS),
     .s_ahb_hsize(HSIZE),
     //.s_ahb_hsize(HSIZE_to_bridge),
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

  // AXI Clock Converter
  clkconverter clkconverter
    (.s_axi_aclk(CPUCLK),
     .s_axi_aresetn(peripheral_aresetn),
     .s_axi_awid(m_axi_awid),
     .s_axi_awlen(m_axi_awlen),
     .s_axi_awsize(m_axi_awsize),
     .s_axi_awburst(m_axi_awburst),
     .s_axi_awcache(m_axi_awcache),
     .s_axi_awaddr(m_axi_awaddr[31:0]),
     .s_axi_awprot(m_axi_awprot),
     .s_axi_awregion(4'b0), // bridge does not provide these
     .s_axi_awqos(4'b0),    // bridge does not provide these
     .s_axi_awvalid(m_axi_awvalid),
     .s_axi_awready(m_axi_awready),
     .s_axi_awlock(m_axi_awlock),
     .s_axi_wdata(m_axi_wdata),
     .s_axi_wstrb(m_axi_wstrb),
     .s_axi_wlast(m_axi_wlast),
     .s_axi_wvalid(m_axi_wvalid),
     .s_axi_wready(m_axi_wready),
     .s_axi_bid(m_axi_bid),
     .s_axi_bresp(m_axi_bresp),
     .s_axi_bvalid(m_axi_bvalid),
     .s_axi_bready(m_axi_bready),
     .s_axi_arid(m_axi_arid),
     .s_axi_arlen(m_axi_arlen),
     .s_axi_arsize(m_axi_arsize),
     .s_axi_arburst(m_axi_arburst),
     .s_axi_arprot(m_axi_arprot),
     .s_axi_arregion(4'b0), // bridge does not provide these
     .s_axi_arqos(4'b0),    // bridge does not provide these
     .s_axi_arcache(m_axi_arcache),
     .s_axi_arvalid(m_axi_arvalid),
     .s_axi_araddr(m_axi_araddr[31:0]),
     .s_axi_arlock(m_axi_arlock),
     .s_axi_arready(m_axi_arready),
     .s_axi_rid(m_axi_rid),
     .s_axi_rdata(m_axi_rdata),
     .s_axi_rresp(m_axi_rresp),
     .s_axi_rvalid(m_axi_rvalid),
     .s_axi_rlast(m_axi_rlast),
     .s_axi_rready(m_axi_rready),

     .m_axi_aclk(BUSCLK),
     .m_axi_aresetn(resetn),
     .m_axi_awid(BUS_axi_awid),
     .m_axi_awlen(BUS_axi_awlen),
     .m_axi_awsize(BUS_axi_awsize),
     .m_axi_awburst(BUS_axi_awburst),
     .m_axi_awcache(BUS_axi_awcache),
     .m_axi_awaddr(BUS_axi_awaddr),
     .m_axi_awprot(BUS_axi_awprot),
     .m_axi_awregion(BUS_axi_awregion),
     .m_axi_awqos(BUS_axi_awqos),
     .m_axi_awvalid(BUS_axi_awvalid),
     .m_axi_awready(BUS_axi_awready),
     .m_axi_awlock(BUS_axi_awlock),
     .m_axi_wdata(BUS_axi_wdata),
     .m_axi_wstrb(BUS_axi_wstrb),
     .m_axi_wlast(BUS_axi_wlast),
     .m_axi_wvalid(BUS_axi_wvalid),
     .m_axi_wready(BUS_axi_wready),
     .m_axi_bid(BUS_axi_bid),
     .m_axi_bresp(BUS_axi_bresp),
     .m_axi_bvalid(BUS_axi_bvalid),
     .m_axi_bready(BUS_axi_bready),
     .m_axi_arid(BUS_axi_arid),
     .m_axi_arlen(BUS_axi_arlen),
     .m_axi_arsize(BUS_axi_arsize),
     .m_axi_arburst(BUS_axi_arburst),
     .m_axi_arprot(BUS_axi_arprot),
     .m_axi_arregion(BUS_axi_arregion),
     .m_axi_arqos(BUS_axi_arqos),
     .m_axi_arcache(BUS_axi_arcache),
     .m_axi_arvalid(BUS_axi_arvalid),
     .m_axi_araddr(BUS_axi_araddr),
     .m_axi_arlock(BUS_axi_arlock),
     .m_axi_arready(BUS_axi_arready),
     .m_axi_rid(BUS_axi_rid),
     .m_axi_rdata(BUS_axi_rdata),
     .m_axi_rresp(BUS_axi_rresp),
     .m_axi_rvalid(BUS_axi_rvalid),
     .m_axi_rlast(BUS_axi_rlast),
     .m_axi_rready(BUS_axi_rready));

  axicrossbar axicrossbar (
    .aclk(BUSCLK),
    .aresetn(resetn),

    // Packed S_AXI (S00=CPU, S01=CDMA)
    .s_axi_awaddr(cb_s_axi_awaddr),
    .s_axi_awlen(cb_s_axi_awlen),
    .s_axi_awsize(cb_s_axi_awsize),
    .s_axi_awburst(cb_s_axi_awburst),
    .s_axi_awlock(cb_s_axi_awlock),
    .s_axi_awcache(cb_s_axi_awcache),
    .s_axi_awprot(cb_s_axi_awprot),
    .s_axi_awqos(cb_s_axi_awqos),
    .s_axi_awvalid(cb_s_axi_awvalid),
    .s_axi_awready(cb_s_axi_awready),

    .s_axi_wdata(cb_s_axi_wdata),
    .s_axi_wstrb(cb_s_axi_wstrb),
    .s_axi_wlast(cb_s_axi_wlast),
    .s_axi_wvalid(cb_s_axi_wvalid),
    .s_axi_wready(cb_s_axi_wready),

    .s_axi_bresp(cb_s_axi_bresp),
    .s_axi_bvalid(cb_s_axi_bvalid),
    .s_axi_bready(cb_s_axi_bready),

    .s_axi_araddr(cb_s_axi_araddr),
    .s_axi_arlen(cb_s_axi_arlen),
    .s_axi_arsize(cb_s_axi_arsize),
    .s_axi_arburst(cb_s_axi_arburst),
    .s_axi_arlock(cb_s_axi_arlock),
    .s_axi_arcache(cb_s_axi_arcache),
    .s_axi_arprot(cb_s_axi_arprot),
    .s_axi_arqos(cb_s_axi_arqos),
    .s_axi_arvalid(cb_s_axi_arvalid),
    .s_axi_arready(cb_s_axi_arready),

    .s_axi_rdata(cb_s_axi_rdata),
    .s_axi_rresp(cb_s_axi_rresp),
    .s_axi_rlast(cb_s_axi_rlast),
    .s_axi_rvalid(cb_s_axi_rvalid),
    .s_axi_rready(cb_s_axi_rready),

    .s_axi_awid(cb_s_axi_awid),
    .s_axi_arid(cb_s_axi_arid),
    .s_axi_bid(cb_s_axi_bid),
    .s_axi_rid(cb_s_axi_rid),

    // Packed M_AXI (M00=DDR/MIG, M01=CDMA regs, M02=VGA regs)
    .m_axi_awaddr(cb_m_axi_awaddr),
    .m_axi_awlen(cb_m_axi_awlen),
    .m_axi_awsize(cb_m_axi_awsize),
    .m_axi_awburst(cb_m_axi_awburst),
    .m_axi_awlock(cb_m_axi_awlock),
    .m_axi_awcache(cb_m_axi_awcache),
    .m_axi_awprot(cb_m_axi_awprot),
    .m_axi_awregion(cb_m_axi_awregion),
    .m_axi_awqos(cb_m_axi_awqos),
    .m_axi_awvalid(cb_m_axi_awvalid),
    .m_axi_awready(cb_m_axi_awready),

    .m_axi_wdata(cb_m_axi_wdata),
    .m_axi_wstrb(cb_m_axi_wstrb),
    .m_axi_wlast(cb_m_axi_wlast),
    .m_axi_wvalid(cb_m_axi_wvalid),
    .m_axi_wready(cb_m_axi_wready),

    .m_axi_bresp(cb_m_axi_bresp),
    .m_axi_bvalid(cb_m_axi_bvalid),
    .m_axi_bready(cb_m_axi_bready),

    .m_axi_araddr(cb_m_axi_araddr),
    .m_axi_arlen(cb_m_axi_arlen),
    .m_axi_arsize(cb_m_axi_arsize),
    .m_axi_arburst(cb_m_axi_arburst),
    .m_axi_arlock(cb_m_axi_arlock),
    .m_axi_arcache(cb_m_axi_arcache),
    .m_axi_arprot(cb_m_axi_arprot),
    .m_axi_arregion(cb_m_axi_arregion),
    .m_axi_arqos(cb_m_axi_arqos),
    .m_axi_arvalid(cb_m_axi_arvalid),
    .m_axi_arready(cb_m_axi_arready),

    .m_axi_rdata(cb_m_axi_rdata),
    .m_axi_rresp(cb_m_axi_rresp),
    .m_axi_rlast(cb_m_axi_rlast),
    .m_axi_rvalid(cb_m_axi_rvalid),
    .m_axi_rready(cb_m_axi_rready),

    .m_axi_awid(cb_m_axi_awid),
    .m_axi_arid(cb_m_axi_arid),
    .m_axi_bid(cb_m_axi_bid),
    .m_axi_rid(cb_m_axi_rid)
  );

  // M02 (AXI4/64) -> axi_vga_wrap (AXI slave regs + AXI master scanout), all on BUSCLK
  axi_vga_wrap axi_vga_wrap_i (
    .aclk    (BUSCLK),
    .aresetn (resetn),

    // AXI slave regs (from crossbar M02)
    .s_axi_awid    (cb_m_axi_awid[11:8]),
    .s_axi_awaddr  (cb_m_axi_awaddr[95:64]),
    .s_axi_awlen   (cb_m_axi_awlen[23:16]),
    .s_axi_awsize  (cb_m_axi_awsize[8:6]),
    .s_axi_awburst (cb_m_axi_awburst[5:4]),
    .s_axi_awlock  (cb_m_axi_awlock[2]),
    .s_axi_awcache (cb_m_axi_awcache[11:8]),
    .s_axi_awprot  (cb_m_axi_awprot[8:6]),
    .s_axi_awqos   (cb_m_axi_awqos[11:8]),
    .s_axi_awvalid (cb_m_axi_awvalid[2]),
    .s_axi_awready (vga_reg_awready),

    .s_axi_wdata   (cb_m_axi_wdata[191:128]),
    .s_axi_wstrb   (cb_m_axi_wstrb[23:16]),
    .s_axi_wlast   (cb_m_axi_wlast[2]),
    .s_axi_wvalid  (cb_m_axi_wvalid[2]),
    .s_axi_wready  (vga_reg_wready),

    .s_axi_bresp   (vga_reg_bresp),
    .s_axi_bvalid  (vga_reg_bvalid),
    .s_axi_bid     (vga_reg_bid),
    .s_axi_bready  (cb_m_axi_bready[2]),

    .s_axi_arid    (cb_m_axi_arid[11:8]),
    .s_axi_araddr  (cb_m_axi_araddr[95:64]),
    .s_axi_arlen   (cb_m_axi_arlen[23:16]),
    .s_axi_arsize  (cb_m_axi_arsize[8:6]),
    .s_axi_arburst (cb_m_axi_arburst[5:4]),
    .s_axi_arlock  (cb_m_axi_arlock[2]),
    .s_axi_arcache (cb_m_axi_arcache[11:8]),
    .s_axi_arprot  (cb_m_axi_arprot[8:6]),
    .s_axi_arqos   (cb_m_axi_arqos[11:8]),
    .s_axi_arvalid (cb_m_axi_arvalid[2]),
    .s_axi_arready (vga_reg_arready),

    .s_axi_rdata   (vga_reg_rdata),
    .s_axi_rresp   (vga_reg_rresp),
    .s_axi_rlast   (vga_reg_rlast),
    .s_axi_rvalid  (vga_reg_rvalid),
    .s_axi_rid     (vga_reg_rid),
    .s_axi_rready  (cb_m_axi_rready[2]),

    // AXI master scanout (to crossbar S02)
    .m_axi_awid    (vga_m_axi_awid),
    .m_axi_awaddr  (vga_m_axi_awaddr),
    .m_axi_awlen   (vga_m_axi_awlen),
    .m_axi_awsize  (vga_m_axi_awsize),
    .m_axi_awburst (vga_m_axi_awburst),
    .m_axi_awlock  (vga_m_axi_awlock),
    .m_axi_awcache (vga_m_axi_awcache),
    .m_axi_awprot  (vga_m_axi_awprot),
    .m_axi_awvalid (vga_m_axi_awvalid),
    .m_axi_awready (vga_m_axi_awready),

    .m_axi_wdata   (vga_m_axi_wdata),
    .m_axi_wstrb   (vga_m_axi_wstrb),
    .m_axi_wlast   (vga_m_axi_wlast),
    .m_axi_wvalid  (vga_m_axi_wvalid),
    .m_axi_wready  (vga_m_axi_wready),

    .m_axi_bid     (vga_m_axi_bid),
    .m_axi_bresp   (vga_m_axi_bresp),
    .m_axi_bvalid  (vga_m_axi_bvalid),
    .m_axi_bready  (vga_m_axi_bready),

    .m_axi_arid    (vga_m_axi_arid),
    .m_axi_araddr  (vga_m_axi_araddr),
    .m_axi_arlen   (vga_m_axi_arlen),
    .m_axi_arsize  (vga_m_axi_arsize),
    .m_axi_arburst (vga_m_axi_arburst),
    .m_axi_arlock  (vga_m_axi_arlock),
    .m_axi_arcache (vga_m_axi_arcache),
    .m_axi_arprot  (vga_m_axi_arprot),
    .m_axi_arvalid (vga_m_axi_arvalid),
    .m_axi_arready (vga_m_axi_arready),

    .m_axi_rid     (vga_m_axi_rid),
    .m_axi_rdata   (vga_m_axi_rdata),
    .m_axi_rresp   (vga_m_axi_rresp),
    .m_axi_rlast   (vga_m_axi_rlast),
    .m_axi_rvalid  (vga_m_axi_rvalid),
    .m_axi_rready  (vga_m_axi_rready),

    // VGA pins
    .vga_hsync_o   (vga_hsync),
    .vga_vsync_o   (vga_vsync),
    .vga_r_o       (vga_r_5_internal),
    .vga_g_o       (vga_g_6_internal),
    .vga_b_o       (vga_b_5_internal)
  );

  // M01 (AXI4/64) -> MMIO bridge -> AXI4-Lite/32 -> CDMA regs
  axi64_mmio_to_axilite32 mmio_cdmaregs (
    .aclk(BUSCLK),
    .aresetn(resetn),

    // AXI4 slave side from crossbar M01
    .s_axi_awid    (cb_m_axi_awid[7:4]),
    .s_axi_awaddr  (cb_m_axi_awaddr[63:32]),
    .s_axi_awlen   (cb_m_axi_awlen[15:8]),
    .s_axi_awsize  (cb_m_axi_awsize[5:3]),
    .s_axi_awburst (cb_m_axi_awburst[3:2]),
    .s_axi_awvalid (cb_m_axi_awvalid[1]),
    .s_axi_awready (reg_awready),

    .s_axi_wdata   (cb_m_axi_wdata[127:64]),
    .s_axi_wstrb   (cb_m_axi_wstrb[15:8]),
    .s_axi_wlast   (cb_m_axi_wlast[1]),
    .s_axi_wvalid  (cb_m_axi_wvalid[1]),
    .s_axi_wready  (reg_wready),

    .s_axi_bresp   (reg_bresp),
    .s_axi_bvalid  (reg_bvalid),
    .s_axi_bid     (reg_bid),
    .s_axi_bready  (cb_m_axi_bready[1]),

    .s_axi_arid    (cb_m_axi_arid[7:4]),
    .s_axi_araddr  (cb_m_axi_araddr[63:32]),
    .s_axi_arlen   (cb_m_axi_arlen[15:8]),
    .s_axi_arsize  (cb_m_axi_arsize[5:3]),
    .s_axi_arburst (cb_m_axi_arburst[3:2]),
    .s_axi_arvalid (cb_m_axi_arvalid[1]),
    .s_axi_arready (reg_arready),

    .s_axi_rdata   (reg_rdata),
    .s_axi_rresp   (reg_rresp),
    .s_axi_rlast   (reg_rlast),
    .s_axi_rvalid  (reg_rvalid),
    .s_axi_rid     (reg_rid),
    .s_axi_rready  (cb_m_axi_rready[1]),

    // AXI4-Lite master side to CDMA
    .m_axil_awaddr (pc_lite_awaddr),
    .m_axil_awprot (pc_lite_awprot),
    .m_axil_awvalid(pc_lite_awvalid),
    .m_axil_awready(pc_lite_awready),

    .m_axil_wdata  (pc_lite_wdata),
    .m_axil_wstrb  (pc_lite_wstrb),
    .m_axil_wvalid (pc_lite_wvalid),
    .m_axil_wready (pc_lite_wready),

    .m_axil_bresp  (pc_lite_bresp),
    .m_axil_bvalid (pc_lite_bvalid),
    .m_axil_bready (pc_lite_bready),

    .m_axil_araddr (pc_lite_araddr),
    .m_axil_arprot (pc_lite_arprot),
    .m_axil_arvalid(pc_lite_arvalid),
    .m_axil_arready(pc_lite_arready),

    .m_axil_rdata  (pc_lite_rdata),
    .m_axil_rresp  (pc_lite_rresp),
    .m_axil_rvalid (pc_lite_rvalid),
    .m_axil_rready (pc_lite_rready)
  );

  axicdma axicdma (
    .m_axi_aclk        (BUSCLK),
    .s_axi_lite_aclk   (BUSCLK),
    .s_axi_lite_aresetn(resetn),

    // AXI4-Lite control
	    // This project generates CDMA with a small AXI4-Lite address port (6 bits).
	    // Base address decode is done in the crossbar; CDMA only needs low bits for register offsets.
	    .s_axi_lite_awaddr (pc_lite_awaddr[5:0]),
    .s_axi_lite_awvalid(pc_lite_awvalid),
    .s_axi_lite_awready(pc_lite_awready),

    .s_axi_lite_wdata  (pc_lite_wdata),
    .s_axi_lite_wvalid (pc_lite_wvalid),
    .s_axi_lite_wready (pc_lite_wready),

    .s_axi_lite_bresp  (pc_lite_bresp),
    .s_axi_lite_bvalid (pc_lite_bvalid),
    .s_axi_lite_bready (pc_lite_bready),

	    .s_axi_lite_araddr (pc_lite_araddr[5:0]),
    .s_axi_lite_arvalid(pc_lite_arvalid),
    .s_axi_lite_arready(pc_lite_arready),

    .s_axi_lite_rdata  (pc_lite_rdata),
    .s_axi_lite_rresp  (pc_lite_rresp),
    .s_axi_lite_rvalid (pc_lite_rvalid),
    .s_axi_lite_rready (pc_lite_rready),

    // AXI4 MM2MM master into crossbar S01
    .m_axi_awaddr  (cdma_m_axi_awaddr),
    .m_axi_awlen   (cdma_m_axi_awlen),
    .m_axi_awsize  (cdma_m_axi_awsize),
    .m_axi_awburst (cdma_m_axi_awburst),
    .m_axi_awcache (cdma_m_axi_awcache),
    .m_axi_awprot  (cdma_m_axi_awprot),
    .m_axi_awvalid (cdma_m_axi_awvalid),
    .m_axi_awready (cdma_m_axi_awready),

    .m_axi_wdata   (cdma_m_axi_wdata),
    .m_axi_wstrb   (cdma_m_axi_wstrb),
    .m_axi_wlast   (cdma_m_axi_wlast),
    .m_axi_wvalid  (cdma_m_axi_wvalid),
    .m_axi_wready  (cdma_m_axi_wready),

    .m_axi_bresp   (cdma_m_axi_bresp),
    .m_axi_bvalid  (cdma_m_axi_bvalid),
    .m_axi_bready  (cdma_m_axi_bready),

    .m_axi_araddr  (cdma_m_axi_araddr),
    .m_axi_arlen   (cdma_m_axi_arlen),
    .m_axi_arsize  (cdma_m_axi_arsize),
    .m_axi_arburst (cdma_m_axi_arburst),
    .m_axi_arcache (cdma_m_axi_arcache),
    .m_axi_arprot  (cdma_m_axi_arprot),
    .m_axi_arvalid (cdma_m_axi_arvalid),
    .m_axi_arready (cdma_m_axi_arready),

    .m_axi_rdata   (cdma_m_axi_rdata),
    .m_axi_rresp   (cdma_m_axi_rresp),
    .m_axi_rlast   (cdma_m_axi_rlast),
    .m_axi_rvalid  (cdma_m_axi_rvalid),
    .m_axi_rready  (cdma_m_axi_rready),

    .cdma_introut  (dma_introut)
  );

  // DDR2 Controller

  ddr2 ddr2
    (
     // ddr2 I/O
     .ddr2_dq(ddr2_dq),
     .ddr2_dqs_n(ddr2_dqs_n),
     .ddr2_dqs_p(ddr2_dqs_p),
     .ddr2_addr(ddr2_addr),
     .ddr2_ba(ddr2_ba),
     .ddr2_ras_n(ddr2_ras_n),
     .ddr2_cas_n(ddr2_cas_n),
     .ddr2_we_n(ddr2_we_n),
     // no reset_n for DDR2
     //.ddr2_reset_n(ddr2_reset_n),
     .ddr2_ck_p(ddr2_ck_p),
     .ddr2_ck_n(ddr2_ck_n),
     .ddr2_cke(ddr2_cke),
     .ddr2_cs_n(ddr2_cs_n),
     .ddr2_dm(ddr2_dm),
     .ddr2_odt(ddr2_odt),
     .sys_clk_i(clk200),
     // clk_ref_i: When both are 200 MHz same clock can be used
     .ui_clk(BUSCLK),
     .ui_clk_sync_rst(ui_clk_sync_rst),
     .aresetn(resetn),
     .sys_rst(resetn),    // 'SysResetPolarity' setting is ACTIVE_LOW in MIG .prj
     .mmcm_locked(mmcm_locked),

     .app_sr_req(1'b0),  // reserved command
     .app_ref_req(1'b0), // refresh command
     .app_zq_req(1'b0),  // recalibrate command
     .app_sr_active(app_sr_active), // reserved response
     .app_ref_ack(app_ref_ack),     // refresh ack
     .app_zq_ack(app_zq_ack),       // recalibrate ack

     // AXI (FROM CROSSBAR M00 -> MIG)
     .s_axi_awid(BUS_cb_axi_awid),
     .s_axi_awaddr(BUS_cb_axi_awaddr[26:0]), // This width must match DDR size
     .s_axi_awlen(BUS_cb_axi_awlen),
     .s_axi_awsize(BUS_cb_axi_awsize),
     .s_axi_awburst(BUS_cb_axi_awburst),
     .s_axi_awlock(BUS_cb_axi_awlock),
     .s_axi_awcache(BUS_cb_axi_awcache),
     .s_axi_awprot(BUS_cb_axi_awprot),
     .s_axi_awqos(BUS_cb_axi_awqos),
     .s_axi_awvalid(BUS_cb_axi_awvalid),
     .s_axi_awready(BUS_cb_axi_awready),
     .s_axi_wdata(BUS_cb_axi_wdata),
     .s_axi_wstrb(BUS_cb_axi_wstrb),
     .s_axi_wlast(BUS_cb_axi_wlast),
     .s_axi_wvalid(BUS_cb_axi_wvalid),
     .s_axi_wready(BUS_cb_axi_wready),
     .s_axi_bready(BUS_cb_axi_bready),
     .s_axi_bid(BUS_cb_axi_bid),
     .s_axi_bresp(BUS_cb_axi_bresp),
     .s_axi_bvalid(BUS_cb_axi_bvalid),
     .s_axi_arid(BUS_cb_axi_arid),
     .s_axi_araddr(BUS_cb_axi_araddr[26:0]), // This width must match DDR size
     .s_axi_arlen(BUS_cb_axi_arlen),
     .s_axi_arsize(BUS_cb_axi_arsize),
     .s_axi_arburst(BUS_cb_axi_arburst),
     .s_axi_arlock(BUS_cb_axi_arlock),
     .s_axi_arcache(BUS_cb_axi_arcache),
     .s_axi_arprot(BUS_cb_axi_arprot),
     .s_axi_arqos(BUS_cb_axi_arqos),
     .s_axi_arvalid(BUS_cb_axi_arvalid),
     .s_axi_arready(BUS_cb_axi_arready),
     .s_axi_rready(BUS_cb_axi_rready),
     .s_axi_rlast(BUS_cb_axi_rlast),
     .s_axi_rvalid(BUS_cb_axi_rvalid),
     .s_axi_rresp(BUS_cb_axi_rresp),
     .s_axi_rid(BUS_cb_axi_rid),
     .s_axi_rdata(BUS_cb_axi_rdata),

     .init_calib_complete(c0_init_calib_complete),
     .device_temp_i(device_temp));

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
    logic [63:0]                                      Mcycle, Minstret;
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

  //assign phy_reset_n = ~bus_struct_reset;
  assign phy_reset_n = ~1'b0;

endmodule
