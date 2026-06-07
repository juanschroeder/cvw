// Minimal AXI4 slave -> AXI4-Lite(32-bit) master bridge for MMIO register access.
//
// Supports *single-beat* 32-bit register reads/writes on a 32-bit or 64-bit AXI
// slave port.
// For unsupported bursts (LEN!=0) or unsupported sizes/bursts:
//  - READ: drains all beats with SLVERR, asserts RLAST on last beat
//  - WRITE: drains W beats (LEN+1) with WREADY, then returns single SLVERR B
//

module axi_mmio_to_axilite32_v3 #(
  parameter int unsigned AXI_ADDR_WIDTH = 32,
  parameter int unsigned AXI_DATA_WIDTH = 64,
  parameter int unsigned AXI_ID_WIDTH   = 4
) (
  input  wire                         aclk,
  input  wire                         aresetn,

  // AXI4 slave
  input  wire [AXI_ID_WIDTH-1:0]      s_axi_awid,
  input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
  input  wire [7:0]                   s_axi_awlen,
  input  wire [2:0]                   s_axi_awsize,
  input  wire [1:0]                   s_axi_awburst,
  input  wire                         s_axi_awvalid,
  output wire                         s_axi_awready,

  input  wire [AXI_DATA_WIDTH-1:0]    s_axi_wdata,
  input  wire [AXI_DATA_WIDTH/8-1:0]  s_axi_wstrb,
  input  wire                         s_axi_wlast,
  input  wire                         s_axi_wvalid,
  output wire                         s_axi_wready,

  output reg  [1:0]                   s_axi_bresp,
  output reg                          s_axi_bvalid,
  output reg  [AXI_ID_WIDTH-1:0]      s_axi_bid,
  input  wire                         s_axi_bready,

  input  wire [AXI_ID_WIDTH-1:0]      s_axi_arid,
  input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
  input  wire [7:0]                   s_axi_arlen,
  input  wire [2:0]                   s_axi_arsize,
  input  wire [1:0]                   s_axi_arburst,
  input  wire                         s_axi_arvalid,
  output wire                         s_axi_arready,

  output reg  [AXI_DATA_WIDTH-1:0]    s_axi_rdata,
  output reg  [1:0]                   s_axi_rresp,
  output reg                          s_axi_rlast,
  output reg                          s_axi_rvalid,
  output reg  [AXI_ID_WIDTH-1:0]      s_axi_rid,
  input  wire                         s_axi_rready,

  // AXI4-Lite master (32-bit data)
  output reg  [AXI_ADDR_WIDTH-1:0]    m_axil_awaddr,
  output reg  [2:0]                   m_axil_awprot,
  output reg                          m_axil_awvalid,
  input  wire                         m_axil_awready,

  output reg  [31:0]                  m_axil_wdata,
  output reg  [3:0]                   m_axil_wstrb,
  output reg                          m_axil_wvalid,
  input  wire                         m_axil_wready,

  input  wire [1:0]                   m_axil_bresp,
  input  wire                         m_axil_bvalid,
  output reg                          m_axil_bready,

  output reg  [AXI_ADDR_WIDTH-1:0]    m_axil_araddr,
  output reg  [2:0]                   m_axil_arprot,
  output reg                          m_axil_arvalid,
  input  wire                         m_axil_arready,

  input  wire [31:0]                  m_axil_rdata,
  input  wire [1:0]                   m_axil_rresp,
  input  wire                         m_axil_rvalid,
  output reg                          m_axil_rready
);

  localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

  if ((AXI_DATA_WIDTH != 32) && (AXI_DATA_WIDTH != 64)) begin : gen_bad_axi_width
    initial $fatal(1, "axi_mmio_to_axilite32_v3 supports AXI_DATA_WIDTH 32 or 64, got %0d", AXI_DATA_WIDTH);
  end

  // --------------------------
  // Write channel state
  // --------------------------
  reg                         aw_pending;
  reg                         w_pending;
  reg [AXI_ID_WIDTH-1:0]      awid_q;
  reg [AXI_ADDR_WIDTH-1:0]    awaddr_q;
  reg [2:0]                   awsize_q;
  reg [7:0]                   wstrb_q;
  reg [63:0]                  wdata_q;

  reg                         aw_err_pending;
  reg                         w_err_pending;
  reg                         write_inflight;

  // Burst/error drain for writes (LEN!=0 etc.)
  reg                         wr_drain;
  reg [7:0]                   wr_drain_beats_left;
  reg [AXI_ID_WIDTH-1:0]      wr_drain_id;

  // --------------------------
  // Read channel state
  // --------------------------
  reg                         read_inflight;
  reg [AXI_ID_WIDTH-1:0]      arid_q;
  reg [AXI_ADDR_WIDTH-1:0]    araddr_q;
  reg [2:0]                   arsize_q;

  // Burst/error drain for reads (LEN!=0 etc.)
  reg                         rd_drain;
  reg [7:0]                   rd_drain_beats_left;
  reg [AXI_ID_WIDTH-1:0]      rd_drain_id;

  wire [63:0] wdata_padded = {{(64-AXI_DATA_WIDTH){1'b0}}, s_axi_wdata};
  wire [7:0]  wstrb_padded = {{(8-AXI_STRB_WIDTH){1'b0}}, s_axi_wstrb};

  // Helper: determine which 32-bit lane a 32-bit access targets.
  wire lane_sel_w = (AXI_DATA_WIDTH == 64) && awaddr_q[2];
  wire lane_sel_r = (AXI_DATA_WIDTH == 64) && araddr_q[2];

  // Helper: validate write strobes for a single 32-bit register write.
  wire wstrb_lo = |wstrb_q[3:0];
  wire wstrb_hi = |wstrb_q[7:4];

  wire [AXI_DATA_WIDTH-1:0] axil_rdata_to_axi =
      {{(AXI_DATA_WIDTH-32){1'b0}}, m_axil_rdata} << (lane_sel_r ? 32 : 0);

  // Accept AW/W independently until both captured (single-beat only),
  // but if draining a burst/error write, keep WREADY asserted to drain beats.
  assign s_axi_awready = aresetn && !wr_drain && !aw_pending && !write_inflight && !s_axi_bvalid;
  assign s_axi_wready  = aresetn && ((wr_drain && !s_axi_bvalid) ||
                                     (!wr_drain && !w_pending && !write_inflight && !s_axi_bvalid));

  // Read address ready only when idle (not draining, not inflight, no pending R).
  assign s_axi_arready = aresetn && !rd_drain && !read_inflight && !s_axi_rvalid;

  // --------------------------
  // Sequential logic
  // --------------------------
  always @(posedge aclk) begin
    if (!aresetn) begin
      // AXI slave responses
      s_axi_bvalid <= 1'b0;
      s_axi_bresp  <= 2'b00;
      s_axi_bid    <= '0;

      s_axi_rvalid <= 1'b0;
      s_axi_rresp  <= 2'b00;
      s_axi_rdata  <= '0;
      s_axi_rid    <= '0;
      s_axi_rlast  <= 1'b1;

      // AXI-Lite master
      m_axil_awvalid <= 1'b0;
      m_axil_wvalid  <= 1'b0;
      m_axil_bready  <= 1'b0;
      m_axil_arvalid <= 1'b0;
      m_axil_rready  <= 1'b0;
      m_axil_awaddr  <= '0;
      m_axil_awprot  <= 3'b000;
      m_axil_wdata   <= 32'b0;
      m_axil_wstrb   <= 4'b0;
      m_axil_araddr  <= '0;
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
      wr_drain_id         <= '0;
      rd_drain            <= 1'b0;
      rd_drain_beats_left <= 8'd0;
      rd_drain_id         <= '0;

      awid_q   <= '0;
      awaddr_q <= '0;
      awsize_q <= 3'b0;
      wstrb_q  <= 8'b0;
      wdata_q  <= 64'b0;
      arid_q   <= '0;
      araddr_q <= '0;
      arsize_q <= 3'b0;
    end else begin
      // ==========================================================
      // WRITE BURST/ERROR DRAIN MODE (drain W beats then respond B)
      // ==========================================================
      if (wr_drain) begin
        if (s_axi_wvalid && s_axi_wready) begin
          if (wr_drain_beats_left != 8'd0)
            wr_drain_beats_left <= wr_drain_beats_left - 8'd1;

          // When last beat consumed (LEN+1 beats), return SLVERR once.
          if ((wr_drain_beats_left == 8'd1) && !s_axi_bvalid) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= 2'b10; // SLVERR
            s_axi_bid    <= wr_drain_id;
            wr_drain     <= 1'b0;
          end
        end
      end

      // AXI B channel handshake back to crossbar.
      if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end

      // ==========================================================
      // READ BURST/ERROR DRAIN MODE (emit SLVERR beats with RLAST)
      // ==========================================================
      if (rd_drain) begin
        // If no valid pending, present next error beat.
        if (!s_axi_rvalid && (rd_drain_beats_left != 8'd0)) begin
          s_axi_rvalid <= 1'b1;
          s_axi_rresp  <= 2'b10; // SLVERR
          s_axi_rid    <= rd_drain_id;
          s_axi_rdata  <= '0;
          s_axi_rlast  <= (rd_drain_beats_left == 8'd1);
        end

        // Consume beat.
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
        // Capture AXI write address.
        if (s_axi_awvalid && s_axi_awready) begin
          aw_pending <= 1'b1;
          awid_q     <= s_axi_awid;
          awaddr_q   <= s_axi_awaddr;
          awsize_q   <= s_axi_awsize;

          // If burst, go to drain mode immediately (must not accept only 1 W beat).
          if (s_axi_awlen != 8'd0) begin
            wr_drain            <= 1'b1;
            wr_drain_beats_left <= s_axi_awlen + 8'd1;
            wr_drain_id         <= s_axi_awid;

            // Cancel any partial single-beat tracking.
            aw_pending          <= 1'b0;
            w_pending           <= 1'b0;
            aw_err_pending      <= 1'b0;
            w_err_pending       <= 1'b0;
          end else begin
            // Single-beat validation (latched into pending error flags).
            aw_err_pending <= 1'b0;
            if (s_axi_awsize > 3'd2) aw_err_pending <= 1'b1;
            if (s_axi_awburst[1]) aw_err_pending <= 1'b1; // 10/11
          end
        end

        // Capture AXI write data.
        if (s_axi_wvalid && s_axi_wready) begin
          w_pending <= 1'b1;
          wdata_q   <= wdata_padded;
          wstrb_q   <= wstrb_padded;

          w_err_pending <= 1'b0;
          if (!s_axi_wlast) w_err_pending <= 1'b1;
        end

        // When both AW and W captured, either return SLVERR or issue AXI-Lite write.
        if (!write_inflight && aw_pending && w_pending && !s_axi_bvalid) begin
          if (aw_err_pending || w_err_pending ||
              (wstrb_lo && wstrb_hi) ||
              (!(wstrb_lo || wstrb_hi))) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= 2'b10; // SLVERR
            s_axi_bid    <= awid_q;

            aw_pending     <= 1'b0;
            w_pending      <= 1'b0;
            aw_err_pending <= 1'b0;
            w_err_pending  <= 1'b0;
          end else begin
            m_axil_awaddr  <= awaddr_q;
            m_axil_awprot  <= 3'b000;
            m_axil_awvalid <= 1'b1;

            m_axil_wdata  <= wdata_q[(lane_sel_w ? 32 : 0) +: 32];
            m_axil_wstrb  <= wstrb_q[(lane_sel_w ? 4 : 0) +: 4];
            m_axil_wvalid <= 1'b1;
            m_axil_bready <= 1'b1;

            write_inflight <= 1'b1;
            aw_pending     <= 1'b0;
            w_pending      <= 1'b0;
            aw_err_pending <= 1'b0;
            w_err_pending  <= 1'b0;
          end
        end

        // AXI-Lite address/data handshakes may complete independently.
        if (m_axil_awvalid && m_axil_awready) m_axil_awvalid <= 1'b0;
        if (m_axil_wvalid  && m_axil_wready)  m_axil_wvalid  <= 1'b0;

        // AXI-Lite write response becomes AXI B response.
        if (write_inflight && m_axil_bvalid && m_axil_bready) begin
          m_axil_bready  <= 1'b0;
          write_inflight <= 1'b0;

          s_axi_bvalid <= 1'b1;
          s_axi_bresp  <= m_axil_bresp;
          s_axi_bid    <= awid_q;
        end
      end

      // ==========================================================
      // Normal READ path (single-beat)
      // ==========================================================
      if (!rd_drain) begin
        if (!read_inflight && !s_axi_rvalid && s_axi_arvalid && s_axi_arready) begin
          // Burst read: drain with SLVERR beats.
          if (s_axi_arlen != 8'd0) begin
            rd_drain            <= 1'b1;
            rd_drain_beats_left <= s_axi_arlen + 8'd1;
            rd_drain_id         <= s_axi_arid;
          end else begin
            // Unsupported burst type: single SLVERR.
            if (s_axi_arburst[1]) begin
              s_axi_rvalid <= 1'b1;
              s_axi_rlast  <= 1'b1;
              s_axi_rresp  <= 2'b10; // SLVERR
              s_axi_rid    <= s_axi_arid;
              s_axi_rdata  <= '0;
            end else begin
              // Valid single-beat read: issue AXI-Lite read.
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

        // AXI-Lite read address accepted.
        if (m_axil_arvalid && m_axil_arready) begin
          m_axil_arvalid <= 1'b0;
        end

        // AXI-Lite read response becomes AXI R response.
        if (read_inflight && m_axil_rvalid && m_axil_rready) begin
          m_axil_rready <= 1'b0;
          read_inflight <= 1'b0;

          s_axi_rvalid <= 1'b1;
          s_axi_rlast  <= 1'b1;
          s_axi_rresp  <= m_axil_rresp;
          s_axi_rid    <= arid_q;
          s_axi_rdata  <= axil_rdata_to_axi;
        end

        // AXI R channel handshake back to crossbar.
        if (s_axi_rvalid && s_axi_rready) begin
          s_axi_rvalid <= 1'b0;
        end
      end
    end
  end

endmodule
