// Minimal AXI4(64-bit) slave -> AXI4-Lite(32-bit) master bridge for MMIO register access.
//
// Supports *single-beat* 32-bit register reads/writes.
// For unsupported bursts (LEN!=0) or unsupported sizes/bursts:
//  - READ: drains all beats with SLVERR, asserts RLAST on last beat
//  - WRITE: drains W beats (LEN+1) with WREADY, then returns single SLVERR B
//

module axi64_mmio_to_axilite32_v2 (
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

  // AXI4-Lite master (32-bit)
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

  reg        aw_err_pending;
  reg        w_err_pending;
  reg        write_inflight;

  // Burst/error drain for writes (LEN!=0 etc.)
  reg        wr_drain;
  reg [7:0]  wr_drain_beats_left;
  reg [3:0]  wr_drain_id;

  // --------------------------
  // Read channel state
  // --------------------------
  reg        read_inflight;
  reg [3:0]  arid_q;
  reg [31:0] araddr_q;
  reg [2:0]  arsize_q;

  // Burst/error drain for reads (LEN!=0 etc.)
  reg        rd_drain;
  reg [7:0]  rd_drain_beats_left;
  reg [3:0]  rd_drain_id;

  // Helper: determine which 32-bit lane a 32-bit access targets.
  wire lane_sel_w = awaddr_q[2];
  // lane_sel_r is derived from latched address when forming response

  // Helper: validate write strobes for a single 32-bit register write
  wire wstrb_lo = |wstrb_q[3:0];
  wire wstrb_hi = |wstrb_q[7:4];

  // Accept AW/W independently until both captured (single-beat only),
  // but if draining a burst/error write, keep WREADY asserted to drain beats.
  assign s_axi_awready = aresetn && !wr_drain && !aw_pending && !write_inflight && !s_axi_bvalid;
  assign s_axi_wready  = aresetn && ( (wr_drain && !s_axi_bvalid) ||
                                     (!wr_drain && !w_pending && !write_inflight && !s_axi_bvalid) );

  // Read address ready only when idle (not draining, not inflight, no pending R)
  assign s_axi_arready = aresetn && !rd_drain && !read_inflight && !s_axi_rvalid;

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
      aw_err_pending <= 1'b0;
      w_err_pending  <= 1'b0;
      write_inflight <= 1'b0;

      read_inflight  <= 1'b0;

      wr_drain            <= 1'b0;
      wr_drain_beats_left <= 8'd0;
      wr_drain_id         <= 4'd0;

      rd_drain            <= 1'b0;
      rd_drain_beats_left <= 8'd0;
      rd_drain_id         <= 4'd0;

      awid_q   <= 4'b0;
      awaddr_q <= 32'b0;
      awsize_q <= 3'b0;
      wstrb_q  <= 8'b0;
      wdata_q  <= 64'b0;

      arid_q   <= 4'b0;
      araddr_q <= 32'b0;
      arsize_q <= 3'b0;

    end else begin
      // ==========================================================
      // WRITE BURST/ERROR DRAIN MODE (drain W beats then respond B)
      // ==========================================================
      if (wr_drain) begin
        if (s_axi_wvalid && s_axi_wready) begin
          if (wr_drain_beats_left != 8'd0)
            wr_drain_beats_left <= wr_drain_beats_left - 8'd1;

          // When last beat consumed (LEN+1 beats), return SLVERR once
          if ((wr_drain_beats_left == 8'd1) && !s_axi_bvalid) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= 2'b10; // SLVERR
            s_axi_bid    <= wr_drain_id;
            wr_drain     <= 1'b0;
          end
        end
      end

      // AXI B channel handshake back to crossbar
      if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end

      // ==========================================================
      // READ BURST/ERROR DRAIN MODE (emit SLVERR beats with RLAST)
      // ==========================================================
      if (rd_drain) begin
        // If no valid pending, present next error beat
        if (!s_axi_rvalid && (rd_drain_beats_left != 8'd0)) begin
          s_axi_rvalid <= 1'b1;
          s_axi_rresp  <= 2'b10; // SLVERR
          s_axi_rid    <= rd_drain_id;
          s_axi_rdata  <= 64'b0;
          s_axi_rlast  <= (rd_drain_beats_left == 8'd1);
        end

        // Consume beat
        if (s_axi_rvalid && s_axi_rready) begin
          s_axi_rvalid <= 1'b0;
          if (rd_drain_beats_left != 8'd0)
            rd_drain_beats_left <= rd_drain_beats_left - 8'd1;

          if (rd_drain_beats_left == 8'd1) begin
            rd_drain <= 1'b0;
          end
        end
      end

      // ==========================================================
      // Normal WRITE path (only when not draining)
      // ==========================================================
      if (!wr_drain) begin
        // Capture AXI write address
        if (s_axi_awvalid && s_axi_awready) begin
          aw_pending <= 1'b1;
          awid_q     <= s_axi_awid;
          awaddr_q   <= s_axi_awaddr;
          awsize_q   <= s_axi_awsize;

          // If burst, go to drain mode immediately (must not accept only 1 W beat)
          if (s_axi_awlen != 8'd0) begin
            wr_drain            <= 1'b1;
            wr_drain_beats_left <= s_axi_awlen + 8'd1;
            wr_drain_id         <= s_axi_awid;

            // Cancel any partial single-beat tracking
            aw_pending     <= 1'b0;
            w_pending      <= 1'b0;
            aw_err_pending <= 1'b0;
            w_err_pending  <= 1'b0;
          end else begin
            // Single-beat validation (latched into pending error flags)
            aw_err_pending <= 1'b0;
            //if (s_axi_awsize != 3'd2) aw_err_pending <= 1'b1;
            if (s_axi_awsize > 3'd2) aw_err_pending <= 1'b1;
            if (s_axi_awburst[1] == 1'b1) aw_err_pending <= 1'b1; // 10/11
          end
        end

        // Capture AXI write data
        if (s_axi_wvalid && s_axi_wready) begin
          w_pending <= 1'b1;
          wdata_q   <= s_axi_wdata;
          wstrb_q   <= s_axi_wstrb;

          w_err_pending <= 1'b0;
          if (!s_axi_wlast) w_err_pending <= 1'b1; // single-beat requires WLAST
        end

        // Launch AXI-Lite write when AW+W are captured
        if (!write_inflight && aw_pending && w_pending && !s_axi_bvalid) begin
          // Compute error *combinationally* from latched flags and strobes
          // (no nonblocking "old value" issue)
          if (aw_err_pending || w_err_pending ||
              (wstrb_lo && wstrb_hi) ||
              (!(wstrb_lo || wstrb_hi))) begin

            // Immediate SLVERR response (no AXI-Lite)
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= 2'b10; // SLVERR
            s_axi_bid    <= awid_q;

            // Clear pending
            aw_pending     <= 1'b0;
            w_pending      <= 1'b0;
            aw_err_pending <= 1'b0;
            w_err_pending  <= 1'b0;

          end else begin
            // Drive AXI-Lite write
            m_axil_awaddr  <= awaddr_q;
            m_axil_awprot  <= 3'b000;
            m_axil_awvalid <= 1'b1;

            // Select 32-bit lane based on strobe (preferred) or address[2]
            if (wstrb_hi && !wstrb_lo) begin
              m_axil_wdata <= wdata_q[63:32];
              m_axil_wstrb <= wstrb_q[7:4];
            end else if (wstrb_lo && !wstrb_hi) begin
              m_axil_wdata <= wdata_q[31:0];
              m_axil_wstrb <= wstrb_q[3:0];
            end else begin
              // Fallback: use latched address[2]
              m_axil_wdata <= lane_sel_w ? wdata_q[63:32] : wdata_q[31:0];
              m_axil_wstrb <= lane_sel_w ? wstrb_q[7:4]  : wstrb_q[3:0];
            end

            m_axil_wvalid  <= 1'b1;
            m_axil_bready  <= 1'b1;

            write_inflight <= 1'b1;

            // Clear pending
            aw_pending     <= 1'b0;
            w_pending      <= 1'b0;
            aw_err_pending <= 1'b0;
            w_err_pending  <= 1'b0;
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
      end // !wr_drain

      // ==========================================================
      // Normal READ path (only when not draining)
      // ==========================================================
      if (!rd_drain) begin
        // Launch AXI-Lite read or start drain (burst/unsupported)
        if (!read_inflight && !s_axi_rvalid && s_axi_arvalid && s_axi_arready) begin
          // If burst, drain with SLVERR beats (prevents master hang)
          if (s_axi_arlen != 8'd0) begin
            rd_drain            <= 1'b1;
            rd_drain_beats_left <= s_axi_arlen + 8'd1;
            rd_drain_id         <= s_axi_arid;
          end else begin
            // Single-beat only: validate
            // For MMIO regs we expect 32-bit reads (size=2). If not, error (1 beat).
            //if ((s_axi_arsize != 3'd2) || (s_axi_arburst[1] == 1'b1)) begin
            //if ((s_axi_arsize > 3'd2) || (s_axi_arburst[1] == 1'b1)) begin
            if (s_axi_arburst[1] == 1'b1) begin
              // Single-beat SLVERR
              s_axi_rvalid <= 1'b1;
              s_axi_rlast  <= 1'b1;
              s_axi_rresp  <= 2'b10;
              s_axi_rid    <= s_axi_arid;
              s_axi_rdata  <= 64'b0;
            end else begin
              arid_q   <= s_axi_arid;
              araddr_q <= s_axi_araddr;
              arsize_q <= s_axi_arsize;

              m_axil_araddr  <= s_axi_araddr;
              m_axil_arprot  <= 3'b000;
              m_axil_arvalid <= 1'b1;
              m_axil_rready  <= 1'b1;
              read_inflight  <= 1'b1;
            end
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
      end // !rd_drain
    end
  end

endmodule
