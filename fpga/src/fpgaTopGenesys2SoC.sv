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

  localparam int unsigned ADDR_W    = 32; // FIXME
  localparam int unsigned DATA_W    = P.AHBW;
  localparam int unsigned STRB_W    = DATA_W/8;
  localparam int unsigned AXI_LEN_W = 8;
  localparam int unsigned AXI_SIZE_W = 3;
  localparam int unsigned AXI_BURST_W = 2;
  localparam int unsigned AXI_CACHE_W = 4;
  localparam int unsigned AXI_PROT_W = 3;
  localparam int unsigned AXI_QOS_W = 4;
  localparam int unsigned AXI_RESP_W = 2;

  typedef logic [ADDR_W-1:0] axi_addr_t;

  // Generate XBAR configuration
  localparam xbar_out_t XBAR_OUT = gen_xbar_out(P);

  localparam int unsigned N_SLV     = XBAR_OUT.n_slv;
  // XBAR is master for: DDR3, CDMA, VGA, USB, LITEETH, LiteDRAM CSR, SDHCI,
  //                     iDMA desc64 memory, iDMA reg64, iDMA desc64 AXIS
  localparam int unsigned N_MST     = XBAR_OUT.n_mst;
  localparam int unsigned SLV_ID_W  = 2;
  localparam int unsigned MST_ID_W  = SLV_ID_W + $clog2(N_SLV);
  localparam int unsigned DDR_ID_W  = MST_ID_W;
  localparam int unsigned N_RULES   = XBAR_OUT.n_rules;

  localparam int unsigned CB_S_CPU  = XBAR_OUT.s_cpu;
  localparam int unsigned CB_S_CDMA = XBAR_OUT.s_cdma;
  localparam int unsigned CB_S_VGA  = XBAR_OUT.s_vga;
  localparam int unsigned CB_S_USB  = XBAR_OUT.s_usb;
  localparam int unsigned CB_S_IDMA_FE = XBAR_OUT.s_idma_fe;
  localparam int unsigned CB_S_IDMA_FE_AXIS = XBAR_OUT.s_idma_fe_axis;
  localparam int unsigned CB_S_IDMA_BE = XBAR_OUT.s_idma_be;

  localparam int unsigned CB_M_DDR      = XBAR_OUT.m_ddr;
  localparam int unsigned CB_M_CDMA_REG = XBAR_OUT.m_cdma_reg;
  localparam int unsigned CB_M_VGA_REG  = XBAR_OUT.m_vga_reg;
  localparam int unsigned CB_M_USB_REG  = XBAR_OUT.m_usb_reg;
  localparam int unsigned CB_M_ETH_REG  = XBAR_OUT.m_eth_reg;
  localparam int unsigned CB_M_DRAM_CSR = XBAR_OUT.m_dram_csr;
  localparam int unsigned CB_M_SDHCI    = XBAR_OUT.m_sdhci;
  localparam int unsigned CB_M_IDMA_DESC = XBAR_OUT.m_idma_desc;
  localparam int unsigned CB_M_IDMA_REG64 = XBAR_OUT.m_idma_reg64;
  localparam int unsigned CB_M_IDMA_AXIS = XBAR_OUT.m_idma_axis;

  localparam int unsigned MIG_ADDR_WIDTH = 30;
  localparam int unsigned DDR_ADDR_BITS = MIG_ADDR_WIDTH;

`ifndef P_WISHBONE_ETH_SUPPORTED

    // WB Ethernet
    logic WB_RMII_REF_CLK;
    logic WB_RMII_CRS_DV;
    logic [1:0]  WB_RMII_RX_DATA;
    logic [1:0]  WB_RMII_TX_DATA;
    logic        WB_RMII_TX_EN;
    logic        WB_RMII_MDC;
    wire         WB_RMII_MDIO;
    logic        WB_RMII_RST_N;
    logic        WB_RMII_PHY_IRQ;
`endif

  // MMCM Signals
  logic          CPUCLK;
  logic          c0_ddr4_ui_clk_sync_rst;
  logic          bus_struct_reset;
  logic          peripheral_reset;
  logic          interconnect_aresetn;
  logic          peripheral_aresetn;
  logic          mb_reset;

  // AHB Signals from Wally
  logic          HCLKOpen;
  logic          HRESETnOpen;
  (* mark_debug = "true" *) logic [P.AHBW-1:0]      HRDATAEXT;
  (* mark_debug = "true" *) logic          HREADYEXT;
  (* mark_debug = "true" *) logic          HRESPEXT;
  logic          HSELEXT;
  (* mark_debug = "true" *) logic [55:0]      HADDR;
  (* mark_debug = "true" *) logic [P.AHBW-1:0]      HWDATA;
  (* mark_debug = "true" *) logic [STRB_W-1:0]  HWSTRB;
  (* mark_debug = "true" *) logic          HWRITE;
  (* mark_debug = "true" *) logic [2:0]      HSIZE;
  (* mark_debug = "true" *) logic [2:0]      HBURST;
  (* mark_debug = "true" *) logic [1:0]      HTRANS;
  (* mark_debug = "true" *) logic          HREADY;
  (* mark_debug = "true" *) logic [3:0]      HPROT;
  (* mark_debug = "true" *) logic          HMASTLOCK;

  // GPIO Signals
  logic [31:0]      GPIOIN, GPIOOUT, GPIOEN;

  // AHB to AXI Bridge Signals
  (* mark_debug = "true" *) logic [3:0]      m_axi_awid;
  (* mark_debug = "true" *) logic [7:0]      m_axi_awlen;
  (* mark_debug = "true" *) logic [2:0]      m_axi_awsize;
  (* mark_debug = "true" *) logic [1:0]      m_axi_awburst;
  (* mark_debug = "true" *) logic [3:0]      m_axi_awcache;
  (* mark_debug = "true" *) logic [31:0]      m_axi_awaddr;
  (* mark_debug = "true" *) logic [2:0]      m_axi_awprot;
  (* mark_debug = "true" *) logic             m_axi_awvalid;
  (* mark_debug = "true" *) logic             m_axi_awready;
  (* mark_debug = "true" *) logic             m_axi_awlock;
  (* mark_debug = "true" *) logic [P.AHBW-1:0]      m_axi_wdata;
  (* mark_debug = "true" *) logic [STRB_W-1:0]      m_axi_wstrb;
  (* mark_debug = "true" *) logic             m_axi_wlast;
  (* mark_debug = "true" *) logic             m_axi_wvalid;
  (* mark_debug = "true" *) logic             m_axi_wready;
  (* mark_debug = "true" *) logic [3:0]      m_axi_bid;
  (* mark_debug = "true" *) logic [1:0]      m_axi_bresp;
  (* mark_debug = "true" *) logic             m_axi_bvalid;
  (* mark_debug = "true" *) logic             m_axi_bready;
  (* mark_debug = "true" *) logic [3:0]      m_axi_arid;
  (* mark_debug = "true" *) logic [7:0]      m_axi_arlen;
  (* mark_debug = "true" *) logic [2:0]      m_axi_arsize;
  (* mark_debug = "true" *) logic [1:0]      m_axi_arburst;
  (* mark_debug = "true" *) logic [2:0]      m_axi_arprot;
  (* mark_debug = "true" *) logic [3:0]      m_axi_arcache;
  (* mark_debug = "true" *) logic             m_axi_arvalid;
  (* mark_debug = "true" *) logic [31:0]      m_axi_araddr;
  (* mark_debug = "true" *) logic          m_axi_arlock;
  (* mark_debug = "true" *) logic             m_axi_arready;
  (* mark_debug = "true" *) logic [3:0]      m_axi_rid;
  (* mark_debug = "true" *) logic [P.AHBW-1:0]      m_axi_rdata;
  (* mark_debug = "true" *) logic [1:0]      m_axi_rresp;
  (* mark_debug = "true" *) logic             m_axi_rvalid;
  (* mark_debug = "true" *) logic             m_axi_rlast;
  (* mark_debug = "true" *) logic             m_axi_rready;

  // AXI Signals going out of Clock Converter
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_arregion;
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_arqos;
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_awregion;
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_awqos;
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_awid;
  (* mark_debug = "true" *) logic [7:0]      BUS_axi_awlen;
  (* mark_debug = "true" *) logic [2:0]      BUS_axi_awsize;
  (* mark_debug = "true" *) logic [1:0]      BUS_axi_awburst;
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_awcache;
  (* mark_debug = "true" *) logic [31:0]      BUS_axi_awaddr;
  (* mark_debug = "true" *) logic [2:0]      BUS_axi_awprot;
  (* mark_debug = "true" *) logic          BUS_axi_awvalid;
  (* mark_debug = "true" *) logic          BUS_axi_awready;
  (* mark_debug = "true" *) logic          BUS_axi_awlock;
  (* mark_debug = "true" *) logic [P.AHBW-1:0]      BUS_axi_wdata;
  (* mark_debug = "true" *) logic [STRB_W-1:0]      BUS_axi_wstrb;
  (* mark_debug = "true" *) logic          BUS_axi_wlast;
  (* mark_debug = "true" *) logic          BUS_axi_wvalid;
  (* mark_debug = "true" *) logic          BUS_axi_wready;
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_bid;
  (* mark_debug = "true" *) logic [1:0]      BUS_axi_bresp;
  (* mark_debug = "true" *) logic          BUS_axi_bvalid;
  (* mark_debug = "true" *) logic          BUS_axi_bready;
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_arid;
  (* mark_debug = "true" *) logic [7:0]      BUS_axi_arlen;
  (* mark_debug = "true" *) logic [2:0]      BUS_axi_arsize;
  (* mark_debug = "true" *) logic [1:0]      BUS_axi_arburst;
  (* mark_debug = "true" *) logic [2:0]      BUS_axi_arprot;
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_arcache;
  (* mark_debug = "true" *) logic          BUS_axi_arvalid;
  (* mark_debug = "true" *) logic [31:0]      BUS_axi_araddr;
  (* mark_debug = "true" *) logic          BUS_axi_arlock;
  (* mark_debug = "true" *) logic          BUS_axi_arready;
  (* mark_debug = "true" *) logic [3:0]      BUS_axi_rid;
  (* mark_debug = "true" *) logic [P.AHBW-1:0]      BUS_axi_rdata;
  (* mark_debug = "true" *) logic [1:0]      BUS_axi_rresp;
  (* mark_debug = "true" *) logic          BUS_axi_rvalid;
  (* mark_debug = "true" *) logic          BUS_axi_rlast;
  (* mark_debug = "true" *) logic          BUS_axi_rready;

  // AXI master Signals going out of Clock Converter (MIG-facing, M00 slice)
  (* mark_debug = "true" *) logic [3:0]      BUS_cb_axi_arregion;
  (* mark_debug = "true" *) logic [3:0]      BUS_cb_axi_arqos;
  (* mark_debug = "true" *) logic [3:0]      BUS_cb_axi_awregion;
  (* mark_debug = "true" *) logic [3:0]      BUS_cb_axi_awqos;
  (* mark_debug = "true" *) logic [DDR_ID_W-1:0]      BUS_cb_axi_awid;
  (* mark_debug = "true" *) logic [7:0]      BUS_cb_axi_awlen;
  (* mark_debug = "true" *) logic [2:0]      BUS_cb_axi_awsize;
  (* mark_debug = "true" *) logic [1:0]      BUS_cb_axi_awburst;
  (* mark_debug = "true" *) logic [3:0]      BUS_cb_axi_awcache;
  (* mark_debug = "true" *) logic [31:0]     BUS_cb_axi_awaddr;
  (* mark_debug = "true" *) logic [2:0]      BUS_cb_axi_awprot;
  (* mark_debug = "true" *) logic            BUS_cb_axi_awvalid;
  (* mark_debug = "true" *) logic            BUS_cb_axi_awready;
  (* mark_debug = "true" *) logic            BUS_cb_axi_awlock;
  (* mark_debug = "true" *) logic [P.AHBW-1:0]     BUS_cb_axi_wdata;
  (* mark_debug = "true" *) logic [STRB_W-1:0]      BUS_cb_axi_wstrb;
  (* mark_debug = "true" *) logic            BUS_cb_axi_wlast;
  (* mark_debug = "true" *) logic            BUS_cb_axi_wvalid;
  (* mark_debug = "true" *) logic            BUS_cb_axi_wready;
  (* mark_debug = "true" *) logic [DDR_ID_W-1:0]      BUS_cb_axi_bid;
  (* mark_debug = "true" *) logic [1:0]      BUS_cb_axi_bresp;
  (* mark_debug = "true" *) logic            BUS_cb_axi_bvalid;
  (* mark_debug = "true" *) logic            BUS_cb_axi_bready;
  (* mark_debug = "true" *) logic [DDR_ID_W-1:0]      BUS_cb_axi_arid;
  (* mark_debug = "true" *) logic [7:0]      BUS_cb_axi_arlen;
  (* mark_debug = "true" *) logic [2:0]      BUS_cb_axi_arsize;
  (* mark_debug = "true" *) logic [1:0]      BUS_cb_axi_arburst;
  (* mark_debug = "true" *) logic [2:0]      BUS_cb_axi_arprot;
  (* mark_debug = "true" *) logic [3:0]      BUS_cb_axi_arcache;
  (* mark_debug = "true" *) logic            BUS_cb_axi_arvalid;
  (* mark_debug = "true" *) logic [31:0]     BUS_cb_axi_araddr;
  (* mark_debug = "true" *) logic            BUS_cb_axi_arlock;
  (* mark_debug = "true" *) logic            BUS_cb_axi_arready;
  (* mark_debug = "true" *) logic [DDR_ID_W-1:0]      BUS_cb_axi_rid;
  (* mark_debug = "true" *) logic [P.AHBW-1:0]     BUS_cb_axi_rdata;
  (* mark_debug = "true" *) logic [1:0]      BUS_cb_axi_rresp;
  (* mark_debug = "true" *) logic            BUS_cb_axi_rvalid;
  (* mark_debug = "true" *) logic            BUS_cb_axi_rlast;
  (* mark_debug = "true" *) logic            BUS_cb_axi_rready;

  // Crossbar packed M_AXI ports
  // Crossbar uses ADDR_WIDTH=32, DATA_WIDTH=DATA_W, ID_WIDTH=4
  // NUM_MI=7 => M00=DDR, M01=CDMA, M02=VGA, M03=USB, M04=LiteEth, M05=LiteDRAM CSR, M06=SDHCI.
  (* mark_debug = "true" *) wire [N_MST*MST_ID_W-1:0]      cb_m_axi_awid;
  (* mark_debug = "true" *) wire [N_MST*ADDR_W-1:0]        cb_m_axi_awaddr;
  (* mark_debug = "true" *) wire [N_MST*AXI_LEN_W-1:0]     cb_m_axi_awlen;
  (* mark_debug = "true" *) wire [N_MST*AXI_SIZE_W-1:0]    cb_m_axi_awsize;
  (* mark_debug = "true" *) wire [N_MST*AXI_BURST_W-1:0]   cb_m_axi_awburst;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_awlock;
  (* mark_debug = "true" *) wire [N_MST*AXI_CACHE_W-1:0]   cb_m_axi_awcache;
  (* mark_debug = "true" *) wire [N_MST*AXI_PROT_W-1:0]    cb_m_axi_awprot;
  (* mark_debug = "true" *) wire [N_MST*AXI_QOS_W-1:0]        cb_m_axi_awregion;
  (* mark_debug = "true" *) wire [N_MST*AXI_QOS_W-1:0]     cb_m_axi_awqos;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_awvalid;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_awready;

  (* mark_debug = "true" *) wire [N_MST*DATA_W-1:0]  cb_m_axi_wdata;
  (* mark_debug = "true" *) wire [N_MST*STRB_W-1:0]   cb_m_axi_wstrb;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_wlast;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_wvalid;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_wready;

  (* mark_debug = "true" *) wire [N_MST*MST_ID_W-1:0]      cb_m_axi_bid;
  (* mark_debug = "true" *) wire [N_MST*AXI_RESP_W-1:0]    cb_m_axi_bresp;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_bvalid;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_bready;

  (* mark_debug = "true" *) wire [N_MST*MST_ID_W-1:0]      cb_m_axi_arid;
  (* mark_debug = "true" *) wire [N_MST*ADDR_W-1:0]        cb_m_axi_araddr;
  (* mark_debug = "true" *) wire [N_MST*AXI_LEN_W-1:0]     cb_m_axi_arlen;
  (* mark_debug = "true" *) wire [N_MST*AXI_SIZE_W-1:0]    cb_m_axi_arsize;
  (* mark_debug = "true" *) wire [N_MST*AXI_BURST_W-1:0]   cb_m_axi_arburst;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_arlock;
  (* mark_debug = "true" *) wire [N_MST*AXI_CACHE_W-1:0]   cb_m_axi_arcache;
  (* mark_debug = "true" *) wire [N_MST*AXI_PROT_W-1:0]    cb_m_axi_arprot;
  (* mark_debug = "true" *) wire [N_MST*AXI_QOS_W-1:0]        cb_m_axi_arregion;
  (* mark_debug = "true" *) wire [N_MST*AXI_QOS_W-1:0]     cb_m_axi_arqos;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_arvalid;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_arready;

  (* mark_debug = "true" *) wire [N_MST*MST_ID_W-1:0]      cb_m_axi_rid;
  (* mark_debug = "true" *) wire [N_MST*DATA_W-1:0]  cb_m_axi_rdata;
  (* mark_debug = "true" *) wire [N_MST*AXI_RESP_W-1:0]    cb_m_axi_rresp;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_rlast;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_rvalid;
  (* mark_debug = "true" *) wire [N_MST-1:0]                  cb_m_axi_rready;

  // Crossbar packed S_AXI ports
  // NUM_SI=4 (S00=CPU, S01=CDMA, S02=VGA, S03=USB OHCI DMA)
  (* mark_debug = "true" *) wire [N_SLV*MST_ID_W-1:0]      cb_s_axi_awid;
  (* mark_debug = "true" *) wire [N_SLV*ADDR_W-1:0]        cb_s_axi_awaddr;
  (* mark_debug = "true" *) wire [N_SLV*AXI_LEN_W-1:0]     cb_s_axi_awlen;
  (* mark_debug = "true" *) wire [N_SLV*AXI_SIZE_W-1:0]    cb_s_axi_awsize;
  (* mark_debug = "true" *) wire [N_SLV*AXI_BURST_W-1:0]   cb_s_axi_awburst;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_awlock;
  (* mark_debug = "true" *) wire [N_SLV*AXI_CACHE_W-1:0]   cb_s_axi_awcache;
  (* mark_debug = "true" *) wire [N_SLV*AXI_PROT_W-1:0]    cb_s_axi_awprot;
  (* mark_debug = "true" *) wire [N_SLV*AXI_QOS_W-1:0]     cb_s_axi_awqos;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_awvalid;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_awready;

  (* mark_debug = "true" *) wire [N_SLV*DATA_W-1:0] cb_s_axi_wdata;
  (* mark_debug = "true" *) wire [N_SLV*STRB_W-1:0]  cb_s_axi_wstrb;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_wlast;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_wvalid;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_wready;

  (* mark_debug = "true" *) wire [N_SLV*MST_ID_W-1:0]      cb_s_axi_bid;
  (* mark_debug = "true" *) wire [N_SLV*AXI_RESP_W-1:0]    cb_s_axi_bresp;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_bvalid;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_bready;

  (* mark_debug = "true" *) wire [N_SLV*MST_ID_W-1:0]      cb_s_axi_arid;
  (* mark_debug = "true" *) wire [N_SLV*ADDR_W-1:0]        cb_s_axi_araddr;
  (* mark_debug = "true" *) wire [N_SLV*AXI_LEN_W-1:0]     cb_s_axi_arlen;
  (* mark_debug = "true" *) wire [N_SLV*AXI_SIZE_W-1:0]    cb_s_axi_arsize;
  (* mark_debug = "true" *) wire [N_SLV*AXI_BURST_W-1:0]   cb_s_axi_arburst;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_arlock;
  (* mark_debug = "true" *) wire [N_SLV*AXI_CACHE_W-1:0]   cb_s_axi_arcache;
  (* mark_debug = "true" *) wire [N_SLV*AXI_PROT_W-1:0]    cb_s_axi_arprot;
  (* mark_debug = "true" *) wire [N_SLV*AXI_QOS_W-1:0]     cb_s_axi_arqos;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_arvalid;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_arready;

  (* mark_debug = "true" *) wire [N_SLV*MST_ID_W-1:0]      cb_s_axi_rid;
  (* mark_debug = "true" *) wire [N_SLV*DATA_W-1:0] cb_s_axi_rdata;
  (* mark_debug = "true" *) wire [N_SLV*AXI_RESP_W-1:0]    cb_s_axi_rresp;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_rlast;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_rvalid;
  (* mark_debug = "true" *) wire [N_SLV-1:0]                  cb_s_axi_rready;

// AXI CDMA M_AXI (master into crossbar S01)
  logic [SLV_ID_W-1:0]  cdma_m_axi_awid;
  logic [31:0] cdma_m_axi_awaddr;
  logic [7:0]  cdma_m_axi_awlen;
  logic [2:0]  cdma_m_axi_awsize;
  logic [1:0]  cdma_m_axi_awburst;
  logic        cdma_m_axi_awlock;
  logic [3:0]  cdma_m_axi_awcache;
  logic [2:0]  cdma_m_axi_awprot;
  logic        cdma_m_axi_awvalid;
  logic        cdma_m_axi_awready;
  logic [P.AHBW-1:0] cdma_m_axi_wdata;
  logic [STRB_W-1:0]  cdma_m_axi_wstrb;
  logic        cdma_m_axi_wlast;
  logic        cdma_m_axi_wvalid;
  logic        cdma_m_axi_wready;
  logic [MST_ID_W-1:0]  cdma_m_axi_bid;
  logic [1:0]  cdma_m_axi_bresp;
  logic        cdma_m_axi_bvalid;
  logic        cdma_m_axi_bready;
  logic [SLV_ID_W-1:0]  cdma_m_axi_arid;
  logic [31:0] cdma_m_axi_araddr;
  logic [7:0]  cdma_m_axi_arlen;
  logic [2:0]  cdma_m_axi_arsize;
  logic [1:0]  cdma_m_axi_arburst;
  logic        cdma_m_axi_arlock;
  logic [3:0]  cdma_m_axi_arcache;
  logic [2:0]  cdma_m_axi_arprot;
  logic        cdma_m_axi_arvalid;
  logic        cdma_m_axi_arready;
  logic [MST_ID_W-1:0]  cdma_m_axi_rid;
  logic [P.AHBW-1:0] cdma_m_axi_rdata;
  logic [1:0]  cdma_m_axi_rresp;
  logic        cdma_m_axi_rlast;
  logic        cdma_m_axi_rvalid;
  logic        cdma_m_axi_rready;


  // AXI VGA scanout M_AXI (master into crossbar S02)
  logic [SLV_ID_W-1:0]  vga_m_axi_awid;
  logic [31:0] vga_m_axi_awaddr;
  logic [7:0]  vga_m_axi_awlen;
  logic [2:0]  vga_m_axi_awsize;
  logic [1:0]  vga_m_axi_awburst;
  logic        vga_m_axi_awlock;
  logic [3:0]  vga_m_axi_awcache;
  logic [2:0]  vga_m_axi_awprot;
  logic        vga_m_axi_awvalid;
  logic        vga_m_axi_awready;

  logic [P.AHBW-1:0] vga_m_axi_wdata;
  logic [STRB_W-1:0]  vga_m_axi_wstrb;
  logic        vga_m_axi_wlast;
  logic        vga_m_axi_wvalid;
  logic        vga_m_axi_wready;

  logic [SLV_ID_W-1:0]  vga_m_axi_bid;
  logic [1:0]  vga_m_axi_bresp;
  logic        vga_m_axi_bvalid;
  logic        vga_m_axi_bready;

  logic [SLV_ID_W-1:0]  vga_m_axi_arid;
  logic [31:0] vga_m_axi_araddr;
  logic [7:0]  vga_m_axi_arlen;
  logic [2:0]  vga_m_axi_arsize;
  logic [1:0]  vga_m_axi_arburst;
  logic        vga_m_axi_arlock;
  logic [3:0]  vga_m_axi_arcache;
  logic [2:0]  vga_m_axi_arprot;
  logic        vga_m_axi_arvalid;
  logic        vga_m_axi_arready;

  logic [SLV_ID_W-1:0]  vga_m_axi_rid;
  logic [P.AHBW-1:0] vga_m_axi_rdata;
  logic [1:0]  vga_m_axi_rresp;
  logic        vga_m_axi_rlast;
  logic        vga_m_axi_rvalid;
  logic        vga_m_axi_rready;

    // USB OHCI DMA M_AXI (master into crossbar S03)
  (* mark_debug = "true" *) logic [SLV_ID_W-1:0]  usb_m_axi_awid;
  (* mark_debug = "true" *) logic [31:0] usb_m_axi_awaddr;
  (* mark_debug = "true" *) logic [7:0]  usb_m_axi_awlen;
  (* mark_debug = "true" *) logic [2:0]  usb_m_axi_awsize;
  (* mark_debug = "true" *) logic [1:0]  usb_m_axi_awburst;
  (* mark_debug = "true" *) logic        usb_m_axi_awlock;
  (* mark_debug = "true" *) logic [3:0]  usb_m_axi_awcache;
  (* mark_debug = "true" *) logic [2:0]  usb_m_axi_awprot;
  (* mark_debug = "true" *) logic        usb_m_axi_awvalid;
  (* mark_debug = "true" *) logic        usb_m_axi_awready;

  (* mark_debug = "true" *) logic [P.AHBW-1:0] usb_m_axi_wdata;
  (* mark_debug = "true" *) logic [STRB_W-1:0]  usb_m_axi_wstrb;
  (* mark_debug = "true" *) logic        usb_m_axi_wlast;
  (* mark_debug = "true" *) logic        usb_m_axi_wvalid;
  (* mark_debug = "true" *) logic        usb_m_axi_wready;

  (* mark_debug = "true" *) logic [SLV_ID_W-1:0]  usb_m_axi_bid;
  (* mark_debug = "true" *) logic [1:0]  usb_m_axi_bresp;
  (* mark_debug = "true" *) logic        usb_m_axi_bvalid;
  (* mark_debug = "true" *) logic        usb_m_axi_bready;

  (* mark_debug = "true" *) logic [SLV_ID_W-1:0]  usb_m_axi_arid;
  (* mark_debug = "true" *) logic [31:0] usb_m_axi_araddr;
  (* mark_debug = "true" *) logic [7:0]  usb_m_axi_arlen;
  (* mark_debug = "true" *) logic [2:0]  usb_m_axi_arsize;
  (* mark_debug = "true" *) logic [1:0]  usb_m_axi_arburst;
  (* mark_debug = "true" *) logic        usb_m_axi_arlock;
  (* mark_debug = "true" *) logic [3:0]  usb_m_axi_arcache;
  (* mark_debug = "true" *) logic [2:0]  usb_m_axi_arprot;
  (* mark_debug = "true" *) logic        usb_m_axi_arvalid;
  (* mark_debug = "true" *) logic        usb_m_axi_arready;

  (* mark_debug = "true" *) logic [SLV_ID_W-1:0]  usb_m_axi_rid;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] usb_m_axi_rdata;
  (* mark_debug = "true" *) logic [1:0]  usb_m_axi_rresp;
  (* mark_debug = "true" *) logic        usb_m_axi_rlast;
  (* mark_debug = "true" *) logic        usb_m_axi_rvalid;
  (* mark_debug = "true" *) logic        usb_m_axi_rready;

  logic        usb_irq;

  logic        liteeth_irq;
  logic        sdhci_irq;

  // Regs window path (M01) signals from dwidth converter back to crossbar
  wire        reg_awready;
  wire        reg_wready;
  wire        reg_arready;
  wire        reg_bvalid;
  wire [1:0]  reg_bresp;
  wire [MST_ID_W-1:0]  reg_bid;
  wire        reg_rvalid;
  wire        reg_rlast;
  wire [1:0]  reg_rresp;
  wire [MST_ID_W-1:0]  reg_rid;
  wire [P.AHBW-1:0] reg_rdata;

  // VGA regs window path (M02) signals back to crossbar
  wire        vga_reg_awready;
  wire        vga_reg_wready;
  wire        vga_reg_arready;
  wire        vga_reg_bvalid;
  wire [1:0]  vga_reg_bresp;
  wire [MST_ID_W-1:0]  vga_reg_bid;
  wire        vga_reg_rvalid;
  wire        vga_reg_rlast;
  wire [1:0]  vga_reg_rresp;
  wire [MST_ID_W-1:0]  vga_reg_rid;
  wire [P.AHBW-1:0] vga_reg_rdata;

  // USB regs window path (M03) signals back to crossbar
  wire        usb_reg_awready;
  wire        usb_reg_wready;
  wire        usb_reg_arready;
  wire        usb_reg_bvalid;
  wire [1:0]  usb_reg_bresp;
  wire [MST_ID_W-1:0]  usb_reg_bid;
  wire        usb_reg_rvalid;
  wire        usb_reg_rlast;
  wire [1:0]  usb_reg_rresp;
  wire [MST_ID_W-1:0]  usb_reg_rid;
  wire [P.AHBW-1:0] usb_reg_rdata;

  // USB regs window path (M03) signals back to crossbar
  wire        liteeth_reg_awready;
  wire        liteeth_reg_wready;
  wire        liteeth_reg_arready;
  wire        liteeth_reg_bvalid;
  wire [1:0]  liteeth_reg_bresp;
  wire [MST_ID_W-1:0]  liteeth_reg_bid;
  wire        liteeth_reg_rvalid;
  wire        liteeth_reg_rlast;
  wire [1:0]  liteeth_reg_rresp;
  wire [MST_ID_W-1:0]  liteeth_reg_rid;
  wire [P.AHBW-1:0] liteeth_reg_rdata;

  // LiteDRAM CSR path (M05) signals back to crossbar — declared at module level
  // so they are visible in the module-level cb_m_axi_* concatenations.
  // Driven by u_axi64_to_axil_dram when LITEDRAM_SUPPORTED=1; tied to 0 otherwise.
  logic        litedram_axi_awready;
  logic        litedram_axi_wready;
  logic        litedram_axi_arready;
  logic        litedram_axi_bvalid;
  logic [1:0]  litedram_axi_bresp;
  logic [MST_ID_W-1:0]  litedram_axi_bid;
  logic        litedram_axi_rvalid;
  logic        litedram_axi_rlast;
  logic [1:0]  litedram_axi_rresp;
  logic [MST_ID_W-1:0]  litedram_axi_rid;
  logic [P.AHBW-1:0] litedram_axi_rdata;

  // SDHCI regs window path (M06) signals back to crossbar.
  logic        sdhci_reg_awready;
  logic        sdhci_reg_wready;
  logic        sdhci_reg_arready;
  logic        sdhci_reg_bvalid;
  logic [1:0]  sdhci_reg_bresp;
  logic [MST_ID_W-1:0]  sdhci_reg_bid;
  logic        sdhci_reg_rvalid;
  logic        sdhci_reg_rlast;
  logic [1:0]  sdhci_reg_rresp;
  logic [MST_ID_W-1:0]  sdhci_reg_rid;
  logic [P.AHBW-1:0] sdhci_reg_rdata;

  (* mark_debug = "true" *) logic        sd_clk_o;
  (* mark_debug = "true" *) logic        sd_cd_ni;
  (* mark_debug = "true" *) logic        sd_cmd_en;
  (* mark_debug = "true" *) logic        sd_cmd_o;
  (* mark_debug = "true" *) logic        sd_cmd_i;
  (* mark_debug = "true" *) logic        sd_dat_en;
  (* mark_debug = "true" *) logic [3:0]  sd_dat_o;
  (* mark_debug = "true" *) logic [3:0]  sd_dat_i;

  // AXI4-Lite/32 signals to USB OHCI control regs (driven by MMIO bridge)
  wire [31:0] usb_lite_awaddr;
  wire [2:0]  usb_lite_awprot;
  wire        usb_lite_awvalid;
  wire        usb_lite_awready;
  wire [31:0] usb_lite_wdata;
  wire [3:0]  usb_lite_wstrb;
  wire        usb_lite_wvalid;
  wire        usb_lite_wready;
  wire [1:0]  usb_lite_bresp;
  wire        usb_lite_bvalid;
  wire        usb_lite_bready;
  wire [31:0] usb_lite_araddr;
  wire [2:0]  usb_lite_arprot;
  wire        usb_lite_arvalid;
  wire        usb_lite_arready;
  wire [31:0] usb_lite_rdata;
  wire [1:0]  usb_lite_rresp;
  wire        usb_lite_rvalid;
  wire        usb_lite_rready;

  // AXI4/32 signals (AXI-Lite subset) towards usb_ohci_wrap (control interface)
  wire [7:0]  usb_ctrl_awid;
  wire [11:0] usb_ctrl_awaddr;
  wire [7:0]  usb_ctrl_awlen;
  wire [2:0]  usb_ctrl_awsize;
  wire [1:0]  usb_ctrl_awburst;
  wire        usb_ctrl_awlock;
  wire [3:0]  usb_ctrl_awcache;
  wire [2:0]  usb_ctrl_awprot;
  wire [3:0]  usb_ctrl_awqos;
  wire        usb_ctrl_awvalid;
  wire        usb_ctrl_awready;

  wire [31:0] usb_ctrl_wdata;
  wire [3:0]  usb_ctrl_wstrb;
  wire        usb_ctrl_wlast;
  wire        usb_ctrl_wvalid;
  wire        usb_ctrl_wready;

  wire [7:0]  usb_ctrl_bid;
  wire [1:0]  usb_ctrl_bresp;
  wire        usb_ctrl_bvalid;
  wire        usb_ctrl_bready;

  wire [7:0]  usb_ctrl_arid;
  wire [11:0] usb_ctrl_araddr;
  wire [7:0]  usb_ctrl_arlen;
  wire [2:0]  usb_ctrl_arsize;
  wire [1:0]  usb_ctrl_arburst;
  wire        usb_ctrl_arlock;
  wire [3:0]  usb_ctrl_arcache;
  wire [2:0]  usb_ctrl_arprot;
  wire [3:0]  usb_ctrl_arqos;
  wire        usb_ctrl_arvalid;
  wire        usb_ctrl_arready;

  wire [7:0]  usb_ctrl_rid;
  wire [31:0] usb_ctrl_rdata;
  wire [1:0]  usb_ctrl_rresp;
  wire        usb_ctrl_rlast;
  wire        usb_ctrl_rvalid;
  wire        usb_ctrl_rready;


  logic [4:0] vga_r_5_internal;
  logic [5:0] vga_g_6_internal;
  logic [4:0] vga_b_5_internal;

  // no need to truncate for Genesys2
  assign vga_r_5 = vga_r_5_internal[4:0];
  assign vga_g_6 = vga_g_6_internal[5:0];
  assign vga_b_5 = vga_b_5_internal[4:0];

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

  (* mark_debug = "true" *) logic       dma_irq_raw;
  logic       dma_introut_sync;
  logic       axi_dma_intr_sync;
  (* ASYNC_REG="TRUE" *) logic [1:0] dma_irq_sync;
  logic      usb_phy_resetn_sync;


  // IMPORTANT: the generated AXI CDMA instance in this project is an ID-less / lock-less AXI master.
  // It does not expose m_axi_awid/arid/bid/rid nor m_axi_awlock/arlock ports.
  // To satisfy the crossbar source-port ID sideband, drive those missing IDs to 0.
  assign cdma_m_axi_awid   = '0;
  assign cdma_m_axi_arid   = '0;
  assign cdma_m_axi_awlock = 1'b0;
  assign cdma_m_axi_arlock = 1'b0;

  // USB OHCI control interface: adapt AXI4-Lite/32 to AXI4/32 (AXI-Lite subset)
  assign usb_ctrl_awaddr  = usb_lite_awaddr[11:0];
  assign usb_ctrl_awprot  = usb_lite_awprot;
  assign usb_ctrl_awvalid = usb_lite_awvalid;
  assign usb_lite_awready = usb_ctrl_awready;
  assign usb_ctrl_awid    = 8'h00;
  assign usb_ctrl_awlen   = 8'h00;
  assign usb_ctrl_awsize  = 3'b010;  // 4 bytes
  assign usb_ctrl_awburst = 2'b01;   // INCR
  assign usb_ctrl_awlock  = 1'b0;
  assign usb_ctrl_awcache = 4'b0000;
  assign usb_ctrl_awqos   = 4'b0000;

  assign usb_ctrl_wdata   = usb_lite_wdata;
  assign usb_ctrl_wstrb   = usb_lite_wstrb;
  assign usb_ctrl_wlast   = 1'b1;
  assign usb_ctrl_wvalid  = usb_lite_wvalid;
  assign usb_lite_wready  = usb_ctrl_wready;

  assign usb_lite_bresp   = usb_ctrl_bresp;
  assign usb_lite_bvalid  = usb_ctrl_bvalid;
  assign usb_ctrl_bready  = usb_lite_bready;

  assign usb_ctrl_araddr  = usb_lite_araddr[11:0];
  assign usb_ctrl_arprot  = usb_lite_arprot;
  assign usb_ctrl_arvalid = usb_lite_arvalid;
  assign usb_lite_arready = usb_ctrl_arready;
  assign usb_ctrl_arid    = 8'h00;
  assign usb_ctrl_arlen   = 8'h00;
  assign usb_ctrl_arsize  = 3'b010;  // 4 bytes
  assign usb_ctrl_arburst = 2'b01;   // INCR
  assign usb_ctrl_arlock  = 1'b0;
  assign usb_ctrl_arcache = 4'b0000;
  assign usb_ctrl_arqos   = 4'b0000;

  assign usb_lite_rdata   = usb_ctrl_rdata;
  assign usb_lite_rresp   = usb_ctrl_rresp;
  assign usb_lite_rvalid  = usb_ctrl_rvalid;
  assign usb_ctrl_rready  = usb_lite_rready;

  // Crossbar M00 -> MIG (BUS_cb_*)
  assign BUS_cb_axi_awid    = cb_m_axi_awid[CB_M_DDR*MST_ID_W +: MST_ID_W];
  assign BUS_cb_axi_awaddr  = cb_m_axi_awaddr[CB_M_DDR*ADDR_W +: DDR_ADDR_BITS]; // DDR size dependent (dropping higher order bits)
  assign BUS_cb_axi_awlen   = cb_m_axi_awlen[CB_M_DDR*AXI_LEN_W +: AXI_LEN_W];
  assign BUS_cb_axi_awsize  = cb_m_axi_awsize[CB_M_DDR*AXI_SIZE_W +: AXI_SIZE_W];
  assign BUS_cb_axi_awburst = cb_m_axi_awburst[CB_M_DDR*AXI_BURST_W +: AXI_BURST_W];
  assign BUS_cb_axi_awlock  = cb_m_axi_awlock[CB_M_DDR];
  assign BUS_cb_axi_awcache = cb_m_axi_awcache[CB_M_DDR*AXI_CACHE_W +: AXI_CACHE_W];
  assign BUS_cb_axi_awprot  = cb_m_axi_awprot[CB_M_DDR*AXI_PROT_W +: AXI_PROT_W];
  assign BUS_cb_axi_awqos   = cb_m_axi_awqos[CB_M_DDR*AXI_QOS_W +: AXI_QOS_W];
  assign BUS_cb_axi_awvalid = cb_m_axi_awvalid[CB_M_DDR];

  assign BUS_cb_axi_wdata   = cb_m_axi_wdata[CB_M_DDR*DATA_W +: DATA_W];
  assign BUS_cb_axi_wstrb   = cb_m_axi_wstrb[CB_M_DDR*STRB_W +: STRB_W];
  assign BUS_cb_axi_wlast   = cb_m_axi_wlast[CB_M_DDR];
  assign BUS_cb_axi_wvalid  = cb_m_axi_wvalid[CB_M_DDR];

  assign BUS_cb_axi_bready  = cb_m_axi_bready[CB_M_DDR];

  assign BUS_cb_axi_arid    = cb_m_axi_arid[CB_M_DDR*MST_ID_W +: MST_ID_W];
  assign BUS_cb_axi_araddr  = cb_m_axi_araddr[CB_M_DDR*ADDR_W +: DDR_ADDR_BITS]; // DDR size dependent (dropping higher order bits)
  assign BUS_cb_axi_arlen   = cb_m_axi_arlen[CB_M_DDR*AXI_LEN_W +: AXI_LEN_W];
  assign BUS_cb_axi_arsize  = cb_m_axi_arsize[CB_M_DDR*AXI_SIZE_W +: AXI_SIZE_W];
  assign BUS_cb_axi_arburst = cb_m_axi_arburst[CB_M_DDR*AXI_BURST_W +: AXI_BURST_W];
  assign BUS_cb_axi_arlock  = cb_m_axi_arlock[CB_M_DDR];
  assign BUS_cb_axi_arcache = cb_m_axi_arcache[CB_M_DDR*AXI_CACHE_W +: AXI_CACHE_W];
  assign BUS_cb_axi_arprot  = cb_m_axi_arprot[CB_M_DDR*AXI_PROT_W +: AXI_PROT_W];
  assign BUS_cb_axi_arqos   = cb_m_axi_arqos[CB_M_DDR*AXI_QOS_W +: AXI_QOS_W];
  assign BUS_cb_axi_arvalid = cb_m_axi_arvalid[CB_M_DDR];

  assign BUS_cb_axi_rready  = cb_m_axi_rready[CB_M_DDR];

  // Crossbar source-port thread IDs are SLV_ID_W bits; the xbar adds the port tag internally.
  assign cb_s_axi_awid[CB_S_CPU*MST_ID_W +: MST_ID_W]  = {{(MST_ID_W-SLV_ID_W){1'b0}}, BUS_axi_awid[SLV_ID_W-1:0]};
  assign cb_s_axi_awaddr[CB_S_CPU*ADDR_W +: ADDR_W]  = BUS_axi_awaddr;
  assign cb_s_axi_awlen[CB_S_CPU*AXI_LEN_W +: AXI_LEN_W]  = BUS_axi_awlen;
  assign cb_s_axi_awsize[CB_S_CPU*AXI_SIZE_W +: AXI_SIZE_W]  = BUS_axi_awsize;
  assign cb_s_axi_awburst[CB_S_CPU*AXI_BURST_W +: AXI_BURST_W]  = BUS_axi_awburst;
  assign cb_s_axi_awlock[CB_S_CPU]  = BUS_axi_awlock;
  assign cb_s_axi_awcache[CB_S_CPU*AXI_CACHE_W +: AXI_CACHE_W]  = BUS_axi_awcache;
  assign cb_s_axi_awprot[CB_S_CPU*AXI_PROT_W +: AXI_PROT_W]  = BUS_axi_awprot;
  assign cb_s_axi_awqos[CB_S_CPU*AXI_QOS_W +: AXI_QOS_W]  = BUS_axi_awqos;
  assign cb_s_axi_awvalid[CB_S_CPU]  = BUS_axi_awvalid;
  assign cb_s_axi_wdata[CB_S_CPU*DATA_W  +: DATA_W] = BUS_axi_wdata;
  assign cb_s_axi_wstrb[CB_S_CPU*STRB_W  +: STRB_W] = BUS_axi_wstrb;
  assign cb_s_axi_wlast[CB_S_CPU]  = BUS_axi_wlast;
  assign cb_s_axi_wvalid[CB_S_CPU]  = BUS_axi_wvalid;
  assign cb_s_axi_bready[CB_S_CPU]  = BUS_axi_bready;
  assign cb_s_axi_arid[CB_S_CPU*MST_ID_W +: MST_ID_W]  = {{(MST_ID_W-SLV_ID_W){1'b0}}, BUS_axi_arid[SLV_ID_W-1:0]};
  assign cb_s_axi_araddr[CB_S_CPU*ADDR_W +: ADDR_W]  = BUS_axi_araddr;
  assign cb_s_axi_arlen[CB_S_CPU*AXI_LEN_W +: AXI_LEN_W]  = BUS_axi_arlen;
  assign cb_s_axi_arsize[CB_S_CPU*AXI_SIZE_W +: AXI_SIZE_W]  = BUS_axi_arsize;
  assign cb_s_axi_arburst[CB_S_CPU*AXI_BURST_W +: AXI_BURST_W]  = BUS_axi_arburst;
  assign cb_s_axi_arlock[CB_S_CPU]  = BUS_axi_arlock;
  assign cb_s_axi_arcache[CB_S_CPU*AXI_CACHE_W +: AXI_CACHE_W]  = BUS_axi_arcache;
  assign cb_s_axi_arprot[CB_S_CPU*AXI_PROT_W +: AXI_PROT_W]  = BUS_axi_arprot;
  assign cb_s_axi_arqos[CB_S_CPU*AXI_QOS_W +: AXI_QOS_W]  = BUS_axi_arqos;
  assign cb_s_axi_arvalid[CB_S_CPU]  = BUS_axi_arvalid;
  assign cb_s_axi_rready[CB_S_CPU]  = BUS_axi_rready;


  // Split back to CPU master (Slave 0)
  assign BUS_axi_awready = cb_s_axi_awready[CB_S_CPU];
  assign BUS_axi_wready  = cb_s_axi_wready[CB_S_CPU];
  assign BUS_axi_bvalid  = cb_s_axi_bvalid[CB_S_CPU];
  assign BUS_axi_bresp   = cb_s_axi_bresp[CB_S_CPU*AXI_RESP_W +: AXI_RESP_W];
  assign BUS_axi_bid     = cb_s_axi_bid[CB_S_CPU*MST_ID_W +: MST_ID_W];
  assign BUS_axi_arready = cb_s_axi_arready[CB_S_CPU];
  assign BUS_axi_rvalid  = cb_s_axi_rvalid[CB_S_CPU];
  assign BUS_axi_rlast   = cb_s_axi_rlast[CB_S_CPU];
  assign BUS_axi_rresp   = cb_s_axi_rresp[CB_S_CPU*AXI_RESP_W +: AXI_RESP_W];
  assign BUS_axi_rid     = cb_s_axi_rid[CB_S_CPU*MST_ID_W +: MST_ID_W];
  assign BUS_axi_rdata   = cb_s_axi_rdata[CB_S_CPU*DATA_W +: DATA_W];

  if (P.XILINX_AXI_DMA_SUPPORTED) begin : gen_cb_s_cdma
    assign {cb_s_axi_awid[CB_S_CDMA*MST_ID_W +: MST_ID_W], cb_s_axi_awaddr[CB_S_CDMA*ADDR_W +: ADDR_W], cb_s_axi_awlen[CB_S_CDMA*AXI_LEN_W +: AXI_LEN_W], cb_s_axi_awsize[CB_S_CDMA*AXI_SIZE_W +: AXI_SIZE_W], cb_s_axi_awburst[CB_S_CDMA*AXI_BURST_W +: AXI_BURST_W], cb_s_axi_awlock[CB_S_CDMA], cb_s_axi_awcache[CB_S_CDMA*AXI_CACHE_W +: AXI_CACHE_W], cb_s_axi_awprot[CB_S_CDMA*AXI_PROT_W +: AXI_PROT_W], cb_s_axi_awqos[CB_S_CDMA*AXI_QOS_W +: AXI_QOS_W], cb_s_axi_awvalid[CB_S_CDMA], cb_s_axi_wdata[CB_S_CDMA*DATA_W +: DATA_W], cb_s_axi_wstrb[CB_S_CDMA*STRB_W +: STRB_W], cb_s_axi_wlast[CB_S_CDMA], cb_s_axi_wvalid[CB_S_CDMA], cb_s_axi_bready[CB_S_CDMA], cb_s_axi_arid[CB_S_CDMA*MST_ID_W +: MST_ID_W], cb_s_axi_araddr[CB_S_CDMA*ADDR_W +: ADDR_W], cb_s_axi_arlen[CB_S_CDMA*AXI_LEN_W +: AXI_LEN_W], cb_s_axi_arsize[CB_S_CDMA*AXI_SIZE_W +: AXI_SIZE_W], cb_s_axi_arburst[CB_S_CDMA*AXI_BURST_W +: AXI_BURST_W], cb_s_axi_arlock[CB_S_CDMA], cb_s_axi_arcache[CB_S_CDMA*AXI_CACHE_W +: AXI_CACHE_W], cb_s_axi_arprot[CB_S_CDMA*AXI_PROT_W +: AXI_PROT_W], cb_s_axi_arqos[CB_S_CDMA*AXI_QOS_W +: AXI_QOS_W], cb_s_axi_arvalid[CB_S_CDMA], cb_s_axi_rready[CB_S_CDMA]} = {{(MST_ID_W-SLV_ID_W){1'b0}}, cdma_m_axi_awid, cdma_m_axi_awaddr, cdma_m_axi_awlen, cdma_m_axi_awsize, cdma_m_axi_awburst, cdma_m_axi_awlock, cdma_m_axi_awcache, cdma_m_axi_awprot, {AXI_QOS_W{1'b0}}, cdma_m_axi_awvalid, cdma_m_axi_wdata, cdma_m_axi_wstrb, cdma_m_axi_wlast, cdma_m_axi_wvalid, cdma_m_axi_bready, {(MST_ID_W-SLV_ID_W){1'b0}}, cdma_m_axi_arid, cdma_m_axi_araddr, cdma_m_axi_arlen, cdma_m_axi_arsize, cdma_m_axi_arburst, cdma_m_axi_arlock, cdma_m_axi_arcache, cdma_m_axi_arprot, {AXI_QOS_W{1'b0}}, cdma_m_axi_arvalid, cdma_m_axi_rready};
    assign {cdma_m_axi_awready, cdma_m_axi_wready, cdma_m_axi_bvalid, cdma_m_axi_bresp, cdma_m_axi_bid, cdma_m_axi_arready, cdma_m_axi_rvalid, cdma_m_axi_rlast, cdma_m_axi_rresp, cdma_m_axi_rid, cdma_m_axi_rdata} = {cb_s_axi_awready[CB_S_CDMA], cb_s_axi_wready[CB_S_CDMA], cb_s_axi_bvalid[CB_S_CDMA], cb_s_axi_bresp[CB_S_CDMA*AXI_RESP_W +: AXI_RESP_W], cb_s_axi_bid[CB_S_CDMA*MST_ID_W +: MST_ID_W], cb_s_axi_arready[CB_S_CDMA], cb_s_axi_rvalid[CB_S_CDMA], cb_s_axi_rlast[CB_S_CDMA], cb_s_axi_rresp[CB_S_CDMA*AXI_RESP_W +: AXI_RESP_W], cb_s_axi_rid[CB_S_CDMA*MST_ID_W +: MST_ID_W], cb_s_axi_rdata[CB_S_CDMA*DATA_W +: DATA_W]};
  end

  if (P.AXI_VGA_SUPPORTED) begin : gen_cb_s_vga
    assign {cb_s_axi_awid[CB_S_VGA*MST_ID_W +: MST_ID_W], cb_s_axi_awaddr[CB_S_VGA*ADDR_W +: ADDR_W], cb_s_axi_awlen[CB_S_VGA*AXI_LEN_W +: AXI_LEN_W], cb_s_axi_awsize[CB_S_VGA*AXI_SIZE_W +: AXI_SIZE_W], cb_s_axi_awburst[CB_S_VGA*AXI_BURST_W +: AXI_BURST_W], cb_s_axi_awlock[CB_S_VGA], cb_s_axi_awcache[CB_S_VGA*AXI_CACHE_W +: AXI_CACHE_W], cb_s_axi_awprot[CB_S_VGA*AXI_PROT_W +: AXI_PROT_W], cb_s_axi_awqos[CB_S_VGA*AXI_QOS_W +: AXI_QOS_W], cb_s_axi_awvalid[CB_S_VGA], cb_s_axi_wdata[CB_S_VGA*DATA_W +: DATA_W], cb_s_axi_wstrb[CB_S_VGA*STRB_W +: STRB_W], cb_s_axi_wlast[CB_S_VGA], cb_s_axi_wvalid[CB_S_VGA], cb_s_axi_bready[CB_S_VGA], cb_s_axi_arid[CB_S_VGA*MST_ID_W +: MST_ID_W], cb_s_axi_araddr[CB_S_VGA*ADDR_W +: ADDR_W], cb_s_axi_arlen[CB_S_VGA*AXI_LEN_W +: AXI_LEN_W], cb_s_axi_arsize[CB_S_VGA*AXI_SIZE_W +: AXI_SIZE_W], cb_s_axi_arburst[CB_S_VGA*AXI_BURST_W +: AXI_BURST_W], cb_s_axi_arlock[CB_S_VGA], cb_s_axi_arcache[CB_S_VGA*AXI_CACHE_W +: AXI_CACHE_W], cb_s_axi_arprot[CB_S_VGA*AXI_PROT_W +: AXI_PROT_W], cb_s_axi_arqos[CB_S_VGA*AXI_QOS_W +: AXI_QOS_W], cb_s_axi_arvalid[CB_S_VGA], cb_s_axi_rready[CB_S_VGA]} = {{(MST_ID_W-SLV_ID_W){1'b0}}, vga_m_axi_awid, vga_m_axi_awaddr, vga_m_axi_awlen, vga_m_axi_awsize, vga_m_axi_awburst, vga_m_axi_awlock, vga_m_axi_awcache, vga_m_axi_awprot, {AXI_QOS_W{1'b0}}, vga_m_axi_awvalid, vga_m_axi_wdata, vga_m_axi_wstrb, vga_m_axi_wlast, vga_m_axi_wvalid, vga_m_axi_bready, {(MST_ID_W-SLV_ID_W){1'b0}}, vga_m_axi_arid, vga_m_axi_araddr, vga_m_axi_arlen, vga_m_axi_arsize, vga_m_axi_arburst, vga_m_axi_arlock, vga_m_axi_arcache, vga_m_axi_arprot, {AXI_QOS_W{1'b0}}, vga_m_axi_arvalid, vga_m_axi_rready};
    assign {vga_m_axi_awready, vga_m_axi_wready, vga_m_axi_bvalid, vga_m_axi_bresp, vga_m_axi_bid, vga_m_axi_arready, vga_m_axi_rvalid, vga_m_axi_rlast, vga_m_axi_rresp, vga_m_axi_rid, vga_m_axi_rdata} = {cb_s_axi_awready[CB_S_VGA], cb_s_axi_wready[CB_S_VGA], cb_s_axi_bvalid[CB_S_VGA], cb_s_axi_bresp[CB_S_VGA*AXI_RESP_W +: AXI_RESP_W], cb_s_axi_bid[CB_S_VGA*MST_ID_W +: SLV_ID_W], cb_s_axi_arready[CB_S_VGA], cb_s_axi_rvalid[CB_S_VGA], cb_s_axi_rlast[CB_S_VGA], cb_s_axi_rresp[CB_S_VGA*AXI_RESP_W +: AXI_RESP_W], cb_s_axi_rid[CB_S_VGA*MST_ID_W +: SLV_ID_W], cb_s_axi_rdata[CB_S_VGA*DATA_W +: DATA_W]};
  end

  if (P.AXI_USB_SUPPORTED) begin : gen_cb_s_usb
    assign {cb_s_axi_awid[CB_S_USB*MST_ID_W +: MST_ID_W], cb_s_axi_awaddr[CB_S_USB*ADDR_W +: ADDR_W], cb_s_axi_awlen[CB_S_USB*AXI_LEN_W +: AXI_LEN_W], cb_s_axi_awsize[CB_S_USB*AXI_SIZE_W +: AXI_SIZE_W], cb_s_axi_awburst[CB_S_USB*AXI_BURST_W +: AXI_BURST_W], cb_s_axi_awlock[CB_S_USB], cb_s_axi_awcache[CB_S_USB*AXI_CACHE_W +: AXI_CACHE_W], cb_s_axi_awprot[CB_S_USB*AXI_PROT_W +: AXI_PROT_W], cb_s_axi_awqos[CB_S_USB*AXI_QOS_W +: AXI_QOS_W], cb_s_axi_awvalid[CB_S_USB], cb_s_axi_wdata[CB_S_USB*DATA_W +: DATA_W], cb_s_axi_wstrb[CB_S_USB*STRB_W +: STRB_W], cb_s_axi_wlast[CB_S_USB], cb_s_axi_wvalid[CB_S_USB], cb_s_axi_bready[CB_S_USB], cb_s_axi_arid[CB_S_USB*MST_ID_W +: MST_ID_W], cb_s_axi_araddr[CB_S_USB*ADDR_W +: ADDR_W], cb_s_axi_arlen[CB_S_USB*AXI_LEN_W +: AXI_LEN_W], cb_s_axi_arsize[CB_S_USB*AXI_SIZE_W +: AXI_SIZE_W], cb_s_axi_arburst[CB_S_USB*AXI_BURST_W +: AXI_BURST_W], cb_s_axi_arlock[CB_S_USB], cb_s_axi_arcache[CB_S_USB*AXI_CACHE_W +: AXI_CACHE_W], cb_s_axi_arprot[CB_S_USB*AXI_PROT_W +: AXI_PROT_W], cb_s_axi_arqos[CB_S_USB*AXI_QOS_W +: AXI_QOS_W], cb_s_axi_arvalid[CB_S_USB], cb_s_axi_rready[CB_S_USB]} = {{(MST_ID_W-SLV_ID_W){1'b0}}, usb_m_axi_awid, usb_m_axi_awaddr, usb_m_axi_awlen, usb_m_axi_awsize, usb_m_axi_awburst, usb_m_axi_awlock, usb_m_axi_awcache, usb_m_axi_awprot, {AXI_QOS_W{1'b0}}, usb_m_axi_awvalid, usb_m_axi_wdata, usb_m_axi_wstrb, usb_m_axi_wlast, usb_m_axi_wvalid, usb_m_axi_bready, {(MST_ID_W-SLV_ID_W){1'b0}}, usb_m_axi_arid, usb_m_axi_araddr, usb_m_axi_arlen, usb_m_axi_arsize, usb_m_axi_arburst, usb_m_axi_arlock, usb_m_axi_arcache, usb_m_axi_arprot, {AXI_QOS_W{1'b0}}, usb_m_axi_arvalid, usb_m_axi_rready};
    assign {usb_m_axi_awready, usb_m_axi_wready, usb_m_axi_bvalid, usb_m_axi_bresp, usb_m_axi_bid, usb_m_axi_arready, usb_m_axi_rvalid, usb_m_axi_rlast, usb_m_axi_rresp, usb_m_axi_rid, usb_m_axi_rdata} = {cb_s_axi_awready[CB_S_USB], cb_s_axi_wready[CB_S_USB], cb_s_axi_bvalid[CB_S_USB], cb_s_axi_bresp[CB_S_USB*AXI_RESP_W +: AXI_RESP_W], cb_s_axi_bid[CB_S_USB*MST_ID_W +: SLV_ID_W], cb_s_axi_arready[CB_S_USB], cb_s_axi_rvalid[CB_S_USB], cb_s_axi_rlast[CB_S_USB], cb_s_axi_rresp[CB_S_USB*AXI_RESP_W +: AXI_RESP_W], cb_s_axi_rid[CB_S_USB*MST_ID_W +: SLV_ID_W], cb_s_axi_rdata[CB_S_USB*DATA_W +: DATA_W]};
  end


  // Crossbar is master to DDR
  assign cb_m_axi_awready[CB_M_DDR]      = BUS_cb_axi_awready;
  assign cb_m_axi_wready[CB_M_DDR]      = BUS_cb_axi_wready;
  assign cb_m_axi_arready[CB_M_DDR]      = BUS_cb_axi_arready;
  assign cb_m_axi_bvalid[CB_M_DDR]      = BUS_cb_axi_bvalid;
  assign cb_m_axi_bresp[CB_M_DDR*AXI_RESP_W +: AXI_RESP_W]      = BUS_cb_axi_bresp;
  assign cb_m_axi_bid[CB_M_DDR*MST_ID_W +: MST_ID_W]      = BUS_cb_axi_bid;
  assign cb_m_axi_rvalid[CB_M_DDR]      = BUS_cb_axi_rvalid;
  assign cb_m_axi_rlast[CB_M_DDR]      = BUS_cb_axi_rlast;
  assign cb_m_axi_rresp[CB_M_DDR*AXI_RESP_W +: AXI_RESP_W]      = BUS_cb_axi_rresp;
  assign cb_m_axi_rid[CB_M_DDR*MST_ID_W +: MST_ID_W]      = BUS_cb_axi_rid;
  assign cb_m_axi_rdata[CB_M_DDR*DATA_W      +: DATA_W] = BUS_cb_axi_rdata;


  ///////////////////////////////////////////////////////////

  logic          BUSCLK;
  logic          BUSRST;
  logic          BUSRSTn;
  // reset for CPU -> DDR AXI path
  logic          BUSCORERST;
  logic          BUSCORERSTn;
  logic          sdio_reset_open;
  logic          ahblite_resetn;
  logic          cpu_reset;
  logic          init_error;
  logic          ddr_ready;


  logic             c0_init_calib_complete;
  logic          dbg_clk;
  logic [511 : 0]   dbg_bus;
  logic             ui_clk_sync_rst;

  logic          CLK208;
  logic             clk167;
  logic             clk200;

  logic             app_sr_active;
  logic             app_ref_ack;
  logic             app_zq_ack;
  logic             mmcm_locked;
  logic [11:0]      device_temp;
  logic             mmcm1_locked;

(* mark_debug = "true" *)  logic              RVVIStall;

  assign GPIOIN = {25'b0, SDCCD, SDCWP, 1'b0, GPI};
  assign GPO = GPIOOUT[4:0];
  assign ahblite_resetn = peripheral_aresetn;
  assign cpu_reset = bus_struct_reset;

  logic [3:0] SDCCSin;
  assign SDCCS = SDCCSin[0];

  // active high reset
  logic reset = ~resetn;


`ifndef P_WISHBONE_ETH_SUPPORTED
  wire phy_ref_clk_raw;   // 50 MHz from MMCM
  wire rmii_clk50;
`endif

  // USB clock
  logic            clk48MHz_raw, clk48MHz;
(* ASYNC_REG="TRUE" *) logic usb_irq_ff1, usb_irq_ff2;
(* ASYNC_REG="TRUE" *) logic liteeth_irq_ff1, liteeth_irq_ff2;
(* ASYNC_REG="TRUE" *) logic sdhci_irq_ff1, sdhci_irq_ff2;


  // FIXME: CHECK IF THIS IS OK. clk167 is actually 200 MHz. Only one 200 MHz clock output is really needed
  // FIXME: CHECK IF THIS IS OK. clk167 is actually 200 MHz. Only one 200 MHz clock output is really needed
  // FIXME: CHECK IF THIS IS OK. clk167 is actually 200 MHz. Only one 200 MHz clock output is really needed
  // mmcm

  // the ddr3 mig7 requires 2 input clocks
  // 1. sys clock which is 167 MHz = ddr3 clock / 4
  // 2. a second clock which is 200 MHz
  // Wally requires a slower clock.  At this point I don't know what speed the atrix 7 will run so I'm initially targeting 25Mhz.
  // the mig will output a clock at 1/4 the sys clock or 41Mhz which might work with wally so we may be able to simplify the logic a lot.
  logic        phy_ref_clk; // *** fix when we add rvvi
  logic        audio_clk;
  mmcm mmcm(
        .clk_out1(audio_clk),
        .clk_out2(clk167), //FIXME: this is not 167 MHz for Genesys 2
        .clk_out3(clk200),
        .clk_out4(CPUCLK),
        .clk_out5(clk48MHz_raw),
        .reset(1'b0),
        .locked(mmcm1_locked),
        .clk_in1_p(default_200mhz_clk_p),
        .clk_in1_n(default_200mhz_clk_n));


`ifndef P_WISHBONE_ETH_SUPPORTED

    BUFG u_bufg_rmii (
    .I(phy_ref_clk_raw),
    .O(rmii_clk50)
    );

    // drive PHY + LiteEth
    //assign rmii_ref_clk = rmii_clk50;
    //assign WB_RMII_REF_CLK = rmii_clk50;
    assign WB_RMII_REF_CLK = rmii_clk50;  // goes to pin D5 via XDC

`endif



  logic rst_req;
  logic resetn_comb;

  assign rst_req      = ~resetn | south_reset;  // active-high reset request
  assign resetn_comb  = ~rst_req;               // active-low reset

  sysrst sysrst
    (.slowest_sync_clk(CPUCLK),
    .ext_reset_in(rst_req),
    .aux_reset_in(1'b0),
     .mb_debug_sys_rst(1'b0),
     .dcm_locked(mmcm1_locked),
     .mb_reset(mb_reset),  //open
     .bus_struct_reset(bus_struct_reset),
     .peripheral_reset(peripheral_reset), //open
     .interconnect_aresetn(interconnect_aresetn), //open
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
                    , .AXI_DMAIntr(axi_dma_intr_sync)
                    //, .AXI_USBIntr(usb_irq)
                    , .AXI_USBIntr(usb_irq_ff2)
                    , .AXI_EthIntr(liteeth_irq_ff2)
                    , .AXI_SDHCIIntr(sdhci_irq_ff2)
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



  // PULP STYLE DEFINITIONS
  // Matches your Vivado TCL intent: NUM_SI=4, NUM_MI=7, ADDR=32, DATA=DATA_W.
  // Slave-port ID width = 2 (your real initiator ID bits).

  typedef logic [SLV_ID_W-1:0] slv_id_t;
  typedef logic [MST_ID_W-1:0] mst_id_t;

  typedef logic [DATA_W-1:0] axi_data_t;
  typedef logic [STRB_W-1:0] axi_strb_t;

  typedef logic user_t; // unused user, tie-off to 0

  // Slave-port channel/req/resp types (initiators)
  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_t, axi_addr_t, slv_id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_t, axi_addr_t, slv_id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T (axi_w_t,  axi_data_t, axi_strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T (slv_b_t,  slv_id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T (slv_r_t,  axi_data_t, slv_id_t, user_t)
  `AXI_TYPEDEF_REQ_T    (slv_req_t, slv_aw_t, axi_w_t, slv_ar_t)
  `AXI_TYPEDEF_RESP_T   (slv_resp_t, slv_b_t, slv_r_t)

  // Master-port channel/req/resp types (targets)
  `AXI_TYPEDEF_AW_CHAN_T(mst_aw_t, axi_addr_t, mst_id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(mst_ar_t, axi_addr_t, mst_id_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T (mst_b_t,  mst_id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T (mst_r_t,  axi_data_t, mst_id_t, user_t)
  `AXI_TYPEDEF_REQ_T    (mst_req_t, mst_aw_t, axi_w_t, mst_ar_t)
  `AXI_TYPEDEF_RESP_T   (mst_resp_t, mst_b_t, mst_r_t)

  `AXI_STREAM_TYPEDEF_S_CHAN_T(axis_t_chan_t, axi_data_t, axi_strb_t,
                               axi_strb_t, slv_id_t, slv_id_t, user_t)
  `AXI_STREAM_TYPEDEF_REQ_T(axis_req_t, axis_t_chan_t)
  `AXI_STREAM_TYPEDEF_RSP_T(axis_rsp_t)

  (* mark_debug = "true" *) slv_req_t  [2:0] idma_xbar_mst_req;
  (* mark_debug = "true" *) slv_resp_t [2:0] idma_xbar_mst_rsp;
  (* mark_debug = "true" *) mst_req_t  [2:0] idma_xbar_slv_req;
  (* mark_debug = "true" *) mst_resp_t [2:0] idma_xbar_slv_rsp;
  axis_req_t idma_axis_req;
  axis_rsp_t idma_axis_rsp;
  (* ASYNC_REG="TRUE" *) logic [1:0] audio_resetn_ff;
  logic audio_reset;
  logic audio_resetn;

  assign audio_reset = rst_req | ~mmcm1_locked;
  always_ff @(posedge audio_clk or posedge audio_reset) begin
    if (audio_reset)
      audio_resetn_ff <= 2'b00;
    else
      audio_resetn_ff <= {audio_resetn_ff[0], 1'b1};
  end
  assign audio_resetn = audio_resetn_ff[1];

  if (P.AXI_IDMA_SUPPORTED || P.AXI_IDMA_REG64_SUPPORTED ||
      P.AXIS_IDMA_SUPPORTED) begin : gen_idma_xbar
    for (genvar i = 0; i < XBAR_OUT.idma_n_slv; i++) begin : gen_idma_xbar_s_pack
        localparam int unsigned S = XBAR_OUT.idma_slv_port[i];
        localparam int unsigned I = XBAR_OUT.idma_slv_req[i];

        assign cb_s_axi_awid[S*MST_ID_W +: MST_ID_W] = {{(MST_ID_W-SLV_ID_W){1'b0}}, idma_xbar_mst_req[I].aw.id};
        assign cb_s_axi_awaddr[S*ADDR_W +: ADDR_W] = idma_xbar_mst_req[I].aw.addr;
        assign cb_s_axi_awlen[S*AXI_LEN_W +: AXI_LEN_W] = idma_xbar_mst_req[I].aw.len;
        assign cb_s_axi_awsize[S*AXI_SIZE_W +: AXI_SIZE_W] = idma_xbar_mst_req[I].aw.size;
        assign cb_s_axi_awburst[S*AXI_BURST_W +: AXI_BURST_W] = idma_xbar_mst_req[I].aw.burst;
        assign cb_s_axi_awlock[S] = idma_xbar_mst_req[I].aw.lock;
        assign cb_s_axi_awcache[S*AXI_CACHE_W +: AXI_CACHE_W] = idma_xbar_mst_req[I].aw.cache;
        assign cb_s_axi_awprot[S*AXI_PROT_W +: AXI_PROT_W] = idma_xbar_mst_req[I].aw.prot;
        assign cb_s_axi_awqos[S*AXI_QOS_W +: AXI_QOS_W] = idma_xbar_mst_req[I].aw.qos;
        assign cb_s_axi_awvalid[S] = idma_xbar_mst_req[I].aw_valid;
        assign idma_xbar_mst_rsp[I].aw_ready = cb_s_axi_awready[S];

        assign cb_s_axi_wdata[S*DATA_W +: DATA_W] = idma_xbar_mst_req[I].w.data;
        assign cb_s_axi_wstrb[S*STRB_W +: STRB_W] = idma_xbar_mst_req[I].w.strb;
        assign cb_s_axi_wlast[S] = idma_xbar_mst_req[I].w.last;
        assign cb_s_axi_wvalid[S] = idma_xbar_mst_req[I].w_valid;
        assign idma_xbar_mst_rsp[I].w_ready = cb_s_axi_wready[S];

        assign cb_s_axi_bready[S] = idma_xbar_mst_req[I].b_ready;
        assign idma_xbar_mst_rsp[I].b_valid = cb_s_axi_bvalid[S];
        assign idma_xbar_mst_rsp[I].b.id = cb_s_axi_bid[S*MST_ID_W +: SLV_ID_W];
        assign idma_xbar_mst_rsp[I].b.resp = cb_s_axi_bresp[S*AXI_RESP_W +: AXI_RESP_W];
        assign idma_xbar_mst_rsp[I].b.user = '0;

        assign cb_s_axi_arid[S*MST_ID_W +: MST_ID_W] = {{(MST_ID_W-SLV_ID_W){1'b0}}, idma_xbar_mst_req[I].ar.id};
        assign cb_s_axi_araddr[S*ADDR_W +: ADDR_W] = idma_xbar_mst_req[I].ar.addr;
        assign cb_s_axi_arlen[S*AXI_LEN_W +: AXI_LEN_W] = idma_xbar_mst_req[I].ar.len;
        assign cb_s_axi_arsize[S*AXI_SIZE_W +: AXI_SIZE_W] = idma_xbar_mst_req[I].ar.size;
        assign cb_s_axi_arburst[S*AXI_BURST_W +: AXI_BURST_W] = idma_xbar_mst_req[I].ar.burst;
        assign cb_s_axi_arlock[S] = idma_xbar_mst_req[I].ar.lock;
        assign cb_s_axi_arcache[S*AXI_CACHE_W +: AXI_CACHE_W] = idma_xbar_mst_req[I].ar.cache;
        assign cb_s_axi_arprot[S*AXI_PROT_W +: AXI_PROT_W] = idma_xbar_mst_req[I].ar.prot;
        assign cb_s_axi_arqos[S*AXI_QOS_W +: AXI_QOS_W] = idma_xbar_mst_req[I].ar.qos;
        assign cb_s_axi_arvalid[S] = idma_xbar_mst_req[I].ar_valid;
        assign idma_xbar_mst_rsp[I].ar_ready = cb_s_axi_arready[S];

        assign cb_s_axi_rready[S] = idma_xbar_mst_req[I].r_ready;
        assign idma_xbar_mst_rsp[I].r_valid = cb_s_axi_rvalid[S];
        assign idma_xbar_mst_rsp[I].r.id = cb_s_axi_rid[S*MST_ID_W +: SLV_ID_W];
        assign idma_xbar_mst_rsp[I].r.data = cb_s_axi_rdata[S*DATA_W +: DATA_W];
        assign idma_xbar_mst_rsp[I].r.resp = cb_s_axi_rresp[S*AXI_RESP_W +: AXI_RESP_W];
        assign idma_xbar_mst_rsp[I].r.last = cb_s_axi_rlast[S];
        assign idma_xbar_mst_rsp[I].r.user = '0;
    end

    for (genvar i = 0; i < XBAR_OUT.idma_n_mst; i++) begin : gen_idma_xbar_m_unpack
        localparam int unsigned M = XBAR_OUT.idma_mst_port[i];
        localparam int unsigned I = XBAR_OUT.idma_mst_resp[i];

        assign idma_xbar_slv_req[I].aw.id = cb_m_axi_awid[M*MST_ID_W +: MST_ID_W];
        assign idma_xbar_slv_req[I].aw.addr = cb_m_axi_awaddr[M*ADDR_W +: ADDR_W];
        assign idma_xbar_slv_req[I].aw.len = cb_m_axi_awlen[M*AXI_LEN_W +: AXI_LEN_W];
        assign idma_xbar_slv_req[I].aw.size = cb_m_axi_awsize[M*AXI_SIZE_W +: AXI_SIZE_W];
        assign idma_xbar_slv_req[I].aw.burst = cb_m_axi_awburst[M*AXI_BURST_W +: AXI_BURST_W];
        assign idma_xbar_slv_req[I].aw.lock = cb_m_axi_awlock[M];
        assign idma_xbar_slv_req[I].aw.cache = cb_m_axi_awcache[M*AXI_CACHE_W +: AXI_CACHE_W];
        assign idma_xbar_slv_req[I].aw.prot = cb_m_axi_awprot[M*AXI_PROT_W +: AXI_PROT_W];
        assign idma_xbar_slv_req[I].aw.qos = cb_m_axi_awqos[M*AXI_QOS_W +: AXI_QOS_W];
        assign idma_xbar_slv_req[I].aw.region = cb_m_axi_awregion[M*AXI_QOS_W +: AXI_QOS_W];
        assign idma_xbar_slv_req[I].aw.atop = '0;
        assign idma_xbar_slv_req[I].aw.user = '0;
        assign idma_xbar_slv_req[I].aw_valid = cb_m_axi_awvalid[M];
        assign cb_m_axi_awready[M] = idma_xbar_slv_rsp[I].aw_ready;

        assign idma_xbar_slv_req[I].w.data = cb_m_axi_wdata[M*DATA_W +: DATA_W];
        assign idma_xbar_slv_req[I].w.strb = cb_m_axi_wstrb[M*STRB_W +: STRB_W];
        assign idma_xbar_slv_req[I].w.last = cb_m_axi_wlast[M];
        assign idma_xbar_slv_req[I].w.user = '0;
        assign idma_xbar_slv_req[I].w_valid = cb_m_axi_wvalid[M];
        assign cb_m_axi_wready[M] = idma_xbar_slv_rsp[I].w_ready;

        assign idma_xbar_slv_req[I].b_ready = cb_m_axi_bready[M];
        assign cb_m_axi_bvalid[M] = idma_xbar_slv_rsp[I].b_valid;
        assign cb_m_axi_bresp[M*AXI_RESP_W +: AXI_RESP_W] = idma_xbar_slv_rsp[I].b.resp;
        assign cb_m_axi_bid[M*MST_ID_W +: MST_ID_W] = idma_xbar_slv_rsp[I].b.id;

        assign idma_xbar_slv_req[I].ar.id = cb_m_axi_arid[M*MST_ID_W +: MST_ID_W];
        assign idma_xbar_slv_req[I].ar.addr = cb_m_axi_araddr[M*ADDR_W +: ADDR_W];
        assign idma_xbar_slv_req[I].ar.len = cb_m_axi_arlen[M*AXI_LEN_W +: AXI_LEN_W];
        assign idma_xbar_slv_req[I].ar.size = cb_m_axi_arsize[M*AXI_SIZE_W +: AXI_SIZE_W];
        assign idma_xbar_slv_req[I].ar.burst = cb_m_axi_arburst[M*AXI_BURST_W +: AXI_BURST_W];
        assign idma_xbar_slv_req[I].ar.lock = cb_m_axi_arlock[M];
        assign idma_xbar_slv_req[I].ar.cache = cb_m_axi_arcache[M*AXI_CACHE_W +: AXI_CACHE_W];
        assign idma_xbar_slv_req[I].ar.prot = cb_m_axi_arprot[M*AXI_PROT_W +: AXI_PROT_W];
        assign idma_xbar_slv_req[I].ar.qos = cb_m_axi_arqos[M*AXI_QOS_W +: AXI_QOS_W];
        assign idma_xbar_slv_req[I].ar.region = cb_m_axi_arregion[M*AXI_QOS_W +: AXI_QOS_W];
        assign idma_xbar_slv_req[I].ar.user = '0;
        assign idma_xbar_slv_req[I].ar_valid = cb_m_axi_arvalid[M];
        assign cb_m_axi_arready[M] = idma_xbar_slv_rsp[I].ar_ready;

        assign idma_xbar_slv_req[I].r_ready = cb_m_axi_rready[M];
        assign cb_m_axi_rvalid[M] = idma_xbar_slv_rsp[I].r_valid;
        assign cb_m_axi_rdata[M*DATA_W +: DATA_W] = idma_xbar_slv_rsp[I].r.data;
        assign cb_m_axi_rresp[M*AXI_RESP_W +: AXI_RESP_W] = idma_xbar_slv_rsp[I].r.resp;
        assign cb_m_axi_rlast[M] = idma_xbar_slv_rsp[I].r.last;
        assign cb_m_axi_rid[M*MST_ID_W +: MST_ID_W] = idma_xbar_slv_rsp[I].r.id;
    end
  end

  localparam int unsigned AXI_USER_W = 1;
  typedef logic [AXI_USER_W-1:0] axi_user_t; //what is this for?

  // Channel typedefs (PULP macros)
  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, axi_addr_t, mst_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T (w_chan_t,  axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T (b_chan_t,  mst_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, axi_addr_t, mst_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T (r_chan_t,  axi_data_t, mst_id_t, axi_user_t)

  `AXI_TYPEDEF_REQ_T (axi_req_t,  aw_chan_t, w_chan_t, ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_resp_t, b_chan_t,  r_chan_t)

  typedef logic [31:0] axil32_data_t;
  typedef logic [3:0]  axil32_strb_t;
  `AXI_LITE_TYPEDEF_ALL_CT(usb_axil, usb_axil_req_t, usb_axil_rsp_t, axi_addr_t, axil32_data_t, axil32_strb_t)


  if (P.XILINX_CDC_SUPPORTED) begin

    // AXI Clock Converter
    clkconverter clkconverter
      (.s_axi_aclk(CPUCLK),
       .s_axi_aresetn(peripheral_aresetn),
       .s_axi_awid(m_axi_awid),
       .s_axi_awlen(m_axi_awlen),
       .s_axi_awsize(m_axi_awsize),
       .s_axi_awburst(m_axi_awburst),
       .s_axi_awcache(m_axi_awcache),
       .s_axi_awaddr(m_axi_awaddr[31:0] ),
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
       .m_axi_aresetn(BUSCORERSTn),
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
  end else begin

    // Bundles in each clock domain
    axi_req_t  cpu_req, bus_req;
    axi_resp_t cpu_resp, bus_resp;

    // -------------------------
    // CPUCLK domain (SRC side)
    // -------------------------

    // Write address channel
    assign cpu_req.aw.id     = m_axi_awid;
    assign cpu_req.aw.addr   = m_axi_awaddr[31:0];
    assign cpu_req.aw.len    = m_axi_awlen;
    assign cpu_req.aw.size   = m_axi_awsize;
    assign cpu_req.aw.burst  = m_axi_awburst;
    assign cpu_req.aw.lock   = m_axi_awlock;
    assign cpu_req.aw.cache  = m_axi_awcache;
    assign cpu_req.aw.prot   = m_axi_awprot;
    assign cpu_req.aw.region = 4'b0;      // like your current tie-off
    assign cpu_req.aw.qos    = 4'b0;      // like your current tie-off
    assign cpu_req.aw.atop   = 6'b0;      // if present in your PULP version; otherwise delete
    assign cpu_req.aw.user   = '0;
    assign cpu_req.aw_valid  = m_axi_awvalid;
    assign m_axi_awready     = cpu_resp.aw_ready;

    // Write data channel
    assign cpu_req.w.data    = m_axi_wdata;
    assign cpu_req.w.strb    = m_axi_wstrb;
    assign cpu_req.w.last    = m_axi_wlast;
    assign cpu_req.w.user    = '0;
    assign cpu_req.w_valid   = m_axi_wvalid;
    assign m_axi_wready      = cpu_resp.w_ready;

    // Write response channel
    assign m_axi_bid         = cpu_resp.b.id;
    assign m_axi_bresp       = cpu_resp.b.resp;
    assign m_axi_bvalid      = cpu_resp.b_valid;
    assign cpu_req.b_ready   = m_axi_bready;

    // Read address channel
    assign cpu_req.ar.id     = m_axi_arid;
    assign cpu_req.ar.addr   = m_axi_araddr[31:0];
    assign cpu_req.ar.len    = m_axi_arlen;
    assign cpu_req.ar.size   = m_axi_arsize;
    assign cpu_req.ar.burst  = m_axi_arburst;
    assign cpu_req.ar.lock   = m_axi_arlock;
    assign cpu_req.ar.cache  = m_axi_arcache;
    assign cpu_req.ar.prot   = m_axi_arprot;
    assign cpu_req.ar.region = 4'b0;      // tie-off
    assign cpu_req.ar.qos    = 4'b0;      // tie-off
    assign cpu_req.ar.user   = '0;
    assign cpu_req.ar_valid  = m_axi_arvalid;
    assign m_axi_arready     = cpu_resp.ar_ready;

    // Read data channel
    assign m_axi_rid         = cpu_resp.r.id;
    assign m_axi_rdata       = cpu_resp.r.data;
    assign m_axi_rresp       = cpu_resp.r.resp;
    assign m_axi_rlast       = cpu_resp.r.last;
    assign m_axi_rvalid      = cpu_resp.r_valid;
    assign cpu_req.r_ready   = m_axi_rready;
    //---
    // -------------------------
    // BUSCLK domain (DST side)
    // -------------------------

    // Write address
    assign BUS_axi_awid      = bus_req.aw.id;
    assign BUS_axi_awaddr    = bus_req.aw.addr;
    assign BUS_axi_awlen     = bus_req.aw.len;
    assign BUS_axi_awsize    = bus_req.aw.size;
    assign BUS_axi_awburst   = bus_req.aw.burst;
    assign BUS_axi_awlock    = bus_req.aw.lock;
    assign BUS_axi_awcache   = bus_req.aw.cache;
    assign BUS_axi_awprot    = bus_req.aw.prot;
    assign BUS_axi_awregion  = bus_req.aw.region;
    assign BUS_axi_awqos     = bus_req.aw.qos;
    assign BUS_axi_awvalid   = bus_req.aw_valid;
    assign bus_resp.aw_ready = BUS_axi_awready;

    // Write data
    assign BUS_axi_wdata     = bus_req.w.data;
    assign BUS_axi_wstrb     = bus_req.w.strb;
    assign BUS_axi_wlast     = bus_req.w.last;
    assign BUS_axi_wvalid    = bus_req.w_valid;
    assign bus_resp.w_ready  = BUS_axi_wready;

    // Write response
    assign bus_resp.b.id     = BUS_axi_bid;
    assign bus_resp.b.resp   = BUS_axi_bresp;
    assign bus_resp.b_valid  = BUS_axi_bvalid;
    assign BUS_axi_bready    = bus_req.b_ready;

    // Read address
    assign BUS_axi_arid      = bus_req.ar.id;
    assign BUS_axi_araddr    = bus_req.ar.addr;
    assign BUS_axi_arlen     = bus_req.ar.len;
    assign BUS_axi_arsize    = bus_req.ar.size;
    assign BUS_axi_arburst   = bus_req.ar.burst;
    assign BUS_axi_arlock    = bus_req.ar.lock;
    assign BUS_axi_arcache   = bus_req.ar.cache;
    assign BUS_axi_arprot    = bus_req.ar.prot;
    assign BUS_axi_arregion  = bus_req.ar.region;
    assign BUS_axi_arqos     = bus_req.ar.qos;
    assign BUS_axi_arvalid   = bus_req.ar_valid;
    assign bus_resp.ar_ready = BUS_axi_arready;

    // Read data
    assign bus_resp.r.id     = BUS_axi_rid;
    assign bus_resp.r.data   = BUS_axi_rdata;
    assign bus_resp.r.resp   = BUS_axi_rresp;
    assign bus_resp.r.last   = BUS_axi_rlast;
    assign bus_resp.r_valid  = BUS_axi_rvalid;
    assign BUS_axi_rready    = bus_req.r_ready;

    axi_cdc #(
        .aw_chan_t ( aw_chan_t   ),
        .w_chan_t  ( w_chan_t    ),
        .b_chan_t  ( b_chan_t    ),
        .ar_chan_t ( ar_chan_t   ),
        .r_chan_t  ( r_chan_t    ),
        .axi_req_t ( axi_req_t   ),
        .axi_resp_t( axi_resp_t  ),
        .LogDepth  ( 2           ), // FIFO depth = 2**LogDepth; tune if needed
        .SyncStages( 2           )
        ) u_axi_cdc (
        .src_clk_i  ( CPUCLK             ),
        .src_rst_ni ( peripheral_aresetn ),
        .src_req_i  ( cpu_req            ),
        .src_resp_o ( cpu_resp           ),

        .dst_clk_i  ( BUSCLK             ),
        //.dst_rst_ni ( resetn             ),
        .dst_rst_ni ( BUSCORERSTn            ),
        .dst_req_o  ( bus_req            ),
        .dst_resp_i ( bus_resp           )
    );
  end

  if (P.XILINX_XBAR_SUPPORTED) begin
    axicrossbar axicrossbar (
        .aclk(BUSCLK),
        .aresetn(BUSCORERSTn),

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
  end else begin
    // -----------------------------------------------------------------------------
    // PULP axi_xbar drop-in replacement for Xilinx packed-vector AXI crossbar
    // -----------------------------------------------------------------------------

    // Internal struct arrays
    slv_req_t  [N_SLV-1:0] slv_req;
    slv_resp_t [N_SLV-1:0] slv_resp;
    mst_req_t  [N_MST-1:0] mst_req;
    mst_resp_t [N_MST-1:0] mst_resp;

    // Crossbar configuration (recommended timing baseline: CUT_ALL_AX, FallThrough=0)
    localparam axi_pkg::xbar_cfg_t XBAR_CFG = '{
        NoSlvPorts:         N_SLV,
        NoMstPorts:         N_MST,
        MaxMstTrans:        16,
        MaxSlvTrans:        16,
        FallThrough:        1'b0,
        //LatencyMode:        axi_pkg::CUT_ALL_AX,
        // Cheshire uses CUT_ALL_PORTS
        LatencyMode:        axi_pkg::CUT_ALL_PORTS,

        // Newer cfg field: number of axi_multicut stages in the xbar datapaths
        PipelineStages:     0,

        AxiIdWidthSlvPorts: SLV_ID_W,
        AxiIdUsedSlvPorts:  SLV_ID_W,
        UniqueIds:          1'b0,
        AxiAddrWidth:       ADDR_W,
        AxiDataWidth:       DATA_W,
        NoAddrRules:        N_RULES
    };

    // The function builds a compact map; end_addr is exclusive.
    localparam axi_pkg::xbar_rule_32_t [N_RULES-1:0] ADDR_MAP =
        XBAR_OUT.addr_map[N_RULES-1:0];
    // XBAR connectivity config
    localparam bit [XBAR_MAX_SLV-1:0][XBAR_MAX_MST-1:0] XBAR_CONNECTIVITY_FULL =
        gen_xbar_connectivity(P);

    // Vivado does not accept a two-dimensional packed part-select here.  Copy
    // the shared full matrix into the exact parameter type required by axi_xbar.
    function automatic bit [N_SLV-1:0][N_MST-1:0] resize_xbar_connectivity();
      bit [N_SLV-1:0][N_MST-1:0] conn;

      conn = '0;
      for (int unsigned s = 0; s < N_SLV; s++)
        for (int unsigned m = 0; m < N_MST; m++)
          conn[s][m] = XBAR_CONNECTIVITY_FULL[s][m];
      return conn;
    endfunction
    localparam bit [N_SLV-1:0][N_MST-1:0] XBAR_CONNECTIVITY =
        resize_xbar_connectivity();

    // ------------------------------
    // Unpack packed S_AXI -> slv_req
    // ------------------------------
    for (genvar s = 0; s < N_SLV; s++) begin : gen_slv_unpack
        // AW
        assign slv_req[s].aw.addr   = cb_s_axi_awaddr [s*ADDR_W +: ADDR_W];
        assign slv_req[s].aw.id     = cb_s_axi_awid   [s*MST_ID_W +: SLV_ID_W]; // take low 2 bits
        assign slv_req[s].aw.len    = cb_s_axi_awlen  [s*AXI_LEN_W +: AXI_LEN_W];
        assign slv_req[s].aw.size   = cb_s_axi_awsize [s*AXI_SIZE_W +: AXI_SIZE_W];
        assign slv_req[s].aw.burst  = cb_s_axi_awburst[s*AXI_BURST_W +: AXI_BURST_W];
        assign slv_req[s].aw.lock   = cb_s_axi_awlock [s];
        assign slv_req[s].aw.cache  = cb_s_axi_awcache[s*AXI_CACHE_W +: AXI_CACHE_W];
        assign slv_req[s].aw.prot   = cb_s_axi_awprot [s*AXI_PROT_W +: AXI_PROT_W];
        assign slv_req[s].aw.qos    = cb_s_axi_awqos  [s*AXI_QOS_W +: AXI_QOS_W];
        assign slv_req[s].aw.region = '0;
        assign slv_req[s].aw.atop   = '0;
        assign slv_req[s].aw.user   = '0;
        assign slv_req[s].aw_valid  = cb_s_axi_awvalid[s];
        assign cb_s_axi_awready[s]  = slv_resp[s].aw_ready;

        // W
        assign slv_req[s].w.data    = cb_s_axi_wdata [s*DATA_W +: DATA_W];
        assign slv_req[s].w.strb    = cb_s_axi_wstrb [s*STRB_W +: STRB_W];
        assign slv_req[s].w.last    = cb_s_axi_wlast [s];
        assign slv_req[s].w.user    = '0;
        assign slv_req[s].w_valid   = cb_s_axi_wvalid[s];
        assign cb_s_axi_wready[s]   = slv_resp[s].w_ready;

        // B
        assign slv_req[s].b_ready   = cb_s_axi_bready[s];
        assign cb_s_axi_bvalid[s]   = slv_resp[s].b_valid;
        assign cb_s_axi_bresp[s*AXI_RESP_W +: AXI_RESP_W] = slv_resp[s].b.resp;
        assign cb_s_axi_bid  [s*MST_ID_W +: MST_ID_W] = {{(MST_ID_W-SLV_ID_W){1'b0}}, slv_resp[s].b.id}; // keep your old padding convention

        // AR
        assign slv_req[s].ar.addr   = cb_s_axi_araddr [s*ADDR_W +: ADDR_W];
        assign slv_req[s].ar.id     = cb_s_axi_arid   [s*MST_ID_W +: SLV_ID_W]; // low 2 bits
        assign slv_req[s].ar.len    = cb_s_axi_arlen  [s*AXI_LEN_W +: AXI_LEN_W];
        assign slv_req[s].ar.size   = cb_s_axi_arsize [s*AXI_SIZE_W +: AXI_SIZE_W];
        assign slv_req[s].ar.burst  = cb_s_axi_arburst[s*AXI_BURST_W +: AXI_BURST_W];
        assign slv_req[s].ar.lock   = cb_s_axi_arlock [s];
        assign slv_req[s].ar.cache  = cb_s_axi_arcache[s*AXI_CACHE_W +: AXI_CACHE_W];
        assign slv_req[s].ar.prot   = cb_s_axi_arprot [s*AXI_PROT_W +: AXI_PROT_W];
        assign slv_req[s].ar.qos    = cb_s_axi_arqos  [s*AXI_QOS_W +: AXI_QOS_W];
        assign slv_req[s].ar.region = '0;
        assign slv_req[s].ar.user   = '0;
        assign slv_req[s].ar_valid  = cb_s_axi_arvalid[s];
        assign cb_s_axi_arready[s]  = slv_resp[s].ar_ready;

        // R
        assign slv_req[s].r_ready   = cb_s_axi_rready[s];
        assign cb_s_axi_rvalid[s]   = slv_resp[s].r_valid;
        assign cb_s_axi_rdata[s*DATA_W +: DATA_W] = slv_resp[s].r.data;
        assign cb_s_axi_rresp[s*AXI_RESP_W +: AXI_RESP_W] = slv_resp[s].r.resp;
        assign cb_s_axi_rlast[s]                 = slv_resp[s].r.last;
        assign cb_s_axi_rid  [s*MST_ID_W +: MST_ID_W] = {{(MST_ID_W-SLV_ID_W){1'b0}}, slv_resp[s].r.id}; // keep old padding
    end

    // ------------------------------------
    // Pack mst_req -> packed M_AXI vectors
    // and unpack packed M_AXI -> mst_resp
    // ------------------------------------
    for (genvar m = 0; m < N_MST; m++) begin : gen_mst_pack
        // AW out
        assign cb_m_axi_awaddr  [m*ADDR_W +: ADDR_W] = mst_req[m].aw.addr;
        assign cb_m_axi_awid    [m*MST_ID_W +: MST_ID_W] = mst_req[m].aw.id;      // widened 4-bit ID
        assign cb_m_axi_awlen   [m*AXI_LEN_W +: AXI_LEN_W] = mst_req[m].aw.len;
        assign cb_m_axi_awsize  [m*AXI_SIZE_W +: AXI_SIZE_W] = mst_req[m].aw.size;
        assign cb_m_axi_awburst [m*AXI_BURST_W +: AXI_BURST_W] = mst_req[m].aw.burst;
        assign cb_m_axi_awlock  [m]                  = mst_req[m].aw.lock;
        assign cb_m_axi_awcache [m*AXI_CACHE_W +: AXI_CACHE_W] = mst_req[m].aw.cache;
        assign cb_m_axi_awprot  [m*AXI_PROT_W +: AXI_PROT_W] = mst_req[m].aw.prot;
        assign cb_m_axi_awqos   [m*AXI_QOS_W +: AXI_QOS_W] = mst_req[m].aw.qos;
        assign cb_m_axi_awregion[m*AXI_QOS_W +: AXI_QOS_W] = mst_req[m].aw.region;
        assign cb_m_axi_awvalid [m]                  = mst_req[m].aw_valid;
        assign mst_resp[m].aw_ready                  = cb_m_axi_awready[m];

        // W out
        assign cb_m_axi_wdata [m*DATA_W +: DATA_W] = mst_req[m].w.data;
        assign cb_m_axi_wstrb [m*STRB_W +: STRB_W] = mst_req[m].w.strb;
        assign cb_m_axi_wlast [m]                  = mst_req[m].w.last;
        assign cb_m_axi_wvalid[m]                  = mst_req[m].w_valid;
        assign mst_resp[m].w_ready                 = cb_m_axi_wready[m];

        // B in
        assign cb_m_axi_bready[m]        = mst_req[m].b_ready;
        assign mst_resp[m].b_valid       = cb_m_axi_bvalid[m];
        assign mst_resp[m].b.id          = cb_m_axi_bid  [m*MST_ID_W +: MST_ID_W];
        assign mst_resp[m].b.resp        = cb_m_axi_bresp[m*AXI_RESP_W +: AXI_RESP_W];
        assign mst_resp[m].b.user        = '0;

        // AR out
        assign cb_m_axi_araddr  [m*ADDR_W +: ADDR_W] = mst_req[m].ar.addr;
        assign cb_m_axi_arid    [m*MST_ID_W +: MST_ID_W] = mst_req[m].ar.id;
        assign cb_m_axi_arlen   [m*AXI_LEN_W +: AXI_LEN_W] = mst_req[m].ar.len;
        assign cb_m_axi_arsize  [m*AXI_SIZE_W +: AXI_SIZE_W] = mst_req[m].ar.size;
        assign cb_m_axi_arburst [m*AXI_BURST_W +: AXI_BURST_W] = mst_req[m].ar.burst;
        assign cb_m_axi_arlock  [m]                  = mst_req[m].ar.lock;
        assign cb_m_axi_arcache [m*AXI_CACHE_W +: AXI_CACHE_W] = mst_req[m].ar.cache;
        assign cb_m_axi_arprot  [m*AXI_PROT_W +: AXI_PROT_W] = mst_req[m].ar.prot;
        assign cb_m_axi_arqos   [m*AXI_QOS_W +: AXI_QOS_W] = mst_req[m].ar.qos;
        assign cb_m_axi_arregion[m*AXI_QOS_W +: AXI_QOS_W] = mst_req[m].ar.region;
        assign cb_m_axi_arvalid [m]                  = mst_req[m].ar_valid;
        assign mst_resp[m].ar_ready                  = cb_m_axi_arready[m];

        // R in
        assign cb_m_axi_rready[m]        = mst_req[m].r_ready;
        assign mst_resp[m].r_valid       = cb_m_axi_rvalid[m];
        assign mst_resp[m].r.id          = cb_m_axi_rid  [m*MST_ID_W +: MST_ID_W];
        assign mst_resp[m].r.data        = cb_m_axi_rdata[m*DATA_W +: DATA_W];
        assign mst_resp[m].r.resp        = cb_m_axi_rresp[m*AXI_RESP_W +: AXI_RESP_W];
        assign mst_resp[m].r.last        = cb_m_axi_rlast[m];
        assign mst_resp[m].r.user        = '0;
    end

    axi_xbar #(
        .Cfg            (XBAR_CFG),
        .ATOPs          (1'b0),
        .Connectivity   (XBAR_CONNECTIVITY),

        .slv_aw_chan_t  (slv_aw_t),
        .mst_aw_chan_t  (mst_aw_t),
        .w_chan_t       (axi_w_t),
        .slv_b_chan_t   (slv_b_t),
        .mst_b_chan_t   (mst_b_t),
        .slv_ar_chan_t  (slv_ar_t),
        .mst_ar_chan_t  (mst_ar_t),
        .slv_r_chan_t   (slv_r_t),
        .mst_r_chan_t   (mst_r_t),
        .slv_req_t      (slv_req_t),
        .slv_resp_t     (slv_resp_t),
        .mst_req_t      (mst_req_t),
        .mst_resp_t     (mst_resp_t),

        .rule_t         (axi_pkg::xbar_rule_32_t)
        ) i_axi_xbar (
        .clk_i                 (BUSCLK),
        .rst_ni                 (BUSCORERSTn),
        .test_i                (1'b0),
        .slv_ports_req_i       (slv_req),
        .slv_ports_resp_o      (slv_resp),
        .mst_ports_req_o       (mst_req),
        .mst_ports_resp_i      (mst_resp),
        .addr_map_i            (ADDR_MAP),
        .en_default_mst_port_i ('0),
        .default_mst_port_i    ('0)
    );
  end


  // M02 -> axi_vga_wrap (AXI slave regs + AXI master scanout), all on BUSCLK
  if (P.AXI_VGA_SUPPORTED) begin : gen_axi_vga
    axi_vga_wrap #(
        .AXI_ADDR_W ( ADDR_W   ),
        .AXI_DATA_W ( DATA_W   ),
        .AXI_ID_W   ( MST_ID_W ),
        .AXI_M_ID_W ( SLV_ID_W ),
        .AXI_USER_W ( 1        )
    ) axi_vga_wrap_i (
        .aclk    (BUSCLK),
        .aresetn (BUSRSTn),

        // AXI slave regs (from crossbar M02)
        .s_axi_awid    (cb_m_axi_awid[CB_M_VGA_REG*MST_ID_W +: MST_ID_W]),
        .s_axi_awaddr  (cb_m_axi_awaddr[CB_M_VGA_REG*ADDR_W +: ADDR_W]),
        .s_axi_awlen   (cb_m_axi_awlen[CB_M_VGA_REG*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_awsize  (cb_m_axi_awsize[CB_M_VGA_REG*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_awburst (cb_m_axi_awburst[CB_M_VGA_REG*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_awlock  (cb_m_axi_awlock[CB_M_VGA_REG]),
        .s_axi_awcache (cb_m_axi_awcache[CB_M_VGA_REG*AXI_CACHE_W +: AXI_CACHE_W]),
        .s_axi_awprot  (cb_m_axi_awprot[CB_M_VGA_REG*AXI_PROT_W +: AXI_PROT_W]),
        .s_axi_awqos   (cb_m_axi_awqos[CB_M_VGA_REG*AXI_QOS_W +: AXI_QOS_W]),
        .s_axi_awvalid (cb_m_axi_awvalid[CB_M_VGA_REG]),
        .s_axi_awready (vga_reg_awready),

        .s_axi_wdata   (cb_m_axi_wdata[CB_M_VGA_REG*DATA_W +: DATA_W]),
        .s_axi_wstrb   (cb_m_axi_wstrb[CB_M_VGA_REG*STRB_W +: STRB_W]),
        .s_axi_wlast   (cb_m_axi_wlast[CB_M_VGA_REG]),
        .s_axi_wvalid  (cb_m_axi_wvalid[CB_M_VGA_REG]),
        .s_axi_wready  (vga_reg_wready),

        .s_axi_bresp   (vga_reg_bresp),
        .s_axi_bvalid  (vga_reg_bvalid),
        .s_axi_bid     (vga_reg_bid),
        .s_axi_bready  (cb_m_axi_bready[CB_M_VGA_REG]),

        .s_axi_arid    (cb_m_axi_arid[CB_M_VGA_REG*MST_ID_W +: MST_ID_W]),
        .s_axi_araddr  (cb_m_axi_araddr[CB_M_VGA_REG*ADDR_W +: ADDR_W]),
        .s_axi_arlen   (cb_m_axi_arlen[CB_M_VGA_REG*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_arsize  (cb_m_axi_arsize[CB_M_VGA_REG*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_arburst (cb_m_axi_arburst[CB_M_VGA_REG*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_arlock  (cb_m_axi_arlock[CB_M_VGA_REG]),
        .s_axi_arcache (cb_m_axi_arcache[CB_M_VGA_REG*AXI_CACHE_W +: AXI_CACHE_W]),
        .s_axi_arprot  (cb_m_axi_arprot[CB_M_VGA_REG*AXI_PROT_W +: AXI_PROT_W]),
        .s_axi_arqos   (cb_m_axi_arqos[CB_M_VGA_REG*AXI_QOS_W +: AXI_QOS_W]),
        .s_axi_arvalid (cb_m_axi_arvalid[CB_M_VGA_REG]),
        .s_axi_arready (vga_reg_arready),

        .s_axi_rdata   (vga_reg_rdata),
        .s_axi_rresp   (vga_reg_rresp),
        .s_axi_rlast   (vga_reg_rlast),
        .s_axi_rvalid  (vga_reg_rvalid),
        .s_axi_rid     (vga_reg_rid),
        .s_axi_rready  (cb_m_axi_rready[CB_M_VGA_REG]),

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

    assign cb_m_axi_awready[CB_M_VGA_REG] = vga_reg_awready;
    assign cb_m_axi_wready [CB_M_VGA_REG] = vga_reg_wready;
    assign cb_m_axi_arready[CB_M_VGA_REG] = vga_reg_arready;
    assign cb_m_axi_bvalid [CB_M_VGA_REG] = vga_reg_bvalid;
    assign cb_m_axi_bresp[CB_M_VGA_REG*AXI_RESP_W +: AXI_RESP_W] = vga_reg_bresp;
    assign cb_m_axi_bid  [CB_M_VGA_REG*MST_ID_W +: MST_ID_W] = vga_reg_bid;
    assign cb_m_axi_rvalid[CB_M_VGA_REG] = vga_reg_rvalid;
    assign cb_m_axi_rlast [CB_M_VGA_REG] = vga_reg_rlast;
    assign cb_m_axi_rresp[CB_M_VGA_REG*AXI_RESP_W +: AXI_RESP_W] = vga_reg_rresp;
    assign cb_m_axi_rid  [CB_M_VGA_REG*MST_ID_W +: MST_ID_W] = vga_reg_rid;
    assign cb_m_axi_rdata[CB_M_VGA_REG*DATA_W +: DATA_W] = vga_reg_rdata;
  end else begin : gen_no_axi_vga
    // Keep the fixed S02/M02 ports quiescent until the xbar ports are compacted.
    assign {vga_m_axi_awid, vga_m_axi_awaddr, vga_m_axi_awlen,
            vga_m_axi_awsize, vga_m_axi_awburst, vga_m_axi_awlock,
            vga_m_axi_awcache, vga_m_axi_awprot, vga_m_axi_awvalid,
            vga_m_axi_wdata, vga_m_axi_wstrb, vga_m_axi_wlast,
            vga_m_axi_wvalid, vga_m_axi_bready, vga_m_axi_arid,
            vga_m_axi_araddr, vga_m_axi_arlen, vga_m_axi_arsize,
            vga_m_axi_arburst, vga_m_axi_arlock, vga_m_axi_arcache,
            vga_m_axi_arprot, vga_m_axi_arvalid, vga_m_axi_rready} = '0;
    assign {vga_hsync, vga_vsync, vga_r_5_internal, vga_g_6_internal,
            vga_b_5_internal} = '0;
  end

  // -> AXI4-Lite/32 -> USB OHCI control regs
  if (P.AXI_USB_SUPPORTED) begin : gen_axi_usb
    if (DATA_W == 32) begin : gen_usb_axi32_to_axilite32
        axi_req_t       usb_axi_req;
        axi_resp_t      usb_axi_resp;
        usb_axil_req_t  usb_axil_req;
        usb_axil_rsp_t  usb_axil_rsp;

        always_comb begin
        usb_axi_req = '0;

        usb_axi_req.aw_valid  = cb_m_axi_awvalid[CB_M_USB_REG];
        usb_axi_req.aw.id     = cb_m_axi_awid[CB_M_USB_REG*MST_ID_W +: MST_ID_W];
        usb_axi_req.aw.addr   = cb_m_axi_awaddr[CB_M_USB_REG*ADDR_W +: ADDR_W];
        usb_axi_req.aw.len    = cb_m_axi_awlen[CB_M_USB_REG*AXI_LEN_W +: AXI_LEN_W];
        usb_axi_req.aw.size   = cb_m_axi_awsize[CB_M_USB_REG*AXI_SIZE_W +: AXI_SIZE_W];
        usb_axi_req.aw.burst  = cb_m_axi_awburst[CB_M_USB_REG*AXI_BURST_W +: AXI_BURST_W];
        usb_axi_req.aw.lock   = cb_m_axi_awlock[CB_M_USB_REG];
        usb_axi_req.aw.cache  = cb_m_axi_awcache[CB_M_USB_REG*AXI_CACHE_W +: AXI_CACHE_W];
        usb_axi_req.aw.prot   = cb_m_axi_awprot[CB_M_USB_REG*AXI_PROT_W +: AXI_PROT_W];
        usb_axi_req.aw.qos    = cb_m_axi_awqos[CB_M_USB_REG*AXI_QOS_W +: AXI_QOS_W];
        usb_axi_req.aw.region = '0;
        usb_axi_req.aw.atop   = '0;
        usb_axi_req.aw.user   = '0;

        usb_axi_req.w_valid   = cb_m_axi_wvalid[CB_M_USB_REG];
        usb_axi_req.w.data    = cb_m_axi_wdata[CB_M_USB_REG*DATA_W +: DATA_W];
        usb_axi_req.w.strb    = cb_m_axi_wstrb[CB_M_USB_REG*STRB_W +: STRB_W];
        usb_axi_req.w.last    = cb_m_axi_wlast[CB_M_USB_REG];
        usb_axi_req.w.user    = '0;

        usb_axi_req.b_ready   = cb_m_axi_bready[CB_M_USB_REG];

        usb_axi_req.ar_valid  = cb_m_axi_arvalid[CB_M_USB_REG];
        usb_axi_req.ar.id     = cb_m_axi_arid[CB_M_USB_REG*MST_ID_W +: MST_ID_W];
        usb_axi_req.ar.addr   = cb_m_axi_araddr[CB_M_USB_REG*ADDR_W +: ADDR_W];
        usb_axi_req.ar.len    = cb_m_axi_arlen[CB_M_USB_REG*AXI_LEN_W +: AXI_LEN_W];
        usb_axi_req.ar.size   = cb_m_axi_arsize[CB_M_USB_REG*AXI_SIZE_W +: AXI_SIZE_W];
        usb_axi_req.ar.burst  = cb_m_axi_arburst[CB_M_USB_REG*AXI_BURST_W +: AXI_BURST_W];
        usb_axi_req.ar.lock   = cb_m_axi_arlock[CB_M_USB_REG];
        usb_axi_req.ar.cache  = cb_m_axi_arcache[CB_M_USB_REG*AXI_CACHE_W +: AXI_CACHE_W];
        usb_axi_req.ar.prot   = cb_m_axi_arprot[CB_M_USB_REG*AXI_PROT_W +: AXI_PROT_W];
        usb_axi_req.ar.qos    = cb_m_axi_arqos[CB_M_USB_REG*AXI_QOS_W +: AXI_QOS_W];
        usb_axi_req.ar.region = '0;
        usb_axi_req.ar.user   = '0;

        usb_axi_req.r_ready   = cb_m_axi_rready[CB_M_USB_REG];
        end

        assign usb_reg_awready = usb_axi_resp.aw_ready;
        assign usb_reg_wready  = usb_axi_resp.w_ready;
        assign usb_reg_bvalid  = usb_axi_resp.b_valid;
        assign usb_reg_bresp   = usb_axi_resp.b.resp;
        assign usb_reg_bid     = usb_axi_resp.b.id;
        assign usb_reg_arready = usb_axi_resp.ar_ready;
        assign usb_reg_rvalid  = usb_axi_resp.r_valid;
        assign usb_reg_rdata   = usb_axi_resp.r.data;
        assign usb_reg_rresp   = usb_axi_resp.r.resp;
        assign usb_reg_rlast   = usb_axi_resp.r.last;
        assign usb_reg_rid     = usb_axi_resp.r.id;


        axi_req_t       usb_axi_req_cut;
        axi_resp_t      usb_axi_resp_cut;

        axi_cut #(
        .Bypass     ( 1'b0 ),
        .aw_chan_t  ( aw_chan_t ),
        .w_chan_t   ( w_chan_t  ),
        .b_chan_t   ( b_chan_t  ),
        .ar_chan_t  ( ar_chan_t ),
        .r_chan_t   ( r_chan_t  ),
        .axi_req_t  ( axi_req_t ),
        .axi_resp_t ( axi_resp_t )
        ) i_usb_axi_cut (
            .clk_i      ( BUSCLK       ),
            .rst_ni     ( BUSRSTn      ),
            .slv_req_i  ( usb_axi_req ),
            .slv_resp_o ( usb_axi_resp ),
            .mst_req_o  ( usb_axi_req_cut ),
            .mst_resp_i ( usb_axi_resp_cut )
        );


        axi_to_axi_lite #(
        .AxiAddrWidth    ( ADDR_W         ),
        .AxiDataWidth    ( DATA_W         ),
        .AxiIdWidth      ( MST_ID_W       ),
        .AxiUserWidth    ( AXI_USER_W     ),
        //.AxiMaxWriteTxns ( 2              ),
        .AxiMaxWriteTxns ( 1              ),
        //.AxiMaxReadTxns  ( 2              ),
        .AxiMaxReadTxns  ( 1              ),
        .FallThrough     ( 1'b0           ),
        .full_req_t      ( axi_req_t      ),
        .full_resp_t     ( axi_resp_t     ),
        .lite_req_t      ( usb_axil_req_t ),
        .lite_resp_t     ( usb_axil_rsp_t )
        ) mmio_usbregs_axi32 (
        .clk_i      ( BUSCLK       ),
        .rst_ni     ( BUSRSTn      ),
        .test_i     ( 1'b0         ),
        //.slv_req_i  ( usb_axi_req  ),
        .slv_req_i  ( usb_axi_req_cut  ),
        //.slv_resp_o ( usb_axi_resp ),
        .slv_resp_o ( usb_axi_resp_cut ),
        .mst_req_o  ( usb_axil_req ),
        .mst_resp_i ( usb_axil_rsp )
        );

        wire [31:0] usb_lite_pre_awaddr;
        wire [2:0]  usb_lite_pre_awprot;
        wire        usb_lite_pre_awvalid;
        wire        usb_lite_pre_awready;
        wire [31:0] usb_lite_pre_wdata;
        wire [3:0]  usb_lite_pre_wstrb;
        wire        usb_lite_pre_wvalid;
        wire        usb_lite_pre_wready;
        wire [1:0]  usb_lite_pre_bresp;
        wire        usb_lite_pre_bvalid;
        wire        usb_lite_pre_bready;
        wire [31:0] usb_lite_pre_araddr;
        wire [2:0]  usb_lite_pre_arprot;
        wire        usb_lite_pre_arvalid;
        wire        usb_lite_pre_arready;
        wire [31:0] usb_lite_pre_rdata;
        wire [1:0]  usb_lite_pre_rresp;
        wire        usb_lite_pre_rvalid;
        wire        usb_lite_pre_rready;

        assign usb_lite_pre_awaddr  = usb_axil_req.aw.addr;
        assign usb_lite_pre_awprot  = usb_axil_req.aw.prot;
        assign usb_lite_pre_awvalid = usb_axil_req.aw_valid;
        assign usb_axil_rsp.aw_ready = usb_lite_pre_awready;

        assign usb_lite_pre_wdata   = usb_axil_req.w.data;
        assign usb_lite_pre_wstrb   = usb_axil_req.w.strb;
        assign usb_lite_pre_wvalid  = usb_axil_req.w_valid;
        assign usb_axil_rsp.w_ready = usb_lite_pre_wready;

        assign usb_axil_rsp.b.resp  = usb_lite_pre_bresp;
        assign usb_axil_rsp.b_valid = usb_lite_pre_bvalid;
        assign usb_lite_pre_bready  = usb_axil_req.b_ready;

        assign usb_lite_pre_araddr  = usb_axil_req.ar.addr;
        assign usb_lite_pre_arprot  = usb_axil_req.ar.prot;
        assign usb_lite_pre_arvalid = usb_axil_req.ar_valid;
        assign usb_axil_rsp.ar_ready = usb_lite_pre_arready;

        assign usb_axil_rsp.r.data  = usb_lite_pre_rdata;
        assign usb_axil_rsp.r.resp  = usb_lite_pre_rresp;
        assign usb_axil_rsp.r_valid = usb_lite_pre_rvalid;
        assign usb_lite_pre_rready  = usb_axil_req.r_ready;

        axil_register #(
        .DATA_WIDTH  ( 32 ),
        .ADDR_WIDTH  ( 32 ),
        .STRB_WIDTH  ( 4  ),
        .AW_REG_TYPE ( 1  ),
        .W_REG_TYPE  ( 1  ),
        .B_REG_TYPE  ( 1  ),
        .AR_REG_TYPE ( 1  ),
        .R_REG_TYPE  ( 1  )
        ) i_usb_axil_register (
        .clk             ( BUSCLK ),
        .rst             ( BUSRST ),

        .s_axil_awaddr   ( usb_lite_pre_awaddr ),
        .s_axil_awprot   ( usb_lite_pre_awprot ),
        .s_axil_awvalid  ( usb_lite_pre_awvalid ),
        .s_axil_awready  ( usb_lite_pre_awready ),
        .s_axil_wdata    ( usb_lite_pre_wdata ),
        .s_axil_wstrb    ( usb_lite_pre_wstrb ),
        .s_axil_wvalid   ( usb_lite_pre_wvalid ),
        .s_axil_wready   ( usb_lite_pre_wready ),
        .s_axil_bresp    ( usb_lite_pre_bresp ),
        .s_axil_bvalid   ( usb_lite_pre_bvalid ),
        .s_axil_bready   ( usb_lite_pre_bready ),
        .s_axil_araddr   ( usb_lite_pre_araddr ),
        .s_axil_arprot   ( usb_lite_pre_arprot ),
        .s_axil_arvalid  ( usb_lite_pre_arvalid ),
        .s_axil_arready  ( usb_lite_pre_arready ),
        .s_axil_rdata    ( usb_lite_pre_rdata ),
        .s_axil_rresp    ( usb_lite_pre_rresp ),
        .s_axil_rvalid   ( usb_lite_pre_rvalid ),
        .s_axil_rready   ( usb_lite_pre_rready ),

        .m_axil_awaddr   ( usb_lite_awaddr ),
        .m_axil_awprot   ( usb_lite_awprot ),
        .m_axil_awvalid  ( usb_lite_awvalid ),
        .m_axil_awready  ( usb_lite_awready ),
        .m_axil_wdata    ( usb_lite_wdata ),
        .m_axil_wstrb    ( usb_lite_wstrb ),
        .m_axil_wvalid   ( usb_lite_wvalid ),
        .m_axil_wready   ( usb_lite_wready ),
        .m_axil_bresp    ( usb_lite_bresp ),
        .m_axil_bvalid   ( usb_lite_bvalid ),
        .m_axil_bready   ( usb_lite_bready ),
        .m_axil_araddr   ( usb_lite_araddr ),
        .m_axil_arprot   ( usb_lite_arprot ),
        .m_axil_arvalid  ( usb_lite_arvalid ),
        .m_axil_arready  ( usb_lite_arready ),
        .m_axil_rdata    ( usb_lite_rdata ),
        .m_axil_rresp    ( usb_lite_rresp ),
        .m_axil_rvalid   ( usb_lite_rvalid ),
        .m_axil_rready   ( usb_lite_rready )
        );
    end else begin : gen_usb_axi64_to_axilite32
        // Switched from axi64_mmio_to_axilite32_v2 to parameterized v3 for MST_ID_W IDs.
        // This USB register path must be re-tested.
        axi_mmio_to_axilite32_v3 #(
        .AXI_ADDR_WIDTH ( ADDR_W   ),
        .AXI_DATA_WIDTH ( DATA_W   ),
        .AXI_ID_WIDTH   ( MST_ID_W )
        ) mmio_usbregs (
        .aclk(BUSCLK),
        .aresetn(BUSRSTn),

        // AXI4 slave side from crossbar M03
        .s_axi_awid    (cb_m_axi_awid[CB_M_USB_REG*MST_ID_W +: MST_ID_W]),
        .s_axi_awaddr  (cb_m_axi_awaddr[CB_M_USB_REG*ADDR_W +: ADDR_W]),
        .s_axi_awlen   (cb_m_axi_awlen[CB_M_USB_REG*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_awsize  (cb_m_axi_awsize[CB_M_USB_REG*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_awburst (cb_m_axi_awburst[CB_M_USB_REG*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_awvalid (cb_m_axi_awvalid[CB_M_USB_REG]),
        .s_axi_awready (usb_reg_awready),

        .s_axi_wdata   (cb_m_axi_wdata[CB_M_USB_REG*DATA_W +: DATA_W]),
        .s_axi_wstrb   (cb_m_axi_wstrb[CB_M_USB_REG*STRB_W +: STRB_W]),
        .s_axi_wlast   (cb_m_axi_wlast[CB_M_USB_REG]),
        .s_axi_wvalid  (cb_m_axi_wvalid[CB_M_USB_REG]),
        .s_axi_wready  (usb_reg_wready),

        .s_axi_bresp   (usb_reg_bresp),
        .s_axi_bvalid  (usb_reg_bvalid),
        .s_axi_bid     (usb_reg_bid),
        .s_axi_bready  (cb_m_axi_bready[CB_M_USB_REG]),

        .s_axi_arid    (cb_m_axi_arid[CB_M_USB_REG*MST_ID_W +: MST_ID_W]),
        .s_axi_araddr  (cb_m_axi_araddr[CB_M_USB_REG*ADDR_W +: ADDR_W]),
        .s_axi_arlen   (cb_m_axi_arlen[CB_M_USB_REG*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_arsize  (cb_m_axi_arsize[CB_M_USB_REG*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_arburst (cb_m_axi_arburst[CB_M_USB_REG*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_arvalid (cb_m_axi_arvalid[CB_M_USB_REG]),
        .s_axi_arready (usb_reg_arready),

        .s_axi_rdata   (usb_reg_rdata),
        .s_axi_rresp   (usb_reg_rresp),
        .s_axi_rlast   (usb_reg_rlast),
        .s_axi_rvalid  (usb_reg_rvalid),
        .s_axi_rid     (usb_reg_rid),
        .s_axi_rready  (cb_m_axi_rready[CB_M_USB_REG]),

        // AXI4-Lite master side towards USB OHCI regs
        .m_axil_awaddr (usb_lite_awaddr),
        .m_axil_awprot (usb_lite_awprot),
        .m_axil_awvalid(usb_lite_awvalid),
        .m_axil_awready(usb_lite_awready),

        .m_axil_wdata  (usb_lite_wdata),
        .m_axil_wstrb  (usb_lite_wstrb),
        .m_axil_wvalid (usb_lite_wvalid),
        .m_axil_wready (usb_lite_wready),

        .m_axil_bresp  (usb_lite_bresp),
        .m_axil_bvalid (usb_lite_bvalid),
        .m_axil_bready (usb_lite_bready),

        .m_axil_araddr (usb_lite_araddr),
        .m_axil_arprot (usb_lite_arprot),
        .m_axil_arvalid(usb_lite_arvalid),
        .m_axil_arready(usb_lite_arready),

        .m_axil_rdata  (usb_lite_rdata),
        .m_axil_rresp  (usb_lite_rresp),
        .m_axil_rvalid (usb_lite_rvalid),
        .m_axil_rready (usb_lite_rready)
        );
    end

    BUFG u_bufg_usb (
        .I(clk48MHz_raw),
        .O(clk48MHz)
    );

    (* ASYNC_REG="TRUE" *) logic [1:0] usb_phy_resetn_ff;
    always_ff @(posedge clk48MHz or posedge BUSRST) begin
        if (BUSRST)
        usb_phy_resetn_ff <= 2'b00;            // assert reset immediately
        else
        usb_phy_resetn_ff <= {usb_phy_resetn_ff[0], 1'b1};
    end
    assign usb_phy_resetn_sync = usb_phy_resetn_ff[1];

    // USB OHCI wrapper (SpinalHDL UsbOhciAxi4_p2_dma32/dma64)
    // NOTE: phy_clk should be 48 MHz (or another integer multiple of 12 MHz). rmii_clk50 is only a placeholder.
    usb_ohci_wrap #(
        .DMA_AXI_DATA_WIDTH ( DATA_W   ),
        .DMA_AXI_ID_WIDTH   ( SLV_ID_W )
    ) usb_ohci_i (
        // Clocks / resets
        .ctrl_clk     (BUSCLK),
        .ctrl_aresetn (BUSRSTn),
        .phy_clk   (clk48MHz),
        .phy_aresetn(usb_phy_resetn_sync),

        // Control (AXI4/32, AXI-Lite subset)
        .s_axi_awid    (usb_ctrl_awid),
        .s_axi_awaddr  (usb_ctrl_awaddr),
        .s_axi_awlen   (usb_ctrl_awlen),
        .s_axi_awsize  (usb_ctrl_awsize),
        .s_axi_awburst (usb_ctrl_awburst),
        .s_axi_awlock  (usb_ctrl_awlock),
        .s_axi_awcache (usb_ctrl_awcache),
        .s_axi_awprot  (usb_ctrl_awprot),
        .s_axi_awqos   (usb_ctrl_awqos),
        .s_axi_awvalid (usb_ctrl_awvalid),
        .s_axi_awready (usb_ctrl_awready),

        .s_axi_wdata   (usb_ctrl_wdata),
        .s_axi_wstrb   (usb_ctrl_wstrb),
        .s_axi_wlast   (usb_ctrl_wlast),
        .s_axi_wvalid  (usb_ctrl_wvalid),
        .s_axi_wready  (usb_ctrl_wready),

        .s_axi_bresp   (usb_ctrl_bresp),
        .s_axi_bvalid  (usb_ctrl_bvalid),
        .s_axi_bid     (usb_ctrl_bid),
        .s_axi_bready  (usb_ctrl_bready),

        .s_axi_arid    (usb_ctrl_arid),
        .s_axi_araddr  (usb_ctrl_araddr),
        .s_axi_arlen   (usb_ctrl_arlen),
        .s_axi_arsize  (usb_ctrl_arsize),
        .s_axi_arburst (usb_ctrl_arburst),
        .s_axi_arlock  (usb_ctrl_arlock),
        .s_axi_arcache (usb_ctrl_arcache),
        .s_axi_arprot  (usb_ctrl_arprot),
        .s_axi_arqos   (usb_ctrl_arqos),
        .s_axi_arvalid (usb_ctrl_arvalid),
        .s_axi_arready (usb_ctrl_arready),

        .s_axi_rdata   (usb_ctrl_rdata),
        .s_axi_rresp   (usb_ctrl_rresp),
        .s_axi_rlast   (usb_ctrl_rlast),
        .s_axi_rvalid  (usb_ctrl_rvalid),
        .s_axi_rid     (usb_ctrl_rid),
        .s_axi_rready  (usb_ctrl_rready),

        // DMA master (AXI4 DATA_W) into crossbar S03
        .m_axi_awid    (usb_m_axi_awid),
        .m_axi_awaddr  (usb_m_axi_awaddr),
        .m_axi_awlen   (usb_m_axi_awlen),
        .m_axi_awsize  (usb_m_axi_awsize),
        .m_axi_awburst (usb_m_axi_awburst),
        .m_axi_awlock  (usb_m_axi_awlock),
        .m_axi_awcache (usb_m_axi_awcache),
        .m_axi_awprot  (usb_m_axi_awprot),
        .m_axi_awvalid (usb_m_axi_awvalid),
        .m_axi_awready (usb_m_axi_awready),

        .m_axi_wdata   (usb_m_axi_wdata),
        .m_axi_wstrb   (usb_m_axi_wstrb),
        .m_axi_wlast   (usb_m_axi_wlast),
        .m_axi_wvalid  (usb_m_axi_wvalid),
        .m_axi_wready  (usb_m_axi_wready),

        .m_axi_bid     (usb_m_axi_bid),
        .m_axi_bresp   (usb_m_axi_bresp),
        .m_axi_bvalid  (usb_m_axi_bvalid),
        .m_axi_bready  (usb_m_axi_bready),

        .m_axi_arid    (usb_m_axi_arid),
        .m_axi_araddr  (usb_m_axi_araddr),
        .m_axi_arlen   (usb_m_axi_arlen),
        .m_axi_arsize  (usb_m_axi_arsize),
        .m_axi_arburst (usb_m_axi_arburst),
        .m_axi_arlock  (usb_m_axi_arlock),
        .m_axi_arcache (usb_m_axi_arcache),
        .m_axi_arprot  (usb_m_axi_arprot),
        .m_axi_arvalid (usb_m_axi_arvalid),
        .m_axi_arready (usb_m_axi_arready),

        .m_axi_rid     (usb_m_axi_rid),
        .m_axi_rdata   (usb_m_axi_rdata),
        .m_axi_rresp   (usb_m_axi_rresp),
        .m_axi_rlast   (usb_m_axi_rlast),
        .m_axi_rvalid  (usb_m_axi_rvalid),
        .m_axi_rready  (usb_m_axi_rready),

        // IRQ + D+/D- pins
        .irq_o         (usb_irq),
        .usb0_dp       (usb0_dp),
        .usb0_dm       (usb0_dm),
        .usb1_dp       (usb1_dp),
        .usb1_dm       (usb1_dm)
    );

    assign cb_m_axi_awready[CB_M_USB_REG] = usb_reg_awready;
    assign cb_m_axi_wready [CB_M_USB_REG] = usb_reg_wready;
    assign cb_m_axi_arready[CB_M_USB_REG] = usb_reg_arready;
    assign cb_m_axi_bvalid [CB_M_USB_REG] = usb_reg_bvalid;
    assign cb_m_axi_bresp[CB_M_USB_REG*AXI_RESP_W +: AXI_RESP_W] = usb_reg_bresp;
    assign cb_m_axi_bid  [CB_M_USB_REG*MST_ID_W +: MST_ID_W] = usb_reg_bid;
    assign cb_m_axi_rvalid[CB_M_USB_REG] = usb_reg_rvalid;
    assign cb_m_axi_rlast [CB_M_USB_REG] = usb_reg_rlast;
    assign cb_m_axi_rresp[CB_M_USB_REG*AXI_RESP_W +: AXI_RESP_W] = usb_reg_rresp;
    assign cb_m_axi_rid  [CB_M_USB_REG*MST_ID_W +: MST_ID_W] = usb_reg_rid;
    assign cb_m_axi_rdata[CB_M_USB_REG*DATA_W +: DATA_W] = usb_reg_rdata;
  end else begin : gen_no_axi_usb
    // Keep the fixed S03/M03 ports quiescent until the xbar ports are compacted.
    assign {usb_m_axi_awid, usb_m_axi_awaddr, usb_m_axi_awlen,
            usb_m_axi_awsize, usb_m_axi_awburst, usb_m_axi_awlock,
            usb_m_axi_awcache, usb_m_axi_awprot, usb_m_axi_awvalid,
            usb_m_axi_wdata, usb_m_axi_wstrb, usb_m_axi_wlast,
            usb_m_axi_wvalid, usb_m_axi_bready, usb_m_axi_arid,
            usb_m_axi_araddr, usb_m_axi_arlen, usb_m_axi_arsize,
            usb_m_axi_arburst, usb_m_axi_arlock, usb_m_axi_arcache,
            usb_m_axi_arprot, usb_m_axi_arvalid, usb_m_axi_rready} = '0;
    assign usb_irq = 1'b0;
  end

  // latch/synchronize INT request coming from a different clock domain after two flip-flops
  always_ff @(posedge CPUCLK or negedge peripheral_aresetn) begin
    if (!peripheral_aresetn) begin
        usb_irq_ff1 <= 1'b0;
        usb_irq_ff2 <= 1'b0;
    end else begin
        usb_irq_ff1 <= usb_irq;       // usb_irq is from BUSCLK domain
        usb_irq_ff2 <= usb_irq_ff1;
    end
  end

  if (P.AXI_ETH_SUPPORTED) begin : gen_axi_eth
    liteEthRGMIIAxiWrap  #(
        .RX_BASE(P.AXI_ETH_BASE),
        .TX_BASE(P.AXI_ETH_BASE + 'h1000),
        .CSR_BASE(P.AXI_ETH_BASE + 'h2000),
        .AXI_ADDR_W(ADDR_W),
        .AXI_DATA_W(DATA_W),
        .AXI_ID_W(MST_ID_W)
    ) liteEthAXI   (
        .bus_clk(BUSCLK),
        .bus_resetn(BUSRSTn),   // active-low reset (for adapter/shim)
        .clk200(clk200),    // 200 MHz ref clock
        .clk200_locked(mmcm1_locked),

        // ------------------------------------------------------------
        // AXI4 SLAVE interface (connect directly to crossbar)
        // ------------------------------------------------------------
        .s_axi_awid    (cb_m_axi_awid[CB_M_ETH_REG*MST_ID_W +: MST_ID_W]),
        .s_axi_awaddr  (cb_m_axi_awaddr[CB_M_ETH_REG*ADDR_W +: ADDR_W]),
        .s_axi_awlen   (cb_m_axi_awlen[CB_M_ETH_REG*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_awsize  (cb_m_axi_awsize[CB_M_ETH_REG*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_awburst (cb_m_axi_awburst[CB_M_ETH_REG*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_awvalid (cb_m_axi_awvalid[CB_M_ETH_REG]),
        .s_axi_awready (liteeth_reg_awready),

        .s_axi_wdata   (cb_m_axi_wdata[CB_M_ETH_REG*DATA_W +: DATA_W]),
        .s_axi_wstrb   (cb_m_axi_wstrb[CB_M_ETH_REG*STRB_W +: STRB_W]),
        .s_axi_wlast   (cb_m_axi_wlast[CB_M_ETH_REG]),
        .s_axi_wvalid  (cb_m_axi_wvalid[CB_M_ETH_REG]),
        .s_axi_wready  (liteeth_reg_wready),


        .s_axi_bresp   (liteeth_reg_bresp),
        .s_axi_bvalid  (liteeth_reg_bvalid),
        .s_axi_bid     (liteeth_reg_bid),
        .s_axi_bready  (cb_m_axi_bready[CB_M_ETH_REG]),


        .s_axi_arid    (cb_m_axi_arid[CB_M_ETH_REG*MST_ID_W +: MST_ID_W]),
        .s_axi_araddr  (cb_m_axi_araddr[CB_M_ETH_REG*ADDR_W +: ADDR_W]),
        .s_axi_arlen   (cb_m_axi_arlen[CB_M_ETH_REG*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_arsize  (cb_m_axi_arsize[CB_M_ETH_REG*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_arburst (cb_m_axi_arburst[CB_M_ETH_REG*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_arvalid (cb_m_axi_arvalid[CB_M_ETH_REG]),
        .s_axi_arready (liteeth_reg_arready),

        .s_axi_rdata   (liteeth_reg_rdata),
        .s_axi_rresp   (liteeth_reg_rresp),
        .s_axi_rlast   (liteeth_reg_rlast),
        .s_axi_rvalid  (liteeth_reg_rvalid),
        .s_axi_rid     (liteeth_reg_rid),
        .s_axi_rready  (cb_m_axi_rready[CB_M_ETH_REG]),


        // ------------------------------------------------------------
        // LiteEth PHY pins
        // ------------------------------------------------------------
        .rgmii_clocks_rx(rgmii_clocks_rx),
        .rgmii_clocks_tx(rgmii_clocks_tx),
        .rgmii_int_n(rgmii_int_n),
        .rgmii_mdc(rgmii_mdc),
        .rgmii_mdio(rgmii_mdio),
        .rgmii_rst_n(rgmii_rst_n),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .rgmii_rx_data(rgmii_rx_data),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .rgmii_tx_data(rgmii_tx_data),

        // ------------------------------------------------------------
        // Interrupt (BUS clock domain, raw from core)
        // ------------------------------------------------------------
        .interrupt(liteeth_irq)
    );

    assign cb_m_axi_awready[CB_M_ETH_REG] = liteeth_reg_awready;
    assign cb_m_axi_wready [CB_M_ETH_REG] = liteeth_reg_wready;
    assign cb_m_axi_arready[CB_M_ETH_REG] = liteeth_reg_arready;
    assign cb_m_axi_bvalid [CB_M_ETH_REG] = liteeth_reg_bvalid;
    assign cb_m_axi_bresp[CB_M_ETH_REG*AXI_RESP_W +: AXI_RESP_W] = liteeth_reg_bresp;
    assign cb_m_axi_bid  [CB_M_ETH_REG*MST_ID_W +: MST_ID_W] = liteeth_reg_bid;
    assign cb_m_axi_rvalid[CB_M_ETH_REG] = liteeth_reg_rvalid;
    assign cb_m_axi_rlast [CB_M_ETH_REG] = liteeth_reg_rlast;
    assign cb_m_axi_rresp[CB_M_ETH_REG*AXI_RESP_W +: AXI_RESP_W] = liteeth_reg_rresp;
    assign cb_m_axi_rid  [CB_M_ETH_REG*MST_ID_W +: MST_ID_W] = liteeth_reg_rid;
    assign cb_m_axi_rdata[CB_M_ETH_REG*DATA_W +: DATA_W] = liteeth_reg_rdata;
  end else begin : gen_no_axi_eth
    assign liteeth_irq = 1'b0;
  end


  // latch/synchronize INT request coming from a BUS CLK domain
  always_ff @(posedge CPUCLK or negedge peripheral_aresetn) begin
    if (!peripheral_aresetn) begin
        liteeth_irq_ff1 <= 1'b0;
        liteeth_irq_ff2 <= 1'b0;
    end else begin
        liteeth_irq_ff1 <= liteeth_irq;       // liteeth_irq is from BUSCLK domain
        liteeth_irq_ff2 <= liteeth_irq_ff1;
    end
  end

  if (P.AXI_SDHCI_SUPPORTED) begin : gen_axi_sdhci
    assign SD_CLK   = sd_clk_o;
    assign SD_CMD   = sd_cmd_en ? sd_cmd_o : 1'bz;
    assign sd_cmd_i = SD_CMD;
    assign SD_DAT   = sd_dat_en ? sd_dat_o : 4'bzzzz;
    assign sd_dat_i = SD_DAT;
    assign sd_cd_ni = SD_CD_N;

    axi_sdhci_wrap #(
      .AXI_ADDR_W ( ADDR_W   ),
      .AXI_DATA_W ( DATA_W   ),
      .AXI_ID_W   ( MST_ID_W ),
      .AXI_USER_W ( 1        )
    ) sdhci_i (
      .aclk    (BUSCLK),
      .aresetn (BUSRSTn),

      // AXI slave regs from crossbar M06
      .s_axi_awid    (cb_m_axi_awid[CB_M_SDHCI*MST_ID_W +: MST_ID_W]),
      .s_axi_awaddr  (cb_m_axi_awaddr[CB_M_SDHCI*ADDR_W +: ADDR_W]),
      .s_axi_awlen   (cb_m_axi_awlen[CB_M_SDHCI*AXI_LEN_W +: AXI_LEN_W]),
      .s_axi_awsize  (cb_m_axi_awsize[CB_M_SDHCI*AXI_SIZE_W +: AXI_SIZE_W]),
      .s_axi_awburst (cb_m_axi_awburst[CB_M_SDHCI*AXI_BURST_W +: AXI_BURST_W]),
      .s_axi_awlock  (cb_m_axi_awlock[CB_M_SDHCI]),
      .s_axi_awcache (cb_m_axi_awcache[CB_M_SDHCI*AXI_CACHE_W +: AXI_CACHE_W]),
      .s_axi_awprot  (cb_m_axi_awprot[CB_M_SDHCI*AXI_PROT_W +: AXI_PROT_W]),
      .s_axi_awqos   (cb_m_axi_awqos[CB_M_SDHCI*AXI_QOS_W +: AXI_QOS_W]),
      .s_axi_awvalid (cb_m_axi_awvalid[CB_M_SDHCI]),
      .s_axi_awready (sdhci_reg_awready),

      .s_axi_wdata   (cb_m_axi_wdata[CB_M_SDHCI*DATA_W +: DATA_W]),
      .s_axi_wstrb   (cb_m_axi_wstrb[CB_M_SDHCI*STRB_W +: STRB_W]),
      .s_axi_wlast   (cb_m_axi_wlast[CB_M_SDHCI]),
      .s_axi_wvalid  (cb_m_axi_wvalid[CB_M_SDHCI]),
      .s_axi_wready  (sdhci_reg_wready),

      .s_axi_bresp   (sdhci_reg_bresp),
      .s_axi_bvalid  (sdhci_reg_bvalid),
      .s_axi_bid     (sdhci_reg_bid),
      .s_axi_bready  (cb_m_axi_bready[CB_M_SDHCI]),

      .s_axi_arid    (cb_m_axi_arid[CB_M_SDHCI*MST_ID_W +: MST_ID_W]),
      .s_axi_araddr  (cb_m_axi_araddr[CB_M_SDHCI*ADDR_W +: ADDR_W]),
      .s_axi_arlen   (cb_m_axi_arlen[CB_M_SDHCI*AXI_LEN_W +: AXI_LEN_W]),
      .s_axi_arsize  (cb_m_axi_arsize[CB_M_SDHCI*AXI_SIZE_W +: AXI_SIZE_W]),
      .s_axi_arburst (cb_m_axi_arburst[CB_M_SDHCI*AXI_BURST_W +: AXI_BURST_W]),
      .s_axi_arlock  (cb_m_axi_arlock[CB_M_SDHCI]),
      .s_axi_arcache (cb_m_axi_arcache[CB_M_SDHCI*AXI_CACHE_W +: AXI_CACHE_W]),
      .s_axi_arprot  (cb_m_axi_arprot[CB_M_SDHCI*AXI_PROT_W +: AXI_PROT_W]),
      .s_axi_arqos   (cb_m_axi_arqos[CB_M_SDHCI*AXI_QOS_W +: AXI_QOS_W]),
      .s_axi_arvalid (cb_m_axi_arvalid[CB_M_SDHCI]),
      .s_axi_arready (sdhci_reg_arready),

      .s_axi_rdata   (sdhci_reg_rdata),
      .s_axi_rresp   (sdhci_reg_rresp),
      .s_axi_rlast   (sdhci_reg_rlast),
      .s_axi_rvalid  (sdhci_reg_rvalid),
      .s_axi_rid     (sdhci_reg_rid),
      .s_axi_rready  (cb_m_axi_rready[CB_M_SDHCI]),

      .sd_clk_o      (sd_clk_o),
      .sd_cd_ni      (sd_cd_ni),
      .sd_cmd_en_o   (sd_cmd_en),
      .sd_cmd_o      (sd_cmd_o),
      .sd_cmd_i      (sd_cmd_i),
      .sd_dat_i      (sd_dat_i),
      .sd_dat_o      (sd_dat_o),
      .sd_dat_en_o   (sd_dat_en),

      .interrupt_o   (sdhci_irq)
    );

    // ---------------------------------------------------------------------------
    // ---------------------------------------------------------------------------
    // SDHCI debug taps: command path
    // ---------------------------------------------------------------------------
    // (* mark_debug = "true" *) logic [5:0]  dbg_sdhci_current_cmd;
    // (* mark_debug = "true" *) logic [31:0] dbg_sdhci_current_arg;
    // (* mark_debug = "true" *) logic        dbg_sdhci_cmd_started;
    // (* mark_debug = "true" *) logic        dbg_sdhci_cmd_data_present;
    // (* mark_debug = "true" *) logic        dbg_sdhci_cmd_xfer_dir;
    // (* mark_debug = "true" *) logic        dbg_sdhci_cmd_needs_busy;
    // (* mark_debug = "true" *) logic        dbg_sdhci_sd_cmd_done;
    // (* mark_debug = "true" *) logic        dbg_sdhci_sd_rsp_done;

    // (* mark_debug = "true" *) logic        dbg_sdhci_cmd_result_valid;
    // (* mark_debug = "true" *) logic        dbg_sdhci_cmd_timeout_error;
    // (* mark_debug = "true" *) logic        dbg_sdhci_cmd_crc_error;
    // (* mark_debug = "true" *) logic        dbg_sdhci_cmd_index_error;
    // (* mark_debug = "true" *) logic        dbg_sdhci_cmd_end_bit_error;

    // assign dbg_sdhci_current_cmd       = sdhci_i.i_axi_sdhci.i_autocmd_wrap.current_cmd;
    // assign dbg_sdhci_current_arg       = sdhci_i.i_axi_sdhci.i_autocmd_wrap.current_arg;
    // assign dbg_sdhci_cmd_started       = sdhci_i.i_axi_sdhci.cmd_started;
    // assign dbg_sdhci_cmd_data_present  = sdhci_i.i_axi_sdhci.cmd_data_present;
    // assign dbg_sdhci_cmd_xfer_dir      = sdhci_i.i_axi_sdhci.cmd_transfer_direction;
    // assign dbg_sdhci_cmd_needs_busy    = sdhci_i.i_axi_sdhci.cmd_needs_busy;
    // assign dbg_sdhci_sd_cmd_done       = sdhci_i.i_axi_sdhci.sd_cmd_done;
    // assign dbg_sdhci_sd_rsp_done       = sdhci_i.i_axi_sdhci.sd_rsp_done;

    // assign dbg_sdhci_cmd_result_valid  = sdhci_i.i_axi_sdhci.i_autocmd_wrap.cmd_result_valid;
    // assign dbg_sdhci_cmd_timeout_error = sdhci_i.i_axi_sdhci.i_autocmd_wrap.timeout_error;
    // assign dbg_sdhci_cmd_crc_error     = sdhci_i.i_axi_sdhci.i_autocmd_wrap.crc_error;
    // assign dbg_sdhci_cmd_index_error   = sdhci_i.i_axi_sdhci.i_autocmd_wrap.index_error;
    // assign dbg_sdhci_cmd_end_bit_error = sdhci_i.i_axi_sdhci.i_autocmd_wrap.end_bit_error;

    // // ---------------------------------------------------------------------------
    // // SDHCI debug taps: mode / register-derived state
    // // ---------------------------------------------------------------------------
    // (* mark_debug = "true" *) logic        dbg_sdhci_bus_width_4;
    // (* mark_debug = "true" *) logic [9:0]  dbg_sdhci_block_size;
    // (* mark_debug = "true" *) logic [15:0] dbg_sdhci_block_count;
    // (* mark_debug = "true" *) logic        dbg_sdhci_read_transfer_active;
    // (* mark_debug = "true" *) logic        dbg_sdhci_write_transfer_active;
    // (* mark_debug = "true" *) logic        dbg_sdhci_buffer_read_enable;
    // (* mark_debug = "true" *) logic        dbg_sdhci_buffer_write_enable;
    // (* mark_debug = "true" *) logic        dbg_sdhci_pause_sd_clk;

    // assign dbg_sdhci_bus_width_4          = sdhci_i.i_axi_sdhci.reg2hw.host_control.data_transfer_width.q;
    // assign dbg_sdhci_block_size           = sdhci_i.i_axi_sdhci.reg2hw.block_size.transfer_block_size.q;
    // assign dbg_sdhci_block_count          = sdhci_i.i_axi_sdhci.reg2hw.block_count.q;
    // assign dbg_sdhci_read_transfer_active = sdhci_i.i_axi_sdhci.reg2hw.present_state.read_transfer_active.q;
    // assign dbg_sdhci_write_transfer_active= sdhci_i.i_axi_sdhci.reg2hw.present_state.write_transfer_active.q;
    // assign dbg_sdhci_buffer_read_enable   = sdhci_i.i_axi_sdhci.hw2reg.present_state.buffer_read_enable.d;
    // assign dbg_sdhci_buffer_write_enable  = sdhci_i.i_axi_sdhci.hw2reg.present_state.buffer_write_enable.d;
    // assign dbg_sdhci_pause_sd_clk         = sdhci_i.i_axi_sdhci.pause_sd_clk;

    // // ---------------------------------------------------------------------------
    // // SDHCI debug taps: data FSM
    // // ---------------------------------------------------------------------------
    // (* mark_debug = "true" *) logic [1:0]  dbg_sdhci_dat_state;
    // (* mark_debug = "true" *) logic [2:0]  dbg_sdhci_read_state;
    // (* mark_debug = "true" *) logic [2:0]  dbg_sdhci_write_state;

    // (* mark_debug = "true" *) logic        dbg_sdhci_start_read;
    // (* mark_debug = "true" *) logic        dbg_sdhci_read_valid;
    // (* mark_debug = "true" *) logic        dbg_sdhci_read_done;
    // (* mark_debug = "true" *) logic        dbg_sdhci_read_crc_err;
    // (* mark_debug = "true" *) logic        dbg_sdhci_read_end_bit_err;
    // (* mark_debug = "true" *) logic        dbg_sdhci_timeout_elapsed;

    // (* mark_debug = "true" *) logic        dbg_sdhci_buffer_write_valid;
    // (* mark_debug = "true" *) logic        dbg_sdhci_buffer_write_ready;
    // (* mark_debug = "true" *) logic [31:0] dbg_sdhci_buffer_write_data;
    // (* mark_debug = "true" *) logic        dbg_sdhci_buffer_read_valid;
    // (* mark_debug = "true" *) logic        dbg_sdhci_buffer_read_ready;
    // (* mark_debug = "true" *) logic [31:0] dbg_sdhci_buffer_read_data;
    // (* mark_debug = "true" *) logic        dbg_sdhci_buffer_empty;

    // assign dbg_sdhci_dat_state           = sdhci_i.i_axi_sdhci.i_dat_wrap.dat_state_q;
    // assign dbg_sdhci_read_state          = sdhci_i.i_axi_sdhci.i_dat_wrap.read_state_q;
    // assign dbg_sdhci_write_state         = sdhci_i.i_axi_sdhci.i_dat_wrap.write_state_q;

    // assign dbg_sdhci_start_read          = sdhci_i.i_axi_sdhci.i_dat_wrap.start_read;
    // assign dbg_sdhci_read_valid          = sdhci_i.i_axi_sdhci.i_dat_wrap.read_valid;
    // assign dbg_sdhci_read_done           = sdhci_i.i_axi_sdhci.i_dat_wrap.read_done;
    // assign dbg_sdhci_read_crc_err        = sdhci_i.i_axi_sdhci.i_dat_wrap.read_crc_err;
    // assign dbg_sdhci_read_end_bit_err    = sdhci_i.i_axi_sdhci.i_dat_wrap.read_end_bit_err;
    // assign dbg_sdhci_timeout_elapsed     = sdhci_i.i_axi_sdhci.i_dat_wrap.timeout_elapsed;

    // assign dbg_sdhci_buffer_write_valid  = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_write_valid;
    // assign dbg_sdhci_buffer_write_ready  = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_write_ready;
    // assign dbg_sdhci_buffer_write_data   = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_write_data;
    // assign dbg_sdhci_buffer_read_valid   = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_read_valid;
    // assign dbg_sdhci_buffer_read_ready   = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_read_ready;
    // assign dbg_sdhci_buffer_read_data    = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_read_data;
    // assign dbg_sdhci_buffer_empty        = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_empty;

    // // ---------------------------------------------------------------------------
    // // SDHCI debug taps: dat_buffer / SRAM shift register
    // // ---------------------------------------------------------------------------
    // (* mark_debug = "true" *) logic        dbg_sdhci_reg_push;
    // (* mark_debug = "true" *) logic [31:0] dbg_sdhci_reg_push_data;
    // (* mark_debug = "true" *) logic        dbg_sdhci_reg_pop;
    // (* mark_debug = "true" *) logic [31:0] dbg_sdhci_reg_pop_data;
    // (* mark_debug = "true" *) logic        dbg_sdhci_reg_empty;
    // (* mark_debug = "true" *) logic [8:0]  dbg_sdhci_reg_length;
    // (* mark_debug = "true" *) logic        dbg_sdhci_has_block;
    // (* mark_debug = "true" *) logic        dbg_sdhci_has_space;
    // (* mark_debug = "true" *) logic [9:0]  dbg_sdhci_current_word_counter;

    // (* mark_debug = "true" *) logic        dbg_sdhci_sram_en;
    // (* mark_debug = "true" *) logic        dbg_sdhci_sram_pop_front_i;
    // (* mark_debug = "true" *) logic        dbg_sdhci_sram_pop_front_q;
    // (* mark_debug = "true" *) logic        dbg_sdhci_sram_push_back_i;
    // (* mark_debug = "true" *) logic [31:0] dbg_sdhci_sram_back_data_i;
    // (* mark_debug = "true" *) logic [31:0] dbg_sdhci_sram_front_data_o;
    // (* mark_debug = "true" *) logic        dbg_sdhci_sram_empty_o;
    // (* mark_debug = "true" *) logic [8:0]  dbg_sdhci_sram_length_o;

    // assign dbg_sdhci_reg_push            = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_push;
    // assign dbg_sdhci_reg_push_data       = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_push_data;
    // assign dbg_sdhci_reg_pop             = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_pop;
    // assign dbg_sdhci_reg_pop_data        = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_pop_data;
    // assign dbg_sdhci_reg_empty           = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_empty;
    // assign dbg_sdhci_reg_length          = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_length;
    // assign dbg_sdhci_has_block           = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.has_block;
    // // not in newer version of the RTL
    // //assign dbg_sdhci_has_space           = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.has_space;
    // assign dbg_sdhci_current_word_counter= sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.current_word_counter_q;

    // assign dbg_sdhci_sram_en             = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.en_i;
    // assign dbg_sdhci_sram_pop_front_i    = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.pop_front_i;
    // assign dbg_sdhci_sram_pop_front_q    = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.pop_front_q;
    // assign dbg_sdhci_sram_push_back_i    = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.push_back_i;
    // assign dbg_sdhci_sram_back_data_i    = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.back_data_i;
    // assign dbg_sdhci_sram_front_data_o   = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.front_data_o;
    // assign dbg_sdhci_sram_empty_o        = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.empty_o;
    // assign dbg_sdhci_sram_length_o       = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.length_o;

    // // ---------------------------------------------------------------------------
    // // SDHCI debug taps: command response / R2 CRC path
    // // ---------------------------------------------------------------------------
    // (* mark_debug = "true" *) logic [2:0]   dbg_sdhci_cmd_state;
    // (* mark_debug = "true" *) logic [6:0]   dbg_sdhci_cmd_cycles_waiting;
    // (* mark_debug = "true" *) logic [1:0]   dbg_sdhci_accepted_rsp_type;

    // (* mark_debug = "true" *) logic [2:0]   dbg_sdhci_rsp_rx_state;
    // (* mark_debug = "true" *) logic [7:0]   dbg_sdhci_rsp_bit_cnt;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp_long;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp_receiving;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp_start_bit_observed;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp_all_bits_received;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp_capture_bit;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp_capture_word_bit;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp_crc_start;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp_crc_end_output;
    // (* mark_debug = "true" *) logic [6:0]   dbg_sdhci_rsp_crc7_calc;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp_crc_corr;
    // (* mark_debug = "true" *) logic [31:0]  dbg_sdhci_rsp0;
    // (* mark_debug = "true" *) logic [31:0]  dbg_sdhci_rsp1;
    // (* mark_debug = "true" *) logic [31:0]  dbg_sdhci_rsp2;
    // (* mark_debug = "true" *) logic [31:0]  dbg_sdhci_rsp3;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp0_de;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp1_de;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp2_de;
    // (* mark_debug = "true" *) logic         dbg_sdhci_rsp3_de;

    // (* mark_debug = "true" *) logic [159:0] dbg_sdhci_cmd_resp_shift;
    // (* mark_debug = "true" *) logic [7:0]   dbg_sdhci_cmd_resp_shift_count;
    // (* mark_debug = "true" *) logic         dbg_sdhci_cmd_resp_shift_active;
    // (* mark_debug = "true" *) logic         dbg_sdhci_sd_clk_en_p;

    // assign dbg_sdhci_cmd_state          = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.cmd_state_q;
    // assign dbg_sdhci_cmd_cycles_waiting = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.cycles_waiting;
    // assign dbg_sdhci_accepted_rsp_type  = sdhci_i.i_axi_sdhci.i_autocmd_wrap.accepted_rsp_type_q;

    // assign dbg_sdhci_rsp_rx_state             = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.rx_state_q;
    // assign dbg_sdhci_rsp_bit_cnt              = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.bit_cnt;
    // assign dbg_sdhci_rsp_long                 = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.long_rsp_i;
    // assign dbg_sdhci_rsp_receiving            = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.receiving_o;
    // assign dbg_sdhci_rsp_start_bit_observed   = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.start_bit_observed;
    // assign dbg_sdhci_rsp_all_bits_received    = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.all_bits_received;
    // assign dbg_sdhci_rsp_capture_bit          = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.capture_response_bit;
    // assign dbg_sdhci_rsp_capture_word_bit     = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.capture_word_bit;
    // assign dbg_sdhci_rsp_crc_start            = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.crc_start;
    // assign dbg_sdhci_rsp_crc_end_output       = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.crc_end_output;
    // assign dbg_sdhci_rsp_crc7_calc            = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.crc7_calc;
    // assign dbg_sdhci_rsp_crc_corr             = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.crc_corr_o;
    // assign dbg_sdhci_rsp0                     = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.response0_d_o;
    // assign dbg_sdhci_rsp1                     = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.response1_d_o;
    // assign dbg_sdhci_rsp2                     = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.response2_d_o;
    // assign dbg_sdhci_rsp3                     = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.response3_d_o;
    // assign dbg_sdhci_rsp0_de                  = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.response0_de_o;
    // assign dbg_sdhci_rsp1_de                  = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.response1_de_o;
    // assign dbg_sdhci_rsp2_de                  = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.response2_de_o;
    // assign dbg_sdhci_rsp3_de                  = sdhci_i.i_axi_sdhci.i_autocmd_wrap.i_cmd_logic.i_rsp_read.response3_de_o;
    // assign dbg_sdhci_sd_clk_en_p              = sdhci_i.i_axi_sdhci.sd_clk_en_p;

    // always_ff @(posedge BUSCLK or negedge BUSRSTn) begin
    //   if (!BUSRSTn) begin
    //     dbg_sdhci_cmd_resp_shift        <= '0;
    //     dbg_sdhci_cmd_resp_shift_count  <= '0;
    //     dbg_sdhci_cmd_resp_shift_active <= 1'b0;
    //   end else begin
    //     if (dbg_sdhci_cmd_started) begin
    //       dbg_sdhci_cmd_resp_shift        <= '0;
    //       dbg_sdhci_cmd_resp_shift_count  <= '0;
    //       dbg_sdhci_cmd_resp_shift_active <= 1'b0;
    //     end else if (dbg_sdhci_rsp_start_bit_observed) begin
    //       dbg_sdhci_cmd_resp_shift        <= {{159{1'b0}}, sd_cmd_i};
    //       dbg_sdhci_cmd_resp_shift_count  <= 8'd1;
    //       dbg_sdhci_cmd_resp_shift_active <= 1'b1;
    //     end else if (dbg_sdhci_sd_clk_en_p && dbg_sdhci_cmd_resp_shift_active) begin
    //       dbg_sdhci_cmd_resp_shift <= {dbg_sdhci_cmd_resp_shift[158:0], sd_cmd_i};
    //       if (dbg_sdhci_cmd_resp_shift_count != 8'd160) begin
    //         dbg_sdhci_cmd_resp_shift_count <= dbg_sdhci_cmd_resp_shift_count + 8'd1;
    //       end
    //       if (dbg_sdhci_cmd_result_valid || dbg_sdhci_cmd_timeout_error) begin
    //         dbg_sdhci_cmd_resp_shift_active <= 1'b0;
    //       end
    //     end
    //   end
    // end

    assign cb_m_axi_awready[CB_M_SDHCI] = sdhci_reg_awready;
    assign cb_m_axi_wready [CB_M_SDHCI] = sdhci_reg_wready;
    assign cb_m_axi_arready[CB_M_SDHCI] = sdhci_reg_arready;
    assign cb_m_axi_bvalid [CB_M_SDHCI] = sdhci_reg_bvalid;
    assign cb_m_axi_bresp[CB_M_SDHCI*AXI_RESP_W +: AXI_RESP_W] = sdhci_reg_bresp;
    assign cb_m_axi_bid  [CB_M_SDHCI*MST_ID_W +: MST_ID_W] = sdhci_reg_bid;
    assign cb_m_axi_rvalid[CB_M_SDHCI] = sdhci_reg_rvalid;
    assign cb_m_axi_rlast [CB_M_SDHCI] = sdhci_reg_rlast;
    assign cb_m_axi_rresp[CB_M_SDHCI*AXI_RESP_W +: AXI_RESP_W] = sdhci_reg_rresp;
    assign cb_m_axi_rid  [CB_M_SDHCI*MST_ID_W +: MST_ID_W] = sdhci_reg_rid;
    assign cb_m_axi_rdata[CB_M_SDHCI*DATA_W +: DATA_W] = sdhci_reg_rdata;
  end else begin : gen_no_axi_sdhci
    assign SD_CLK = 1'b0;
    assign SD_CMD = 1'bz;
    assign SD_DAT = 4'bzzzz;

    assign sdhci_irq = 1'b0;
    assign {sd_clk_o, sd_cd_ni, sd_cmd_en, sd_cmd_o, sd_cmd_i, sd_dat_en, sd_dat_o, sd_dat_i} = '0;

    assign sdhci_reg_awready = 1'b0;
    assign sdhci_reg_wready  = 1'b0;
    assign sdhci_reg_arready = 1'b0;
    assign sdhci_reg_bvalid  = 1'b0;
    assign sdhci_reg_bresp   = 2'b00;
    assign sdhci_reg_bid     = '0;
    assign sdhci_reg_rvalid  = 1'b0;
    assign sdhci_reg_rlast   = 1'b0;
    assign sdhci_reg_rresp   = 2'b00;
    assign sdhci_reg_rid     = '0;
    assign sdhci_reg_rdata   = '0;
  end

  always_ff @(posedge CPUCLK or negedge peripheral_aresetn) begin
    if (!peripheral_aresetn) begin
        sdhci_irq_ff1 <= 1'b0;
        sdhci_irq_ff2 <= 1'b0;
    end else begin
        sdhci_irq_ff1 <= sdhci_irq;       // sdhci_irq is from BUSCLK domain
        sdhci_irq_ff2 <= sdhci_irq_ff1;
    end
  end


  if (P.XILINX_AXI_DMA_SUPPORTED) begin : gen_axicdma
    assign idma_xbar_mst_req = '0;
    assign idma_xbar_slv_rsp = '0;

    // M01 -> MMIO bridge -> AXI4-Lite/32 -> CDMA regs
    // Switched from axi64_mmio_to_axilite32_v2 to parameterized v3 for MST_ID_W IDs.
    // This CDMA register path has not been re-tested after the adapter change.
    axi_mmio_to_axilite32_v3 #(
      .AXI_ADDR_WIDTH ( ADDR_W   ),
      .AXI_DATA_WIDTH ( DATA_W   ),
      .AXI_ID_WIDTH   ( MST_ID_W )
    ) mmio_cdmaregs (
      .aclk(BUSCLK),
      .aresetn(BUSRSTn),

        // AXI4 slave side from crossbar M01
        .s_axi_awid    (cb_m_axi_awid[CB_M_CDMA_REG*MST_ID_W +: MST_ID_W]),
        .s_axi_awaddr  (cb_m_axi_awaddr[CB_M_CDMA_REG*ADDR_W +: ADDR_W]),
        .s_axi_awlen   (cb_m_axi_awlen[CB_M_CDMA_REG*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_awsize  (cb_m_axi_awsize[CB_M_CDMA_REG*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_awburst (cb_m_axi_awburst[CB_M_CDMA_REG*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_awvalid (cb_m_axi_awvalid[CB_M_CDMA_REG]),
        .s_axi_awready (reg_awready),

        .s_axi_wdata   (cb_m_axi_wdata[CB_M_CDMA_REG*DATA_W +: DATA_W]),
        .s_axi_wstrb   (cb_m_axi_wstrb[CB_M_CDMA_REG*STRB_W +: STRB_W]),
        .s_axi_wlast   (cb_m_axi_wlast[CB_M_CDMA_REG]),
        .s_axi_wvalid  (cb_m_axi_wvalid[CB_M_CDMA_REG]),
        .s_axi_wready  (reg_wready),

        .s_axi_bresp   (reg_bresp),
        .s_axi_bvalid  (reg_bvalid),
        .s_axi_bid     (reg_bid),
        .s_axi_bready  (cb_m_axi_bready[CB_M_CDMA_REG]),

        .s_axi_arid    (cb_m_axi_arid[CB_M_CDMA_REG*MST_ID_W +: MST_ID_W]),
        .s_axi_araddr  (cb_m_axi_araddr[CB_M_CDMA_REG*ADDR_W +: ADDR_W]),
        .s_axi_arlen   (cb_m_axi_arlen[CB_M_CDMA_REG*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_arsize  (cb_m_axi_arsize[CB_M_CDMA_REG*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_arburst (cb_m_axi_arburst[CB_M_CDMA_REG*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_arvalid (cb_m_axi_arvalid[CB_M_CDMA_REG]),
        .s_axi_arready (reg_arready),

        .s_axi_rdata   (reg_rdata),
        .s_axi_rresp   (reg_rresp),
        .s_axi_rlast   (reg_rlast),
        .s_axi_rvalid  (reg_rvalid),
        .s_axi_rid     (reg_rid),
        .s_axi_rready  (cb_m_axi_rready[CB_M_CDMA_REG]),

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
      .s_axi_lite_aresetn(BUSRSTn),

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

      .cdma_introut  (dma_irq_raw)
    );
    assign cb_m_axi_awready[CB_M_CDMA_REG] = reg_awready;
    assign cb_m_axi_wready [CB_M_CDMA_REG] = reg_wready;
    assign cb_m_axi_arready[CB_M_CDMA_REG] = reg_arready;
    assign cb_m_axi_bvalid [CB_M_CDMA_REG] = reg_bvalid;
    assign cb_m_axi_bresp[CB_M_CDMA_REG*AXI_RESP_W +: AXI_RESP_W] = reg_bresp;
    assign cb_m_axi_bid  [CB_M_CDMA_REG*MST_ID_W +: MST_ID_W] = reg_bid;
    assign cb_m_axi_rvalid[CB_M_CDMA_REG] = reg_rvalid;
    assign cb_m_axi_rlast [CB_M_CDMA_REG] = reg_rlast;
    assign cb_m_axi_rresp[CB_M_CDMA_REG*AXI_RESP_W +: AXI_RESP_W] = reg_rresp;
    assign cb_m_axi_rid  [CB_M_CDMA_REG*MST_ID_W +: MST_ID_W] = reg_rid;
    assign cb_m_axi_rdata[CB_M_CDMA_REG*DATA_W +: DATA_W] = reg_rdata;
  end else if (P.AXI_IDMA_SUPPORTED || P.AXI_IDMA_REG64_SUPPORTED ||
               P.AXIS_IDMA_SUPPORTED) begin : gen_idma
    assign reg_awready = 1'b0;
    assign reg_wready  = 1'b0;
    assign reg_arready = 1'b0;
    assign reg_bvalid  = 1'b0;
    assign reg_bresp   = 2'b00;
    assign reg_bid     = '0;
    assign reg_rvalid  = 1'b0;
    assign reg_rlast   = 1'b0;
    assign reg_rresp   = 2'b00;
    assign reg_rid     = '0;
    assign reg_rdata   = '0;

    assign pc_lite_awaddr  = '0;
    assign pc_lite_awprot  = '0;
    assign pc_lite_awvalid = 1'b0;
    assign pc_lite_awready = 1'b0;
    assign pc_lite_wdata   = '0;
    assign pc_lite_wstrb   = '0;
    assign pc_lite_wvalid  = 1'b0;
    assign pc_lite_wready  = 1'b0;
    assign pc_lite_bresp   = 2'b00;
    assign pc_lite_bvalid  = 1'b0;
    assign pc_lite_bready  = 1'b0;
    assign pc_lite_araddr  = '0;
    assign pc_lite_arprot  = '0;
    assign pc_lite_arvalid = 1'b0;
    assign pc_lite_arready = 1'b0;
    assign pc_lite_rdata   = '0;
    assign pc_lite_rresp   = 2'b00;
    assign pc_lite_rvalid  = 1'b0;
    assign pc_lite_rready  = 1'b0;

    assign cdma_m_axi_awaddr  = '0;
    assign cdma_m_axi_awlen   = '0;
    assign cdma_m_axi_awsize  = '0;
    assign cdma_m_axi_awburst = '0;
    assign cdma_m_axi_awcache = '0;
    assign cdma_m_axi_awprot  = '0;
    assign cdma_m_axi_awvalid = 1'b0;
    assign cdma_m_axi_wdata   = '0;
    assign cdma_m_axi_wstrb   = '0;
    assign cdma_m_axi_wlast   = 1'b0;
    assign cdma_m_axi_wvalid  = 1'b0;
    assign cdma_m_axi_bready  = 1'b0;
    assign cdma_m_axi_araddr  = '0;
    assign cdma_m_axi_arlen   = '0;
    assign cdma_m_axi_arsize  = '0;
    assign cdma_m_axi_arburst = '0;
    assign cdma_m_axi_arcache = '0;
    assign cdma_m_axi_arprot  = '0;
    assign cdma_m_axi_arvalid = 1'b0;
    assign cdma_m_axi_rready  = 1'b0;

    localparam int unsigned AudioFifoDepth = 16384;
    logic [$clog2(AudioFifoDepth):0] audio_fifo_depth;

    idma_axi_axis_wrap #(
      .AxiAddrWidth      ( ADDR_W               ),
      .AxiDataWidth      ( DATA_W               ),
      .AxiIdWidth        ( SLV_ID_W             ),
      .AxiUserWidth      ( 1                    ),
      .AxiSlvIdWidth     ( MST_ID_W             ),
      .AxiMaxReadTxns    ( 4                    ),
      .AxiMaxWriteTxns   ( 4                    ),
      .NumAxInFlight     ( 4                    ),
      .MemSysDepth       ( 0                    ),
      .JobFifoDepth      ( 2                    ),
      .RAWCouplingAvail  ( 1'b0                 ),
      .EnableDesc64      ( P.AXI_IDMA_SUPPORTED ),
      .EnableDesc64AxiAxis ( P.AXIS_IDMA_SUPPORTED ),
      .EnableReg64       ( P.AXI_IDMA_REG64_SUPPORTED ),
      .EnableReg64TwoD   ( 1'b0                 ),
      .EnableAxisFifoAdmission ( P.AXIS_IDMA_SUPPORTED ),
      .AxisFifoCapacityBytes ( AudioFifoDepth   ),
      .axi_mst_req_t     ( slv_req_t            ),
      .axi_mst_rsp_t     ( slv_resp_t           ),
      .axi_slv_req_t     ( mst_req_t            ),
      .axi_slv_rsp_t     ( mst_resp_t           ),
      .axis_t_chan_t     ( axis_t_chan_t        ),
      .axis_req_t        ( axis_req_t           ),
      .axis_rsp_t        ( axis_rsp_t           )
    ) idma_i (
      .clk_i             ( BUSCLK               ),
      .rst_ni            ( BUSCORERSTn          ),
      .testmode_i        ( 1'b0                 ),
      .axi_mst_fe_req_o  ( idma_xbar_mst_req[1:0] ),
      .axi_mst_fe_rsp_i  ( idma_xbar_mst_rsp[1:0] ),
      .axi_mst_be_req_o  ( idma_xbar_mst_req[2] ),
      .axi_mst_be_rsp_i  ( idma_xbar_mst_rsp[2] ),
      .axi_slv_req_i     ( idma_xbar_slv_req    ),
      .axi_slv_rsp_o     ( idma_xbar_slv_rsp    ),
      .axis_write_req_o  ( idma_axis_req        ),
      .axis_write_rsp_i  ( idma_axis_rsp        ),
      .axis_fifo_occupancy_i ( audio_fifo_depth ),
      .axis_irq_o        ( dma_irq_raw )
    );

    if (P.AXIS_I2S_SUPPORTED) begin : gen_axis_i2s
      logic [31:0] audio_fifo_tdata;
      logic audio_fifo_tvalid;
      logic audio_fifo_tready;
      logic [31:0] audio_axis_tdata;
      logic audio_axis_tvalid;
      logic audio_axis_tready;
      logic audio_axis_tlast;

      axis_async_fifo_adapter #(
        .DEPTH          ( AudioFifoDepth ),
        .S_DATA_WIDTH   ( DATA_W   ),
        .S_KEEP_ENABLE  ( 1        ),
        .S_KEEP_WIDTH   ( STRB_W   ),
        .M_DATA_WIDTH   ( 32       ),
        .M_KEEP_ENABLE  ( 1        ),
        .M_KEEP_WIDTH   ( 4        ),
        .ID_ENABLE      ( 0        ),
        .ID_WIDTH       ( SLV_ID_W ),
        .DEST_ENABLE    ( 0        ),
        .DEST_WIDTH     ( SLV_ID_W ),
        .USER_ENABLE    ( 0        ),
        .USER_WIDTH     ( 1        ),
        .PAUSE_ENABLE   ( 0        )
      ) axis_audio_fifo_i (
        .s_clk                  ( BUSCLK                 ),
        .s_rst                  ( ~BUSCORERSTn           ),
        .s_axis_tdata           ( idma_axis_req.t.data   ),
        .s_axis_tkeep           ( idma_axis_req.t.keep   ),
        .s_axis_tvalid          ( idma_axis_req.tvalid   ),
        .s_axis_tready          ( idma_axis_rsp.tready   ),
        .s_axis_tlast           ( idma_axis_req.t.last   ),
        .s_axis_tid             ( idma_axis_req.t.id     ),
        .s_axis_tdest           ( idma_axis_req.t.dest   ),
        .s_axis_tuser           ( idma_axis_req.t.user   ),
        .m_clk                  ( audio_clk              ),
        .m_rst                  ( ~audio_resetn          ),
        .m_axis_tdata           ( audio_fifo_tdata       ),
        .m_axis_tkeep           (                        ),
        .m_axis_tvalid          ( audio_fifo_tvalid      ),
        .m_axis_tready          ( audio_fifo_tready      ),
        .m_axis_tlast           (                        ),
        .m_axis_tid             (                        ),
        .m_axis_tdest           (                        ),
        .m_axis_tuser           (                        ),
        .s_pause_req            ( 1'b0                   ),
        .s_pause_ack            (                        ),
        .m_pause_req            ( 1'b0                   ),
        .m_pause_ack            (                        ),
        .s_status_depth         ( audio_fifo_depth       ),
        .s_status_depth_commit  (                        ),
        .s_status_overflow      (                        ),
        .s_status_bad_frame     (                        ),
        .s_status_good_frame    (                        ),
        .m_status_depth         (                        ),
        .m_status_depth_commit  (                        ),
        .m_status_overflow      (                        ),
        .m_status_bad_frame     (                        ),
        .m_status_good_frame    (                        )
      );

      axis_stereo_tlast_tagger stereo_tagger_i (
        .clk_i          ( audio_clk         ),
        .rst_ni         ( audio_resetn      ),
        .s_axis_tdata   ( audio_fifo_tdata  ),
        .s_axis_tvalid  ( audio_fifo_tvalid ),
        .s_axis_tready  ( audio_fifo_tready ),
        .m_axis_tdata   ( audio_axis_tdata  ),
        .m_axis_tvalid  ( audio_axis_tvalid ),
        .m_axis_tready  ( audio_axis_tready ),
        .m_axis_tlast   ( audio_axis_tlast  )
      );

      axis_i2s2 i2s_i (
        .axis_clk        ( audio_clk         ),
        .axis_resetn     ( audio_resetn      ),
        .tx_axis_s_data  ( audio_axis_tdata  ),
        .tx_axis_s_valid ( audio_axis_tvalid ),
        .tx_axis_s_ready ( audio_axis_tready ),
        .tx_axis_s_last  ( audio_axis_tlast  ),
        .rx_axis_m_data  (                   ),
        .rx_axis_m_valid (                   ),
        .rx_axis_m_ready ( 1'b1              ),
        .rx_axis_m_last  (                   ),
        .tx_mclk         ( i2s_tx_mclk       ),
        .tx_lrck         ( i2s_tx_lrck       ),
        .tx_sclk         ( i2s_tx_sclk       ),
        .tx_sdout        ( i2s_tx_sdout      ),
        .rx_mclk         (                   ),
        .rx_lrck         (                   ),
        .rx_sclk         (                   ),
        .rx_sdin         ( 1'b0              )
      );
    end else begin : gen_no_idma_audio
      assign idma_axis_rsp.tready = 1'b1;
      assign i2s_tx_mclk = 1'b0;
      assign i2s_tx_lrck = 1'b0;
      assign i2s_tx_sclk = 1'b0;
      assign i2s_tx_sdout = 1'b0;
    end
  end else begin : gen_no_dma
    assign reg_awready = 1'b0;
    assign reg_wready  = 1'b0;
    assign reg_arready = 1'b0;
    assign reg_bvalid  = 1'b0;
    assign reg_bresp   = 2'b00;
    assign reg_bid     = '0;
    assign reg_rvalid  = 1'b0;
    assign reg_rlast   = 1'b0;
    assign reg_rresp   = 2'b00;
    assign reg_rid     = '0;
    assign reg_rdata   = '0;
    assign i2s_tx_mclk = 1'b0;
    assign i2s_tx_lrck = 1'b0;
    assign i2s_tx_sclk = 1'b0;
    assign i2s_tx_sdout = 1'b0;

    assign pc_lite_awaddr  = '0;
    assign pc_lite_awprot  = '0;
    assign pc_lite_awvalid = 1'b0;
    assign pc_lite_awready = 1'b0;
    assign pc_lite_wdata   = '0;
    assign pc_lite_wstrb   = '0;
    assign pc_lite_wvalid  = 1'b0;
    assign pc_lite_wready  = 1'b0;
    assign pc_lite_bresp   = 2'b00;
    assign pc_lite_bvalid  = 1'b0;
    assign pc_lite_bready  = 1'b0;
    assign pc_lite_araddr  = '0;
    assign pc_lite_arprot  = '0;
    assign pc_lite_arvalid = 1'b0;
    assign pc_lite_arready = 1'b0;
    assign pc_lite_rdata   = '0;
    assign pc_lite_rresp   = 2'b00;
    assign pc_lite_rvalid  = 1'b0;
    assign pc_lite_rready  = 1'b0;

    assign cdma_m_axi_awaddr  = '0;
    assign cdma_m_axi_awlen   = '0;
    assign cdma_m_axi_awsize  = '0;
    assign cdma_m_axi_awburst = '0;
    assign cdma_m_axi_awcache = '0;
    assign cdma_m_axi_awprot  = '0;
    assign cdma_m_axi_awvalid = 1'b0;
    assign cdma_m_axi_wdata   = '0;
    assign cdma_m_axi_wstrb   = '0;
    assign cdma_m_axi_wlast   = 1'b0;
    assign cdma_m_axi_wvalid  = 1'b0;
    assign cdma_m_axi_bready  = 1'b0;
    assign cdma_m_axi_araddr  = '0;
    assign cdma_m_axi_arlen   = '0;
    assign cdma_m_axi_arsize  = '0;
    assign cdma_m_axi_arburst = '0;
    assign cdma_m_axi_arcache = '0;
    assign cdma_m_axi_arprot  = '0;
    assign cdma_m_axi_arvalid = 1'b0;
    assign cdma_m_axi_rready  = 1'b0;

    assign idma_xbar_mst_req = '0;
    assign idma_xbar_slv_rsp = '0;
    assign dma_irq_raw = 1'b0;
  end

  always_ff @(posedge CPUCLK or posedge peripheral_reset) begin
    if (peripheral_reset) begin
      dma_irq_sync <= 2'b00;
    end else begin
      dma_irq_sync <= {dma_irq_sync[0], dma_irq_raw};
    end
  end

  assign dma_introut_sync = dma_irq_sync[1];
  assign axi_dma_intr_sync = dma_introut_sync;

  // CDC: synchronizer for calib_complete signal
  logic ddr_ready_raw;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic [1:0] ddr_ready_bus_sync;

  assign ddr_ready_raw = c0_init_calib_complete & ~init_error;
  always_ff @(posedge BUSCLK or posedge rst_req) begin
    if (rst_req) begin
        ddr_ready_bus_sync <= 2'b00;
    end else if (ui_clk_sync_rst) begin
        ddr_ready_bus_sync <= 2'b00;
    end else begin
        ddr_ready_bus_sync <= {ddr_ready_bus_sync[0], ddr_ready_raw};
    end
  end
  assign ddr_ready = ddr_ready_bus_sync[1];

  assign BUSCORERST  = ~mmcm_locked;    // deassert once BUSCLK is stable; ui_clk_sync_rst stays high through calibration
  assign BUSCORERSTn = ~BUSCORERST;

  assign BUSRST       = ui_clk_sync_rst | ~ddr_ready;
  assign BUSRSTn      = ~BUSRST;


  if (!P.LITEDRAM_SUPPORTED & !P.UBERDDR3_SUPPORTED) begin

    // no need to access DDR while not fully functional
    assign init_error = 1'b0;

    // No LiteDRAM CSR interface when using Xilinx MIG — tie M05 responses to 0
    assign litedram_axi_awready = 1'b0;
    assign litedram_axi_wready  = 1'b0;
    assign litedram_axi_arready = 1'b0;
    assign litedram_axi_bvalid  = 1'b0;
    assign litedram_axi_bresp   = 2'b0;
    assign litedram_axi_bid     = '0;
    assign litedram_axi_rvalid  = 1'b0;
    assign litedram_axi_rlast   = 1'b0;
    assign litedram_axi_rresp   = 2'b0;
    assign litedram_axi_rid     = '0;
    assign litedram_axi_rdata   = '0;

  // DDR3 Controller
  ddr3 ddr3
    (
     // ddr3 I/O
     .ddr3_dq(ddr3_dq),
     .ddr3_dqs_n(ddr3_dqs_n),
     .ddr3_dqs_p(ddr3_dqs_p),
     .ddr3_addr(ddr3_addr),
     .ddr3_ba(ddr3_ba),
     .ddr3_ras_n(ddr3_ras_n),
     .ddr3_cas_n(ddr3_cas_n),
     .ddr3_we_n(ddr3_we_n),
     .ddr3_reset_n(ddr3_reset_n),
     .ddr3_ck_p(ddr3_ck_p),
     .ddr3_ck_n(ddr3_ck_n),
     .ddr3_cke(ddr3_cke),
     .ddr3_cs_n(ddr3_cs_n),
     .ddr3_dm(ddr3_dm),
     .ddr3_odt(ddr3_odt),

     .sys_clk_i(clk167),
     .clk_ref_i(clk200),

     .ui_clk(BUSCLK),
     .ui_clk_sync_rst(ui_clk_sync_rst),
     // FIXME: Is this OK?
     //.aresetn(resetn),
     .aresetn(resetn_comb),
     //.sys_rst(resetn),    // omg. this is active low?!?!??
     .sys_rst(resetn_comb),    // omg. this is active low?!?!??
     .mmcm_locked(mmcm_locked),

     .app_sr_req(1'b0),  // reserved command
     .app_ref_req(1'b0), // refresh command
     .app_zq_req(1'b0),  // recalibrate command
     .app_sr_active(app_sr_active), // reserved response
     .app_ref_ack(app_ref_ack),     // refresh ack
     .app_zq_ack(app_zq_ack),       // recalibrate ack

     // AXI (FROM CROSSBAR M00 -> MIG)
     .s_axi_awid(BUS_cb_axi_awid),
     .s_axi_awaddr(BUS_cb_axi_awaddr[29:0]), // This width must match DDR size
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
     .s_axi_araddr(BUS_cb_axi_araddr[29:0]), // This width must match DDR size
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
     .device_temp(device_temp));
  end else if (P.LITEDRAM_SUPPORTED) begin

    assign cb_m_axi_awready[CB_M_DRAM_CSR] = litedram_axi_awready;
    assign cb_m_axi_wready[CB_M_DRAM_CSR]  = litedram_axi_wready;
    assign cb_m_axi_arready[CB_M_DRAM_CSR] = litedram_axi_arready;
    assign cb_m_axi_bvalid[CB_M_DRAM_CSR]  = litedram_axi_bvalid;
    assign cb_m_axi_bresp[CB_M_DRAM_CSR*AXI_RESP_W +: AXI_RESP_W] = litedram_axi_bresp;
    assign cb_m_axi_bid[CB_M_DRAM_CSR*MST_ID_W +: MST_ID_W] = litedram_axi_bid;
    assign cb_m_axi_rvalid[CB_M_DRAM_CSR]  = litedram_axi_rvalid;
    assign cb_m_axi_rlast[CB_M_DRAM_CSR]   = litedram_axi_rlast;
    assign cb_m_axi_rresp[CB_M_DRAM_CSR*AXI_RESP_W +: AXI_RESP_W] = litedram_axi_rresp;
    assign cb_m_axi_rid[CB_M_DRAM_CSR*MST_ID_W +: MST_ID_W] = litedram_axi_rid;
    assign cb_m_axi_rdata[CB_M_DRAM_CSR*DATA_W +: DATA_W] = litedram_axi_rdata;

    // ===========================================================================
    // AXI4->AXI-Lite signals (adapter master side)
    // ===========================================================================
    logic [31:0] axil_awaddr;
    logic [2:0]  axil_awprot;
    logic        axil_awvalid;
    logic        axil_awready;

    logic [31:0] axil_wdata;
    logic [3:0]  axil_wstrb;
    logic        axil_wvalid;
    logic        axil_wready;

    logic [1:0]  axil_bresp;
    logic        axil_bvalid;
    logic        axil_bready;

    logic [31:0] axil_araddr;
    logic [2:0]  axil_arprot;
    logic        axil_arvalid;
    logic        axil_arready;

    logic [31:0] axil_rdata;
    logic [1:0]  axil_rresp;
    logic        axil_rvalid;
    logic        axil_rready;


    logic          wb_ctrl_ack;
    logic   [29:0] wb_ctrl_adr;
    logic    [1:0] wb_ctrl_bte;
    logic    [2:0] wb_ctrl_cti;
    logic          wb_ctrl_cyc;
    logic   [31:0] wb_ctrl_dat_r;
    logic   [31:0] wb_ctrl_dat_w;
    logic          wb_ctrl_err;
    logic    [3:0] wb_ctrl_sel;
    logic          wb_ctrl_stb;
    logic          wb_ctrl_we;


    // litedram_axi_* are declared at module level for the crossbar response path.

    logic   litedram_reset_unused;


    axi_mmio_to_axilite32_v3 #(
        .AXI_ADDR_WIDTH(ADDR_W),
        .AXI_DATA_WIDTH(DATA_W),
        .AXI_ID_WIDTH  (MST_ID_W)
    ) u_axi_to_axil_dram (
        .aclk          (BUSCLK),
        .aresetn(BUSCORERSTn),

        .s_axi_awid    (cb_m_axi_awid[CB_M_DRAM_CSR*MST_ID_W +: MST_ID_W]),
        .s_axi_awaddr  (cb_m_axi_awaddr[CB_M_DRAM_CSR*ADDR_W +: ADDR_W]),
        .s_axi_awlen   (cb_m_axi_awlen[CB_M_DRAM_CSR*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_awsize  (cb_m_axi_awsize[CB_M_DRAM_CSR*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_awburst (cb_m_axi_awburst[CB_M_DRAM_CSR*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_awvalid (cb_m_axi_awvalid[CB_M_DRAM_CSR]),
        .s_axi_awready (litedram_axi_awready),

        .s_axi_wdata   (cb_m_axi_wdata[CB_M_DRAM_CSR*DATA_W +: DATA_W]),
        .s_axi_wstrb   (cb_m_axi_wstrb[CB_M_DRAM_CSR*STRB_W +: STRB_W]),
        .s_axi_wlast   (cb_m_axi_wlast[CB_M_DRAM_CSR]),
        .s_axi_wvalid  (cb_m_axi_wvalid[CB_M_DRAM_CSR]),
        .s_axi_wready  (litedram_axi_wready),

        .s_axi_bresp   (litedram_axi_bresp),
        .s_axi_bvalid  (litedram_axi_bvalid),
        .s_axi_bid     (litedram_axi_bid),
        .s_axi_bready  (cb_m_axi_bready[CB_M_DRAM_CSR]),

        .s_axi_arid    (cb_m_axi_arid[CB_M_DRAM_CSR*MST_ID_W +: MST_ID_W]),
        .s_axi_araddr  (cb_m_axi_araddr[CB_M_DRAM_CSR*ADDR_W +: ADDR_W]),
        .s_axi_arlen   (cb_m_axi_arlen[CB_M_DRAM_CSR*AXI_LEN_W +: AXI_LEN_W]),
        .s_axi_arsize  (cb_m_axi_arsize[CB_M_DRAM_CSR*AXI_SIZE_W +: AXI_SIZE_W]),
        .s_axi_arburst (cb_m_axi_arburst[CB_M_DRAM_CSR*AXI_BURST_W +: AXI_BURST_W]),
        .s_axi_arvalid (cb_m_axi_arvalid[CB_M_DRAM_CSR]),
        .s_axi_arready (litedram_axi_arready),

        .s_axi_rdata   (litedram_axi_rdata),
        .s_axi_rresp   (litedram_axi_rresp),
        .s_axi_rlast   (litedram_axi_rlast),
        .s_axi_rvalid  (litedram_axi_rvalid),
        .s_axi_rid     (litedram_axi_rid),
        .s_axi_rready  (cb_m_axi_rready[CB_M_DRAM_CSR]),

        // AXI lite side
        .m_axil_awaddr (axil_awaddr),
        .m_axil_awprot (axil_awprot),
        .m_axil_awvalid(axil_awvalid),
        .m_axil_awready(axil_awready),

        .m_axil_wdata  (axil_wdata),
        .m_axil_wstrb  (axil_wstrb),
        .m_axil_wvalid (axil_wvalid),
        .m_axil_wready (axil_wready),

        .m_axil_bresp  (axil_bresp),
        .m_axil_bvalid (axil_bvalid),
        .m_axil_bready (axil_bready),

        .m_axil_araddr (axil_araddr),
        .m_axil_arprot (axil_arprot),
        .m_axil_arvalid(axil_arvalid),
        .m_axil_arready(axil_arready),

        .m_axil_rdata  (axil_rdata),
        .m_axil_rresp  (axil_rresp),
        .m_axil_rvalid (axil_rvalid),
        .m_axil_rready (axil_rready)
    );

    axlite2wbsp
        axil2wb (
            .i_clk(BUSCLK),
            .i_axi_reset_n(BUSCORERSTn),

            // AXI signals
            .i_axi_awvalid(axil_awvalid),
            .o_axi_awready(axil_awready),
            .i_axi_awaddr(axil_awaddr),
            .i_axi_awprot(axil_awprot),
            .i_axi_wvalid(axil_wvalid),
            .o_axi_wready(axil_wready),
            .i_axi_wdata(axil_wdata),
            .i_axi_wstrb(axil_wstrb),
            .o_axi_bvalid(axil_bvalid),
            .i_axi_bready(axil_bready),
            .o_axi_bresp(axil_bresp),
            .i_axi_arvalid(axil_arvalid),
            .o_axi_arready(axil_arready),
            .i_axi_araddr(axil_araddr),
            .i_axi_arprot(axil_arprot),
            .o_axi_rvalid(axil_rvalid),
            .i_axi_rready(axil_rready),
            .o_axi_rdata(axil_rdata),
            .o_axi_rresp(axil_rresp),

            .o_reset(litedram_reset_unused),

            // Wishbone signals
            .o_wb_cyc(wb_ctrl_cyc),
            .o_wb_stb(wb_ctrl_stb),
            .o_wb_we(wb_ctrl_we),
            .o_wb_addr(wb_ctrl_adr),
            .o_wb_data(wb_ctrl_dat_w),
            .o_wb_sel(wb_ctrl_sel),
            .i_wb_stall(1'b0),
            .i_wb_ack(wb_ctrl_ack),
            .i_wb_data(wb_ctrl_dat_r),
            .i_wb_err(wb_ctrl_err)
        );

    if (DATA_W == 64) begin
        litedram_genesys2 ddr3(
        .clk      (clk200),          // external 200 MHz board clock
        .rst(rst_req),

        .ddram_a(ddr3_addr),
        .ddram_ba(ddr3_ba),
        .ddram_cas_n(ddr3_cas_n),
        .ddram_cke(ddr3_cke),
        .ddram_clk_n(ddr3_ck_n),
        .ddram_clk_p(ddr3_ck_p),
        .ddram_cs_n(ddr3_cs_n),
        .ddram_dm(ddr3_dm),
        .ddram_dq(ddr3_dq),
        .ddram_dqs_n(ddr3_dqs_n),
        .ddram_dqs_p(ddr3_dqs_p),
        .ddram_odt(ddr3_odt),
        .ddram_ras_n(ddr3_ras_n),
        .ddram_reset_n(ddr3_reset_n),
        .ddram_we_n(ddr3_we_n),

        .init_done(c0_init_calib_complete),
        .init_error(init_error),
        .pll_locked(mmcm_locked),
        .user_clk (BUSCLK),
        .user_rst (ui_clk_sync_rst),

        .user_port_axi_0_araddr(BUS_cb_axi_araddr[29:0]),
        .user_port_axi_0_arburst(BUS_cb_axi_arburst),
        .user_port_axi_0_arid(BUS_cb_axi_arid),
        .user_port_axi_0_arlen(BUS_cb_axi_arlen),
        .user_port_axi_0_arready(BUS_cb_axi_arready),
        .user_port_axi_0_arsize(BUS_cb_axi_arsize),
        .user_port_axi_0_arvalid(BUS_cb_axi_arvalid),
        .user_port_axi_0_awaddr(BUS_cb_axi_awaddr[29:0]),
        .user_port_axi_0_awburst(BUS_cb_axi_awburst),
        .user_port_axi_0_awid(BUS_cb_axi_awid),
        .user_port_axi_0_awlen(BUS_cb_axi_awlen),
        .user_port_axi_0_awready(BUS_cb_axi_awready),
        .user_port_axi_0_awsize(BUS_cb_axi_awsize),
        .user_port_axi_0_awvalid(BUS_cb_axi_awvalid),
        .user_port_axi_0_bid(BUS_cb_axi_bid),
        .user_port_axi_0_bready(BUS_cb_axi_bready),
        .user_port_axi_0_bresp(BUS_cb_axi_bresp),
        .user_port_axi_0_bvalid(BUS_cb_axi_bvalid),
        .user_port_axi_0_rdata(BUS_cb_axi_rdata),
        .user_port_axi_0_rid(BUS_cb_axi_rid),
        .user_port_axi_0_rlast(BUS_cb_axi_rlast),
        .user_port_axi_0_rready(BUS_cb_axi_rready),
        .user_port_axi_0_rresp(BUS_cb_axi_rresp),
        .user_port_axi_0_rvalid(BUS_cb_axi_rvalid),
        .user_port_axi_0_wdata(BUS_cb_axi_wdata),
        .user_port_axi_0_wlast(BUS_cb_axi_wlast),
        .user_port_axi_0_wready(BUS_cb_axi_wready),
        .user_port_axi_0_wstrb(BUS_cb_axi_wstrb),
        .user_port_axi_0_wvalid(BUS_cb_axi_wvalid),

        .wb_ctrl_ack(wb_ctrl_ack),
        .wb_ctrl_adr(wb_ctrl_adr),
        .wb_ctrl_bte(2'b00),
        .wb_ctrl_cti(3'b000),
        .wb_ctrl_cyc(wb_ctrl_cyc),
        .wb_ctrl_dat_r(wb_ctrl_dat_r),
        .wb_ctrl_dat_w(wb_ctrl_dat_w),
        .wb_ctrl_err(wb_ctrl_err),
        .wb_ctrl_sel(wb_ctrl_sel),
        .wb_ctrl_stb(wb_ctrl_stb),
        .wb_ctrl_we(wb_ctrl_we)

      );
    end else begin
      litedram_genesys2w32 ddr3(
        .clk      (clk200),
        .rst      (rst_req),

        .ddram_a(ddr3_addr),
        .ddram_ba(ddr3_ba),
        .ddram_cas_n(ddr3_cas_n),
        .ddram_cke(ddr3_cke),
        .ddram_clk_n(ddr3_ck_n),
        .ddram_clk_p(ddr3_ck_p),
        .ddram_cs_n(ddr3_cs_n),
        .ddram_dm(ddr3_dm),
        .ddram_dq(ddr3_dq),
        .ddram_dqs_n(ddr3_dqs_n),
        .ddram_dqs_p(ddr3_dqs_p),
        .ddram_odt(ddr3_odt),
        .ddram_ras_n(ddr3_ras_n),
        .ddram_reset_n(ddr3_reset_n),
        .ddram_we_n(ddr3_we_n),

        .init_done(c0_init_calib_complete),
        .init_error(init_error),
        .pll_locked(mmcm_locked),
        .user_clk(BUSCLK),
        .user_rst(ui_clk_sync_rst),

        .user_port_axi_0_araddr(BUS_cb_axi_araddr[29:0]),
        .user_port_axi_0_arburst(BUS_cb_axi_arburst),
        .user_port_axi_0_arid(BUS_cb_axi_arid),
        .user_port_axi_0_arlen(BUS_cb_axi_arlen),
        .user_port_axi_0_arready(BUS_cb_axi_arready),
        .user_port_axi_0_arsize(BUS_cb_axi_arsize),
        .user_port_axi_0_arvalid(BUS_cb_axi_arvalid),
        .user_port_axi_0_awaddr(BUS_cb_axi_awaddr[29:0]),
        .user_port_axi_0_awburst(BUS_cb_axi_awburst),
        .user_port_axi_0_awid(BUS_cb_axi_awid),
        .user_port_axi_0_awlen(BUS_cb_axi_awlen),
        .user_port_axi_0_awready(BUS_cb_axi_awready),
        .user_port_axi_0_awsize(BUS_cb_axi_awsize),
        .user_port_axi_0_awvalid(BUS_cb_axi_awvalid),
        .user_port_axi_0_bid(BUS_cb_axi_bid),
        .user_port_axi_0_bready(BUS_cb_axi_bready),
        .user_port_axi_0_bresp(BUS_cb_axi_bresp),
        .user_port_axi_0_bvalid(BUS_cb_axi_bvalid),
        .user_port_axi_0_rdata(BUS_cb_axi_rdata),
        .user_port_axi_0_rid(BUS_cb_axi_rid),
        .user_port_axi_0_rlast(BUS_cb_axi_rlast),
        .user_port_axi_0_rready(BUS_cb_axi_rready),
        .user_port_axi_0_rresp(BUS_cb_axi_rresp),
        .user_port_axi_0_rvalid(BUS_cb_axi_rvalid),
        .user_port_axi_0_wdata(BUS_cb_axi_wdata),
        .user_port_axi_0_wlast(BUS_cb_axi_wlast),
        .user_port_axi_0_wready(BUS_cb_axi_wready),
        .user_port_axi_0_wstrb(BUS_cb_axi_wstrb),
        .user_port_axi_0_wvalid(BUS_cb_axi_wvalid),

        .wb_ctrl_ack(wb_ctrl_ack),
        .wb_ctrl_adr(wb_ctrl_adr),
        .wb_ctrl_bte(2'b00),
        .wb_ctrl_cti(3'b000),
        .wb_ctrl_cyc(wb_ctrl_cyc),
        .wb_ctrl_dat_r(wb_ctrl_dat_r),
        .wb_ctrl_dat_w(wb_ctrl_dat_w),
        .wb_ctrl_err(wb_ctrl_err),
        .wb_ctrl_sel(wb_ctrl_sel),
        .wb_ctrl_stb(wb_ctrl_stb),
        .wb_ctrl_we(wb_ctrl_we)
      );
    end
  end else begin

    logic dummy_rstn;
    logic dummy_clk200;
    assign init_error = 1'b0;

    // No LiteDRAM CSR interface
    assign litedram_axi_awready = 1'b0;
    assign litedram_axi_wready  = 1'b0;
    assign litedram_axi_arready = 1'b0;
    assign litedram_axi_bvalid  = 1'b0;
    assign litedram_axi_bresp   = 2'b0;
    assign litedram_axi_bid     = '0;
    assign litedram_axi_rvalid  = 1'b0;
    assign litedram_axi_rlast   = 1'b0;
    assign litedram_axi_rresp   = 2'b0;
    assign litedram_axi_rid     = '0;
    assign litedram_axi_rdata   = '0;

    uberddr3_wrapper #(
        .AXI_ID_WIDTH(DDR_ID_W),
        .AXI_DATA_WIDTH(DATA_W),
        .UBER_AXI_ID_WIDTH(DDR_ID_W)
    ) ddr3 (

        .i_clk_200(clk200),
        .i_sys_rst(rst_req),        // active-high global reset

        .o_ui_clk(BUSCLK),         // AXI/UI clock for the SoC side (100 MHz)
        .o_ref_clk_200(dummy_clk200),    // buffered 200 MHz reference clock
        .o_ui_clk_sync_rst(ui_clk_sync_rst),// active-high reset synchronous to o_ui_clk
        .o_ui_aresetn(dummy_rstn),     // active-low version of the same reset
        .o_pll_locked(mmcm_locked),
        .o_init_calib_complete(c0_init_calib_complete),

        // AXI slave interface (SoC side, kept MIG/LiteDRAM-like)
        .i_s_axi_awid(BUS_cb_axi_awid),
        .i_s_axi_awaddr(BUS_cb_axi_awaddr),
        .i_s_axi_awlen(BUS_cb_axi_awlen),
        .i_s_axi_awsize(BUS_cb_axi_awsize),
        .i_s_axi_awburst(BUS_cb_axi_awburst),
        .i_s_axi_awlock(BUS_cb_axi_awlock),
        .i_s_axi_awcache(BUS_cb_axi_awcache),
        .i_s_axi_awprot(BUS_cb_axi_awprot),
        .i_s_axi_awqos(BUS_cb_axi_awqos),
        .i_s_axi_awvalid(BUS_cb_axi_awvalid),
        .o_s_axi_awready(BUS_cb_axi_awready),

        .i_s_axi_wdata(BUS_cb_axi_wdata),
        .i_s_axi_wstrb(BUS_cb_axi_wstrb),
        .i_s_axi_wlast(BUS_cb_axi_wlast),
        .i_s_axi_wvalid(BUS_cb_axi_wvalid),
        .o_s_axi_wready(BUS_cb_axi_wready),

        .o_s_axi_bid(BUS_cb_axi_bid),
        .o_s_axi_bresp(BUS_cb_axi_bresp),
        .o_s_axi_bvalid(BUS_cb_axi_bvalid),
        .i_s_axi_bready(BUS_cb_axi_bready),

        .i_s_axi_arid(BUS_cb_axi_arid),
        .i_s_axi_araddr(BUS_cb_axi_araddr),
        .i_s_axi_arlen(BUS_cb_axi_arlen),
        .i_s_axi_arsize(BUS_cb_axi_arsize),
        .i_s_axi_arburst(BUS_cb_axi_arburst),
        .i_s_axi_arlock(BUS_cb_axi_arlock),
        .i_s_axi_arcache(BUS_cb_axi_arcache),
        .i_s_axi_arprot(BUS_cb_axi_arprot),
        .i_s_axi_arqos(BUS_cb_axi_arqos),
        .i_s_axi_arvalid(BUS_cb_axi_arvalid),
        .o_s_axi_arready(BUS_cb_axi_arready),

        .o_s_axi_rid(BUS_cb_axi_rid),
        .o_s_axi_rdata(BUS_cb_axi_rdata),
        .o_s_axi_rresp(BUS_cb_axi_rresp),
        .o_s_axi_rlast(BUS_cb_axi_rlast),
        .o_s_axi_rvalid(BUS_cb_axi_rvalid),
        .i_s_axi_rready(BUS_cb_axi_rready),

        // DDR3 pins
        .io_ddr3_dq(ddr3_dq),
        .io_ddr3_dqs_n(ddr3_dqs_n),
        .io_ddr3_dqs_p(ddr3_dqs_p),
        .o_ddr3_addr(ddr3_addr),
        .o_ddr3_ba(ddr3_ba),
        .o_ddr3_ras_n(ddr3_ras_n),
        .o_ddr3_cas_n(ddr3_cas_n),
        .o_ddr3_we_n(ddr3_we_n),
        .o_ddr3_reset_n(ddr3_reset_n),
        .o_ddr3_ck_p(ddr3_ck_p),
        .o_ddr3_ck_n(ddr3_ck_n),
        .o_ddr3_cke(ddr3_cke),
        .o_ddr3_cs_n(ddr3_cs_n),
        .o_ddr3_dm(ddr3_dm),
        .o_ddr3_odt(ddr3_odt)
    );

  end

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
