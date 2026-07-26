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

module cvwsoc_ram #(
    parameter cvwsoc_cfg_t C,
    parameter int unsigned CPU_AXI_ID_WIDTH = 2,
    parameter type ddr_axi_req_t = logic,
    parameter type ddr_axi_resp_t = logic,
    parameter type ddr_csr_axi_req_t = logic,
    parameter type ddr_csr_axi_resp_t = logic
  ) (
    input logic clk167_i, clk200_i, rst_req_i, resetn_comb_i,
    output logic BUSCLK_o, BUSCORERSTn_o, BUSRSTn_o,
    input ddr_axi_req_t ddr_axi_req_i,
    output ddr_axi_resp_t ddr_axi_resp_o,
    input ddr_csr_axi_req_t ddr_csr_axi_req_i,
    output ddr_csr_axi_resp_t ddr_csr_axi_resp_o,
    inout logic [((C.mem_type == CVWSOC_MEM_XILINX_DDR2 || C.mem_type == CVWSOC_MEM_LITEDRAM_NEXYSA7) ? 16 : 32)-1:0] ddr_dq,
    inout logic [((C.mem_type == CVWSOC_MEM_XILINX_DDR2 || C.mem_type == CVWSOC_MEM_LITEDRAM_NEXYSA7) ? 2 : 4)-1:0] ddr_dqs_n,
    inout logic [((C.mem_type == CVWSOC_MEM_XILINX_DDR2 || C.mem_type == CVWSOC_MEM_LITEDRAM_NEXYSA7) ? 2 : 4)-1:0] ddr_dqs_p,
    output logic [((C.mem_type == CVWSOC_MEM_XILINX_DDR2 || C.mem_type == CVWSOC_MEM_LITEDRAM_NEXYSA7) ? 13 : 15)-1:0] ddr_addr,
    output logic [2:0] ddr_ba,
    output logic ddr_ras_n, ddr_cas_n, ddr_we_n, ddr_reset_n,
    output logic [0:0] ddr_ck_p, ddr_ck_n, ddr_cke, ddr_cs_n,
    output logic [((C.mem_type == CVWSOC_MEM_XILINX_DDR2 || C.mem_type == CVWSOC_MEM_LITEDRAM_NEXYSA7) ? 2 : 4)-1:0] ddr_dm,
    output logic [0:0] ddr_odt
  );
  localparam cvw_t P = C.wally;
  localparam int unsigned ADDR_W = 32;
  localparam int unsigned DATA_W = P.AHBW;
  localparam int unsigned STRB_W = DATA_W / 8;
  localparam xbar_out_t XBAR_OUT = gen_xbar_out(P);
  localparam int unsigned MST_ID_W = CPU_AXI_ID_WIDTH + $clog2(XBAR_OUT.n_slv);
  localparam int unsigned DDR_ID_W = MST_ID_W;
  localparam int unsigned CB_M_DRAM_CSR = XBAR_OUT.m_dram_csr;
  logic BUSCLK, BUSRST, BUSRSTn, BUSCORERST, BUSCORERSTn;
  (* mark_debug = "true" *) logic c0_init_calib_complete, ddr_clk_locked, init_error;
  logic ddr_ready, ui_clk_sync_rst;
  logic app_sr_active, app_ref_ack, app_zq_ack;
  logic [11:0] device_temp;
  logic clk167, clk200, rst_req, resetn_comb;
  assign clk167 = clk167_i; assign clk200 = clk200_i;
  assign rst_req = rst_req_i; assign resetn_comb = resetn_comb_i;
  assign BUSCLK_o = BUSCLK; assign BUSCORERSTn_o = BUSCORERSTn; assign BUSRSTn_o = BUSRSTn;
  assign ddr_axi_resp_o.b.user = '0;
  assign ddr_axi_resp_o.r.user = '0;

  // Keep scalar aliases at the RAM boundary for the board-independent MIG
  // ILA constraint set.  The controller itself is inside a memory-type
  // generate branch, so its instance hierarchy differs between DDR2 and DDR3.
  (* mark_debug = "true" *) logic [MST_ID_W-1:0] ddr_axi_awid, ddr_axi_arid,
      ddr_axi_bid, ddr_axi_rid;
  (* mark_debug = "true" *) logic [31:0] ddr_axi_awaddr, ddr_axi_araddr;
  (* mark_debug = "true" *) logic [7:0] ddr_axi_awlen, ddr_axi_arlen;
  (* mark_debug = "true" *) logic [2:0] ddr_axi_awsize, ddr_axi_arsize;
  (* mark_debug = "true" *) logic [1:0] ddr_axi_awburst, ddr_axi_arburst;
  (* mark_debug = "true" *) logic ddr_axi_awvalid, ddr_axi_awready,
      ddr_axi_wvalid, ddr_axi_wready, ddr_axi_wlast,
      ddr_axi_bvalid, ddr_axi_bready, ddr_axi_arvalid, ddr_axi_arready,
      ddr_axi_rvalid, ddr_axi_rready, ddr_axi_rlast;
  (* mark_debug = "true" *) logic [DATA_W-1:0] ddr_axi_wdata, ddr_axi_rdata;
  (* mark_debug = "true" *) logic [STRB_W-1:0] ddr_axi_wstrb;

  assign ddr_axi_awid = ddr_axi_req_i.aw.id;
  assign ddr_axi_awaddr = ddr_axi_req_i.aw.addr;
  assign ddr_axi_awlen = ddr_axi_req_i.aw.len;
  assign ddr_axi_awsize = ddr_axi_req_i.aw.size;
  assign ddr_axi_awburst = ddr_axi_req_i.aw.burst;
  assign ddr_axi_awvalid = ddr_axi_req_i.aw_valid;
  assign ddr_axi_awready = ddr_axi_resp_o.aw_ready;
  assign ddr_axi_wdata = ddr_axi_req_i.w.data;
  assign ddr_axi_wstrb = ddr_axi_req_i.w.strb;
  assign ddr_axi_wlast = ddr_axi_req_i.w.last;
  assign ddr_axi_wvalid = ddr_axi_req_i.w_valid;
  assign ddr_axi_wready = ddr_axi_resp_o.w_ready;
  assign ddr_axi_bid = ddr_axi_resp_o.b.id;
  assign ddr_axi_bvalid = ddr_axi_resp_o.b_valid;
  assign ddr_axi_bready = ddr_axi_req_i.b_ready;
  assign ddr_axi_arid = ddr_axi_req_i.ar.id;
  assign ddr_axi_araddr = ddr_axi_req_i.ar.addr;
  assign ddr_axi_arlen = ddr_axi_req_i.ar.len;
  assign ddr_axi_arsize = ddr_axi_req_i.ar.size;
  assign ddr_axi_arburst = ddr_axi_req_i.ar.burst;
  assign ddr_axi_arvalid = ddr_axi_req_i.ar_valid;
  assign ddr_axi_arready = ddr_axi_resp_o.ar_ready;
  assign ddr_axi_rid = ddr_axi_resp_o.r.id;
  assign ddr_axi_rdata = ddr_axi_resp_o.r.data;
  assign ddr_axi_rlast = ddr_axi_resp_o.r.last;
  assign ddr_axi_rvalid = ddr_axi_resp_o.r_valid;
  assign ddr_axi_rready = ddr_axi_req_i.r_ready;
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

  assign BUSCORERST  = ~ddr_clk_locked; // deassert once BUSCLK is stable; ui_clk_sync_rst stays high through calibration
  assign BUSCORERSTn = ~BUSCORERST;

  assign BUSRST       = ui_clk_sync_rst | ~ddr_ready;
  assign BUSRSTn      = ~BUSRST;


  if (C.mem_type == CVWSOC_MEM_XILINX_DDR3) begin

    // no need to access DDR while not fully functional
    assign init_error = 1'b0;

    // No LiteDRAM CSR interface when using Xilinx MIG — tie M05 responses to 0

    // Xilinx DDR3 Controller
    ddr3 ddr
    (
      // ddr3 I/O
      .ddr3_dq(ddr_dq),
      .ddr3_dqs_n(ddr_dqs_n),
      .ddr3_dqs_p(ddr_dqs_p),
      .ddr3_addr(ddr_addr),
      .ddr3_ba(ddr_ba),
      .ddr3_ras_n(ddr_ras_n),
      .ddr3_cas_n(ddr_cas_n),
      .ddr3_we_n(ddr_we_n),
      .ddr3_reset_n(ddr_reset_n),
      .ddr3_ck_p(ddr_ck_p),
      .ddr3_ck_n(ddr_ck_n),
      .ddr3_cke(ddr_cke),
      .ddr3_cs_n(ddr_cs_n),
      .ddr3_dm(ddr_dm),
      .ddr3_odt(ddr_odt),

      .sys_clk_i(clk167),
      .clk_ref_i(clk200),

      .ui_clk(BUSCLK),
      .ui_clk_sync_rst(ui_clk_sync_rst),
      // FIXME: Is this OK?
      //.aresetn(resetn),
      .aresetn(resetn_comb),
      //.sys_rst(resetn),    // omg. this is active low?!?!??
      .sys_rst(resetn_comb),    // omg. this is active low?!?!??
      .mmcm_locked(ddr_clk_locked),

      .app_sr_req(1'b0),  // reserved command
      .app_ref_req(1'b0), // refresh command
      .app_zq_req(1'b0),  // recalibrate command
      .app_sr_active(app_sr_active), // reserved response
      .app_ref_ack(app_ref_ack),     // refresh ack
      .app_zq_ack(app_zq_ack),       // recalibrate ack

      // AXI (FROM CROSSBAR M00 -> MIG)
      .s_axi_awid(ddr_axi_req_i.aw.id),
      .s_axi_awaddr(ddr_axi_req_i.aw.addr[29:0]), // This width must match DDR size
      .s_axi_awlen(ddr_axi_req_i.aw.len),
      .s_axi_awsize(ddr_axi_req_i.aw.size),
      .s_axi_awburst(ddr_axi_req_i.aw.burst),
      .s_axi_awlock(ddr_axi_req_i.aw.lock),
      .s_axi_awcache(ddr_axi_req_i.aw.cache),
      .s_axi_awprot(ddr_axi_req_i.aw.prot),
      .s_axi_awqos(ddr_axi_req_i.aw.qos),
      .s_axi_awvalid(ddr_axi_req_i.aw_valid),
      .s_axi_awready(ddr_axi_resp_o.aw_ready),
      .s_axi_wdata(ddr_axi_req_i.w.data),
      .s_axi_wstrb(ddr_axi_req_i.w.strb),
      .s_axi_wlast(ddr_axi_req_i.w.last),
      .s_axi_wvalid(ddr_axi_req_i.w_valid),
      .s_axi_wready(ddr_axi_resp_o.w_ready),
      .s_axi_bready(ddr_axi_req_i.b_ready),
      .s_axi_bid(ddr_axi_resp_o.b.id),
      .s_axi_bresp(ddr_axi_resp_o.b.resp),
      .s_axi_bvalid(ddr_axi_resp_o.b_valid),
      .s_axi_arid(ddr_axi_req_i.ar.id),
      .s_axi_araddr(ddr_axi_req_i.ar.addr[29:0]), // This width must match DDR size
      .s_axi_arlen(ddr_axi_req_i.ar.len),
      .s_axi_arsize(ddr_axi_req_i.ar.size),
      .s_axi_arburst(ddr_axi_req_i.ar.burst),
      .s_axi_arlock(ddr_axi_req_i.ar.lock),
      .s_axi_arcache(ddr_axi_req_i.ar.cache),
      .s_axi_arprot(ddr_axi_req_i.ar.prot),
      .s_axi_arqos(ddr_axi_req_i.ar.qos),
      .s_axi_arvalid(ddr_axi_req_i.ar_valid),
      .s_axi_arready(ddr_axi_resp_o.ar_ready),
      .s_axi_rready(ddr_axi_req_i.r_ready),
      .s_axi_rlast(ddr_axi_resp_o.r.last),
      .s_axi_rvalid(ddr_axi_resp_o.r_valid),
      .s_axi_rresp(ddr_axi_resp_o.r.resp),
      .s_axi_rid(ddr_axi_resp_o.r.id),
      .s_axi_rdata(ddr_axi_resp_o.r.data),

      .init_calib_complete(c0_init_calib_complete),
      .device_temp(device_temp));
  end else if (C.mem_type == CVWSOC_MEM_XILINX_DDR2) begin

    assign init_error = 1'b0;

    ddr2 ddr (
      .ddr2_dq(ddr_dq),
      .ddr2_dqs_n(ddr_dqs_n),
      .ddr2_dqs_p(ddr_dqs_p),
      .ddr2_addr(ddr_addr),
      .ddr2_ba(ddr_ba),
      .ddr2_ras_n(ddr_ras_n),
      .ddr2_cas_n(ddr_cas_n),
      .ddr2_we_n(ddr_we_n),
      .ddr2_ck_p(ddr_ck_p),
      .ddr2_ck_n(ddr_ck_n),
      .ddr2_cke(ddr_cke),
      .ddr2_cs_n(ddr_cs_n),
      .ddr2_dm(ddr_dm),
      .ddr2_odt(ddr_odt),

      .sys_clk_i(clk200),
      .ui_clk(BUSCLK),
      .ui_clk_sync_rst(ui_clk_sync_rst),
      // The Nexys DDR2 MIG is generated with active-low SysResetPolarity.
      .aresetn(resetn_comb),
      .sys_rst(resetn_comb),
      .mmcm_locked(ddr_clk_locked),

      .app_sr_req(1'b0),
      .app_ref_req(1'b0),
      .app_zq_req(1'b0),
      .app_sr_active(app_sr_active),
      .app_ref_ack(app_ref_ack),
      .app_zq_ack(app_zq_ack),

      .s_axi_awid(ddr_axi_req_i.aw.id),
      .s_axi_awaddr(ddr_axi_req_i.aw.addr[26:0]),
      .s_axi_awlen(ddr_axi_req_i.aw.len),
      .s_axi_awsize(ddr_axi_req_i.aw.size),
      .s_axi_awburst(ddr_axi_req_i.aw.burst),
      .s_axi_awlock(ddr_axi_req_i.aw.lock),
      .s_axi_awcache(ddr_axi_req_i.aw.cache),
      .s_axi_awprot(ddr_axi_req_i.aw.prot),
      .s_axi_awqos(ddr_axi_req_i.aw.qos),
      .s_axi_awvalid(ddr_axi_req_i.aw_valid),
      .s_axi_awready(ddr_axi_resp_o.aw_ready),
      .s_axi_wdata(ddr_axi_req_i.w.data),
      .s_axi_wstrb(ddr_axi_req_i.w.strb),
      .s_axi_wlast(ddr_axi_req_i.w.last),
      .s_axi_wvalid(ddr_axi_req_i.w_valid),
      .s_axi_wready(ddr_axi_resp_o.w_ready),
      .s_axi_bready(ddr_axi_req_i.b_ready),
      .s_axi_bid(ddr_axi_resp_o.b.id),
      .s_axi_bresp(ddr_axi_resp_o.b.resp),
      .s_axi_bvalid(ddr_axi_resp_o.b_valid),
      .s_axi_arid(ddr_axi_req_i.ar.id),
      .s_axi_araddr(ddr_axi_req_i.ar.addr[26:0]),
      .s_axi_arlen(ddr_axi_req_i.ar.len),
      .s_axi_arsize(ddr_axi_req_i.ar.size),
      .s_axi_arburst(ddr_axi_req_i.ar.burst),
      .s_axi_arlock(ddr_axi_req_i.ar.lock),
      .s_axi_arcache(ddr_axi_req_i.ar.cache),
      .s_axi_arprot(ddr_axi_req_i.ar.prot),
      .s_axi_arqos(ddr_axi_req_i.ar.qos),
      .s_axi_arvalid(ddr_axi_req_i.ar_valid),
      .s_axi_arready(ddr_axi_resp_o.ar_ready),
      .s_axi_rready(ddr_axi_req_i.r_ready),
      .s_axi_rlast(ddr_axi_resp_o.r.last),
      .s_axi_rvalid(ddr_axi_resp_o.r_valid),
      .s_axi_rresp(ddr_axi_resp_o.r.resp),
      .s_axi_rid(ddr_axi_resp_o.r.id),
      .s_axi_rdata(ddr_axi_resp_o.r.data),
      .init_calib_complete(c0_init_calib_complete),
      .device_temp_i(12'd0)
    );
  //-------------------------------------------------------------------------------------

  end else if (C.mem_type == CVWSOC_MEM_LITEDRAM_NEXYSA7) begin : gen_litedram
    logic litedram_axi_awready, litedram_axi_wready, litedram_axi_arready;
    logic litedram_axi_bvalid, litedram_axi_rvalid, litedram_axi_rlast;
    logic [1:0] litedram_axi_bresp, litedram_axi_rresp;
    logic [MST_ID_W-1:0] litedram_axi_bid, litedram_axi_rid;
    logic [DATA_W-1:0] litedram_axi_rdata;

    assign ddr_csr_axi_resp_o.aw_ready = litedram_axi_awready;
    assign ddr_csr_axi_resp_o.w_ready  = litedram_axi_wready;
    assign ddr_csr_axi_resp_o.ar_ready = litedram_axi_arready;
    assign ddr_csr_axi_resp_o.b_valid  = litedram_axi_bvalid;
    assign ddr_csr_axi_resp_o.b.resp = litedram_axi_bresp;
    assign ddr_csr_axi_resp_o.b.id = litedram_axi_bid;
    assign ddr_csr_axi_resp_o.b.user = '0;
    assign ddr_csr_axi_resp_o.r_valid  = litedram_axi_rvalid;
    assign ddr_csr_axi_resp_o.r.last   = litedram_axi_rlast;
    assign ddr_csr_axi_resp_o.r.resp = litedram_axi_rresp;
    assign ddr_csr_axi_resp_o.r.id = litedram_axi_rid;
    assign ddr_csr_axi_resp_o.r.data = litedram_axi_rdata;
    assign ddr_csr_axi_resp_o.r.user = '0;

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


    logic   litedram_reset_unused;


    axi_mmio_to_axilite32_v3 #(
        .AXI_ADDR_WIDTH(ADDR_W),
        .AXI_DATA_WIDTH(DATA_W),
        .AXI_ID_WIDTH  (MST_ID_W)
    ) u_axi_to_axil_dram (
        .aclk          (BUSCLK),
        .aresetn(BUSCORERSTn),

        .s_axi_awid    (ddr_csr_axi_req_i.aw.id),
        .s_axi_awaddr  (ddr_csr_axi_req_i.aw.addr),
        .s_axi_awlen   (ddr_csr_axi_req_i.aw.len),
        .s_axi_awsize  (ddr_csr_axi_req_i.aw.size),
        .s_axi_awburst (ddr_csr_axi_req_i.aw.burst),
        .s_axi_awvalid (ddr_csr_axi_req_i.aw_valid),
        .s_axi_awready (litedram_axi_awready),

        .s_axi_wdata   (ddr_csr_axi_req_i.w.data),
        .s_axi_wstrb   (ddr_csr_axi_req_i.w.strb),
        .s_axi_wlast   (ddr_csr_axi_req_i.w.last),
        .s_axi_wvalid  (ddr_csr_axi_req_i.w_valid),
        .s_axi_wready  (litedram_axi_wready),

        .s_axi_bresp   (litedram_axi_bresp),
        .s_axi_bvalid  (litedram_axi_bvalid),
        .s_axi_bid     (litedram_axi_bid),
        .s_axi_bready  (ddr_csr_axi_req_i.b_ready),

        .s_axi_arid    (ddr_csr_axi_req_i.ar.id),
        .s_axi_araddr  (ddr_csr_axi_req_i.ar.addr),
        .s_axi_arlen   (ddr_csr_axi_req_i.ar.len),
        .s_axi_arsize  (ddr_csr_axi_req_i.ar.size),
        .s_axi_arburst (ddr_csr_axi_req_i.ar.burst),
        .s_axi_arvalid (ddr_csr_axi_req_i.ar_valid),
        .s_axi_arready (litedram_axi_arready),

        .s_axi_rdata   (litedram_axi_rdata),
        .s_axi_rresp   (litedram_axi_rresp),
        .s_axi_rlast   (litedram_axi_rlast),
        .s_axi_rvalid  (litedram_axi_rvalid),
        .s_axi_rid     (litedram_axi_rid),
        .s_axi_rready  (ddr_csr_axi_req_i.r_ready),

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

      litedram_nexysa7_w64 ddr(
        .clk      (clk200),          // external 200 MHz board clock
        .rst(rst_req),

        .ddram_a(ddr_addr), .ddram_ba(ddr_ba), .ddram_cas_n(ddr_cas_n),
        .ddram_cke(ddr_cke), .ddram_clk_n(ddr_ck_n), .ddram_clk_p(ddr_ck_p),
        .ddram_cs_n(ddr_cs_n), .ddram_dm(ddr_dm), .ddram_dq(ddr_dq),
        .ddram_dqs_n(ddr_dqs_n), .ddram_dqs_p(ddr_dqs_p), .ddram_odt(ddr_odt),
        .ddram_ras_n(ddr_ras_n), .ddram_reset_n(ddr_reset_n), .ddram_we_n(ddr_we_n),

        .init_done(c0_init_calib_complete),
        .init_error(init_error),
        .pll_locked(ddr_clk_locked),
        .user_clk (BUSCLK),
        .user_rst (ui_clk_sync_rst),

        //.user_port_axi_0_araddr(ddr_axi_req_i.ar.addr[29:0]),
        .user_port_axi_0_araddr(ddr_axi_req_i.ar.addr[26:0]),
        .user_port_axi_0_arburst(ddr_axi_req_i.ar.burst),
        .user_port_axi_0_arid(ddr_axi_req_i.ar.id),
        .user_port_axi_0_arlen(ddr_axi_req_i.ar.len),
        .user_port_axi_0_arready(ddr_axi_resp_o.ar_ready),
        .user_port_axi_0_arsize(ddr_axi_req_i.ar.size),
        .user_port_axi_0_arvalid(ddr_axi_req_i.ar_valid),
        //.user_port_axi_0_awaddr(ddr_axi_req_i.aw.addr[29:0]),
        .user_port_axi_0_awaddr(ddr_axi_req_i.aw.addr[26:0]),
        .user_port_axi_0_awburst(ddr_axi_req_i.aw.burst),
        .user_port_axi_0_awid(ddr_axi_req_i.aw.id),
        .user_port_axi_0_awlen(ddr_axi_req_i.aw.len),
        .user_port_axi_0_awready(ddr_axi_resp_o.aw_ready),
        .user_port_axi_0_awsize(ddr_axi_req_i.aw.size),
        .user_port_axi_0_awvalid(ddr_axi_req_i.aw_valid),
        .user_port_axi_0_bid(ddr_axi_resp_o.b.id),
        .user_port_axi_0_bready(ddr_axi_req_i.b_ready),
        .user_port_axi_0_bresp(ddr_axi_resp_o.b.resp),
        .user_port_axi_0_bvalid(ddr_axi_resp_o.b_valid),
        .user_port_axi_0_rdata(ddr_axi_resp_o.r.data),
        .user_port_axi_0_rid(ddr_axi_resp_o.r.id),
        .user_port_axi_0_rlast(ddr_axi_resp_o.r.last),
        .user_port_axi_0_rready(ddr_axi_req_i.r_ready),
        .user_port_axi_0_rresp(ddr_axi_resp_o.r.resp),
        .user_port_axi_0_rvalid(ddr_axi_resp_o.r_valid),
        .user_port_axi_0_wdata(ddr_axi_req_i.w.data),
        .user_port_axi_0_wlast(ddr_axi_req_i.w.last),
        .user_port_axi_0_wready(ddr_axi_resp_o.w_ready),
        .user_port_axi_0_wstrb(ddr_axi_req_i.w.strb),
        .user_port_axi_0_wvalid(ddr_axi_req_i.w_valid),

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
      litedram_nexysa7_w32 ddr(
        .clk      (clk200),          // external 200 MHz board clock
        .rst(rst_req),

        .ddram_a(ddr_addr), .ddram_ba(ddr_ba), .ddram_cas_n(ddr_cas_n),
        .ddram_cke(ddr_cke), .ddram_clk_n(ddr_ck_n), .ddram_clk_p(ddr_ck_p),
        .ddram_cs_n(ddr_cs_n), .ddram_dm(ddr_dm), .ddram_dq(ddr_dq),
        .ddram_dqs_n(ddr_dqs_n), .ddram_dqs_p(ddr_dqs_p), .ddram_odt(ddr_odt),
        .ddram_ras_n(ddr_ras_n), .ddram_reset_n(ddr_reset_n), .ddram_we_n(ddr_we_n),

        .init_done(c0_init_calib_complete),
        .init_error(init_error),
        .pll_locked(ddr_clk_locked),
        .user_clk (BUSCLK),
        .user_rst (ui_clk_sync_rst),

        //.user_port_axi_0_araddr(ddr_axi_req_i.ar.addr[29:0]),
        .user_port_axi_0_araddr(ddr_axi_req_i.ar.addr[26:0]),
        .user_port_axi_0_arburst(ddr_axi_req_i.ar.burst),
        .user_port_axi_0_arid(ddr_axi_req_i.ar.id),
        .user_port_axi_0_arlen(ddr_axi_req_i.ar.len),
        .user_port_axi_0_arready(ddr_axi_resp_o.ar_ready),
        .user_port_axi_0_arsize(ddr_axi_req_i.ar.size),
        .user_port_axi_0_arvalid(ddr_axi_req_i.ar_valid),
        //.user_port_axi_0_awaddr(ddr_axi_req_i.aw.addr[29:0]),
        .user_port_axi_0_awaddr(ddr_axi_req_i.aw.addr[26:0]),
        .user_port_axi_0_awburst(ddr_axi_req_i.aw.burst),
        .user_port_axi_0_awid(ddr_axi_req_i.aw.id),
        .user_port_axi_0_awlen(ddr_axi_req_i.aw.len),
        .user_port_axi_0_awready(ddr_axi_resp_o.aw_ready),
        .user_port_axi_0_awsize(ddr_axi_req_i.aw.size),
        .user_port_axi_0_awvalid(ddr_axi_req_i.aw_valid),
        .user_port_axi_0_bid(ddr_axi_resp_o.b.id),
        .user_port_axi_0_bready(ddr_axi_req_i.b_ready),
        .user_port_axi_0_bresp(ddr_axi_resp_o.b.resp),
        .user_port_axi_0_bvalid(ddr_axi_resp_o.b_valid),
        .user_port_axi_0_rdata(ddr_axi_resp_o.r.data),
        .user_port_axi_0_rid(ddr_axi_resp_o.r.id),
        .user_port_axi_0_rlast(ddr_axi_resp_o.r.last),
        .user_port_axi_0_rready(ddr_axi_req_i.r_ready),
        .user_port_axi_0_rresp(ddr_axi_resp_o.r.resp),
        .user_port_axi_0_rvalid(ddr_axi_resp_o.r_valid),
        .user_port_axi_0_wdata(ddr_axi_req_i.w.data),
        .user_port_axi_0_wlast(ddr_axi_req_i.w.last),
        .user_port_axi_0_wready(ddr_axi_resp_o.w_ready),
        .user_port_axi_0_wstrb(ddr_axi_req_i.w.strb),
        .user_port_axi_0_wvalid(ddr_axi_req_i.w_valid),

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

  //-------------------------------------------------------------------------------------
  end else if (C.mem_type == CVWSOC_MEM_LITEDRAM_GENESYS2) begin : gen_litedram
    logic litedram_axi_awready, litedram_axi_wready, litedram_axi_arready;
    logic litedram_axi_bvalid, litedram_axi_rvalid, litedram_axi_rlast;
    logic [1:0] litedram_axi_bresp, litedram_axi_rresp;
    logic [MST_ID_W-1:0] litedram_axi_bid, litedram_axi_rid;
    logic [DATA_W-1:0] litedram_axi_rdata;

    assign ddr_csr_axi_resp_o.aw_ready = litedram_axi_awready;
    assign ddr_csr_axi_resp_o.w_ready  = litedram_axi_wready;
    assign ddr_csr_axi_resp_o.ar_ready = litedram_axi_arready;
    assign ddr_csr_axi_resp_o.b_valid  = litedram_axi_bvalid;
    assign ddr_csr_axi_resp_o.b.resp = litedram_axi_bresp;
    assign ddr_csr_axi_resp_o.b.id = litedram_axi_bid;
    assign ddr_csr_axi_resp_o.b.user = '0;
    assign ddr_csr_axi_resp_o.r_valid  = litedram_axi_rvalid;
    assign ddr_csr_axi_resp_o.r.last   = litedram_axi_rlast;
    assign ddr_csr_axi_resp_o.r.resp = litedram_axi_rresp;
    assign ddr_csr_axi_resp_o.r.id = litedram_axi_rid;
    assign ddr_csr_axi_resp_o.r.data = litedram_axi_rdata;
    assign ddr_csr_axi_resp_o.r.user = '0;

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


    logic   litedram_reset_unused;


    axi_mmio_to_axilite32_v3 #(
        .AXI_ADDR_WIDTH(ADDR_W),
        .AXI_DATA_WIDTH(DATA_W),
        .AXI_ID_WIDTH  (MST_ID_W)
    ) u_axi_to_axil_dram (
        .aclk          (BUSCLK),
        .aresetn(BUSCORERSTn),

        .s_axi_awid    (ddr_csr_axi_req_i.aw.id),
        .s_axi_awaddr  (ddr_csr_axi_req_i.aw.addr),
        .s_axi_awlen   (ddr_csr_axi_req_i.aw.len),
        .s_axi_awsize  (ddr_csr_axi_req_i.aw.size),
        .s_axi_awburst (ddr_csr_axi_req_i.aw.burst),
        .s_axi_awvalid (ddr_csr_axi_req_i.aw_valid),
        .s_axi_awready (litedram_axi_awready),

        .s_axi_wdata   (ddr_csr_axi_req_i.w.data),
        .s_axi_wstrb   (ddr_csr_axi_req_i.w.strb),
        .s_axi_wlast   (ddr_csr_axi_req_i.w.last),
        .s_axi_wvalid  (ddr_csr_axi_req_i.w_valid),
        .s_axi_wready  (litedram_axi_wready),

        .s_axi_bresp   (litedram_axi_bresp),
        .s_axi_bvalid  (litedram_axi_bvalid),
        .s_axi_bid     (litedram_axi_bid),
        .s_axi_bready  (ddr_csr_axi_req_i.b_ready),

        .s_axi_arid    (ddr_csr_axi_req_i.ar.id),
        .s_axi_araddr  (ddr_csr_axi_req_i.ar.addr),
        .s_axi_arlen   (ddr_csr_axi_req_i.ar.len),
        .s_axi_arsize  (ddr_csr_axi_req_i.ar.size),
        .s_axi_arburst (ddr_csr_axi_req_i.ar.burst),
        .s_axi_arvalid (ddr_csr_axi_req_i.ar_valid),
        .s_axi_arready (litedram_axi_arready),

        .s_axi_rdata   (litedram_axi_rdata),
        .s_axi_rresp   (litedram_axi_rresp),
        .s_axi_rlast   (litedram_axi_rlast),
        .s_axi_rvalid  (litedram_axi_rvalid),
        .s_axi_rid     (litedram_axi_rid),
        .s_axi_rready  (ddr_csr_axi_req_i.r_ready),

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
        litedram_genesys2 ddr(
        .clk      (clk200),          // external 200 MHz board clock
        .rst(rst_req),

        .ddram_a(ddr_addr), .ddram_ba(ddr_ba), .ddram_cas_n(ddr_cas_n),
        .ddram_cke(ddr_cke), .ddram_clk_n(ddr_ck_n), .ddram_clk_p(ddr_ck_p),
        .ddram_cs_n(ddr_cs_n), .ddram_dm(ddr_dm), .ddram_dq(ddr_dq),
        .ddram_dqs_n(ddr_dqs_n), .ddram_dqs_p(ddr_dqs_p), .ddram_odt(ddr_odt),
        .ddram_ras_n(ddr_ras_n), .ddram_reset_n(ddr_reset_n), .ddram_we_n(ddr_we_n),

        .init_done(c0_init_calib_complete),
        .init_error(init_error),
        .pll_locked(ddr_clk_locked),
        .user_clk (BUSCLK),
        .user_rst (ui_clk_sync_rst),

        .user_port_axi_0_araddr(ddr_axi_req_i.ar.addr[29:0]),
        .user_port_axi_0_arburst(ddr_axi_req_i.ar.burst),
        .user_port_axi_0_arid(ddr_axi_req_i.ar.id),
        .user_port_axi_0_arlen(ddr_axi_req_i.ar.len),
        .user_port_axi_0_arready(ddr_axi_resp_o.ar_ready),
        .user_port_axi_0_arsize(ddr_axi_req_i.ar.size),
        .user_port_axi_0_arvalid(ddr_axi_req_i.ar_valid),
        .user_port_axi_0_awaddr(ddr_axi_req_i.aw.addr[29:0]),
        .user_port_axi_0_awburst(ddr_axi_req_i.aw.burst),
        .user_port_axi_0_awid(ddr_axi_req_i.aw.id),
        .user_port_axi_0_awlen(ddr_axi_req_i.aw.len),
        .user_port_axi_0_awready(ddr_axi_resp_o.aw_ready),
        .user_port_axi_0_awsize(ddr_axi_req_i.aw.size),
        .user_port_axi_0_awvalid(ddr_axi_req_i.aw_valid),
        .user_port_axi_0_bid(ddr_axi_resp_o.b.id),
        .user_port_axi_0_bready(ddr_axi_req_i.b_ready),
        .user_port_axi_0_bresp(ddr_axi_resp_o.b.resp),
        .user_port_axi_0_bvalid(ddr_axi_resp_o.b_valid),
        .user_port_axi_0_rdata(ddr_axi_resp_o.r.data),
        .user_port_axi_0_rid(ddr_axi_resp_o.r.id),
        .user_port_axi_0_rlast(ddr_axi_resp_o.r.last),
        .user_port_axi_0_rready(ddr_axi_req_i.r_ready),
        .user_port_axi_0_rresp(ddr_axi_resp_o.r.resp),
        .user_port_axi_0_rvalid(ddr_axi_resp_o.r_valid),
        .user_port_axi_0_wdata(ddr_axi_req_i.w.data),
        .user_port_axi_0_wlast(ddr_axi_req_i.w.last),
        .user_port_axi_0_wready(ddr_axi_resp_o.w_ready),
        .user_port_axi_0_wstrb(ddr_axi_req_i.w.strb),
        .user_port_axi_0_wvalid(ddr_axi_req_i.w_valid),

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
      litedram_genesys2w32 ddr(
        .clk      (clk200),
        .rst      (rst_req),

        .ddram_a(ddr_addr), .ddram_ba(ddr_ba), .ddram_cas_n(ddr_cas_n),
        .ddram_cke(ddr_cke), .ddram_clk_n(ddr_ck_n), .ddram_clk_p(ddr_ck_p),
        .ddram_cs_n(ddr_cs_n), .ddram_dm(ddr_dm), .ddram_dq(ddr_dq),
        .ddram_dqs_n(ddr_dqs_n), .ddram_dqs_p(ddr_dqs_p), .ddram_odt(ddr_odt),
        .ddram_ras_n(ddr_ras_n), .ddram_reset_n(ddr_reset_n), .ddram_we_n(ddr_we_n),

        .init_done(c0_init_calib_complete),
        .init_error(init_error),
        .pll_locked(ddr_clk_locked),
        .user_clk(BUSCLK),
        .user_rst(ui_clk_sync_rst),

        .user_port_axi_0_araddr(ddr_axi_req_i.ar.addr[29:0]),
        .user_port_axi_0_arburst(ddr_axi_req_i.ar.burst),
        .user_port_axi_0_arid(ddr_axi_req_i.ar.id),
        .user_port_axi_0_arlen(ddr_axi_req_i.ar.len),
        .user_port_axi_0_arready(ddr_axi_resp_o.ar_ready),
        .user_port_axi_0_arsize(ddr_axi_req_i.ar.size),
        .user_port_axi_0_arvalid(ddr_axi_req_i.ar_valid),
        .user_port_axi_0_awaddr(ddr_axi_req_i.aw.addr[29:0]),
        .user_port_axi_0_awburst(ddr_axi_req_i.aw.burst),
        .user_port_axi_0_awid(ddr_axi_req_i.aw.id),
        .user_port_axi_0_awlen(ddr_axi_req_i.aw.len),
        .user_port_axi_0_awready(ddr_axi_resp_o.aw_ready),
        .user_port_axi_0_awsize(ddr_axi_req_i.aw.size),
        .user_port_axi_0_awvalid(ddr_axi_req_i.aw_valid),
        .user_port_axi_0_bid(ddr_axi_resp_o.b.id),
        .user_port_axi_0_bready(ddr_axi_req_i.b_ready),
        .user_port_axi_0_bresp(ddr_axi_resp_o.b.resp),
        .user_port_axi_0_bvalid(ddr_axi_resp_o.b_valid),
        .user_port_axi_0_rdata(ddr_axi_resp_o.r.data),
        .user_port_axi_0_rid(ddr_axi_resp_o.r.id),
        .user_port_axi_0_rlast(ddr_axi_resp_o.r.last),
        .user_port_axi_0_rready(ddr_axi_req_i.r_ready),
        .user_port_axi_0_rresp(ddr_axi_resp_o.r.resp),
        .user_port_axi_0_rvalid(ddr_axi_resp_o.r_valid),
        .user_port_axi_0_wdata(ddr_axi_req_i.w.data),
        .user_port_axi_0_wlast(ddr_axi_req_i.w.last),
        .user_port_axi_0_wready(ddr_axi_resp_o.w_ready),
        .user_port_axi_0_wstrb(ddr_axi_req_i.w.strb),
        .user_port_axi_0_wvalid(ddr_axi_req_i.w_valid),

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
  end else begin : gen_uberddr3

    logic dummy_rstn;
    logic dummy_clk200;
    assign init_error = 1'b0;

    // No LiteDRAM CSR interface

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
        .o_pll_locked(ddr_clk_locked),
        .o_init_calib_complete(c0_init_calib_complete),

        // AXI slave interface (SoC side, kept MIG/LiteDRAM-like)
        .i_s_axi_awid(ddr_axi_req_i.aw.id),
        .i_s_axi_awaddr(ddr_axi_req_i.aw.addr),
        .i_s_axi_awlen(ddr_axi_req_i.aw.len),
        .i_s_axi_awsize(ddr_axi_req_i.aw.size),
        .i_s_axi_awburst(ddr_axi_req_i.aw.burst),
        .i_s_axi_awlock(ddr_axi_req_i.aw.lock),
        .i_s_axi_awcache(ddr_axi_req_i.aw.cache),
        .i_s_axi_awprot(ddr_axi_req_i.aw.prot),
        .i_s_axi_awqos(ddr_axi_req_i.aw.qos),
        .i_s_axi_awvalid(ddr_axi_req_i.aw_valid),
        .o_s_axi_awready(ddr_axi_resp_o.aw_ready),

        .i_s_axi_wdata(ddr_axi_req_i.w.data),
        .i_s_axi_wstrb(ddr_axi_req_i.w.strb),
        .i_s_axi_wlast(ddr_axi_req_i.w.last),
        .i_s_axi_wvalid(ddr_axi_req_i.w_valid),
        .o_s_axi_wready(ddr_axi_resp_o.w_ready),

        .o_s_axi_bid(ddr_axi_resp_o.b.id),
        .o_s_axi_bresp(ddr_axi_resp_o.b.resp),
        .o_s_axi_bvalid(ddr_axi_resp_o.b_valid),
        .i_s_axi_bready(ddr_axi_req_i.b_ready),

        .i_s_axi_arid(ddr_axi_req_i.ar.id),
        .i_s_axi_araddr(ddr_axi_req_i.ar.addr),
        .i_s_axi_arlen(ddr_axi_req_i.ar.len),
        .i_s_axi_arsize(ddr_axi_req_i.ar.size),
        .i_s_axi_arburst(ddr_axi_req_i.ar.burst),
        .i_s_axi_arlock(ddr_axi_req_i.ar.lock),
        .i_s_axi_arcache(ddr_axi_req_i.ar.cache),
        .i_s_axi_arprot(ddr_axi_req_i.ar.prot),
        .i_s_axi_arqos(ddr_axi_req_i.ar.qos),
        .i_s_axi_arvalid(ddr_axi_req_i.ar_valid),
        .o_s_axi_arready(ddr_axi_resp_o.ar_ready),

        .o_s_axi_rid(ddr_axi_resp_o.r.id),
        .o_s_axi_rdata(ddr_axi_resp_o.r.data),
        .o_s_axi_rresp(ddr_axi_resp_o.r.resp),
        .o_s_axi_rlast(ddr_axi_resp_o.r.last),
        .o_s_axi_rvalid(ddr_axi_resp_o.r_valid),
        .i_s_axi_rready(ddr_axi_req_i.r_ready),

        // DDR3 pins
        .io_ddr3_dq(ddr_dq), .io_ddr3_dqs_n(ddr_dqs_n),
        .io_ddr3_dqs_p(ddr_dqs_p), .o_ddr3_addr(ddr_addr),
        .o_ddr3_ba(ddr_ba), .o_ddr3_ras_n(ddr_ras_n),
        .o_ddr3_cas_n(ddr_cas_n), .o_ddr3_we_n(ddr_we_n),
        .o_ddr3_reset_n(ddr_reset_n), .o_ddr3_ck_p(ddr_ck_p),
        .o_ddr3_ck_n(ddr_ck_n), .o_ddr3_cke(ddr_cke),
        .o_ddr3_cs_n(ddr_cs_n), .o_ddr3_dm(ddr_dm), .o_ddr3_odt(ddr_odt)
    );

  end


endmodule
