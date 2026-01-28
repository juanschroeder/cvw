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

module axi_vga_wrap (
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
  // AXI MASTER (scanout) to xbar S02
  // ----------------------------
  output logic [3:0]  m_axi_awid,
  output logic [31:0] m_axi_awaddr,
  output logic [7:0]  m_axi_awlen,
  output logic [2:0]  m_axi_awsize,
  output logic [1:0]  m_axi_awburst,
  output logic        m_axi_awlock,
  output logic [3:0]  m_axi_awcache,
  output logic [2:0]  m_axi_awprot,
  output logic        m_axi_awvalid,
  input  logic        m_axi_awready,

  output logic [63:0] m_axi_wdata,
  output logic [7:0]  m_axi_wstrb,
  output logic        m_axi_wlast,
  output logic        m_axi_wvalid,
  input  logic        m_axi_wready,

  input  logic [3:0]  m_axi_bid,
  input  logic [1:0]  m_axi_bresp,
  input  logic        m_axi_bvalid,
  output logic        m_axi_bready,

  output logic [3:0]  m_axi_arid,
  output logic [31:0] m_axi_araddr,
  output logic [7:0]  m_axi_arlen,
  output logic [2:0]  m_axi_arsize,
  output logic [1:0]  m_axi_arburst,
  output logic        m_axi_arlock,
  output logic [3:0]  m_axi_arcache,
  output logic [2:0]  m_axi_arprot,
  output logic        m_axi_arvalid,
  input  logic        m_axi_arready,

  input  logic [3:0]  m_axi_rid,
  input  logic [63:0] m_axi_rdata,
  input  logic [1:0]  m_axi_rresp,
  input  logic        m_axi_rlast,
  input  logic        m_axi_rvalid,
  output logic        m_axi_rready,

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

  localparam int unsigned AXI_ADDR_W = 32;
  localparam int unsigned AXI_DATA_W = 64;
  localparam int unsigned AXI_ID_W   = 4;
  localparam int unsigned AXI_USER_W = 1;

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
  // Types: regbus for axi_vga_reg_top inside axi_vga
  // (names must match axi_vga parameters: reg_req_t / reg_resp_t)
  // ----------------------------
  typedef logic [31:0] reg_addr_t;
  typedef logic [31:0] reg_data_t;
  typedef logic [3:0]  reg_strb_t;

  // these packages are defined in vga_regbus_pkg.sv
//   `REG_BUS_TYPEDEF_REQ(reg_req_t,  reg_addr_t, reg_data_t, reg_strb_t)
//   `REG_BUS_TYPEDEF_RSP(reg_resp_t, reg_data_t)

  // ----------------------------
  // Discrete <-> struct signals
  // ----------------------------
  axi_req_t  cfg_axi_req;
  axi_resp_t cfg_axi_resp;

  axi_req_t  vga_axi_req;
  axi_resp_t vga_axi_resp;

  // AXI SLAVE (regs) discrete -> struct
  always_comb begin
    cfg_axi_req = '0;

    cfg_axi_req.aw_valid   = s_axi_awvalid;
    cfg_axi_req.aw.id      = s_axi_awid;
    cfg_axi_req.aw.addr    = s_axi_awaddr;
    cfg_axi_req.aw.len     = s_axi_awlen;
    cfg_axi_req.aw.size    = s_axi_awsize;
    cfg_axi_req.aw.burst   = s_axi_awburst;
    cfg_axi_req.aw.lock    = s_axi_awlock;
    cfg_axi_req.aw.cache   = s_axi_awcache;
    cfg_axi_req.aw.prot    = s_axi_awprot;
    cfg_axi_req.aw.qos     = s_axi_awqos;
    // fields not present on top-level: drive 0
    cfg_axi_req.aw.region  = '0;
    cfg_axi_req.aw.atop    = '0;
    cfg_axi_req.aw.user    = '0;

    cfg_axi_req.w_valid    = s_axi_wvalid;
    cfg_axi_req.w.data     = s_axi_wdata;
    cfg_axi_req.w.strb     = s_axi_wstrb;
    cfg_axi_req.w.last     = s_axi_wlast;
    cfg_axi_req.w.user     = '0;

    cfg_axi_req.b_ready    = s_axi_bready;

    cfg_axi_req.ar_valid   = s_axi_arvalid;
    cfg_axi_req.ar.id      = s_axi_arid;
    cfg_axi_req.ar.addr    = s_axi_araddr;
    cfg_axi_req.ar.len     = s_axi_arlen;
    cfg_axi_req.ar.size    = s_axi_arsize;
    cfg_axi_req.ar.burst   = s_axi_arburst;
    cfg_axi_req.ar.lock    = s_axi_arlock;
    cfg_axi_req.ar.cache   = s_axi_arcache;
    cfg_axi_req.ar.prot    = s_axi_arprot;
    cfg_axi_req.ar.qos     = s_axi_arqos;
    cfg_axi_req.ar.region  = '0;
    cfg_axi_req.ar.user    = '0;

    cfg_axi_req.r_ready    = s_axi_rready;
  end

  // AXI SLAVE (regs) struct -> discrete
  always_comb begin
    s_axi_awready = cfg_axi_resp.aw_ready;
    s_axi_wready  = cfg_axi_resp.w_ready;

    s_axi_bvalid  = cfg_axi_resp.b_valid;
    s_axi_bresp   = cfg_axi_resp.b.resp;
    s_axi_bid     = cfg_axi_resp.b.id;

    s_axi_arready = cfg_axi_resp.ar_ready;

    s_axi_rvalid  = cfg_axi_resp.r_valid;
    s_axi_rdata   = cfg_axi_resp.r.data;
    s_axi_rresp   = cfg_axi_resp.r.resp;
    s_axi_rlast   = cfg_axi_resp.r.last;
    s_axi_rid     = cfg_axi_resp.r.id;
  end

  // AXI MASTER (scanout) struct -> discrete
  always_comb begin
    m_axi_awvalid = vga_axi_req.aw_valid;
    m_axi_awid    = vga_axi_req.aw.id;
    m_axi_awaddr  = vga_axi_req.aw.addr;
    m_axi_awlen   = vga_axi_req.aw.len;
    m_axi_awsize  = vga_axi_req.aw.size;
    m_axi_awburst = vga_axi_req.aw.burst;
    m_axi_awlock  = vga_axi_req.aw.lock;
    m_axi_awcache = vga_axi_req.aw.cache;
    m_axi_awprot  = vga_axi_req.aw.prot;

    m_axi_wvalid  = vga_axi_req.w_valid;
    m_axi_wdata   = vga_axi_req.w.data;
    m_axi_wstrb   = vga_axi_req.w.strb;
    m_axi_wlast   = vga_axi_req.w.last;

    m_axi_bready  = vga_axi_req.b_ready;

    m_axi_arvalid = vga_axi_req.ar_valid;
    m_axi_arid    = vga_axi_req.ar.id;
    m_axi_araddr  = vga_axi_req.ar.addr;
    m_axi_arlen   = vga_axi_req.ar.len;
    m_axi_arsize  = vga_axi_req.ar.size;
    m_axi_arburst = vga_axi_req.ar.burst;
    m_axi_arlock  = vga_axi_req.ar.lock;
    m_axi_arcache = vga_axi_req.ar.cache;
    m_axi_arprot  = vga_axi_req.ar.prot;

    m_axi_rready  = vga_axi_req.r_ready;
  end

  // AXI MASTER (scanout) discrete -> struct
  always_comb begin
    vga_axi_resp = '0;

    vga_axi_resp.aw_ready = m_axi_awready;
    vga_axi_resp.w_ready  = m_axi_wready;

    vga_axi_resp.b_valid  = m_axi_bvalid;
    vga_axi_resp.b.id     = m_axi_bid;
    vga_axi_resp.b.resp   = m_axi_bresp;
    vga_axi_resp.b.user   = '0;

    vga_axi_resp.ar_ready = m_axi_arready;

    vga_axi_resp.r_valid  = m_axi_rvalid;
    vga_axi_resp.r.id     = m_axi_rid;
    vga_axi_resp.r.data   = m_axi_rdata;
    vga_axi_resp.r.resp   = m_axi_rresp;
    vga_axi_resp.r.last   = m_axi_rlast;
    vga_axi_resp.r.user   = '0;
  end

  // ----------------------------
  // AXI -> regbus (regs path)
  // ----------------------------
  reg_req_t  reg_req;
  reg_resp_t reg_rsp;
    (* keep = "true", mark_debug = "true" *) logic        dbg_reg_req_valid;
    (* keep = "true", mark_debug = "true" *) logic        dbg_reg_req_write;
    (* keep = "true", mark_debug = "true" *) logic [11:0] dbg_reg_req_addr;
    (* keep = "true", mark_debug = "true" *) logic [31:0] dbg_reg_req_wdata;
    (* keep = "true", mark_debug = "true" *) logic [3:0]  dbg_reg_req_wstrb;

    (* keep = "true", mark_debug = "true" *) logic        dbg_reg_rsp_ready;
    (* keep = "true", mark_debug = "true" *) logic        dbg_reg_rsp_error;
    (* keep = "true", mark_debug = "true" *) logic [31:0] dbg_reg_rsp_rdata;

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
    .AxiAddrWidth (32),
    .AxiDataWidth (64),
    .AxiIdWidth   (4),
    .AxiUserWidth (1),
    .RegDataWidth (32),          // because your regbus wdata is 32-bit, wstrb is 4-bit
    //.CutMemReqs   (1'b0),
    .CutMemReqs   (1'b1), //As in Cheshire project
    //.CutMemRsps   (1'b0),
    .CutMemRsps   (1'b1), //Not set like this in Cheshire project
    .axi_req_t    (axi_req_t),
    .axi_rsp_t    (axi_resp_t),
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
    .AXIIdWidth   ( AXI_ID_W   ),
    .AXIUserWidth ( AXI_USER_W ),
    .AXIStrbWidth ( AXI_DATA_W/8 ),
    .axi_req_t    ( axi_req_t  ),
    .axi_resp_t   ( axi_resp_t ),   // correct name (NOT axi_rsp_t)
    .axi_r_chan_t ( r_chan_t   ),
    .reg_req_t    ( reg_req_t  ),
    .reg_resp_t   ( reg_resp_t ),
    // Default: 16 and 24
    .BufferDepth  ( 4 ), // Testing values to see if it fixes timing 
    //.MaxReadTxns  ( 4 ) // This value brings AXI VGA out of the critical path
    //.BufferDepth  ( 2 ), // This  
    .MaxReadTxns  ( 2 ) // This brings
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

endmodule
