`include "axi/typedef.svh"

module cvwsoc_wishbone import cvw::*; #(
  parameter cvw_t P,
  parameter int unsigned AXI_ID_W = 2,
  parameter type axi_req_t = logic,
  parameter type axi_resp_t = logic
) (
  input logic clk_i, rst_ni,
  input axi_req_t axi_req_i,
  output axi_resp_t axi_resp_o,
  input logic uart_rx_i, output logic uart_tx_o, output logic uart_irq_o,
  input logic rmii_ref_clk_i, rmii_crs_dv_i,
  input logic [1:0] rmii_rx_data_i,
  output logic [1:0] rmii_tx_data_o,
  output logic rmii_tx_en_o, rmii_mdc_o,
  inout wire rmii_mdio_io,
  output logic rmii_rst_n_o, eth_irq_o
);
  localparam int unsigned ADDR_W = 32;
  localparam int unsigned DATA_W = P.AHBW;
  typedef logic [ADDR_W-1:0] addr_t;
  typedef logic [DATA_W-1:0] wide_data_t;
  typedef logic [DATA_W/8-1:0] wide_strb_t;
  typedef logic [31:0] wb_data_t;
  typedef logic [3:0] wb_strb_t;
  `AXI_LITE_TYPEDEF_ALL(wb_wide, addr_t, wide_data_t, wide_strb_t)
  `AXI_LITE_TYPEDEF_ALL(wb_narrow, addr_t, wb_data_t, wb_strb_t)
  wb_wide_req_t wide_req;
  wb_wide_resp_t wide_resp;
  wb_narrow_req_t narrow_req;
  wb_narrow_resp_t narrow_resp;
  logic [29:0] wb_addr;
  logic [31:0] wb_wdata, wb_rdata;
  logic [3:0] wb_sel;
  logic wb_cyc, wb_stb, wb_we, wb_ack, wb_err, wb_reset;

  logic [31:0] wb_axil_awaddr, wb_axil_wdata, wb_axil_araddr, wb_axil_rdata;
  logic [3:0] wb_axil_wstrb;
  logic [2:0] wb_axil_awprot, wb_axil_arprot;
  logic [1:0] wb_axil_bresp, wb_axil_rresp;
  logic wb_axil_awvalid, wb_axil_awready, wb_axil_wvalid, wb_axil_wready;
  logic wb_axil_bvalid, wb_axil_bready, wb_axil_arvalid, wb_axil_arready;
  logic wb_axil_rvalid, wb_axil_rready;


  axi_mmio_to_axilite32_v3 #(
    .AXI_ADDR_WIDTH ( ADDR_W   ),
    .AXI_DATA_WIDTH ( DATA_W   ),
    .AXI_ID_WIDTH   ( AXI_ID_W )
    ) axil_mmio_wishbone (

    .aclk(clk_i),
    .aresetn(rst_ni),

    .s_axi_awid(axi_req_i.aw.id),
    .s_axi_awaddr(axi_req_i.aw.addr),
    .s_axi_awlen(axi_req_i.aw.len),
    .s_axi_awsize(axi_req_i.aw.size),
    .s_axi_awburst(axi_req_i.aw.burst),
    .s_axi_awvalid(axi_req_i.aw_valid),
    .s_axi_awready(axi_resp_o.aw_ready),
    .s_axi_wdata(axi_req_i.w.data),
    .s_axi_wstrb(axi_req_i.w.strb),
    .s_axi_wlast(axi_req_i.w.last),
    .s_axi_wvalid(axi_req_i.w_valid),
    .s_axi_wready(axi_resp_o.w_ready),
    .s_axi_bid(axi_resp_o.b.id),
    .s_axi_bvalid(axi_resp_o.b_valid),
    .s_axi_bready(axi_req_i.b_ready),
    .s_axi_arid(axi_req_i.ar.id),
    .s_axi_araddr(axi_req_i.ar.addr),
    .s_axi_arlen(axi_req_i.ar.len),
    .s_axi_arsize(axi_req_i.ar.size),
    .s_axi_arburst(axi_req_i.ar.burst),
    .s_axi_arvalid(axi_req_i.ar_valid),
    .s_axi_arready(axi_resp_o.ar_ready),
    .s_axi_rid(axi_resp_o.r.id),
    .s_axi_rdata(axi_resp_o.r.data),
    .s_axi_rlast(axi_resp_o.r.last),
    .s_axi_rvalid(axi_resp_o.r_valid),
    .s_axi_rready(axi_req_i.r_ready),

    .m_axil_awaddr (wb_axil_awaddr),
    .m_axil_awprot (wb_axil_awprot),
    .m_axil_awvalid(wb_axil_awvalid),
    .m_axil_awready(wb_axil_awready),

    .m_axil_wdata  (wb_axil_wdata),
    .m_axil_wstrb  (wb_axil_wstrb),
    .m_axil_wvalid (wb_axil_wvalid),
    .m_axil_wready (wb_axil_wready),

    .m_axil_bresp  (wb_axil_bresp),
    .m_axil_bvalid (wb_axil_bvalid),
    .m_axil_bready (wb_axil_bready),

    .m_axil_araddr (wb_axil_araddr),
    .m_axil_arprot (wb_axil_arprot),
    .m_axil_arvalid(wb_axil_arvalid),
    .m_axil_arready(wb_axil_arready),

    .m_axil_rdata  (wb_axil_rdata),
    .m_axil_rresp  (wb_axil_rresp),
    .m_axil_rvalid (wb_axil_rvalid),
    .m_axil_rready (wb_axil_rready) );

  axlite2wbsp #(
        .C_AXI_DATA_WIDTH(DATA_W), 
        .C_AXI_ADDR_WIDTH(ADDR_W)
  ) i_axil_to_wb (
    .i_clk(clk_i), .i_axi_reset_n(rst_ni),
    .i_axi_awvalid(wb_axil_awvalid),
    .o_axi_awready(wb_axil_awready),
    .i_axi_awaddr(wb_axil_awaddr),
    .i_axi_awprot(wb_axil_awprot),
    .i_axi_wvalid(wb_axil_w_valid),
    .o_axi_wready(wb_axil_w_ready),
    .i_axi_wdata(wb_axil_wdata),
    .i_axi_wstrb(wb_axil_wstrb),
    .o_axi_bvalid(wb_axil_bvalid),
    .i_axi_bready(wb_axil_bready),
    .o_axi_bresp(wb_axil_bresp),
    .i_axi_arvalid(wb_axil_arvalid),
    .o_axi_arready(wb_axil_arready),
    .i_axi_araddr(wb_axil_araddr),
    .i_axi_arprot(wb_axil_arprot),
    .o_axi_rvalid(wb_axil_rvalid),
    .i_axi_rready(wb_axil_rready),
    .o_axi_rdata(wb_axil_rdata),
    .o_axi_rresp(wb_axil_rresp),
    .o_reset(wb_reset),
    .o_wb_cyc(wb_cyc),
    .o_wb_stb(wb_stb),
    .o_wb_we(wb_we),
    .o_wb_addr(wb_addr),
    .o_wb_data(wb_wdata),
    .o_wb_sel(wb_sel),
    .i_wb_stall(1'b0),
    .i_wb_ack(wb_ack),
    .i_wb_data(wb_rdata),
    .i_wb_err(wb_err) );


  wb_island #(.P(P), .AW(30)) island (
    .clk(clk_i),
    .rst(~rst_ni),
    .m_adr_i(wb_addr),
    .m_dat_i(wb_wdata),
    .m_dat_o(wb_rdata),
    .m_sel_i(wb_sel),
    .m_we_i(wb_we),
    .m_cyc_i(wb_cyc),
    .m_stb_i(wb_stb),
    .m_ack_o(wb_ack),
    .m_err_o(wb_err),
    .uart_rx_i, .uart_tx_o, .uart_irq_o,
    .rmii_ref_clk(rmii_ref_clk_i),
    .rmii_crs_dv(rmii_crs_dv_i),
    .rmii_rx_data(rmii_rx_data_i),
    .rmii_tx_data(rmii_tx_data_o),
    .rmii_tx_en(rmii_tx_en_o),
    .rmii_mdc(rmii_mdc_o),
    .rmii_mdio(rmii_mdio_io),
    .rmii_rst_n(rmii_rst_n_o),
    .eth_irq(eth_irq_o) );

endmodule
