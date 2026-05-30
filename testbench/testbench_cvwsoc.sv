///////////////////////////////////////////
// testbench_cvwsoc.sv
//
// Whole-system cvwsoc simulation top:
//   Wally SoC -> external AHB -> AHB/AXI bridge -> AXI CDC -> AXI xbar
//              -> functional AXI RAM + small AXI peripheral RAM
//
// This keeps the bridge-focused setup intact while adding the missing base
// bus components used by the cvwsoc virtual platform.
///////////////////////////////////////////

`timescale 1ns / 1ps
`include "config.vh"
`include "axi/typedef.svh"

import cvw::*;


// Enable one external-memory model. SDHCI is opt-in; AXI RAM is the default.
`ifndef SIM_AXI_RAM
  `ifndef SIM_AXI_SDHCI
    `define SIM_AXI_RAM 1
  `endif
`endif

module testbench_cvwsoc #(
  parameter int unsigned CLK_PERIOD_NS       = 10,
  //parameter int unsigned BUS_CLK_PERIOD_NS   = 7,
  parameter int unsigned BUS_CLK_PERIOD_NS   = 5, //a bit faster simulation?
  parameter int unsigned RESET_CYCLES        = 32,
  parameter int unsigned BUS_RESET_CYCLES    = 64,
  parameter int unsigned EXT_MEM_ADDR_WIDTH  = 30,
  parameter int unsigned CDC_LOG_DEPTH       = 2,
  parameter int unsigned CDC_SYNC_STAGES     = 2,
  parameter int unsigned PERIPH_ADDR_WIDTH   = 18,
  parameter bit          MAKE_VCD            = 1
);

  `ifdef VERILATOR
    import "DPI-C" function string getenvval(input string env_name);
    import "DPI-C" function real wallclock_seconds();
    import "DPI-C" function string wallclock_datetime();
    string RISCV_DIR = getenvval("RISCV");
    string WALLY_DIR = getenvval("WALLY");
  `else
    string RISCV_DIR = "$RISCV";
    string WALLY_DIR = "$WALLY";
  `endif

  `include "parameter-defs.vh"

  function automatic cvw_t cvwsoc_sim_cfg(input cvw_t cfg);
    cvw_t tmp;
    begin
      tmp = cfg;
      tmp.BOOTROM_PRELOAD = 1'b0;
      tmp.UNCORE_RAM_PRELOAD = 1'b0;
      tmp.WISHBONE_SUPPORTED = 1'b0;
      tmp.WISHBONE_UART_SUPPORTED = 1'b0;
      tmp.WISHBONE_ETH_SUPPORTED = 1'b0;
      tmp.WISHBONE_STUB_SUPPORTED = 1'b0;
`ifdef SIM_AXI_SDHCI
      tmp.AXI_SDHCI_SUPPORTED = 1'b1;
`else
      tmp.AXI_SDHCI_SUPPORTED = 1'b0;
`endif
      tmp.AXI_DMA_SUPPORTED = 1'b0;
      tmp.AXI_VGA_SUPPORTED = 1'b0;
      tmp.AXI_USB_SUPPORTED = 1'b0;
      tmp.AXI_ETH_SUPPORTED = 1'b0;
      tmp.LITEDRAM_SUPPORTED = 1'b0;
      tmp.UBERDDR3_SUPPORTED = 1'b0;
      tmp.BOOTROM_RANGE = 64'h3FFFF; // 256 KB
      tmp.AXI_DUMMY_SUPPORTED = 1'b1;
      cvwsoc_sim_cfg = tmp;
    end
  endfunction

  localparam BUSW = P.AHBW; // AXI width = AHB width
  localparam cvw_t SOC_P = cvwsoc_sim_cfg(P);
  localparam int unsigned AXI_ID_WIDTH = 4;
  localparam int unsigned XBAR_NUM_SLV_PORTS = 2;
  localparam int unsigned XBAR_NUM_MST_PORTS = 3;
  localparam int unsigned XBAR_NUM_ADDR_RULES = 3;
  localparam int unsigned AXI_MST_ID_WIDTH = AXI_ID_WIDTH + $clog2(XBAR_NUM_SLV_PORTS);
  localparam logic [31:0] EXT_RAM_BASE_ADDR = 32'h8000_0000;
  localparam logic [31:0] EXT_RAM_END_ADDR = EXT_RAM_BASE_ADDR + (32'd1 << EXT_MEM_ADDR_WIDTH);
  localparam logic [31:0] SDHCI_BASE_ADDR = SOC_P.AXI_SDHCI_BASE[31:0];
  localparam logic [31:0] SDHCI_END_ADDR = SDHCI_BASE_ADDR + SOC_P.AXI_SDHCI_RANGE[31:0] + 32'd1;
  localparam logic [31:0] AXI_DUMMY_BASE_ADDR = SOC_P.AXI_DUMMY_BASE[31:0];
  localparam logic [31:0] AXI_DUMMY_END_ADDR = AXI_DUMMY_BASE_ADDR + SOC_P.AXI_DUMMY_RANGE[31:0] + 32'd1;
  localparam longint unsigned HEARTBEAT_CYCLES = 10_000_000;
  localparam longint unsigned HEARTBEAT_SPEED_INTERVAL_CYCLES_DEFAULT = HEARTBEAT_CYCLES;
  localparam logic [P.XLEN-1:0] KERNEL_ENTRY_PC = 64'h0000_0000_8020_0000;
  localparam longint unsigned AHBW_BYTES = P.AHBW / 8;
  localparam int unsigned BOOTROM_PRELOAD_START = SOC_P.BOOTROM_BASE >> $clog2(AHBW_BYTES);
  localparam int unsigned BOOTROM_WORDS = (SOC_P.BOOTROM_RANGE + 1) / AHBW_BYTES;
  localparam int unsigned UNCORE_RAM_WORDS = (SOC_P.UNCORE_RAM_RANGE + 1) / AHBW_BYTES;
  localparam realtime HALF_PERIOD_NS = CLK_PERIOD_NS / 2.0;
  localparam realtime BUS_HALF_PERIOD_NS = BUS_CLK_PERIOD_NS / 2.0;
  localparam realtime UART_BIT_PERIOD_NS = 1_000_000_000.0 / 115200.0;
  localparam realtime UART_TX_START_DELAY_NS = 100_000.0;

  typedef logic [31:0]                axi_addr_t;
  typedef logic [BUSW-1:0]          axi_data_t;
  typedef logic [BUSW/8-1:0]        axi_strb_t;
  typedef logic [AXI_ID_WIDTH-1:0]    slv_id_t;
  typedef logic [AXI_MST_ID_WIDTH-1:0] mst_id_t;
  typedef logic [0:0]                 axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_t, axi_addr_t, slv_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T (axi_w_t,  axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T (slv_b_t,  slv_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_t, axi_addr_t, slv_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T (slv_r_t,  axi_data_t, slv_id_t, axi_user_t)
  `AXI_TYPEDEF_REQ_T    (slv_req_t, slv_aw_t, axi_w_t, slv_ar_t)
  `AXI_TYPEDEF_RESP_T   (slv_resp_t, slv_b_t, slv_r_t)

  `AXI_TYPEDEF_AW_CHAN_T(mst_aw_t, axi_addr_t, mst_id_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T (mst_b_t,  mst_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(mst_ar_t, axi_addr_t, mst_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T (mst_r_t,  axi_data_t, mst_id_t, axi_user_t)
  `AXI_TYPEDEF_REQ_T    (mst_req_t, mst_aw_t, axi_w_t, mst_ar_t)
  `AXI_TYPEDEF_RESP_T   (mst_resp_t, mst_b_t, mst_r_t)

  localparam axi_pkg::xbar_cfg_t XBAR_CFG = '{
    NoSlvPorts:         XBAR_NUM_SLV_PORTS,
    NoMstPorts:         XBAR_NUM_MST_PORTS,
    MaxMstTrans:        16,
    MaxSlvTrans:        16,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_PORTS,
    PipelineStages:     0,
    AxiIdWidthSlvPorts: AXI_ID_WIDTH,
    AxiIdUsedSlvPorts:  AXI_ID_WIDTH,
    UniqueIds:          1'b0,
    AxiAddrWidth:       32,
    AxiDataWidth:       BUSW,
    NoAddrRules:        XBAR_NUM_ADDR_RULES
  };

  localparam axi_pkg::xbar_rule_32_t [XBAR_NUM_ADDR_RULES-1:0] XBAR_ADDR_MAP = '{
    '{ idx: 0, start_addr: EXT_RAM_BASE_ADDR, end_addr: EXT_RAM_END_ADDR },
    '{ idx: 1, start_addr: SDHCI_BASE_ADDR, end_addr: SDHCI_END_ADDR },
    '{ idx: 2, start_addr: AXI_DUMMY_BASE_ADDR, end_addr: AXI_DUMMY_END_ADDR }
  };

  // ---------------------------------------------------------------------------
  // Clocks / resets
  // ---------------------------------------------------------------------------
  logic clk = 1'b0;
  logic bus_clk = 1'b0;
  logic reset_ext = 1'b1;
  logic bus_reset = 1'b1;
  logic reset;

  always #(HALF_PERIOD_NS) clk = ~clk;
  always #(BUS_HALF_PERIOD_NS) bus_clk = ~bus_clk;

  initial begin
    repeat (RESET_CYCLES) @(posedge clk);
    reset_ext = 1'b0;
  end

  initial begin
    repeat (BUS_RESET_CYCLES) @(posedge bus_clk);
    bus_reset = 1'b0;
  end

  // ---------------------------------------------------------------------------
  // SoC-facing AHB signals
  // ---------------------------------------------------------------------------
  logic [P.AHBW-1:0]    HRDATAEXT;
  logic                 HREADYEXT;
  logic                 HRESPEXT;
  logic                 HSELEXT;
  logic                 HCLK;
  logic                 HRESETn;
  logic [P.PA_BITS-1:0] HADDR;
  logic [P.AHBW-1:0]    HWDATA;
  logic [BUSW/8-1:0]    HWSTRB;
  logic                 HWRITE;
  logic [2:0]           HSIZE;
  logic [2:0]           HBURST;
  logic [3:0]           HPROT;
  logic [1:0]           HTRANS;
  logic                 HMASTLOCK;
  logic                 HREADY;
  logic [P.XLEN-1:0]    PCM;
  logic                 InstrValidM;
  logic [31:0]          InstrM;
  logic                 TrapM;
  logic                 StallM;
  logic                 FlushM;

  // Other SoC internal signals
  logic [P.AHBW-1:0]    HRDATAINT;

  // APB signals
  logic                        PCLK, PRESETn, PWRITE, PENABLE;
  logic [5:0]                  PSEL;
  logic [31:0]                 PADDR;
  logic [P.AHBW-1:0]           PWDATA;
  logic [P.AHBW/8-1:0]         PSTRB;
  logic [5:0]                  PREADY;
  logic [5:0][P.AHBW-1:0]      PRDATA;


  // ---------------------------------------------------------------------------
  // Uncore I/O
  // ---------------------------------------------------------------------------
  logic [31:0] GPIOIN = '0;
  logic [31:0] GPIOOUT;
  logic [31:0] GPIOEN;
  logic        UARTSin = 1'b1;
  logic        UARTSout;
  logic        uart_char_valid /*verilator public_flat_rw*/;
  logic [7:0]  uart_char_data  /*verilator public_flat_rw*/;
  logic        SPIIn = 1'b0;
  logic        SPIOut;
  logic [3:0]  SPICS;
  logic        SPICLK;
  logic        SDCIn = 1'b1;
  logic        SDCCmd;
  logic [3:0]  SDCCS;
  logic        SDCCLK;

  logic WB_UART_RX = 1'b1;
  logic WB_UART_TX;
  logic WB_RMII_REF_CLK = 1'b0;
  logic WB_RMII_CRS_DV = 1'b0;
  logic [1:0] WB_RMII_RX_DATA = '0;
  logic [1:0] WB_RMII_TX_DATA;
  logic WB_RMII_TX_EN;
  logic WB_RMII_MDC;
  wire  WB_RMII_MDIO;
  logic WB_RMII_RST_N;
  logic WB_RMII_PHY_IRQ = 1'b0;

  logic AXI_DMAIntr = 1'b0;
  logic AXI_USBIntr = 1'b0;
  logic AXI_EthIntr = 1'b0;
  logic AXI_SDHCIIntr;
  logic AXI_SDHCIIntr_orig;
  logic AXI_DummyIntr = 1'b0;
  logic AXI_DummyIntr_orig;
  logic ExternalStall = 1'b0;

  // ---------------------------------------------------------------------------
  // Bridge AXI master signals
  // ---------------------------------------------------------------------------
  logic [AXI_ID_WIDTH-1:0] m_axi_awid;
  logic [31:0]             m_axi_awaddr;
  logic [7:0]              m_axi_awlen;
  logic [2:0]              m_axi_awsize;
  logic [1:0]              m_axi_awburst;
  logic                    m_axi_awlock;
  logic [3:0]              m_axi_awcache;
  logic [2:0]              m_axi_awprot;
  logic [3:0]              m_axi_awqos;
  logic                    m_axi_awvalid;
  logic                    m_axi_awready;

  logic [BUSW-1:0]       m_axi_wdata;
  logic [BUSW/8-1:0]     m_axi_wstrb;
  logic                    m_axi_wlast;
  logic                    m_axi_wvalid;
  logic                    m_axi_wready;

  logic [AXI_ID_WIDTH-1:0] m_axi_bid;
  logic [1:0]              m_axi_bresp;
  logic                    m_axi_bvalid;
  logic                    m_axi_bready;

  logic [AXI_ID_WIDTH-1:0] m_axi_arid;
  logic [31:0]             m_axi_araddr;
  logic [7:0]              m_axi_arlen;
  logic [2:0]              m_axi_arsize;
  logic [1:0]              m_axi_arburst;
  logic                    m_axi_arlock;
  logic [3:0]              m_axi_arcache;
  logic [2:0]              m_axi_arprot;
  logic [3:0]              m_axi_arqos;
  logic                    m_axi_arvalid;
  logic                    m_axi_arready;

  logic [AXI_ID_WIDTH-1:0] m_axi_rid;
  logic [BUSW-1:0]       m_axi_rdata;
  logic [1:0]              m_axi_rresp;
  logic                    m_axi_rlast;
  logic                    m_axi_rvalid;
  logic                    m_axi_rready;

  // ---------------------------------------------------------------------------
  // CDC / xbar AXI structs
  // ---------------------------------------------------------------------------
  slv_req_t                 cpu_axi_req;
  slv_resp_t                cpu_axi_resp;
  slv_req_t                 cdc_axi_req;
  slv_resp_t                cdc_axi_resp;
  slv_req_t  [XBAR_NUM_SLV_PORTS-1:0] slv_req;
  slv_resp_t [XBAR_NUM_SLV_PORTS-1:0] slv_resp;
  mst_req_t  [XBAR_NUM_MST_PORTS-1:0] mst_req;
  mst_resp_t [XBAR_NUM_MST_PORTS-1:0] mst_resp;

  assign PCM            = soc.core.ifu.PCM;
  assign InstrValidM    = soc.core.ieu.InstrValidM;
  assign InstrM         = soc.core.InstrM;
  assign TrapM          = soc.core.TrapM;
  assign StallM         = soc.core.StallM;
  assign FlushM         = soc.core.FlushM;

  assign HRDATAINT      = soc.core.HRDATA;

  assign PCLK = soc.uncoregen.uncore.PCLK;
  assign PSEL = soc.uncoregen.uncore.PSEL;
  assign PADDR = soc.uncoregen.uncore.PADDR;
  assign PWDATA = soc.uncoregen.uncore.PWDATA;
  assign PSTRB = soc.uncoregen.uncore.PSTRB;
  assign PRDATA = soc.uncoregen.uncore.PRDATA;

  //--------------------------------
  // EXTRA DEBUG STUFF (REMOVE)
  //--------------------------------
    // wire [$bits(bridge.state)-1:0]             bridge_state             = bridge.state;
    // wire [$bits(bridge.beat_cnt)-1:0]          bridge_beat_cnt          = bridge.beat_cnt;
    // wire                                       bridge_ar_done           = bridge.ar_done;
    // wire                                       bridge_pnd_valid         = bridge.pnd_valid;
    // wire [$bits(bridge.pnd_addr)-1:0]          bridge_pnd_addr          = bridge.pnd_addr;
    // wire                                       bridge_rd_buf_valid      = bridge.rd_buf_valid;
    // wire [$bits(bridge.haddr_q)-1:0]           bridge_haddr_q           = bridge.haddr_q;
    // wire [$bits(bridge.htrans_q)-1:0]          bridge_htrans_q          = bridge.htrans_q;
    // wire                                       bridge_hreadyin_q        = bridge.hreadyin_q;
    // wire [$bits(bridge.dbg_last_ar_addr)-1:0]  bridge_dbg_last_ar_addr  = bridge.dbg_last_ar_addr;
    // wire [$bits(bridge.dbg_last_r_data)-1:0]   bridge_dbg_last_r_data   = bridge.dbg_last_r_data;
    // wire                                       bridge_dbg_trip_sticky   = bridge.dbg_trip_sticky;
    // wire [$bits(bridge.dbg_trip_cause)-1:0]    bridge_dbg_trip_cause    = bridge.dbg_trip_cause;
  //----------------------------------

  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------
  wallypipelinedsoc #(SOC_P) soc (
    .clk(clk),
    .reset_ext(reset_ext),
    .reset(reset),
    .HRDATAEXT(HRDATAEXT),
    .HREADYEXT(HREADYEXT),
    .HRESPEXT(HRESPEXT),
    .HSELEXT(HSELEXT),
    .ExternalStall(ExternalStall),
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .HADDR(HADDR),
    .HWDATA(HWDATA),
    .HWSTRB(HWSTRB),
    .HWRITE(HWRITE),
    .HSIZE(HSIZE),
    .HBURST(HBURST),
    .HPROT(HPROT),
    .HTRANS(HTRANS),
    .HMASTLOCK(HMASTLOCK),
    .HREADY(HREADY),
    .TIMECLK(1'b0),
    .GPIOIN(GPIOIN),
    .GPIOOUT(GPIOOUT),
    .GPIOEN(GPIOEN),
    .UARTSin(UARTSin),
    .UARTSout(UARTSout),
    .SPIIn(SPIIn),
    .SPIOut(SPIOut),
    .SPICS(SPICS),
    .SPICLK(SPICLK),
    .SDCIn(SDCIn),
    .SDCCmd(SDCCmd),
    .SDCCS(SDCCS),
    .SDCCLK(SDCCLK),
    .WB_UART_RX(WB_UART_RX),
    .WB_UART_TX(WB_UART_TX),
    .WB_RMII_REF_CLK(WB_RMII_REF_CLK),
    .WB_RMII_CRS_DV(WB_RMII_CRS_DV),
    .WB_RMII_RX_DATA(WB_RMII_RX_DATA),
    .WB_RMII_TX_DATA(WB_RMII_TX_DATA),
    .WB_RMII_TX_EN(WB_RMII_TX_EN),
    .WB_RMII_MDC(WB_RMII_MDC),
    .WB_RMII_MDIO(WB_RMII_MDIO),
    .WB_RMII_RST_N(WB_RMII_RST_N),
    .WB_RMII_PHY_IRQ(WB_RMII_PHY_IRQ),
    .AXI_DMAIntr(AXI_DMAIntr),
    .AXI_USBIntr(AXI_USBIntr),
    .AXI_EthIntr(AXI_EthIntr),
    .AXI_SDHCIIntr(AXI_SDHCIIntr),
    .AXI_DummyIntr(AXI_DummyIntr)
  );

  ahb_to_axi4_burst #(
    .AW(32),
    .DW(BUSW),
    .IW(AXI_ID_WIDTH)
  ) bridge (
    .clk(clk),
    .resetn(~reset),
    .HSEL(HSELEXT),
    .HREADYIN(HREADY),
    .HADDR(HADDR[31:0]),
    .HBURST(HBURST),
    .HMASTLOCK(HMASTLOCK),
    .HPROT(HPROT),
    .HSIZE(HSIZE),
    .HTRANS(HTRANS),
    .HWDATA(HWDATA),
    .HWRITE(HWRITE),
    .HRDATA(HRDATAEXT),
    .HREADY(HREADYEXT),
    .HRESP(HRESPEXT),
    .AWID(m_axi_awid),
    .AWADDR(m_axi_awaddr),
    .AWLEN(m_axi_awlen),
    .AWSIZE(m_axi_awsize),
    .AWBURST(m_axi_awburst),
    .AWLOCK(m_axi_awlock),
    .AWCACHE(m_axi_awcache),
    .AWPROT(m_axi_awprot),
    .AWQOS(m_axi_awqos),
    .AWVALID(m_axi_awvalid),
    .AWREADY(m_axi_awready),
    .WDATA(m_axi_wdata),
    .WSTRB(m_axi_wstrb),
    .WLAST(m_axi_wlast),
    .WVALID(m_axi_wvalid),
    .WREADY(m_axi_wready),
    .BID(m_axi_bid),
    .BRESP(m_axi_bresp),
    .BVALID(m_axi_bvalid),
    .BREADY(m_axi_bready),
    .ARID(m_axi_arid),
    .ARADDR(m_axi_araddr),
    .ARLEN(m_axi_arlen),
    .ARSIZE(m_axi_arsize),
    .ARBURST(m_axi_arburst),
    .ARLOCK(m_axi_arlock),
    .ARCACHE(m_axi_arcache),
    .ARPROT(m_axi_arprot),
    .ARQOS(m_axi_arqos),
    .ARVALID(m_axi_arvalid),
    .ARREADY(m_axi_arready),
    .RID(m_axi_rid),
    .RDATA(m_axi_rdata),
    .RRESP(m_axi_rresp),
    .RLAST(m_axi_rlast),
    .RVALID(m_axi_rvalid),
    .RREADY(m_axi_rready)
  );

  // ---------------------------------------------------------------------------
  // Bridge -> CDC source domain
  // ---------------------------------------------------------------------------
  assign cpu_axi_req.aw.id     = m_axi_awid;
  assign cpu_axi_req.aw.addr   = m_axi_awaddr;
  assign cpu_axi_req.aw.len    = m_axi_awlen;
  assign cpu_axi_req.aw.size   = m_axi_awsize;
  assign cpu_axi_req.aw.burst  = m_axi_awburst;
  assign cpu_axi_req.aw.lock   = m_axi_awlock;
  assign cpu_axi_req.aw.cache  = m_axi_awcache;
  assign cpu_axi_req.aw.prot   = m_axi_awprot;
  assign cpu_axi_req.aw.qos    = m_axi_awqos;
  assign cpu_axi_req.aw.region = 4'b0;
  assign cpu_axi_req.aw.atop   = 6'b0;
  assign cpu_axi_req.aw.user   = '0;
  assign cpu_axi_req.aw_valid  = m_axi_awvalid;
  assign m_axi_awready         = cpu_axi_resp.aw_ready;

  assign cpu_axi_req.w.data    = m_axi_wdata;
  assign cpu_axi_req.w.strb    = m_axi_wstrb;
  assign cpu_axi_req.w.last    = m_axi_wlast;
  assign cpu_axi_req.w.user    = '0;
  assign cpu_axi_req.w_valid   = m_axi_wvalid;
  assign m_axi_wready          = cpu_axi_resp.w_ready;

  assign m_axi_bid             = cpu_axi_resp.b.id;
  assign m_axi_bresp           = cpu_axi_resp.b.resp;
  assign m_axi_bvalid          = cpu_axi_resp.b_valid;
  assign cpu_axi_req.b_ready   = m_axi_bready;

  assign cpu_axi_req.ar.id     = m_axi_arid;
  assign cpu_axi_req.ar.addr   = m_axi_araddr;
  assign cpu_axi_req.ar.len    = m_axi_arlen;
  assign cpu_axi_req.ar.size   = m_axi_arsize;
  assign cpu_axi_req.ar.burst  = m_axi_arburst;
  assign cpu_axi_req.ar.lock   = m_axi_arlock;
  assign cpu_axi_req.ar.cache  = m_axi_arcache;
  assign cpu_axi_req.ar.prot   = m_axi_arprot;
  assign cpu_axi_req.ar.qos    = m_axi_arqos;
  assign cpu_axi_req.ar.region = 4'b0;
  assign cpu_axi_req.ar.user   = '0;
  assign cpu_axi_req.ar_valid  = m_axi_arvalid;
  assign m_axi_arready         = cpu_axi_resp.ar_ready;

  assign m_axi_rid             = cpu_axi_resp.r.id;
  assign m_axi_rdata           = cpu_axi_resp.r.data;
  assign m_axi_rresp           = cpu_axi_resp.r.resp;
  assign m_axi_rlast           = cpu_axi_resp.r.last;
  assign m_axi_rvalid          = cpu_axi_resp.r_valid;
  assign cpu_axi_req.r_ready   = m_axi_rready;

  axi_cdc #(
    .aw_chan_t  (slv_aw_t),
    .w_chan_t   (axi_w_t),
    .b_chan_t   (slv_b_t),
    .ar_chan_t  (slv_ar_t),
    .r_chan_t   (slv_r_t),
    .axi_req_t  (slv_req_t),
    .axi_resp_t (slv_resp_t),
    .LogDepth   (CDC_LOG_DEPTH),
    .SyncStages (CDC_SYNC_STAGES)
  ) axi_cdc_i (
    .src_clk_i  (clk),
    .src_rst_ni (~reset),
    .src_req_i  (cpu_axi_req),
    .src_resp_o (cpu_axi_resp),
    .dst_clk_i  (bus_clk),
    .dst_rst_ni (~bus_reset),
    .dst_req_o  (cdc_axi_req),
    .dst_resp_i (cdc_axi_resp)
  );

  // Slave port 0 is the real SoC traffic coming through the CDC.  Slave port 1
  // is an always-idle dummy master so the xbar is instantiated with more than
  // one requester.
  assign slv_req[0] = cdc_axi_req;
  assign cdc_axi_resp = slv_resp[0];
  assign slv_req[1] = '0;

  axi_xbar #(
    .Cfg           (XBAR_CFG),
    .ATOPs         (1'b0),
    .Connectivity  ('1),
    .slv_aw_chan_t (slv_aw_t),
    .mst_aw_chan_t (mst_aw_t),
    .w_chan_t      (axi_w_t),
    .slv_b_chan_t  (slv_b_t),
    .mst_b_chan_t  (mst_b_t),
    .slv_ar_chan_t (slv_ar_t),
    .mst_ar_chan_t (mst_ar_t),
    .slv_r_chan_t  (slv_r_t),
    .mst_r_chan_t  (mst_r_t),
    .slv_req_t     (slv_req_t),
    .slv_resp_t    (slv_resp_t),
    .mst_req_t     (mst_req_t),
    .mst_resp_t    (mst_resp_t),
    .rule_t        (axi_pkg::xbar_rule_32_t)
  ) axi_xbar_i (
    .clk_i                 (bus_clk),
    .rst_ni                (~bus_reset),
    .test_i                (1'b0),
    .slv_ports_req_i       (slv_req),
    .slv_ports_resp_o      (slv_resp),
    .mst_ports_req_o       (mst_req),
    .mst_ports_resp_i      (mst_resp),
    .addr_map_i            (XBAR_ADDR_MAP),
    .en_default_mst_port_i ('0),
    .default_mst_port_i    ('0)
  );

  axi_ram #(
    .DATA_WIDTH(BUSW),
    .ADDR_WIDTH(EXT_MEM_ADDR_WIDTH),
    .STRB_WIDTH(BUSW/8),
    .ID_WIDTH(AXI_MST_ID_WIDTH),
    .PIPELINE_OUTPUT(0)
  ) ext_ram_i (
    .clk           (bus_clk),
    .rst           (bus_reset),
    .s_axi_awid    (mst_req[0].aw.id),
    .s_axi_awaddr  (mst_req[0].aw.addr[EXT_MEM_ADDR_WIDTH-1:0]),
    .s_axi_awlen   (mst_req[0].aw.len),
    .s_axi_awsize  (mst_req[0].aw.size),
    .s_axi_awburst (mst_req[0].aw.burst),
    .s_axi_awlock  (mst_req[0].aw.lock),
    .s_axi_awcache (mst_req[0].aw.cache),
    .s_axi_awprot  (mst_req[0].aw.prot),
    .s_axi_awvalid (mst_req[0].aw_valid),
    .s_axi_awready (mst_resp[0].aw_ready),
    .s_axi_wdata   (mst_req[0].w.data),
    .s_axi_wstrb   (mst_req[0].w.strb),
    .s_axi_wlast   (mst_req[0].w.last),
    .s_axi_wvalid  (mst_req[0].w_valid),
    .s_axi_wready  (mst_resp[0].w_ready),
    .s_axi_bid     (mst_resp[0].b.id),
    .s_axi_bresp   (mst_resp[0].b.resp),
    .s_axi_bvalid  (mst_resp[0].b_valid),
    .s_axi_bready  (mst_req[0].b_ready),
    .s_axi_arid    (mst_req[0].ar.id),
    .s_axi_araddr  (mst_req[0].ar.addr[EXT_MEM_ADDR_WIDTH-1:0]),
    .s_axi_arlen   (mst_req[0].ar.len),
    .s_axi_arsize  (mst_req[0].ar.size),
    .s_axi_arburst (mst_req[0].ar.burst),
    .s_axi_arlock  (mst_req[0].ar.lock),
    .s_axi_arcache (mst_req[0].ar.cache),
    .s_axi_arprot  (mst_req[0].ar.prot),
    .s_axi_arvalid (mst_req[0].ar_valid),
    .s_axi_arready (mst_resp[0].ar_ready),
    .s_axi_rid     (mst_resp[0].r.id),
    .s_axi_rdata   (mst_resp[0].r.data),
    .s_axi_rresp   (mst_resp[0].r.resp),
    .s_axi_rlast   (mst_resp[0].r.last),
    .s_axi_rvalid  (mst_resp[0].r_valid),
    .s_axi_rready  (mst_req[0].r_ready)
  );

`ifdef SIM_AXI_SDHCI

  //-------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // SDHCI debug taps: command path
  // ---------------------------------------------------------------------------
  logic [5:0]  dbg_sdhci_current_cmd;
  logic [31:0] dbg_sdhci_current_arg;
  logic        dbg_sdhci_cmd_started;
  logic        dbg_sdhci_cmd_data_present;
  logic        dbg_sdhci_cmd_xfer_dir;
  logic        dbg_sdhci_cmd_needs_busy;
  logic        dbg_sdhci_sd_cmd_done;
  logic        dbg_sdhci_sd_rsp_done;

  logic        dbg_sdhci_cmd_result_valid;
  logic        dbg_sdhci_cmd_timeout_error;
  logic        dbg_sdhci_cmd_crc_error;
  logic        dbg_sdhci_cmd_index_error;
  logic        dbg_sdhci_cmd_end_bit_error;

  assign dbg_sdhci_current_cmd       = sdhci_i.i_axi_sdhci.i_autocmd_wrap.current_cmd;
  assign dbg_sdhci_current_arg       = sdhci_i.i_axi_sdhci.i_autocmd_wrap.current_arg;
  assign dbg_sdhci_cmd_started       = sdhci_i.i_axi_sdhci.cmd_started;
  assign dbg_sdhci_cmd_data_present  = sdhci_i.i_axi_sdhci.cmd_data_present;
  assign dbg_sdhci_cmd_xfer_dir      = sdhci_i.i_axi_sdhci.cmd_transfer_direction;
  assign dbg_sdhci_cmd_needs_busy    = sdhci_i.i_axi_sdhci.cmd_needs_busy;
  assign dbg_sdhci_sd_cmd_done       = sdhci_i.i_axi_sdhci.sd_cmd_done;
  assign dbg_sdhci_sd_rsp_done       = sdhci_i.i_axi_sdhci.sd_rsp_done;

  assign dbg_sdhci_cmd_result_valid  = sdhci_i.i_axi_sdhci.i_autocmd_wrap.cmd_result_valid;
  assign dbg_sdhci_cmd_timeout_error = sdhci_i.i_axi_sdhci.i_autocmd_wrap.timeout_error;
  assign dbg_sdhci_cmd_crc_error     = sdhci_i.i_axi_sdhci.i_autocmd_wrap.crc_error;
  assign dbg_sdhci_cmd_index_error   = sdhci_i.i_axi_sdhci.i_autocmd_wrap.index_error;
  assign dbg_sdhci_cmd_end_bit_error = sdhci_i.i_axi_sdhci.i_autocmd_wrap.end_bit_error;

  // ---------------------------------------------------------------------------
  // SDHCI debug taps: mode / register-derived state
  // ---------------------------------------------------------------------------
  logic        dbg_sdhci_bus_width_4;
  logic [9:0]  dbg_sdhci_block_size;
  logic [15:0] dbg_sdhci_block_count;
  logic        dbg_sdhci_read_transfer_active;
  logic        dbg_sdhci_write_transfer_active;
  logic        dbg_sdhci_buffer_read_enable;
  logic        dbg_sdhci_buffer_write_enable;
  logic        dbg_sdhci_pause_sd_clk;

  assign dbg_sdhci_bus_width_4          = sdhci_i.i_axi_sdhci.reg2hw.host_control.data_transfer_width.q;
  assign dbg_sdhci_block_size           = sdhci_i.i_axi_sdhci.reg2hw.block_size.transfer_block_size.q;
  assign dbg_sdhci_block_count          = sdhci_i.i_axi_sdhci.reg2hw.block_count.q;
  assign dbg_sdhci_read_transfer_active = sdhci_i.i_axi_sdhci.reg2hw.present_state.read_transfer_active.q;
  assign dbg_sdhci_write_transfer_active= sdhci_i.i_axi_sdhci.reg2hw.present_state.write_transfer_active.q;
  assign dbg_sdhci_buffer_read_enable   = sdhci_i.i_axi_sdhci.hw2reg.present_state.buffer_read_enable.d;
  assign dbg_sdhci_buffer_write_enable  = sdhci_i.i_axi_sdhci.hw2reg.present_state.buffer_write_enable.d;
  assign dbg_sdhci_pause_sd_clk         = sdhci_i.i_axi_sdhci.pause_sd_clk;

  // ---------------------------------------------------------------------------
  // SDHCI debug taps: data FSM
  // ---------------------------------------------------------------------------
  logic [1:0]  dbg_sdhci_dat_state;
  logic [2:0]  dbg_sdhci_read_state;
  logic [2:0]  dbg_sdhci_write_state;

  logic        dbg_sdhci_start_read;
  logic        dbg_sdhci_read_valid;
  logic        dbg_sdhci_read_done;
  logic        dbg_sdhci_read_crc_err;
  logic        dbg_sdhci_read_end_bit_err;
  logic        dbg_sdhci_timeout_elapsed;

  logic        dbg_sdhci_buffer_write_valid;
  logic        dbg_sdhci_buffer_write_ready;
  logic [31:0] dbg_sdhci_buffer_write_data;
  logic        dbg_sdhci_buffer_read_valid;
  logic        dbg_sdhci_buffer_read_ready;
  logic [31:0] dbg_sdhci_buffer_read_data;
  logic        dbg_sdhci_buffer_empty;

  assign dbg_sdhci_dat_state           = sdhci_i.i_axi_sdhci.i_dat_wrap.dat_state_q;
  assign dbg_sdhci_read_state          = sdhci_i.i_axi_sdhci.i_dat_wrap.read_state_q;
  assign dbg_sdhci_write_state         = sdhci_i.i_axi_sdhci.i_dat_wrap.write_state_q;

  assign dbg_sdhci_start_read          = sdhci_i.i_axi_sdhci.i_dat_wrap.start_read;
  assign dbg_sdhci_read_valid          = sdhci_i.i_axi_sdhci.i_dat_wrap.read_valid;
  assign dbg_sdhci_read_done           = sdhci_i.i_axi_sdhci.i_dat_wrap.read_done;
  assign dbg_sdhci_read_crc_err        = sdhci_i.i_axi_sdhci.i_dat_wrap.read_crc_err;
  assign dbg_sdhci_read_end_bit_err    = sdhci_i.i_axi_sdhci.i_dat_wrap.read_end_bit_err;
  assign dbg_sdhci_timeout_elapsed     = sdhci_i.i_axi_sdhci.i_dat_wrap.timeout_elapsed;

  assign dbg_sdhci_buffer_write_valid  = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_write_valid;
  assign dbg_sdhci_buffer_write_ready  = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_write_ready;
  assign dbg_sdhci_buffer_write_data   = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_write_data;
  assign dbg_sdhci_buffer_read_valid   = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_read_valid;
  assign dbg_sdhci_buffer_read_ready   = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_read_ready;
  assign dbg_sdhci_buffer_read_data    = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_read_data;
  assign dbg_sdhci_buffer_empty        = sdhci_i.i_axi_sdhci.i_dat_wrap.buffer_empty;

  // ---------------------------------------------------------------------------
  // SDHCI debug taps: dat_buffer / SRAM shift register
  // ---------------------------------------------------------------------------
  logic        dbg_sdhci_reg_push;
  logic [31:0] dbg_sdhci_reg_push_data;
  logic        dbg_sdhci_reg_pop;
  logic [31:0] dbg_sdhci_reg_pop_data;
  logic        dbg_sdhci_reg_empty;
  logic [8:0]  dbg_sdhci_reg_length;
  logic        dbg_sdhci_has_block;
  logic        dbg_sdhci_has_space;
  logic [9:0]  dbg_sdhci_current_word_counter;

  logic        dbg_sdhci_sram_en;
  logic        dbg_sdhci_sram_pop_front_i;
  logic        dbg_sdhci_sram_pop_front_q;
  logic        dbg_sdhci_sram_push_back_i;
  logic [31:0] dbg_sdhci_sram_back_data_i;
  logic [31:0] dbg_sdhci_sram_front_data_o;
  logic        dbg_sdhci_sram_empty_o;
  logic [8:0]  dbg_sdhci_sram_length_o;

  assign dbg_sdhci_reg_push            = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_push;
  assign dbg_sdhci_reg_push_data       = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_push_data;
  assign dbg_sdhci_reg_pop             = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_pop;
  assign dbg_sdhci_reg_pop_data        = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_pop_data;
  assign dbg_sdhci_reg_empty           = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_empty;
  assign dbg_sdhci_reg_length          = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.reg_length;
  assign dbg_sdhci_has_block           = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.has_block;
  // not in newer version of the RTL
  //assign dbg_sdhci_has_space           = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.has_space;
  assign dbg_sdhci_current_word_counter= sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.current_word_counter_q;

  assign dbg_sdhci_sram_en             = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.en_i;
  assign dbg_sdhci_sram_pop_front_i    = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.pop_front_i;
  assign dbg_sdhci_sram_pop_front_q    = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.pop_front_q;
  assign dbg_sdhci_sram_push_back_i    = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.push_back_i;
  assign dbg_sdhci_sram_back_data_i    = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.back_data_i;
  assign dbg_sdhci_sram_front_data_o   = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.front_data_o;
  assign dbg_sdhci_sram_empty_o        = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.empty_o;
  assign dbg_sdhci_sram_length_o       = sdhci_i.i_axi_sdhci.i_dat_wrap.i_dat_buffer.i_sram_shift_reg.length_o;

  // ---------------------------------------------------------------------------
  // Optional but very useful: correlate SW reads of SDHCI buffer port 0x20
  // ---------------------------------------------------------------------------
//   logic dbg_sdhci_mmio_bufport_read_fire;
//   logic dbg_sdhci_mmio_bufport_write_fire;

//   assign dbg_sdhci_mmio_bufport_read_fire =
//       mst_req[1].ar_valid && mst_resp[1].ar_ready &&
//       (mst_req[1].ar.addr[15:0] == 16'h0020);

//   assign dbg_sdhci_mmio_bufport_write_fire =
//       mst_req[1].aw_valid && mst_resp[1].aw_ready &&
//       (mst_req[1].aw.addr[15:0] == 16'h0020);

//   logic dbg_sdhci_mmio_intstat_read_fire;
//   logic dbg_sdhci_mmio_intstat_aw_fire;
//   logic dbg_sdhci_mmio_w_fire;
//   logic [63:0] dbg_sdhci_mmio_wdata;

//   assign dbg_sdhci_mmio_intstat_read_fire =
//     mst_req[1].ar_valid && mst_resp[1].ar_ready &&
//     (mst_req[1].ar.addr[15:0] == 16'h0030);

//   assign dbg_sdhci_mmio_intstat_aw_fire =
//     mst_req[1].aw_valid && mst_resp[1].aw_ready &&
//     (mst_req[1].aw.addr[15:0] == 16'h0030);

//   assign dbg_sdhci_mmio_w_fire =
//     mst_req[1].w_valid && mst_resp[1].w_ready;

//   assign dbg_sdhci_mmio_wdata = mst_req[1].w.data;
  //-------------------------------------------------------------------------

  logic       sd_clk_o;
  logic       sd_cd_ni;
  logic       sd_cmd_en;
  logic       sd_cmd_o;
  logic       sd_cmd_i;
  logic       sd_dat_en;
  logic [3:0] sd_dat_o;
  logic [3:0] sd_dat_i;

  axi_sdhci_wrap #(
    .AXI_ADDR_W ( PERIPH_ADDR_WIDTH ),
    .AXI_DATA_W ( BUSW              ),
    .AXI_ID_W   ( AXI_MST_ID_WIDTH  ),
    .AXI_USER_W ( 1                 )
  ) sdhci_i (
      // For simplicity we use same clock as the bus
      .aclk(bus_clk),
      //.aclk(sdhci_clk),
      .aresetn(~bus_reset),

    .s_axi_awid    (mst_req[1].aw.id),
    .s_axi_awaddr  (mst_req[1].aw.addr[PERIPH_ADDR_WIDTH-1:0]),
    .s_axi_awlen   (mst_req[1].aw.len),
    .s_axi_awsize  (mst_req[1].aw.size),
    .s_axi_awburst (mst_req[1].aw.burst),
    .s_axi_awlock  (mst_req[1].aw.lock),
    .s_axi_awcache (mst_req[1].aw.cache),
    .s_axi_awprot  (mst_req[1].aw.prot),
    .s_axi_awvalid (mst_req[1].aw_valid),
    .s_axi_awready (mst_resp[1].aw_ready),
    .s_axi_wdata   (mst_req[1].w.data),
    .s_axi_wstrb   (mst_req[1].w.strb),
    .s_axi_wlast   (mst_req[1].w.last),
    .s_axi_wvalid  (mst_req[1].w_valid),
    .s_axi_wready  (mst_resp[1].w_ready),
    .s_axi_bid     (mst_resp[1].b.id),
    .s_axi_bresp   (mst_resp[1].b.resp),
    .s_axi_bvalid  (mst_resp[1].b_valid),
    .s_axi_bready  (mst_req[1].b_ready),
    .s_axi_arid    (mst_req[1].ar.id),
    .s_axi_araddr  (mst_req[1].ar.addr[PERIPH_ADDR_WIDTH-1:0]),
    .s_axi_arlen   (mst_req[1].ar.len),
    .s_axi_arsize  (mst_req[1].ar.size),
    .s_axi_arburst (mst_req[1].ar.burst),
    .s_axi_arlock  (mst_req[1].ar.lock),
    .s_axi_arcache (mst_req[1].ar.cache),
    .s_axi_arprot  (mst_req[1].ar.prot),
    .s_axi_arvalid (mst_req[1].ar_valid),
    .s_axi_arready (mst_resp[1].ar_ready),
    .s_axi_rid     (mst_resp[1].r.id),
    .s_axi_rdata   (mst_resp[1].r.data),
    .s_axi_rresp   (mst_resp[1].r.resp),
    .s_axi_rlast   (mst_resp[1].r.last),
    .s_axi_rvalid  (mst_resp[1].r_valid),
    .s_axi_rready  (mst_req[1].r_ready),

    // SDHCI pins
    .sd_clk_o(sd_clk_o),
    .sd_cd_ni(sd_cd_ni),
    .sd_cmd_en_o(sd_cmd_en),
    .sd_cmd_o(sd_cmd_o),
    .sd_cmd_i(sd_cmd_i),

    .sd_dat_i(sd_dat_i),
    .sd_dat_o(sd_dat_o),
    .sd_dat_en_o(sd_dat_en),

    //.interrupt_o(AXI_DummyIntr)
    .interrupt_o(AXI_SDHCIIntr_orig)
  );

    // This might not be necessary on simulation
    sync #(
        .STAGES ( 2 ) // 2-flip flop
    ) i_sync (
        .clk_i    ( clk ),
        .rst_ni   ( ~reset ),
        .serial_i ( AXI_SDHCIIntr_orig ),
        .serial_o ( AXI_SDHCIIntr )
    );

  ////////////////////
  //  SD card model //
  ////////////////////

  sd_card i_sd_card (
    .sd_clk_i ( sd_clk_o  ),
    .cmd_en_i ( sd_cmd_en ),
    .cmd_i    ( sd_cmd_o  ),
    .cmd_o    ( sd_cmd_i  ),
    .dat_en_i ( sd_dat_en ),
    .dat_i    ( sd_dat_o  ),
    .dat_o    ( sd_dat_i  )
  );

  assign sd_cd_ni = '0;
  assign mst_resp[1].b.user = '0;
  assign mst_resp[1].r.user = '0;

`else
  assign mst_resp[1] = '0;
  assign AXI_DummyIntr = 1'b0;
`endif

`ifdef SIM_AXI_RAM
  axi_ram #(
    .DATA_WIDTH(BUSW),
    .ADDR_WIDTH(PERIPH_ADDR_WIDTH),
    .STRB_WIDTH(BUSW/8),
    .ID_WIDTH(AXI_MST_ID_WIDTH),
    .PIPELINE_OUTPUT(0)
  ) axi_dummy_ram_i (
    .clk           (bus_clk),
    .rst           (bus_reset),
    .s_axi_awid    (mst_req[2].aw.id),
    .s_axi_awaddr  (mst_req[2].aw.addr[PERIPH_ADDR_WIDTH-1:0]),
    .s_axi_awlen   (mst_req[2].aw.len),
    .s_axi_awsize  (mst_req[2].aw.size),
    .s_axi_awburst (mst_req[2].aw.burst),
    .s_axi_awlock  (mst_req[2].aw.lock),
    .s_axi_awcache (mst_req[2].aw.cache),
    .s_axi_awprot  (mst_req[2].aw.prot),
    .s_axi_awvalid (mst_req[2].aw_valid),
    .s_axi_awready (mst_resp[2].aw_ready),
    .s_axi_wdata   (mst_req[2].w.data),
    .s_axi_wstrb   (mst_req[2].w.strb),
    .s_axi_wlast   (mst_req[2].w.last),
    .s_axi_wvalid  (mst_req[2].w_valid),
    .s_axi_wready  (mst_resp[2].w_ready),
    .s_axi_bid     (mst_resp[2].b.id),
    .s_axi_bresp   (mst_resp[2].b.resp),
    .s_axi_bvalid  (mst_resp[2].b_valid),
    .s_axi_bready  (mst_req[2].b_ready),
    .s_axi_arid    (mst_req[2].ar.id),
    .s_axi_araddr  (mst_req[2].ar.addr[PERIPH_ADDR_WIDTH-1:0]),
    .s_axi_arlen   (mst_req[2].ar.len),
    .s_axi_arsize  (mst_req[2].ar.size),
    .s_axi_arburst (mst_req[2].ar.burst),
    .s_axi_arlock  (mst_req[2].ar.lock),
    .s_axi_arcache (mst_req[2].ar.cache),
    .s_axi_arprot  (mst_req[2].ar.prot),
    .s_axi_arvalid (mst_req[2].ar_valid),
    .s_axi_arready (mst_resp[2].ar_ready),
    .s_axi_rid     (mst_resp[2].r.id),
    .s_axi_rdata   (mst_resp[2].r.data),
    .s_axi_rresp   (mst_resp[2].r.resp),
    .s_axi_rlast   (mst_resp[2].r.last),
    .s_axi_rvalid  (mst_resp[2].r_valid),
    .s_axi_rready  (mst_req[2].r_ready)
  );
  assign mst_resp[2].b.user = '0;
  assign mst_resp[2].r.user = '0;

`else
  assign mst_resp[2] = '0;
`endif

  // ---------------------------------------------------------------------------
  // PLIC debug for SDHCI interrupt routed as PLIC_AXI_DUMMY_ID / AXIDummyIntr
  // Expected hierarchy: soc.uncore.plic.plic
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // PLIC debug exported by bind from plic_apb_dbg_bind
  // ---------------------------------------------------------------------------
  wire [5:0]  dbg_plic_axi_dummy_id;

  wire        dbg_plic_src_irq;
  wire        dbg_plic_req;
  wire        dbg_plic_pending;
  wire        dbg_plic_next_pending;
  wire        dbg_plic_in_progress;

  wire [2:0]  dbg_plic_priority;
  wire        dbg_plic_en_ctx0;
  wire        dbg_plic_en_ctx1;
  wire [2:0]  dbg_plic_threshold_ctx0;
  wire [2:0]  dbg_plic_threshold_ctx1;

  wire [5:0]  dbg_plic_claim_ctx0;
  wire [5:0]  dbg_plic_claim_ctx1;

  wire [6:0]  dbg_plic_priorities_with_irqs_ctx0;
  wire [6:0]  dbg_plic_priorities_with_irqs_ctx1;
  wire [6:0]  dbg_plic_threshmask_ctx0;
  wire [6:0]  dbg_plic_threshmask_ctx1;

  wire        dbg_plic_irq_at_max_ctx0;
  wire        dbg_plic_irq_at_max_ctx1;

  wire        dbg_plic_mextint;
  wire        dbg_plic_sextint;

  wire        dbg_plic_memread;
  wire        dbg_plic_memwrite;
  wire [23:0] dbg_plic_entry;
  wire [31:0] dbg_plic_din;
  wire [31:0] dbg_plic_dout;

  wire        dbg_plic_claim0_read;
  wire        dbg_plic_claim1_read;
  wire        dbg_plic_claim0_write;
  wire        dbg_plic_claim1_write;

  //-----------------------------------------------
  //-----------------------------------------------
  //-----------------------------------------------
  //-----------------------------------------------
  //-----------------------------------------------

  assign mst_resp[0].b.user = '0;
  assign mst_resp[0].r.user = '0;

  // ---------------------------------------------------------------------------
  // Runtime controls
  // ---------------------------------------------------------------------------
  string bootrom_bin;
  string bootrom_memh;
  string uncore_ram_memh;
  string ext_ram_bin;
  string uart_log_path;
  bit    uncore_ram_memh_given = 1'b0;
  bit    trace_started = 1'b0;
  bit    trace_stopped = 1'b0;
  bit    trace_start_on_kernel_entry = 1'b0;
  bit    trace_full_dump = 1'b0;
  bit    trace_uart_dump = 1'b0;
  bit    trace_external_control = 1'b0;
  bit    uart_autorunmount = 1'b0;
  bit    uart_autoruncmd = 1'b0;
  bit    uart_input_enable = 1'b0;
  bit    uart_timestamp = 1'b1;
  bit    uart_line_start = 1'b1;
  bit    uart_after_cr = 1'b0;
  bit    uart_log_enable = 1'b0;
  integer uart_stdout = 0;
  integer uart_shell_tags = 1;
  longint unsigned max_cycles = 1000_000_000;
  longint unsigned trace_start_cycle = 0;
  longint unsigned trace_stop_cycle = 0;
  longint unsigned trace_length_cycles = 0;
  longint unsigned trace_stop_cycle_effective = 0;
  longint unsigned trace_poll_cycles = 1_000_000;
  longint unsigned uart_input_poll_cycles = 1_000_000;
  longint unsigned trace_capture_index = 0;
  longint unsigned cycle_count = 0;
  longint unsigned next_heartbeat_cycle = HEARTBEAT_CYCLES;
  longint unsigned heartbeat_speed_interval_cycles = HEARTBEAT_SPEED_INTERVAL_CYCLES_DEFAULT;
  longint unsigned next_speed_report_cycle = HEARTBEAT_SPEED_INTERVAL_CYCLES_DEFAULT;
  longint unsigned heartbeat_speed_prev_cycle = 0;
  longint unsigned next_trace_poll_cycle = 1_000_000;
  longint unsigned next_uart_input_poll_cycle = 1_000_000;
  integer file_handle;
  integer bytes_read;
  integer uart_file;
  bit    kernel_entry_seen = 1'b0;
  bit    uart_login_sent = 1'b0;
  bit    uart_mount_sent = 1'b0;
  bit    uart_runcmd_sent = 1'b0;
  bit    uart_tx_busy = 1'b0;
  bit    heartbeat_speed_initialized = 1'b0;
  string uart_recent = "";
  string trace_start_file = "";
  string trace_stop_file = "";
  string trace_file_prefix = "dump";
  string trace_file_name = "";
  string uart_input_file = "";
  string uart_runcmd_file = "";
  real   heartbeat_speed_prev_wall_s = 0.0;
  real   heartbeat_speed_elapsed_wall_s = 0.0;
  real   heartbeat_cycles_per_s = 0.0;
  string uart_shell_prefix = "";
  string uart_shell_line = "";

  function automatic real current_wallclock_seconds();
    begin
`ifdef VERILATOR
      current_wallclock_seconds = wallclock_seconds();
`else
      current_wallclock_seconds = 0.0;
`endif
    end
  endfunction

  function automatic bit string_ends_with(input string value, input string suffix);
    int value_len;
    int suffix_len;
    begin
      value_len = value.len();
      suffix_len = suffix.len();
      if (suffix_len > value_len)
        return 1'b0;
      return value.substr(value_len - suffix_len, value_len - 1) == suffix;
    end
  endfunction

  function automatic bit file_exists(input string path);
    integer fd;
    begin
      if (path.len() == 0)
        return 1'b0;
      fd = $fopen(path, "r");
      if (fd != 0) begin
        $fclose(fd);
        return 1'b1;
      end
      return 1'b0;
    end
  endfunction

  task automatic consume_trigger_file(input string path, output bit triggered);
    integer fd;
    integer rc;
    begin
      triggered = 1'b0;
      if (path.len() == 0)
        return;
      fd = $fopen(path, "r");
      if (fd != 0) begin
        $fclose(fd);
        rc = $system({"rm -f ", path});
        rc = rc;
        triggered = 1'b1;
      end
    end
  endtask

  task automatic consume_text_file(input string path, output bit triggered, output string content);
    integer fd;
    integer rc;
    string line;
    begin
      triggered = 1'b0;
      content = "";
      if (path.len() == 0)
        return;
      fd = $fopen(path, "r");
      if (fd != 0) begin
        while ($fgets(line, fd) != 0)
          content = {content, line};
        $fclose(fd);
        rc = $system({"rm -f ", path});
        rc = rc;
        triggered = 1'b1;
      end
    end
  endtask

  task automatic uart_send_byte(input byte ch);
    int bit_idx;
    begin
      UARTSin = 1'b0;
      #(UART_BIT_PERIOD_NS);
      for (bit_idx = 0; bit_idx < 8; bit_idx++) begin
        UARTSin = ch[bit_idx];
        #(UART_BIT_PERIOD_NS);
      end
      UARTSin = 1'b1;
      #(UART_BIT_PERIOD_NS);
    end
  endtask

  task automatic uart_send_string(input string text, input string label);
    int char_idx;
    byte ch;
    begin
      wait (!uart_tx_busy);
      uart_tx_busy = 1'b1;
      #(UART_TX_START_DELAY_NS);
      $display("[uart-in] sending %0s at cycle=%0d", label, cycle_count);
      for (char_idx = 0; char_idx < text.len(); char_idx++) begin
        ch = text[char_idx];
        uart_send_byte(ch);
      end
      uart_tx_busy = 1'b0;
    end
  endtask

  task automatic dump_cpu_gprs;
    begin
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[1]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[2]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[3]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[4]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[5]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[6]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[7]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[8]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[9]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[10]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[11]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[12]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[13]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[14]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[15]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[16]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[17]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[18]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[19]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[20]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[21]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[22]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[23]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[24]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[25]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[26]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[27]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[28]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[29]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[30]);
      $dumpvars(0, testbench_cvwsoc.soc.core.ieu.dp.regf.rf[31]);
    end
  endtask

  task automatic dump_bridge_debug_scope;
    begin
      $dumpvars(0, testbench_cvwsoc.cycle_count);
      $dumpvars(0, testbench_cvwsoc.PCM);
      $dumpvars(0, testbench_cvwsoc.InstrValidM);
      $dumpvars(0, testbench_cvwsoc.TrapM);
      $dumpvars(0, testbench_cvwsoc.soc.core.InstrM);
      dump_cpu_gprs();

      $dumpvars(0, testbench_cvwsoc.HSELEXT);
      $dumpvars(0, testbench_cvwsoc.HADDR);
      $dumpvars(0, testbench_cvwsoc.HWDATA);
      $dumpvars(0, testbench_cvwsoc.HWSTRB);
      $dumpvars(0, testbench_cvwsoc.HWRITE);
      $dumpvars(0, testbench_cvwsoc.HSIZE);
      $dumpvars(0, testbench_cvwsoc.HBURST);
      $dumpvars(0, testbench_cvwsoc.HPROT);
      $dumpvars(0, testbench_cvwsoc.HTRANS);
      $dumpvars(0, testbench_cvwsoc.HMASTLOCK);
      $dumpvars(0, testbench_cvwsoc.HREADY);
      $dumpvars(0, testbench_cvwsoc.HREADYEXT);
      $dumpvars(0, testbench_cvwsoc.HRESPEXT);
      $dumpvars(0, testbench_cvwsoc.HRDATAEXT);

      $dumpvars(0, testbench_cvwsoc.m_axi_awid);
      $dumpvars(0, testbench_cvwsoc.m_axi_awaddr);
      $dumpvars(0, testbench_cvwsoc.m_axi_awlen);
      $dumpvars(0, testbench_cvwsoc.m_axi_awsize);
      $dumpvars(0, testbench_cvwsoc.m_axi_awburst);
      $dumpvars(0, testbench_cvwsoc.m_axi_awlock);
      $dumpvars(0, testbench_cvwsoc.m_axi_awcache);
      $dumpvars(0, testbench_cvwsoc.m_axi_awprot);
      $dumpvars(0, testbench_cvwsoc.m_axi_awqos);
      $dumpvars(0, testbench_cvwsoc.m_axi_awvalid);
      $dumpvars(0, testbench_cvwsoc.m_axi_awready);

      $dumpvars(0, testbench_cvwsoc.m_axi_wdata);
      $dumpvars(0, testbench_cvwsoc.m_axi_wstrb);
      $dumpvars(0, testbench_cvwsoc.m_axi_wlast);
      $dumpvars(0, testbench_cvwsoc.m_axi_wvalid);
      $dumpvars(0, testbench_cvwsoc.m_axi_wready);

      $dumpvars(0, testbench_cvwsoc.m_axi_bid);
      $dumpvars(0, testbench_cvwsoc.m_axi_bresp);
      $dumpvars(0, testbench_cvwsoc.m_axi_bvalid);
      $dumpvars(0, testbench_cvwsoc.m_axi_bready);

      $dumpvars(0, testbench_cvwsoc.m_axi_arid);
      $dumpvars(0, testbench_cvwsoc.m_axi_araddr);
      $dumpvars(0, testbench_cvwsoc.m_axi_arlen);
      $dumpvars(0, testbench_cvwsoc.m_axi_arsize);
      $dumpvars(0, testbench_cvwsoc.m_axi_arburst);
      $dumpvars(0, testbench_cvwsoc.m_axi_arlock);
      $dumpvars(0, testbench_cvwsoc.m_axi_arcache);
      $dumpvars(0, testbench_cvwsoc.m_axi_arprot);
      $dumpvars(0, testbench_cvwsoc.m_axi_arqos);
      $dumpvars(0, testbench_cvwsoc.m_axi_arvalid);
      $dumpvars(0, testbench_cvwsoc.m_axi_arready);

      $dumpvars(0, testbench_cvwsoc.m_axi_rid);
      $dumpvars(0, testbench_cvwsoc.m_axi_rdata);
      $dumpvars(0, testbench_cvwsoc.m_axi_rresp);
      $dumpvars(0, testbench_cvwsoc.m_axi_rlast);
      $dumpvars(0, testbench_cvwsoc.m_axi_rvalid);
      $dumpvars(0, testbench_cvwsoc.m_axi_rready);

      $dumpvars(0, testbench_cvwsoc.bus_clk);
      $dumpvars(0, testbench_cvwsoc.bus_reset);
      $dumpvars(0, testbench_cvwsoc.cdc_axi_req.aw.addr);
      $dumpvars(0, testbench_cvwsoc.cdc_axi_req.aw_valid);
      $dumpvars(0, testbench_cvwsoc.cdc_axi_req.w_valid);
      $dumpvars(0, testbench_cvwsoc.cdc_axi_req.ar.addr);
      $dumpvars(0, testbench_cvwsoc.cdc_axi_req.ar_valid);
      $dumpvars(0, testbench_cvwsoc.mst_req[0].aw.addr);
      $dumpvars(0, testbench_cvwsoc.mst_req[0].aw_valid);
      $dumpvars(0, testbench_cvwsoc.mst_req[0].ar.addr);
      $dumpvars(0, testbench_cvwsoc.mst_req[0].ar_valid);
      $dumpvars(0, testbench_cvwsoc.mst_req[1].aw.addr);
      $dumpvars(0, testbench_cvwsoc.mst_req[1].aw_valid);
      $dumpvars(0, testbench_cvwsoc.mst_req[1].ar.addr);
      $dumpvars(0, testbench_cvwsoc.mst_req[1].ar_valid);
    end
  endtask

  task automatic start_trace_capture(input longint unsigned start_cycle);
    longint unsigned start_time_ns;
    begin
      start_time_ns = start_cycle * CLK_PERIOD_NS;
      trace_capture_index = trace_capture_index + 1;
      trace_file_name = $sformatf("%s_capture_%0d_cycle_%0d.fst",
                                  trace_file_prefix, trace_capture_index, start_cycle);
      $dumpfile(trace_file_name);
      if (trace_full_dump) begin
        $dumpvars(0, testbench_cvwsoc);
      end else begin
        dump_bridge_debug_scope();
        if (trace_uart_dump) begin
          $dumpvars(0, testbench_cvwsoc.soc.uncoregen.uncore.uartgen.uart.MEMWb);
          $dumpvars(0, testbench_cvwsoc.soc.uncoregen.uncore.uartgen.uart.uartPC.A);
          $dumpvars(0, testbench_cvwsoc.soc.uncoregen.uncore.uartgen.uart.uartPC.Din);
          $dumpvars(0, testbench_cvwsoc.soc.uncoregen.uncore.uartgen.uart.uartPC.DLAB);
        end
      end
      $dumpflush;
      trace_started = 1'b1;
      trace_stopped = 1'b0;
      if (trace_length_cycles != 0)
        trace_stop_cycle_effective = start_cycle + trace_length_cycles;
      else
        trace_stop_cycle_effective = trace_stop_cycle;
      $display("[trace] started file=%0s cycle=%0d approx_ns=%0d mode=%0s stop_cycle=%0d",
               trace_file_name,
               start_cycle,
               start_time_ns,
               trace_full_dump ? "full" : (trace_uart_dump ? "bridge+fabric+cpu+uart" : "bridge+fabric+cpu"),
               trace_stop_cycle_effective);
    end
  endtask

  initial begin
    if (!$value$plusargs("BOOTROM_BIN=%s", bootrom_bin))
      bootrom_bin = "";
    if (!$value$plusargs("BOOTROM_MEMH=%s", bootrom_memh))
      bootrom_memh = {WALLY_DIR, "/fpga/src/boot.mem"};
    if (!$value$plusargs("EXT_RAM_BIN=%s", ext_ram_bin))
      ext_ram_bin = "";
    uncore_ram_memh_given = $value$plusargs("UNCORE_RAM_MEMH=%s", uncore_ram_memh);
    if (!uncore_ram_memh_given) begin
      if ((bootrom_bin.len() != 0) || (ext_ram_bin.len() != 0))
        uncore_ram_memh = "";
      else
        uncore_ram_memh = {WALLY_DIR, "/fpga/src/data.mem"};
    end
    if (!$value$plusargs("UART_LOG=%s", uart_log_path))
      uart_log_path = "";
    void'($value$plusargs("UART_STDOUT=%d", uart_stdout));
    void'($value$plusargs("UART_TIMESTAMP=%d", uart_timestamp));
    void'($value$plusargs("UART_SHELL_TAGS=%d", uart_shell_tags));
    void'($value$plusargs("UART_AUTORUNMOUNT=%d", uart_autorunmount));
    void'($value$plusargs("UART_AUTORUNCMD=%d", uart_autoruncmd));
    void'($value$plusargs("UART_INPUT_ENABLE=%d", uart_input_enable));
    void'($value$plusargs("UART_INPUT_POLL_CYCLES=%d", uart_input_poll_cycles));
    void'($value$plusargs("UART_INPUT_FILE=%s", uart_input_file));
    void'($value$plusargs("UART_RUNCMD_FILE=%s", uart_runcmd_file));
    void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
    void'($value$plusargs("HEARTBEAT_SPEED_INTERVAL_CYCLES=%d", heartbeat_speed_interval_cycles));
    void'($value$plusargs("TRACE_START_CYCLE=%d", trace_start_cycle));
    void'($value$plusargs("TRACE_STOP_CYCLE=%d", trace_stop_cycle));
    void'($value$plusargs("TRACE_LENGTH_CYCLES=%d", trace_length_cycles));
    void'($value$plusargs("TRACE_POLL_CYCLES=%d", trace_poll_cycles));
    void'($value$plusargs("TRACE_START_ON_KERNEL_ENTRY=%d", trace_start_on_kernel_entry));
    void'($value$plusargs("TRACE_EXTERNAL_CONTROL=%d", trace_external_control));
    void'($value$plusargs("TRACE_START_FILE=%s", trace_start_file));
    void'($value$plusargs("TRACE_STOP_FILE=%s", trace_stop_file));
    void'($value$plusargs("TRACE_FILE_PREFIX=%s", trace_file_prefix));
    void'($value$plusargs("TRACE_FULL=%d", trace_full_dump));
    void'($value$plusargs("TRACE_UART=%d", trace_uart_dump));

    uart_log_enable = (uart_log_path.len() != 0);
    if (uart_log_enable) begin
      uart_file = $fopen(uart_log_path, "w");
      if (uart_file == 0) begin
        $error("Could not open UART log file %s", uart_log_path);
        $finish;
      end
    end

    repeat (2) @(posedge clk);

    if (bootrom_bin.len() != 0) begin
      file_handle = $fopen(bootrom_bin, "rb");
      if (file_handle == 0) begin
        $error({"Could not open boot ROM image ", bootrom_bin,
                ". Override with +BOOTROM_BIN=<path> if needed."});
        $finish;
      end
      bytes_read = $fread(soc.uncoregen.uncore.bootrom.bootrom.memory.ROM,
                           file_handle,
                           BOOTROM_PRELOAD_START);
      $fclose(file_handle);
      $display("Loaded %0d bytes of boot ROM from %s", bytes_read, bootrom_bin);
    end else begin
      $display("Loading at %0d, %0d words of boot ROM from %s", BOOTROM_PRELOAD_START, BOOTROM_WORDS - 1, bootrom_memh);
      $readmemh(bootrom_memh,
                soc.uncoregen.uncore.bootrom.bootrom.memory.ROM,
                BOOTROM_PRELOAD_START,
                BOOTROM_WORDS - 1);
      $display("Loaded boot ROM hex from %s", bootrom_memh);
    end

    if (P.UNCORE_RAM_SUPPORTED) begin
      if (uncore_ram_memh.len() != 0) begin
        $readmemh(uncore_ram_memh,
                  soc.uncoregen.uncore.ram.ram.memory.ram.RAM,
                  0,
                  UNCORE_RAM_WORDS - 1);
        $display("Loaded uncore RAM hex from %s", uncore_ram_memh);
      end else begin
        $display("Uncore RAM left zero-initialized.");
      end
    end

    if (ext_ram_bin.len() != 0) begin
      file_handle = $fopen(ext_ram_bin, "rb");
      if (file_handle == 0) begin
        $error({"Could not open external RAM image ", ext_ram_bin,
                ". Override with +EXT_RAM_BIN=<path> if needed."});
        $finish;
      end
      bytes_read = $fread(ext_ram_i.mem, file_handle);
      $fclose(file_handle);
      $display("Loaded %0d bytes of external RAM from %s", bytes_read, ext_ram_bin);
    end else begin
      $display("External AXI RAM left zero-initialized.");
    end
    if (uart_log_enable)
      $display("UART log: %s", uart_log_path);
    else
      $display("UART log: disabled");

    if (MAKE_VCD) begin
      if (!trace_start_on_kernel_entry && trace_start_cycle == 0) begin
        if (!trace_external_control)
          start_trace_capture(0);
      end
    end
  end

  always @(posedge clk) begin
    bit trace_start_request;
    bit trace_stop_request;
    if (reset) begin
      cycle_count <= 0;
      next_heartbeat_cycle <= HEARTBEAT_CYCLES;
      next_speed_report_cycle <= heartbeat_speed_interval_cycles;
      heartbeat_speed_prev_cycle <= 0;
      next_trace_poll_cycle <= trace_poll_cycles;
      next_uart_input_poll_cycle <= uart_input_poll_cycles;
      kernel_entry_seen <= 1'b0;
      uart_login_sent <= 1'b0;
      uart_mount_sent <= 1'b0;
      uart_runcmd_sent <= 1'b0;
      heartbeat_speed_initialized <= 1'b0;
      uart_recent = "";
      heartbeat_speed_prev_wall_s = 0.0;
      heartbeat_speed_elapsed_wall_s = 0.0;
      heartbeat_cycles_per_s = 0.0;
    end else begin
      trace_start_request = 1'b0;
      trace_stop_request = 1'b0;
      begin
        bit uart_input_request;
        string uart_input_text;
        uart_input_request = 1'b0;
        uart_input_text = "";
        if (uart_input_enable &&
            uart_input_poll_cycles != 0 && cycle_count + 1 >= next_uart_input_poll_cycle) begin
          consume_text_file(uart_input_file, uart_input_request, uart_input_text);
          next_uart_input_poll_cycle <= next_uart_input_poll_cycle + uart_input_poll_cycles;
          if (uart_input_request && uart_input_text.len() != 0) begin
            fork
              uart_send_string(uart_input_text, "external");
            join_none
          end
        end
      end
      cycle_count <= cycle_count + 1;
      if (!heartbeat_speed_initialized) begin
        heartbeat_speed_prev_wall_s = current_wallclock_seconds();
        heartbeat_speed_prev_cycle <= cycle_count;
        heartbeat_speed_initialized <= 1'b1;
      end

      if (heartbeat_speed_initialized &&
          heartbeat_speed_interval_cycles != 0 &&
          cycle_count + 1 >= next_speed_report_cycle) begin
        heartbeat_speed_elapsed_wall_s = current_wallclock_seconds() - heartbeat_speed_prev_wall_s;
        if (heartbeat_speed_elapsed_wall_s > 0.0)
          heartbeat_cycles_per_s =
              ((cycle_count + 1) - heartbeat_speed_prev_cycle) /
              heartbeat_speed_elapsed_wall_s;
        else
          heartbeat_cycles_per_s = 0.0;
        heartbeat_speed_prev_wall_s = current_wallclock_seconds();
        heartbeat_speed_prev_cycle <= cycle_count + 1;
        next_speed_report_cycle <= next_speed_report_cycle + heartbeat_speed_interval_cycles;
      end

      if (cycle_count + 1 >= next_heartbeat_cycle) begin
        if (uart_log_enable) begin
          $fwrite(uart_file,
                  "[heartbeat] cycle=%0d pc=%016h valid=%0d hsel=%0d haddr=%016h hready=%0d hrdataext=%016h cycles/s=%0.3f MHz=%0.3f\n",
                  cycle_count + 1, PCM, InstrValidM, HSELEXT, HADDR, HREADYEXT, HRDATAEXT,
                  heartbeat_cycles_per_s, heartbeat_cycles_per_s / 1.0e6);
          $fflush(uart_file);
        end
        $display("[heartbeat] cycle=%0d pc=%016h valid=%0d hsel=%0d haddr=%016h hready=%0d hrdataext=%016h cycles/s=%0.3f MHz=%0.3f",
                 cycle_count + 1, PCM, InstrValidM, HSELEXT, HADDR, HREADYEXT, HRDATAEXT,
                 heartbeat_cycles_per_s, heartbeat_cycles_per_s / 1.0e6);
        next_heartbeat_cycle <= next_heartbeat_cycle + HEARTBEAT_CYCLES;
      end

      if (!kernel_entry_seen && InstrValidM && PCM == KERNEL_ENTRY_PC) begin
        $display("[milestone] reached kernel entry pc=%016h at cycle=%0d", PCM, cycle_count + 1);
        kernel_entry_seen <= 1'b1;
      end

      if (max_cycles != 0 && cycle_count >= max_cycles) begin
        $display("Reached MAX_CYCLES=%0d, stopping simulation.", max_cycles);
        $finish;
      end

      if (MAKE_VCD) begin
        if (trace_external_control &&
            trace_poll_cycles != 0 && cycle_count + 1 >= next_trace_poll_cycle) begin
          consume_trigger_file(trace_start_file, trace_start_request);
          consume_trigger_file(trace_stop_file, trace_stop_request);
          next_trace_poll_cycle <= next_trace_poll_cycle + trace_poll_cycles;
        end

        if (trace_started && !trace_stopped &&
            ((trace_stop_cycle_effective != 0 && cycle_count + 1 >= trace_stop_cycle_effective) ||
             (trace_external_control && trace_stop_request))) begin
          $dumpoff;
          $dumpflush;
          $display("[trace] stopped at cycle=%0d", cycle_count + 1);
          trace_started = 1'b0;
          trace_stopped = 1'b1;
          trace_stop_cycle_effective = 0;
        end

        if ((trace_external_control && trace_start_request && (!trace_started || trace_stopped)) ||
            (!trace_external_control && !trace_started && !trace_stopped &&
            ((trace_start_on_kernel_entry && InstrValidM && PCM == KERNEL_ENTRY_PC) ||
             (!trace_start_on_kernel_entry && trace_start_cycle != 0 && cycle_count >= trace_start_cycle)))) begin
          start_trace_capture(cycle_count + 1);
        end
      end
    end
  end

  // Mirror the internal UART character stream into a log file.  This keeps the
  // bridge-era debug flow intact while allowing lightweight scripted input.
  if (P.UART_SUPPORTED) begin : uart_logger
    string uart_char_str;
    string uart_prefix_str;
    string uart_wallclock_str;
    always @(posedge clk) begin
      byte uart_byte;
      bit emit_uart_prefix;
      bit finish_shell_line;
      uart_char_valid <= 1'b0;
      if (reset) begin
        uart_line_start <= 1'b1;
        uart_after_cr <= 1'b0;
        uart_shell_prefix = "";
        uart_shell_line = "";
      end else if (
          ~soc.uncoregen.uncore.uartgen.uart.MEMWb &&
          soc.uncoregen.uncore.uartgen.uart.uartPC.A == 3'b000 &&
          ~soc.uncoregen.uncore.uartgen.uart.uartPC.DLAB) begin
        uart_char_valid <= 1'b1;
        uart_byte = soc.uncoregen.uncore.uartgen.uart.uartPC.Din;
        uart_char_data  <= uart_byte;
        uart_char_str = $sformatf("%c", uart_byte);
        emit_uart_prefix = uart_timestamp && uart_line_start &&
                           !(uart_after_cr && uart_byte == 8'h0a);
        if (emit_uart_prefix) begin
          uart_wallclock_str = wallclock_datetime();
          uart_prefix_str = $sformatf("[%s] ", uart_wallclock_str);
          if (uart_log_enable)
            $fwrite(uart_file, "%s", uart_prefix_str);
          if (uart_shell_tags != 0)
            uart_shell_prefix = uart_prefix_str;
        end
        if (uart_log_enable) begin
          $fwrite(uart_file, "%s", uart_char_str);
          $fflush(uart_file);
        end
        if (uart_stdout != 0)
          $write("%s", uart_char_str);
        finish_shell_line = 1'b0;
        if (uart_byte == 8'h0d) begin
          finish_shell_line = 1'b1;
          uart_line_start <= 1'b1;
          uart_after_cr <= 1'b1;
        end else if (uart_byte == 8'h0a) begin
          finish_shell_line = !uart_after_cr;
          uart_line_start <= 1'b1;
          uart_after_cr <= 1'b0;
        end else begin
          if (uart_shell_tags != 0)
            uart_shell_line = {uart_shell_line, uart_char_str};
          uart_line_start <= 1'b0;
          uart_after_cr <= 1'b0;
        end
        if (uart_shell_tags != 0 && finish_shell_line) begin
          $display("%s%s", uart_shell_prefix, uart_shell_line);
          uart_shell_prefix = "";
          uart_shell_line = "";
        end

        if (uart_autorunmount || uart_autoruncmd) begin
          uart_recent = {uart_recent, uart_char_str};
          if (uart_recent.len() > 128)
            uart_recent = uart_recent.substr(uart_recent.len() - 128, uart_recent.len() - 1);

          if (!uart_login_sent && string_ends_with(uart_recent, " login: ")) begin
            uart_login_sent <= 1'b1;
            fork
              uart_send_string("root\r", "login");
            join_none
          end

          if (uart_autorunmount && !uart_mount_sent &&
              string_ends_with(uart_recent, "~ # ")) begin
            uart_mount_sent <= 1'b1;
            fork
              uart_send_string("mount -t proc proc /proc\r", "mount");
            join_none
          end

          if (uart_autorunmount && uart_login_sent && !uart_mount_sent &&
              string_ends_with(uart_recent, "root@cvwsoc-virt:~# ")) begin
            uart_mount_sent <= 1'b1;
            fork
              uart_send_string("mount -t proc proc /proc\r", "mount");
            join_none
          end

          if (uart_autoruncmd && uart_login_sent && !uart_runcmd_sent &&
              (string_ends_with(uart_recent, "root@cvwsoc-virt:~# ") ||
               string_ends_with(uart_recent, "~ # "))) begin
            bit uart_runcmd_request;
            string uart_runcmd_text;
            uart_runcmd_request = 1'b0;
            uart_runcmd_text = "";
            consume_text_file(uart_runcmd_file, uart_runcmd_request, uart_runcmd_text);
            if (uart_runcmd_request && uart_runcmd_text.len() != 0) begin
              uart_runcmd_sent <= 1'b1;
              fork
                uart_send_string(uart_runcmd_text, "runcmd");
              join_none
            end
          end
        end
      end
    end
  end


//------------------------------------------------------------------------
// Stuff for SDHCI and PLIC debugging. Will be removed later
//------------------------------------------------------------------------
`ifdef SIM_AXI_SDHCI
    logic        dbg_axi_dummyintr_sync_q;
    logic        dbg_axi_dummyintr_waiting_for_trap;
    logic [31:0] dbg_axi_dummyintr_wait_cycles;
    logic        dbg_axi_dummyintr_no_trap_sticky;

    always_ff @(posedge clk or posedge reset_ext) begin
        if (reset_ext) begin
            dbg_axi_dummyintr_sync_q         <= 1'b0;
            dbg_axi_dummyintr_waiting_for_trap <= 1'b0;
            dbg_axi_dummyintr_wait_cycles    <= 32'd0;
            dbg_axi_dummyintr_no_trap_sticky <= 1'b0;
        end else begin
            dbg_axi_dummyintr_sync_q <= AXI_DummyIntr;

            if (AXI_DummyIntr && !dbg_axi_dummyintr_sync_q) begin
                dbg_axi_dummyintr_waiting_for_trap <= 1'b1;
                dbg_axi_dummyintr_wait_cycles      <= 32'd0;
                dbg_axi_dummyintr_no_trap_sticky   <= 1'b0;
            end else if (!AXI_DummyIntr) begin
                dbg_axi_dummyintr_waiting_for_trap <= 1'b0;
                dbg_axi_dummyintr_wait_cycles      <= 32'd0;
            end else if (TrapM) begin
                dbg_axi_dummyintr_waiting_for_trap <= 1'b0;
                dbg_axi_dummyintr_wait_cycles      <= 32'd0;
            end else if (dbg_axi_dummyintr_waiting_for_trap) begin
                dbg_axi_dummyintr_wait_cycles <= dbg_axi_dummyintr_wait_cycles + 1;

                if ((dbg_axi_dummyintr_wait_cycles == 32'd100000) &&
                    !dbg_axi_dummyintr_no_trap_sticky) begin
                    dbg_axi_dummyintr_no_trap_sticky <= 1'b1;
                    $display("[irq-watch] t=%0t cycle=%0d AXI_DummyIntr high for 100000 clk cycles without TrapM raw=%0b sync=%0b pc=%h",
                            $time, cycle_count, AXI_DummyIntr_orig, AXI_DummyIntr, PCM);
                end
            end
        end
    end
`endif

endmodule


// -----------------------------------------------------------------------------
// Bound PLIC debug exporter.
// No plic_apb port-list changes.
// No instance hierarchy needed.
// Drives only top-level testbench wires, so they appear in your trace.
// -----------------------------------------------------------------------------

module plic_apb_dbg_bind import cvw::*; #(
  parameter cvw_t P
) (
  input  logic                              AXIDummyIntr,
  input  logic                              MExtInt,
  input  logic                              SExtInt,

  input  logic [P.PLIC_NUM_SRC:1]           requests,
  input  logic [P.PLIC_NUM_SRC:1]           intPending,
  input  logic [P.PLIC_NUM_SRC:1]           nextIntPending,
  input  logic [P.PLIC_NUM_SRC:1]           intInProgress,
  input  logic [P.PLIC_NUM_SRC:1][2:0]      intPriority,

  input  logic [1:0][P.PLIC_NUM_SRC:1]      intEn,
  input  logic [1:0][2:0]                   intThreshold,
  input  logic [1:0][5:0]                   intClaim,

  input  logic [1:0][7:1]                   priorities_with_irqs,
  input  logic [1:0][7:1]                   threshMask,
  input  logic [1:0][P.PLIC_NUM_SRC:1]      irqs_at_max_priority,

  input  logic                              memread,
  input  logic                              memwrite,
  input  logic [23:0]                       entry,
  input  logic [31:0]                       Din,
  input  logic [31:0]                       Dout,

  output logic [5:0]                        dbg_plic_axi_dummy_id,

  output logic                              dbg_plic_src_irq,
  output logic                              dbg_plic_req,
  output logic                              dbg_plic_pending,
  output logic                              dbg_plic_next_pending,
  output logic                              dbg_plic_in_progress,

  output logic [2:0]                        dbg_plic_priority,
  output logic                              dbg_plic_en_ctx0,
  output logic                              dbg_plic_en_ctx1,
  output logic [2:0]                        dbg_plic_threshold_ctx0,
  output logic [2:0]                        dbg_plic_threshold_ctx1,

  output logic [5:0]                        dbg_plic_claim_ctx0,
  output logic [5:0]                        dbg_plic_claim_ctx1,

  output logic [6:0]                        dbg_plic_priorities_with_irqs_ctx0,
  output logic [6:0]                        dbg_plic_priorities_with_irqs_ctx1,
  output logic [6:0]                        dbg_plic_threshmask_ctx0,
  output logic [6:0]                        dbg_plic_threshmask_ctx1,

  output logic                              dbg_plic_irq_at_max_ctx0,
  output logic                              dbg_plic_irq_at_max_ctx1,

  output logic                              dbg_plic_mextint,
  output logic                              dbg_plic_sextint,

  output logic                              dbg_plic_memread,
  output logic                              dbg_plic_memwrite,
  output logic [23:0]                       dbg_plic_entry,
  output logic [31:0]                       dbg_plic_din,
  output logic [31:0]                       dbg_plic_dout,

  output logic                              dbg_plic_claim0_read,
  output logic                              dbg_plic_claim1_read,
  output logic                              dbg_plic_claim0_write,
  output logic                              dbg_plic_claim1_write
);

  localparam int DBG_ID = P.PLIC_AXI_DUMMY_ID;

  assign dbg_plic_axi_dummy_id = DBG_ID[5:0];

  if ((DBG_ID >= 1) && (DBG_ID <= P.PLIC_NUM_SRC)) begin : valid_dbg_id
    assign dbg_plic_src_irq          = AXIDummyIntr;
    assign dbg_plic_req              = requests[DBG_ID];
    assign dbg_plic_pending          = intPending[DBG_ID];
    assign dbg_plic_next_pending     = nextIntPending[DBG_ID];
    assign dbg_plic_in_progress      = intInProgress[DBG_ID];

    assign dbg_plic_priority         = intPriority[DBG_ID];
    assign dbg_plic_en_ctx0          = intEn[0][DBG_ID];
    assign dbg_plic_en_ctx1          = intEn[1][DBG_ID];

    assign dbg_plic_irq_at_max_ctx0  = irqs_at_max_priority[0][DBG_ID];
    assign dbg_plic_irq_at_max_ctx1  = irqs_at_max_priority[1][DBG_ID];
  end else begin : invalid_dbg_id
    assign dbg_plic_src_irq          = 1'b0;
    assign dbg_plic_req              = 1'b0;
    assign dbg_plic_pending          = 1'b0;
    assign dbg_plic_next_pending     = 1'b0;
    assign dbg_plic_in_progress      = 1'b0;

    assign dbg_plic_priority         = 3'b0;
    assign dbg_plic_en_ctx0          = 1'b0;
    assign dbg_plic_en_ctx1          = 1'b0;

    assign dbg_plic_irq_at_max_ctx0  = 1'b0;
    assign dbg_plic_irq_at_max_ctx1  = 1'b0;
  end

  assign dbg_plic_threshold_ctx0           = intThreshold[0];
  assign dbg_plic_threshold_ctx1           = intThreshold[1];

  assign dbg_plic_claim_ctx0               = intClaim[0];
  assign dbg_plic_claim_ctx1               = intClaim[1];

  assign dbg_plic_priorities_with_irqs_ctx0 = priorities_with_irqs[0][7:1];
  assign dbg_plic_priorities_with_irqs_ctx1 = priorities_with_irqs[1][7:1];
  assign dbg_plic_threshmask_ctx0           = threshMask[0][7:1];
  assign dbg_plic_threshmask_ctx1           = threshMask[1][7:1];

  assign dbg_plic_mextint = MExtInt;
  assign dbg_plic_sextint = SExtInt;

  assign dbg_plic_memread  = memread;
  assign dbg_plic_memwrite = memwrite;
  assign dbg_plic_entry    = entry;
  assign dbg_plic_din      = Din;
  assign dbg_plic_dout     = Dout;

  assign dbg_plic_claim0_read  = memread  && (entry == 24'h200004);
  assign dbg_plic_claim1_read  = memread  && (entry == 24'h201004);
  assign dbg_plic_claim0_write = memwrite && (entry == 24'h200004);
  assign dbg_plic_claim1_write = memwrite && (entry == 24'h201004);

endmodule


bind plic_apb plic_apb_dbg_bind #(
  .P(P)
) i_plic_apb_dbg_bind (
  .AXIDummyIntr(AXIDummyIntr),
  .MExtInt(MExtInt),
  .SExtInt(SExtInt),

  .requests(requests),
  .intPending(intPending),
  .nextIntPending(nextIntPending),
  .intInProgress(intInProgress),
  .intPriority(intPriority),

  .intEn(intEn),
  .intThreshold(intThreshold),
  .intClaim(intClaim),

  .priorities_with_irqs(priorities_with_irqs),
  .threshMask(threshMask),
  .irqs_at_max_priority(irqs_at_max_priority),

  .memread(memread),
  .memwrite(memwrite),
  .entry(entry),
  .Din(Din),
  .Dout(Dout),

  .dbg_plic_axi_dummy_id($root.testbench_cvwsoc.dbg_plic_axi_dummy_id),

  .dbg_plic_src_irq($root.testbench_cvwsoc.dbg_plic_src_irq),
  .dbg_plic_req($root.testbench_cvwsoc.dbg_plic_req),
  .dbg_plic_pending($root.testbench_cvwsoc.dbg_plic_pending),
  .dbg_plic_next_pending($root.testbench_cvwsoc.dbg_plic_next_pending),
  .dbg_plic_in_progress($root.testbench_cvwsoc.dbg_plic_in_progress),

  .dbg_plic_priority($root.testbench_cvwsoc.dbg_plic_priority),
  .dbg_plic_en_ctx0($root.testbench_cvwsoc.dbg_plic_en_ctx0),
  .dbg_plic_en_ctx1($root.testbench_cvwsoc.dbg_plic_en_ctx1),
  .dbg_plic_threshold_ctx0($root.testbench_cvwsoc.dbg_plic_threshold_ctx0),
  .dbg_plic_threshold_ctx1($root.testbench_cvwsoc.dbg_plic_threshold_ctx1),

  .dbg_plic_claim_ctx0($root.testbench_cvwsoc.dbg_plic_claim_ctx0),
  .dbg_plic_claim_ctx1($root.testbench_cvwsoc.dbg_plic_claim_ctx1),

  .dbg_plic_priorities_with_irqs_ctx0($root.testbench_cvwsoc.dbg_plic_priorities_with_irqs_ctx0),
  .dbg_plic_priorities_with_irqs_ctx1($root.testbench_cvwsoc.dbg_plic_priorities_with_irqs_ctx1),
  .dbg_plic_threshmask_ctx0($root.testbench_cvwsoc.dbg_plic_threshmask_ctx0),
  .dbg_plic_threshmask_ctx1($root.testbench_cvwsoc.dbg_plic_threshmask_ctx1),

  .dbg_plic_irq_at_max_ctx0($root.testbench_cvwsoc.dbg_plic_irq_at_max_ctx0),
  .dbg_plic_irq_at_max_ctx1($root.testbench_cvwsoc.dbg_plic_irq_at_max_ctx1),

  .dbg_plic_mextint($root.testbench_cvwsoc.dbg_plic_mextint),
  .dbg_plic_sextint($root.testbench_cvwsoc.dbg_plic_sextint),

  .dbg_plic_memread($root.testbench_cvwsoc.dbg_plic_memread),
  .dbg_plic_memwrite($root.testbench_cvwsoc.dbg_plic_memwrite),
  .dbg_plic_entry($root.testbench_cvwsoc.dbg_plic_entry),
  .dbg_plic_din($root.testbench_cvwsoc.dbg_plic_din),
  .dbg_plic_dout($root.testbench_cvwsoc.dbg_plic_dout),

  .dbg_plic_claim0_read($root.testbench_cvwsoc.dbg_plic_claim0_read),
  .dbg_plic_claim1_read($root.testbench_cvwsoc.dbg_plic_claim1_read),
  .dbg_plic_claim0_write($root.testbench_cvwsoc.dbg_plic_claim0_write),
  .dbg_plic_claim1_write($root.testbench_cvwsoc.dbg_plic_claim1_write)
);
