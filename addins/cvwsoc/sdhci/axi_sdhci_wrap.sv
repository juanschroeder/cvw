`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

// Uncomment to use the same conservative MMIO bridge for AXI32 and AXI64.
`define SDHCI_USE_SAME_AXIL_ADAPTER

// axi_shdci_wrap.sv
import sdhci_regbus_pkg::*;
import sdhci_reg_pkg::*;
import axi_sdhci_wrap_pkg::*;

// axi_sdhci_wrap.sv
`timescale 1ns/1ps

module axi_sdhci_wrap #(
  parameter int unsigned AXI_ADDR_W  = 32,
  parameter int unsigned AXI_DATA_W  = 64,
  parameter int unsigned AXI_ID_W    = 4,
  parameter int unsigned AXI_USER_W  = 1,
  parameter bit          InsertRegClkBuf = 1'b0
) (
  input  logic        aclk,
  input  logic        aresetn,

  // ----------------------------
  // AXI SLAVE (regs) from xbar M02
  // ----------------------------
  input  logic [AXI_ID_W-1:0]   s_axi_awid,
  input  logic [AXI_ADDR_W-1:0] s_axi_awaddr,
  input  logic [7:0]  s_axi_awlen,
  input  logic [2:0]  s_axi_awsize,
  input  logic [1:0]  s_axi_awburst,
  input  logic        s_axi_awlock,
  input  logic [3:0]  s_axi_awcache,
  input  logic [2:0]  s_axi_awprot,
  input  logic [3:0]  s_axi_awqos,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,

  input  logic [AXI_DATA_W-1:0]   s_axi_wdata,
  input  logic [AXI_DATA_W/8-1:0] s_axi_wstrb,
  input  logic        s_axi_wlast,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,

  output logic [AXI_ID_W-1:0] s_axi_bid,
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,

  input  logic [AXI_ID_W-1:0]   s_axi_arid,
  input  logic [AXI_ADDR_W-1:0] s_axi_araddr,
  input  logic [7:0]  s_axi_arlen,
  input  logic [2:0]  s_axi_arsize,
  input  logic [1:0]  s_axi_arburst,
  input  logic        s_axi_arlock,
  input  logic [3:0]  s_axi_arcache,
  input  logic [2:0]  s_axi_arprot,
  input  logic [3:0]  s_axi_arqos,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,

  output logic [AXI_ID_W-1:0]     s_axi_rid,
  output logic [AXI_DATA_W-1:0]   s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rlast,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready,

  // SDHCI pins
  output logic       sd_clk_o,
  input  logic       sd_cd_ni,
  output logic       sd_cmd_en_o,
  output logic       sd_cmd_o,
  input  logic       sd_cmd_i,

  input  logic [3:0] sd_dat_i,
  output logic [3:0] sd_dat_o,
  output logic       sd_dat_en_o,

  output logic interrupt_o
);

  // ----------------------------
  // Types
  // ----------------------------
  import axi_pkg::*;
  `include "axi/typedef.svh"
  `include "register_interface/typedef.svh"

  localparam int unsigned AXIL_DATA_W = 32;

  typedef logic [AXI_ADDR_W-1:0] axi_addr_t;
  typedef logic [AXI_DATA_W-1:0] axi_data_t;
  typedef logic [AXI_DATA_W/8-1:0] axi_strb_t;
  typedef logic [AXI_ID_W-1:0]   axi_id_t;
  typedef logic [AXI_USER_W-1:0] axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T (w_chan_t,  axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T (b_chan_t,  axi_id_t,   axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T (r_chan_t,  axi_data_t, axi_id_t, axi_user_t)

  `AXI_TYPEDEF_REQ_T (axi_req_t,  aw_chan_t, w_chan_t, ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_resp_t, b_chan_t,  r_chan_t)

  // ----------------------------
  // Types: AXI-Lite32 and regbus
  // ----------------------------
  typedef logic [AXIL_DATA_W-1:0] axil_data_t;
  typedef logic [AXIL_DATA_W/8-1:0] axil_strb_t;
  `AXI_LITE_TYPEDEF_ALL_CT(axil, axil_req_t, axil_rsp_t, axi_addr_t, axil_data_t, axil_strb_t)

  typedef logic [31:0] reg_addr_t;
  typedef logic [31:0] reg_data_t;
  typedef logic [3:0]  reg_strb_t;

  if ((AXI_DATA_W != 32) && (AXI_DATA_W != 64)) begin : gen_bad_axi_width
    initial $fatal(1, "axi_sdhci_wrap supports AXI_DATA_W 32 or 64, got %0d", AXI_DATA_W);
  end

  // ----------------------------
  // AXI -> AXI-Lite32 -> regbus
  // ----------------------------
  axil_req_t axil_req;
  axil_rsp_t axil_rsp;

  reg_req_t  reg_req;
  reg_resp_t reg_rsp;
    logic        dbg_reg_req_valid;
    logic        dbg_reg_req_write;
    logic [11:0] dbg_reg_req_addr;
    logic [31:0] dbg_reg_req_wdata;
    logic [3:0]  dbg_reg_req_wstrb;

    logic        dbg_reg_rsp_ready;
    logic        dbg_reg_rsp_error;
    logic [31:0] dbg_reg_rsp_rdata;

    always_comb begin
        dbg_reg_req_valid = reg_req.valid;
        dbg_reg_req_write = reg_req.write;
        dbg_reg_req_addr  = reg_req.addr[11:0];
        dbg_reg_req_wdata  = reg_req.wdata;
        dbg_reg_req_wstrb  = reg_req.wstrb;

        dbg_reg_rsp_ready = reg_rsp.ready;
        dbg_reg_rsp_error = reg_rsp.error;
        dbg_reg_rsp_rdata = reg_rsp.rdata;
    end

`ifdef SDHCI_USE_SAME_AXIL_ADAPTER
    axi_mmio_to_axilite32_v3 #(
      .AXI_ADDR_WIDTH ( AXI_ADDR_W    ),
      .AXI_DATA_WIDTH ( AXI_DATA_W    ),
      .AXI_ID_WIDTH   ( AXI_ID_W      )
    ) i_axi_to_axilite32 (
      .aclk    ( aclk    ),
      .aresetn ( aresetn ),

      .s_axi_awid    ( s_axi_awid    ),
      .s_axi_awaddr  ( s_axi_awaddr  ),
      .s_axi_awlen   ( s_axi_awlen   ),
      .s_axi_awsize  ( s_axi_awsize  ),
      .s_axi_awburst ( s_axi_awburst ),
      .s_axi_awvalid ( s_axi_awvalid ),
      .s_axi_awready ( s_axi_awready ),

      .s_axi_wdata  ( s_axi_wdata  ),
      .s_axi_wstrb  ( s_axi_wstrb  ),
      .s_axi_wlast  ( s_axi_wlast  ),
      .s_axi_wvalid ( s_axi_wvalid ),
      .s_axi_wready ( s_axi_wready ),

      .s_axi_bresp  ( s_axi_bresp  ),
      .s_axi_bvalid ( s_axi_bvalid ),
      .s_axi_bid    ( s_axi_bid    ),
      .s_axi_bready ( s_axi_bready ),

      .s_axi_arid    ( s_axi_arid    ),
      .s_axi_araddr  ( s_axi_araddr  ),
      .s_axi_arlen   ( s_axi_arlen   ),
      .s_axi_arsize  ( s_axi_arsize  ),
      .s_axi_arburst ( s_axi_arburst ),
      .s_axi_arvalid ( s_axi_arvalid ),
      .s_axi_arready ( s_axi_arready ),

      .s_axi_rdata  ( s_axi_rdata  ),
      .s_axi_rresp  ( s_axi_rresp  ),
      .s_axi_rlast  ( s_axi_rlast  ),
      .s_axi_rvalid ( s_axi_rvalid ),
      .s_axi_rid    ( s_axi_rid    ),
      .s_axi_rready ( s_axi_rready ),

      .m_axil_awaddr  ( axil_req.aw.addr  ),
      .m_axil_awprot  ( axil_req.aw.prot  ),
      .m_axil_awvalid ( axil_req.aw_valid ),
      .m_axil_awready ( axil_rsp.aw_ready ),

      .m_axil_wdata  ( axil_req.w.data  ),
      .m_axil_wstrb  ( axil_req.w.strb  ),
      .m_axil_wvalid ( axil_req.w_valid ),
      .m_axil_wready ( axil_rsp.w_ready ),

      .m_axil_bresp  ( axil_rsp.b.resp  ),
      .m_axil_bvalid ( axil_rsp.b_valid ),
      .m_axil_bready ( axil_req.b_ready ),

      .m_axil_araddr  ( axil_req.ar.addr  ),
      .m_axil_arprot  ( axil_req.ar.prot  ),
      .m_axil_arvalid ( axil_req.ar_valid ),
      .m_axil_arready ( axil_rsp.ar_ready ),

      .m_axil_rdata  ( axil_rsp.r.data  ),
      .m_axil_rresp  ( axil_rsp.r.resp  ),
      .m_axil_rvalid ( axil_rsp.r_valid ),
      .m_axil_rready ( axil_req.r_ready )
    );
`else
    if (AXI_DATA_W == 32) begin : gen_axi32_to_axilite32
      axi_req_t  axi_req;
      axi_resp_t axi_resp;

      always_comb begin
        axi_req = '0;

        axi_req.aw_valid   = s_axi_awvalid;
        axi_req.aw.id      = s_axi_awid;
        axi_req.aw.addr    = s_axi_awaddr;
        axi_req.aw.len     = s_axi_awlen;
        axi_req.aw.size    = s_axi_awsize;
        axi_req.aw.burst   = s_axi_awburst;
        axi_req.aw.lock    = s_axi_awlock;
        axi_req.aw.cache   = s_axi_awcache;
        axi_req.aw.prot    = s_axi_awprot;
        axi_req.aw.qos     = s_axi_awqos;
        axi_req.aw.region  = '0;
        axi_req.aw.atop    = '0;
        axi_req.aw.user    = '0;

        axi_req.w_valid    = s_axi_wvalid;
        axi_req.w.data     = s_axi_wdata;
        axi_req.w.strb     = s_axi_wstrb;
        axi_req.w.last     = s_axi_wlast;
        axi_req.w.user     = '0;

        axi_req.b_ready    = s_axi_bready;

        axi_req.ar_valid   = s_axi_arvalid;
        axi_req.ar.id      = s_axi_arid;
        axi_req.ar.addr    = s_axi_araddr;
        axi_req.ar.len     = s_axi_arlen;
        axi_req.ar.size    = s_axi_arsize;
        axi_req.ar.burst   = s_axi_arburst;
        axi_req.ar.lock    = s_axi_arlock;
        axi_req.ar.cache   = s_axi_arcache;
        axi_req.ar.prot    = s_axi_arprot;
        axi_req.ar.qos     = s_axi_arqos;
        axi_req.ar.region  = '0;
        axi_req.ar.user    = '0;

        axi_req.r_ready    = s_axi_rready;
      end

      always_comb begin
        s_axi_awready = axi_resp.aw_ready;
        s_axi_wready  = axi_resp.w_ready;
        s_axi_bvalid  = axi_resp.b_valid;
        s_axi_bresp   = axi_resp.b.resp;
        s_axi_bid     = axi_resp.b.id;
        s_axi_arready = axi_resp.ar_ready;
        s_axi_rvalid  = axi_resp.r_valid;
        s_axi_rdata   = axi_resp.r.data;
        s_axi_rresp   = axi_resp.r.resp;
        s_axi_rlast   = axi_resp.r.last;
        s_axi_rid     = axi_resp.r.id;
      end

      axi_to_axi_lite #(
        .AxiAddrWidth    ( AXI_ADDR_W  ),
        .AxiDataWidth    ( AXI_DATA_W  ),
        .AxiIdWidth      ( AXI_ID_W    ),
        .AxiUserWidth    ( AXI_USER_W  ),
        .AxiMaxWriteTxns ( 2           ),
        .AxiMaxReadTxns  ( 2           ),
        .FallThrough     ( 1'b0        ),
        .full_req_t      ( axi_req_t   ),
        .full_resp_t     ( axi_resp_t  ),
        .lite_req_t      ( axil_req_t  ),
        .lite_resp_t     ( axil_rsp_t  )
      ) i_axi_to_axilite32 (
        .clk_i      ( aclk     ),
        .rst_ni     ( aresetn  ),
        .test_i     ( 1'b0     ),
        .slv_req_i  ( axi_req  ),
        .slv_resp_o ( axi_resp ),
        .mst_req_o  ( axil_req ),
        .mst_resp_i ( axil_rsp )
      );
    end else begin : gen_axi64_to_axilite32
      axi_mmio_to_axilite32_v3 #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_W ),
        .AXI_DATA_WIDTH ( AXI_DATA_W ),
        .AXI_ID_WIDTH   ( AXI_ID_W   )
      ) i_axi64_to_axilite32 (
        .aclk    ( aclk    ),
        .aresetn ( aresetn ),

        .s_axi_awid    ( s_axi_awid    ),
        .s_axi_awaddr  ( s_axi_awaddr  ),
        .s_axi_awlen   ( s_axi_awlen   ),
        .s_axi_awsize  ( s_axi_awsize  ),
        .s_axi_awburst ( s_axi_awburst ),
        .s_axi_awvalid ( s_axi_awvalid ),
        .s_axi_awready ( s_axi_awready ),

        .s_axi_wdata  ( s_axi_wdata  ),
        .s_axi_wstrb  ( s_axi_wstrb  ),
        .s_axi_wlast  ( s_axi_wlast  ),
        .s_axi_wvalid ( s_axi_wvalid ),
        .s_axi_wready ( s_axi_wready ),

        .s_axi_bresp  ( s_axi_bresp  ),
        .s_axi_bvalid ( s_axi_bvalid ),
        .s_axi_bid    ( s_axi_bid    ),
        .s_axi_bready ( s_axi_bready ),

        .s_axi_arid    ( s_axi_arid    ),
        .s_axi_araddr  ( s_axi_araddr  ),
        .s_axi_arlen   ( s_axi_arlen   ),
        .s_axi_arsize  ( s_axi_arsize  ),
        .s_axi_arburst ( s_axi_arburst ),
        .s_axi_arvalid ( s_axi_arvalid ),
        .s_axi_arready ( s_axi_arready ),

        .s_axi_rdata  ( s_axi_rdata  ),
        .s_axi_rresp  ( s_axi_rresp  ),
        .s_axi_rlast  ( s_axi_rlast  ),
        .s_axi_rvalid ( s_axi_rvalid ),
        .s_axi_rid    ( s_axi_rid    ),
        .s_axi_rready ( s_axi_rready ),

        .m_axil_awaddr  ( axil_req.aw.addr  ),
        .m_axil_awprot  ( axil_req.aw.prot  ),
        .m_axil_awvalid ( axil_req.aw_valid ),
        .m_axil_awready ( axil_rsp.aw_ready ),

        .m_axil_wdata  ( axil_req.w.data  ),
        .m_axil_wstrb  ( axil_req.w.strb  ),
        .m_axil_wvalid ( axil_req.w_valid ),
        .m_axil_wready ( axil_rsp.w_ready ),

        .m_axil_bresp  ( axil_rsp.b.resp  ),
        .m_axil_bvalid ( axil_rsp.b_valid ),
        .m_axil_bready ( axil_req.b_ready ),

        .m_axil_araddr  ( axil_req.ar.addr  ),
        .m_axil_arprot  ( axil_req.ar.prot  ),
        .m_axil_arvalid ( axil_req.ar_valid ),
        .m_axil_arready ( axil_rsp.ar_ready ),

        .m_axil_rdata  ( axil_rsp.r.data  ),
        .m_axil_rresp  ( axil_rsp.r.resp  ),
        .m_axil_rvalid ( axil_rsp.r_valid ),
        .m_axil_rready ( axil_req.r_ready )
      );
    end
`endif

  axi_lite_to_reg #(
    .ADDR_WIDTH     ( AXI_ADDR_W  ),
    .DATA_WIDTH     ( AXIL_DATA_W ),
    .axi_lite_req_t ( axil_req_t  ),
    .axi_lite_rsp_t ( axil_rsp_t  ),
    .reg_req_t      ( reg_req_t   ),
    .reg_rsp_t      ( reg_resp_t  )
  ) i_axi_lite_to_reg (
    .clk_i          ( aclk     ),
    .rst_ni         ( aresetn  ),
    .axi_lite_req_i ( axil_req ),
    .axi_lite_rsp_o ( axil_rsp ),
    .reg_req_o      ( reg_req  ),
    .reg_rsp_i      ( reg_rsp  )
  );

    sdhci_top #(
        .AddrWidth(AXI_ADDR_W),
        .reg_req_t    ( reg_req_t  ),
        .reg_rsp_t   ( reg_resp_t ),
        // Pre-divider to be < 63 MHz in all cases
        .ClkPreDiv(4),
        .InsertRegClkBuf(InsertRegClkBuf),
        .TimeoutDivider(1),
        // Keep the existing debounce setting for now; this only affects
        // card-detect stabilization, not the command/data engine.
        .NumDebounceCycles(400_000) // 10ms
    ) 
    i_axi_sdhci (
        .clk_i         ( aclk     ),
        .rst_ni        ( aresetn  ),
        .reg_req_i     ( reg_req  ),
        .reg_rsp_o     ( reg_rsp  ),

        .sd_clk_o(sd_clk_o),
        .sd_cd_ni(sd_cd_ni),
        .sd_cmd_en_o(sd_cmd_en_o),
        .sd_cmd_o(sd_cmd_o),
        .sd_cmd_i(sd_cmd_i),

        .sd_dat_i(sd_dat_i),
        .sd_dat_o(sd_dat_o),
        .sd_dat_en_o(sd_dat_en_o),
        .interrupt_o(interrupt_o)
    ) ;


endmodule
