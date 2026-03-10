`timescale 1ns/1ps


module liteEthRGMIIAxiWrap #(
  // These MUST match the hard-coded buffer decode inside liteEthAXIRgmii.v
  parameter logic [31:0] RX_BASE   = 32'h100D0000,
  parameter logic [31:0] TX_BASE   = 32'h100D1000,
  parameter logic [31:0] BUF_SIZE  = 32'h00001000,  // 4KB each

  // SoC-visible CSR base (translated down to 0x0000_xxxx for LiteEth CSR path)
  parameter logic [31:0] CSR_BASE  = 32'h100D2000,
  parameter logic [31:0] CSR_SIZE  = 32'h00010000,  // 64KB

  // IDELAYCTRL settings
  parameter int          IDELAY_RST_CYCLES = 6      // shift-register length
)(
  // BUS clock/reset for AXI/MMIO + LiteEth sys_clock
  input  logic        bus_clk,
  input  logic        bus_resetn,      // active-low

  // IDELAYCTRL reference clock and "valid" qualifier (MMCM lock, etc.)
  input  logic        clk200,          // 200 MHz reference clock for IDELAYCTRL
  input  logic        clk200_locked,   // 1 when clk200 is stable (tie 1'b1 if you insist)

  // ------------------------------------------------------------
  // AXI4 (64-bit) SLAVE interface (connect to crossbar Mxx)
  // ------------------------------------------------------------
  input  logic [3:0]  s_axi_awid,
  input  logic [31:0] s_axi_awaddr,
  input  logic [7:0]  s_axi_awlen,
  input  logic [2:0]  s_axi_awsize,
  input  logic [1:0]  s_axi_awburst,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,

  input  logic [63:0] s_axi_wdata,
  input  logic [7:0]  s_axi_wstrb,
  input  logic        s_axi_wlast,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,

  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  output logic [3:0]  s_axi_bid,
  input  logic        s_axi_bready,

  input  logic [3:0]  s_axi_arid,
  input  logic [31:0] s_axi_araddr,
  input  logic [7:0]  s_axi_arlen,
  input  logic [2:0]  s_axi_arsize,
  input  logic [1:0]  s_axi_arburst,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,

  output logic [63:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rlast,
  output logic        s_axi_rvalid,
  output logic [3:0]  s_axi_rid,
  input  logic        s_axi_rready,

  // ------------------------------------------------------------
  // LiteEth PHY pins
  // ------------------------------------------------------------
  input  logic        rgmii_clocks_rx,
  output logic        rgmii_clocks_tx,
  input  logic        rgmii_int_n,
  output logic        rgmii_mdc,
  inout  wire         rgmii_mdio,
  output logic        rgmii_rst_n,
  input  logic        rgmii_rx_ctl,
  input  logic [3:0]  rgmii_rx_data,
  output logic        rgmii_tx_ctl,
  output logic [3:0]  rgmii_tx_data,

  // Raw interrupt from LiteEth (BUSCLK domain). CDC belongs in SoC top.
  output logic        interrupt
);

  // ===========================================================================
  // IDELAYCTRL (for IDELAYE2 used inside liteEthAXIRgmii.v)
  // ===========================================================================
  wire clk200_bufg;
  BUFG u_bufg_clk200 (.I(clk200), .O(clk200_bufg));

  // Reset sequencing in clk200 domain:
  // - async assert if bus_resetn deasserts (low) OR clk200_locked drops
  // - sync deassert after IDELAY_RST_CYCLES cycles
  logic [IDELAY_RST_CYCLES-1:0] idelay_rst_sr;

  always_ff @(posedge clk200_bufg or negedge bus_resetn or negedge clk200_locked) begin
    if (!bus_resetn || !clk200_locked)
      idelay_rst_sr <= {IDELAY_RST_CYCLES{1'b1}};
    else
      idelay_rst_sr <= {idelay_rst_sr[IDELAY_RST_CYCLES-2:0], 1'b0};
  end

  wire idelayctrl_rst = idelay_rst_sr[IDELAY_RST_CYCLES-1];

  // Attribute is set on IDELAYCTRL; this matches what you already had in top.
  (* IODELAY_GROUP = "ETH_RGMII" *)
  IDELAYCTRL u_idelayctrl_eth (
    .REFCLK(clk200_bufg),
    .RST   (idelayctrl_rst),
    .RDY   ()
  );

  // ===========================================================================
  // AXI4->AXI-Lite signals (adapter master side)
  // ===========================================================================
  logic [31:0] axil_awaddr;
  logic [2:0]  axil_awprot;
  logic        axil_awvalid;
  logic        axil_awready;

  logic [31:0] axil_wdata;
  logic [3:0]  axil_wstrb;
  logic        axil_wvalid;
  logic        axil_wready;

  logic [1:0]  axil_bresp;
  logic        axil_bvalid;
  logic        axil_bready;

  logic [31:0] axil_araddr;
  logic [2:0]  axil_arprot;
  logic        axil_arvalid;
  logic        axil_arready;

  logic [31:0] axil_rdata;
  logic [1:0]  axil_rresp;
  logic        axil_rvalid;
  logic        axil_rready;

  // ===========================================================================
  // AXI-Lite shim -> LiteEth core bus_*
  // ===========================================================================
  logic [31:0] core_awaddr;
  logic [2:0]  core_awprot;
  logic        core_awvalid;
  logic        core_awready;

  logic [31:0] core_wdata;
  logic [3:0]  core_wstrb;
  logic        core_wvalid;
  logic        core_wready;

  logic [1:0]  core_bresp;
  logic        core_bvalid;
  logic        core_bready;

  logic [31:0] core_araddr;

  logic [2:0]  core_arprot;
  logic        core_arvalid;
  logic        core_arready;

  logic [31:0] core_rdata;
  logic [1:0]  core_rresp;
  logic        core_rvalid;
  logic        core_rready;


  // ===========================================
  // 64-bit AXI4 MMIO -> 32-bit AXI-Lite adapter
  // ===========================================
  //axi64_mmio_to_axilite32_v2 u_axi64_to_axil (
  axi64_to_axil_adapter_split #(
    .BUF_BASE(RX_BASE),
    .BUF_END(TX_BASE + BUF_SIZE)
  )  u_axi64_to_axil (
    .aclk          (bus_clk),
    .aresetn       (bus_resetn),

    .s_axi_awid    (s_axi_awid),
    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awlen   (s_axi_awlen),
    .s_axi_awsize  (s_axi_awsize),
    .s_axi_awburst (s_axi_awburst),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),

    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wstrb   (s_axi_wstrb),
    .s_axi_wlast   (s_axi_wlast),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),

    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bid     (s_axi_bid),
    .s_axi_bready  (s_axi_bready),

    .s_axi_arid    (s_axi_arid),
    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arlen   (s_axi_arlen),
    .s_axi_arsize  (s_axi_arsize),
    .s_axi_arburst (s_axi_arburst),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),

    .s_axi_rdata   (s_axi_rdata),
    .s_axi_rresp   (s_axi_rresp),
    .s_axi_rlast   (s_axi_rlast),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rid     (s_axi_rid),
    .s_axi_rready  (s_axi_rready),

    .m_axil_awaddr (axil_awaddr),
    .m_axil_awprot (axil_awprot),
    .m_axil_awvalid(axil_awvalid),
    .m_axil_awready(axil_awready),

    .m_axil_wdata  (axil_wdata),
    .m_axil_wstrb  (axil_wstrb),
    .m_axil_wvalid (axil_wvalid),
    .m_axil_wready (axil_wready),

    .m_axil_bresp  (axil_bresp),
    .m_axil_bvalid (axil_bvalid),
    .m_axil_bready (axil_bready),

    .m_axil_araddr (axil_araddr),
    .m_axil_arprot (axil_arprot),
    .m_axil_arvalid(axil_arvalid),
    .m_axil_arready(axil_arready),

    .m_axil_rdata  (axil_rdata),
    .m_axil_rresp  (axil_rresp),
    .m_axil_rvalid (axil_rvalid),
    .m_axil_rready (axil_rready)
  );

  // ===========================================================================
  // AXI-Lite shim: CSR base-translate + buffer byte-swap (for RX/TX buffers only)
  // ===========================================================================
  liteeth_axil_shim #(
    .RX_BASE (RX_BASE),
    .TX_BASE (TX_BASE),
    .BUF_SIZE(BUF_SIZE),
    .CSR_BASE(CSR_BASE),
    .CSR_SIZE(CSR_SIZE)
  ) u_axil_shim (
    .aclk    (bus_clk),
    .aresetn (bus_resetn),

    .s_awaddr (axil_awaddr),
    .s_awprot (axil_awprot),
    .s_awvalid(axil_awvalid),
    .s_awready(axil_awready),

    .s_wdata  (axil_wdata),
    .s_wstrb  (axil_wstrb),
    .s_wvalid (axil_wvalid),
    .s_wready (axil_wready),

    .s_bresp  (axil_bresp),
    .s_bvalid (axil_bvalid),
    .s_bready (axil_bready),

    .s_araddr (axil_araddr),
    .s_arprot (axil_arprot),
    .s_arvalid(axil_arvalid),
    .s_arready(axil_arready),

    .s_rdata  (axil_rdata),
    .s_rresp  (axil_rresp),
    .s_rvalid (axil_rvalid),
    .s_rready (axil_rready),

    .m_awaddr (core_awaddr),
    .m_awprot (core_awprot),
    .m_awvalid(core_awvalid),
    .m_awready(core_awready),

    .m_wdata  (core_wdata),
    .m_wstrb  (core_wstrb),
    .m_wvalid (core_wvalid),
    .m_wready (core_wready),

    .m_bresp  (core_bresp),
    .m_bvalid (core_bvalid),
    .m_bready (core_bready),

    .m_araddr (core_araddr),
    .m_arprot (core_arprot),
    .m_arvalid(core_arvalid),
    .m_arready(core_arready),

    .m_rdata  (core_rdata),
    .m_rresp  (core_rresp),
    .m_rvalid (core_rvalid),
    .m_rready (core_rready)
  );

  // ===========================================================================
  // LiteEth core (generated)
  // ===========================================================================
  liteEthAXIRgmii u_liteeth (
    .bus_araddr (core_araddr),
    .bus_arprot (core_arprot),
    .bus_arready(core_arready),
    .bus_arvalid(core_arvalid),

    .bus_awaddr (core_awaddr),
    .bus_awprot (core_awprot),
    .bus_awready(core_awready),
    .bus_awvalid(core_awvalid),

    .bus_bready (core_bready),
    .bus_bresp  (core_bresp),
    .bus_bvalid (core_bvalid),

    .bus_rdata  (core_rdata),
    .bus_rready (core_rready),
    .bus_rresp  (core_rresp),
    .bus_rvalid (core_rvalid),

    .bus_wdata  (core_wdata),
    .bus_wready (core_wready),
    .bus_wstrb  (core_wstrb),
    .bus_wvalid (core_wvalid),

    .interrupt  (interrupt),

    .rgmii_clocks_rx(rgmii_clocks_rx),
    .rgmii_clocks_tx(rgmii_clocks_tx),
    .rgmii_int_n    (rgmii_int_n),
    .rgmii_mdc      (rgmii_mdc),
    .rgmii_mdio     (rgmii_mdio),
    .rgmii_rst_n    (rgmii_rst_n),
    .rgmii_rx_ctl   (rgmii_rx_ctl),
    .rgmii_rx_data  (rgmii_rx_data),
    .rgmii_tx_ctl   (rgmii_tx_ctl),
    .rgmii_tx_data  (rgmii_tx_data),

    .sys_clock (bus_clk),
    .sys_reset (~bus_resetn) // LiteEth expects active-high sys_reset
  );

endmodule


// ============================================================================
// AXI-Lite shim module (CSR translate + buffer swap)
// - Supports single outstanding read, single outstanding write.
// - Correctly pairs AW and W even if they arrive in different cycles.
// ============================================================================
module liteeth_axil_shim #(
  parameter logic [31:0] RX_BASE   = 32'h100D0000,
  parameter logic [31:0] TX_BASE   = 32'h100D1000,
  parameter logic [31:0] BUF_SIZE  = 32'h00001000,
  parameter logic [31:0] CSR_BASE  = 32'h100D2000,
  parameter logic [31:0] CSR_SIZE  = 32'h00010000
)(
  input  logic        aclk,
  input  logic        aresetn,

  // Slave side (from adapter)
  input  logic [31:0] s_awaddr,
  input  logic [2:0]  s_awprot,
  input  logic        s_awvalid,
  output logic        s_awready,

  input  logic [31:0] s_wdata,
  input  logic [3:0]  s_wstrb,
  input  logic        s_wvalid,
  output logic        s_wready,

  output logic [1:0]  s_bresp,
  output logic        s_bvalid,
  input  logic        s_bready,

  input  logic [31:0] s_araddr,
  input  logic [2:0]  s_arprot,
  input  logic        s_arvalid,
  output logic        s_arready,

  output logic [31:0] s_rdata,
  output logic [1:0]  s_rresp,
  output logic        s_rvalid,
  input  logic        s_rready,

  // Master side (to LiteEth core)
  output logic [31:0] m_awaddr,
  output logic [2:0]  m_awprot,
  output logic        m_awvalid,
  input  logic        m_awready,

  output logic [31:0] m_wdata,
  output logic [3:0]  m_wstrb,
  output logic        m_wvalid,
  input  logic        m_wready,

  input  logic [1:0]  m_bresp,
  input  logic        m_bvalid,
  output logic        m_bready,

  output logic [31:0] m_araddr,
  output logic [2:0]  m_arprot,
  output logic        m_arvalid,
  input  logic        m_arready,

  input  logic [31:0] m_rdata,
  input  logic [1:0]  m_rresp,
  input  logic        m_rvalid,
  output logic        m_rready
);

  function automatic logic [31:0] bswap32(input logic [31:0] x);
    bswap32 = {x[7:0], x[15:8], x[23:16], x[31:24]};
  endfunction

  function automatic logic [3:0] bswap_strb(input logic [3:0] s);
    // Out[3] corresponds to in[0] when bytes are swapped, etc.
    bswap_strb = {s[0], s[1], s[2], s[3]};
  endfunction

  function automatic logic is_buf_addr(input logic [31:0] a);
    is_buf_addr = ((a >= RX_BASE) && (a < (RX_BASE + BUF_SIZE))) ||
                  ((a >= TX_BASE) && (a < (TX_BASE + BUF_SIZE)));
  endfunction

  function automatic logic [31:0] map_addr(input logic [31:0] a);
    if ((a >= CSR_BASE) && (a < (CSR_BASE + CSR_SIZE)))
      map_addr = a - CSR_BASE;  // CSR -> 0x0000_xxxx
    else
      map_addr = a;             // buffers stay absolute (LiteEth hard decode)
  endfunction

  // -----------------------
  // WRITE: pair AW and W, then forward to core, then pass B back
  // -----------------------
  typedef enum logic [1:0] {WR_IDLE, WR_SEND, WR_WAITB} wr_state_e;
  wr_state_e wr_state;

  logic        have_aw, have_w;
  logic [31:0] aw_addr_q;
  logic [2:0]  aw_prot_q;
  logic        aw_is_buf_q;
  logic [31:0] w_data_q;
  logic [3:0]  w_strb_q;

  wire aw_fire = s_awvalid && s_awready;
  wire w_fire  = s_wvalid  && s_wready;

  // Ready to accept AW/W only while idle and we don't already have that piece
  always_comb begin
    s_awready = (wr_state == WR_IDLE) && !have_aw;
    s_wready  = (wr_state == WR_IDLE) && !have_w;
  end

  // Drive core write address/data from latched values
  always_comb begin
    m_awaddr  = map_addr(aw_addr_q);
    m_awprot  = aw_prot_q;

    m_wdata   = aw_is_buf_q ? bswap32(w_data_q) : w_data_q;
    m_wstrb   = aw_is_buf_q ? bswap_strb(w_strb_q) : w_strb_q;
  end

  // Default signals (registered valids)
  // B channel pass-through while waiting
  always_comb begin
    s_bvalid = (wr_state == WR_WAITB) ? m_bvalid : 1'b0;
    s_bresp  = m_bresp;
    m_bready = (wr_state == WR_WAITB) ? s_bready : 1'b0;
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      wr_state   <= WR_IDLE;
      have_aw    <= 1'b0;
      have_w     <= 1'b0;
      aw_addr_q  <= 32'd0;
      aw_prot_q  <= 3'd0;
      aw_is_buf_q<= 1'b0;
      w_data_q   <= 32'd0;
      w_strb_q   <= 4'd0;
      m_awvalid  <= 1'b0;
      m_wvalid   <= 1'b0;
    end else begin
      case (wr_state)
        WR_IDLE: begin
          // capture AW/W independently
          if (aw_fire) begin
            have_aw     <= 1'b1;
            aw_addr_q   <= s_awaddr;
            aw_prot_q   <= s_awprot;
            aw_is_buf_q <= is_buf_addr(s_awaddr);
          end
          if (w_fire) begin
            have_w   <= 1'b1;
            w_data_q <= s_wdata;
            w_strb_q <= s_wstrb;
          end

          // start sending once both captured (including same-cycle capture)
          if ((have_aw || aw_fire) && (have_w || w_fire)) begin
            wr_state  <= WR_SEND;
            m_awvalid <= 1'b1;
            m_wvalid  <= 1'b1;
          end
        end

        WR_SEND: begin
          if (m_awvalid && m_awready)
            m_awvalid <= 1'b0;

          if (m_wvalid && m_wready)
            m_wvalid <= 1'b0;

          // once both accepted by core, wait for response
          if ((m_awvalid == 1'b0) && (m_wvalid == 1'b0)) begin
            wr_state <= WR_WAITB;
          end
        end

        WR_WAITB: begin
          // complete when B handshakes back to slave
          if (m_bvalid && s_bready) begin
            wr_state <= WR_IDLE;
            have_aw  <= 1'b0;
            have_w   <= 1'b0;
          end
        end

        default: wr_state <= WR_IDLE;
      endcase
    end
  end

  // -----------------------
  // READ: single outstanding; remember if buffer (swap) until R
  // -----------------------
  typedef enum logic [1:0] {RD_IDLE, RD_SEND, RD_WAITR} rd_state_e;
  rd_state_e rd_state;

  logic [31:0] ar_addr_q;
  logic [2:0]  ar_prot_q;
  logic        ar_is_buf_q;

  wire ar_fire = s_arvalid && s_arready;

  always_comb begin
    s_arready = (rd_state == RD_IDLE);

    m_araddr  = map_addr(ar_addr_q);
    m_arprot  = ar_prot_q;

    s_rvalid  = (rd_state == RD_WAITR) ? m_rvalid : 1'b0;
    s_rresp   = m_rresp;
    s_rdata   = ar_is_buf_q ? bswap32(m_rdata) : m_rdata;

    m_rready  = (rd_state == RD_WAITR) ? s_rready : 1'b0;
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      rd_state   <= RD_IDLE;
      ar_addr_q  <= 32'd0;
      ar_prot_q  <= 3'd0;
      ar_is_buf_q<= 1'b0;
      m_arvalid  <= 1'b0;
    end else begin
      case (rd_state)
        RD_IDLE: begin
          if (ar_fire) begin
            ar_addr_q   <= s_araddr;
            ar_prot_q   <= s_arprot;
            ar_is_buf_q <= is_buf_addr(s_araddr);
            m_arvalid   <= 1'b1;
            rd_state    <= RD_SEND;
          end
        end

        RD_SEND: begin
          if (m_arvalid && m_arready) begin
            m_arvalid <= 1'b0;
            rd_state  <= RD_WAITR;
          end
        end

        RD_WAITR: begin
          if (m_rvalid && s_rready) begin
            rd_state <= RD_IDLE;
          end
        end

        default: rd_state <= RD_IDLE;
      endcase
    end
  end

endmodule
