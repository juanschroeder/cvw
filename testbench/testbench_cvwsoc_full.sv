`timescale 1ns/1ps
`include "config.vh"
`include "axi/typedef.svh"
import cvw::*;
import cvwsoc_pkg::*;

module testbench_cvwsoc_full #(
  parameter int unsigned CLK_PERIOD_NS = 10,
  parameter int unsigned BUS_CLK_PERIOD_NS = 10,
  parameter int unsigned RESET_CYCLES = 32,
  parameter int unsigned BUS_RESET_CYCLES = 64,
  parameter bit MAKE_VCD = 1'b0,
  parameter int unsigned EXT_MEM_ADDR_WIDTH = 30,
  parameter bit ENABLE_DMA = 1'b0,
  parameter bit ENABLE_I2S = 1'b0,
  parameter bit ENABLE_SDHCI = 1'b0,
  parameter bit ENABLE_WISHBONE = 1'b0
);
  `include "parameter-defs.vh"
  function automatic cvw_t sim_cfg(input cvw_t in);
    cvw_t c;

    c = in;
    c.XILINX_AXI_DMA_SUPPORTED = ENABLE_DMA;
    c.AXI_VGA_SUPPORTED = 1'b0;
    c.AXI_USB_SUPPORTED = 1'b0;
    c.AXI_ETH_SUPPORTED = 1'b0;
    c.AXI_SDHCI_SUPPORTED = ENABLE_SDHCI;
    c.AXI_IDMA_SUPPORTED = 1'b0;
    c.AXI_IDMA_REG64_SUPPORTED = 1'b0;
    c.AXIS_IDMA_SUPPORTED = 1'b0;
    c.AXIS_I2S_SUPPORTED = ENABLE_I2S;
    c.LITEDRAM_SUPPORTED = 1'b0;
    c.UBERDDR3_SUPPORTED = 1'b0;
    c.AXI_DUMMY_SUPPORTED = 1'b0;
    // Keep loading under runtime control, matching testbench_cvwsoc.
    c.BOOTROM_PRELOAD = 1'b0;
    c.UNCORE_RAM_PRELOAD = 1'b0;
    // boot.mem does not fit in the default FPGA boot-ROM allocation.
    c.BOOTROM_RANGE = 64'h1ffff;
    c.EXT_MEM_RANGE = (64'd1 << EXT_MEM_ADDR_WIDTH) - 1;
    c.WISHBONE_SUPPORTED = ENABLE_WISHBONE;
    if (ENABLE_WISHBONE) begin
        c.WISHBONE_STUB_SUPPORTED = 1'b1;
    end
    return c;
  endfunction
  localparam cvw_t SP = sim_cfg(P);
  localparam cvwsoc_cfg_t C = '{
    wally: SP,
    cpu:      SP.CPU_VEXRISCV_ENABLED ? CVWSOC_CPU_VEXRISCV :
              (SP.CPU_CVA6_ENABLED ? CVWSOC_CPU_CVA6 : CVWSOC_CPU_WALLY),
    bus: '{ AtopsEnabled: P.CPU_CVA6_ENABLED ? 1'b1 : 1'b0 }, 
    mem_type: CVWSOC_MEM_XILINX_DDR3,
    idma_config: '{AxisDescReqCut: 0},
    vga_config: '{CutSplitterPath: 0, BufferDepth: 32, MaxReadTxns: 4},
    sdhci_config: '{InsertRegClkBuf: 0}
  };
  localparam int ID_W = 2;
  localparam int NS = gen_xbar_out(SP).n_slv;
  localparam int MID_W = ID_W + ((NS > 1) ? $clog2(NS) : 0);
  localparam int unsigned BOOTROM_PRELOAD_START = SP.BOOTROM_BASE >> $clog2(SP.AHBW / 8);
  localparam int unsigned BOOTROM_WORDS = (SP.BOOTROM_RANGE + 1) / (SP.AHBW / 8);
  localparam int unsigned UNCORE_RAM_WORDS = (SP.UNCORE_RAM_RANGE + 1) / (SP.AHBW / 8);
  localparam longint unsigned HEARTBEAT_CYCLES = 10_000_000;
  localparam logic [SP.XLEN-1:0] KERNEL_ENTRY_PC =  64'h0000_0000_8020_0000;
  typedef logic [31:0] addr_t;
  typedef logic [SP.AHBW-1:0] data_t;
  typedef logic [SP.AHBW/8-1:0] strb_t;
  typedef logic user_t;
  typedef logic [ID_W-1:0] id_t;
  typedef logic [MID_W-1:0] mid_t;
  `AXI_TYPEDEF_ALL(cpu, addr_t, id_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_ALL(ddr, addr_t, mid_t, data_t, strb_t, user_t)
  typedef ddr_req_t island_axi_req_t;
  typedef ddr_resp_t island_axi_resp_t;
`ifdef VERILATOR
  import "DPI-C" function string getenvval(input string env_name);
  import "DPI-C" function string wallclock_datetime();
  string WALLY_DIR = getenvval("WALLY");
`else
  string WALLY_DIR = "$WALLY";
`endif
  localparam realtime HALF_PERIOD_NS = CLK_PERIOD_NS / 2.0;
  localparam realtime BUS_HALF_PERIOD_NS = BUS_CLK_PERIOD_NS / 2.0;
  logic clk = 1'b0;
  logic bus_clk = 1'b0;
  logic reset_ext = 1'b1;
  logic bus_reset = 1'b1;
  logic reset;
  logic rst_n;
  longint unsigned cycle_count=0, max_cycles=0;
  longint unsigned next_heartbeat_cycle = HEARTBEAT_CYCLES;
  longint unsigned heartbeat_speed_interval_cycles = HEARTBEAT_CYCLES;
  longint unsigned next_speed_report_cycle = HEARTBEAT_CYCLES;
  longint unsigned heartbeat_speed_previous_cycle = 0;
  bit heartbeat_speed_initialized = 1'b0;
  real heartbeat_speed_cycles_per_second = 0.0;
  real heartbeat_speed_previous_wall_seconds = 0.0;
  real heartbeat_elapsed_seconds = 0.0;
  string uart_log_path = "";
  integer uart_file;
  bit uart_log_enable = 1'b0;
  integer uart_stdout = 0;
  integer uart_shell_tags = 1;
  bit uart_timestamp = 1'b1;
  bit uart_line_start = 1'b1;
  bit uart_after_cr = 1'b0;
  string uart_shell_prefix = "";
  string uart_shell_line = "";
  bit kernel_entry_seen = 1'b0;
  bit trace_started=0, trace_stopped=0, trace_full_dump=0, trace_uart_dump=0;
  longint unsigned trace_start_cycle=0, trace_stop_cycle=0, trace_length_cycles=0;
  longint unsigned trace_stop_cycle_effective=0, trace_capture_index=0;
  string trace_file_prefix="dump", trace_file_name="";
  always #(HALF_PERIOD_NS) clk = ~clk;
  always #(BUS_HALF_PERIOD_NS) bus_clk = ~bus_clk;

  assign reset = reset_ext | bus_reset;
  assign rst_n = ~reset;

  initial begin
    void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
    void'($value$plusargs("HEARTBEAT_SPEED_INTERVAL_CYCLES=%d",
                         heartbeat_speed_interval_cycles));
    void'($value$plusargs("UART_LOG=%s", uart_log_path));
    void'($value$plusargs("UART_STDOUT=%d", uart_stdout));
    void'($value$plusargs("UART_TIMESTAMP=%d", uart_timestamp));
    void'($value$plusargs("UART_SHELL_TAGS=%d", uart_shell_tags));
    if (uart_log_path.len() != 0) begin
      uart_file = $fopen(uart_log_path, "w");
      if (uart_file == 0)
        $fatal(1, "Could not open UART log file %s", uart_log_path);
      uart_log_enable = 1'b1;
    end
    repeat (RESET_CYCLES) @(posedge clk);
    reset_ext = 1'b0;
  end

  initial begin
    repeat (BUS_RESET_CYCLES) @(posedge bus_clk);
    bus_reset = 1'b0;
  end
  `ifdef VERILATOR
    import "DPI-C" function real wallclock_seconds();
  `endif

  always_ff @(posedge clk) begin
    if (reset) begin
      cycle_count <= 0;
      next_heartbeat_cycle <= HEARTBEAT_CYCLES;
      next_speed_report_cycle <= heartbeat_speed_interval_cycles;
      heartbeat_speed_previous_cycle <= 0;
      heartbeat_speed_initialized <= 1'b0;
      kernel_entry_seen <= 1'b0;
      heartbeat_speed_cycles_per_second = 0.0;
      heartbeat_speed_previous_wall_seconds = 0.0;
    end else begin
      cycle_count <= cycle_count + 1;

      if (!heartbeat_speed_initialized) begin
        `ifdef VERILATOR
          heartbeat_speed_previous_wall_seconds = wallclock_seconds();
        `else
          heartbeat_speed_previous_wall_seconds = 0.0;
        `endif
        heartbeat_speed_previous_cycle <= cycle_count;
        heartbeat_speed_initialized <= 1'b1;
      end

      if (heartbeat_speed_initialized &&
          heartbeat_speed_interval_cycles != 0 &&
        cycle_count + 1 >= next_speed_report_cycle) begin
        `ifdef VERILATOR
          heartbeat_elapsed_seconds =
              wallclock_seconds() - heartbeat_speed_previous_wall_seconds;
          if (heartbeat_elapsed_seconds > 0.0)
            heartbeat_speed_cycles_per_second =
                ((cycle_count + 1) - heartbeat_speed_previous_cycle) /
                heartbeat_elapsed_seconds;
          else
            heartbeat_speed_cycles_per_second = 0.0;
          heartbeat_speed_previous_wall_seconds = wallclock_seconds();
        `endif
        heartbeat_speed_previous_cycle <= cycle_count + 1;
        next_speed_report_cycle <=
            next_speed_report_cycle + heartbeat_speed_interval_cycles;
      end

      if (cycle_count + 1 >= next_heartbeat_cycle) begin
        $display("[heartbeat] cycle=%0d pc=%016h valid=%0d haddr=%016h hready=%0d hrdataext=%016h cycles/s=%0.3f MHz=%0.3f",
                 cycle_count + 1, PCM, InstrValidM, dbg_cpu_haddr,
                 dbg_cpu_hready, dbg_cpu_hrdata,
                 heartbeat_speed_cycles_per_second,
                 heartbeat_speed_cycles_per_second / 1.0e6);
        if (uart_log_enable) begin
          $fwrite(uart_file,
                  "[heartbeat] cycle=%0d pc=%016h valid=%0d haddr=%016h hready=%0d hrdataext=%016h cycles/s=%0.3f MHz=%0.3f\n",
                  cycle_count + 1, PCM, InstrValidM, dbg_cpu_haddr,
                  dbg_cpu_hready, dbg_cpu_hrdata,
                  heartbeat_speed_cycles_per_second,
                  heartbeat_speed_cycles_per_second / 1.0e6);
          $fflush(uart_file);
        end
        next_heartbeat_cycle <= next_heartbeat_cycle + HEARTBEAT_CYCLES;
      end

      if (!kernel_entry_seen && InstrValidM && PCM == KERNEL_ENTRY_PC) begin
        $display("[milestone] reached kernel entry pc=%016h at cycle=%0d",
                 PCM, cycle_count + 1);
        if (uart_log_enable)
          $fwrite(uart_file,
                  "[milestone] reached kernel entry pc=%016h at cycle=%0d\n",
                  PCM, cycle_count + 1);
        kernel_entry_seen <= 1'b1;
      end

      if (max_cycles != 0 && cycle_count + 1 >= max_cycles) begin
        $display("Reached MAX_CYCLES=%0d, stopping simulation.", max_cycles);
        $finish;
      end
    end
  end

  task automatic start_trace_capture(input longint unsigned start_cycle);
    begin
      trace_capture_index = trace_capture_index + 1;
      trace_file_name = $sformatf("%s_capture_%0d_cycle_%0d.fst",
                                  trace_file_prefix, trace_capture_index, start_cycle);
      $dumpfile(trace_file_name);
      if (trace_full_dump) begin
        // Explicit opt-in: this includes the full hierarchy and can be huge.
        $dumpvars(0, testbench_cvwsoc_full);
      end else begin
        // Depth one preserves the old SIGUSR1-focused contract: all useful
        // top-level aliases, without recursively tracing the 1 GiB AXI RAM.
        $dumpvars(1, testbench_cvwsoc_full);
        $dumpvars(0, testbench_cvwsoc_full.cpu.wally.core.ieu.dp.regf);
      end
      $dumpflush;
      trace_started = 1'b1;
      trace_stopped = 1'b0;
      trace_stop_cycle_effective = (trace_length_cycles != 0) ?
                                   start_cycle + trace_length_cycles : trace_stop_cycle;
      $display("[trace] started file=%0s cycle=%0d mode=%0s stop_cycle=%0d",
               trace_file_name, start_cycle,
               trace_full_dump ? "full" : "focused", trace_stop_cycle_effective);
    end
  endtask

  initial begin
    void'($value$plusargs("TRACE_START_CYCLE=%d", trace_start_cycle));
    void'($value$plusargs("TRACE_STOP_CYCLE=%d", trace_stop_cycle));
    void'($value$plusargs("TRACE_LENGTH_CYCLES=%d", trace_length_cycles));
    void'($value$plusargs("TRACE_FILE_PREFIX=%s", trace_file_prefix));
    void'($value$plusargs("TRACE_FULL=%d", trace_full_dump));
    void'($value$plusargs("TRACE_UART=%d", trace_uart_dump));
    if (MAKE_VCD && trace_start_cycle == 0)
      start_trace_capture(0);
  end

  always @(posedge clk) begin
    if (MAKE_VCD && rst_n) begin
      if (trace_started && !trace_stopped &&
          trace_stop_cycle_effective != 0 && cycle_count + 1 >= trace_stop_cycle_effective) begin
        $dumpoff;
        $dumpflush;
        $display("[trace] stopped at cycle=%0d", cycle_count + 1);
        trace_started = 1'b0;
        trace_stopped = 1'b1;
      end
      if (!trace_started && !trace_stopped && trace_start_cycle != 0 &&
          cycle_count >= trace_start_cycle)
        start_trace_capture(cycle_count + 1);
    end
  end
  cpu_req_t cpu_req;
  cpu_resp_t cpu_resp;
  ddr_req_t ddr_req;
  ddr_req_t csr_req;
  ddr_resp_t ddr_resp;
  ddr_resp_t csr_resp;
  logic meip, seip;
  logic ahb_meip, ahb_seip;
  logic [3:0] irqs;
  island_axi_req_t ahb_req, wb_req;
  island_axi_resp_t ahb_resp, wb_resp;
  logic wb_uart_irq, wb_eth_irq;
  logic [31:0] GPIOOUT, GPIOEN;
  logic SPIOut;
  logic [3:0] SPICS;
  logic SPICLK;
  logic SDCCmd;
  logic [3:0] SDCCS;
  logic SDCCLK;
  logic WB_UART_TX;
  logic [1:0] WB_RMII_TX_DATA;
  logic WB_RMII_TX_EN, WB_RMII_MDC, WB_RMII_RST_N;
  logic UARTSin /*verilator public_flat_rw*/ = 1'b1;
  logic UARTSout /*verilator public_flat_rw*/;
  logic uart_char_valid /*verilator public_flat_rw*/;
  logic [7:0] uart_char_data /*verilator public_flat_rw*/;
  wire mdio;
  wire usb0dp;
  wire usb0dm;
  wire usb1dp;
  wire usb1dm;
  wire sdcmd;
  wire [3:0] sddat;

  // Focused trace aliases.  Runtime SIGUSR1 tracing records testbench scope
  // (depth 1), so keep the useful CPU and AHB-island state at this level.
  logic [SP.XLEN-1:0] PCM;
  logic InstrValidM, TrapM, StallM, FlushM;
  logic [31:0] InstrM;
  // IFU/cache observation: distinguishes a bad AXI refill from corruption
  // introduced while selecting, spilling, or decoding a cached instruction.
  logic [SP.XLEN-1:0] dbg_pcf, dbg_pcd;
  logic [31:0] dbg_icache_instr_f, dbg_instr_raw_f, dbg_postspill_instr_raw_f;
  logic [31:0] dbg_instr_raw_d, dbg_instr_d;
  logic dbg_icache_miss_f, dbg_icache_stall_f, dbg_cacheable_f;
  logic dbg_load_misaligned_fault_m, dbg_load_access_fault_m, dbg_load_page_fault_m;
  logic dbg_store_amo_misaligned_fault_m, dbg_store_amo_access_fault_m, dbg_store_amo_page_fault_m;
  logic dbg_instr_misaligned_fault_m, dbg_instr_access_fault_m, dbg_instr_page_fault_m;
  logic [3:0] dbg_trap_cause_m;
  logic dbg_trap_exception_m, dbg_trap_interrupt_m;
  logic [SP.XLEN-1:0] dbg_trap_epc_m, dbg_trap_vector_m, dbg_trap_tval_src_m;
  logic [SP.XLEN-1:0] dbg_gpr_ra, dbg_gpr_sp, dbg_gpr_s1, dbg_gpr_a0, dbg_gpr_a1, dbg_gpr_a2;
  logic [SP.XLEN-1:0] dbg_gpr_s2, dbg_gpr_s3, dbg_gpr_s4, dbg_gpr_result_w;
  logic dbg_gpr_regwrite_w;
  logic [4:0] dbg_gpr_rd_w;

  // CPU AHB, immediately before the AHB-to-AXI bridge.
  logic [SP.PA_BITS-1:0] dbg_cpu_haddr;
  logic [SP.AHBW-1:0] dbg_cpu_hwdata, dbg_cpu_hrdata;
  logic [SP.AHBW/8-1:0] dbg_cpu_hwstrb;
  logic dbg_cpu_hwrite, dbg_cpu_hmastlock, dbg_cpu_hready, dbg_cpu_hresp;
  logic [2:0] dbg_cpu_hsize, dbg_cpu_hburst;
  logic [3:0] dbg_cpu_hprot;
  logic [1:0] dbg_cpu_htrans;

  // AXI crossing the cvwsoc_cpu boundary (towards cvwsoc_axi).
  logic [ID_W-1:0] dbg_cpu_axi_awid, dbg_cpu_axi_arid, dbg_cpu_axi_bid, dbg_cpu_axi_rid;
  logic [31:0] dbg_cpu_axi_awaddr, dbg_cpu_axi_araddr;
  logic [7:0] dbg_cpu_axi_awlen, dbg_cpu_axi_arlen;
  logic [2:0] dbg_cpu_axi_awsize, dbg_cpu_axi_arsize;
  logic [1:0] dbg_cpu_axi_awburst, dbg_cpu_axi_arburst, dbg_cpu_axi_bresp, dbg_cpu_axi_rresp;
  logic dbg_cpu_axi_awlock, dbg_cpu_axi_awvalid, dbg_cpu_axi_awready;
  logic [SP.AHBW-1:0] dbg_cpu_axi_wdata, dbg_cpu_axi_rdata;
  logic [SP.AHBW/8-1:0] dbg_cpu_axi_wstrb;
  logic dbg_cpu_axi_wlast, dbg_cpu_axi_wvalid, dbg_cpu_axi_wready;
  logic dbg_cpu_axi_bvalid, dbg_cpu_axi_bready, dbg_cpu_axi_arlock, dbg_cpu_axi_arvalid, dbg_cpu_axi_arready;
  logic dbg_cpu_axi_rlast, dbg_cpu_axi_rvalid, dbg_cpu_axi_rready;
  logic [3:0] dbg_cpu_axi_awcache, dbg_cpu_axi_arcache, dbg_cpu_axi_awqos, dbg_cpu_axi_arqos;
  logic [2:0] dbg_cpu_axi_awprot, dbg_cpu_axi_arprot;

  // DDR-side AXI observation.  This is kept separate from the normal focused
  // set because it diagnoses root-crossbar delivery, not LiteDRAM itself.
  logic [MID_W-1:0] dbg_ddr_axi_arid, dbg_ddr_axi_rid;
  logic [31:0] dbg_ddr_axi_araddr;
  logic [7:0] dbg_ddr_axi_arlen;
  logic [2:0] dbg_ddr_axi_arsize;
  logic [1:0] dbg_ddr_axi_arburst, dbg_ddr_axi_rresp;
  logic dbg_ddr_axi_arvalid, dbg_ddr_axi_arready, dbg_ddr_axi_rvalid, dbg_ddr_axi_rready, dbg_ddr_axi_rlast;
  logic [SP.AHBW-1:0] dbg_ddr_axi_rdata;

  // AHB peripheral island (the former dbg_uncore_* observation point).
  logic [7:0] dbg_uncore_hselregions, dbg_uncore_hselregions_d;
  logic dbg_uncore_hsel_ram, dbg_uncore_hsel_ram_d;
  logic [SP.PA_BITS-1:0] dbg_uncore_haddr;
  logic [SP.AHBW-1:0] dbg_uncore_hwdata, dbg_uncore_hrdata, dbg_uncore_hread_ram;
  logic [SP.AHBW/8-1:0] dbg_uncore_hwstrb;
  logic dbg_uncore_hwrite, dbg_uncore_hready, dbg_uncore_hresp;
  logic [2:0] dbg_uncore_hsize, dbg_uncore_hburst;
  logic [3:0] dbg_uncore_hprot;
  logic [1:0] dbg_uncore_htrans;
  logic dbg_uncore_hresp_ram, dbg_uncore_hready_ram;

  // Temporary bridge-analyzer names.  Keep these at testbench scope so the
  // analyzer sees the same names as in the legacy testbench.
  //ID_W
  logic HSELEXT;
  logic [SP.PA_BITS-1:0] HADDR;
  logic [SP.AHBW-1:0] HWDATA, HRDATAEXT;
  logic [SP.AHBW/8-1:0] HWSTRB;
  logic HWRITE, HREADY, HREADYEXT, HRESPEXT;
  logic [2:0] HSIZE, HBURST;
  logic [1:0] HTRANS;
  //logic [AXI_ID_W-1:0] m_axi_awid, m_axi_bid, m_axi_arid, m_axi_rid;
  logic [ID_W-1:0] m_axi_awid, m_axi_bid, m_axi_arid, m_axi_rid;
  logic [31:0] m_axi_awaddr, m_axi_araddr;
  logic [7:0] m_axi_awlen, m_axi_arlen;
  logic [2:0] m_axi_awsize, m_axi_arsize;
  logic [1:0] m_axi_awburst, m_axi_arburst, m_axi_bresp, m_axi_rresp;
  logic m_axi_awvalid, m_axi_awready, m_axi_wlast, m_axi_wvalid, m_axi_wready;
  logic m_axi_bvalid, m_axi_bready, m_axi_arvalid, m_axi_arready;
  logic m_axi_rlast, m_axi_rvalid, m_axi_rready;
  logic [SP.AHBW-1:0] m_axi_wdata, m_axi_rdata;
  logic [SP.AHBW/8-1:0] m_axi_wstrb;

  cvwsoc_cpu #(
    //.P(SP),
    .C(C),
    .AXI_ID_W(ID_W),
    .cpu_axi_req_t(cpu_req_t),
    .cpu_axi_resp_t(cpu_resp_t)
  ) cpu (
    .clk_i(clk),
    .rst_ni(rst_n),
    .time_clk_i(clk),
    .meip_i(meip),
    .seip_i(seip),
    .external_stall_i(1'b0),
    .axi_req_o(cpu_req),
    .axi_resp_i(cpu_resp));

  cvwsoc_axi #(
    .C(C),
    .CPU_AXI_ID_WIDTH(ID_W),
    .cpu_axi_req_t(cpu_req_t),
    .cpu_axi_resp_t(cpu_resp_t),
    .ddr_axi_req_t(ddr_req_t),
    .ddr_axi_resp_t(ddr_resp_t),
    .ddr_csr_axi_req_t(ddr_req_t),
    .ddr_csr_axi_resp_t(ddr_resp_t),
    .ahb_axi_req_t(island_axi_req_t),
    .ahb_axi_resp_t(island_axi_resp_t),
    .wishbone_axi_req_t(island_axi_req_t),
    .wishbone_axi_resp_t(island_axi_resp_t)
  ) fabric (
    .CPUCLK_i(clk),
    .clk167_i(bus_clk),
    .clk200_i(bus_clk),
    .clk48MHz_raw_i(bus_clk),
    .audio_clk_i(bus_clk),
    .cpu_clk_locked_i(1'b1),
    .peripheral_reset_i(reset_ext),
    .peripheral_aresetn_i(~reset_ext),
    .rst_req_i(reset_ext),
    .resetn_comb_i(~reset_ext),
    .rgmii_clocks_rx(1'b0),
    .rgmii_clocks_tx(),
    .rgmii_int_n(1'b1),
    .rgmii_mdc(),
    .rgmii_mdio(mdio),
    .rgmii_rst_n(),
    .rgmii_rx_ctl(1'b0),
    .rgmii_rx_data('0),
    .rgmii_tx_ctl(),
    .rgmii_tx_data(),
    .vga_hsync(),
    .vga_vsync(),
    .vga_r_5(),
    .vga_g_6(),
    .vga_b_5(),
    .usb0_dp(usb0dp),
    .usb0_dm(usb0dm),
    .usb1_dp(usb1dp),
    .usb1_dm(usb1dm),
    .SD_CLK(),
    .SD_CD_N(1'b1),
    .SD_CMD(sdcmd),
    .SD_DAT(sddat),
    .i2s_tx_mclk(),
    .i2s_tx_lrck(),
    .i2s_tx_sclk(),
    .i2s_tx_sdout(),
    .cpu_axi_req_i(cpu_req),
    .cpu_axi_resp_o(cpu_resp),
    .ddr_axi_req_o(ddr_req),
    .ddr_axi_resp_i(ddr_resp),
    .ddr_csr_axi_req_o(csr_req),
    .ddr_csr_axi_resp_i(csr_resp),
    .ahb_axi_req_o(ahb_req),
    .ahb_axi_resp_i(ahb_resp),
    .wishbone_axi_req_o(wb_req),
    .wishbone_axi_resp_i(wb_resp),
    .BUSCLK_i(bus_clk),
    .BUSCORERSTn_i(~bus_reset),
    .BUSRSTn_i(~bus_reset),
    .cpu_axi_irq_o(irqs));

  cvwsoc_ahb #(
    .P(SP),
    .AXI_ID_W(MID_W),
    .axi_req_t(island_axi_req_t),
    .axi_resp_t(island_axi_resp_t)
  ) ahb_island (
    .clk_i(bus_clk),
    .rst_ni(~bus_reset),
    .axi_req_i(ahb_req),
    .axi_resp_o(ahb_resp),
    .MExtInt(ahb_meip),
    .SExtInt(ahb_seip),
    .GPIOIN('0),
    .GPIOOUT,
    .GPIOEN,
    .UARTSin,
    .UARTSout,
    .SPIIn(1'b0),
    .SPIOut,
    .SPICS,
    .SPICLK,
    .SDCIn(1'b0),
    .SDCCmd,
    .SDCCS,
    .SDCCLK,
    .WBUartIntr(wb_uart_irq),
    .WBEthIntr(wb_eth_irq),
    .AXI_DMAIntr(irqs[0]),
    .AXI_USBIntr(irqs[1]),
    .AXI_EthIntr(irqs[2]),
    .AXI_DummyIntr(1'b0),
    .AXI_SDHCIIntr(irqs[3])
  );

  assign meip = ahb_meip;
  assign seip = ahb_seip;

  generate
    if (ENABLE_WISHBONE) begin : gen_wishbone
      cvwsoc_wishbone #(
        .P(SP),
        .AXI_ID_W(MID_W),
        .axi_req_t(island_axi_req_t),
        .axi_resp_t(island_axi_resp_t)
      ) wishbone_island (
        .clk_i(bus_clk),
        .rst_ni(~bus_reset),
        .axi_req_i(wb_req),
        .axi_resp_o(wb_resp),
        .uart_rx_i(1'b1),
        .uart_tx_o(WB_UART_TX),
        .uart_irq_o(wb_uart_irq),
        .rmii_ref_clk_i(1'b0),
        .rmii_crs_dv_i(1'b0),
        .rmii_rx_data_i('0),
        .rmii_tx_data_o(WB_RMII_TX_DATA),
        .rmii_tx_en_o(WB_RMII_TX_EN),
        .rmii_mdc_o(WB_RMII_MDC),
        .rmii_mdio_io(),
        .rmii_rst_n_o(WB_RMII_RST_N),
        .eth_irq_o(wb_eth_irq)
      );
    end else begin : gen_no_wishbone
      assign wb_resp = '0;
      assign wb_uart_irq = 1'b0;
      assign wb_eth_irq = 1'b0;
      assign WB_UART_TX = 1'b0;
      assign WB_RMII_TX_DATA = '0;
      assign WB_RMII_TX_EN = 1'b0;
      assign WB_RMII_MDC = 1'b0;
      assign WB_RMII_RST_N = 1'b0;
    end
  endgenerate

  // Bridge-trace aliases must observe the bridge pins, not the legacy
  // always-selected external-AHB convention.  In this wrapper the bridge
  // deliberately rejects speculative/unmapped CPU addresses with hsel_axi.
  assign HSELEXT = cpu.HSELEXT;
  assign HADDR = cpu.HADDR;
  assign HWDATA = cpu.HWDATA;
  assign HWSTRB = cpu.HWSTRB;
  assign HWRITE = cpu.HWRITE;
  assign HSIZE = cpu.HSIZE;
  assign HBURST = cpu.HBURST;
  assign HTRANS = cpu.HTRANS;
  assign HREADY = cpu.HREADY;
  assign HRDATAEXT = cpu.HRDATAEXT;
  assign HREADYEXT = cpu.HREADYEXT;
  assign HRESPEXT = cpu.HRESPEXT;
  assign m_axi_awid = cpu.m_axi_awid;
  assign m_axi_awaddr = cpu.m_axi_awaddr;
  assign m_axi_awlen = cpu.m_axi_awlen;
  assign m_axi_awsize = cpu.m_axi_awsize;
  assign m_axi_awburst = cpu.m_axi_awburst;
  assign m_axi_awvalid = cpu.m_axi_awvalid;
  assign m_axi_awready = cpu.m_axi_awready;
  assign m_axi_wdata = cpu.m_axi_wdata;
  assign m_axi_wstrb = cpu.m_axi_wstrb;
  assign m_axi_wlast = cpu.m_axi_wlast;
  assign m_axi_wvalid = cpu.m_axi_wvalid;
  assign m_axi_wready = cpu.m_axi_wready;
  assign m_axi_bid = cpu.m_axi_bid;
  assign m_axi_bresp = cpu.m_axi_bresp;
  assign m_axi_bvalid = cpu.m_axi_bvalid;
  assign m_axi_bready = cpu.m_axi_bready;
  assign m_axi_arid = cpu.m_axi_arid;
  assign m_axi_araddr = cpu.m_axi_araddr;
  assign m_axi_arlen = cpu.m_axi_arlen;
  assign m_axi_arsize = cpu.m_axi_arsize;
  assign m_axi_arburst = cpu.m_axi_arburst;
  assign m_axi_arvalid = cpu.m_axi_arvalid;
  assign m_axi_arready = cpu.m_axi_arready;
  assign m_axi_rid = cpu.m_axi_rid;
  assign m_axi_rdata = cpu.m_axi_rdata;
  assign m_axi_rresp = cpu.m_axi_rresp;
  assign m_axi_rlast = cpu.m_axi_rlast;
  assign m_axi_rvalid = cpu.m_axi_rvalid;
  assign m_axi_rready = cpu.m_axi_rready;

  assign PCM = cpu.PCM;
  assign dbg_pcf = cpu.dbg_pcf;
  assign dbg_pcd = cpu.dbg_pcd;
  assign dbg_icache_instr_f = cpu.dbg_icache_instr_f;
  assign dbg_instr_raw_f = cpu.dbg_instr_raw_f;
  assign dbg_postspill_instr_raw_f = cpu.dbg_postspill_instr_raw_f;
  assign dbg_instr_raw_d = cpu.dbg_instr_raw_d;
  assign dbg_instr_d = cpu.dbg_instr_d;
  assign dbg_icache_miss_f = cpu.dbg_icache_miss_f;
  assign dbg_icache_stall_f = cpu.dbg_icache_stall_f;
  assign dbg_cacheable_f = cpu.dbg_cacheable_f;
  assign InstrValidM = cpu.InstrValidM;
  assign InstrM = cpu.InstrM;
  assign TrapM = cpu.TrapM;
  assign StallM = cpu.StallM;
  assign FlushM = cpu.FlushM;
  assign dbg_load_misaligned_fault_m = cpu.dbg_load_misaligned_fault_m;
  assign dbg_load_access_fault_m = cpu.dbg_load_access_fault_m;
  assign dbg_load_page_fault_m = cpu.dbg_load_page_fault_m;
  assign dbg_store_amo_misaligned_fault_m = cpu.dbg_store_amo_misaligned_fault_m;
  assign dbg_store_amo_access_fault_m = cpu.dbg_store_amo_access_fault_m;
  assign dbg_store_amo_page_fault_m = cpu.dbg_store_amo_page_fault_m;
  assign dbg_instr_misaligned_fault_m = cpu.dbg_instr_misaligned_fault_m;
  assign dbg_instr_access_fault_m = cpu.dbg_instr_access_fault_m;
  assign dbg_instr_page_fault_m = cpu.dbg_instr_page_fault_m;
  assign dbg_trap_cause_m = cpu.dbg_trap_cause_m;
  assign dbg_trap_exception_m = cpu.dbg_trap_exception_m;
  assign dbg_trap_interrupt_m = cpu.dbg_trap_interrupt_m;
  assign dbg_trap_epc_m = cpu.dbg_trap_epc_m;
  assign dbg_trap_vector_m = cpu.dbg_trap_vector_m;
  assign dbg_trap_tval_src_m = cpu.dbg_trap_tval_src_m;
  assign dbg_gpr_ra = cpu.dbg_gpr_ra;
  assign dbg_gpr_sp = cpu.dbg_gpr_sp;
  assign dbg_gpr_s1 = cpu.dbg_gpr_s1;
  assign dbg_gpr_a0 = cpu.dbg_gpr_a0;
  assign dbg_gpr_a1 = cpu.dbg_gpr_a1;
  assign dbg_gpr_a2 = cpu.dbg_gpr_a2;
  assign dbg_gpr_s2 = cpu.dbg_gpr_s2;
  assign dbg_gpr_s3 = cpu.dbg_gpr_s3;
  assign dbg_gpr_s4 = cpu.dbg_gpr_s4;
  assign dbg_gpr_regwrite_w = cpu.dbg_gpr_regwrite_w;
  assign dbg_gpr_rd_w = cpu.dbg_gpr_rd_w;
  assign dbg_gpr_result_w = cpu.dbg_gpr_result_w;

//   assign dbg_cpu_haddr = cpu.HADDR;
//   assign dbg_cpu_hwdata = cpu.HWDATA;
//   assign dbg_cpu_hwstrb = cpu.HWSTRB;
//   assign dbg_cpu_hwrite = cpu.HWRITE;
//   assign dbg_cpu_hsize = cpu.HSIZE;
//   assign dbg_cpu_hburst = cpu.HBURST;
//   assign dbg_cpu_hprot = cpu.HPROT;
//   assign dbg_cpu_htrans = cpu.HTRANS;
//   assign dbg_cpu_hmastlock = cpu.HMASTLOCK;
//   assign dbg_cpu_hrdata = cpu.HRDATA;
//   assign dbg_cpu_hready = cpu.HREADY;
//   assign dbg_cpu_hresp = cpu.HRESP;

  assign dbg_cpu_axi_awid = cpu_req.aw.id;
  assign dbg_cpu_axi_awaddr = cpu_req.aw.addr;
  assign dbg_cpu_axi_awlen = cpu_req.aw.len;
  assign dbg_cpu_axi_awsize = cpu_req.aw.size;
  assign dbg_cpu_axi_awburst = cpu_req.aw.burst;
  assign dbg_cpu_axi_awlock = cpu_req.aw.lock;
  assign dbg_cpu_axi_awcache = cpu_req.aw.cache;
  assign dbg_cpu_axi_awprot = cpu_req.aw.prot;
  assign dbg_cpu_axi_awqos = cpu_req.aw.qos;
  assign dbg_cpu_axi_awvalid = cpu_req.aw_valid;
  assign dbg_cpu_axi_awready = cpu_resp.aw_ready;
  assign dbg_cpu_axi_wdata = cpu_req.w.data;
  assign dbg_cpu_axi_wstrb = cpu_req.w.strb;
  assign dbg_cpu_axi_wlast = cpu_req.w.last;
  assign dbg_cpu_axi_wvalid = cpu_req.w_valid;
  assign dbg_cpu_axi_wready = cpu_resp.w_ready;
  assign dbg_cpu_axi_bid = cpu_resp.b.id;
  assign dbg_cpu_axi_bresp = cpu_resp.b.resp;
  assign dbg_cpu_axi_bvalid = cpu_resp.b_valid;
  assign dbg_cpu_axi_bready = cpu_req.b_ready;
  assign dbg_cpu_axi_arid = cpu_req.ar.id;
  assign dbg_cpu_axi_araddr = cpu_req.ar.addr;
  assign dbg_cpu_axi_arlen = cpu_req.ar.len;
  assign dbg_cpu_axi_arsize = cpu_req.ar.size;
  assign dbg_cpu_axi_arburst = cpu_req.ar.burst;
  assign dbg_cpu_axi_arlock = cpu_req.ar.lock;
  assign dbg_cpu_axi_arcache = cpu_req.ar.cache;
  assign dbg_cpu_axi_arprot = cpu_req.ar.prot;
  assign dbg_cpu_axi_arqos = cpu_req.ar.qos;
  assign dbg_cpu_axi_arvalid = cpu_req.ar_valid;
  assign dbg_cpu_axi_arready = cpu_resp.ar_ready;
  assign dbg_cpu_axi_rid = cpu_resp.r.id;
  assign dbg_cpu_axi_rdata = cpu_resp.r.data;
  assign dbg_cpu_axi_rresp = cpu_resp.r.resp;
  assign dbg_cpu_axi_rlast = cpu_resp.r.last;
  assign dbg_cpu_axi_rvalid = cpu_resp.r_valid;
  assign dbg_cpu_axi_rready = cpu_req.r_ready;

  assign dbg_ddr_axi_arid = ddr_req.ar.id;
  assign dbg_ddr_axi_araddr = ddr_req.ar.addr;
  assign dbg_ddr_axi_arlen = ddr_req.ar.len;
  assign dbg_ddr_axi_arsize = ddr_req.ar.size;
  assign dbg_ddr_axi_arburst = ddr_req.ar.burst;
  assign dbg_ddr_axi_arvalid = ddr_req.ar_valid;
  assign dbg_ddr_axi_arready = ddr_resp.ar_ready;
  assign dbg_ddr_axi_rid = ddr_resp.r.id;
  assign dbg_ddr_axi_rdata = ddr_resp.r.data;
  assign dbg_ddr_axi_rresp = ddr_resp.r.resp;
  assign dbg_ddr_axi_rlast = ddr_resp.r.last;
  assign dbg_ddr_axi_rvalid = ddr_resp.r_valid;
  assign dbg_ddr_axi_rready = ddr_req.r_ready;

  assign dbg_uncore_hselregions = ahb_island.system.hsel;
  assign dbg_uncore_hselregions_d = ahb_island.system.hsel_q;
  assign dbg_uncore_hsel_ram = dbg_uncore_hselregions[1];
  assign dbg_uncore_hsel_ram_d = dbg_uncore_hselregions_d[1];
  assign dbg_uncore_haddr = ahb_island.system.HADDR;
  assign dbg_uncore_hwdata = ahb_island.system.HWDATA;
  assign dbg_uncore_hwstrb = ahb_island.system.HWSTRB;
  assign dbg_uncore_hwrite = ahb_island.system.HWRITE;
  assign dbg_uncore_hsize = ahb_island.system.HSIZE;
  assign dbg_uncore_hburst = ahb_island.system.HBURST;
  assign dbg_uncore_hprot = ahb_island.system.HPROT;
  assign dbg_uncore_htrans = ahb_island.system.HTRANS;
  assign dbg_uncore_hready = ahb_island.system.HREADY;
  assign dbg_uncore_hresp = ahb_island.system.HRESP;
  assign dbg_uncore_hrdata = ahb_island.system.HRDATA;
  assign dbg_uncore_hread_ram = ahb_island.system.ram_rdata;
  assign dbg_uncore_hresp_ram = ahb_island.system.ram_resp;
  assign dbg_uncore_hready_ram = ahb_island.system.ram_ready;
  // Match the legacy testbench's 1 GiB external-memory model.  Generated
  // Linux images must not alias into a small behavioral RAM.
  axi_ram #(
    .DATA_WIDTH(SP.AHBW), .ADDR_WIDTH(EXT_MEM_ADDR_WIDTH), .STRB_WIDTH(SP.AHBW/8),
    .ID_WIDTH(MID_W), .PIPELINE_OUTPUT(0)
  ) axi_ram_i (
    .clk(bus_clk), .rst(bus_reset),
    .s_axi_awid(ddr_req.aw.id), .s_axi_awaddr(ddr_req.aw.addr[EXT_MEM_ADDR_WIDTH-1:0]),
    .s_axi_awlen(ddr_req.aw.len), .s_axi_awsize(ddr_req.aw.size),
    .s_axi_awburst(ddr_req.aw.burst), .s_axi_awlock(ddr_req.aw.lock),
    .s_axi_awcache(ddr_req.aw.cache), .s_axi_awprot(ddr_req.aw.prot),
    .s_axi_awvalid(ddr_req.aw_valid), .s_axi_awready(ddr_resp.aw_ready),
    .s_axi_wdata(ddr_req.w.data), .s_axi_wstrb(ddr_req.w.strb),
    .s_axi_wlast(ddr_req.w.last), .s_axi_wvalid(ddr_req.w_valid),
    .s_axi_wready(ddr_resp.w_ready), .s_axi_bid(ddr_resp.b.id),
    .s_axi_bresp(ddr_resp.b.resp), .s_axi_bvalid(ddr_resp.b_valid),
    .s_axi_bready(ddr_req.b_ready), .s_axi_arid(ddr_req.ar.id),
    .s_axi_araddr(ddr_req.ar.addr[EXT_MEM_ADDR_WIDTH-1:0]), .s_axi_arlen(ddr_req.ar.len),
    .s_axi_arsize(ddr_req.ar.size), .s_axi_arburst(ddr_req.ar.burst),
    .s_axi_arlock(ddr_req.ar.lock), .s_axi_arcache(ddr_req.ar.cache),
    .s_axi_arprot(ddr_req.ar.prot), .s_axi_arvalid(ddr_req.ar_valid),
    .s_axi_arready(ddr_resp.ar_ready), .s_axi_rid(ddr_resp.r.id),
    .s_axi_rdata(ddr_resp.r.data), .s_axi_rresp(ddr_resp.r.resp),
    .s_axi_rlast(ddr_resp.r.last), .s_axi_rvalid(ddr_resp.r_valid),
    .s_axi_rready(ddr_req.r_ready));
  assign ddr_resp.b.user='0;
  assign ddr_resp.r.user='0;
  assign csr_resp='0;

  // Runtime image loading follows the legacy testbench contract.  The only
  // hierarchy change is that ROM and on-chip RAM now sit in cvwsoc_ahb.
  string bootrom_bin, bootrom_memh, uncore_ram_memh, ext_ram_bin;
  bit uncore_ram_memh_given;
  integer file_handle, bytes_read;
  initial begin
    // axi_ram (and the retained AHB memories) clear their arrays in their own
    // time-zero initial blocks.  Do not race that initialization: the legacy
    // bench waits two clocks before loading images for exactly this reason.
    repeat (2) @(posedge bus_clk);
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

    if (bootrom_bin.len() != 0) begin
      file_handle = $fopen(bootrom_bin, "rb");
      if (file_handle == 0) $fatal(1, "Could not open boot ROM image %s", bootrom_bin);
      bytes_read = $fread(ahb_island.system.bootrom.romgen.bootrom.memory.ROM,
                          file_handle, BOOTROM_PRELOAD_START);
      $fclose(file_handle);
      $display("Loaded %0d bytes of boot ROM from %s", bytes_read, bootrom_bin);
    end else if (bootrom_memh.len() != 0) begin
      $readmemh(bootrom_memh,
                ahb_island.system.bootrom.romgen.bootrom.memory.ROM,
                BOOTROM_PRELOAD_START, BOOTROM_WORDS-1);
      $display("Loaded boot ROM hex from %s", bootrom_memh);
    end

    if (SP.UNCORE_RAM_SUPPORTED && uncore_ram_memh.len() != 0) begin
      $readmemh(uncore_ram_memh,
                ahb_island.system.ram.ramgen.ram.memory.ram.RAM,
                0, UNCORE_RAM_WORDS-1);
      $display("Loaded on-chip RAM hex from %s", uncore_ram_memh);
    end

    if (ext_ram_bin.len() != 0) begin
      file_handle = $fopen(ext_ram_bin, "rb");
      if (file_handle == 0) $fatal(1, "Could not open external RAM image %s", ext_ram_bin);
      bytes_read = $fread(axi_ram_i.mem, file_handle);
      $fclose(file_handle);
      $display("Loaded %0d bytes of external RAM from %s (mem[0]=%016h)",
               bytes_read, ext_ram_bin, axi_ram_i.mem[0]);
    end
  end

  // Mirror the internal UART character stream into a log file.  This is the
  // same handling used by testbench_cvwsoc; only the hierarchy prefix differs.
  if (SP.UART_SUPPORTED) begin : uart_logger
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
          ~ahb_island.system.apb.uartgen.uart.MEMWb &&
          ahb_island.system.apb.uartgen.uart.uartPC.A == 3'b000 &&
          ~ahb_island.system.apb.uartgen.uart.uartPC.DLAB) begin
        uart_char_valid <= 1'b1;
        uart_byte = ahb_island.system.apb.uartgen.uart.uartPC.Din;
        uart_char_data <= uart_byte;
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
      end
    end
  end
endmodule
