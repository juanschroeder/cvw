// axi_to_axilite32_adapter_split.sv
// verilog-axi axi_axil_adapter wrapper with address-based sanitization.
//
// Policy:
//   * CSR/MDIO/event ranges: strict single-beat 32-bit MMIO semantics
//       - LEN   = 0
//       - SIZE  = 2 (32-bit)
//       - BURST = INCR
//       - for AXI64, read data duplicated into both 32-bit halves of AXI rdata
//       - for AXI32, read data passed through as-is
//   * Buffer range: preserve original traffic as much as possible
//       - LEN   = original
//       - SIZE  = min(original, log2(AXI beat bytes))
//       - BURST = original if FIXED/INCR, else INCR
//       - read data passed through unchanged
//
// This keeps the current upstream HSIZE/ARSIZE=6 bug from breaking CSR accesses,
// while allowing buffer traffic to remain more memory-like.

module axi_to_axil_adapter_split #(
  // These MUST match the hard-coded buffer decode inside liteEthAXIRgmii.v
  parameter logic [31:0] BUF_BASE = 32'h100D0000,
  parameter logic [31:0] BUF_END  = 32'h100D2000,
  parameter int unsigned AXI_ADDR_WIDTH = 32,
  parameter int unsigned AXI_DATA_WIDTH = 64,
  parameter int unsigned AXI_ID_WIDTH   = 4
 )

(
  input  wire        aclk,
  input  wire        aresetn,

  // AXI4 slave
  input  wire [AXI_ID_WIDTH-1:0] s_axi_awid,
  input  wire [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
  input  wire [7:0]  s_axi_awlen,
  input  wire [2:0]  s_axi_awsize,
  input  wire [1:0]  s_axi_awburst,
  input  wire        s_axi_awvalid,
  output wire        s_axi_awready,

  input  wire [AXI_DATA_WIDTH-1:0]   s_axi_wdata,
  input  wire [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
  input  wire        s_axi_wlast,
  input  wire        s_axi_wvalid,
  output wire        s_axi_wready,

  output wire [1:0]  s_axi_bresp,
  output wire        s_axi_bvalid,
  output wire [AXI_ID_WIDTH-1:0] s_axi_bid,
  input  wire        s_axi_bready,

  input  wire [AXI_ID_WIDTH-1:0] s_axi_arid,
  input  wire [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
  input  wire [7:0]  s_axi_arlen,
  input  wire [2:0]  s_axi_arsize,
  input  wire [1:0]  s_axi_arburst,
  input  wire        s_axi_arvalid,
  output wire        s_axi_arready,

  output wire [AXI_DATA_WIDTH-1:0] s_axi_rdata,
  output wire [1:0]  s_axi_rresp,
  output wire        s_axi_rlast,
  output wire        s_axi_rvalid,
  output wire [AXI_ID_WIDTH-1:0] s_axi_rid,
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

  localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;
  localparam logic [2:0] AXI_MAX_SIZE_ENC = (AXI_DATA_WIDTH == 64) ? 3'd3 : 3'd2;

  if ((AXI_DATA_WIDTH != 32) && (AXI_DATA_WIDTH != 64)) begin : gen_bad_axi_width
    initial $fatal(1, "axi64_to_axil_adapter_split supports AXI_DATA_WIDTH 32 or 64, got %0d", AXI_DATA_WIDTH);
  end

  // Tie off AXI sidebands not present in your crossbar slice
  wire        s_axi_awlock   = 1'b0;
  wire [3:0]  s_axi_awcache  = 4'b0000;
  wire [2:0]  s_axi_awprot_i = 3'b000;

  wire        s_axi_arlock   = 1'b0;
  wire [3:0]  s_axi_arcache  = 4'b0000;
  wire [2:0]  s_axi_arprot_i = 3'b000;

  // --------------------------------------------------------------------------
  // Address map used by current LiteEth integration
  //   buffer : 0x100D0000 - 0x100D1FFF
  //   mdio   : 0x100D2800 - 0x100D28FF
  //   mac    : 0x100D3000 - 0x100D30FF
  // Everything outside the buffer aperture is treated as strict CSR/MMIO.
  // --------------------------------------------------------------------------

  wire aw_is_buffer = (s_axi_awaddr >= BUF_BASE) && (s_axi_awaddr < BUF_END);
  wire ar_is_buffer = (s_axi_araddr >= BUF_BASE) && (s_axi_araddr < BUF_END);

  function automatic [2:0] clamp_size_to_axi_width;
    input [2:0] size_in;
    begin
      clamp_size_to_axi_width = (size_in > AXI_MAX_SIZE_ENC) ? AXI_MAX_SIZE_ENC : size_in;
    end
  endfunction

  function automatic [1:0] sanitize_burst_mem;
    input [1:0] burst_in;
    begin
      // Allow FIXED and INCR as-is; map WRAP/reserved to INCR.
      sanitize_burst_mem = burst_in[1] ? 2'b01 : burst_in;
    end
  endfunction

  wire [7:0] awlen_fix   = aw_is_buffer ? s_axi_awlen                       : 8'd0;
  wire [2:0] awsize_fix  = aw_is_buffer ? clamp_size_to_axi_width(s_axi_awsize) : 3'd2;
  wire [1:0] awburst_fix = aw_is_buffer ? sanitize_burst_mem(s_axi_awburst) : 2'b01;

  wire [7:0] arlen_fix   = ar_is_buffer ? s_axi_arlen                       : 8'd0;
  wire [2:0] arsize_fix  = ar_is_buffer ? clamp_size_to_axi_width(s_axi_arsize) : 3'd2;
  wire [1:0] arburst_fix = ar_is_buffer ? sanitize_burst_mem(s_axi_arburst) : 2'b01;

  // Remember the read address class/lane at AXI handshake time so the returned
  // data can be post-processed consistently.
  reg rd_is_buffer;
  reg rd_lane_hi;
  always @(posedge aclk) begin
    if (rst) begin
      rd_is_buffer <= 1'b0;
      rd_lane_hi   <= 1'b0;
    end else if (s_axi_arvalid && s_axi_arready) begin
      rd_is_buffer <= ar_is_buffer;
      rd_lane_hi   <= s_axi_araddr[2];
    end
  end

  // Internal adapter outputs before optional CSR read-data normalization
  wire [AXI_DATA_WIDTH-1:0] s_axi_rdata_int;
  wire [1:0]  s_axi_rresp_int;
  wire        s_axi_rlast_int;
  wire        s_axi_rvalid_int;
  wire [AXI_ID_WIDTH-1:0] s_axi_rid_int;

  wire [AXI_DATA_WIDTH-1:0] s_axi_rdata_csr;
  if (AXI_DATA_WIDTH == 64) begin : gen_axi64_csr_rdata
    wire [31:0] csr_rword_sel = rd_lane_hi ? s_axi_rdata_int[63:32] : s_axi_rdata_int[31:0];
    assign s_axi_rdata_csr = {csr_rword_sel, csr_rword_sel};
  end else begin : gen_axi32_csr_rdata
    assign s_axi_rdata_csr = s_axi_rdata_int;
  end

  assign s_axi_rdata  = rd_is_buffer ? s_axi_rdata_int : s_axi_rdata_csr;
  assign s_axi_rresp  = s_axi_rresp_int;
  assign s_axi_rlast  = s_axi_rlast_int;
  assign s_axi_rvalid = s_axi_rvalid_int;
  assign s_axi_rid    = s_axi_rid_int;

  axi_axil_adapter #(
    .ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
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
    .s_axi_awlen  (awlen_fix),
    .s_axi_awsize (awsize_fix),
    .s_axi_awburst(awburst_fix),
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
    .s_axi_arlen  (arlen_fix),
    .s_axi_arsize (arsize_fix),
    .s_axi_arburst(arburst_fix),
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
