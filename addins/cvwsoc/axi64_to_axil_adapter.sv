// axi64_mmio_to_axilite32_new_verilog_axi_fixed.sv
// Replacement for axi64_mmio_to_axilite32_v2 using verilog-axi axi_axil_adapter,
// with fixes for the current HSIZE/ARSIZE bug.
//
// Main fixes relative to the original wrapper:
//   1) Force single-beat INCR accesses into axi_axil_adapter.
//   2) Force AXI beat size to 32-bit (SIZE=2) so AXI64->AXI-Lite32 does not fan out one
//      bad AXI request into many AXI-Lite accesses across neighboring CSRs/buffer words.
//   3) Duplicate the selected 32-bit read word into both halves of the 64-bit AXI read data,
//      so an upstream consumer that samples the "wrong" half still sees the expected value.
//
// This makes the bridge tolerant of the current upstream illegal HSIZE/ARSIZE=6 traffic.
// It is a containment fix, not the root-cause fix.

module axi64_to_axil_adapter (
  input  wire        aclk,
  input  wire        aresetn,

  // AXI4 slave (64-bit)
  input  wire [3:0]  s_axi_awid,
  input  wire [31:0] s_axi_awaddr,
  input  wire [7:0]  s_axi_awlen,
  input  wire [2:0]  s_axi_awsize,
  input  wire [1:0]  s_axi_awburst,
  input  wire        s_axi_awvalid,
  output wire        s_axi_awready,

  input  wire [63:0] s_axi_wdata,
  input  wire [7:0]  s_axi_wstrb,
  input  wire        s_axi_wlast,
  input  wire        s_axi_wvalid,
  output wire        s_axi_wready,

  output wire [1:0]  s_axi_bresp,
  output wire        s_axi_bvalid,
  output wire [3:0]  s_axi_bid,
  input  wire        s_axi_bready,

  input  wire [3:0]  s_axi_arid,
  input  wire [31:0] s_axi_araddr,
  input  wire [7:0]  s_axi_arlen,
  input  wire [2:0]  s_axi_arsize,
  input  wire [1:0]  s_axi_arburst,
  input  wire        s_axi_arvalid,
  output wire        s_axi_arready,

  output wire [63:0] s_axi_rdata,
  output wire [1:0]  s_axi_rresp,
  output wire        s_axi_rlast,
  output wire        s_axi_rvalid,
  output wire [3:0]  s_axi_rid,
  input  wire        s_axi_rready,

  // AXI4-Lite master (32-bit)
  output wire [31:0] m_axil_awaddr,
  output wire [2:0]  m_axil_awprot,
  output wire        m_axil_awvalid,
  input  wire        m_axil_awready,

  output wire [31:0] m_axil_wdata,
  output wire [3:0]  m_axil_wstrb,
  output wire        m_axil_wvalid,
  input  wire        m_axil_wready,

  input  wire [1:0]  m_axil_bresp,
  input  wire        m_axil_bvalid,
  output wire        m_axil_bready,

  output wire [31:0] m_axil_araddr,
  output wire [2:0]  m_axil_arprot,
  output wire        m_axil_arvalid,
  input  wire        m_axil_arready,

  input  wire [31:0] m_axil_rdata,
  input  wire [1:0]  m_axil_rresp,
  input  wire        m_axil_rvalid,
  output wire        m_axil_rready
);

  // verilog-axi uses active-high reset
  wire rst = ~aresetn;

  // Tie off AXI sidebands not present in your crossbar slice
  wire        s_axi_awlock   = 1'b0;
  wire [3:0]  s_axi_awcache  = 4'b0000;
  wire [2:0]  s_axi_awprot_i = 3'b000;

  wire        s_axi_arlock   = 1'b0;
  wire [3:0]  s_axi_arcache  = 4'b0000;
  wire [2:0]  s_axi_arprot_i = 3'b000;

  // --------------------------------------------------------------------------
  // Defensive sanitization for current upstream illegal HSIZE/ARSIZE=6 traffic.
  // Treat this bridge as a 32-bit single-beat device window.
  // --------------------------------------------------------------------------
  wire [7:0]  s_axi_awlen_fix   = 8'd0;
  wire [2:0]  s_axi_awsize_fix  = 3'd2;
  wire [1:0]  s_axi_awburst_fix = 2'b01; // INCR

  wire [7:0]  s_axi_arlen_fix   = 8'd0;
  wire [2:0]  s_axi_arsize_fix  = 3'd2;
  wire [1:0]  s_axi_arburst_fix = 2'b01; // INCR

  // Remember which 32-bit lane was requested so we can mirror it on the readback.
  // This avoids upstream consumers depending on lower-vs-upper half selection.
  reg rd_lane_hi;
  always @(posedge aclk) begin
    if (rst) begin
      rd_lane_hi <= 1'b0;
    end else if (s_axi_arvalid && s_axi_arready) begin
      rd_lane_hi <= s_axi_araddr[2];
    end
  end

  // Internal adapter outputs before read-data normalization
  wire [63:0] s_axi_rdata_int;
  wire [1:0]  s_axi_rresp_int;
  wire        s_axi_rlast_int;
  wire        s_axi_rvalid_int;
  wire [3:0]  s_axi_rid_int;

  wire [31:0] s_axi_rword_sel = rd_lane_hi ? s_axi_rdata_int[63:32] : s_axi_rdata_int[31:0];

  assign s_axi_rdata  = {s_axi_rword_sel, s_axi_rword_sel};
  assign s_axi_rresp  = s_axi_rresp_int;
  assign s_axi_rlast  = s_axi_rlast_int;
  assign s_axi_rvalid = s_axi_rvalid_int;
  assign s_axi_rid    = s_axi_rid_int;

  axi_axil_adapter #(
    .ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(64),
    .AXI_STRB_WIDTH(8),
    .AXI_ID_WIDTH(4),
    .AXIL_DATA_WIDTH(32),
    .AXIL_STRB_WIDTH(4),
    .CONVERT_BURST(1),
    .CONVERT_NARROW_BURST(0)
  ) u_axi_axil_adapter (
    .clk(aclk),
    .rst(rst),

    // AXI slave
    .s_axi_awid   (s_axi_awid),
    .s_axi_awaddr (s_axi_awaddr),
    .s_axi_awlen  (s_axi_awlen_fix),
    .s_axi_awsize (s_axi_awsize_fix),
    .s_axi_awburst(s_axi_awburst_fix),
    .s_axi_awlock (s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot (s_axi_awprot_i),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),

    .s_axi_wdata  (s_axi_wdata),
    .s_axi_wstrb  (s_axi_wstrb),
    .s_axi_wlast  (s_axi_wlast),
    .s_axi_wvalid (s_axi_wvalid),
    .s_axi_wready (s_axi_wready),

    .s_axi_bid    (s_axi_bid),
    .s_axi_bresp  (s_axi_bresp),
    .s_axi_bvalid (s_axi_bvalid),
    .s_axi_bready (s_axi_bready),

    .s_axi_arid   (s_axi_arid),
    .s_axi_araddr (s_axi_araddr),
    .s_axi_arlen  (s_axi_arlen_fix),
    .s_axi_arsize (s_axi_arsize_fix),
    .s_axi_arburst(s_axi_arburst_fix),
    .s_axi_arlock (s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot (s_axi_arprot_i),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),

    .s_axi_rid    (s_axi_rid_int),
    .s_axi_rdata  (s_axi_rdata_int),
    .s_axi_rresp  (s_axi_rresp_int),
    .s_axi_rlast  (s_axi_rlast_int),
    .s_axi_rvalid (s_axi_rvalid_int),
    .s_axi_rready (s_axi_rready),

    // AXI-Lite master
    .m_axil_awaddr (m_axil_awaddr),
    .m_axil_awprot (m_axil_awprot),
    .m_axil_awvalid(m_axil_awvalid),
    .m_axil_awready(m_axil_awready),

    .m_axil_wdata  (m_axil_wdata),
    .m_axil_wstrb  (m_axil_wstrb),
    .m_axil_wvalid (m_axil_wvalid),
    .m_axil_wready (m_axil_wready),

    .m_axil_bresp  (m_axil_bresp),
    .m_axil_bvalid (m_axil_bvalid),
    .m_axil_bready (m_axil_bready),

    .m_axil_araddr (m_axil_araddr),
    .m_axil_arprot (m_axil_arprot),
    .m_axil_arvalid(m_axil_arvalid),
    .m_axil_arready(m_axil_arready),

    .m_axil_rdata  (m_axil_rdata),
    .m_axil_rresp  (m_axil_rresp),
    .m_axil_rvalid (m_axil_rvalid),
    .m_axil_rready (m_axil_rready)
  );

endmodule
