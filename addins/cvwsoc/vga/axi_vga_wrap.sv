// axi_vga_wrap.sv
`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

// axi_vga_wrap.sv
import vga_regbus_pkg::*;
import axi_vga_reg_pkg::*;
import axi_vga_wrap_pkg::*;

// axi_vga_wrap.sv
`timescale 1ns/1ps

module axi_vga_wrap #(
  parameter int unsigned AXI_ADDR_W = 32,
  parameter int unsigned AXI_DATA_W = 64,
  parameter int unsigned AXI_ID_W   = 4,
  parameter int unsigned AXI_M_ID_W = AXI_ID_W,
  parameter int unsigned AXI_USER_W = 1,
  parameter type s_axi_req_t  = logic,
  parameter type s_axi_resp_t = logic,
  parameter type m_axi_req_t  = logic,
  parameter type m_axi_resp_t = logic
) (
  input  logic        aclk,
  input  logic        aresetn,

  // AXI slave register port and AXI scanout master port.
  input  s_axi_req_t  s_axi_req_i,
  output s_axi_resp_t s_axi_resp_o,
  output m_axi_req_t  m_axi_req_o,
  input  m_axi_resp_t m_axi_resp_i,

  // VGA pins
  output logic        vga_hsync_o,
  output logic        vga_vsync_o,
  output logic [4:0]  vga_r_o,
  output logic [5:0]  vga_g_o,
  output logic [4:0]  vga_b_o
);

  // ----------------------------
  // Types: AXI (PULP structs)
  // ----------------------------
  import axi_pkg::*;
  `include "axi/typedef.svh"
  `include "register_interface/typedef.svh"

  typedef logic [AXI_ADDR_W-1:0] axi_addr_t;
  typedef logic [AXI_DATA_W-1:0] axi_data_t;
  typedef logic [AXI_DATA_W/8-1:0] axi_strb_t;
  typedef logic [AXI_ID_W-1:0]   cfg_axi_id_t;
  typedef logic [AXI_M_ID_W-1:0] axi_id_t;
  typedef logic [AXI_USER_W-1:0] axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(cfg_aw_chan_t, axi_addr_t, cfg_axi_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T (cfg_w_chan_t,  axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T (cfg_b_chan_t,  cfg_axi_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(cfg_ar_chan_t, axi_addr_t, cfg_axi_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T (cfg_r_chan_t,  axi_data_t, cfg_axi_id_t, axi_user_t)

  `AXI_TYPEDEF_REQ_T (cfg_axi_req_t,  cfg_aw_chan_t, cfg_w_chan_t, cfg_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(cfg_axi_resp_t, cfg_b_chan_t,  cfg_r_chan_t)

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T (w_chan_t,  axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T (b_chan_t,  axi_id_t,   axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T (r_chan_t,  axi_data_t, axi_id_t, axi_user_t)

  `AXI_TYPEDEF_REQ_T (axi_req_t,  aw_chan_t, w_chan_t, ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_resp_t, b_chan_t,  r_chan_t)

  // ----------------------------
  // Types: regbus for axi_vga_reg_top inside axi_vga
  // (names must match axi_vga parameters: reg_req_t / reg_resp_t)
  // ----------------------------
  typedef logic [31:0] reg_addr_t;
  typedef logic [31:0] reg_data_t;
  typedef logic [3:0]  reg_strb_t;

  if ((AXI_DATA_W != 32) && (AXI_DATA_W != 64)) begin : gen_bad_axi_width
    initial $fatal(1, "axi_vga_wrap supports AXI_DATA_W 32 or 64, got %0d", AXI_DATA_W);
  end

  // these packages are defined in vga_regbus_pkg.sv
//   `REG_BUS_TYPEDEF_REQ(reg_req_t,  reg_addr_t, reg_data_t, reg_strb_t)
//   `REG_BUS_TYPEDEF_RSP(reg_resp_t, reg_data_t)

  // ----------------------------
  // Discrete <-> struct signals
  // ----------------------------
  cfg_axi_req_t  cfg_axi_req;
  cfg_axi_resp_t cfg_axi_resp;

  axi_req_t  vga_axi_req;
  axi_resp_t vga_axi_resp;

  // Stable ILA taps for the scanout read channel.  Keep these as flat nets:
  // probing fields of packed structs is tool/version dependent.
  (* mark_debug = "true" *) logic [AXI_ADDR_W-1:0] dbg_scan_araddr;
  (* mark_debug = "true" *) logic [7:0]            dbg_scan_arlen;
  (* mark_debug = "true" *) logic [2:0]            dbg_scan_arsize;
  (* mark_debug = "true" *) logic                  dbg_scan_arvalid;
  (* mark_debug = "true" *) logic                  dbg_scan_arready;
  (* mark_debug = "true" *) logic [1:0]            dbg_scan_rresp;
  (* mark_debug = "true" *) logic                  dbg_scan_rlast;
  (* mark_debug = "true" *) logic                  dbg_scan_rvalid;
  (* mark_debug = "true" *) logic                  dbg_scan_rready;

  assign dbg_scan_araddr  = vga_axi_req.ar.addr;
  assign dbg_scan_arlen   = vga_axi_req.ar.len;
  assign dbg_scan_arsize  = vga_axi_req.ar.size;
  assign dbg_scan_arvalid = vga_axi_req.ar_valid;
  assign dbg_scan_arready = m_axi_resp_i.ar_ready;
  assign dbg_scan_rresp   = m_axi_resp_i.r.resp;
  assign dbg_scan_rlast   = m_axi_resp_i.r.last;
  assign dbg_scan_rvalid  = m_axi_resp_i.r_valid;
  assign dbg_scan_rready  = vga_axi_req.r_ready;

  assign cfg_axi_req  = s_axi_req_i;
  assign s_axi_resp_o = cfg_axi_resp;

  // ----------------------------
  // AXI -> regbus (regs path)
  // ----------------------------
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

  axi_to_reg_v2 #(
    .AxiAddrWidth (AXI_ADDR_W),
    .AxiDataWidth (AXI_DATA_W),
    .AxiIdWidth   (AXI_ID_W),
    .AxiUserWidth (AXI_USER_W),
    .RegDataWidth (32),          // because your regbus wdata is 32-bit, wstrb is 4-bit
    //.CutMemReqs   (1'b0),
    .CutMemReqs   (1'b1), //As in Cheshire project
    //.CutMemRsps   (1'b0),
    .CutMemRsps   (1'b1), //Not set like this in Cheshire project
    .axi_req_t    (cfg_axi_req_t),
    .axi_rsp_t    (cfg_axi_resp_t),
    .reg_req_t    (reg_req_t),
    .reg_rsp_t    (reg_resp_t)
  )  i_axi_to_reg (
    .clk_i      ( aclk     ),
    .rst_ni     ( aresetn  ),
    .axi_req_i  ( cfg_axi_req  ),
    .axi_rsp_o  ( cfg_axi_resp ),
    .reg_req_o  ( reg_req ),
    .reg_rsp_i  ( reg_rsp )
  );

  // ----------------------------
  // axi_vga core (includes regfile internally)
  // ----------------------------
  axi_vga #(
    // just use default 5-6-5 and truncate later for 4-4-4 output
    //.RedWidth(4),
    //.GreenWidth(4),
    //.BlueWidth(4),
    .AXIAddrWidth ( AXI_ADDR_W ),
    .AXIDataWidth ( AXI_DATA_W ),
    .AXIIdWidth   ( AXI_M_ID_W ),
    .AXIUserWidth ( AXI_USER_W ),
    .AXIStrbWidth ( AXI_DATA_W/8 ),
    .axi_req_t    ( axi_req_t  ),
    .axi_resp_t   ( axi_resp_t ),   // correct name (NOT axi_rsp_t)
    .axi_r_chan_t ( r_chan_t   ),
    .reg_req_t    ( reg_req_t  ),
    .reg_resp_t   ( reg_resp_t ),
    // Default: 16 and 24
    // Using BufferDepth=4 and MaxReadTxns=4 was tested at least once be good for timing requirements and not have black stripes
    .BufferDepth  ( 32 ), // with 16 framebuffer scan was often affected by AXI stream bursts
    .MaxReadTxns  ( 4 )
  ) i_axi_vga (
    .clk_i         ( aclk     ),
    .rst_ni        ( aresetn  ),
    .test_mode_en_i( 1'b0     ),

    .reg_req_i     ( reg_req  ),
    .reg_rsp_o     ( reg_rsp  ),

    .axi_req_o     ( vga_axi_req  ),
    .axi_resp_i    ( vga_axi_resp ),

    .hsync_o       ( vga_hsync_o ),
    .vsync_o       ( vga_vsync_o ),
    .red_o         ( vga_r_o     ),
    .green_o       ( vga_g_o     ),
    .blue_o        ( vga_b_o     )
  );


    // split out AR handshake
    ar_chan_t ar_i, ar_o;
    logic         ar_valid_i, ar_ready_i;
    logic         ar_valid_o, ar_ready_o;

    assign ar_i       = vga_axi_req.ar;
    assign ar_valid_i = vga_axi_req.ar_valid;

    // 1-deep cut (registered)
    spill_register #(
    //.T ( axi_ar_chan_t )
    .T ( ar_chan_t )
    ) i_vga_ar_cut (
    .clk_i( aclk     ),
    .rst_ni( aresetn  ),
    .data_i  ( ar_i       ),
    .valid_i ( ar_valid_i ),
    .ready_o ( ar_ready_i ),
    .data_o  ( ar_o       ),
    .valid_o ( ar_valid_o ),
    .ready_i ( ar_ready_o )
    );

    always_comb begin
      m_axi_req_o          = vga_axi_req;
      m_axi_req_o.ar       = ar_o;
      m_axi_req_o.ar_valid = ar_valid_o;
    end

    assign vga_axi_resp = m_axi_resp_i;
    assign ar_ready_o   = m_axi_resp_i.ar_ready;


endmodule
