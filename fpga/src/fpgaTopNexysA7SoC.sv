// Nexys A7 board wrapper for the CVWSoC.
// Written: jcschroeder@gmail.com February 25, 2025

`include "config.vh"
`include "axi/typedef.svh"
`include "axi_stream/typedef.svh"
import cvw::*;
import cvwsoc_pkg::*;
`include "parameter-defs.vh"

module fpgaTop #(parameter logic RVVI_SYNTH_SUPPORTED = 0) (
  input logic default_100mhz_clk, resetn,

  input logic [3:0] GPI, 
  output logic [4:0] GPO,
  input logic UARTSin, 
  output logic UARTSout,
  input logic SDCIn, 
  output logic SDCCLK, SDCCmd, SDCCS, 
  input logic SDCCD,

  inout logic [15:0] ddr2_dq, 
  inout logic [1:0] ddr2_dqs_n, ddr2_dqs_p,
  output logic [12:0] ddr2_addr, 
  output logic [2:0] ddr2_ba,
  output logic ddr2_ras_n, ddr2_cas_n, ddr2_we_n,
  output logic [0:0] ddr2_ck_p, ddr2_ck_n, ddr2_cke, ddr2_cs_n,
  output logic [1:0] ddr2_dm, 
  output logic [0:0] ddr2_odt,

  // wishbone
  input logic WB_UART_RX, 
  output logic WB_UART_TX, 
  output logic WB_RMII_REF_CLK,
  input logic WB_RMII_CRS_DV, 
  input logic [1:0] WB_RMII_RX_DATA,
  output logic [1:0] WB_RMII_TX_DATA, 
  output logic WB_RMII_TX_EN, WB_RMII_MDC,
  inout wire WB_RMII_MDIO, 
  output logic WB_RMII_RST_N, 
  input logic WB_RMII_PHY_IRQ,
  // vga
  output logic vga_hsync, vga_vsync, 
  output logic [3:0] vga_r_4, vga_g_4, vga_b_4,
  // usb
  inout wire usb0_dp, usb0_dm, usb1_dp, usb1_dm,
  // SDHC
  output logic SD_CLK, 
  input logic SD_CD_N, 
  inout wire SD_CMD, 
  inout wire [3:0] SD_DAT,
  output logic SD_RESET, 
  // I2S
  output logic i2s_tx_mclk, i2s_tx_lrck, i2s_tx_sclk, i2s_tx_sdout
);

  localparam int unsigned STRB_W = P.AHBW / 8;

  function automatic cvwsoc_mem_type_t cvwsoc_mem_type_from_wally(input cvw_t cfg);
    if (cfg.LITEDRAM_SUPPORTED) 
        return CVWSOC_MEM_LITEDRAM_NEXYSA7;
    return CVWSOC_MEM_XILINX_DDR2;
  endfunction

  localparam cvwsoc_cfg_t C = '{
    wally: P,
    cpu: (P.CPU_VEXRISCV_ENABLED ? CVWSOC_CPU_VEXRISCV : 
            (P.CPU_CVA6_ENABLED ? CVWSOC_CPU_CVA6 : CVWSOC_CPU_WALLY)),
    bus: '{ AtopsEnabled: P.CPU_CVA6_ENABLED ? 1'b1 : 1'b0 }, 
    mem_type: cvwsoc_mem_type_from_wally(P),
    idma_config: '{AxisDescReqCut: 1'b0},
    vga_config: '{CutSplitterPath: 1'b1, BufferDepth: 16, MaxReadTxns: 4},
    sdhci_config: '{InsertRegClkBuf: 1'b1}
  };

  typedef logic [31:0] cpu_axi_addr_t;
  typedef logic [1:0] cpu_axi_id_t;
  typedef logic [P.AHBW-1:0] cpu_axi_data_t;
  typedef logic [STRB_W-1:0] cpu_axi_strb_t;
  typedef logic cpu_axi_user_t;
  `AXI_TYPEDEF_ALL_CT(cpu_axi, cpu_axi_req_t, cpu_axi_resp_t, cpu_axi_addr_t, cpu_axi_id_t, cpu_axi_data_t, cpu_axi_strb_t, cpu_axi_user_t)
  localparam xbar_out_t XBAR_OUT = gen_xbar_out(P);
  localparam int unsigned CPU_AXI_ID_WIDTH = $bits(cpu_axi_id_t);
  typedef logic [CPU_AXI_ID_WIDTH+$clog2(XBAR_OUT.n_slv)-1:0] ddr_axi_id_t;
  `AXI_TYPEDEF_ALL_CT(ddr_axi, ddr_axi_req_t, ddr_axi_resp_t, cpu_axi_addr_t, ddr_axi_id_t, cpu_axi_data_t, cpu_axi_strb_t, cpu_axi_user_t)
  `AXI_TYPEDEF_ALL_CT(ddr_csr_axi, ddr_csr_axi_req_t, ddr_csr_axi_resp_t, cpu_axi_addr_t, ddr_axi_id_t, cpu_axi_data_t, cpu_axi_strb_t, cpu_axi_user_t)
  typedef ddr_axi_req_t ahb_axi_req_t;
  typedef ddr_axi_resp_t ahb_axi_resp_t;
  typedef ddr_axi_req_t wishbone_axi_req_t;
  typedef ddr_axi_resp_t wishbone_axi_resp_t;

  cpu_axi_req_t bridge_axi_req; 
  cpu_axi_resp_t bridge_axi_resp;
  ddr_axi_req_t ddr_axi_req; ddr_axi_resp_t ddr_axi_resp;
  ddr_csr_axi_req_t ddr_csr_axi_req; ddr_csr_axi_resp_t ddr_csr_axi_resp;
  ahb_axi_req_t ahb_axi_req; ahb_axi_resp_t ahb_axi_resp;
  wishbone_axi_req_t wishbone_axi_req; wishbone_axi_resp_t wishbone_axi_resp;

  logic CPUCLK, cpuclk_raw, clk200, clk48MHz_raw, cpu_clk_locked;
  (* mark_debug = "true" *) logic bus_struct_reset, peripheral_reset, peripheral_aresetn, interconnect_aresetn, mb_reset, rst_req, resetn_comb;
  logic ddr_busclk, ddr_buscorerstn, ddr_busrstn, ddr_buscorerstn_sync, cpu_rst_ni;
  logic cpu_meip, cpu_seip, ahb_meip, ahb_seip, RVVIStall;
  logic [3:0] cpu_axi_irq, SDCCSin;
  logic [31:0] GPIOIN, GPIOOUT, GPIOEN;
  logic wb_uart_irq, wb_eth_irq;
  logic [4:0] cvwsoc_vga_r_5;
  logic [5:0] cvwsoc_vga_g_6;
  logic [4:0] cvwsoc_vga_b_5;
  wire phy_ref_clk_raw, rmii_clk50, rgmii_mdio_unused;

  // Flat AXI aliases retained for the board ILA constraints and trace tools.
  (* mark_debug = "true" *) logic [3:0] cpu_m_axi_awid, cpu_m_axi_bid, cpu_m_axi_arid, cpu_m_axi_rid;
  (* mark_debug = "true" *) logic [31:0] cpu_m_axi_awaddr, cpu_m_axi_araddr;
  (* mark_debug = "true" *) logic [7:0] cpu_m_axi_awlen, cpu_m_axi_arlen;
  (* mark_debug = "true" *) logic [2:0] cpu_m_axi_awsize, cpu_m_axi_arsize;
  (* mark_debug = "true" *) logic [1:0] cpu_m_axi_awburst, cpu_m_axi_arburst, cpu_m_axi_bresp, cpu_m_axi_rresp;
  (* mark_debug = "true" *) logic [3:0] cpu_m_axi_awcache, cpu_m_axi_arcache;
  (* mark_debug = "true" *) logic [2:0] cpu_m_axi_awprot, cpu_m_axi_arprot;
  (* mark_debug = "true" *) logic cpu_m_axi_awvalid, cpu_m_axi_awready, cpu_m_axi_awlock;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] cpu_m_axi_wdata, cpu_m_axi_rdata;
  (* mark_debug = "true" *) logic [STRB_W-1:0] cpu_m_axi_wstrb;
  (* mark_debug = "true" *) logic cpu_m_axi_wlast, cpu_m_axi_wvalid, cpu_m_axi_wready;
  (* mark_debug = "true" *) logic cpu_m_axi_bvalid, cpu_m_axi_bready;
  (* mark_debug = "true" *) logic cpu_m_axi_arvalid, cpu_m_axi_arready, cpu_m_axi_arlock;
  (* mark_debug = "true" *) logic cpu_m_axi_rvalid, cpu_m_axi_rlast, cpu_m_axi_rready;

  assign GPIOIN = {25'b0, SDCCD, 2'b0, GPI};
  assign GPO = GPIOOUT[4:0];
  assign SDCCS = SDCCSin[0];
  assign SD_RESET = peripheral_reset;
  assign vga_r_4 = cvwsoc_vga_r_5[4:1];
  assign vga_g_4 = cvwsoc_vga_g_6[5:2];
  assign vga_b_4 = cvwsoc_vga_b_5[4:1];
  assign cpu_m_axi_awid = bridge_axi_req.aw.id;
  assign cpu_m_axi_awaddr = bridge_axi_req.aw.addr;
  assign cpu_m_axi_awlen = bridge_axi_req.aw.len;
  assign cpu_m_axi_awsize = bridge_axi_req.aw.size;
  assign cpu_m_axi_awburst = bridge_axi_req.aw.burst;
  assign cpu_m_axi_awcache = bridge_axi_req.aw.cache;
  assign cpu_m_axi_awprot = bridge_axi_req.aw.prot;
  assign cpu_m_axi_awvalid = bridge_axi_req.aw_valid;
  assign cpu_m_axi_awready = bridge_axi_resp.aw_ready;
  assign cpu_m_axi_awlock = bridge_axi_req.aw.lock;
  assign cpu_m_axi_wdata = bridge_axi_req.w.data;
  assign cpu_m_axi_wstrb = bridge_axi_req.w.strb;
  assign cpu_m_axi_wlast = bridge_axi_req.w.last;
  assign cpu_m_axi_wvalid = bridge_axi_req.w_valid;
  assign cpu_m_axi_wready = bridge_axi_resp.w_ready;
  assign cpu_m_axi_bid = bridge_axi_resp.b.id;
  assign cpu_m_axi_bresp = bridge_axi_resp.b.resp;
  assign cpu_m_axi_bvalid = bridge_axi_resp.b_valid;
  assign cpu_m_axi_bready = bridge_axi_req.b_ready;
  assign cpu_m_axi_arid = bridge_axi_req.ar.id;
  assign cpu_m_axi_araddr = bridge_axi_req.ar.addr;
  assign cpu_m_axi_arlen = bridge_axi_req.ar.len;
  assign cpu_m_axi_arsize = bridge_axi_req.ar.size;
  assign cpu_m_axi_arburst = bridge_axi_req.ar.burst;
  assign cpu_m_axi_arcache = bridge_axi_req.ar.cache;
  assign cpu_m_axi_arprot = bridge_axi_req.ar.prot;
  assign cpu_m_axi_arvalid = bridge_axi_req.ar_valid;
  assign cpu_m_axi_arready = bridge_axi_resp.ar_ready;
  assign cpu_m_axi_arlock = bridge_axi_req.ar.lock;
  assign cpu_m_axi_rid = bridge_axi_resp.r.id;
  assign cpu_m_axi_rdata = bridge_axi_resp.r.data;
  assign cpu_m_axi_rresp = bridge_axi_resp.r.resp;
  assign cpu_m_axi_rvalid = bridge_axi_resp.r_valid;
  assign cpu_m_axi_rlast = bridge_axi_resp.r.last;
  assign cpu_m_axi_rready = bridge_axi_req.r_ready;

  mmcm mmcm (
        .clk_out1(clk200), 
        .clk_out2(clk48MHz_raw),
        .clk_out3(cpuclk_raw),
        .clk_out4(phy_ref_clk_raw),
        .reset(1'b0),
        .locked(cpu_clk_locked),
        .clk_in1(default_100mhz_clk) );

  BUFG u_bufg_cpuclk (.I(cpuclk_raw), .O(CPUCLK) );
  BUFG u_bufg_rmii (.I(phy_ref_clk_raw), .O(rmii_clk50) );

  assign WB_RMII_REF_CLK = rmii_clk50;
  assign rst_req = ~resetn;
  assign resetn_comb = ~rst_req;

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

  synchronizer sync_ddr_reset (CPUCLK, ddr_buscorerstn, ddr_buscorerstn_sync);

  assign cpu_rst_ni = peripheral_aresetn & ddr_buscorerstn_sync;

  cvwsoc_cpu #(
        .C(C),
        .AXI_ID_W(CPU_AXI_ID_WIDTH),
        .cpu_axi_req_t(cpu_axi_req_t),
        .cpu_axi_resp_t(cpu_axi_resp_t) ) 
  cpu (
        .clk_i(CPUCLK),
        .rst_ni(cpu_rst_ni),
        .time_clk_i(CPUCLK),
        .meip_i(cpu_meip),
        .seip_i(cpu_seip),
        .external_stall_i(RVVIStall),
        .axi_req_o(bridge_axi_req),
        .axi_resp_i(bridge_axi_resp) );

  cvwsoc_ram #(.C(C),
    .CPU_AXI_ID_WIDTH(CPU_AXI_ID_WIDTH),
    .ddr_axi_req_t(ddr_axi_req_t),
    .ddr_axi_resp_t(ddr_axi_resp_t),
    .ddr_csr_axi_req_t(ddr_csr_axi_req_t),
    .ddr_csr_axi_resp_t(ddr_csr_axi_resp_t)) 
  u_cvwsoc_ram (
    .clk167_i(clk200),
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
    .ddr_dq(ddr2_dq),
    .ddr_dqs_n(ddr2_dqs_n),
    .ddr_dqs_p(ddr2_dqs_p),
    .ddr_addr(ddr2_addr),
    .ddr_ba(ddr2_ba),
    .ddr_ras_n(ddr2_ras_n),
    .ddr_cas_n(ddr2_cas_n),
    .ddr_we_n(ddr2_we_n),
    .ddr_reset_n(),
    .ddr_ck_p(ddr2_ck_p),
    .ddr_ck_n(ddr2_ck_n),
    .ddr_cke(ddr2_cke),
    .ddr_cs_n(ddr2_cs_n),
    .ddr_dm(ddr2_dm),
    .ddr_odt(ddr2_odt) );

  cvwsoc_axi #(
    .C(C),
    .CPU_AXI_ID_WIDTH(CPU_AXI_ID_WIDTH),
    .cpu_axi_req_t(cpu_axi_req_t),
    .cpu_axi_resp_t(cpu_axi_resp_t),
    .ddr_axi_req_t(ddr_axi_req_t),
    .ddr_axi_resp_t(ddr_axi_resp_t),
    .ddr_csr_axi_req_t(ddr_csr_axi_req_t),
    .ddr_csr_axi_resp_t(ddr_csr_axi_resp_t),
    .ahb_axi_req_t(ahb_axi_req_t),
    .ahb_axi_resp_t(ahb_axi_resp_t),
    .wishbone_axi_req_t(wishbone_axi_req_t),
    .wishbone_axi_resp_t(wishbone_axi_resp_t) )
  u_cvwsoc_axi (
    .CPUCLK_i(CPUCLK),
    .clk167_i(clk200),
    .clk200_i(clk200),
    .clk48MHz_raw_i(clk48MHz_raw),
    .audio_clk_i(CPUCLK),
    .cpu_clk_locked_i(cpu_clk_locked),
    .peripheral_reset_i(peripheral_reset),
    .peripheral_aresetn_i(peripheral_aresetn),
    .rst_req_i(rst_req),
    .resetn_comb_i(resetn_comb),
    .rgmii_clocks_rx(1'b0),
    .rgmii_clocks_tx(),
    .rgmii_int_n(1'b1),
    .rgmii_mdc(),
    .rgmii_mdio(rgmii_mdio_unused),
    .rgmii_rst_n(),
    .rgmii_rx_ctl(1'b0),
    .rgmii_rx_data('0),
    .rgmii_tx_ctl(),
    .rgmii_tx_data(),
    .vga_hsync,
    .vga_vsync,
    .vga_r_5(cvwsoc_vga_r_5),
    .vga_g_6(cvwsoc_vga_g_6),
    .vga_b_5(cvwsoc_vga_b_5),
    .usb0_dp, .usb0_dm, .usb1_dp, .usb1_dm,
    .SD_CLK, .SD_CD_N, .SD_CMD, .SD_DAT,
    .i2s_tx_mclk, .i2s_tx_lrck, .i2s_tx_sclk, .i2s_tx_sdout,
    .cpu_axi_req_i(bridge_axi_req),
    .cpu_axi_resp_o(bridge_axi_resp),
    .ddr_axi_req_o(ddr_axi_req),
    .ddr_axi_resp_i(ddr_axi_resp),
    .ddr_csr_axi_req_o(ddr_csr_axi_req),
    .ddr_csr_axi_resp_i(ddr_csr_axi_resp),
    .ahb_axi_req_o(ahb_axi_req),
    .ahb_axi_resp_i(ahb_axi_resp),
    .wishbone_axi_req_o(wishbone_axi_req),
    .wishbone_axi_resp_i(wishbone_axi_resp),
    .BUSCLK_i(ddr_busclk),
    .BUSCORERSTn_i(ddr_buscorerstn),
    .BUSRSTn_i(ddr_busrstn),
    .cpu_axi_irq_o(cpu_axi_irq) );

  cvwsoc_ahb #(
    .P(C.wally),
    .AXI_ID_W($bits(ahb_axi_req.aw.id)),
    .axi_req_t(ahb_axi_req_t),
    .axi_resp_t(ahb_axi_resp_t))
  u_cvwsoc_ahb (
    .clk_i(ddr_busclk),
    .rst_ni(ddr_buscorerstn),
    .axi_req_i(ahb_axi_req),
    .axi_resp_o(ahb_axi_resp),
    .MExtInt(ahb_meip),
    .SExtInt(ahb_seip),
    .GPIOIN,.GPIOOUT,.GPIOEN,
    .UARTSin, .UARTSout,
    .SPIIn(1'b0), .SPIOut(), .SPICS(), .SPICLK(),
    .SDCIn, .SDCCmd, .SDCCS(SDCCSin), .SDCCLK,
    .WBUartIntr(wb_uart_irq),
    .WBEthIntr(wb_eth_irq),
    .AXI_DMAIntr(cpu_axi_irq[0]),
    .AXI_USBIntr(cpu_axi_irq[1]),
    .AXI_EthIntr(cpu_axi_irq[2]),
    .AXI_DummyIntr(1'b0),
    .AXI_SDHCIIntr(cpu_axi_irq[3]) );

  assign cpu_meip = ahb_meip;
  assign cpu_seip = ahb_seip;

  generate if (C.wally.WISHBONE_SUPPORTED) begin : gen_fpga_wishbone
    cvwsoc_wishbone #(
        .P(C.wally),
        .AXI_ID_W($bits(wishbone_axi_req.aw.id)),
        .axi_req_t(wishbone_axi_req_t),
        .axi_resp_t(wishbone_axi_resp_t))
    u_cvwsoc_wishbone (
        .clk_i(ddr_busclk),
        .rst_ni(ddr_buscorerstn),
        .axi_req_i(wishbone_axi_req),
        .axi_resp_o(wishbone_axi_resp),
        .uart_rx_i(WB_UART_RX),
        .uart_tx_o(WB_UART_TX),
        .uart_irq_o(wb_uart_irq),
        .rmii_ref_clk_i(rmii_clk50),
        .rmii_crs_dv_i(WB_RMII_CRS_DV),
        .rmii_rx_data_i(WB_RMII_RX_DATA),
        .rmii_tx_data_o(WB_RMII_TX_DATA),
        .rmii_tx_en_o(WB_RMII_TX_EN),
        .rmii_mdc_o(WB_RMII_MDC),
        .rmii_mdio_io(WB_RMII_MDIO),
        .rmii_rst_n_o(WB_RMII_RST_N),
        .eth_irq_o(wb_eth_irq) );

  end else begin : gen_no_fpga_wishbone
    assign wishbone_axi_resp = '0;
    assign WB_UART_TX = 1'b0;
    assign WB_RMII_TX_DATA = '0;
    assign WB_RMII_TX_EN = 1'b0;
    assign WB_RMII_MDC = 1'b0;
    assign WB_RMII_RST_N = 1'b0;
    assign wb_uart_irq = 1'b0;
    assign wb_eth_irq = 1'b0;
  end endgenerate

  assign RVVIStall = 1'b0;

endmodule
