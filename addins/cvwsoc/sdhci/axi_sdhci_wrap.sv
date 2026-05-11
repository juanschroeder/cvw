`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

// axi_shdci_wrap.sv
import sdhci_regbus_pkg::*;
import sdhci_reg_pkg::*;
import axi_sdhci_wrap_pkg::*;

// axi_sdhci_wrap.sv
`timescale 1ns/1ps

module axi_sdhci_wrap (
  input  logic        aclk,
  input  logic        aresetn,

  // ----------------------------
  // AXI SLAVE (regs) from xbar M02
  // ----------------------------
  input  logic [3:0]  s_axi_awid,
  input  logic [31:0] s_axi_awaddr,
  input  logic [7:0]  s_axi_awlen,
  input  logic [2:0]  s_axi_awsize,
  input  logic [1:0]  s_axi_awburst,
  input  logic        s_axi_awlock,
  input  logic [3:0]  s_axi_awcache,
  input  logic [2:0]  s_axi_awprot,
  input  logic [3:0]  s_axi_awqos,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,

  input  logic [63:0] s_axi_wdata,
  input  logic [7:0]  s_axi_wstrb,
  input  logic        s_axi_wlast,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,

  output logic [3:0]  s_axi_bid,
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,

  input  logic [3:0]  s_axi_arid,
  input  logic [31:0] s_axi_araddr,
  input  logic [7:0]  s_axi_arlen,
  input  logic [2:0]  s_axi_arsize,
  input  logic [1:0]  s_axi_arburst,
  input  logic        s_axi_arlock,
  input  logic [3:0]  s_axi_arcache,
  input  logic [2:0]  s_axi_arprot,
  input  logic [3:0]  s_axi_arqos,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,

  output logic [3:0]  s_axi_rid,
  output logic [63:0] s_axi_rdata,
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

  localparam int unsigned AXI_ADDR_W = 32;
  localparam int unsigned AXI_DATA_W = 64;
  localparam int unsigned AXI_ID_W   = 4;
  localparam int unsigned AXI_USER_W = 1;
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

  // ----------------------------
  // AXI64 -> AXI-Lite32 -> regbus
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

  axi64_mmio_to_axilite32_v2 i_axi64_to_axilite32 (
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
        // The CVW SoC testbench drives the peripheral bus at 7 ns (~143 MHz).
        // Pre-divide by 4 here so the SDHCI core sees ~35.7 MHz instead of
        // an out-of-spec >63 MHz source clock.
        .ClkPreDiv(2),
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
