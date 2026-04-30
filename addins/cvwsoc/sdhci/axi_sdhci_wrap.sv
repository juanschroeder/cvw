`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

// axi_shdci_wrap.sv
import sdhci_regbus_pkg::*;
//import axi_sdhci_reg_pkg::*;
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

  // ----------------------------
  // NO AXI MASTER FOR SDHCI
  // ----------------------------
//   output logic [3:0]  m_axi_awid,
//   output logic [31:0] m_axi_awaddr,
//   output logic [7:0]  m_axi_awlen,
//   output logic [2:0]  m_axi_awsize,
//   output logic [1:0]  m_axi_awburst,
//   output logic        m_axi_awlock,
//   output logic [3:0]  m_axi_awcache,
//   output logic [2:0]  m_axi_awprot,
//   output logic        m_axi_awvalid,
//   input  logic        m_axi_awready,

//   output logic [63:0] m_axi_wdata,
//   output logic [7:0]  m_axi_wstrb,
//   output logic        m_axi_wlast,
//   output logic        m_axi_wvalid,
//   input  logic        m_axi_wready,

//   input  logic [3:0]  m_axi_bid,
//   input  logic [1:0]  m_axi_bresp,
//   input  logic        m_axi_bvalid,
//   output logic        m_axi_bready,

//   output logic [3:0]  m_axi_arid,
//   output logic [31:0] m_axi_araddr,
//   output logic [7:0]  m_axi_arlen,
//   output logic [2:0]  m_axi_arsize,
//   output logic [1:0]  m_axi_arburst,
//   output logic        m_axi_arlock,
//   output logic [3:0]  m_axi_arcache,
//   output logic [2:0]  m_axi_arprot,
//   output logic        m_axi_arvalid,
//   input  logic        m_axi_arready,

//   input  logic [3:0]  m_axi_rid,
//   input  logic [63:0] m_axi_rdata,
//   input  logic [1:0]  m_axi_rresp,
//   input  logic        m_axi_rlast,
//   input  logic        m_axi_rvalid,
//   output logic        m_axi_rready,

//   // VGA pins
//   output logic        vga_hsync_o,
//   output logic        vga_vsync_o,
//   output logic [4:0]  vga_r_o,
//   output logic [5:0]  vga_g_o,
//   output logic [4:0]  vga_b_o
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

  // ----------------------------
  // axi_vga core (includes regfile internally)
  // ----------------------------
//   axi_vga #(
//     // just use default 5-6-5 and truncate later for 4-4-4 output
//     //.RedWidth(4),
//     //.GreenWidth(4),
//     //.BlueWidth(4),
//     .AXIAddrWidth ( AXI_ADDR_W ),
//     .AXIDataWidth ( AXI_DATA_W ),
//     .AXIIdWidth   ( AXI_ID_W   ),
//     .AXIUserWidth ( AXI_USER_W ),
//     .AXIStrbWidth ( AXI_DATA_W/8 ),
//     .axi_req_t    ( axi_req_t  ),
//     .axi_resp_t   ( axi_resp_t ),   // correct name (NOT axi_rsp_t)
//     .axi_r_chan_t ( r_chan_t   ),
//     .reg_req_t    ( reg_req_t  ),
//     .reg_resp_t   ( reg_resp_t ),
//     // Default: 16 and 24
//     // Using BufferDepth=4 and MaxReadTxns=4 was tested at least once be good for timing requirements and not have black stripes
//     .BufferDepth  ( 4 ),
//     .MaxReadTxns  ( 4 ) 
//   ) i_axi_vga (
//     .clk_i         ( aclk     ),
//     .rst_ni        ( aresetn  ),
//     .test_mode_en_i( 1'b0     ),

//     .reg_req_i     ( reg_req  ),
//     .reg_rsp_o     ( reg_rsp  ),

//     .axi_req_o     ( sdhci_axi_req  ),
//     .axi_resp_i    ( sdhci_axi_resp ),

//     .hsync_o       ( vga_hsync_o ),
//     .vsync_o       ( vga_vsync_o ),
//     .red_o         ( vga_r_o     ),
//     .green_o       ( vga_g_o     ),
//     .blue_o        ( vga_b_o     )
//   );


    // module sdhci_top #(
    //     parameter int unsigned AddrWidth = 32'd32,
    //     parameter type               reg_req_t   = logic,
    //     parameter type               reg_rsp_t   = logic,

    //     //sw handles clock division. However, largest base freq. accepted is 63MHz!
    //     //-> internal clock predivider to get below 63MHz
    //     //only power of 2 dividers allowed :(
    //     //input log2 of divider i.e div by 4 ->  ClkPreDivLog = 2
    //     parameter int unsigned       ClkPreDivLog   = 1,
    //     //also change base_clock_frequency_for_sd_clock resval in reg/sdhci_regs.hjson and regenerate registers

    //     parameter int unsigned TimeoutDivider = 1, // by how much to divide clk_i to get the timeout count frequency,
    //                                         // see dat_timeout for details

    //     // clock runs at 50MHz, so 1ms is 50_000 cycles
    //     parameter int unsigned       NumDebounceCycles = 500_000 // 10ms
    // ) (
    //     input  logic clk_i,
    //     input  logic rst_ni,

    //     input  reg_req_t reg_req_i,
    //     output reg_rsp_t reg_rsp_o,

    //     output logic       sd_clk_o,
    //     input  logic       sd_cd_ni,
    //     output logic       sd_cmd_en_o,
    //     output logic       sd_cmd_o,
    //     input  logic       sd_cmd_i,

    //     input  logic [3:0] sd_dat_i,
    //     output logic [3:0] sd_dat_o,
    //     output logic       sd_dat_en_o,

    //     output logic interrupt_o
    // );

    sdhci_top #(
        .AddrWidth(AXI_ADDR_W),
        // parameter type               reg_req_t   = logic,
        // parameter type               reg_rsp_t   = logic,
        .reg_req_t    ( reg_req_t  ),
        .reg_rsp_t   ( reg_resp_t ),
        // The CVW SoC testbench drives the peripheral bus at 7 ns (~143 MHz).
        // Pre-divide by 4 here so the SDHCI core sees ~35.7 MHz instead of
        // an out-of-spec >63 MHz source clock.
        //.ClkPreDivLog(2),
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


    // // split out AR handshake
    // ar_chan_t ar_i, ar_o;
    // logic         ar_valid_i, ar_ready_i;
    // logic         ar_valid_o, ar_ready_o;

    // assign ar_i       = sdhci_axi_req.ar;
    // assign ar_valid_i = sdhci_axi_req.ar_valid;

    // // 1-deep cut (registered)
    // spill_register #(
    // //.T ( axi_ar_chan_t )
    // .T ( ar_chan_t )
    // ) i_vga_ar_cut (
    // .clk_i( aclk     ),
    // .rst_ni( aresetn  ),
    // .data_i  ( ar_i       ),
    // .valid_i ( ar_valid_i ),
    // .ready_o ( ar_ready_i ),
    // .data_o  ( ar_o       ),
    // .valid_o ( ar_valid_o ),
    // .ready_i ( ar_ready_o )
    // );

    // //assign cross_axi_req.ar_valid = ar_valid_o;
    // assign m_axi_arvalid = ar_valid_o;
    // assign m_axi_araddr  = ar_o.addr;
    // assign m_axi_arid    = ar_o.id;
    // assign m_axi_arlen   = ar_o.len;
    // assign m_axi_arsize  = ar_o.size;
    // assign m_axi_arburst = ar_o.burst;
    // assign m_axi_arlock  = ar_o.lock;
    // assign m_axi_arcache = ar_o.cache;
    // assign m_axi_arprot  = ar_o.prot;

    // // AXI MASTER (scanout) discrete -> struct
    // always_comb begin
    //     sdhci_axi_resp = '0;

    //     sdhci_axi_resp.aw_ready = m_axi_awready;
    //     sdhci_axi_resp.w_ready  = m_axi_wready;

    //     sdhci_axi_resp.b_valid  = m_axi_bvalid;
    //     sdhci_axi_resp.b.id     = m_axi_bid;
    //     sdhci_axi_resp.b.resp   = m_axi_bresp;
    //     sdhci_axi_resp.b.user   = '0;

    //     sdhci_axi_resp.ar_ready = ar_ready_i;

    //     sdhci_axi_resp.r_valid  = m_axi_rvalid;
    //     sdhci_axi_resp.r.id     = m_axi_rid;
    //     sdhci_axi_resp.r.data   = m_axi_rdata;
    //     sdhci_axi_resp.r.resp   = m_axi_rresp;
    //     sdhci_axi_resp.r.last   = m_axi_rlast;
    //     sdhci_axi_resp.r.user   = '0;
    // end

    // assign ar_ready_o             = m_axi_arready;


endmodule
