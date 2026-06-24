module uberddr3_wrapper #(
    // ------------------------------------------------------------------------
    // External AXI slave interface (match the existing SoC-side DDR port)
    // ------------------------------------------------------------------------
    parameter int AXI_ID_WIDTH   = 4,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 64,

    // ------------------------------------------------------------------------
    // Genesys 2 DDR3 geometry / UberDDR3 config
    // ------------------------------------------------------------------------
    parameter int UBER_ROW_BITS         = 15,
    parameter int UBER_COL_BITS         = 10,
    parameter int UBER_BA_BITS          = 3,
    parameter int UBER_BYTE_LANES       = 4,   // x32 DDR3 = 4 byte lanes
    parameter int UBER_AXI_ID_WIDTH     = 4,
    parameter int CONTROLLER_CLK_PERIOD = 10_000, // ps = 100 MHz
    parameter int DDR3_CLK_PERIOD       = 2_500,  // ps = 400 MHz
    parameter bit ODELAY_SUPPORTED      = 1'b1,

    // Disable long built-in memory test by default so calibration completes faster.
    parameter int BIST_MODE             = 0,

    // Genesys 2 Digilent/MIG-recommended impedance values.
    parameter [1:0] UBER_DIC            = 2'b01,  // RZQ/7
    parameter [2:0] UBER_RTT_NOM        = 3'b011  // RZQ/6
) (
    // ------------------------------------------------------------------------
    // Clocks / resets
    // ------------------------------------------------------------------------
    input  wire                        i_clk_200,
    input  wire                        i_sys_rst,        // active-high global reset

    output wire                        o_ui_clk,         // AXI/UI clock for the SoC side (100 MHz)
    output wire                        o_ref_clk_200,    // buffered 200 MHz reference clock
    output wire                        o_ui_clk_sync_rst,// active-high reset synchronous to o_ui_clk
    output wire                        o_ui_aresetn,     // active-low version of the same reset
    output wire                        o_pll_locked,
    output wire                        o_init_calib_complete,
    output wire [31:0]                 o_debug1,

    // ------------------------------------------------------------------------
    // AXI slave interface (SoC side, kept MIG/LiteDRAM-like)
    // ------------------------------------------------------------------------
    input  wire [AXI_ID_WIDTH-1:0]     i_s_axi_awid,
    input  wire [AXI_ADDR_WIDTH-1:0]   i_s_axi_awaddr,
    input  wire [7:0]                  i_s_axi_awlen,
    input  wire [2:0]                  i_s_axi_awsize,
    input  wire [1:0]                  i_s_axi_awburst,
    input  wire                        i_s_axi_awlock,
    input  wire [3:0]                  i_s_axi_awcache,
    input  wire [2:0]                  i_s_axi_awprot,
    input  wire [3:0]                  i_s_axi_awqos,
    input  wire                        i_s_axi_awvalid,
    output wire                        o_s_axi_awready,

    input  wire [AXI_DATA_WIDTH-1:0]   i_s_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0] i_s_axi_wstrb,
    input  wire                        i_s_axi_wlast,
    input  wire                        i_s_axi_wvalid,
    output wire                        o_s_axi_wready,

    output wire [AXI_ID_WIDTH-1:0]     o_s_axi_bid,
    output wire [1:0]                  o_s_axi_bresp,
    output wire                        o_s_axi_bvalid,
    input  wire                        i_s_axi_bready,

    input  wire [AXI_ID_WIDTH-1:0]     i_s_axi_arid,
    input  wire [AXI_ADDR_WIDTH-1:0]   i_s_axi_araddr,
    input  wire [7:0]                  i_s_axi_arlen,
    input  wire [2:0]                  i_s_axi_arsize,
    input  wire [1:0]                  i_s_axi_arburst,
    input  wire                        i_s_axi_arlock,
    input  wire [3:0]                  i_s_axi_arcache,
    input  wire [2:0]                  i_s_axi_arprot,
    input  wire [3:0]                  i_s_axi_arqos,
    input  wire                        i_s_axi_arvalid,
    output wire                        o_s_axi_arready,

    output wire [AXI_ID_WIDTH-1:0]     o_s_axi_rid,
    output wire [AXI_DATA_WIDTH-1:0]   o_s_axi_rdata,
    output wire [1:0]                  o_s_axi_rresp,
    output wire                        o_s_axi_rlast,
    output wire                        o_s_axi_rvalid,
    input  wire                        i_s_axi_rready,

    // ------------------------------------------------------------------------
    // DDR3 pins
    // ------------------------------------------------------------------------
    inout  wire [31:0]                 io_ddr3_dq,
    inout  wire [3:0]                  io_ddr3_dqs_n,
    inout  wire [3:0]                  io_ddr3_dqs_p,
    output wire [14:0]                 o_ddr3_addr,
    output wire [2:0]                  o_ddr3_ba,
    output wire                        o_ddr3_ras_n,
    output wire                        o_ddr3_cas_n,
    output wire                        o_ddr3_we_n,
    output wire                        o_ddr3_reset_n,
    output wire [0:0]                  o_ddr3_ck_p,
    output wire [0:0]                  o_ddr3_ck_n,
    output wire [0:0]                  o_ddr3_cke,
    output wire [0:0]                  o_ddr3_cs_n,
    output wire [3:0]                  o_ddr3_dm,
    output wire [0:0]                  o_ddr3_odt
);

    localparam int UBER_DQ_BITS         = 8;
    localparam int UBER_SERDES_RATIO    = 4;
    localparam int UBER_AXI_DATA_WIDTH  = UBER_DQ_BITS * UBER_BYTE_LANES * UBER_SERDES_RATIO * 2;
    localparam int UBER_WB_ADDR_BITS    = UBER_ROW_BITS + UBER_COL_BITS + UBER_BA_BITS - $clog2(UBER_SERDES_RATIO * 2);
    localparam int UBER_AXI_LSBS        = $clog2(UBER_AXI_DATA_WIDTH) - 3;
    localparam int UBER_AXI_ADDR_WIDTH  = UBER_WB_ADDR_BITS + UBER_AXI_LSBS;

    // Sanity check: this wrapper adapts the SoC-facing AXI port to UberDDR3's
    // native 256-bit AXI port.
    initial begin
        if ((AXI_DATA_WIDTH % 8) != 0) begin
            $error("uberddr3_wrapper AXI_DATA_WIDTH must be byte-aligned.");
        end
        if (AXI_DATA_WIDTH > UBER_AXI_DATA_WIDTH) begin
            $error("uberddr3_wrapper AXI_DATA_WIDTH must not exceed UBER_AXI_DATA_WIDTH.");
        end
        if ((UBER_AXI_DATA_WIDTH % AXI_DATA_WIDTH) != 0) begin
            $error("uberddr3_wrapper UBER_AXI_DATA_WIDTH must be an integer multiple of AXI_DATA_WIDTH.");
        end
        if (UBER_AXI_DATA_WIDTH != 256) begin
            $error("uberddr3_wrapper currently expects UBER_AXI_DATA_WIDTH=256 for the internal UberDDR3 AXI port.");
        end
    end

    // ------------------------------------------------------------------------
    // Clock generation: 200 MHz in -> 100 MHz UI, 400 MHz DDR, 200 MHz ref
    // ------------------------------------------------------------------------
    wire pll_clkfb;
    wire pll_clkfb_buf;
    wire pll_clk_ui_raw;
    wire pll_clk_ddr_raw;
    wire pll_clk_ref_raw;
    wire pll_locked;
    wire u_uber_clk_ddr;

    PLLE2_ADV #(
        .BANDWIDTH("OPTIMIZED"),
        .COMPENSATION("ZHOLD"),
        .STARTUP_WAIT("FALSE"),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT(4),        // 200 MHz * 4 = 800 MHz VCO
        .CLKFBOUT_PHASE(0.0),
        .CLKIN1_PERIOD(5.0),      // 200 MHz input clock
        .CLKIN2_PERIOD(0.0),
        .CLKOUT0_DIVIDE(8),       // 800 / 8 = 100 MHz UI clock
        .CLKOUT0_PHASE(0.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT1_DIVIDE(2),       // 800 / 2 = 400 MHz DDR clock
        .CLKOUT1_PHASE(0.0),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT2_DIVIDE(4),       // 800 / 4 = 200 MHz ref clock
        .CLKOUT2_PHASE(0.0),
        .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT3_DIVIDE(1),
        .CLKOUT3_PHASE(0.0),
        .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT4_DIVIDE(1),
        .CLKOUT4_PHASE(0.0),
        .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT5_DIVIDE(1),
        .CLKOUT5_PHASE(0.0),
        .CLKOUT5_DUTY_CYCLE(0.5),
        .REF_JITTER1(0.010)
    ) u_pll (
        .CLKFBOUT   (pll_clkfb),
        .CLKOUT0    (pll_clk_ui_raw),
        .CLKOUT1    (pll_clk_ddr_raw),
        .CLKOUT2    (pll_clk_ref_raw),
        .CLKOUT3    (),
        .CLKOUT4    (),
        .CLKOUT5    (),
        .LOCKED     (pll_locked),
        .CLKFBIN    (pll_clkfb_buf),
        .CLKIN1     (i_clk_200),
        .CLKIN2     (1'b0),
        .CLKINSEL   (1'b1),
        .DADDR      (7'd0),
        .DCLK       (1'b0),
        .DEN        (1'b0),
        .DI         (16'd0),
        .DO         (),
        .DRDY       (),
        .DWE        (1'b0),
        .PWRDWN     (1'b0),
        .RST        (i_sys_rst)
    );

    BUFG u_bufg_fb   (.I(pll_clkfb),      .O(pll_clkfb_buf));
    BUFG u_bufg_ui   (.I(pll_clk_ui_raw), .O(o_ui_clk));
    BUFG u_bufg_ddr  (.I(pll_clk_ddr_raw),.O(u_uber_clk_ddr));
    BUFG u_bufg_ref  (.I(pll_clk_ref_raw),.O(o_ref_clk_200));

    assign o_pll_locked = pll_locked;

    // UberDDR3 expects an active-low reset input.
    wire u_uber_rst_n = ~i_sys_rst & pll_locked;

    // ------------------------------------------------------------------------
    // Internal AXI wiring: external SoC-facing AXI -> axi_adapter -> internal 256-bit AXI
    // ------------------------------------------------------------------------
    (* mark_debug = "true" *) wire [AXI_ID_WIDTH-1:0]         axi256_awid;
    (* mark_debug = "true" *) wire [AXI_ADDR_WIDTH-1:0]       axi256_awaddr_full;
    (* mark_debug = "true" *) wire [7:0]                      axi256_awlen;
    (* mark_debug = "true" *) wire [2:0]                      axi256_awsize;
    (* mark_debug = "true" *) wire [1:0]                      axi256_awburst;
    wire                            axi256_awlock;
    wire [3:0]                      axi256_awcache;
    wire [2:0]                      axi256_awprot;
    wire [3:0]                      axi256_awqos;
    wire [3:0]                      axi256_awregion;
    (* mark_debug = "true" *) wire                            axi256_awvalid;
    (* mark_debug = "true" *) wire                            axi256_awready;

    wire [UBER_AXI_DATA_WIDTH-1:0]   axi256_wdata;
    (* mark_debug = "true" *) wire [UBER_AXI_DATA_WIDTH/8-1:0] axi256_wstrb;
    (* mark_debug = "true" *) wire                             axi256_wlast;
    (* mark_debug = "true" *) wire                             axi256_wvalid;
    (* mark_debug = "true" *) wire                             axi256_wready;

    (* mark_debug = "true" *) wire [AXI_ID_WIDTH-1:0]         axi256_bid;
    (* mark_debug = "true" *) wire [1:0]                      axi256_bresp;
    (* mark_debug = "true" *) wire                            axi256_bvalid;
    (* mark_debug = "true" *) wire                            axi256_bready;

    (* mark_debug = "true" *) wire [AXI_ID_WIDTH-1:0]         axi256_arid;
    (* mark_debug = "true" *) wire [AXI_ADDR_WIDTH-1:0]       axi256_araddr_full;
    (* mark_debug = "true" *) wire [7:0]                      axi256_arlen;
    (* mark_debug = "true" *) wire [2:0]                      axi256_arsize;
    (* mark_debug = "true" *) wire [1:0]                      axi256_arburst;
    wire                            axi256_arlock;
    wire [3:0]                      axi256_arcache;
    wire [2:0]                      axi256_arprot;
    wire [3:0]                      axi256_arqos;
    wire [3:0]                      axi256_arregion;
    (* mark_debug = "true" *) wire                            axi256_arvalid;
    (* mark_debug = "true" *) wire                            axi256_arready;

    (* mark_debug = "true" *) wire [AXI_ID_WIDTH-1:0]         axi256_rid;
    wire [UBER_AXI_DATA_WIDTH-1:0]  axi256_rdata;
    (* mark_debug = "true" *) wire [1:0]                      axi256_rresp;
    (* mark_debug = "true" *) wire                            axi256_rlast;
    (* mark_debug = "true" *) wire                            axi256_rvalid;
    (* mark_debug = "true" *) wire                            axi256_rready;

    axi_adapter #(
        .ADDR_WIDTH           (AXI_ADDR_WIDTH),
        .S_DATA_WIDTH         (AXI_DATA_WIDTH),
        .S_STRB_WIDTH         (AXI_DATA_WIDTH/8),
        .M_DATA_WIDTH         (UBER_AXI_DATA_WIDTH),
        .M_STRB_WIDTH         (UBER_AXI_DATA_WIDTH/8),
        .ID_WIDTH             (AXI_ID_WIDTH),
        .AWUSER_ENABLE        (0),
        .WUSER_ENABLE         (0),
        .BUSER_ENABLE         (0),
        .ARUSER_ENABLE        (0),
        .RUSER_ENABLE         (0),
        .CONVERT_BURST        (1),
        .CONVERT_NARROW_BURST (0),
        .FORWARD_ID           (1)
    ) u_axi_adapter_soc_to_256 (
        .clk                  (o_ui_clk),
        .rst                  (o_ui_clk_sync_rst),

        .s_axi_awid           (i_s_axi_awid),
        .s_axi_awaddr         (i_s_axi_awaddr),
        .s_axi_awlen          (i_s_axi_awlen),
        .s_axi_awsize         (i_s_axi_awsize),
        .s_axi_awburst        (i_s_axi_awburst),
        .s_axi_awlock         (i_s_axi_awlock),
        .s_axi_awcache        (i_s_axi_awcache),
        .s_axi_awprot         (i_s_axi_awprot),
        .s_axi_awqos          (i_s_axi_awqos),
        .s_axi_awregion       (4'b0000),
        .s_axi_awuser         (1'b0),
        .s_axi_awvalid        (i_s_axi_awvalid),
        .s_axi_awready        (o_s_axi_awready),

        .s_axi_wdata          (i_s_axi_wdata),
        .s_axi_wstrb          (i_s_axi_wstrb),
        .s_axi_wlast          (i_s_axi_wlast),
        .s_axi_wuser          (1'b0),
        .s_axi_wvalid         (i_s_axi_wvalid),
        .s_axi_wready         (o_s_axi_wready),

        .s_axi_bid            (o_s_axi_bid),
        .s_axi_bresp          (o_s_axi_bresp),
        .s_axi_buser          (),
        .s_axi_bvalid         (o_s_axi_bvalid),
        .s_axi_bready         (i_s_axi_bready),

        .s_axi_arid           (i_s_axi_arid),
        .s_axi_araddr         (i_s_axi_araddr),
        .s_axi_arlen          (i_s_axi_arlen),
        .s_axi_arsize         (i_s_axi_arsize),
        .s_axi_arburst        (i_s_axi_arburst),
        .s_axi_arlock         (i_s_axi_arlock),
        .s_axi_arcache        (i_s_axi_arcache),
        .s_axi_arprot         (i_s_axi_arprot),
        .s_axi_arqos          (i_s_axi_arqos),
        .s_axi_arregion       (4'b0000),
        .s_axi_aruser         (1'b0),
        .s_axi_arvalid        (i_s_axi_arvalid),
        .s_axi_arready        (o_s_axi_arready),

        .s_axi_rid            (o_s_axi_rid),
        .s_axi_rdata          (o_s_axi_rdata),
        .s_axi_rresp          (o_s_axi_rresp),
        .s_axi_rlast          (o_s_axi_rlast),
        .s_axi_ruser          (),
        .s_axi_rvalid         (o_s_axi_rvalid),
        .s_axi_rready         (i_s_axi_rready),

        .m_axi_awid           (axi256_awid),
        .m_axi_awaddr         (axi256_awaddr_full),
        .m_axi_awlen          (axi256_awlen),
        .m_axi_awsize         (axi256_awsize),
        .m_axi_awburst        (axi256_awburst),
        .m_axi_awlock         (axi256_awlock),
        .m_axi_awcache        (axi256_awcache),
        .m_axi_awprot         (axi256_awprot),
        .m_axi_awqos          (axi256_awqos),
        .m_axi_awregion       (axi256_awregion),
        .m_axi_awuser         (),
        .m_axi_awvalid        (axi256_awvalid),
        .m_axi_awready        (axi256_awready),

        .m_axi_wdata          (axi256_wdata),
        .m_axi_wstrb          (axi256_wstrb),
        .m_axi_wlast          (axi256_wlast),
        .m_axi_wuser          (),
        .m_axi_wvalid         (axi256_wvalid),
        .m_axi_wready         (axi256_wready),

        .m_axi_bid            (axi256_bid),
        .m_axi_bresp          (axi256_bresp),
        .m_axi_buser          (1'b0),
        .m_axi_bvalid         (axi256_bvalid),
        .m_axi_bready         (axi256_bready),

        .m_axi_arid           (axi256_arid),
        .m_axi_araddr         (axi256_araddr_full),
        .m_axi_arlen          (axi256_arlen),
        .m_axi_arsize         (axi256_arsize),
        .m_axi_arburst        (axi256_arburst),
        .m_axi_arlock         (axi256_arlock),
        .m_axi_arcache        (axi256_arcache),
        .m_axi_arprot         (axi256_arprot),
        .m_axi_arqos          (axi256_arqos),
        .m_axi_arregion       (axi256_arregion),
        .m_axi_aruser         (),
        .m_axi_arvalid        (axi256_arvalid),
        .m_axi_arready        (axi256_arready),

        .m_axi_rid            (axi256_rid),
        .m_axi_rdata          (axi256_rdata),
        .m_axi_rresp          (axi256_rresp),
        .m_axi_rlast          (axi256_rlast),
        .m_axi_ruser          (1'b0),
        .m_axi_rvalid         (axi256_rvalid),
        .m_axi_rready         (axi256_rready)
    );

    // ------------------------------------------------------------------------
    // Reset exported to the rest of the AXI/UI domain.
    // Hold the bus in reset until the PLL is locked and DDR calibration is done.
    // ------------------------------------------------------------------------
    reg [3:0] ui_reset_sr = 4'hF;

    always @(posedge o_ui_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            ui_reset_sr <= 4'hF;
        end else if (!pll_locked || !o_init_calib_complete) begin
            ui_reset_sr <= 4'hF;
        end else begin
            ui_reset_sr <= {ui_reset_sr[2:0], 1'b0};
        end
    end

    assign o_ui_clk_sync_rst = ui_reset_sr[3];
    assign o_ui_aresetn      = ~o_ui_clk_sync_rst;

    // ------------------------------------------------------------------------
    // UberDDR3 AXI top
    // Notes:
    // - ODELAY_SUPPORTED=1 on Genesys 2 HP bank, so i_ddr3_clk_90 is tied low.
    // - The UberDDR3 internal/local AXI address width is 30 bits for this x32 config.
    //   The external SoC-facing AXI address is kept at 32 bits; upper bits are dropped here.
    // ------------------------------------------------------------------------
    ddr3_top_axi #(
        .CONTROLLER_CLK_PERIOD (CONTROLLER_CLK_PERIOD),
        .DDR3_CLK_PERIOD       (DDR3_CLK_PERIOD),
        .ROW_BITS              (UBER_ROW_BITS),
        .COL_BITS              (UBER_COL_BITS),
        .BA_BITS               (UBER_BA_BITS),
        .BYTE_LANES            (UBER_BYTE_LANES),
        .AXI_ID_WIDTH          (UBER_AXI_ID_WIDTH),
        .MICRON_SIM            (1'b0),
        .ODELAY_SUPPORTED      (ODELAY_SUPPORTED),
        .SECOND_WISHBONE       (1'b0),
        .WB_ERROR              (1'b0),
        .BIST_MODE             (BIST_MODE),
        .ECC_ENABLE            (2'b00),
        .DIC                   (UBER_DIC),
        .RTT_NOM               (UBER_RTT_NOM),
        .SELF_REFRESH          (2'b00)
    ) u_uberddr3 (
        .i_controller_clk      (o_ui_clk),
        .i_ddr3_clk            (u_uber_clk_ddr),
        .i_ref_clk             (o_ref_clk_200),
        .i_ddr3_clk_90         (1'b0),
        .i_rst_n               (u_uber_rst_n),

        .s_axi_awvalid         (axi256_awvalid),
        .s_axi_awready         (axi256_awready),
        .s_axi_awid            (axi256_awid),
        .s_axi_awaddr          (axi256_awaddr_full[UBER_AXI_ADDR_WIDTH-1:0]),
        .s_axi_awlen           (axi256_awlen),
        .s_axi_awsize          (axi256_awsize),
        .s_axi_awburst         (axi256_awburst),
        .s_axi_awlock          (axi256_awlock),
        .s_axi_awcache         (axi256_awcache),
        .s_axi_awprot          (axi256_awprot),
        .s_axi_awqos           (axi256_awqos),

        .s_axi_wvalid          (axi256_wvalid),
        .s_axi_wready          (axi256_wready),
        .s_axi_wdata           (axi256_wdata),
        .s_axi_wstrb           (axi256_wstrb),
        .s_axi_wlast           (axi256_wlast),

        .s_axi_bvalid          (axi256_bvalid),
        .s_axi_bready          (axi256_bready),
        .s_axi_bid             (axi256_bid),
        .s_axi_bresp           (axi256_bresp),

        .s_axi_arvalid         (axi256_arvalid),
        .s_axi_arready         (axi256_arready),
        .s_axi_arid            (axi256_arid),
        .s_axi_araddr          (axi256_araddr_full[UBER_AXI_ADDR_WIDTH-1:0]),
        .s_axi_arlen           (axi256_arlen),
        .s_axi_arsize          (axi256_arsize),
        .s_axi_arburst         (axi256_arburst),
        .s_axi_arlock          (axi256_arlock),
        .s_axi_arcache         (axi256_arcache),
        .s_axi_arprot          (axi256_arprot),
        .s_axi_arqos           (axi256_arqos),

        .s_axi_rvalid          (axi256_rvalid),
        .s_axi_rready          (axi256_rready),
        .s_axi_rid             (axi256_rid),
        .s_axi_rdata           (axi256_rdata),
        .s_axi_rlast           (axi256_rlast),
        .s_axi_rresp           (axi256_rresp),

        .o_ddr3_clk_p          (o_ddr3_ck_p),
        .o_ddr3_clk_n          (o_ddr3_ck_n),
        .o_ddr3_reset_n        (o_ddr3_reset_n),
        .o_ddr3_cke            (o_ddr3_cke),
        .o_ddr3_cs_n           (o_ddr3_cs_n),
        .o_ddr3_ras_n          (o_ddr3_ras_n),
        .o_ddr3_cas_n          (o_ddr3_cas_n),
        .o_ddr3_we_n           (o_ddr3_we_n),
        .o_ddr3_addr           (o_ddr3_addr),
        .o_ddr3_ba_addr        (o_ddr3_ba),
        .io_ddr3_dq            (io_ddr3_dq),
        .io_ddr3_dqs           (io_ddr3_dqs_p),
        .io_ddr3_dqs_n         (io_ddr3_dqs_n),
        .o_ddr3_dm             (o_ddr3_dm),
        .o_ddr3_odt            (o_ddr3_odt),
        .o_calib_complete      (o_init_calib_complete),
        .o_debug1              (o_debug1),
        .i_user_self_refresh   (1'b0)
    );

endmodule
