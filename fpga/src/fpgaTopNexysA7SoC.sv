///////////////////////////////////////////
// fpgaTop.sv
//
// Written: jcschroeder@gmail.com February 25, 2025
// Modified:
//
// Purpose: This is a top level for the fpga's implementation of wally.
//          Instantiates wallysoc and all AXI bus infrastructure
//
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
    // USB OHCI (2 ports) D+/D- pins
    , inout wire        usb0_dp
    , inout wire        usb0_dm
    , inout wire        usb1_dp
   , inout wire        usb1_dm

    // SDHCI card pins
    , output logic      SD_CLK
    , input  logic      SD_CD_N
    //, input  logic      SD_CD
    , inout  wire       SD_CMD
    , inout  wire [3:0] SD_DAT
    , output logic      SD_RESET

    // Pmod I2S2 TX pins
    , output logic      i2s_tx_mclk
    , output logic      i2s_tx_lrck
    , output logic      i2s_tx_sclk
    , output logic      i2s_tx_sdout

   );

  // The board bridge and cvwsoc_axi boundary follow Wally's configured AHB
  // data width.  AXI addresses remain 32 bits because the Xilinx bridge IP
  // and FPGA address map are 32-bit.
  localparam int unsigned STRB_W = P.AHBW/8;

  // MMCM Signals
  logic          CPUCLK;
  logic          cpuclk_raw;
  logic          c0_ddr4_ui_clk_sync_rst;
  logic          bus_struct_reset;
  logic          peripheral_reset;
  logic          interconnect_aresetn;
  logic          peripheral_aresetn;
  logic          mb_reset;

  // The board card-detect signal is active low; SDHCI expects CD_N.
  assign         SD_RESET = peripheral_reset;

  // AHB Signals from Wally
  logic            HCLKOpen;
  logic            HRESETnOpen;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] HRDATAEXT;
  (* mark_debug = "true" *) logic            HREADYEXT;
  (* mark_debug = "true" *) logic            HRESPEXT;
  (* mark_debug = "true" *) logic            HSELEXT;
  (* mark_debug = "true" *) logic [55:0]     HADDR;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] HWDATA;
  (* mark_debug = "true" *) logic [STRB_W-1:0] HWSTRB;
  (* mark_debug = "true" *) logic            HWRITE;
  (* mark_debug = "true" *) logic [2:0]      HSIZE;
  (* mark_debug = "true" *) logic [2:0]      HBURST;
  (* mark_debug = "true" *) logic [1:0]      HTRANS;
  (* mark_debug = "true" *) logic            HREADY;
  (* mark_debug = "true" *) logic [3:0]      HPROT;
  (* mark_debug = "true" *) logic            HMASTLOCK;

  // GPIO Signals
  logic [31:0]    GPIOIN, GPIOOUT, GPIOEN;


  // AHB to AXI Bridge Signals
  (* mark_debug = "true" *) logic [3:0]      m_axi_awid;
  (* mark_debug = "true" *) logic [7:0]      m_axi_awlen;
  (* mark_debug = "true" *) logic [2:0]      m_axi_awsize;
  (* mark_debug = "true" *) logic [1:0]      m_axi_awburst;
  (* mark_debug = "true" *) logic [3:0]      m_axi_awcache;
  (* mark_debug = "true" *) logic [31:0]     m_axi_awaddr;
  (* mark_debug = "true" *) logic [2:0]      m_axi_awprot;
  (* mark_debug = "true" *) logic            m_axi_awvalid;
  (* mark_debug = "true" *) logic            m_axi_awready;
  (* mark_debug = "true" *) logic            m_axi_awlock;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] m_axi_wdata;
  (* mark_debug = "true" *) logic [STRB_W-1:0] m_axi_wstrb;
  (* mark_debug = "true" *) logic            m_axi_wlast;
  (* mark_debug = "true" *) logic            m_axi_wvalid;
  (* mark_debug = "true" *) logic            m_axi_wready;
  (* mark_debug = "true" *) logic [3:0]      m_axi_bid;
  (* mark_debug = "true" *) logic [1:0]      m_axi_bresp;
  (* mark_debug = "true" *) logic            m_axi_bvalid;
  (* mark_debug = "true" *) logic            m_axi_bready;
  (* mark_debug = "true" *) logic [3:0]      m_axi_arid;
  (* mark_debug = "true" *) logic [7:0]      m_axi_arlen;
  (* mark_debug = "true" *) logic [2:0]      m_axi_arsize;
  (* mark_debug = "true" *) logic [1:0]      m_axi_arburst;
  (* mark_debug = "true" *) logic [2:0]      m_axi_arprot;
  (* mark_debug = "true" *) logic [3:0]      m_axi_arcache;
  (* mark_debug = "true" *) logic            m_axi_arvalid;
  (* mark_debug = "true" *) logic [31:0]     m_axi_araddr;
  (* mark_debug = "true" *) logic            m_axi_arlock;
  (* mark_debug = "true" *) logic            m_axi_arready;
  (* mark_debug = "true" *) logic [3:0]      m_axi_rid;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] m_axi_rdata;
  (* mark_debug = "true" *) logic [1:0]      m_axi_rresp;
  (* mark_debug = "true" *) logic            m_axi_rvalid;
  (* mark_debug = "true" *) logic            m_axi_rlast;
  (* mark_debug = "true" *) logic            m_axi_rready;

  //logic        usb_irq;

  logic [4:0] vga_r_5_internal;
  logic [5:0] vga_g_6_internal;
  logic [4:0] vga_b_5_internal;
  logic [4:0] cvwsoc_vga_r_5;
  logic [5:0] cvwsoc_vga_g_6;
  logic [4:0] cvwsoc_vga_b_5;

  //truncate (easiest way to handle 5-6-5 in a 4-4-4 output)
  assign vga_r_4 = cvwsoc_vga_r_5[4:1];
  assign vga_g_4 = cvwsoc_vga_g_6[5:2];
  assign vga_b_4 = cvwsoc_vga_b_5[4:1];


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
  logic            cpu_clk_locked;
  logic            rst_req, resetn_comb;
  logic [3:0]      cpu_axi_irq;

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
  assign rst_req = ~resetn;
  assign resetn_comb = ~rst_req;


  wire phy_ref_clk_raw;   // 50 MHz from MMCM
  wire rmii_clk50;

  // USB clock
  logic            clk48MHz_raw, clk48MHz;
(* ASYNC_REG="TRUE" *) logic usb_irq_ff1, usb_irq_ff2;


  // mmcm
  mmcm mmcm(.clk_out1(clk200),
            .clk_out2(clk48MHz_raw),
            .clk_out3(cpuclk_raw),
            .clk_out4(phy_ref_clk_raw),
            .reset(1'b0),
            .locked(cpu_clk_locked),
            .clk_in1(default_100mhz_clk));

  BUFG u_bufg_cpuclk (
    .I(cpuclk_raw),
    .O(CPUCLK)
  );

    BUFG u_bufg_rmii (
    .I(phy_ref_clk_raw),
    .O(rmii_clk50)
    );

    // drive PHY + LiteEth
    assign WB_RMII_REF_CLK = rmii_clk50;  // goes to pin D5 via XDC

  // reset controller XILINX IP
  sysrst sysrst
    (.slowest_sync_clk(CPUCLK),
     .ext_reset_in(rst_req),
     .aux_reset_in(1'b0),
     .mb_debug_sys_rst(1'b0),
     .dcm_locked(cpu_clk_locked),
     .mb_reset(mb_reset),  //open
     .bus_struct_reset(bus_struct_reset),
     .peripheral_reset(peripheral_reset), //open
     .interconnect_aresetn(interconnect_aresetn), //open
     .peripheral_aresetn(peripheral_aresetn));

  typedef logic [31:0]       cpu_axi_addr_t;
  typedef logic [1:0]        cpu_axi_id_t;
  typedef logic [P.AHBW-1:0] cpu_axi_data_t;
  typedef logic [STRB_W-1:0] cpu_axi_strb_t;
  typedef logic              cpu_axi_user_t;
  `AXI_TYPEDEF_ALL_CT(cpu_axi, cpu_axi_req_t, cpu_axi_resp_t,
                      cpu_axi_addr_t, cpu_axi_id_t, cpu_axi_data_t,
                      cpu_axi_strb_t, cpu_axi_user_t)
  localparam cvwsoc_cfg_t C = '{
      wally    : P,
      mem_type : P.LITEDRAM_SUPPORTED
                  ? CVWSOC_MEM_LITEDRAM_NEXYSA7
                  : CVWSOC_MEM_XILINX_DDR2,
      idma_config: '{
                    AxisDescReqCut: 1'b1
                    },
      vga_config:  '{
                    CutSplitterPath: 1'b1,
                    BufferDepth: 16,
                    MaxReadTxns: 4
                    },

      sdhci_config: '{
                    InsertRegClkBuf: 1'b1
                    }
  };
  cpu_axi_req_t  bridge_axi_req;
  cpu_axi_resp_t bridge_axi_resp;
  localparam xbar_out_t XBAR_OUT = gen_xbar_out(P);
  localparam int unsigned CPU_AXI_ID_WIDTH = $bits(cpu_axi_id_t);
  typedef logic [CPU_AXI_ID_WIDTH+$clog2(XBAR_OUT.n_slv)-1:0] ddr_axi_id_t;
  `AXI_TYPEDEF_ALL_CT(ddr_axi, ddr_axi_req_t, ddr_axi_resp_t,
                      cpu_axi_addr_t, ddr_axi_id_t, cpu_axi_data_t,
                      cpu_axi_strb_t, cpu_axi_user_t)
  `AXI_TYPEDEF_ALL_CT(ddr_csr_axi, ddr_csr_axi_req_t, ddr_csr_axi_resp_t,
                      cpu_axi_addr_t, ddr_axi_id_t, cpu_axi_data_t,
                      cpu_axi_strb_t, cpu_axi_user_t)
  ddr_axi_req_t ddr_axi_req;
  ddr_axi_resp_t ddr_axi_resp;
  ddr_csr_axi_req_t ddr_csr_axi_req;
  ddr_csr_axi_resp_t ddr_csr_axi_resp;
  logic ddr_busclk, ddr_buscorerstn, ddr_busrstn;

  // Wally
  wallypipelinedsoc  #(P)
  wallypipelinedsoc(.clk(CPUCLK), .reset_ext(bus_struct_reset), .reset(),
                    .HRDATAEXT, .HREADYEXT, .HRESPEXT, .HSELEXT,
                    .HCLK(HCLKOpen), .HRESETn(HRESETnOpen),
                    .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT,
                    .HTRANS, .HMASTLOCK, .HREADY, .TIMECLK(1'b0),
                    .GPIOIN, .GPIOOUT, .GPIOEN,
                    .UARTSin, .UARTSout, .SDCIn, .SDCCmd, .SDCCS(SDCCSin), .SDCCLK, .ExternalStall(RVVIStall)
                    /*  WB UART */
                    , .WB_UART_RX
                    , .WB_UART_TX
                    // WB Ethernet
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
                    , .AXI_USBIntr(cpu_axi_irq[1])
                    , .AXI_EthIntr(cpu_axi_irq[2])
                    , .AXI_SDHCIIntr(cpu_axi_irq[3])
                    , .AXI_DummyIntr(1'b0)
                    );

  if (P.XILINX_AXI_BR_SUPPORTED) begin
    // Xilinx AHB-Lite to AXI bridge IP.
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
    ahb_to_axi4_burst #(.AW(32), .DW(P.AHBW), .IW(4),
                        // matching cache line size in beats
                        .STREAM_WR_BUF_BEATS(8))

    ahbaxibridge (
      .clk(CPUCLK), .resetn(peripheral_aresetn),

      .HSEL(HSELEXT), .HADDR(HADDR[31:0]), .HPROT(HPROT),
      .HTRANS(HTRANS), .HSIZE(HSIZE), .HWRITE(HWRITE),
      .HBURST(HBURST), .HWDATA(HWDATA), .HREADY(HREADYEXT),
      .HREADYIN(HREADY), .HRDATA(HRDATAEXT), .HRESP(HRESPEXT),
      .HMASTLOCK(HMASTLOCK),

      .AWID(m_axi_awid), .AWLEN(m_axi_awlen), .AWSIZE(m_axi_awsize),
      .AWBURST(m_axi_awburst), .AWCACHE(m_axi_awcache),
      .AWADDR(m_axi_awaddr), .AWPROT(m_axi_awprot),
      .AWVALID(m_axi_awvalid), .AWREADY(m_axi_awready),
      .AWLOCK(m_axi_awlock), .AWQOS(4'b0000),

      .WDATA(m_axi_wdata), .WSTRB(m_axi_wstrb), .WLAST(m_axi_wlast),
      .WVALID(m_axi_wvalid), .WREADY(m_axi_wready),

      .BID(m_axi_bid), .BRESP(m_axi_bresp), .BVALID(m_axi_bvalid),
      .BREADY(m_axi_bready),

      .ARID(m_axi_arid), .ARLEN(m_axi_arlen), .ARSIZE(m_axi_arsize),
      .ARBURST(m_axi_arburst), .ARPROT(m_axi_arprot),
      .ARCACHE(m_axi_arcache), .ARVALID(m_axi_arvalid),
      .ARADDR(m_axi_araddr), .ARLOCK(m_axi_arlock),
      .ARREADY(m_axi_arready), .ARQOS(4'b0000),

      .RID(m_axi_rid), .RDATA(m_axi_rdata), .RRESP(m_axi_rresp),
      .RVALID(m_axi_rvalid), .RLAST(m_axi_rlast), .RREADY(m_axi_rready)
  );
  end

  // Pack the legacy flat bridge interface at the reusable CVWSoC boundary.
  assign bridge_axi_req.aw.id = m_axi_awid[1:0];
  assign bridge_axi_req.aw.addr = m_axi_awaddr;
  assign bridge_axi_req.aw.len = m_axi_awlen;
  assign bridge_axi_req.aw.size = m_axi_awsize;
  assign bridge_axi_req.aw.burst = m_axi_awburst;
  assign bridge_axi_req.aw.lock = m_axi_awlock;
  assign bridge_axi_req.aw.cache = m_axi_awcache;
  assign bridge_axi_req.aw.prot = m_axi_awprot;
  assign bridge_axi_req.aw.qos = '0;
  assign bridge_axi_req.aw.region = '0;
  assign bridge_axi_req.aw.atop = '0;
  assign bridge_axi_req.aw.user = '0;
  assign bridge_axi_req.aw_valid = m_axi_awvalid;
  assign bridge_axi_req.w.data = m_axi_wdata;
  assign bridge_axi_req.w.strb = m_axi_wstrb;
  assign bridge_axi_req.w.last = m_axi_wlast;
  assign bridge_axi_req.w.user = '0;
  assign bridge_axi_req.w_valid = m_axi_wvalid;
  assign bridge_axi_req.b_ready = m_axi_bready;
  assign bridge_axi_req.ar.id = m_axi_arid[1:0];
  assign bridge_axi_req.ar.addr = m_axi_araddr;
  assign bridge_axi_req.ar.len = m_axi_arlen;
  assign bridge_axi_req.ar.size = m_axi_arsize;
  assign bridge_axi_req.ar.burst = m_axi_arburst;
  assign bridge_axi_req.ar.lock = m_axi_arlock;
  assign bridge_axi_req.ar.cache = m_axi_arcache;
  assign bridge_axi_req.ar.prot = m_axi_arprot;
  assign bridge_axi_req.ar.qos = '0;
  assign bridge_axi_req.ar.region = '0;
  assign bridge_axi_req.ar.user = '0;
  assign bridge_axi_req.ar_valid = m_axi_arvalid;
  assign bridge_axi_req.r_ready = m_axi_rready;
  assign m_axi_awready = bridge_axi_resp.aw_ready;
  assign m_axi_wready = bridge_axi_resp.w_ready;
  assign m_axi_bid = {{2{1'b0}}, bridge_axi_resp.b.id};
  assign m_axi_bresp = bridge_axi_resp.b.resp;
  assign m_axi_bvalid = bridge_axi_resp.b_valid;
  assign m_axi_arready = bridge_axi_resp.ar_ready;
  assign m_axi_rid = {{2{1'b0}}, bridge_axi_resp.r.id};
  assign m_axi_rdata = bridge_axi_resp.r.data;
  assign m_axi_rresp = bridge_axi_resp.r.resp;
  assign m_axi_rlast = bridge_axi_resp.r.last;
  assign m_axi_rvalid = bridge_axi_resp.r_valid;

  cvwsoc_ram #(
    .C(C), .CPU_AXI_ID_WIDTH(CPU_AXI_ID_WIDTH),
    .ddr_axi_req_t(ddr_axi_req_t), .ddr_axi_resp_t(ddr_axi_resp_t),
    .ddr_csr_axi_req_t(ddr_csr_axi_req_t), .ddr_csr_axi_resp_t(ddr_csr_axi_resp_t)
  ) u_cvwsoc_ram (
    .clk167_i(clk200), .clk200_i(clk200), .rst_req_i(rst_req), .resetn_comb_i(resetn_comb),
    .BUSCLK_o(ddr_busclk), .BUSCORERSTn_o(ddr_buscorerstn), .BUSRSTn_o(ddr_busrstn),
    .ddr_axi_req_i(ddr_axi_req), .ddr_axi_resp_o(ddr_axi_resp),
    .ddr_csr_axi_req_i(ddr_csr_axi_req), .ddr_csr_axi_resp_o(ddr_csr_axi_resp),
    .ddr_dq(ddr2_dq), .ddr_dqs_n(ddr2_dqs_n), .ddr_dqs_p(ddr2_dqs_p),
    .ddr_addr(ddr2_addr), .ddr_ba(ddr2_ba), .ddr_ras_n(ddr2_ras_n),
    .ddr_cas_n(ddr2_cas_n), .ddr_we_n(ddr2_we_n), .ddr_reset_n(),
    .ddr_ck_p(ddr2_ck_p), .ddr_ck_n(ddr2_ck_n), .ddr_cke(ddr2_cke),
    .ddr_cs_n(ddr2_cs_n), .ddr_dm(ddr2_dm), .ddr_odt(ddr2_odt)
  );

  cvwsoc_axi #(.C(C), .CPU_AXI_ID_WIDTH(CPU_AXI_ID_WIDTH), .cpu_axi_req_t(cpu_axi_req_t),
               .cpu_axi_resp_t(cpu_axi_resp_t),
               .ddr_axi_req_t(ddr_axi_req_t), .ddr_axi_resp_t(ddr_axi_resp_t),
               .ddr_csr_axi_req_t(ddr_csr_axi_req_t), .ddr_csr_axi_resp_t(ddr_csr_axi_resp_t)) u_cvwsoc_axi (
    .CPUCLK_i(CPUCLK), .clk167_i(clk200), .clk200_i(clk200),
    .clk48MHz_raw_i(clk48MHz_raw), .audio_clk_i(CPUCLK),
    .cpu_clk_locked_i(cpu_clk_locked), .peripheral_reset_i(peripheral_reset),
    .peripheral_aresetn_i(peripheral_aresetn), .rst_req_i(rst_req),
    .resetn_comb_i(resetn_comb),
    .ddr_axi_req_o(ddr_axi_req), .ddr_axi_resp_i(ddr_axi_resp),
    .ddr_csr_axi_req_o(ddr_csr_axi_req), .ddr_csr_axi_resp_i(ddr_csr_axi_resp),
    .BUSCLK_i(ddr_busclk), .BUSCORERSTn_i(ddr_buscorerstn), .BUSRSTn_i(ddr_busrstn),
    .vga_hsync(vga_hsync), .vga_vsync(vga_vsync),
    .vga_r_5(cvwsoc_vga_r_5), .vga_g_6(cvwsoc_vga_g_6),
    .vga_b_5(cvwsoc_vga_b_5),
    .usb0_dp(usb0_dp), .usb0_dm(usb0_dm), .usb1_dp(usb1_dp), .usb1_dm(usb1_dm),

    .SD_CLK,
    .SD_CD_N,
    .SD_CMD,
    .SD_DAT,
    .i2s_tx_mclk,
    .i2s_tx_lrck,
    .i2s_tx_sclk,
    .i2s_tx_sdout,
    .cpu_axi_req_i(bridge_axi_req), .cpu_axi_resp_o(bridge_axi_resp),
    .cpu_axi_irq_o(cpu_axi_irq)
  );

  (* mark_debug = "true" *)  logic IlaTrigger;

  // No RVVI stuff here
  assign IlaTrigger = '0;
  assign RVVIStall = '0;


endmodule
