///////////////////////////////////////////
// cvwsoc_axi.sv
//
// Written: jcschroeder@gmail.com July 17, 2026
// Modified:
//
// Purpose: This is a CVWSoC AXI bus wrapper
//          Instantiates all CVWSoC AXI bus infrastructure
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

`include "axi/typedef.svh"
`include "axi_stream/typedef.svh"

import cvw::*;
import cvwsoc_pkg::*;

module cvwsoc_axi #(
    parameter cvwsoc_cfg_t C,
    parameter type cpu_axi_req_t  = logic,
    parameter type cpu_axi_resp_t = logic,
    parameter type ddr_axi_req_t  = logic,
    parameter type ddr_axi_resp_t = logic,
    parameter type ddr_csr_axi_req_t  = logic,
    parameter type ddr_csr_axi_resp_t = logic
  )
  (
    input logic         CPUCLK_i,
    input logic         clk167_i,
    input logic         clk200_i,
    input logic         clk48MHz_raw_i,
    input logic         audio_clk_i,
    input logic         mmcm1_locked_i,
    input logic         peripheral_reset_i,
    input logic         peripheral_aresetn_i,
    input logic         rst_req_i,
    input logic         resetn_comb_i,

    input  logic          rgmii_clocks_rx,
    output logic          rgmii_clocks_tx,
    input  logic          rgmii_int_n,
    output logic          rgmii_mdc,
    inout  logic          rgmii_mdio,
    output logic          rgmii_rst_n,
    input  logic          rgmii_rx_ctl,
    input  logic    [3:0] rgmii_rx_data,
    output logic          rgmii_tx_ctl,
    output logic    [3:0] rgmii_tx_data,

    // VGA signals
    output logic        vga_hsync,
    output logic        vga_vsync,
    output logic [4:0]  vga_r_5,
    output logic [5:0]  vga_g_6,
    output logic [4:0]  vga_b_5,
    // USB OHCI (2 ports) D+/D- pins
    inout wire        usb0_dp,
    inout wire        usb0_dm,
    inout wire        usb1_dp,
    inout wire        usb1_dm,
    // SDHCI card pins
    output logic      SD_CLK,
    input  logic      SD_CD_N,
    inout  wire       SD_CMD,
    inout  wire [3:0] SD_DAT,
    // Pmod I2S2 TX pins
    output logic      i2s_tx_mclk,
    output logic      i2s_tx_lrck,
    output logic      i2s_tx_sclk,
    output logic      i2s_tx_sdout,

    // CPU/bridge-side AXI master port.
    input  cpu_axi_req_t  cpu_axi_req_i,
    output cpu_axi_resp_t cpu_axi_resp_o,
    // DDR AXI master data and control ports
    output ddr_axi_req_t  ddr_axi_req_o,
    input  ddr_axi_resp_t ddr_axi_resp_i,
    output ddr_csr_axi_req_t  ddr_csr_axi_req_o,
    input  ddr_csr_axi_resp_t ddr_csr_axi_resp_i,

    input logic BUSCLK_i,
    input logic BUSCORERSTn_i,
    input logic BUSRSTn_i,

    output logic [3:0] cpu_axi_irq_o
  );

  // P remains a local alias to preserve the existing logical-SoC uses below.
  localparam cvw_t P = C.wally;
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

  // Keep this constant helper at module scope: some lint tools reject a
  // constant function declared inside the crossbar generate branch.
  localparam bit [XBAR_MAX_SLV-1:0][XBAR_MAX_MST-1:0] XBAR_CONNECTIVITY_FULL =
      gen_xbar_connectivity(P);

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

  // MMCM Signals
  logic          CPUCLK;
  logic          peripheral_reset;
  logic          peripheral_aresetn;

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

  logic        usb_irq;

  logic        liteeth_irq;
  logic        sdhci_irq;

  (* mark_debug = "true" *) logic        sd_clk_o;
  (* mark_debug = "true" *) logic        sd_cd_ni;
  (* mark_debug = "true" *) logic        sd_cmd_en;
  (* mark_debug = "true" *) logic        sd_cmd_o;
  (* mark_debug = "true" *) logic        sd_cmd_i;
  (* mark_debug = "true" *) logic        sd_dat_en;
  (* mark_debug = "true" *) logic [3:0]  sd_dat_o;
  (* mark_debug = "true" *) logic [3:0]  sd_dat_i;


  logic [4:0] vga_r_5_internal;
  logic [5:0] vga_g_6_internal;
  logic [4:0] vga_b_5_internal;

  // no need to truncate for Genesys2
  assign vga_r_5 = vga_r_5_internal[4:0];
  assign vga_g_6 = vga_g_6_internal[5:0];
  assign vga_b_5 = vga_b_5_internal[4:0];

  (* mark_debug = "true" *) logic       dma_irq_raw;
  logic       dma_introut_sync;
  logic       axi_dma_intr_sync;
  (* ASYNC_REG="TRUE" *) logic [1:0] dma_irq_sync;
  logic      usb_phy_resetn_sync;


  ///////////////////////////////////////////////////////////

  logic BUSCLK, BUSRST, BUSRSTn, BUSCORERST, BUSCORERSTn;

  logic          CLK208;
  logic             clk167;
  logic             clk200;

  logic             mmcm1_locked;

(* mark_debug = "true" *)  logic              RVVIStall;

  // USB clock
  logic            clk48MHz_raw, clk48MHz;
(* ASYNC_REG="TRUE" *) logic usb_irq_ff1, usb_irq_ff2;
(* ASYNC_REG="TRUE" *) logic liteeth_irq_ff1, liteeth_irq_ff2;
(* ASYNC_REG="TRUE" *) logic sdhci_irq_ff1, sdhci_irq_ff2;


  logic        audio_clk;
  logic rst_req;
  logic resetn_comb;
  assign BUSCLK = BUSCLK_i;
  assign BUSCORERSTn = BUSCORERSTn_i;
  assign BUSCORERST = ~BUSCORERSTn;
  assign BUSRSTn = BUSRSTn_i;
  assign BUSRST = ~BUSRSTn;
  assign CPUCLK = CPUCLK_i;
  assign peripheral_reset = peripheral_reset_i;
  assign peripheral_aresetn = peripheral_aresetn_i;
  assign clk167 = clk167_i;
  assign clk200 = clk200_i;
  assign audio_clk = audio_clk_i;
  assign clk48MHz_raw = clk48MHz_raw_i;
  assign mmcm1_locked = mmcm1_locked_i;
  assign rst_req = rst_req_i;
  assign resetn_comb = resetn_comb_i;

  // CPU-facing interrupt boundary.
  assign cpu_axi_irq_o = {sdhci_irq_ff2, liteeth_irq_ff2, usb_irq_ff2, axi_dma_intr_sync};


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

  // Native PULP crossbar fabric.  It is kept at module scope so peripherals
  // can connect directly in the PULP branch; only the Xilinx branch uses the
  // packed cb_* adapter signals.
  slv_req_t  [N_SLV-1:0] slv_req;
  slv_resp_t [N_SLV-1:0] slv_resp;
  mst_req_t  [N_MST-1:0] mst_req;
  mst_resp_t [N_MST-1:0] mst_resp;
  slv_req_t  cpu_bus_req;
  slv_resp_t cpu_bus_rsp;
  axis_req_t idma_axis_req;
  axis_rsp_t idma_axis_rsp;

  // PULP-facing peripheral interfaces stay bundled.  The flat cb_* vectors
  // are only an adapter boundary for the optional Xilinx crossbar.
  mst_req_t  vga_reg_req;
  mst_resp_t vga_reg_rsp;
  slv_req_t  vga_scan_req;
  slv_resp_t vga_scan_rsp;
  mst_req_t  sdhci_req;
  mst_resp_t sdhci_rsp;
  slv_req_t  cdma_req, usb_dma_req;
  slv_resp_t cdma_rsp, usb_dma_rsp;
  // DDR master port (external)
  assign ddr_axi_req_o = mst_req[CB_M_DDR];
  assign mst_resp[CB_M_DDR] = ddr_axi_resp_i;
  // DDR master control port
  generate
    if (P.LITEDRAM_SUPPORTED) begin : gen_dram_csr_connection
      assign ddr_csr_axi_req_o = mst_req[CB_M_DRAM_CSR];
      assign mst_resp[CB_M_DRAM_CSR] = ddr_csr_axi_resp_i;
    end else begin : gen_no_dram_csr_connection
      assign ddr_csr_axi_req_o = '0;
    end
  endgenerate

  if (P.XILINX_AXI_DMA_SUPPORTED) begin : gen_cdma_source_connection
    assign slv_req[CB_S_CDMA] = cdma_req;
    assign cdma_rsp = slv_resp[CB_S_CDMA];
  end

  if (P.AXI_USB_SUPPORTED) begin : gen_usb_source_connection
    assign slv_req[CB_S_USB] = usb_dma_req;
    assign usb_dma_rsp = slv_resp[CB_S_USB];
  end
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

  // Both CDC implementations expose exactly one packed BUSCLK-domain port.
  assign slv_req[CB_S_CPU] = cpu_bus_req;
  assign cpu_bus_rsp = slv_resp[CB_S_CPU];


  if (P.AXI_IDMA_SUPPORTED || P.AXI_IDMA_REG64_SUPPORTED ||
      P.AXIS_IDMA_SUPPORTED) begin : gen_idma_xbar
    begin : gen_struct_connections
      for (genvar i = 0; i < XBAR_OUT.idma_n_slv; i++) begin : gen_idma_slv
        localparam int unsigned S = XBAR_OUT.idma_slv_port[i];
        localparam int unsigned I = XBAR_OUT.idma_slv_req[i];
        assign slv_req[S] = idma_xbar_mst_req[I];
        assign idma_xbar_mst_rsp[I] = slv_resp[S];
      end
      for (genvar i = 0; i < XBAR_OUT.idma_n_mst; i++) begin : gen_idma_mst
        localparam int unsigned M = XBAR_OUT.idma_mst_port[i];
        localparam int unsigned I = XBAR_OUT.idma_mst_resp[i];
        assign idma_xbar_slv_req[I] = mst_req[M];
        assign mst_resp[M] = idma_xbar_slv_rsp[I];
      end
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


  if (P.XILINX_CDC_SUPPORTED) begin : gen_xilinx_cdc
    logic [MST_ID_W-1:0] m_axi_bid, m_axi_rid;
    logic [MST_ID_W-1:0] cpu_m_axi_awid, cpu_m_axi_arid;

    assign cpu_axi_resp_o.b.id = m_axi_bid[SLV_ID_W-1:0];
    assign cpu_axi_resp_o.b.user = '0;
    assign cpu_axi_resp_o.r.id = m_axi_rid[SLV_ID_W-1:0];
    assign cpu_axi_resp_o.r.user = '0;
    assign cpu_bus_req.aw.id = cpu_m_axi_awid[SLV_ID_W-1:0];
    assign cpu_bus_req.aw.atop = '0;
    assign cpu_bus_req.aw.user = '0;
    assign cpu_bus_req.w.user = '0;
    assign cpu_bus_req.ar.id = cpu_m_axi_arid[SLV_ID_W-1:0];
    assign cpu_bus_req.ar.user = '0;

    // AXI Clock Converter
    clkconverter clkconverter
      (.s_axi_aclk(CPUCLK),
       .s_axi_aresetn(peripheral_aresetn),
       .s_axi_awid({{(MST_ID_W-SLV_ID_W){1'b0}}, cpu_axi_req_i.aw.id}),
       .s_axi_awlen(cpu_axi_req_i.aw.len),
       .s_axi_awsize(cpu_axi_req_i.aw.size),
       .s_axi_awburst(cpu_axi_req_i.aw.burst),
       .s_axi_awcache(cpu_axi_req_i.aw.cache),
       .s_axi_awaddr(cpu_axi_req_i.aw.addr),
       .s_axi_awprot(cpu_axi_req_i.aw.prot),
       .s_axi_awregion(4'b0), // bridge does not provide these
       .s_axi_awqos(4'b0),    // bridge does not provide these
       .s_axi_awvalid(cpu_axi_req_i.aw_valid),
       .s_axi_awready(cpu_axi_resp_o.aw_ready),
       .s_axi_awlock(cpu_axi_req_i.aw.lock),
       .s_axi_wdata(cpu_axi_req_i.w.data),
       .s_axi_wstrb(cpu_axi_req_i.w.strb),
       .s_axi_wlast(cpu_axi_req_i.w.last),
       .s_axi_wvalid(cpu_axi_req_i.w_valid),
       .s_axi_wready(cpu_axi_resp_o.w_ready),
       .s_axi_bid(m_axi_bid),
       .s_axi_bresp(cpu_axi_resp_o.b.resp),
       .s_axi_bvalid(cpu_axi_resp_o.b_valid),
       .s_axi_bready(cpu_axi_req_i.b_ready),
       .s_axi_arid({{(MST_ID_W-SLV_ID_W){1'b0}}, cpu_axi_req_i.ar.id}),
       .s_axi_arlen(cpu_axi_req_i.ar.len),
       .s_axi_arsize(cpu_axi_req_i.ar.size),
       .s_axi_arburst(cpu_axi_req_i.ar.burst),
       .s_axi_arprot(cpu_axi_req_i.ar.prot),
       .s_axi_arregion(4'b0), // bridge does not provide these
       .s_axi_arqos(4'b0),    // bridge does not provide these
       .s_axi_arcache(cpu_axi_req_i.ar.cache),
       .s_axi_arvalid(cpu_axi_req_i.ar_valid),
       .s_axi_araddr(cpu_axi_req_i.ar.addr),
       .s_axi_arlock(cpu_axi_req_i.ar.lock),
       .s_axi_arready(cpu_axi_resp_o.ar_ready),
       .s_axi_rid(m_axi_rid),
       .s_axi_rdata(cpu_axi_resp_o.r.data),
       .s_axi_rresp(cpu_axi_resp_o.r.resp),
       .s_axi_rvalid(cpu_axi_resp_o.r_valid),
       .s_axi_rlast(cpu_axi_resp_o.r.last),
       .s_axi_rready(cpu_axi_req_i.r_ready),

       .m_axi_aclk(BUSCLK),
       .m_axi_aresetn(BUSCORERSTn),
       .m_axi_awid(cpu_m_axi_awid),
       .m_axi_awlen(cpu_bus_req.aw.len),
       .m_axi_awsize(cpu_bus_req.aw.size),
       .m_axi_awburst(cpu_bus_req.aw.burst),
       .m_axi_awcache(cpu_bus_req.aw.cache),
       .m_axi_awaddr(cpu_bus_req.aw.addr),
       .m_axi_awprot(cpu_bus_req.aw.prot),
       .m_axi_awregion(cpu_bus_req.aw.region),
       .m_axi_awqos(cpu_bus_req.aw.qos),
       .m_axi_awvalid(cpu_bus_req.aw_valid),
       .m_axi_awready(cpu_bus_rsp.aw_ready),
       .m_axi_awlock(cpu_bus_req.aw.lock),
       .m_axi_wdata(cpu_bus_req.w.data),
       .m_axi_wstrb(cpu_bus_req.w.strb),
       .m_axi_wlast(cpu_bus_req.w.last),
       .m_axi_wvalid(cpu_bus_req.w_valid),
       .m_axi_wready(cpu_bus_rsp.w_ready),
       .m_axi_bid({{(MST_ID_W-SLV_ID_W){1'b0}}, cpu_bus_rsp.b.id}),
       .m_axi_bresp(cpu_bus_rsp.b.resp),
       .m_axi_bvalid(cpu_bus_rsp.b_valid),
       .m_axi_bready(cpu_bus_req.b_ready),
       .m_axi_arid(cpu_m_axi_arid),
       .m_axi_arlen(cpu_bus_req.ar.len),
       .m_axi_arsize(cpu_bus_req.ar.size),
       .m_axi_arburst(cpu_bus_req.ar.burst),
       .m_axi_arprot(cpu_bus_req.ar.prot),
       .m_axi_arregion(cpu_bus_req.ar.region),
       .m_axi_arqos(cpu_bus_req.ar.qos),
       .m_axi_arcache(cpu_bus_req.ar.cache),
       .m_axi_arvalid(cpu_bus_req.ar_valid),
       .m_axi_araddr(cpu_bus_req.ar.addr),
       .m_axi_arlock(cpu_bus_req.ar.lock),
       .m_axi_arready(cpu_bus_rsp.ar_ready),
       .m_axi_rid({{(MST_ID_W-SLV_ID_W){1'b0}}, cpu_bus_rsp.r.id}),
       .m_axi_rdata(cpu_bus_rsp.r.data),
       .m_axi_rresp(cpu_bus_rsp.r.resp),
       .m_axi_rvalid(cpu_bus_rsp.r_valid),
       .m_axi_rlast(cpu_bus_rsp.r.last),
       .m_axi_rready(cpu_bus_req.r_ready));
  end else begin : gen_pulp_cdc

    // Bundles in each clock domain
    slv_req_t  cpu_req;
    slv_resp_t cpu_resp;

    assign cpu_req = cpu_axi_req_i;
    assign cpu_axi_resp_o = cpu_resp;

    axi_cdc #(
        .aw_chan_t ( slv_aw_t   ),
        .w_chan_t  ( axi_w_t    ),
        .b_chan_t  ( slv_b_t    ),
        .ar_chan_t ( slv_ar_t   ),
        .r_chan_t  ( slv_r_t    ),
        .axi_req_t ( slv_req_t  ),
        .axi_resp_t( slv_resp_t ),
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
        .dst_req_o  ( cpu_bus_req        ),
        .dst_resp_i ( cpu_bus_rsp        )
    );
  end

  if (P.XILINX_XBAR_SUPPORTED) begin : gen_xilinx_xbar
    logic [N_SLV*MST_ID_W-1:0] cb_s_axi_awid, cb_s_axi_bid, cb_s_axi_arid, cb_s_axi_rid;
    logic [N_SLV*ADDR_W-1:0] cb_s_axi_awaddr, cb_s_axi_araddr;
    logic [N_SLV*AXI_LEN_W-1:0] cb_s_axi_awlen, cb_s_axi_arlen;
    logic [N_SLV*AXI_SIZE_W-1:0] cb_s_axi_awsize, cb_s_axi_arsize;
    logic [N_SLV*AXI_BURST_W-1:0] cb_s_axi_awburst, cb_s_axi_arburst;
    logic [N_SLV*AXI_CACHE_W-1:0] cb_s_axi_awcache, cb_s_axi_arcache;
    logic [N_SLV*AXI_PROT_W-1:0] cb_s_axi_awprot, cb_s_axi_arprot;
    logic [N_SLV*AXI_QOS_W-1:0] cb_s_axi_awqos, cb_s_axi_arqos;
    logic [N_SLV*DATA_W-1:0] cb_s_axi_wdata, cb_s_axi_rdata;
    logic [N_SLV*STRB_W-1:0] cb_s_axi_wstrb;
    logic [N_SLV*AXI_RESP_W-1:0] cb_s_axi_bresp, cb_s_axi_rresp;
    logic [N_SLV-1:0] cb_s_axi_awlock, cb_s_axi_awvalid, cb_s_axi_awready;
    logic [N_SLV-1:0] cb_s_axi_wlast, cb_s_axi_wvalid, cb_s_axi_wready;
    logic [N_SLV-1:0] cb_s_axi_bvalid, cb_s_axi_bready;
    logic [N_SLV-1:0] cb_s_axi_arlock, cb_s_axi_arvalid, cb_s_axi_arready;
    logic [N_SLV-1:0] cb_s_axi_rlast, cb_s_axi_rvalid, cb_s_axi_rready;

    logic [N_MST*MST_ID_W-1:0] cb_m_axi_awid, cb_m_axi_bid, cb_m_axi_arid, cb_m_axi_rid;
    logic [N_MST*ADDR_W-1:0] cb_m_axi_awaddr, cb_m_axi_araddr;
    logic [N_MST*AXI_LEN_W-1:0] cb_m_axi_awlen, cb_m_axi_arlen;
    logic [N_MST*AXI_SIZE_W-1:0] cb_m_axi_awsize, cb_m_axi_arsize;
    logic [N_MST*AXI_BURST_W-1:0] cb_m_axi_awburst, cb_m_axi_arburst;
    logic [N_MST*AXI_CACHE_W-1:0] cb_m_axi_awcache, cb_m_axi_arcache;
    logic [N_MST*AXI_PROT_W-1:0] cb_m_axi_awprot, cb_m_axi_arprot;
    logic [N_MST*AXI_QOS_W-1:0] cb_m_axi_awregion, cb_m_axi_awqos;
    logic [N_MST*AXI_QOS_W-1:0] cb_m_axi_arregion, cb_m_axi_arqos;
    logic [N_MST*DATA_W-1:0] cb_m_axi_wdata, cb_m_axi_rdata;
    logic [N_MST*STRB_W-1:0] cb_m_axi_wstrb;
    logic [N_MST*AXI_RESP_W-1:0] cb_m_axi_bresp, cb_m_axi_rresp;
    logic [N_MST-1:0] cb_m_axi_awlock, cb_m_axi_awvalid, cb_m_axi_awready;
    logic [N_MST-1:0] cb_m_axi_wlast, cb_m_axi_wvalid, cb_m_axi_wready;
    logic [N_MST-1:0] cb_m_axi_bvalid, cb_m_axi_bready;
    logic [N_MST-1:0] cb_m_axi_arlock, cb_m_axi_arvalid, cb_m_axi_arready;
    logic [N_MST-1:0] cb_m_axi_rlast, cb_m_axi_rvalid, cb_m_axi_rready;

    // The Xilinx crossbar is the only flat-vector boundary.  Everything else
    // in cvwsoc_axi consumes or produces the canonical AXI structs.
    for (genvar s = 0; s < N_SLV; s++) begin : gen_xilinx_slv_adapter
      assign cb_s_axi_awid[s*MST_ID_W +: MST_ID_W] = {{(MST_ID_W-SLV_ID_W){1'b0}}, slv_req[s].aw.id};
      assign cb_s_axi_awaddr[s*ADDR_W +: ADDR_W] = slv_req[s].aw.addr;
      assign cb_s_axi_awlen[s*AXI_LEN_W +: AXI_LEN_W] = slv_req[s].aw.len;
      assign cb_s_axi_awsize[s*AXI_SIZE_W +: AXI_SIZE_W] = slv_req[s].aw.size;
      assign cb_s_axi_awburst[s*AXI_BURST_W +: AXI_BURST_W] = slv_req[s].aw.burst;
      assign cb_s_axi_awlock[s] = slv_req[s].aw.lock;
      assign cb_s_axi_awcache[s*AXI_CACHE_W +: AXI_CACHE_W] = slv_req[s].aw.cache;
      assign cb_s_axi_awprot[s*AXI_PROT_W +: AXI_PROT_W] = slv_req[s].aw.prot;
      assign cb_s_axi_awqos[s*AXI_QOS_W +: AXI_QOS_W] = slv_req[s].aw.qos;
      assign cb_s_axi_awvalid[s] = slv_req[s].aw_valid;
      assign cb_s_axi_wdata[s*DATA_W +: DATA_W] = slv_req[s].w.data;
      assign cb_s_axi_wstrb[s*STRB_W +: STRB_W] = slv_req[s].w.strb;
      assign cb_s_axi_wlast[s] = slv_req[s].w.last;
      assign cb_s_axi_wvalid[s] = slv_req[s].w_valid;
      assign cb_s_axi_bready[s] = slv_req[s].b_ready;
      assign cb_s_axi_arid[s*MST_ID_W +: MST_ID_W] = {{(MST_ID_W-SLV_ID_W){1'b0}}, slv_req[s].ar.id};
      assign cb_s_axi_araddr[s*ADDR_W +: ADDR_W] = slv_req[s].ar.addr;
      assign cb_s_axi_arlen[s*AXI_LEN_W +: AXI_LEN_W] = slv_req[s].ar.len;
      assign cb_s_axi_arsize[s*AXI_SIZE_W +: AXI_SIZE_W] = slv_req[s].ar.size;
      assign cb_s_axi_arburst[s*AXI_BURST_W +: AXI_BURST_W] = slv_req[s].ar.burst;
      assign cb_s_axi_arlock[s] = slv_req[s].ar.lock;
      assign cb_s_axi_arcache[s*AXI_CACHE_W +: AXI_CACHE_W] = slv_req[s].ar.cache;
      assign cb_s_axi_arprot[s*AXI_PROT_W +: AXI_PROT_W] = slv_req[s].ar.prot;
      assign cb_s_axi_arqos[s*AXI_QOS_W +: AXI_QOS_W] = slv_req[s].ar.qos;
      assign cb_s_axi_arvalid[s] = slv_req[s].ar_valid;
      assign cb_s_axi_rready[s] = slv_req[s].r_ready;

      always_comb begin
        slv_resp[s] = '0;
        slv_resp[s].aw_ready = cb_s_axi_awready[s];
        slv_resp[s].w_ready = cb_s_axi_wready[s];
        slv_resp[s].b.id = cb_s_axi_bid[s*MST_ID_W +: SLV_ID_W];
        slv_resp[s].b.resp = cb_s_axi_bresp[s*AXI_RESP_W +: AXI_RESP_W];
        slv_resp[s].b_valid = cb_s_axi_bvalid[s];
        slv_resp[s].ar_ready = cb_s_axi_arready[s];
        slv_resp[s].r.id = cb_s_axi_rid[s*MST_ID_W +: SLV_ID_W];
        slv_resp[s].r.data = cb_s_axi_rdata[s*DATA_W +: DATA_W];
        slv_resp[s].r.resp = cb_s_axi_rresp[s*AXI_RESP_W +: AXI_RESP_W];
        slv_resp[s].r.last = cb_s_axi_rlast[s];
        slv_resp[s].r_valid = cb_s_axi_rvalid[s];
      end
    end

    for (genvar m = 0; m < N_MST; m++) begin : gen_xilinx_mst_adapter
      always_comb begin
        mst_req[m] = '0;
        mst_req[m].aw.id = cb_m_axi_awid[m*MST_ID_W +: MST_ID_W];
        mst_req[m].aw.addr = cb_m_axi_awaddr[m*ADDR_W +: ADDR_W];
        mst_req[m].aw.len = cb_m_axi_awlen[m*AXI_LEN_W +: AXI_LEN_W];
        mst_req[m].aw.size = cb_m_axi_awsize[m*AXI_SIZE_W +: AXI_SIZE_W];
        mst_req[m].aw.burst = cb_m_axi_awburst[m*AXI_BURST_W +: AXI_BURST_W];
        mst_req[m].aw.lock = cb_m_axi_awlock[m];
        mst_req[m].aw.cache = cb_m_axi_awcache[m*AXI_CACHE_W +: AXI_CACHE_W];
        mst_req[m].aw.prot = cb_m_axi_awprot[m*AXI_PROT_W +: AXI_PROT_W];
        mst_req[m].aw.qos = cb_m_axi_awqos[m*AXI_QOS_W +: AXI_QOS_W];
        mst_req[m].aw.region = cb_m_axi_awregion[m*AXI_QOS_W +: AXI_QOS_W];
        mst_req[m].aw_valid = cb_m_axi_awvalid[m];
        mst_req[m].w.data = cb_m_axi_wdata[m*DATA_W +: DATA_W];
        mst_req[m].w.strb = cb_m_axi_wstrb[m*STRB_W +: STRB_W];
        mst_req[m].w.last = cb_m_axi_wlast[m];
        mst_req[m].w_valid = cb_m_axi_wvalid[m];
        mst_req[m].b_ready = cb_m_axi_bready[m];
        mst_req[m].ar.id = cb_m_axi_arid[m*MST_ID_W +: MST_ID_W];
        mst_req[m].ar.addr = cb_m_axi_araddr[m*ADDR_W +: ADDR_W];
        mst_req[m].ar.len = cb_m_axi_arlen[m*AXI_LEN_W +: AXI_LEN_W];
        mst_req[m].ar.size = cb_m_axi_arsize[m*AXI_SIZE_W +: AXI_SIZE_W];
        mst_req[m].ar.burst = cb_m_axi_arburst[m*AXI_BURST_W +: AXI_BURST_W];
        mst_req[m].ar.lock = cb_m_axi_arlock[m];
        mst_req[m].ar.cache = cb_m_axi_arcache[m*AXI_CACHE_W +: AXI_CACHE_W];
        mst_req[m].ar.prot = cb_m_axi_arprot[m*AXI_PROT_W +: AXI_PROT_W];
        mst_req[m].ar.qos = cb_m_axi_arqos[m*AXI_QOS_W +: AXI_QOS_W];
        mst_req[m].ar.region = cb_m_axi_arregion[m*AXI_QOS_W +: AXI_QOS_W];
        mst_req[m].ar_valid = cb_m_axi_arvalid[m];
        mst_req[m].r_ready = cb_m_axi_rready[m];
      end

      assign cb_m_axi_awready[m] = mst_resp[m].aw_ready;
      assign cb_m_axi_wready[m] = mst_resp[m].w_ready;
      assign cb_m_axi_bid[m*MST_ID_W +: MST_ID_W] = mst_resp[m].b.id;
      assign cb_m_axi_bresp[m*AXI_RESP_W +: AXI_RESP_W] = mst_resp[m].b.resp;
      assign cb_m_axi_bvalid[m] = mst_resp[m].b_valid;
      assign cb_m_axi_arready[m] = mst_resp[m].ar_ready;
      assign cb_m_axi_rid[m*MST_ID_W +: MST_ID_W] = mst_resp[m].r.id;
      assign cb_m_axi_rdata[m*DATA_W +: DATA_W] = mst_resp[m].r.data;
      assign cb_m_axi_rresp[m*AXI_RESP_W +: AXI_RESP_W] = mst_resp[m].r.resp;
      assign cb_m_axi_rlast[m] = mst_resp[m].r.last;
      assign cb_m_axi_rvalid[m] = mst_resp[m].r_valid;
    end

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
        .AXI_USER_W ( 1        ),
        .CutSplitterPath(C.vga_config.CutSplitterPath),
        .s_axi_req_t  ( mst_req_t  ),
        .s_axi_resp_t ( mst_resp_t ),
        .m_axi_req_t  ( slv_req_t  ),
        .m_axi_resp_t ( slv_resp_t )
    ) axi_vga_wrap_i (
        .aclk    (BUSCLK),
        .aresetn (BUSRSTn),
        .s_axi_req_i   ( vga_reg_req  ),
        .s_axi_resp_o  ( vga_reg_rsp  ),
        .m_axi_req_o   ( vga_scan_req ),
        .m_axi_resp_i  ( vga_scan_rsp ),

        // VGA pins
        .vga_hsync_o   (vga_hsync),
        .vga_vsync_o   (vga_vsync),
        .vga_r_o       (vga_r_5_internal),
        .vga_g_o       (vga_g_6_internal),
        .vga_b_o       (vga_b_5_internal)
    );

    begin : gen_vga_connection
      assign vga_reg_req = mst_req[CB_M_VGA_REG];
      assign mst_resp[CB_M_VGA_REG] = vga_reg_rsp;
      assign slv_req[CB_S_VGA] = vga_scan_req;
      assign vga_scan_rsp = slv_resp[CB_S_VGA];
    end
  end else begin : gen_no_axi_vga
    assign {vga_hsync, vga_vsync, vga_r_5_internal, vga_g_6_internal,
            vga_b_5_internal} = '0;
  end

  // -> AXI4-Lite/32 -> USB OHCI control regs
  if (P.AXI_USB_SUPPORTED) begin : gen_axi_usb
    logic usb_reg_awready, usb_reg_wready, usb_reg_arready;
    logic usb_reg_bvalid, usb_reg_rvalid, usb_reg_rlast;
    logic [1:0] usb_reg_bresp, usb_reg_rresp;
    logic [MST_ID_W-1:0] usb_reg_bid, usb_reg_rid;
    logic [DATA_W-1:0] usb_reg_rdata;

    logic [31:0] usb_axil_awaddr, usb_axil_wdata, usb_axil_araddr, usb_axil_rdata;
    logic [3:0] usb_axil_wstrb;
    logic [2:0] usb_axil_awprot, usb_axil_arprot;
    logic [1:0] usb_axil_bresp, usb_axil_rresp;
    logic usb_axil_awvalid, usb_axil_awready, usb_axil_wvalid, usb_axil_wready;
    logic usb_axil_bvalid, usb_axil_bready, usb_axil_arvalid, usb_axil_arready;
    logic usb_axil_rvalid, usb_axil_rready;

    logic [7:0] usb_ctrl_awid, usb_ctrl_awlen, usb_ctrl_bid;
    logic [7:0] usb_ctrl_arid, usb_ctrl_arlen, usb_ctrl_rid;
    logic [11:0] usb_ctrl_awaddr, usb_ctrl_araddr;
    logic [31:0] usb_ctrl_wdata, usb_ctrl_rdata;
    logic [3:0] usb_ctrl_awcache, usb_ctrl_awqos, usb_ctrl_wstrb;
    logic [3:0] usb_ctrl_arcache, usb_ctrl_arqos;
    logic [2:0] usb_ctrl_awsize, usb_ctrl_awprot, usb_ctrl_arsize, usb_ctrl_arprot;
    logic [1:0] usb_ctrl_awburst, usb_ctrl_bresp, usb_ctrl_arburst, usb_ctrl_rresp;
    logic usb_ctrl_awlock, usb_ctrl_awvalid, usb_ctrl_awready;
    logic usb_ctrl_wlast, usb_ctrl_wvalid, usb_ctrl_wready;
    logic usb_ctrl_bvalid, usb_ctrl_bready, usb_ctrl_arlock;
    logic usb_ctrl_arvalid, usb_ctrl_arready, usb_ctrl_rlast;
    logic usb_ctrl_rvalid, usb_ctrl_rready;

    // AXI-Lite control path adapted to the OHCI wrapper's AXI4 subset.
    assign usb_ctrl_awaddr = usb_axil_awaddr[11:0];
    assign usb_ctrl_awprot = usb_axil_awprot;
    assign usb_ctrl_awvalid = usb_axil_awvalid;
    assign usb_axil_awready = usb_ctrl_awready;
    assign usb_ctrl_awid = '0;
    assign usb_ctrl_awlen = '0;
    assign usb_ctrl_awsize = 3'b010;
    assign usb_ctrl_awburst = 2'b01;
    assign usb_ctrl_awlock = 1'b0;
    assign usb_ctrl_awcache = '0;
    assign usb_ctrl_awqos = '0;
    assign usb_ctrl_wdata = usb_axil_wdata;
    assign usb_ctrl_wstrb = usb_axil_wstrb;
    assign usb_ctrl_wlast = 1'b1;
    assign usb_ctrl_wvalid = usb_axil_wvalid;
    assign usb_axil_wready = usb_ctrl_wready;
    assign usb_axil_bresp = usb_ctrl_bresp;
    assign usb_axil_bvalid = usb_ctrl_bvalid;
    assign usb_ctrl_bready = usb_axil_bready;
    assign usb_ctrl_araddr = usb_axil_araddr[11:0];
    assign usb_ctrl_arprot = usb_axil_arprot;
    assign usb_ctrl_arvalid = usb_axil_arvalid;
    assign usb_axil_arready = usb_ctrl_arready;
    assign usb_ctrl_arid = '0;
    assign usb_ctrl_arlen = '0;
    assign usb_ctrl_arsize = 3'b010;
    assign usb_ctrl_arburst = 2'b01;
    assign usb_ctrl_arlock = 1'b0;
    assign usb_ctrl_arcache = '0;
    assign usb_ctrl_arqos = '0;
    assign usb_axil_rdata = usb_ctrl_rdata;
    assign usb_axil_rresp = usb_ctrl_rresp;
    assign usb_axil_rvalid = usb_ctrl_rvalid;
    assign usb_ctrl_rready = usb_axil_rready;

    // usb_ohci_wrap does not expose these optional AXI sidebands.
    assign usb_dma_req.aw.qos    = '0;
    assign usb_dma_req.aw.region = '0;
    assign usb_dma_req.aw.atop   = '0;
    assign usb_dma_req.aw.user   = '0;
    assign usb_dma_req.w.user    = '0;
    assign usb_dma_req.ar.qos    = '0;
    assign usb_dma_req.ar.region = '0;
    assign usb_dma_req.ar.user   = '0;
    if (DATA_W == 32) begin : gen_usb_axi32_to_axilite32
        axi_req_t       usb_axi_req;
        axi_resp_t      usb_axi_resp;
        usb_axil_req_t  usb_axil_req;
        usb_axil_rsp_t  usb_axil_rsp;

        assign usb_axi_req = mst_req[CB_M_USB_REG];

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

        wire [31:0] usb_axil_pre_awaddr;
        wire [2:0]  usb_axil_pre_awprot;
        wire        usb_axil_pre_awvalid;
        wire        usb_axil_pre_awready;
        wire [31:0] usb_axil_pre_wdata;
        wire [3:0]  usb_axil_pre_wstrb;
        wire        usb_axil_pre_wvalid;
        wire        usb_axil_pre_wready;
        wire [1:0]  usb_axil_pre_bresp;
        wire        usb_axil_pre_bvalid;
        wire        usb_axil_pre_bready;
        wire [31:0] usb_axil_pre_araddr;
        wire [2:0]  usb_axil_pre_arprot;
        wire        usb_axil_pre_arvalid;
        wire        usb_axil_pre_arready;
        wire [31:0] usb_axil_pre_rdata;
        wire [1:0]  usb_axil_pre_rresp;
        wire        usb_axil_pre_rvalid;
        wire        usb_axil_pre_rready;

        assign usb_axil_pre_awaddr  = usb_axil_req.aw.addr;
        assign usb_axil_pre_awprot  = usb_axil_req.aw.prot;
        assign usb_axil_pre_awvalid = usb_axil_req.aw_valid;
        assign usb_axil_rsp.aw_ready = usb_axil_pre_awready;

        assign usb_axil_pre_wdata   = usb_axil_req.w.data;
        assign usb_axil_pre_wstrb   = usb_axil_req.w.strb;
        assign usb_axil_pre_wvalid  = usb_axil_req.w_valid;
        assign usb_axil_rsp.w_ready = usb_axil_pre_wready;

        assign usb_axil_rsp.b.resp  = usb_axil_pre_bresp;
        assign usb_axil_rsp.b_valid = usb_axil_pre_bvalid;
        assign usb_axil_pre_bready  = usb_axil_req.b_ready;

        assign usb_axil_pre_araddr  = usb_axil_req.ar.addr;
        assign usb_axil_pre_arprot  = usb_axil_req.ar.prot;
        assign usb_axil_pre_arvalid = usb_axil_req.ar_valid;
        assign usb_axil_rsp.ar_ready = usb_axil_pre_arready;

        assign usb_axil_rsp.r.data  = usb_axil_pre_rdata;
        assign usb_axil_rsp.r.resp  = usb_axil_pre_rresp;
        assign usb_axil_rsp.r_valid = usb_axil_pre_rvalid;
        assign usb_axil_pre_rready  = usb_axil_req.r_ready;

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

        .s_axil_awaddr   ( usb_axil_pre_awaddr ),
        .s_axil_awprot   ( usb_axil_pre_awprot ),
        .s_axil_awvalid  ( usb_axil_pre_awvalid ),
        .s_axil_awready  ( usb_axil_pre_awready ),
        .s_axil_wdata    ( usb_axil_pre_wdata ),
        .s_axil_wstrb    ( usb_axil_pre_wstrb ),
        .s_axil_wvalid   ( usb_axil_pre_wvalid ),
        .s_axil_wready   ( usb_axil_pre_wready ),
        .s_axil_bresp    ( usb_axil_pre_bresp ),
        .s_axil_bvalid   ( usb_axil_pre_bvalid ),
        .s_axil_bready   ( usb_axil_pre_bready ),
        .s_axil_araddr   ( usb_axil_pre_araddr ),
        .s_axil_arprot   ( usb_axil_pre_arprot ),
        .s_axil_arvalid  ( usb_axil_pre_arvalid ),
        .s_axil_arready  ( usb_axil_pre_arready ),
        .s_axil_rdata    ( usb_axil_pre_rdata ),
        .s_axil_rresp    ( usb_axil_pre_rresp ),
        .s_axil_rvalid   ( usb_axil_pre_rvalid ),
        .s_axil_rready   ( usb_axil_pre_rready ),

        .m_axil_awaddr   ( usb_axil_awaddr ),
        .m_axil_awprot   ( usb_axil_awprot ),
        .m_axil_awvalid  ( usb_axil_awvalid ),
        .m_axil_awready  ( usb_axil_awready ),
        .m_axil_wdata    ( usb_axil_wdata ),
        .m_axil_wstrb    ( usb_axil_wstrb ),
        .m_axil_wvalid   ( usb_axil_wvalid ),
        .m_axil_wready   ( usb_axil_wready ),
        .m_axil_bresp    ( usb_axil_bresp ),
        .m_axil_bvalid   ( usb_axil_bvalid ),
        .m_axil_bready   ( usb_axil_bready ),
        .m_axil_araddr   ( usb_axil_araddr ),
        .m_axil_arprot   ( usb_axil_arprot ),
        .m_axil_arvalid  ( usb_axil_arvalid ),
        .m_axil_arready  ( usb_axil_arready ),
        .m_axil_rdata    ( usb_axil_rdata ),
        .m_axil_rresp    ( usb_axil_rresp ),
        .m_axil_rvalid   ( usb_axil_rvalid ),
        .m_axil_rready   ( usb_axil_rready )
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
        .s_axi_awid    (mst_req[CB_M_USB_REG].aw.id),
        .s_axi_awaddr  (mst_req[CB_M_USB_REG].aw.addr),
        .s_axi_awlen   (mst_req[CB_M_USB_REG].aw.len),
        .s_axi_awsize  (mst_req[CB_M_USB_REG].aw.size),
        .s_axi_awburst (mst_req[CB_M_USB_REG].aw.burst),
        .s_axi_awvalid (mst_req[CB_M_USB_REG].aw_valid),
        .s_axi_awready (usb_reg_awready),

        .s_axi_wdata   (mst_req[CB_M_USB_REG].w.data),
        .s_axi_wstrb   (mst_req[CB_M_USB_REG].w.strb),
        .s_axi_wlast   (mst_req[CB_M_USB_REG].w.last),
        .s_axi_wvalid  (mst_req[CB_M_USB_REG].w_valid),
        .s_axi_wready  (usb_reg_wready),

        .s_axi_bresp   (usb_reg_bresp),
        .s_axi_bvalid  (usb_reg_bvalid),
        .s_axi_bid     (usb_reg_bid),
        .s_axi_bready  (mst_req[CB_M_USB_REG].b_ready),

        .s_axi_arid    (mst_req[CB_M_USB_REG].ar.id),
        .s_axi_araddr  (mst_req[CB_M_USB_REG].ar.addr),
        .s_axi_arlen   (mst_req[CB_M_USB_REG].ar.len),
        .s_axi_arsize  (mst_req[CB_M_USB_REG].ar.size),
        .s_axi_arburst (mst_req[CB_M_USB_REG].ar.burst),
        .s_axi_arvalid (mst_req[CB_M_USB_REG].ar_valid),
        .s_axi_arready (usb_reg_arready),

        .s_axi_rdata   (usb_reg_rdata),
        .s_axi_rresp   (usb_reg_rresp),
        .s_axi_rlast   (usb_reg_rlast),
        .s_axi_rvalid  (usb_reg_rvalid),
        .s_axi_rid     (usb_reg_rid),
        .s_axi_rready  (mst_req[CB_M_USB_REG].r_ready),

        // AXI4-Lite master side towards USB OHCI regs
        .m_axil_awaddr (usb_axil_awaddr),
        .m_axil_awprot (usb_axil_awprot),
        .m_axil_awvalid(usb_axil_awvalid),
        .m_axil_awready(usb_axil_awready),

        .m_axil_wdata  (usb_axil_wdata),
        .m_axil_wstrb  (usb_axil_wstrb),
        .m_axil_wvalid (usb_axil_wvalid),
        .m_axil_wready (usb_axil_wready),

        .m_axil_bresp  (usb_axil_bresp),
        .m_axil_bvalid (usb_axil_bvalid),
        .m_axil_bready (usb_axil_bready),

        .m_axil_araddr (usb_axil_araddr),
        .m_axil_arprot (usb_axil_arprot),
        .m_axil_arvalid(usb_axil_arvalid),
        .m_axil_arready(usb_axil_arready),

        .m_axil_rdata  (usb_axil_rdata),
        .m_axil_rresp  (usb_axil_rresp),
        .m_axil_rvalid (usb_axil_rvalid),
        .m_axil_rready (usb_axil_rready)
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
    // NOTE: phy_clk must be 48 MHz (or another integer multiple of 12 MHz).
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
        .m_axi_awid    (usb_dma_req.aw.id),
        .m_axi_awaddr  (usb_dma_req.aw.addr),
        .m_axi_awlen   (usb_dma_req.aw.len),
        .m_axi_awsize  (usb_dma_req.aw.size),
        .m_axi_awburst (usb_dma_req.aw.burst),
        .m_axi_awlock  (usb_dma_req.aw.lock),
        .m_axi_awcache (usb_dma_req.aw.cache),
        .m_axi_awprot  (usb_dma_req.aw.prot),
        .m_axi_awvalid (usb_dma_req.aw_valid),
        .m_axi_awready (usb_dma_rsp.aw_ready),

        .m_axi_wdata   (usb_dma_req.w.data),
        .m_axi_wstrb   (usb_dma_req.w.strb),
        .m_axi_wlast   (usb_dma_req.w.last),
        .m_axi_wvalid  (usb_dma_req.w_valid),
        .m_axi_wready  (usb_dma_rsp.w_ready),

        .m_axi_bid     (usb_dma_rsp.b.id),
        .m_axi_bresp   (usb_dma_rsp.b.resp),
        .m_axi_bvalid  (usb_dma_rsp.b_valid),
        .m_axi_bready  (usb_dma_req.b_ready),

        .m_axi_arid    (usb_dma_req.ar.id),
        .m_axi_araddr  (usb_dma_req.ar.addr),
        .m_axi_arlen   (usb_dma_req.ar.len),
        .m_axi_arsize  (usb_dma_req.ar.size),
        .m_axi_arburst (usb_dma_req.ar.burst),
        .m_axi_arlock  (usb_dma_req.ar.lock),
        .m_axi_arcache (usb_dma_req.ar.cache),
        .m_axi_arprot  (usb_dma_req.ar.prot),
        .m_axi_arvalid (usb_dma_req.ar_valid),
        .m_axi_arready (usb_dma_rsp.ar_ready),

        .m_axi_rid     (usb_dma_rsp.r.id),
        .m_axi_rdata   (usb_dma_rsp.r.data),
        .m_axi_rresp   (usb_dma_rsp.r.resp),
        .m_axi_rlast   (usb_dma_rsp.r.last),
        .m_axi_rvalid  (usb_dma_rsp.r_valid),
        .m_axi_rready  (usb_dma_req.r_ready),

        // IRQ + D+/D- pins
        .irq_o         (usb_irq),
        .usb0_dp       (usb0_dp),
        .usb0_dm       (usb0_dm),
        .usb1_dp       (usb1_dp),
        .usb1_dm       (usb1_dm)
    );

    assign mst_resp[CB_M_USB_REG].aw_ready = usb_reg_awready;
    assign mst_resp[CB_M_USB_REG].w_ready = usb_reg_wready;
    assign mst_resp[CB_M_USB_REG].ar_ready = usb_reg_arready;
    assign mst_resp[CB_M_USB_REG].b_valid = usb_reg_bvalid;
    assign mst_resp[CB_M_USB_REG].b.resp = usb_reg_bresp;
    assign mst_resp[CB_M_USB_REG].b.id = usb_reg_bid;
    assign mst_resp[CB_M_USB_REG].b.user = '0;
    assign mst_resp[CB_M_USB_REG].r_valid = usb_reg_rvalid;
    assign mst_resp[CB_M_USB_REG].r.last = usb_reg_rlast;
    assign mst_resp[CB_M_USB_REG].r.resp = usb_reg_rresp;
    assign mst_resp[CB_M_USB_REG].r.id = usb_reg_rid;
    assign mst_resp[CB_M_USB_REG].r.data = usb_reg_rdata;
    assign mst_resp[CB_M_USB_REG].r.user = '0;
  end else begin : gen_no_axi_usb
    // Keep the fixed S03/M03 ports quiescent until the xbar ports are compacted.
    assign usb_dma_req = '0;
    assign usb_irq = 1'b0;
  end

  // Synchronize USB interrupt into the CPU clock domain.
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
    logic liteeth_reg_awready, liteeth_reg_wready, liteeth_reg_arready;
    logic liteeth_reg_bvalid, liteeth_reg_rvalid, liteeth_reg_rlast;
    logic [1:0] liteeth_reg_bresp, liteeth_reg_rresp;
    logic [MST_ID_W-1:0] liteeth_reg_bid, liteeth_reg_rid;
    logic [DATA_W-1:0] liteeth_reg_rdata;

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
        .s_axi_awid    (mst_req[CB_M_ETH_REG].aw.id),
        .s_axi_awaddr  (mst_req[CB_M_ETH_REG].aw.addr),
        .s_axi_awlen   (mst_req[CB_M_ETH_REG].aw.len),
        .s_axi_awsize  (mst_req[CB_M_ETH_REG].aw.size),
        .s_axi_awburst (mst_req[CB_M_ETH_REG].aw.burst),
        .s_axi_awvalid (mst_req[CB_M_ETH_REG].aw_valid),
        .s_axi_awready (liteeth_reg_awready),

        .s_axi_wdata   (mst_req[CB_M_ETH_REG].w.data),
        .s_axi_wstrb   (mst_req[CB_M_ETH_REG].w.strb),
        .s_axi_wlast   (mst_req[CB_M_ETH_REG].w.last),
        .s_axi_wvalid  (mst_req[CB_M_ETH_REG].w_valid),
        .s_axi_wready  (liteeth_reg_wready),


        .s_axi_bresp   (liteeth_reg_bresp),
        .s_axi_bvalid  (liteeth_reg_bvalid),
        .s_axi_bid     (liteeth_reg_bid),
        .s_axi_bready  (mst_req[CB_M_ETH_REG].b_ready),


        .s_axi_arid    (mst_req[CB_M_ETH_REG].ar.id),
        .s_axi_araddr  (mst_req[CB_M_ETH_REG].ar.addr),
        .s_axi_arlen   (mst_req[CB_M_ETH_REG].ar.len),
        .s_axi_arsize  (mst_req[CB_M_ETH_REG].ar.size),
        .s_axi_arburst (mst_req[CB_M_ETH_REG].ar.burst),
        .s_axi_arvalid (mst_req[CB_M_ETH_REG].ar_valid),
        .s_axi_arready (liteeth_reg_arready),

        .s_axi_rdata   (liteeth_reg_rdata),
        .s_axi_rresp   (liteeth_reg_rresp),
        .s_axi_rlast   (liteeth_reg_rlast),
        .s_axi_rvalid  (liteeth_reg_rvalid),
        .s_axi_rid     (liteeth_reg_rid),
        .s_axi_rready  (mst_req[CB_M_ETH_REG].r_ready),


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

    assign mst_resp[CB_M_ETH_REG].aw_ready = liteeth_reg_awready;
    assign mst_resp[CB_M_ETH_REG].w_ready = liteeth_reg_wready;
    assign mst_resp[CB_M_ETH_REG].ar_ready = liteeth_reg_arready;
    assign mst_resp[CB_M_ETH_REG].b_valid = liteeth_reg_bvalid;
    assign mst_resp[CB_M_ETH_REG].b.resp = liteeth_reg_bresp;
    assign mst_resp[CB_M_ETH_REG].b.id = liteeth_reg_bid;
    assign mst_resp[CB_M_ETH_REG].b.user = '0;
    assign mst_resp[CB_M_ETH_REG].r_valid = liteeth_reg_rvalid;
    assign mst_resp[CB_M_ETH_REG].r.last = liteeth_reg_rlast;
    assign mst_resp[CB_M_ETH_REG].r.resp = liteeth_reg_rresp;
    assign mst_resp[CB_M_ETH_REG].r.id = liteeth_reg_rid;
    assign mst_resp[CB_M_ETH_REG].r.data = liteeth_reg_rdata;
    assign mst_resp[CB_M_ETH_REG].r.user = '0;
  end else begin : gen_no_axi_eth
    assign liteeth_irq = 1'b0;
  end


  // Synchronize Ethernet interrupt into the CPU clock domain.
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
    logic sdhci_reg_awready, sdhci_reg_wready, sdhci_reg_arready;
    logic sdhci_reg_bvalid, sdhci_reg_rvalid, sdhci_reg_rlast;
    logic [1:0] sdhci_reg_bresp, sdhci_reg_rresp;
    logic [MST_ID_W-1:0] sdhci_reg_bid, sdhci_reg_rid;
    logic [DATA_W-1:0] sdhci_reg_rdata;

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
      .AXI_USER_W ( 1        ),
      .InsertRegClkBuf ( C.sdhci_config.InsertRegClkBuf )
    ) sdhci_i (
      .aclk    (BUSCLK),
      .aresetn (BUSRSTn),

      // AXI slave regs from crossbar M06
      .s_axi_awid    (sdhci_req.aw.id),
      .s_axi_awaddr  (sdhci_req.aw.addr),
      .s_axi_awlen   (sdhci_req.aw.len),
      .s_axi_awsize  (sdhci_req.aw.size),
      .s_axi_awburst (sdhci_req.aw.burst),
      .s_axi_awlock  (sdhci_req.aw.lock),
      .s_axi_awcache (sdhci_req.aw.cache),
      .s_axi_awprot  (sdhci_req.aw.prot),
      .s_axi_awqos   (sdhci_req.aw.qos),
      .s_axi_awvalid (sdhci_req.aw_valid),
      .s_axi_awready (sdhci_reg_awready),

      .s_axi_wdata   (sdhci_req.w.data),
      .s_axi_wstrb   (sdhci_req.w.strb),
      .s_axi_wlast   (sdhci_req.w.last),
      .s_axi_wvalid  (sdhci_req.w_valid),
      .s_axi_wready  (sdhci_reg_wready),

      .s_axi_bresp   (sdhci_reg_bresp),
      .s_axi_bvalid  (sdhci_reg_bvalid),
      .s_axi_bid     (sdhci_reg_bid),
      .s_axi_bready  (sdhci_req.b_ready),

      .s_axi_arid    (sdhci_req.ar.id),
      .s_axi_araddr  (sdhci_req.ar.addr),
      .s_axi_arlen   (sdhci_req.ar.len),
      .s_axi_arsize  (sdhci_req.ar.size),
      .s_axi_arburst (sdhci_req.ar.burst),
      .s_axi_arlock  (sdhci_req.ar.lock),
      .s_axi_arcache (sdhci_req.ar.cache),
      .s_axi_arprot  (sdhci_req.ar.prot),
      .s_axi_arqos   (sdhci_req.ar.qos),
      .s_axi_arvalid (sdhci_req.ar_valid),
      .s_axi_arready (sdhci_reg_arready),

      .s_axi_rdata   (sdhci_reg_rdata),
      .s_axi_rresp   (sdhci_reg_rresp),
      .s_axi_rlast   (sdhci_reg_rlast),
      .s_axi_rvalid  (sdhci_reg_rvalid),
      .s_axi_rid     (sdhci_reg_rid),
      .s_axi_rready  (sdhci_req.r_ready),

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

    always_comb begin
      sdhci_rsp = '0;
      sdhci_rsp.aw_ready = sdhci_reg_awready;
      sdhci_rsp.w_ready  = sdhci_reg_wready;
      sdhci_rsp.b_valid  = sdhci_reg_bvalid;
      sdhci_rsp.b.id     = sdhci_reg_bid;
      sdhci_rsp.b.resp   = sdhci_reg_bresp;
      sdhci_rsp.ar_ready = sdhci_reg_arready;
      sdhci_rsp.r_valid  = sdhci_reg_rvalid;
      sdhci_rsp.r.id     = sdhci_reg_rid;
      sdhci_rsp.r.data   = sdhci_reg_rdata;
      sdhci_rsp.r.resp   = sdhci_reg_rresp;
      sdhci_rsp.r.last   = sdhci_reg_rlast;
    end

    begin : gen_sdhci_connection
      assign sdhci_req = mst_req[CB_M_SDHCI];
      assign mst_resp[CB_M_SDHCI] = sdhci_rsp;
    end
  end else begin : gen_no_axi_sdhci
    assign SD_CLK = 1'b0;
    assign SD_CMD = 1'bz;
    assign SD_DAT = 4'bzzzz;

    assign sdhci_irq = 1'b0;
    assign {sd_clk_o, sd_cd_ni, sd_cmd_en, sd_cmd_o, sd_cmd_i, sd_dat_en, sd_dat_o, sd_dat_i} = '0;

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
    logic reg_awready, reg_wready, reg_arready;
    logic reg_bvalid, reg_rvalid, reg_rlast;
    logic [1:0] reg_bresp, reg_rresp;
    logic [MST_ID_W-1:0] reg_bid, reg_rid;
    logic [DATA_W-1:0] reg_rdata;

    logic [31:0] pc_lite_awaddr, pc_lite_wdata, pc_lite_araddr, pc_lite_rdata;
    logic [3:0] pc_lite_wstrb;
    logic [2:0] pc_lite_awprot, pc_lite_arprot;
    logic [1:0] pc_lite_bresp, pc_lite_rresp;
    logic pc_lite_awvalid, pc_lite_awready, pc_lite_wvalid, pc_lite_wready;
    logic pc_lite_bvalid, pc_lite_bready, pc_lite_arvalid, pc_lite_arready;
    logic pc_lite_rvalid, pc_lite_rready;

    // The generated CDMA master omits ID, lock, QoS, region and user ports.
    assign cdma_req.aw.id = '0;
    assign cdma_req.aw.lock = 1'b0;
    assign cdma_req.aw.qos = '0;
    assign cdma_req.aw.region = '0;
    assign cdma_req.aw.atop = '0;
    assign cdma_req.aw.user = '0;
    assign cdma_req.w.user = '0;
    assign cdma_req.ar.id = '0;
    assign cdma_req.ar.lock = 1'b0;
    assign cdma_req.ar.qos = '0;
    assign cdma_req.ar.region = '0;
    assign cdma_req.ar.user = '0;
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
        .s_axi_awid    (mst_req[CB_M_CDMA_REG].aw.id),
        .s_axi_awaddr  (mst_req[CB_M_CDMA_REG].aw.addr),
        .s_axi_awlen   (mst_req[CB_M_CDMA_REG].aw.len),
        .s_axi_awsize  (mst_req[CB_M_CDMA_REG].aw.size),
        .s_axi_awburst (mst_req[CB_M_CDMA_REG].aw.burst),
        .s_axi_awvalid (mst_req[CB_M_CDMA_REG].aw_valid),
        .s_axi_awready (reg_awready),

        .s_axi_wdata   (mst_req[CB_M_CDMA_REG].w.data),
        .s_axi_wstrb   (mst_req[CB_M_CDMA_REG].w.strb),
        .s_axi_wlast   (mst_req[CB_M_CDMA_REG].w.last),
        .s_axi_wvalid  (mst_req[CB_M_CDMA_REG].w_valid),
        .s_axi_wready  (reg_wready),

        .s_axi_bresp   (reg_bresp),
        .s_axi_bvalid  (reg_bvalid),
        .s_axi_bid     (reg_bid),
        .s_axi_bready  (mst_req[CB_M_CDMA_REG].b_ready),

        .s_axi_arid    (mst_req[CB_M_CDMA_REG].ar.id),
        .s_axi_araddr  (mst_req[CB_M_CDMA_REG].ar.addr),
        .s_axi_arlen   (mst_req[CB_M_CDMA_REG].ar.len),
        .s_axi_arsize  (mst_req[CB_M_CDMA_REG].ar.size),
        .s_axi_arburst (mst_req[CB_M_CDMA_REG].ar.burst),
        .s_axi_arvalid (mst_req[CB_M_CDMA_REG].ar_valid),
        .s_axi_arready (reg_arready),

        .s_axi_rdata   (reg_rdata),
        .s_axi_rresp   (reg_rresp),
        .s_axi_rlast   (reg_rlast),
        .s_axi_rvalid  (reg_rvalid),
        .s_axi_rid     (reg_rid),
        .s_axi_rready  (mst_req[CB_M_CDMA_REG].r_ready),

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
      .m_axi_awaddr  (cdma_req.aw.addr),
      .m_axi_awlen   (cdma_req.aw.len),
      .m_axi_awsize  (cdma_req.aw.size),
      .m_axi_awburst (cdma_req.aw.burst),
      .m_axi_awcache (cdma_req.aw.cache),
      .m_axi_awprot  (cdma_req.aw.prot),
      .m_axi_awvalid (cdma_req.aw_valid),
      .m_axi_awready (cdma_rsp.aw_ready),

      .m_axi_wdata   (cdma_req.w.data),
      .m_axi_wstrb   (cdma_req.w.strb),
      .m_axi_wlast   (cdma_req.w.last),
      .m_axi_wvalid  (cdma_req.w_valid),
      .m_axi_wready  (cdma_rsp.w_ready),

      .m_axi_bresp   (cdma_rsp.b.resp),
      .m_axi_bvalid  (cdma_rsp.b_valid),
      .m_axi_bready  (cdma_req.b_ready),

      .m_axi_araddr  (cdma_req.ar.addr),
      .m_axi_arlen   (cdma_req.ar.len),
      .m_axi_arsize  (cdma_req.ar.size),
      .m_axi_arburst (cdma_req.ar.burst),
      .m_axi_arcache (cdma_req.ar.cache),
      .m_axi_arprot  (cdma_req.ar.prot),
      .m_axi_arvalid (cdma_req.ar_valid),
      .m_axi_arready (cdma_rsp.ar_ready),

      .m_axi_rdata   (cdma_rsp.r.data),
      .m_axi_rresp   (cdma_rsp.r.resp),
      .m_axi_rlast   (cdma_rsp.r.last),
      .m_axi_rvalid  (cdma_rsp.r_valid),
      .m_axi_rready  (cdma_req.r_ready),

      .cdma_introut  (dma_irq_raw)
    );
    assign mst_resp[CB_M_CDMA_REG].aw_ready = reg_awready;
    assign mst_resp[CB_M_CDMA_REG].w_ready = reg_wready;
    assign mst_resp[CB_M_CDMA_REG].ar_ready = reg_arready;
    assign mst_resp[CB_M_CDMA_REG].b_valid = reg_bvalid;
    assign mst_resp[CB_M_CDMA_REG].b.resp = reg_bresp;
    assign mst_resp[CB_M_CDMA_REG].b.id = reg_bid;
    assign mst_resp[CB_M_CDMA_REG].b.user = '0;
    assign mst_resp[CB_M_CDMA_REG].r_valid = reg_rvalid;
    assign mst_resp[CB_M_CDMA_REG].r.last = reg_rlast;
    assign mst_resp[CB_M_CDMA_REG].r.resp = reg_rresp;
    assign mst_resp[CB_M_CDMA_REG].r.id = reg_rid;
    assign mst_resp[CB_M_CDMA_REG].r.data = reg_rdata;
    assign mst_resp[CB_M_CDMA_REG].r.user = '0;
  end else if (P.AXI_IDMA_SUPPORTED || P.AXI_IDMA_REG64_SUPPORTED ||
               P.AXIS_IDMA_SUPPORTED) begin : gen_idma

    assign cdma_req = '0;

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
      .AxisDescReqBypass (~C.idma_config.AxisDescReqCut),
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
    assign i2s_tx_mclk = 1'b0;
    assign i2s_tx_lrck = 1'b0;
    assign i2s_tx_sclk = 1'b0;
    assign i2s_tx_sdout = 1'b0;

    assign cdma_req = '0;

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


endmodule
