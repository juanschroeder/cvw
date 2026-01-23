// Minimal AXI4(64-bit) slave -> AXI4-Lite(32-bit) master bridge for MMIO register access.
//
// Purpose:
// - Crossbar M01 is AXI4/64 (global DATA_WIDTH=64 in your crossbar).
// - AXI CDMA control port is AXI4-Lite/32.
// - Xilinx AXI Data Width Converter in this project appears to backpressure forever on narrow MMIO.
//
// This bridge supports *single-beat* 32-bit register reads/writes (typical Linux MMIO).
// It returns SLVERR for bursts (LEN!=0) or for unsupported write strobes (both halves active).

module axi64_mmio_to_axilite32 (
  input  wire        aclk,
  input  wire        aresetn,

  // AXI4 slave (64-bit) from crossbar M01
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

  output reg  [1:0]  s_axi_bresp,
  output reg         s_axi_bvalid,
  output reg  [3:0]  s_axi_bid,
  input  wire        s_axi_bready,

  input  wire [3:0]  s_axi_arid,
  input  wire [31:0] s_axi_araddr,
  input  wire [7:0]  s_axi_arlen,
  input  wire [2:0]  s_axi_arsize,
  input  wire [1:0]  s_axi_arburst,
  input  wire        s_axi_arvalid,
  output wire        s_axi_arready,

  output reg  [63:0] s_axi_rdata,
  output reg  [1:0]  s_axi_rresp,
  output reg         s_axi_rlast,
  output reg         s_axi_rvalid,
  output reg  [3:0]  s_axi_rid,
  input  wire        s_axi_rready,

  // AXI4-Lite master (32-bit) to CDMA regs
  output reg  [31:0] m_axil_awaddr,
  output reg  [2:0]  m_axil_awprot,
  output reg         m_axil_awvalid,
  input  wire        m_axil_awready,

  output reg  [31:0] m_axil_wdata,
  output reg  [3:0]  m_axil_wstrb,
  output reg         m_axil_wvalid,
  input  wire        m_axil_wready,

  input  wire [1:0]  m_axil_bresp,
  input  wire        m_axil_bvalid,
  output reg         m_axil_bready,

  output reg  [31:0] m_axil_araddr,
  output reg  [2:0]  m_axil_arprot,
  output reg         m_axil_arvalid,
  input  wire        m_axil_arready,

  input  wire [31:0] m_axil_rdata,
  input  wire [1:0]  m_axil_rresp,
  input  wire        m_axil_rvalid,
  output reg         m_axil_rready
);

  // --------------------------
  // Write channel state
  // --------------------------
  reg        aw_pending;
  reg        w_pending;
  reg [3:0]  awid_q;
  reg [31:0] awaddr_q;
  reg [2:0]  awsize_q;
  reg [7:0]  wstrb_q;
  reg [63:0] wdata_q;

  reg        write_err;      // latched: respond SLVERR without touching AXI-Lite
  reg        write_inflight; // AXI-Lite transaction active

  // Accept AW/W independently until both captured (single-beat only)
  assign s_axi_awready = aresetn && !aw_pending && !write_inflight && !s_axi_bvalid;
  assign s_axi_wready  = aresetn && !w_pending  && !write_inflight && !s_axi_bvalid;

  // --------------------------
  // Read channel state
  // --------------------------
  reg        read_inflight;
  reg        read_err;
  reg [3:0]  arid_q;
  reg [31:0] araddr_q;
  reg [2:0]  arsize_q;

  assign s_axi_arready = aresetn && !read_inflight && !s_axi_rvalid;

  // Helper: determine which 32-bit lane a 32-bit access targets.
  // For aligned 32-bit regs, address[2] selects lower/upper 32 bits of the 64-bit beat.
  wire lane_sel_w = (s_axi_awaddr[2]);
  wire lane_sel_r = (s_axi_araddr[2]);

  // Helper: validate write strobes for a single 32-bit register write
  wire wstrb_lo = |wstrb_q[3:0];
  wire wstrb_hi = |wstrb_q[7:4];

  // --------------------------
  // Sequential logic
  // --------------------------
  always @(posedge aclk) begin
    if (!aresetn) begin
      // AXI slave responses
      s_axi_bvalid <= 1'b0;
      s_axi_bresp  <= 2'b00;
      s_axi_bid    <= 4'b0;

      s_axi_rvalid <= 1'b0;
      s_axi_rresp  <= 2'b00;
      s_axi_rdata  <= 64'b0;
      s_axi_rid    <= 4'b0;
      s_axi_rlast  <= 1'b1;

      // AXI-Lite master
      m_axil_awvalid <= 1'b0;
      m_axil_wvalid  <= 1'b0;
      m_axil_bready  <= 1'b0;
      m_axil_arvalid <= 1'b0;
      m_axil_rready  <= 1'b0;
      m_axil_awaddr  <= 32'b0;
      m_axil_awprot  <= 3'b000;
      m_axil_wdata   <= 32'b0;
      m_axil_wstrb   <= 4'b0;
      m_axil_araddr  <= 32'b0;
      m_axil_arprot  <= 3'b000;

      // State
      aw_pending     <= 1'b0;
      w_pending      <= 1'b0;
      write_err      <= 1'b0;
      write_inflight <= 1'b0;

      read_inflight  <= 1'b0;
      read_err       <= 1'b0;

      awid_q   <= 4'b0;
      awaddr_q <= 32'b0;
      awsize_q <= 3'b0;
      wstrb_q  <= 8'b0;
      wdata_q  <= 64'b0;

      arid_q   <= 4'b0;
      araddr_q <= 32'b0;
      arsize_q <= 3'b0;

    end else begin
      // --------------------------
      // Capture AXI write address
      // --------------------------
      if (s_axi_awvalid && s_axi_awready) begin
        aw_pending <= 1'b1;
        awid_q     <= s_axi_awid;
        awaddr_q   <= s_axi_awaddr;
        awsize_q   <= s_axi_awsize;

        // Pre-check unsupported burst
        if (s_axi_awlen != 8'd0) write_err <= 1'b1;
        // For MMIO regs we expect 32-bit writes (size=2). If not, error.
        if (s_axi_awsize != 3'd2) write_err <= 1'b1;
        // Expect INCR (01) or FIXED (00) for single beat; reject others.
        if (s_axi_awburst[1] == 1'b1) write_err <= 1'b1; // 10/11
      end

      // --------------------------
      // Capture AXI write data
      // --------------------------
      if (s_axi_wvalid && s_axi_wready) begin
        w_pending <= 1'b1;
        wdata_q   <= s_axi_wdata;
        wstrb_q   <= s_axi_wstrb;

        // single-beat only
        if (!s_axi_wlast) write_err <= 1'b1;
      end

      // --------------------------
      // Launch AXI-Lite write when AW+W are captured
      // --------------------------
      if (!write_inflight && aw_pending && w_pending && !s_axi_bvalid) begin
        // Validate strobes: only one 32-bit half should be written
        if (wstrb_lo && wstrb_hi) begin
          write_err <= 1'b1;
        end
        if (!(wstrb_lo || wstrb_hi)) begin
          write_err <= 1'b1;
        end

        if (write_err) begin
          // Immediate SLVERR response (no AXI-Lite)
          s_axi_bvalid <= 1'b1;
          s_axi_bresp  <= 2'b10; // SLVERR
          s_axi_bid    <= awid_q;

          // Clear pending
          aw_pending <= 1'b0;
          w_pending  <= 1'b0;
          write_err  <= 1'b0;
        end else begin
          // Drive AXI-Lite write
          m_axil_awaddr  <= awaddr_q;
          m_axil_awprot  <= 3'b000;
          m_axil_awvalid <= 1'b1;

          // Select 32-bit lane based on strobe (preferred) or address[2]
          // wstrb_lo/hi computed from latched strobes
          if (wstrb_hi && !wstrb_lo) begin
            m_axil_wdata <= wdata_q[63:32];
            m_axil_wstrb <= wstrb_q[7:4];
          end else if (wstrb_lo && !wstrb_hi) begin
            m_axil_wdata <= wdata_q[31:0];
            m_axil_wstrb <= wstrb_q[3:0];
          end else begin
            // Fallback: use address[2]
            m_axil_wdata <= lane_sel_w ? wdata_q[63:32] : wdata_q[31:0];
            m_axil_wstrb <= lane_sel_w ? wstrb_q[7:4]  : wstrb_q[3:0];
          end

          m_axil_wvalid  <= 1'b1;
          m_axil_bready  <= 1'b1;

          write_inflight <= 1'b1;

          // Clear pending
          aw_pending <= 1'b0;
          w_pending  <= 1'b0;
        end
      end

      // AXI-Lite write handshakes
      if (m_axil_awvalid && m_axil_awready) m_axil_awvalid <= 1'b0;
      if (m_axil_wvalid  && m_axil_wready)  m_axil_wvalid  <= 1'b0;

      // Complete AXI-Lite write -> respond on AXI
      if (write_inflight && m_axil_bvalid && m_axil_bready) begin
        m_axil_bready  <= 1'b0;
        write_inflight <= 1'b0;

        s_axi_bvalid <= 1'b1;
        s_axi_bresp  <= m_axil_bresp;
        s_axi_bid    <= awid_q;
      end

      // AXI B channel handshake back to crossbar
      if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end

      // --------------------------
      // Launch AXI-Lite read
      // --------------------------
      if (!read_inflight && !s_axi_rvalid && s_axi_arvalid && s_axi_arready) begin
        arid_q   <= s_axi_arid;
        araddr_q <= s_axi_araddr;
        arsize_q <= s_axi_arsize;

        read_err <= 1'b0;
        if (s_axi_arlen != 8'd0) read_err <= 1'b1;
        if (s_axi_arsize != 3'd2) read_err <= 1'b1; // 32-bit regs
        if (s_axi_arburst[1] == 1'b1) read_err <= 1'b1;

        if (read_err) begin
          // Immediate SLVERR read response
          s_axi_rvalid <= 1'b1;
          s_axi_rlast  <= 1'b1;
          s_axi_rresp  <= 2'b10;
          s_axi_rid    <= s_axi_arid;
          s_axi_rdata  <= 64'b0;
          read_err     <= 1'b0;
        end else begin
          m_axil_araddr  <= s_axi_araddr;
          m_axil_arprot  <= 3'b000;
          m_axil_arvalid <= 1'b1;
          m_axil_rready  <= 1'b1;
          read_inflight  <= 1'b1;
        end
      end

      if (m_axil_arvalid && m_axil_arready) begin
        m_axil_arvalid <= 1'b0;
      end

      // Complete AXI-Lite read -> respond on AXI
      if (read_inflight && m_axil_rvalid && m_axil_rready) begin
        m_axil_rready <= 1'b0;
        read_inflight <= 1'b0;

        s_axi_rvalid <= 1'b1;
        s_axi_rlast  <= 1'b1;
        s_axi_rresp  <= m_axil_rresp;
        s_axi_rid    <= arid_q;

        // Place 32-bit read data into the addressed 32-bit lane of the 64-bit AXI beat
        if (araddr_q[2]) begin
          s_axi_rdata <= {m_axil_rdata, 32'b0};
        end else begin
          s_axi_rdata <= {32'b0, m_axil_rdata};
        end
      end

      // AXI R handshake back to crossbar
      if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

endmodule
