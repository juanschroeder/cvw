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

  // Keep Wally's logical configuration intact while selecting the CVWSoC
  // memory implementation locally.  This preserves the existing variants
  // until the legacy memory flags are retired from cvw_t.
  function automatic cvwsoc_mem_type_t cvwsoc_mem_type_from_wally(input cvw_t cfg);
    if (cfg.LITEDRAM_SUPPORTED)
      return CVWSOC_MEM_LITEDRAM_GENESYS2;
    if (cfg.UBERDDR3_SUPPORTED)
      return CVWSOC_MEM_UBERDDR3;
    return CVWSOC_MEM_XILINX_DDR3;
  endfunction

  localparam cvwsoc_cfg_t C = '{
    wally:    P,
    mem_type: cvwsoc_mem_type_from_wally(P),
    idma_config:    '{
                        AxisDescReqCut: 1'b0
                    },
    vga_config:     '{
                        CutSplitterPath: 1'b0,
                        BufferDepth: 32,
                        MaxReadTxns: 4
                    },
    sdhci_config:   '{
                        InsertRegClkBuf: 1'b0
                    }
  };

  // These types describe the AXI port between cvwsoc_cpu and cvwsoc_axi.
  //
  // P.AHBW determines the AXI data width and strobe width here (64-bit data /
  // 8 strobes in this build; 32-bit data / 4 strobes in a 32-bit-bus build).
  // The address width is deliberately fixed at 32 bits: cvwsoc_cpu and
  // cvwsoc_axi use 32-bit AXI addresses.  P.PA_BITS may be changed for
  // the CPU/AHB address bus, but that alone does not widen this AXI/FPGA path;
  // supporting addresses above 32 bits requires a coordinated wrapper and
  // address-map change.
  //
  // cvwsoc_pkg is compiled without this module instance and cannot refer to
  // its parameter P, therefore the P.AHBW-dependent typedefs remain here.
  typedef logic [31:0]       cpu_axi_addr_t;
  // The CPU-side bridge uses a two-bit transaction ID.  At the PULP crossbar boundary, the
  // crossbar prepends its 3-bit ingress-port number, producing the 5-bit DDR
  // target ID needed to route responses back to the originating master.
  typedef logic [1:0]        cpu_axi_id_t;
  typedef logic [P.AHBW-1:0] cpu_axi_data_t;
  typedef logic [STRB_W-1:0] cpu_axi_strb_t;
  typedef logic              cpu_axi_user_t;
  `AXI_TYPEDEF_ALL_CT(cpu_axi, cpu_axi_req_t, cpu_axi_resp_t,
                      cpu_axi_addr_t, cpu_axi_id_t, cpu_axi_data_t,
                      cpu_axi_strb_t, cpu_axi_user_t)

  localparam xbar_out_t XBAR_OUT = gen_xbar_out(P);
  localparam int unsigned CPU_AXI_ID_WIDTH = $bits(cpu_axi_id_t);
  typedef logic [CPU_AXI_ID_WIDTH+$clog2(XBAR_OUT.n_slv)-1:0] ddr_axi_id_t;
  `AXI_TYPEDEF_ALL_CT(ddr_axi, ddr_axi_req_t, ddr_axi_resp_t,
                      cpu_axi_addr_t, ddr_axi_id_t, cpu_axi_data_t,
                      cpu_axi_strb_t, cpu_axi_user_t)
  `AXI_TYPEDEF_ALL_CT(ddr_csr_axi, ddr_csr_axi_req_t, ddr_csr_axi_resp_t,
                      cpu_axi_addr_t, ddr_axi_id_t, cpu_axi_data_t,
                      cpu_axi_strb_t, cpu_axi_user_t)
  typedef ddr_axi_req_t ahb_axi_req_t;
  typedef ddr_axi_resp_t ahb_axi_resp_t;
  typedef ddr_axi_req_t wishbone_axi_req_t;
  typedef ddr_axi_resp_t wishbone_axi_resp_t;
  ddr_axi_req_t ddr_axi_req;
  ddr_axi_resp_t ddr_axi_resp;
  ddr_csr_axi_req_t ddr_csr_axi_req;
  ddr_csr_axi_resp_t ddr_csr_axi_resp;
  ahb_axi_req_t ahb_axi_req;
  ahb_axi_resp_t ahb_axi_resp;
  wishbone_axi_req_t wishbone_axi_req;
  wishbone_axi_resp_t wishbone_axi_resp;

  logic ahb_meip, ahb_seip;
  logic ahb_dma_intr, ahb_usb_intr, ahb_eth_intr;
  logic ahb_dummy_intr, ahb_sdhci_intr;
  logic wb_uart_irq, wb_eth_irq;
  (* mark_debug = "true" *) logic ddr_busclk, ddr_buscorerstn, ddr_busrstn;

  logic CPUCLK;
  (* mark_debug = "true" *) logic bus_struct_reset;
  (* mark_debug = "true" *) logic peripheral_reset;
  (* mark_debug = "true" *) logic peripheral_aresetn;
  (* mark_debug = "true" *) logic interconnect_aresetn;
  logic mb_reset;
  logic [3:0] cpu_axi_irq;
  logic cpu_meip, cpu_seip;
  (* mark_debug = "true" *) logic cpu_clk_locked;
  logic clk167, clk200, audio_clk, clk48MHz_raw;
  (* mark_debug = "true" *) logic rst_req, resetn_comb;

  logic [31:0] GPIOIN, GPIOOUT, GPIOEN;
  logic [3:0] SDCCSin;
  (* mark_debug = "true" *) logic RVVIStall;

  cpu_axi_req_t  bridge_axi_req;
  cpu_axi_resp_t bridge_axi_resp;

  // AHB to AXI Bridge Signals
  (* mark_debug = "true" *) logic [3:0]      cpu_m_axi_awid;
  (* mark_debug = "true" *) logic [7:0]      cpu_m_axi_awlen;
  (* mark_debug = "true" *) logic [2:0]      cpu_m_axi_awsize;
  (* mark_debug = "true" *) logic [1:0]      cpu_m_axi_awburst;
  (* mark_debug = "true" *) logic [3:0]      cpu_m_axi_awcache;
  (* mark_debug = "true" *) logic [31:0]     cpu_m_axi_awaddr;
  (* mark_debug = "true" *) logic [2:0]      cpu_m_axi_awprot;
  (* mark_debug = "true" *) logic            cpu_m_axi_awvalid;
  (* mark_debug = "true" *) logic            cpu_m_axi_awready;
  (* mark_debug = "true" *) logic            cpu_m_axi_awlock;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] cpu_m_axi_wdata;
  (* mark_debug = "true" *) logic [STRB_W-1:0] cpu_m_axi_wstrb;
  (* mark_debug = "true" *) logic            cpu_m_axi_wlast;
  (* mark_debug = "true" *) logic            cpu_m_axi_wvalid;
  (* mark_debug = "true" *) logic            cpu_m_axi_wready;
  (* mark_debug = "true" *) logic [3:0]      cpu_m_axi_bid;
  (* mark_debug = "true" *) logic [1:0]      cpu_m_axi_bresp;
  (* mark_debug = "true" *) logic            cpu_m_axi_bvalid;
  (* mark_debug = "true" *) logic            cpu_m_axi_bready;
  (* mark_debug = "true" *) logic [3:0]      cpu_m_axi_arid;
  (* mark_debug = "true" *) logic [7:0]      cpu_m_axi_arlen;
  (* mark_debug = "true" *) logic [2:0]      cpu_m_axi_arsize;
  (* mark_debug = "true" *) logic [1:0]      cpu_m_axi_arburst;
  (* mark_debug = "true" *) logic [2:0]      cpu_m_axi_arprot;
  (* mark_debug = "true" *) logic [3:0]      cpu_m_axi_arcache;
  (* mark_debug = "true" *) logic            cpu_m_axi_arvalid;
  (* mark_debug = "true" *) logic [31:0]     cpu_m_axi_araddr;
  (* mark_debug = "true" *) logic            cpu_m_axi_arlock;
  (* mark_debug = "true" *) logic            cpu_m_axi_arready;
  (* mark_debug = "true" *) logic [3:0]      cpu_m_axi_rid;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] cpu_m_axi_rdata;
  (* mark_debug = "true" *) logic [1:0]      cpu_m_axi_rresp;
  (* mark_debug = "true" *) logic            cpu_m_axi_rvalid;
  (* mark_debug = "true" *) logic            cpu_m_axi_rlast;
  (* mark_debug = "true" *) logic            cpu_m_axi_rready;

  assign cpu_m_axi_awid = cpu.wally.awid;
  assign cpu_m_axi_awaddr = cpu.wally.awaddr;
  assign cpu_m_axi_awlen = cpu.wally.awlen;
  assign cpu_m_axi_awsize = cpu.wally.awsize;
  assign cpu_m_axi_awburst = cpu.wally.awburst;
  assign cpu_m_axi_awvalid = cpu.wally.awvalid;
  assign cpu_m_axi_awready = cpu.wally.awready;
  assign cpu_m_axi_wdata = cpu.wally.wdata;
  assign cpu_m_axi_wstrb = cpu.wally.wstrb;
  assign cpu_m_axi_wlast = cpu.wally.wlast;
  assign cpu_m_axi_wvalid = cpu.wally.wvalid;
  assign cpu_m_axi_wready = cpu.wally.wready;
  assign cpu_m_axi_bid = cpu.wally.bid;
  assign cpu_m_axi_bresp = cpu.wally.bresp;
  assign cpu_m_axi_bvalid = cpu.wally.bvalid;
  assign cpu_m_axi_bready = cpu.wally.bready;
  assign cpu_m_axi_arid = cpu.wally.arid;
  assign cpu_m_axi_araddr = cpu.wally.araddr;
  assign cpu_m_axi_arlen = cpu.wally.arlen;
  assign cpu_m_axi_arsize = cpu.wally.arsize;
  assign cpu_m_axi_arburst = cpu.wally.arburst;
  assign cpu_m_axi_arvalid = cpu.wally.arvalid;
  assign cpu_m_axi_arready = cpu.wally.arready;
  assign cpu_m_axi_rid = cpu.wally.rid;
  assign cpu_m_axi_rdata = cpu.wally.rdata;
  assign cpu_m_axi_rresp = cpu.wally.rresp;
  assign cpu_m_axi_rlast = cpu.wally.rlast;
  assign cpu_m_axi_rvalid = cpu.wally.rvalid;
  assign cpu_m_axi_rready = cpu.wally.rready;


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
    .clk_in1_p(default_200mhz_clk_p),
    .clk_in1_n(default_200mhz_clk_n),
    .clk_out1(audio_clk),
    .clk_out2(clk167),
    .clk_out3(clk200),
    .clk_out4(CPUCLK),
    .clk_out5(clk48MHz_raw),
    .reset(1'b0),
    .locked(cpu_clk_locked) );

// FIXME!!
`ifndef P_WISHBONE_ETH_SUPPORTED
  BUFG u_bufg_rmii (.I(phy_ref_clk_raw), .O(rmii_clk50));
  assign WB_RMII_REF_CLK = rmii_clk50;
`endif

  assign rst_req = ~resetn | south_reset;
  assign resetn_comb = ~rst_req;

  logic cpu_rst_ni; // cpu block reset: wait for bus core reset
  logic ddr_buscorerstn_sync;
  
  sysrst sysrst (
    .slowest_sync_clk(CPUCLK), 
    .ext_reset_in(rst_req), 
    .aux_reset_in(1'b0),
    .mb_debug_sys_rst(1'b0), 
    .dcm_locked(cpu_clk_locked), 
    .mb_reset(mb_reset),
    .bus_struct_reset(bus_struct_reset),
    .peripheral_reset(peripheral_reset),
    .interconnect_aresetn(interconnect_aresetn),
    .peripheral_aresetn(peripheral_aresetn) );

  // CDC for DDR reset input
  synchronizer sync_ddr_reset (CPUCLK, ddr_buscorerstn, ddr_buscorerstn_sync);
  assign cpu_rst_ni = peripheral_aresetn & ddr_buscorerstn_sync;


  assign cpu_meip = ahb_meip;

  cvwsoc_cpu #(
    .P(P), 
    .AXI_ID_W(CPU_AXI_ID_WIDTH),
    .cpu_axi_req_t(cpu_axi_req_t),
    .cpu_axi_resp_t(cpu_axi_resp_t)
  ) cpu (
    .clk_i(CPUCLK),
    //.rst_ni(~bus_struct_reset),
    .rst_ni(cpu_rst_ni),
    .time_clk_i(CPUCLK),
    .meip_i(cpu_meip),
    .seip_i(cpu_seip),
    .external_stall_i(RVVIStall),
    .axi_req_o(bridge_axi_req),
    .axi_resp_i(bridge_axi_resp)
  );

  cvwsoc_ram #(
    .C(C), 
    .CPU_AXI_ID_WIDTH(CPU_AXI_ID_WIDTH),
    .ddr_axi_req_t(ddr_axi_req_t), 
    .ddr_axi_resp_t(ddr_axi_resp_t),
    .ddr_csr_axi_req_t(ddr_csr_axi_req_t),
    .ddr_csr_axi_resp_t(ddr_csr_axi_resp_t)
  ) u_cvwsoc_ram (
    .clk167_i(clk167),
    .clk200_i(clk200),
    .rst_req_i(rst_req),
    .resetn_comb_i(resetn_comb),
    .BUSCLK_o(ddr_busclk),
    .BUSCORERSTn_o(ddr_buscorerstn),
    .BUSRSTn_o(ddr_busrstn),
    .ddr_axi_req_i(ddr_axi_req),
    .ddr_axi_resp_o(ddr_axi_resp),
    .ddr_csr_axi_req_i(ddr_csr_axi_req),
    .ddr_csr_axi_resp_o(ddr_csr_axi_resp),
    .ddr_dq(ddr3_dq), .ddr_dqs_n(ddr3_dqs_n),
    .ddr_dqs_p(ddr3_dqs_p),
    .ddr_addr(ddr3_addr),
    .ddr_ba(ddr3_ba),
    .ddr_ras_n(ddr3_ras_n),
    .ddr_cas_n(ddr3_cas_n),
    .ddr_we_n(ddr3_we_n),
    .ddr_reset_n(ddr3_reset_n),
    .ddr_ck_p(ddr3_ck_p),
    .ddr_ck_n(ddr3_ck_n),
    .ddr_cke(ddr3_cke),
    .ddr_cs_n(ddr3_cs_n),
    .ddr_dm(ddr3_dm),
    .ddr_odt(ddr3_odt)
  );

  cvwsoc_axi #(
    .C(C),
    .CPU_AXI_ID_WIDTH(CPU_AXI_ID_WIDTH),
    .cpu_axi_req_t(cpu_axi_req_t),
    .cpu_axi_resp_t(cpu_axi_resp_t),
    .ddr_axi_req_t(ddr_axi_req_t), .ddr_axi_resp_t(ddr_axi_resp_t),
    .ddr_csr_axi_req_t(ddr_csr_axi_req_t),
    .ddr_csr_axi_resp_t(ddr_csr_axi_resp_t),
    .ahb_axi_req_t(ahb_axi_req_t),
    .ahb_axi_resp_t(ahb_axi_resp_t),
    .wishbone_axi_req_t(wishbone_axi_req_t),
    .wishbone_axi_resp_t(wishbone_axi_resp_t)
  ) u_cvwsoc_axi (
    .CPUCLK_i(CPUCLK),
    .clk167_i(clk167),
    .clk200_i(clk200),
    .clk48MHz_raw_i(clk48MHz_raw),
    .audio_clk_i(audio_clk),
    .cpu_clk_locked_i(cpu_clk_locked),
    .peripheral_reset_i(peripheral_reset),
    .peripheral_aresetn_i(peripheral_aresetn),
    .rst_req_i(rst_req),
    .resetn_comb_i(resetn_comb),

    .ddr_axi_req_o(ddr_axi_req), .ddr_axi_resp_i(ddr_axi_resp),
    .ddr_csr_axi_req_o(ddr_csr_axi_req), .ddr_csr_axi_resp_i(ddr_csr_axi_resp),
    .ahb_axi_req_o(ahb_axi_req),
    .ahb_axi_resp_i(ahb_axi_resp),
    .wishbone_axi_req_o(wishbone_axi_req),
    .wishbone_axi_resp_i(wishbone_axi_resp),
    .BUSCLK_i(ddr_busclk),
    .BUSCORERSTn_i(ddr_buscorerstn),
    .BUSRSTn_i(ddr_busrstn),

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

    .cpu_axi_req_i(bridge_axi_req),
    .cpu_axi_resp_o(bridge_axi_resp),
    .cpu_axi_irq_o(cpu_axi_irq),
    .ahb_axi_dma_intr_o(ahb_dma_intr),
    .ahb_axi_usb_intr_o(ahb_usb_intr),
    .ahb_axi_eth_intr_o(ahb_eth_intr),
    .ahb_axi_dummy_intr_o(ahb_dummy_intr),
    .ahb_axi_sdhci_intr_o(ahb_sdhci_intr)
  );

  cvwsoc_ahb #(
    .P(C.wally),
    .AXI_ID_W($bits(ahb_axi_req.aw.id)),
    .axi_req_t(ahb_axi_req_t),
    .axi_resp_t(ahb_axi_resp_t)
  ) u_cvwsoc_ahb (
    .clk_i(ddr_busclk),
    .rst_ni(ddr_buscorerstn),
    .axi_req_i(ahb_axi_req),
    .axi_resp_o(ahb_axi_resp),
    .MExtInt(ahb_meip),
    .SExtInt(ahb_seip),
    .GPIOIN,
    .GPIOOUT,
    .GPIOEN,
    .UARTSin,
    .UARTSout,
    .SPIIn(1'b0),
    .SPIOut(),
    .SPICS(),
    .SPICLK(),
    .SDCIn,
    .SDCCmd,
    .SDCCS(SDCCSin),
    .SDCCLK,
    .WBUartIntr(wb_uart_irq),
    .WBEthIntr(wb_eth_irq),
    .AXI_DMAIntr(ahb_dma_intr),
    .AXI_USBIntr(ahb_usb_intr),
    .AXI_EthIntr(ahb_eth_intr),
    .AXI_DummyIntr(ahb_dummy_intr),
    .AXI_SDHCIIntr(ahb_sdhci_intr)
  );

  assign cpu_meip = ahb_meip;
  assign cpu_seip = ahb_seip;

  generate
    if (C.wally.WISHBONE_SUPPORTED) begin : gen_fpga_wishbone
      cvwsoc_wishbone #(
        .P(C.wally),
        .AXI_ID_W($bits(wishbone_axi_req.aw.id)),
        .axi_req_t(wishbone_axi_req_t),
        .axi_resp_t(wishbone_axi_resp_t)
      ) u_cvwsoc_wishbone (
        .clk_i(ddr_busclk),
        .rst_ni(ddr_buscorerstn),
        .axi_req_i(wishbone_axi_req),
        .axi_resp_o(wishbone_axi_resp),
        .uart_rx_i(WB_UART_RX),
        .uart_tx_o(WB_UART_TX),
        .uart_irq_o(wb_uart_irq),
        .rmii_ref_clk_i(WB_RMII_REF_CLK),
        .rmii_crs_dv_i(WB_RMII_CRS_DV),
        .rmii_rx_data_i(WB_RMII_RX_DATA),
        .rmii_tx_data_o(WB_RMII_TX_DATA),
        .rmii_tx_en_o(WB_RMII_TX_EN),
        .rmii_mdc_o(WB_RMII_MDC),
        .rmii_mdio_io(WB_RMII_MDIO),
        .rmii_rst_n_o(WB_RMII_RST_N),
        .eth_irq_o(wb_eth_irq)
      );
    end else begin : gen_no_fpga_wishbone
      assign wishbone_axi_resp = '0;
      assign WB_UART_TX = 1'b0;
      assign wb_uart_irq = 1'b0;
      assign wb_eth_irq = 1'b0;
    end
  endgenerate


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

    assign StallE         = fpgaTop.cpu.wally.core.StallE;
    assign StallM         = fpgaTop.cpu.wally.core.StallM;
    assign StallW         = fpgaTop.cpu.wally.core.StallW;
    assign FlushE         = fpgaTop.cpu.wally.core.FlushE;
    assign FlushM         = fpgaTop.cpu.wally.core.FlushM;
    assign FlushW         = fpgaTop.cpu.wally.core.FlushW;
    assign InstrValidM    = fpgaTop.cpu.wally.core.ieu.InstrValidM;
    assign InstrRawD      = fpgaTop.cpu.wally.core.ifu.InstrRawD;
    assign PCM            = fpgaTop.cpu.wally.core.ifu.PCM;
    assign Mcycle         = fpgaTop.cpu.wally.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[0];
    assign Minstret       = fpgaTop.cpu.wally.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[2];
    assign TrapM          = fpgaTop.cpu.wally.core.TrapM;
    assign PrivilegeModeW = fpgaTop.cpu.wally.core.priv.priv.privmode.PrivilegeModeW;
    assign GPRAddr        = fpgaTop.cpu.wally.core.ieu.dp.regf.a3;
    assign GPRWen         = fpgaTop.cpu.wally.core.ieu.dp.regf.we3;
    assign GPRValue       = fpgaTop.cpu.wally.core.ieu.dp.regf.wd3;
    assign FPRAddr        = fpgaTop.cpu.wally.core.fpu.fpu.fregfile.a4;
    assign FPRWen         = fpgaTop.cpu.wally.core.fpu.fpu.fregfile.we4;
    assign FPRValue       = fpgaTop.cpu.wally.core.fpu.fpu.fregfile.wd4;

    assign CSRArray[0] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MSTATUS_REGW; // 12'h300
    assign CSRArray[1] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MSTATUSH_REGW; // 12'h310
    assign CSRArray[2] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MTVEC_REGW; // 12'h305
    assign CSRArray[3] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MEPC_REGW; // 12'h341
    assign CSRArray[4] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MCOUNTEREN_REGW; // 12'h306
    assign CSRArray[5] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MCOUNTINHIBIT_REGW; // 12'h320
    assign CSRArray[6] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MEDELEG_REGW; // 12'h302
    assign CSRArray[7] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MIDELEG_REGW; // 12'h303
    assign CSRArray[8] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MIP_REGW; // 12'h344
    assign CSRArray[9] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MIE_REGW; // 12'h304
    assign CSRArray[10] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MISA_REGW; // 12'h301
    assign CSRArray[11] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MENVCFG_REGW; // 12'h30A
    assign CSRArray[12] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MHARTID_REGW; // 12'hF14
    assign CSRArray[13] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MSCRATCH_REGW; // 12'h340
    assign CSRArray[14] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MCAUSE_REGW; // 12'h342
    assign CSRArray[15] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MTVAL_REGW; // 12'h343
    assign CSRArray[16] = 0; // 12'hF11
    assign CSRArray[17] = 0; // 12'hF12
    assign CSRArray[18] = {{P.XLEN-12{1'b0}}, 12'h100}; // 12'hF13
    assign CSRArray[19] = 0; // 12'hF15
    assign CSRArray[20] = 0; // 12'h34A
    // supervisor CSRs
    assign CSRArray[21] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.SSTATUS_REGW; // 12'h100
    assign CSRArray[22] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MIE_REGW & 12'h222; // 12'h104
    assign CSRArray[23] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.STVEC_REGW; // 12'h105
    assign CSRArray[24] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.SEPC_REGW; // 12'h141
    assign CSRArray[25] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.SCOUNTEREN_REGW; // 12'h106
    assign CSRArray[26] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.SENVCFG_REGW; // 12'h10A
    assign CSRArray[27] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.SATP_REGW; // 12'h180
    assign CSRArray[28] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.SSCRATCH_REGW; // 12'h140
    assign CSRArray[29] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.STVAL_REGW; // 12'h143
    assign CSRArray[30] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.SCAUSE_REGW; // 12'h142
    assign CSRArray[31] = fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MIP_REGW & 12'h222 & fpgaTop.cpu.wally.core.priv.priv.csr.csrm.MIDELEG_REGW; // 12'h144
    assign CSRArray[32] = fpgaTop.cpu.wally.core.priv.priv.csr.csrs.csrs.STIMECMP_REGW; // 12'h14D
    // user CSRs
    assign CSRArray[33] = fpgaTop.cpu.wally.core.priv.priv.csr.csru.csru.FFLAGS_REGW; // 12'h001
    assign CSRArray[34] = fpgaTop.cpu.wally.core.priv.priv.csr.csru.csru.FRM_REGW; // 12'h002
    assign CSRArray[35] = {fpgaTop.cpu.wally.core.priv.priv.csr.csru.csru.FRM_REGW, fpgaTop.cpu.wally.core.priv.priv.csr.csru.csru.FFLAGS_REGW}; // 12'h003

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
