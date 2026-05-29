
// SpinalHDL OHCI wrapper for Core-V Wally integration (2 ports, 32/64-bit DMA).
// Instantiates: UsbOhciAxi4_p2_dma32 or UsbOhciAxi4_p2_dma64 (SpinalHDL-generated)
//
// Exposes:
//  * AXI4 slave "regs" (matches core: 32-bit data, 12-bit addr, 8-bit ID)
//  * AXI4 master "dma"  (32/64-bit data). Adds AXI ID/LOCK signals expected by many fabrics;
//    IDs are tied to a constant because the generated core has no DMA IDs.
//
// Resets:
//  * Inputs are active-LOW (common SoC style).
//  * Core expects async active-HIGH resets (posedge reset). Wrapper inverts.
//
// Optional DMA address modification (Cheshire-style):
//   dma_addr_mod = (DMA_ADDR_DOMAIN & ~DMA_ADDR_MASK) | (dma_addr & DMA_ADDR_MASK)

`timescale 1ns/1ps
//`default_nettype none

module usb_ohci_wrap #(
  // Cheshire-style address "domain|mask" (32-bit here, because the generated OHCI DMA address is 32-bit)
  parameter logic [31:0] DMA_ADDR_DOMAIN = 32'h0000_0000,
  parameter logic [31:0] DMA_ADDR_MASK   = 32'hFFFF_FFFF,

  // DMA AXI bus width. The generated OHCI core exists in 32-bit and 64-bit variants.
  parameter int unsigned DMA_AXI_DATA_WIDTH = 64,

  // DMA AXI ID handling (wrapper adds AXI IDs; core itself has none)
  parameter int unsigned DMA_AXI_ID_WIDTH = 4,
  parameter logic [DMA_AXI_ID_WIDTH-1:0] DMA_AXI_ID = '0
)(
  // -------------------------
  // Clocks / resets
  // -------------------------
  input  wire          ctrl_clk,
  input  wire          ctrl_aresetn,   // active-low
  input  wire          phy_clk,
  input  wire          phy_aresetn,    // active-low

  // -------------------------
  // Interrupt
  // -------------------------
  output wire          irq_o,

  // -------------------------
  // USB PHY pins (2 ports)
  // -------------------------
  inout  wire          usb0_dp,
  inout  wire          usb0_dm,
  inout  wire          usb1_dp,
  inout  wire          usb1_dm,

  // -------------------------
  // AXI4 SLAVE: control / regs (32-bit)
  // -------------------------
  input  wire          s_axi_awvalid,
  output wire          s_axi_awready,
  input  wire [11:0]   s_axi_awaddr,
  input  wire [7:0]    s_axi_awid,
  input  wire [7:0]    s_axi_awlen,
  input  wire [2:0]    s_axi_awsize,
  input  wire [1:0]    s_axi_awburst,
  input  wire          s_axi_awlock,
  input  wire [3:0]    s_axi_awcache,
  input  wire [2:0]    s_axi_awprot,
  input  wire [3:0]    s_axi_awqos,

  input  wire          s_axi_wvalid,
  output wire          s_axi_wready,
  input  wire [31:0]   s_axi_wdata,
  input  wire [3:0]    s_axi_wstrb,
  input  wire          s_axi_wlast,

  output wire          s_axi_bvalid,
  input  wire          s_axi_bready,
  output wire [7:0]    s_axi_bid,
  output wire [1:0]    s_axi_bresp,

  input  wire          s_axi_arvalid,
  output wire          s_axi_arready,
  input  wire [11:0]   s_axi_araddr,
  input  wire [7:0]    s_axi_arid,
  input  wire [7:0]    s_axi_arlen,
  input  wire [2:0]    s_axi_arsize,
  input  wire [1:0]    s_axi_arburst,
  input  wire          s_axi_arlock,
  input  wire [3:0]    s_axi_arcache,
  input  wire [2:0]    s_axi_arprot,
  input  wire [3:0]    s_axi_arqos,

  output wire          s_axi_rvalid,
  input  wire          s_axi_rready,
  output wire [31:0]   s_axi_rdata,
  output wire [7:0]    s_axi_rid,
  output wire [1:0]    s_axi_rresp,
  output wire          s_axi_rlast,

  // -------------------------
  // AXI4 MASTER: DMA to DDR (32/64-bit)
  // Wrapper adds ID/LOCK outputs expected by many fabrics; IDs are constant.
  // -------------------------
  output wire [DMA_AXI_ID_WIDTH-1:0] m_axi_awid,
  output wire          m_axi_awvalid,
  input  wire          m_axi_awready,
  output wire [31:0]   m_axi_awaddr,
  output wire [7:0]    m_axi_awlen,
  output wire [2:0]    m_axi_awsize,
  output wire [1:0]    m_axi_awburst,
  output wire          m_axi_awlock,
  output wire [3:0]    m_axi_awcache,
  output wire [2:0]    m_axi_awprot,

  output wire          m_axi_wvalid,
  input  wire          m_axi_wready,
  output wire [DMA_AXI_DATA_WIDTH-1:0]   m_axi_wdata,
  output wire [DMA_AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
  output wire          m_axi_wlast,

  input  wire [DMA_AXI_ID_WIDTH-1:0] m_axi_bid,   // ignored by core
  input  wire          m_axi_bvalid,
  output wire          m_axi_bready,
  input  wire [1:0]    m_axi_bresp,

  output wire [DMA_AXI_ID_WIDTH-1:0] m_axi_arid,
  output wire          m_axi_arvalid,
  input  wire          m_axi_arready,
  output wire [31:0]   m_axi_araddr,
  output wire [7:0]    m_axi_arlen,
  output wire [2:0]    m_axi_arsize,
  output wire [1:0]    m_axi_arburst,
  output wire          m_axi_arlock,
  output wire [3:0]    m_axi_arcache,
  output wire [2:0]    m_axi_arprot,

  input  wire [DMA_AXI_ID_WIDTH-1:0] m_axi_rid,   // ignored by core
  input  wire          m_axi_rvalid,
  output wire          m_axi_rready,
  input  wire [DMA_AXI_DATA_WIDTH-1:0]   m_axi_rdata,
  input  wire [1:0]    m_axi_rresp,
  input  wire          m_axi_rlast
);

  // -------------------------
  // Reset polarity conversion
  // -------------------------
  wire ctrl_reset = ~ctrl_aresetn; // active-high, async in core
  wire phy_reset  = ~phy_aresetn;  // active-high, async in core

  if ((DMA_AXI_DATA_WIDTH != 32) && (DMA_AXI_DATA_WIDTH != 64)) begin : gen_bad_dma_width
    initial $fatal(1, "usb_ohci_wrap supports DMA_AXI_DATA_WIDTH 32 or 64, got %0d", DMA_AXI_DATA_WIDTH);
  end

  // -------------------------
  // USB inout -> core DP/DM read/write/oe
  // -------------------------
  (* keep = "true", mark_debug = "true" *) wire usb0_dp_read, usb0_dm_read, usb1_dp_read, usb1_dm_read;
  (* keep = "true", mark_debug = "true" *) wire usb0_dp_write, usb0_dm_write, usb1_dp_write, usb1_dm_write;
  (* keep = "true", mark_debug = "true" *) wire usb0_dp_oe,    usb0_dm_oe,    usb1_dp_oe,    usb1_dm_oe;

//   assign usb0_dp_read = usb0_dp;
//   assign usb0_dm_read = usb0_dm;
//   assign usb1_dp_read = usb1_dp;
//   assign usb1_dm_read = usb1_dm;

//   // Drive when OE asserted, otherwise tri-state (infers IOBUF on Xilinx)
//   assign usb0_dp = usb0_dp_oe ? usb0_dp_write : 1'bz;
//   assign usb0_dm = usb0_dm_oe ? usb0_dm_write : 1'bz;
//   assign usb1_dp = usb1_dp_oe ? usb1_dp_write : 1'bz;
//   assign usb1_dm = usb1_dm_oe ? usb1_dm_write : 1'bz;

// localparam bit USB_GPIO_TEST = 1'b1;  // set back to 0 after test

// wire usb0_dp_write_t = USB_GPIO_TEST ? 1'b1 : usb0_dp_write;
// wire usb0_dm_write_t = USB_GPIO_TEST ? 1'b0 : usb0_dm_write;
// wire usb0_dp_oe_t    = USB_GPIO_TEST ? 1'b1 : usb0_dp_oe;
// wire usb0_dm_oe_t    = USB_GPIO_TEST ? 1'b1 : usb0_dm_oe;

// wire usb1_dp_write_t = USB_GPIO_TEST ? 1'b0 : usb1_dp_write;
// wire usb1_dm_write_t = USB_GPIO_TEST ? 1'b1 : usb1_dm_write;
// wire usb1_dp_oe_t    = USB_GPIO_TEST ? 1'b1 : usb1_dp_oe;
// wire usb1_dm_oe_t    = USB_GPIO_TEST ? 1'b1 : usb1_dm_oe;

// IOBUF iobuf_usb0_dp (.I(usb0_dp_write_t), .O(usb0_dp_read), .T(~usb0_dp_oe_t), .IO(usb0_dp));
// IOBUF iobuf_usb0_dm (.I(usb0_dm_write_t), .O(usb0_dm_read), .T(~usb0_dm_oe_t), .IO(usb0_dm));
// IOBUF iobuf_usb1_dp (.I(usb1_dp_write_t), .O(usb1_dp_read), .T(~usb1_dp_oe_t), .IO(usb1_dp));
// IOBUF iobuf_usb1_dm (.I(usb1_dm_write_t), .O(usb1_dm_read), .T(~usb1_dm_oe_t), .IO(usb1_dm));

// USB inout <-> core signals
IOBUF iobuf_usb0_dp (.I(usb0_dp_write), .O(usb0_dp_read), .T(~usb0_dp_oe), .IO(usb0_dp));
IOBUF iobuf_usb0_dm (.I(usb0_dm_write), .O(usb0_dm_read), .T(~usb0_dm_oe), .IO(usb0_dm));
IOBUF iobuf_usb1_dp (.I(usb1_dp_write), .O(usb1_dp_read), .T(~usb1_dp_oe), .IO(usb1_dp));
IOBUF iobuf_usb1_dm (.I(usb1_dm_write), .O(usb1_dm_read), .T(~usb1_dm_oe), .IO(usb1_dm));


  // -------------------------
  // DMA AXI "added" signals
  // -------------------------
  assign m_axi_awid   = DMA_AXI_ID;
  assign m_axi_arid   = DMA_AXI_ID;
  assign m_axi_awlock = 1'b0;
  assign m_axi_arlock = 1'b0;

  // -------------------------
  // Optional DMA address modification (Cheshire-style)
  // -------------------------
  wire [31:0] dma_awaddr_raw;
  wire [31:0] dma_araddr_raw;

  assign m_axi_awaddr = (DMA_ADDR_DOMAIN & ~DMA_ADDR_MASK) | (dma_awaddr_raw & DMA_ADDR_MASK);
  assign m_axi_araddr = (DMA_ADDR_DOMAIN & ~DMA_ADDR_MASK) | (dma_araddr_raw & DMA_ADDR_MASK);

  // -------------------------
  // SpinalHDL core instance
  // -------------------------
  if (DMA_AXI_DATA_WIDTH == 32) begin : gen_ohci_dma32
    UsbOhciAxi4_p2_dma32 u_ohci (
      .io_dma_aw_valid          (m_axi_awvalid),
      .io_dma_aw_ready          (m_axi_awready),
      .io_dma_aw_payload_addr   (dma_awaddr_raw),
      .io_dma_aw_payload_len    (m_axi_awlen),
      .io_dma_aw_payload_size   (m_axi_awsize),
      .io_dma_aw_payload_burst  (m_axi_awburst),
      .io_dma_aw_payload_cache  (m_axi_awcache),
      .io_dma_aw_payload_prot   (m_axi_awprot),
      .io_dma_w_valid           (m_axi_wvalid),
      .io_dma_w_ready           (m_axi_wready),
      .io_dma_w_payload_data    (m_axi_wdata),
      .io_dma_w_payload_strb    (m_axi_wstrb),
      .io_dma_w_payload_last    (m_axi_wlast),
      .io_dma_b_valid           (m_axi_bvalid),
      .io_dma_b_ready           (m_axi_bready),
      .io_dma_b_payload_resp    (m_axi_bresp),
      .io_dma_ar_valid          (m_axi_arvalid),
      .io_dma_ar_ready          (m_axi_arready),
      .io_dma_ar_payload_addr   (dma_araddr_raw),
      .io_dma_ar_payload_len    (m_axi_arlen),
      .io_dma_ar_payload_size   (m_axi_arsize),
      .io_dma_ar_payload_burst  (m_axi_arburst),
      .io_dma_ar_payload_cache  (m_axi_arcache),
      .io_dma_ar_payload_prot   (m_axi_arprot),
      .io_dma_r_valid           (m_axi_rvalid),
      .io_dma_r_ready           (m_axi_rready),
      .io_dma_r_payload_data    (m_axi_rdata),
      .io_dma_r_payload_resp    (m_axi_rresp),
      .io_dma_r_payload_last    (m_axi_rlast),
      .io_ctrl_aw_valid         (s_axi_awvalid),
      .io_ctrl_aw_ready         (s_axi_awready),
      .io_ctrl_aw_payload_addr  (s_axi_awaddr),
      .io_ctrl_aw_payload_id    (s_axi_awid),
      .io_ctrl_aw_payload_region(4'b0000),
      .io_ctrl_aw_payload_len   (s_axi_awlen),
      .io_ctrl_aw_payload_size  (s_axi_awsize),
      .io_ctrl_aw_payload_burst (s_axi_awburst),
      .io_ctrl_aw_payload_lock  (s_axi_awlock),
      .io_ctrl_aw_payload_cache (s_axi_awcache),
      .io_ctrl_aw_payload_qos   (s_axi_awqos),
      .io_ctrl_aw_payload_prot  (s_axi_awprot),
      .io_ctrl_w_valid          (s_axi_wvalid),
      .io_ctrl_w_ready          (s_axi_wready),
      .io_ctrl_w_payload_data   (s_axi_wdata),
      .io_ctrl_w_payload_strb   (s_axi_wstrb),
      .io_ctrl_w_payload_last   (s_axi_wlast),
      .io_ctrl_b_valid          (s_axi_bvalid),
      .io_ctrl_b_ready          (s_axi_bready),
      .io_ctrl_b_payload_id     (s_axi_bid),
      .io_ctrl_b_payload_resp   (s_axi_bresp),
      .io_ctrl_ar_valid         (s_axi_arvalid),
      .io_ctrl_ar_ready         (s_axi_arready),
      .io_ctrl_ar_payload_addr  (s_axi_araddr),
      .io_ctrl_ar_payload_id    (s_axi_arid),
      .io_ctrl_ar_payload_region(4'b0000),
      .io_ctrl_ar_payload_len   (s_axi_arlen),
      .io_ctrl_ar_payload_size  (s_axi_arsize),
      .io_ctrl_ar_payload_burst (s_axi_arburst),
      .io_ctrl_ar_payload_lock  (s_axi_arlock),
      .io_ctrl_ar_payload_cache (s_axi_arcache),
      .io_ctrl_ar_payload_qos   (s_axi_arqos),
      .io_ctrl_ar_payload_prot  (s_axi_arprot),
      .io_ctrl_r_valid          (s_axi_rvalid),
      .io_ctrl_r_ready          (s_axi_rready),
      .io_ctrl_r_payload_data   (s_axi_rdata),
      .io_ctrl_r_payload_id     (s_axi_rid),
      .io_ctrl_r_payload_resp   (s_axi_rresp),
      .io_ctrl_r_payload_last   (s_axi_rlast),
      .io_interrupt             (irq_o),
      .io_usb_0_dp_read         (usb0_dp_read),
      .io_usb_0_dp_write        (usb0_dp_write),
      .io_usb_0_dp_writeEnable  (usb0_dp_oe),
      .io_usb_0_dm_read         (usb0_dm_read),
      .io_usb_0_dm_write        (usb0_dm_write),
      .io_usb_0_dm_writeEnable  (usb0_dm_oe),
      .io_usb_1_dp_read         (usb1_dp_read),
      .io_usb_1_dp_write        (usb1_dp_write),
      .io_usb_1_dp_writeEnable  (usb1_dp_oe),
      .io_usb_1_dm_read         (usb1_dm_read),
      .io_usb_1_dm_write        (usb1_dm_write),
      .io_usb_1_dm_writeEnable  (usb1_dm_oe),
      .phy_clk                  (phy_clk),
      .phy_reset                (phy_reset),
      .ctrl_clk                 (ctrl_clk),
      .ctrl_reset               (ctrl_reset)
    );
  end else begin : gen_ohci_dma64
    UsbOhciAxi4_p2_dma64 u_ohci (
    // DMA master (out of core)
      .io_dma_aw_valid          (m_axi_awvalid),
      .io_dma_aw_ready          (m_axi_awready),
      .io_dma_aw_payload_addr   (dma_awaddr_raw),
      .io_dma_aw_payload_len    (m_axi_awlen),
      .io_dma_aw_payload_size   (m_axi_awsize),
      .io_dma_aw_payload_burst  (m_axi_awburst),
      .io_dma_aw_payload_cache  (m_axi_awcache),
      .io_dma_aw_payload_prot   (m_axi_awprot),

      .io_dma_w_valid           (m_axi_wvalid),
      .io_dma_w_ready           (m_axi_wready),
      .io_dma_w_payload_data    (m_axi_wdata),
      .io_dma_w_payload_strb    (m_axi_wstrb),
      .io_dma_w_payload_last    (m_axi_wlast),

      .io_dma_b_valid           (m_axi_bvalid),
      .io_dma_b_ready           (m_axi_bready),
      .io_dma_b_payload_resp    (m_axi_bresp),

      .io_dma_ar_valid          (m_axi_arvalid),
      .io_dma_ar_ready          (m_axi_arready),
      .io_dma_ar_payload_addr   (dma_araddr_raw),
      .io_dma_ar_payload_len    (m_axi_arlen),
      .io_dma_ar_payload_size   (m_axi_arsize),
      .io_dma_ar_payload_burst  (m_axi_arburst),
      .io_dma_ar_payload_cache  (m_axi_arcache),
      .io_dma_ar_payload_prot   (m_axi_arprot),

      .io_dma_r_valid           (m_axi_rvalid),
      .io_dma_r_ready           (m_axi_rready),
      .io_dma_r_payload_data    (m_axi_rdata),
      .io_dma_r_payload_resp    (m_axi_rresp),
      .io_dma_r_payload_last    (m_axi_rlast),

      .io_ctrl_aw_valid         (s_axi_awvalid),
      .io_ctrl_aw_ready         (s_axi_awready),
      .io_ctrl_aw_payload_addr  (s_axi_awaddr),
      .io_ctrl_aw_payload_id    (s_axi_awid),
      .io_ctrl_aw_payload_region(4'b0000),
      .io_ctrl_aw_payload_len   (s_axi_awlen),
      .io_ctrl_aw_payload_size  (s_axi_awsize),
      .io_ctrl_aw_payload_burst (s_axi_awburst),
      .io_ctrl_aw_payload_lock  (s_axi_awlock),
      .io_ctrl_aw_payload_cache (s_axi_awcache),
      .io_ctrl_aw_payload_qos   (s_axi_awqos),
      .io_ctrl_aw_payload_prot  (s_axi_awprot),

      .io_ctrl_w_valid          (s_axi_wvalid),
      .io_ctrl_w_ready          (s_axi_wready),
      .io_ctrl_w_payload_data   (s_axi_wdata),
      .io_ctrl_w_payload_strb   (s_axi_wstrb),
      .io_ctrl_w_payload_last   (s_axi_wlast),

      .io_ctrl_b_valid          (s_axi_bvalid),
      .io_ctrl_b_ready          (s_axi_bready),
      .io_ctrl_b_payload_id     (s_axi_bid),
      .io_ctrl_b_payload_resp   (s_axi_bresp),

      .io_ctrl_ar_valid         (s_axi_arvalid),
      .io_ctrl_ar_ready         (s_axi_arready),
      .io_ctrl_ar_payload_addr  (s_axi_araddr),
      .io_ctrl_ar_payload_id    (s_axi_arid),
      .io_ctrl_ar_payload_region(4'b0000),
      .io_ctrl_ar_payload_len   (s_axi_arlen),
      .io_ctrl_ar_payload_size  (s_axi_arsize),
      .io_ctrl_ar_payload_burst (s_axi_arburst),
      .io_ctrl_ar_payload_lock  (s_axi_arlock),
      .io_ctrl_ar_payload_cache (s_axi_arcache),
      .io_ctrl_ar_payload_qos   (s_axi_arqos),
      .io_ctrl_ar_payload_prot  (s_axi_arprot),

      .io_ctrl_r_valid          (s_axi_rvalid),
      .io_ctrl_r_ready          (s_axi_rready),
      .io_ctrl_r_payload_data   (s_axi_rdata),
      .io_ctrl_r_payload_id     (s_axi_rid),
      .io_ctrl_r_payload_resp   (s_axi_rresp),
      .io_ctrl_r_payload_last   (s_axi_rlast),

    // IRQ
      .io_interrupt             (irq_o),

    // USB PHY (2 ports)
      .io_usb_0_dp_read         (usb0_dp_read),
      .io_usb_0_dp_write        (usb0_dp_write),
      .io_usb_0_dp_writeEnable  (usb0_dp_oe),
      .io_usb_0_dm_read         (usb0_dm_read),
      .io_usb_0_dm_write        (usb0_dm_write),
      .io_usb_0_dm_writeEnable  (usb0_dm_oe),

      .io_usb_1_dp_read         (usb1_dp_read),
      .io_usb_1_dp_write        (usb1_dp_write),
      .io_usb_1_dp_writeEnable  (usb1_dp_oe),
      .io_usb_1_dm_read         (usb1_dm_read),
      .io_usb_1_dm_write        (usb1_dm_write),
      .io_usb_1_dm_writeEnable  (usb1_dm_oe),

    // Clocks / resets
      .phy_clk                  (phy_clk),
      .phy_reset                (phy_reset),
      .ctrl_clk                 (ctrl_clk),
      .ctrl_reset               (ctrl_reset)
    );
  end

endmodule

//`default_nettype wire
