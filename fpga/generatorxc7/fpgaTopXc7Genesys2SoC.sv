///////////////////////////////////////////
// fpgaTopXc7Genesys2SoC.sv
//
// Minimal Genesys 2 SoC top for OpenXC7 experiments.
// Wally runs on the divided CPU clock. Its external AHB port reaches UberDDR3
// through the custom AHB-Lite-to-AXI4 bridge and a PULP AXI CDC into ddr_ui_clk.
///////////////////////////////////////////

`default_nettype none

`include "config.vh"
`include "axi/typedef.svh"

import cvw::*;

module fpgaTopXc7Genesys2SoC
  (input  logic         default_200mhz_clk_p,
   input  logic         default_200mhz_clk_n,
   input  logic         resetn,
   input  logic         south_reset,

   input  logic [3:0]   GPI,
   output logic [4:0]   GPO,
   output logic         LED5,
   output logic         LED6,
   output logic         LED7,

   input  logic         UARTSin,
   output logic         UARTSout,
   input  logic         debugIn,
   output logic         debugOut,

   input  logic         SDCIn,
   output logic         SDCCLK,
   output logic         SDCCmd,
   output logic         SDCCS,
   input  logic         SDCCD,
   input  logic         SDCWP,

   inout  wire [31:0]   ddr3_dq,
   inout  wire [3:0]    ddr3_dqs_n,
   inout  wire [3:0]    ddr3_dqs_p,
   output logic [14:0]  ddr3_addr,
   output logic [2:0]   ddr3_ba,
   output logic         ddr3_ras_n,
   output logic         ddr3_cas_n,
   output logic         ddr3_we_n,
   output logic         ddr3_reset_n,
   output logic [0:0]   ddr3_ck_p,
   output logic [0:0]   ddr3_ck_n,
   output logic [0:0]   ddr3_cke,
   output logic [0:0]   ddr3_cs_n,
   output logic [3:0]   ddr3_dm,
   output logic [0:0]   ddr3_odt);

  `include "parameter-defs.vh"

  logic clk200;
  logic CPUCLK;
  logic ddr_ui_clk;
  logic ref_clk200_open;
  logic ui_clk_sync_rst;
  logic ui_aresetn;
  logic pll_locked;
  logic init_calib_complete;
  logic [31:0] uber_debug1;

  IBUFDS clk200_ibufds (
    .I(default_200mhz_clk_p),
    .IB(default_200mhz_clk_n),
    .O(clk200)
  );

  logic rst_req;
  logic soc_reset_ext;
  logic wally_reset;
  logic ddr_ready_meta;
  logic ddr_ready_cpuclk;
  logic ddr_ready_raw;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic rst_req_cpuclk_meta;
  logic rst_req_cpuclk;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic soc_reset_ext_cpuclk_meta;
  logic soc_reset_ext_cpuclk;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic resetn_cpuclk_meta;
  logic resetn_cpuclk;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic south_reset_cpuclk_meta;
  logic south_reset_cpuclk;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic pll_locked_cpuclk_meta;
  logic pll_locked_cpuclk;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic init_calib_complete_cpuclk_meta;
  logic init_calib_complete_cpuclk;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic ui_aresetn_cpuclk_meta;
  logic ui_aresetn_cpuclk;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic ui_clk_sync_rst_cpuclk_meta;
  logic ui_clk_sync_rst_cpuclk;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic ddr_ready_raw_cpuclk_meta;
  logic ddr_ready_raw_cpuclk;
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic [31:0] uber_debug1_cpuclk_meta;
  logic [31:0] uber_debug1_cpuclk;
  logic [4:0]  uber_calib_state_cpuclk;

  assign rst_req       = ~resetn | south_reset;
  assign ddr_ready_raw = init_calib_complete & ui_aresetn & ~ui_clk_sync_rst;
  assign soc_reset_ext = rst_req | ~ddr_ready_cpuclk;

  logic [3:0] cpuclk_div;
  logic       cpuclk_slow;

//   always_ff @(posedge clk200 or posedge rst_req) begin
//     if (rst_req) cpuclk_div <= '0;
//     else         cpuclk_div <= cpuclk_div + 1'b1;
//   end

  always_ff @(posedge clk200) begin
    cpuclk_div <= cpuclk_div + 1'b1;
  end

  BUFG cpuclk_slow_bufg (
    .I(cpuclk_div[3]),
    .O(cpuclk_slow)
  );

  assign CPUCLK = cpuclk_slow;

  always_ff @(posedge CPUCLK or posedge rst_req) begin
    if (rst_req) begin
      ddr_ready_meta   <= 1'b0;
      ddr_ready_cpuclk <= 1'b0;
    end else begin
      ddr_ready_meta   <= ddr_ready_raw;
      ddr_ready_cpuclk <= ddr_ready_meta;
    end
  end

  always_ff @(posedge CPUCLK) begin
    rst_req_cpuclk_meta                 <= rst_req;
    rst_req_cpuclk                      <= rst_req_cpuclk_meta;
    soc_reset_ext_cpuclk_meta           <= soc_reset_ext;
    soc_reset_ext_cpuclk                <= soc_reset_ext_cpuclk_meta;
    resetn_cpuclk_meta                  <= resetn;
    resetn_cpuclk                       <= resetn_cpuclk_meta;
    south_reset_cpuclk_meta             <= south_reset;
    south_reset_cpuclk                  <= south_reset_cpuclk_meta;
    pll_locked_cpuclk_meta              <= pll_locked;
    pll_locked_cpuclk                   <= pll_locked_cpuclk_meta;
    init_calib_complete_cpuclk_meta     <= init_calib_complete;
    init_calib_complete_cpuclk          <= init_calib_complete_cpuclk_meta;
    ui_aresetn_cpuclk_meta              <= ui_aresetn;
    ui_aresetn_cpuclk                   <= ui_aresetn_cpuclk_meta;
    ui_clk_sync_rst_cpuclk_meta         <= ui_clk_sync_rst;
    ui_clk_sync_rst_cpuclk              <= ui_clk_sync_rst_cpuclk_meta;
    ddr_ready_raw_cpuclk_meta           <= ddr_ready_raw;
    ddr_ready_raw_cpuclk                <= ddr_ready_raw_cpuclk_meta;
    uber_debug1_cpuclk_meta             <= uber_debug1;
    uber_debug1_cpuclk                  <= uber_debug1_cpuclk_meta;
  end

  assign uber_calib_state_cpuclk = uber_debug1_cpuclk[4:0];

  logic [23:0] led_counter;

  always_ff @(posedge CPUCLK or posedge soc_reset_ext) begin
    if (soc_reset_ext) led_counter <= '0;
    else               led_counter <= led_counter + 1'b1;
  end

  assign LED5 = 1'b0;
  assign LED6 = init_calib_complete;
  assign LED7 = led_counter[23];

  logic [63:0] HRDATAEXT;
  logic        HREADYEXT;
  logic        HRESPEXT;
  logic        HSELEXT;
  logic        HCLKOpen;
  logic        HRESETnOpen;
  logic [P.PA_BITS-1:0] HADDR;
  logic [P.AHBW-1:0]    HWDATA;
  logic [P.XLEN/8-1:0]  HWSTRB;
  logic        HWRITE;
  logic [2:0]  HSIZE;
  logic [2:0]  HBURST;
  logic [3:0]  HPROT;
  logic [1:0]  HTRANS;
  logic        HMASTLOCK;
  logic        HREADY;

  logic [31:0] GPIOIN;
  logic [31:0] GPIOOUT;
  logic [31:0] GPIOEN;
  logic        SPIIn;
  logic        SPIOut;
  logic [3:0]  SPICS;
  logic        SPICLK;
  logic [3:0]  SDCCSin;

  assign GPIOIN = {25'b0, SDCCD, SDCWP, 1'b0, GPI};
  assign GPO    = GPIOOUT[4:0];
  assign SPIIn  = 1'b0;
  assign SDCCS  = SDCCSin[0];

  logic [1:0] WB_RMII_TX_DATA;
  logic       WB_RMII_TX_EN;
  logic       WB_RMII_MDC;
  logic       WB_RMII_RST_N;

    logic wally_uart_tx;
    logic manta_uart_tx;

    assign UARTSout = wally_uart_tx;
    assign debugOut = manta_uart_tx;

    logic [P.XLEN-1:0] dbg_pcf;
    logic [P.XLEN-1:0] dbg_pcm;
    logic [31:0]       dbg_instr_m;
    logic [31:0]       dbg_instr_raw_d;
    logic              dbg_instr_valid_m;
    logic              dbg_stall_m;
    logic              dbg_flush_m;
    logic              dbg_trap_m;
    logic [P.XLEN-1:0] dbg_mcycle;
    logic [P.XLEN-1:0] dbg_minstret;
    logic [P.XLEN-1:0] dbg_mcause;
    logic [P.XLEN-1:0] dbg_mepc;
    logic [P.XLEN-1:0] dbg_mtval;
    logic [P.XLEN-1:0] dbg_scause;
    logic [P.XLEN-1:0] dbg_sepc;
    logic [P.XLEN-1:0] dbg_stval;
    logic [P.XLEN-1:0] dbg_satp;
    logic [1:0]        dbg_priv_mode_w;
    logic              dbg_stall_f;
    logic              dbg_stall_d;
    logic              dbg_stall_e;
    logic              dbg_stall_w;
    logic              dbg_flush_d;
    logic              dbg_flush_e;
    logic              dbg_flush_w;
    logic              dbg_ifu_stall_f;
    logic              dbg_lsu_stall_m;
    logic              dbg_icache_stall_f;
    logic              dbg_dcache_stall_m;
    logic              dbg_wfi_m;
    logic              dbg_int_pending_m;
    logic              dbg_interrupt_m;
    logic              dbg_exception_m;
    logic              dbg_mtimer_int;
    logic              dbg_mext_int;
    logic              dbg_sext_int;
    logic              dbg_msw_int;
    logic [31:0]       dbg_gpr_a0_lo;
    logic [31:0]       dbg_gpr_a1_lo;
    logic [31:0]       dbg_gpr_a2_lo;
    logic [31:0]       dbg_gpr_a3_lo;
    logic [31:0]       dbg_gpr_a5_lo;

    assign dbg_pcf           = wallypipelinedsoc.core.ifu.PCF;
    assign dbg_pcm           = wallypipelinedsoc.core.ifu.PCM;
    assign dbg_instr_m       = wallypipelinedsoc.core.InstrM;
    assign dbg_instr_raw_d   = wallypipelinedsoc.core.ifu.InstrRawD;
    assign dbg_instr_valid_m = wallypipelinedsoc.core.ieu.InstrValidM;
    assign dbg_stall_f       = wallypipelinedsoc.core.StallF;
    assign dbg_stall_d       = wallypipelinedsoc.core.StallD;
    assign dbg_stall_e       = wallypipelinedsoc.core.StallE;
    assign dbg_stall_m       = wallypipelinedsoc.core.StallM;
    assign dbg_stall_w       = wallypipelinedsoc.core.StallW;
    assign dbg_flush_d       = wallypipelinedsoc.core.FlushD;
    assign dbg_flush_e       = wallypipelinedsoc.core.FlushE;
    assign dbg_flush_m       = wallypipelinedsoc.core.FlushM;
    assign dbg_flush_w       = wallypipelinedsoc.core.FlushW;
    assign dbg_trap_m        = wallypipelinedsoc.core.TrapM;
    assign dbg_ifu_stall_f   = wallypipelinedsoc.core.IFUStallF;
    assign dbg_lsu_stall_m   = wallypipelinedsoc.core.LSUStallM;
    assign dbg_icache_stall_f = wallypipelinedsoc.core.ICacheStallF;
    assign dbg_dcache_stall_m = wallypipelinedsoc.core.DCacheStallM;
    assign dbg_mcycle        = wallypipelinedsoc.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[0];
    assign dbg_minstret      = wallypipelinedsoc.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[2];
    assign dbg_mcause        = wallypipelinedsoc.core.priv.priv.csr.csrm.MCAUSE_REGW;
    assign dbg_mepc          = wallypipelinedsoc.core.priv.priv.csr.csrm.MEPC_REGW;
    assign dbg_mtval         = wallypipelinedsoc.core.priv.priv.csr.csrm.MTVAL_REGW;
    assign dbg_scause        = wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SCAUSE_REGW;
    assign dbg_sepc          = wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SEPC_REGW;
    assign dbg_stval         = wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STVAL_REGW;
    assign dbg_satp          = wallypipelinedsoc.core.priv.priv.csr.SATP_REGW;
    assign dbg_priv_mode_w   = wallypipelinedsoc.core.priv.priv.privmode.PrivilegeModeW;
    assign dbg_wfi_m         = wallypipelinedsoc.core.wfiM;
    assign dbg_int_pending_m = wallypipelinedsoc.core.IntPendingM;
    assign dbg_interrupt_m   = wallypipelinedsoc.core.priv.priv.InterruptM;
    assign dbg_exception_m   = wallypipelinedsoc.core.priv.priv.ExceptionM;
    assign dbg_mtimer_int    = wallypipelinedsoc.MTimerInt;
    assign dbg_mext_int      = wallypipelinedsoc.MExtInt;
    assign dbg_sext_int      = wallypipelinedsoc.SExtInt;
    assign dbg_msw_int       = wallypipelinedsoc.MSwInt;
    assign dbg_gpr_a0_lo     = wallypipelinedsoc.core.ieu.dp.regf.rf[10][31:0];
    assign dbg_gpr_a1_lo     = wallypipelinedsoc.core.ieu.dp.regf.rf[11][31:0];
    assign dbg_gpr_a2_lo     = wallypipelinedsoc.core.ieu.dp.regf.rf[12][31:0];
    assign dbg_gpr_a3_lo     = wallypipelinedsoc.core.ieu.dp.regf.rf[13][31:0];
    assign dbg_gpr_a5_lo     = wallypipelinedsoc.core.ieu.dp.regf.rf[15][31:0];

    logic [31:0] manta_status_word;
    logic [15:0] manta_ahb_ctrl;
    logic [15:0] manta_axi_ctrl;
    logic [31:0] dbg_uram_haddr;
    logic        dbg_uram_hsel;
    logic        dbg_uram_hseld;
    logic        dbg_uram_hreadyram;
    logic        dbg_uram_hrespram;
    logic [63:0] dbg_uram_hreadram;
    logic [31:0] dbg_uram_ramaddr;
    logic [12:0] dbg_uram_word_index;
    logic [2:0]  dbg_uram_byte_offset;
    logic        dbg_uram_read_req;
    logic        dbg_uram_read_req_d;
    logic        dbg_uram_banner_req;
    logic        dbg_uram_banner_req_d;
    logic        dbg_uram_banner_word_ok;
    logic        dbg_uram_banner_word_zero;

    assign manta_status_word = {
        10'b0,                  // [31:22]
        dbg_priv_mode_w,         // [21:20]
        dbg_minstret[0],         // [19]
        dbg_mcycle[0],           // [18]
        (dbg_pcf == P.RESET_VECTOR[P.XLEN-1:0]), // [17]
        dbg_pcf[12],             // [16]
        HWRITE,                  // [15]
        HTRANS[1],               // [14]
        HRESPEXT,                // [13]
        HREADYEXT,               // [12]
        HREADY,                  // [11]
        HSELEXT,                 // [10]
        dbg_instr_valid_m,       // [9]
        dbg_trap_m,              // [8]
        init_calib_complete,     // [7]
        pll_locked,              // [6]
        HRESETnOpen,             // [5]
        wally_reset,             // [4]
        soc_reset_ext,           // [3]
        rst_req,                 // [2]
        south_reset,             // [1]
        resetn                   // [0]
    };

    assign manta_ahb_ctrl = {
        2'b0,        // [15:14]
        HMASTLOCK,   // [13]
        HPROT[3:0],  // [12:9]
        HBURST[2:0], // [8:6]
        HSIZE[2:0],  // [5:3]
        HWRITE,      // [2]
        HTRANS[1:0]  // [1:0]
    };

    assign manta_axi_ctrl = {
        axi_bready, axi_bvalid,
        axi_wready, axi_wvalid,
        axi_awready, axi_awvalid,
        axi_rready, axi_rvalid, axi_rlast,
        axi_arready, axi_arvalid,
        5'b0
    };

    assign dbg_uram_haddr         = HADDR[31:0];
    assign dbg_uram_hsel          = wallypipelinedsoc.uncoregen.uncore.HSELRam;
    assign dbg_uram_hseld         = wallypipelinedsoc.uncoregen.uncore.HSELRamD;
    assign dbg_uram_hreadyram     = wallypipelinedsoc.uncoregen.uncore.HREADYRam;
    assign dbg_uram_hrespram      = wallypipelinedsoc.uncoregen.uncore.HRESPRam;
    assign dbg_uram_hreadram      = wallypipelinedsoc.uncoregen.uncore.HREADRam;
    assign dbg_uram_ramaddr       = wallypipelinedsoc.uncoregen.uncore.ram.ram.RamAddr[31:0];
    assign dbg_uram_word_index    = HADDR[15:3];
    assign dbg_uram_byte_offset   = HADDR[2:0];
    assign dbg_uram_read_req      = HREADY & dbg_uram_hsel & HTRANS[1] & ~HWRITE;
    assign dbg_uram_banner_req    = dbg_uram_read_req & (dbg_uram_haddr == 32'h0002_00d8);
    assign dbg_uram_banner_word_ok =
        dbg_uram_banner_req_d & (dbg_uram_hreadram == 64'he28096e28896e220);
    assign dbg_uram_banner_word_zero =
        dbg_uram_banner_req_d & (dbg_uram_hreadram == 64'b0);

    logic [31:0] uram_haddr;
    logic [31:0] uram_ramaddr;
    logic [12:0] uram_word_index;
    logic [2:0]  uram_byte_offset;
    logic        uram_hsel;
    logic        uram_hseld;
    logic        uram_hreadyram;
    logic        uram_hrespram;
    logic [63:0] uram_hreadram;
    logic        uram_read_req;
    logic        uram_banner_req;
    logic        uram_banner_word_ok;
    logic        uram_banner_word_zero;

    assign uram_haddr            = dbg_uram_haddr;
    assign uram_ramaddr          = dbg_uram_ramaddr;
    assign uram_word_index       = dbg_uram_word_index;
    assign uram_byte_offset      = dbg_uram_byte_offset;
    assign uram_hsel             = dbg_uram_hsel;
    assign uram_hseld            = dbg_uram_hseld;
    assign uram_hreadyram        = dbg_uram_hreadyram;
    assign uram_hrespram         = dbg_uram_hrespram;
    assign uram_hreadram         = dbg_uram_hreadram;
    assign uram_read_req         = dbg_uram_read_req;
    assign uram_banner_req       = dbg_uram_banner_req;
    assign uram_banner_word_ok   = dbg_uram_banner_word_ok;
    assign uram_banner_word_zero = dbg_uram_banner_word_zero;

    logic [7:0]  dbg_sdc_entry;
    logic        dbg_sdc_memwrite;
    logic [31:0] dbg_sdc_din;
    logic [31:0] dbg_sdc_dout;
    logic [4:0]  dbg_sdc_format;
    logic        dbg_sdc_format_dir;
    logic [3:0]  dbg_sdc_frame_length;
    logic [11:0] dbg_sdc_sckdiv;
    logic [1:0]  dbg_sdc_sckmode;
    logic [1:0]  dbg_sdc_cs_mode;
    logic [3:0]  dbg_sdc_cs_def;
    logic [1:0]  dbg_sdc_interrupt_pending;
    logic [8:0]  dbg_sdc_tx_data;
    logic [7:0]  dbg_sdc_tx_read_data;
    logic [7:0]  dbg_sdc_tx_reg;
    logic        dbg_sdc_tx_fifo_empty;
    logic        dbg_sdc_tx_fifo_full;
    logic        dbg_sdc_tx_fifo_write_inc;
    logic        dbg_sdc_tx_fifo_read_inc;
    logic        dbg_sdc_tx_load;
    logic        dbg_sdc_tx_start;
    logic        dbg_sdc_tx_reg_loaded;
    logic [7:0]  dbg_sdc_rx_data;
    logic [7:0]  dbg_sdc_rx_shift_reg;
    logic [7:0]  dbg_sdc_rx_shift_reg_endian;
    logic        dbg_sdc_rx_fifo_empty;
    logic        dbg_sdc_rx_fifo_full;
    logic        dbg_sdc_rx_fifo_write_inc;
    logic        dbg_sdc_rx_fifo_read_inc;
    logic        dbg_sdc_shift_in;
    logic        dbg_sdc_sclkenable;
    logic        dbg_sdc_shift_edge;
    logic        dbg_sdc_sample_edge;
    logic        dbg_sdc_end_of_frame;
    logic        dbg_sdc_transmitting;
    logic        dbg_sdc_inactive_state;
    logic [2:0]  dbg_sdc_ctrl_state;
    logic [2:0]  dbg_sdc_ctrl_next_state;
    logic [3:0]  dbg_sdc_ctrl_bitnum;
    logic        dbg_sdc_ctrl_continue_transmit;
    logic        dbg_sdc_ctrl_spi_clk;
    logic        dbg_sdc_block_active;
    logic        dbg_sdc_block_token_seen;
    logic        dbg_sdc_rx_token_read_pending;
    logic [9:0]  dbg_sdc_block_rx_write_count;
    logic [9:0]  dbg_sdc_block_rx_read_count;

    logic        dbg_uart_psel;
    logic        dbg_uart_pwrite;
    logic        dbg_uart_penable;
    logic [2:0]  dbg_uart_paddr;
    logic [7:0]  dbg_uart_pwdata;
    logic        dbg_uart_pstrb0;
    logic [7:0]  dbg_uart_prdata;
    logic        dbg_uart_memwrite;
    logic        dbg_uart_memread;
    logic [2:0]  dbg_uart_entry;
    logic [7:0]  dbg_uart_din;
    logic [7:0]  dbg_uart_dout;
    logic        dbg_uart_memwb;
    logic        dbg_uart_dlab;
    logic [7:0]  dbg_uart_lcr;
    logic [7:0]  dbg_uart_fcr;
    logic [7:0]  dbg_uart_lsr;
    logic [7:0]  dbg_uart_dll;
    logic [7:0]  dbg_uart_dlm;
    logic        dbg_uart_fifoenabled;
    logic        dbg_uart_txfifoempty;
    logic        dbg_uart_txfifofull;
    logic        dbg_uart_txhrfull;
    logic        dbg_uart_txsrfull;
    logic [1:0]  dbg_uart_txstate;
    logic [3:0]  dbg_uart_txbitssent;
    logic [3:0]  dbg_uart_txoversampledcnt;
    logic        dbg_uart_txnextbit;
    logic        dbg_uart_txbaudpulse;
    logic        dbg_uart_baudpulse;
    logic [15:0] dbg_uart_baudcount_lsb;
    logic [11:0] dbg_uart_txsr;
    logic        dbg_uart_soutbit;

    assign dbg_sdc_entry                 = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.Entry;
    assign dbg_sdc_memwrite              = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.Memwrite;
    assign dbg_sdc_din                   = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.Din;
    assign dbg_sdc_dout                  = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.Dout;
    assign dbg_sdc_format                = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.Format;
    assign dbg_sdc_format_dir            = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.FormatDir;
    assign dbg_sdc_frame_length          = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.FrameLength;
    assign dbg_sdc_sckdiv                = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.SckDiv;
    assign dbg_sdc_sckmode               = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.SckMode;
    assign dbg_sdc_cs_mode               = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ChipSelectMode;
    assign dbg_sdc_cs_def                = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ChipSelectDef;
    assign dbg_sdc_interrupt_pending     = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.InterruptPending;
    assign dbg_sdc_tx_data               = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitData;
    assign dbg_sdc_tx_read_data          = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitReadData;
    assign dbg_sdc_tx_reg                = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitReg;
    assign dbg_sdc_tx_fifo_empty         = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitFIFOEmpty;
    assign dbg_sdc_tx_fifo_full          = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitFIFOFull;
    assign dbg_sdc_tx_fifo_write_inc     = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitFIFOWriteInc;
    assign dbg_sdc_tx_fifo_read_inc      = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitFIFOReadInc;
    assign dbg_sdc_tx_load               = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitLoad;
    assign dbg_sdc_tx_start              = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitStart;
    assign dbg_sdc_tx_reg_loaded         = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.TransmitRegLoaded;
    assign dbg_sdc_rx_data               = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ReceiveData;
    assign dbg_sdc_rx_shift_reg          = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ReceiveShiftReg;
    assign dbg_sdc_rx_shift_reg_endian   = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ReceiveShiftRegEndian;
    assign dbg_sdc_rx_fifo_empty         = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ReceiveFIFOEmpty;
    assign dbg_sdc_rx_fifo_full          = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ReceiveFIFOFull;
    assign dbg_sdc_rx_fifo_write_inc     = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ReceiveFIFOWriteInc;
    assign dbg_sdc_rx_fifo_read_inc      = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ReceiveFIFOReadInc;
    assign dbg_sdc_shift_in              = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ShiftIn;
    assign dbg_sdc_sclkenable            = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.SCLKenable;
    assign dbg_sdc_shift_edge            = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.ShiftEdge;
    assign dbg_sdc_sample_edge           = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.SampleEdge;
    assign dbg_sdc_end_of_frame          = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.EndOfFrame;
    assign dbg_sdc_transmitting          = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.Transmitting;
    assign dbg_sdc_inactive_state        = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.InactiveState;
    assign dbg_sdc_ctrl_state            = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.controller.CurrState;
    assign dbg_sdc_ctrl_next_state       = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.controller.NextState;
    assign dbg_sdc_ctrl_bitnum           = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.controller.BitNum;
    assign dbg_sdc_ctrl_continue_transmit = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.controller.ContinueTransmit;
    assign dbg_sdc_ctrl_spi_clk          = wallypipelinedsoc.uncoregen.uncore.sdc.sdc.controller.SPICLK;

    logic [7:0]  sdc_entry;
    logic        sdc_memwrite;
    logic [31:0] sdc_din;
    logic [31:0] sdc_dout;
    logic [7:0]  sdc_tx_reg;
    logic [7:0]  sdc_rx_data;
    logic        sdc_sck;
    logic        sdc_cmd;
    logic        sdc_cs;
    logic        sdc_txdata_write;
    logic        sdc_cmd_byte_seen;
    logic [7:0]  sdc_cmd_byte;
    logic [5:0]  sdc_cmd_index;
    logic [5:0]  sdc_prev_cmd_index;
    logic        sdc_cmd13_any;
    logic        sdc_acmd13_cmd_byte;


    assign sdc_entry    = dbg_sdc_entry;
    assign sdc_memwrite = dbg_sdc_memwrite;
    assign sdc_din      = dbg_sdc_din;
    assign sdc_dout     = dbg_sdc_dout;
    assign sdc_tx_reg   = dbg_sdc_tx_reg;
    assign sdc_rx_data  = dbg_sdc_rx_data;
    assign sdc_sck      = SDCCLK;
    assign sdc_cmd      = SDCCmd;
    assign sdc_cs       = SDCCS;


    assign sdc_txdata_write = dbg_sdc_memwrite & (dbg_sdc_entry == 8'h48);
    assign sdc_cmd_byte     = dbg_sdc_din[7:0];
    assign sdc_cmd_index    = dbg_sdc_din[5:0];
    assign sdc_cmd_byte_seen = sdc_txdata_write & ~SDCCS & (sdc_cmd_byte[7:6] == 2'b01);
    assign sdc_cmd13_any = sdc_cmd_byte_seen & (sdc_cmd_index == 6'd13);
    assign sdc_acmd13_cmd_byte = sdc_cmd13_any & (sdc_prev_cmd_index == 6'd55);

    always_ff @(posedge CPUCLK or posedge soc_reset_ext) begin
      if (soc_reset_ext) sdc_prev_cmd_index <= 6'h3f;
      else if (sdc_cmd_byte_seen) sdc_prev_cmd_index <= sdc_cmd_index;
    end

    logic kernel_serial_probe_pc;
    assign kernel_serial_probe_pc =
      (dbg_pcm[31:0] >= 32'h8031_d7a0) & (dbg_pcm[31:0] < 32'h8031_dbb0);

    assign dbg_uart_psel                 = wallypipelinedsoc.uncoregen.uncore.PSEL[3];
    assign dbg_uart_pwrite               = wallypipelinedsoc.uncoregen.uncore.PWRITE;
    assign dbg_uart_penable              = wallypipelinedsoc.uncoregen.uncore.PENABLE;
    assign dbg_uart_paddr                = wallypipelinedsoc.uncoregen.uncore.PADDR[2:0];
    assign dbg_uart_pwdata               = wallypipelinedsoc.uncoregen.uncore.PWDATA[7:0];
    assign dbg_uart_pstrb0               = wallypipelinedsoc.uncoregen.uncore.PSTRB[0];
    assign dbg_uart_prdata               = wallypipelinedsoc.uncoregen.uncore.PRDATA[3][7:0];
    assign dbg_uart_memwrite             = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.memwrite;
    assign dbg_uart_memread              = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.memread;
    assign dbg_uart_entry                = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.entry;
    assign dbg_uart_din                  = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.Din;
    assign dbg_uart_dout                 = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.Dout;
    assign dbg_uart_memwb                = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.MEMWb;
    assign dbg_uart_dlab                 = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.DLAB;
    assign dbg_uart_lcr                  = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.LCR;
    assign dbg_uart_fcr                  = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.FCR;
    assign dbg_uart_lsr                  = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.LSR;
    assign dbg_uart_dll                  = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.DLL;
    assign dbg_uart_dlm                  = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.DLM;
    assign dbg_uart_fifoenabled          = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.fifoenabled;
    assign dbg_uart_txfifoempty          = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txfifoempty;
    assign dbg_uart_txfifofull           = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txfifofull;
    assign dbg_uart_txhrfull             = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txhrfull;
    assign dbg_uart_txsrfull             = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txsrfull;
    assign dbg_uart_txstate              = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txstate;
    assign dbg_uart_txbitssent           = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txbitssent;
    assign dbg_uart_txoversampledcnt     = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txoversampledcnt;
    assign dbg_uart_txnextbit            = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txnextbit;
    assign dbg_uart_txbaudpulse          = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txbaudpulse;
    assign dbg_uart_baudpulse            = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.baudpulse;
    assign dbg_uart_baudcount_lsb        = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.baudcount[15:0];
    assign dbg_uart_txsr                 = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.txsr;
    assign dbg_uart_soutbit              = wallypipelinedsoc.uncoregen.uncore.uartgen.uart.uartPC.SOUTbit;

    logic       uart_memwrite;
    logic [2:0] uart_paddr;
    logic [7:0] uart_pwdata;
    logic       uart_tx;

    assign uart_memwrite = dbg_uart_memwrite;
    assign uart_paddr    = dbg_uart_paddr;
    assign uart_pwdata   = dbg_uart_pwdata;
    assign uart_tx       = wally_uart_tx;

    // Debug-only block counters.  They start after the SD data token (0xfe)
    // enters the SPI RX FIFO, so Manta can capture the 512-byte block in chunks.
    always_ff @(posedge CPUCLK or posedge soc_reset_ext) begin
      if (soc_reset_ext) begin
        dbg_uram_read_req_d        <= 1'b0;
        dbg_uram_banner_req_d      <= 1'b0;
        dbg_sdc_block_active         <= 1'b0;
        dbg_sdc_block_token_seen     <= 1'b0;
        dbg_sdc_rx_token_read_pending <= 1'b0;
        dbg_sdc_block_rx_write_count <= 10'b0;
        dbg_sdc_block_rx_read_count  <= 10'b0;
      end else begin
        dbg_uram_read_req_d   <= dbg_uram_read_req;
        dbg_uram_banner_req_d <= dbg_uram_banner_req;
        dbg_sdc_block_token_seen <= 1'b0;

        if (SDCCS) begin
          dbg_sdc_block_active         <= 1'b0;
          dbg_sdc_rx_token_read_pending <= 1'b0;
          dbg_sdc_block_rx_write_count <= 10'b0;
          dbg_sdc_block_rx_read_count  <= 10'b0;
        end else begin
          if (dbg_sdc_rx_fifo_write_inc && !dbg_sdc_block_active &&
              (dbg_sdc_rx_shift_reg_endian == 8'hfe)) begin
            dbg_sdc_block_active         <= 1'b1;
            dbg_sdc_block_token_seen     <= 1'b1;
            dbg_sdc_rx_token_read_pending <= 1'b1;
            dbg_sdc_block_rx_write_count <= 10'b0;
            dbg_sdc_block_rx_read_count  <= 10'b0;
          end else if (dbg_sdc_block_active && dbg_sdc_rx_fifo_write_inc &&
                       (dbg_sdc_block_rx_write_count != 10'h3ff)) begin
            dbg_sdc_block_rx_write_count <= dbg_sdc_block_rx_write_count + 10'b1;
          end

          if (dbg_sdc_block_active && dbg_sdc_rx_fifo_read_inc) begin
            if (dbg_sdc_rx_token_read_pending) begin
              dbg_sdc_rx_token_read_pending <= 1'b0;
            end else if (dbg_sdc_block_rx_read_count != 10'h3ff) begin
              dbg_sdc_block_rx_read_count <= dbg_sdc_block_rx_read_count + 10'b1;
            end
          end
        end
      end
    end

    // manta manta_inst (
    //     .clk(CPUCLK),
    //     .rst(soc_reset_ext),        // Manta reset is active-high.
    //     .rx(UARTSin),
    //     .tx(manta_uart_tx),

    //     .status_word(manta_status_word),
    //     .pcf_now(dbg_pcf[31:0]),
    //     .pcm_now(dbg_pcm[31:0]),
    //     .instr_now(dbg_instr_raw_d),
    //     .mcause_now(dbg_mcause[7:0]),
    //     .mepc_now(dbg_mepc[31:0]),
    //     .mtval_now(dbg_mtval[31:0]),

    //     .pcf(dbg_pcf[31:0]),
    //     .pcm(dbg_pcm[31:0]),
    //     .instr_raw_d(dbg_instr_raw_d),
    //     .mcause(dbg_mcause[7:0]),
    //     .mepc(dbg_mepc[31:0]),
    //     .mtval(dbg_mtval[31:0]),
    //     .mcycle_lsb(dbg_mcycle[15:0]),
    //     .minstret_lsb(dbg_minstret[15:0]),
    //     .ahb_addr_lsb(HADDR[15:0]),
    //     .ahb_ctrl(manta_ahb_ctrl),
    //     .axi_ctrl(manta_axi_ctrl)
    // );

  //-----------------------------------------------------------------

  wallypipelinedsoc #(P) wallypipelinedsoc (
    .clk(CPUCLK),
    .reset_ext(soc_reset_ext),
    .reset(wally_reset),
    .HRDATAEXT(HRDATAEXT),
    .HREADYEXT(HREADYEXT),
    .HRESPEXT(HRESPEXT),
    .HSELEXT(HSELEXT),
    .ExternalStall(1'b0),
    .HCLK(HCLKOpen),
    .HRESETn(HRESETnOpen),
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
    .UARTSout(wally_uart_tx),
    .SPIIn(SPIIn),
    .SPIOut(SPIOut),
    .SPICS(SPICS),
    .SPICLK(SPICLK),
    .SDCIn(SDCIn),
    .SDCCmd(SDCCmd),
    .SDCCS(SDCCSin),
    .SDCCLK(SDCCLK),
    .WB_UART_RX(1'b1),
    .WB_UART_TX(),
    .WB_RMII_REF_CLK(1'b0),
    .WB_RMII_CRS_DV(1'b0),
    .WB_RMII_RX_DATA(2'b00),
    .WB_RMII_TX_DATA(WB_RMII_TX_DATA),
    .WB_RMII_TX_EN(WB_RMII_TX_EN),
    .WB_RMII_MDC(WB_RMII_MDC),
    .WB_RMII_MDIO(),
    .WB_RMII_RST_N(WB_RMII_RST_N),
    .WB_RMII_PHY_IRQ(1'b0),
    .AXI_DMAIntr(1'b0),
    .AXI_USBIntr(1'b0),
    .AXI_EthIntr(1'b0),
    .AXI_DummyIntr(1'b0),
    .AXI_SDHCIIntr(1'b0)
  );

  logic [3:0]  axi_awid;
  logic [31:0] axi_awaddr;
  logic [7:0]  axi_awlen;
  logic [2:0]  axi_awsize;
  logic [1:0]  axi_awburst;
  logic        axi_awlock;
  logic [3:0]  axi_awcache;
  logic [2:0]  axi_awprot;
  logic [3:0]  axi_awqos;
  logic        axi_awvalid;
  logic        axi_awready;

  logic [63:0] axi_wdata;
  logic [7:0]  axi_wstrb;
  logic        axi_wlast;
  logic        axi_wvalid;
  logic        axi_wready;

  logic [3:0]  axi_bid;
  logic [1:0]  axi_bresp;
  logic        axi_bvalid;
  logic        axi_bready;

  logic [3:0]  axi_arid;
  logic [31:0] axi_araddr;
  logic [7:0]  axi_arlen;
  logic [2:0]  axi_arsize;
  logic [1:0]  axi_arburst;
  logic        axi_arlock;
  logic [3:0]  axi_arcache;
  logic [2:0]  axi_arprot;
  logic [3:0]  axi_arqos;
  logic        axi_arvalid;
  logic        axi_arready;

  logic [3:0]  axi_rid;
  logic [63:0] axi_rdata;
  logic [1:0]  axi_rresp;
  logic        axi_rlast;
  logic        axi_rvalid;
  logic        axi_rready;

  logic [3:0]  ddr_axi_awid;
  logic [31:0] ddr_axi_awaddr;
  logic [7:0]  ddr_axi_awlen;
  logic [2:0]  ddr_axi_awsize;
  logic [1:0]  ddr_axi_awburst;
  logic        ddr_axi_awlock;
  logic [3:0]  ddr_axi_awcache;
  logic [2:0]  ddr_axi_awprot;
  logic [3:0]  ddr_axi_awqos;
  logic        ddr_axi_awvalid;
  logic        ddr_axi_awready;

  logic [63:0] ddr_axi_wdata;
  logic [7:0]  ddr_axi_wstrb;
  logic        ddr_axi_wlast;
  logic        ddr_axi_wvalid;
  logic        ddr_axi_wready;

  logic [3:0]  ddr_axi_bid;
  logic [1:0]  ddr_axi_bresp;
  logic        ddr_axi_bvalid;
  logic        ddr_axi_bready;

  logic [3:0]  ddr_axi_arid;
  logic [31:0] ddr_axi_araddr;
  logic [7:0]  ddr_axi_arlen;
  logic [2:0]  ddr_axi_arsize;
  logic [1:0]  ddr_axi_arburst;
  logic        ddr_axi_arlock;
  logic [3:0]  ddr_axi_arcache;
  logic [2:0]  ddr_axi_arprot;
  logic [3:0]  ddr_axi_arqos;
  logic        ddr_axi_arvalid;
  logic        ddr_axi_arready;

  logic [3:0]  ddr_axi_rid;
  logic [63:0] ddr_axi_rdata;
  logic [1:0]  ddr_axi_rresp;
  logic        ddr_axi_rlast;
  logic        ddr_axi_rvalid;
  logic        ddr_axi_rready;

  logic [15:0] dbg_ddr_reset_status;
  logic        dbg_ahb_ext_req;
  logic        dbg_ahb_ext_read_req;
  logic        dbg_ahb_ext_write_req;
  logic        dbg_ahb_ext_wait;
  logic        dbg_dtb_window_req;
  logic        dbg_dtb_word_0_req;
  logic        dbg_dtb_word_8_req;
  logic        dbg_dtb_word_10_req;
  logic        dbg_dtb_word_18_req;
  logic        dbg_dtb_write_req;
  logic        dbg_dtb_read_req;
  logic        dbg_axi_aw_hs;
  logic        dbg_axi_w_hs;
  logic        dbg_axi_b_hs;
  logic        dbg_axi_ar_hs;
  logic        dbg_axi_r_hs;
  logic [15:0] dbg_ext_req_count;
  logic [15:0] dbg_axi_aw_count;
  logic [15:0] dbg_axi_w_count;
  logic [15:0] dbg_axi_b_count;
  logic [15:0] dbg_axi_ar_count;
  logic [15:0] dbg_axi_r_count;
  localparam logic [15:0] DEBUG_LONG_COUNT_THRESHOLD = 16'd60000;
  logic [31:0] dbg_last_minstret_lo;
  logic [31:0] dbg_last_pcm_lo;
  logic [15:0] no_retire_count;
  logic [15:0] stall_m_count;
  logic [15:0] ext_wait_count;
  logic [15:0] same_pcm_count;
  logic        linux_kernel_pc;
  logic        linux_kernel_seen;
  logic        linux_first_null_fault;
  logic        linux_long_no_retire_not_wfi;
  logic        linux_long_stall_m;
  logic        linux_long_ext_wait;
  logic        linux_long_same_pcm;
  logic [3:0]  linux_hang_class;

  assign dbg_ddr_reset_status = {
      8'b0,
      init_calib_complete_cpuclk,
      pll_locked_cpuclk,
      ui_aresetn_cpuclk,
      ui_clk_sync_rst_cpuclk,
      HRESETnOpen,
      ddr_ready_cpuclk,
      soc_reset_ext_cpuclk,
      rst_req_cpuclk
  };

  assign dbg_ahb_ext_req       = HREADY & HSELEXT & HTRANS[1];
  assign dbg_ahb_ext_read_req  = dbg_ahb_ext_req & ~HWRITE;
  assign dbg_ahb_ext_write_req = dbg_ahb_ext_req & HWRITE;
  assign dbg_ahb_ext_wait      = HSELEXT & HTRANS[1] & ~HREADYEXT;

  assign dbg_dtb_window_req  = dbg_ahb_ext_req & (HADDR[31:12] == 20'hbf000);
  assign dbg_dtb_word_0_req  = dbg_ahb_ext_req & (HADDR[31:0] == 32'hbf00_0000);
  assign dbg_dtb_word_8_req  = dbg_ahb_ext_req & (HADDR[31:0] == 32'hbf00_0008);
  assign dbg_dtb_word_10_req = dbg_ahb_ext_req & (HADDR[31:0] == 32'hbf00_0010);
  assign dbg_dtb_word_18_req = dbg_ahb_ext_req & (HADDR[31:0] == 32'hbf00_0018);
  assign dbg_dtb_write_req   = dbg_dtb_window_req & HWRITE;
  assign dbg_dtb_read_req    = dbg_dtb_window_req & ~HWRITE;

  assign dbg_axi_aw_hs = axi_awvalid & axi_awready;
  assign dbg_axi_w_hs  = axi_wvalid & axi_wready;
  assign dbg_axi_b_hs  = axi_bvalid & axi_bready;
  assign dbg_axi_ar_hs = axi_arvalid & axi_arready;
  assign dbg_axi_r_hs  = axi_rvalid & axi_rready;
  assign linux_kernel_pc = (dbg_pcm[63:32] == 32'hffff_ffff);

  always_ff @(posedge CPUCLK or posedge soc_reset_ext) begin
    if (soc_reset_ext) begin
      dbg_ext_req_count <= '0;
      dbg_axi_aw_count  <= '0;
      dbg_axi_w_count   <= '0;
      dbg_axi_b_count   <= '0;
      dbg_axi_ar_count  <= '0;
      dbg_axi_r_count   <= '0;
      dbg_last_minstret_lo <= '0;
      dbg_last_pcm_lo      <= '0;
      no_retire_count      <= '0;
      stall_m_count        <= '0;
      ext_wait_count       <= '0;
      same_pcm_count       <= '0;
      linux_kernel_seen    <= 1'b0;
      linux_first_null_fault <= 1'b0;
    end else begin
      if (dbg_ahb_ext_req) dbg_ext_req_count <= dbg_ext_req_count + 1'b1;
      if (dbg_axi_aw_hs)   dbg_axi_aw_count  <= dbg_axi_aw_count + 1'b1;
      if (dbg_axi_w_hs)    dbg_axi_w_count   <= dbg_axi_w_count + 1'b1;
      if (dbg_axi_b_hs)    dbg_axi_b_count   <= dbg_axi_b_count + 1'b1;
      if (dbg_axi_ar_hs)   dbg_axi_ar_count  <= dbg_axi_ar_count + 1'b1;
      if (dbg_axi_r_hs)    dbg_axi_r_count   <= dbg_axi_r_count + 1'b1;

      dbg_last_minstret_lo <= dbg_minstret[31:0];
      dbg_last_pcm_lo      <= dbg_pcm[31:0];
      if (dbg_instr_valid_m & linux_kernel_pc) linux_kernel_seen <= 1'b1;

      if (linux_kernel_seen) begin
        if ((dbg_minstret[31:0] == dbg_last_minstret_lo) & ~dbg_wfi_m)
          no_retire_count <= (no_retire_count == 16'hffff) ? no_retire_count : no_retire_count + 1'b1;
        else
          no_retire_count <= '0;

        if (dbg_stall_m)
          stall_m_count <= (stall_m_count == 16'hffff) ? stall_m_count : stall_m_count + 1'b1;
        else
          stall_m_count <= '0;

        if (dbg_ahb_ext_wait)
          ext_wait_count <= (ext_wait_count == 16'hffff) ? ext_wait_count : ext_wait_count + 1'b1;
        else
          ext_wait_count <= '0;

        if (dbg_pcm[31:0] == dbg_last_pcm_lo)
          same_pcm_count <= (same_pcm_count == 16'hffff) ? same_pcm_count : same_pcm_count + 1'b1;
        else
          same_pcm_count <= '0;

        if (dbg_trap_m & dbg_exception_m &
            (dbg_scause == 64'd13) &
            (dbg_stval == 64'hffff_ffff_ffff_fff8))
          linux_first_null_fault <= 1'b1;
      end else begin
        no_retire_count <= '0;
        stall_m_count   <= '0;
        ext_wait_count  <= '0;
        same_pcm_count  <= '0;
      end
    end
  end

  assign linux_long_no_retire_not_wfi = linux_kernel_seen & (no_retire_count >= DEBUG_LONG_COUNT_THRESHOLD);
  assign linux_long_stall_m           = linux_kernel_seen & (stall_m_count   >= DEBUG_LONG_COUNT_THRESHOLD);
  assign linux_long_ext_wait          = linux_kernel_seen & (ext_wait_count  >= DEBUG_LONG_COUNT_THRESHOLD);
  assign linux_long_same_pcm          = linux_kernel_seen & (same_pcm_count  >= DEBUG_LONG_COUNT_THRESHOLD);
  assign linux_hang_class             = {linux_long_no_retire_not_wfi, linux_long_stall_m, linux_long_ext_wait, linux_long_same_pcm};

  ahb_to_axi4_burst #(
    .AW(32),
    .DW(64),
    .IW(4)
  ) ahbaxibridge (
    .clk(CPUCLK),
    .resetn(~soc_reset_ext),
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
    .AWID(axi_awid),
    .AWADDR(axi_awaddr),
    .AWLEN(axi_awlen),
    .AWSIZE(axi_awsize),
    .AWBURST(axi_awburst),
    .AWLOCK(axi_awlock),
    .AWCACHE(axi_awcache),
    .AWPROT(axi_awprot),
    .AWQOS(axi_awqos),
    .AWVALID(axi_awvalid),
    .AWREADY(axi_awready),
    .WDATA(axi_wdata),
    .WSTRB(axi_wstrb),
    .WLAST(axi_wlast),
    .WVALID(axi_wvalid),
    .WREADY(axi_wready),
    .BID(axi_bid),
    .BRESP(axi_bresp),
    .BVALID(axi_bvalid),
    .BREADY(axi_bready),
    .ARID(axi_arid),
    .ARADDR(axi_araddr),
    .ARLEN(axi_arlen),
    .ARSIZE(axi_arsize),
    .ARBURST(axi_arburst),
    .ARLOCK(axi_arlock),
    .ARCACHE(axi_arcache),
    .ARPROT(axi_arprot),
    .ARQOS(axi_arqos),
    .ARVALID(axi_arvalid),
    .ARREADY(axi_arready),
    .RID(axi_rid),
    .RDATA(axi_rdata),
    .RRESP(axi_rresp),
    .RLAST(axi_rlast),
    .RVALID(axi_rvalid),
    .RREADY(axi_rready)
  );

  typedef logic [31:0] axi_addr_t;
  typedef logic [63:0] axi_data_t;
  typedef logic [7:0]  axi_strb_t;
  typedef logic [3:0]  axi_id_t;
  typedef logic        axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(axi_aw_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T (axi_w_t,  axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T (axi_b_t,  axi_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_ar_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T (axi_r_t,  axi_data_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_REQ_T    (axi_req_t,  axi_aw_t, axi_w_t, axi_ar_t)
  `AXI_TYPEDEF_RESP_T   (axi_resp_t, axi_b_t, axi_r_t)

  axi_req_t  cpu_axi_req;
  axi_resp_t cpu_axi_resp;
  axi_req_t  ddr_axi_req;
  axi_resp_t ddr_axi_resp;

  assign cpu_axi_req.aw.id     = axi_awid;
  assign cpu_axi_req.aw.addr   = axi_awaddr;
  assign cpu_axi_req.aw.len    = axi_awlen;
  assign cpu_axi_req.aw.size   = axi_awsize;
  assign cpu_axi_req.aw.burst  = axi_awburst;
  assign cpu_axi_req.aw.lock   = axi_awlock;
  assign cpu_axi_req.aw.cache  = axi_awcache;
  assign cpu_axi_req.aw.prot   = axi_awprot;
  assign cpu_axi_req.aw.qos    = axi_awqos;
  assign cpu_axi_req.aw.region = 4'b0;
  assign cpu_axi_req.aw.atop   = 6'b0;
  assign cpu_axi_req.aw.user   = 1'b0;
  assign cpu_axi_req.aw_valid  = axi_awvalid;
  assign axi_awready           = cpu_axi_resp.aw_ready;

  assign cpu_axi_req.w.data    = axi_wdata;
  assign cpu_axi_req.w.strb    = axi_wstrb;
  assign cpu_axi_req.w.last    = axi_wlast;
  assign cpu_axi_req.w.user    = 1'b0;
  assign cpu_axi_req.w_valid   = axi_wvalid;
  assign axi_wready            = cpu_axi_resp.w_ready;

  assign axi_bid               = cpu_axi_resp.b.id;
  assign axi_bresp             = cpu_axi_resp.b.resp;
  assign axi_bvalid            = cpu_axi_resp.b_valid;
  assign cpu_axi_req.b_ready   = axi_bready;

  assign cpu_axi_req.ar.id     = axi_arid;
  assign cpu_axi_req.ar.addr   = axi_araddr;
  assign cpu_axi_req.ar.len    = axi_arlen;
  assign cpu_axi_req.ar.size   = axi_arsize;
  assign cpu_axi_req.ar.burst  = axi_arburst;
  assign cpu_axi_req.ar.lock   = axi_arlock;
  assign cpu_axi_req.ar.cache  = axi_arcache;
  assign cpu_axi_req.ar.prot   = axi_arprot;
  assign cpu_axi_req.ar.qos    = axi_arqos;
  assign cpu_axi_req.ar.region = 4'b0;
  assign cpu_axi_req.ar.user   = 1'b0;
  assign cpu_axi_req.ar_valid  = axi_arvalid;
  assign axi_arready           = cpu_axi_resp.ar_ready;

  assign axi_rid               = cpu_axi_resp.r.id;
  assign axi_rdata             = cpu_axi_resp.r.data;
  assign axi_rresp             = cpu_axi_resp.r.resp;
  assign axi_rlast             = cpu_axi_resp.r.last;
  assign axi_rvalid            = cpu_axi_resp.r_valid;
  assign cpu_axi_req.r_ready   = axi_rready;

  assign ddr_axi_awid          = ddr_axi_req.aw.id;
  assign ddr_axi_awaddr        = ddr_axi_req.aw.addr;
  assign ddr_axi_awlen         = ddr_axi_req.aw.len;
  assign ddr_axi_awsize        = ddr_axi_req.aw.size;
  assign ddr_axi_awburst       = ddr_axi_req.aw.burst;
  assign ddr_axi_awlock        = ddr_axi_req.aw.lock;
  assign ddr_axi_awcache       = ddr_axi_req.aw.cache;
  assign ddr_axi_awprot        = ddr_axi_req.aw.prot;
  assign ddr_axi_awqos         = ddr_axi_req.aw.qos;
  assign ddr_axi_awvalid       = ddr_axi_req.aw_valid;
  assign ddr_axi_resp.aw_ready = ddr_axi_awready;

  assign ddr_axi_wdata         = ddr_axi_req.w.data;
  assign ddr_axi_wstrb         = ddr_axi_req.w.strb;
  assign ddr_axi_wlast         = ddr_axi_req.w.last;
  assign ddr_axi_wvalid        = ddr_axi_req.w_valid;
  assign ddr_axi_resp.w_ready  = ddr_axi_wready;

  assign ddr_axi_resp.b.id     = ddr_axi_bid;
  assign ddr_axi_resp.b.resp   = ddr_axi_bresp;
  assign ddr_axi_resp.b.user   = 1'b0;
  assign ddr_axi_resp.b_valid  = ddr_axi_bvalid;
  assign ddr_axi_bready        = ddr_axi_req.b_ready;

  assign ddr_axi_arid          = ddr_axi_req.ar.id;
  assign ddr_axi_araddr        = ddr_axi_req.ar.addr;
  assign ddr_axi_arlen         = ddr_axi_req.ar.len;
  assign ddr_axi_arsize        = ddr_axi_req.ar.size;
  assign ddr_axi_arburst       = ddr_axi_req.ar.burst;
  assign ddr_axi_arlock        = ddr_axi_req.ar.lock;
  assign ddr_axi_arcache       = ddr_axi_req.ar.cache;
  assign ddr_axi_arprot        = ddr_axi_req.ar.prot;
  assign ddr_axi_arqos         = ddr_axi_req.ar.qos;
  assign ddr_axi_arvalid       = ddr_axi_req.ar_valid;
  assign ddr_axi_resp.ar_ready = ddr_axi_arready;

  assign ddr_axi_resp.r.id     = ddr_axi_rid;
  assign ddr_axi_resp.r.data   = ddr_axi_rdata;
  assign ddr_axi_resp.r.resp   = ddr_axi_rresp;
  assign ddr_axi_resp.r.last   = ddr_axi_rlast;
  assign ddr_axi_resp.r.user   = 1'b0;
  assign ddr_axi_resp.r_valid  = ddr_axi_rvalid;
  assign ddr_axi_rready        = ddr_axi_req.r_ready;

  axi_cdc #(
    .aw_chan_t  (axi_aw_t),
    .w_chan_t   (axi_w_t),
    .b_chan_t   (axi_b_t),
    .ar_chan_t  (axi_ar_t),
    .r_chan_t   (axi_r_t),
    .axi_req_t  (axi_req_t),
    .axi_resp_t (axi_resp_t),
    .LogDepth   (2),
    .SyncStages (2)
  ) axi_ddr_cdc (
    .src_clk_i  (CPUCLK),
    .src_rst_ni (~soc_reset_ext),
    .src_req_i  (cpu_axi_req),
    .src_resp_o (cpu_axi_resp),
    .dst_clk_i  (ddr_ui_clk),
    .dst_rst_ni (ui_aresetn),
    .dst_req_o  (ddr_axi_req),
    .dst_resp_i (ddr_axi_resp)
  );

  uberddr3_wrapper ddr3 (
    .i_clk_200(clk200),
    .i_sys_rst(rst_req),
    .o_ui_clk(ddr_ui_clk),
    .o_ref_clk_200(ref_clk200_open),
    .o_ui_clk_sync_rst(ui_clk_sync_rst),
    .o_ui_aresetn(ui_aresetn),
    .o_pll_locked(pll_locked),
    .o_init_calib_complete(init_calib_complete),
    .o_debug1(uber_debug1),
    .i_s_axi_awid(ddr_axi_awid),
    .i_s_axi_awaddr(ddr_axi_awaddr),
    .i_s_axi_awlen(ddr_axi_awlen),
    .i_s_axi_awsize(ddr_axi_awsize),
    .i_s_axi_awburst(ddr_axi_awburst),
    .i_s_axi_awlock(ddr_axi_awlock),
    .i_s_axi_awcache(ddr_axi_awcache),
    .i_s_axi_awprot(ddr_axi_awprot),
    .i_s_axi_awqos(ddr_axi_awqos),
    .i_s_axi_awvalid(ddr_axi_awvalid),
    .o_s_axi_awready(ddr_axi_awready),
    .i_s_axi_wdata(ddr_axi_wdata),
    .i_s_axi_wstrb(ddr_axi_wstrb),
    .i_s_axi_wlast(ddr_axi_wlast),
    .i_s_axi_wvalid(ddr_axi_wvalid),
    .o_s_axi_wready(ddr_axi_wready),
    .o_s_axi_bid(ddr_axi_bid),
    .o_s_axi_bresp(ddr_axi_bresp),
    .o_s_axi_bvalid(ddr_axi_bvalid),
    .i_s_axi_bready(ddr_axi_bready),
    .i_s_axi_arid(ddr_axi_arid),
    .i_s_axi_araddr(ddr_axi_araddr),
    .i_s_axi_arlen(ddr_axi_arlen),
    .i_s_axi_arsize(ddr_axi_arsize),
    .i_s_axi_arburst(ddr_axi_arburst),
    .i_s_axi_arlock(ddr_axi_arlock),
    .i_s_axi_arcache(ddr_axi_arcache),
    .i_s_axi_arprot(ddr_axi_arprot),
    .i_s_axi_arqos(ddr_axi_arqos),
    .i_s_axi_arvalid(ddr_axi_arvalid),
    .o_s_axi_arready(ddr_axi_arready),
    .o_s_axi_rid(ddr_axi_rid),
    .o_s_axi_rdata(ddr_axi_rdata),
    .o_s_axi_rresp(ddr_axi_rresp),
    .o_s_axi_rlast(ddr_axi_rlast),
    .o_s_axi_rvalid(ddr_axi_rvalid),
    .i_s_axi_rready(ddr_axi_rready),
    .io_ddr3_dq(ddr3_dq),
    .io_ddr3_dqs_n(ddr3_dqs_n),
    .io_ddr3_dqs_p(ddr3_dqs_p),
    .o_ddr3_addr(ddr3_addr),
    .o_ddr3_ba(ddr3_ba),
    .o_ddr3_ras_n(ddr3_ras_n),
    .o_ddr3_cas_n(ddr3_cas_n),
    .o_ddr3_we_n(ddr3_we_n),
    .o_ddr3_reset_n(ddr3_reset_n),
    .o_ddr3_ck_p(ddr3_ck_p),
    .o_ddr3_ck_n(ddr3_ck_n),
    .o_ddr3_cke(ddr3_cke),
    .o_ddr3_cs_n(ddr3_cs_n),
    .o_ddr3_dm(ddr3_dm),
    .o_ddr3_odt(ddr3_odt)
  );

  manta manta_inst_debug (
    .clk(CPUCLK),
    .rst(1'b0),
    .rx(debugIn),
    .tx(manta_uart_tx),

    .rst_req(rst_req_cpuclk),
    .soc_reset_ext(soc_reset_ext_cpuclk),
    .resetn_pin(resetn_cpuclk),
    .south_reset_pin(south_reset_cpuclk),
    .wally_reset(wally_reset),
    .hresetn_open(HRESETnOpen),

    .pll_locked(pll_locked_cpuclk),
    .init_calib_complete(init_calib_complete_cpuclk),
    .ui_aresetn(ui_aresetn_cpuclk),
    .ui_clk_sync_rst(ui_clk_sync_rst_cpuclk),
    .ddr_ready_raw(ddr_ready_raw_cpuclk),
    .ddr_ready_meta(ddr_ready_meta),
    .ddr_ready_cpuclk(ddr_ready_cpuclk),
    .uber_debug1(uber_debug1_cpuclk),
    .uber_calib_state(uber_calib_state_cpuclk),

    .pcf(dbg_pcf[31:0]),
    .pcm(dbg_pcm[31:0]),
    .instr_m(dbg_instr_m),
    .instr_raw_d(dbg_instr_raw_d),
    .instr_valid_m(dbg_instr_valid_m),
    .stall_m(dbg_stall_m),
    .stall_f(dbg_stall_f),
    .stall_d(dbg_stall_d),
    .stall_e(dbg_stall_e),
    .stall_w(dbg_stall_w),
    .flush_m(dbg_flush_m),
    .flush_d(dbg_flush_d),
    .flush_e(dbg_flush_e),
    .flush_w(dbg_flush_w),
    .trap_m(dbg_trap_m),
    .interrupt_m(dbg_interrupt_m),
    .exception_m(dbg_exception_m),
    .mcause(dbg_mcause),
    .mepc(dbg_mepc),
    .mtval(dbg_mtval),
    .scause(dbg_scause),
    .sepc(dbg_sepc),
    .stval(dbg_stval),
    .satp(dbg_satp),
    .mcycle_lo(dbg_mcycle[31:0]),
    .minstret_lo(dbg_minstret[31:0]),
    .priv_mode_w(dbg_priv_mode_w),
    .wfi_m(dbg_wfi_m),
    .int_pending_m(dbg_int_pending_m),
    .ifu_stall_f(dbg_ifu_stall_f),
    .lsu_stall_m(dbg_lsu_stall_m),
    .icache_stall_f(dbg_icache_stall_f),
    .dcache_stall_m(dbg_dcache_stall_m),
    .mtimer_int(dbg_mtimer_int),
    .mext_int(dbg_mext_int),
    .sext_int(dbg_sext_int),
    .msw_int(dbg_msw_int),
    .gpr_a0_lo(dbg_gpr_a0_lo),
    .gpr_a1_lo(dbg_gpr_a1_lo),
    .gpr_a2_lo(dbg_gpr_a2_lo),
    .gpr_a3_lo(dbg_gpr_a3_lo),
    .gpr_a5_lo(dbg_gpr_a5_lo),
    .linux_kernel_seen(linux_kernel_seen),
    .linux_first_null_fault(linux_first_null_fault),
    .linux_long_no_retire_not_wfi(linux_long_no_retire_not_wfi),
    .linux_long_stall_m(linux_long_stall_m),
    .linux_long_ext_wait(linux_long_ext_wait),
    .linux_long_same_pcm(linux_long_same_pcm),
    .no_retire_count(no_retire_count),
    .stall_m_count(stall_m_count),
    .ext_wait_count(ext_wait_count),
    .same_pcm_count(same_pcm_count),
    .linux_hang_class(linux_hang_class),
    .uart_out(wally_uart_tx),
    .reset_status(dbg_ddr_reset_status),

    .ahb_haddr(HADDR[31:0]),
    .ahb_hwrite(HWRITE),
    .ahb_htrans(HTRANS),
    .ahb_hsize(HSIZE),
    .ahb_hburst(HBURST),
    .ahb_hready(HREADY),
    .ahb_hreadyext(HREADYEXT),
    .ahb_hrespext(HRESPEXT),
    .ahb_hselext(HSELEXT),
    .ahb_ext_req(dbg_ahb_ext_req),
    .ahb_ext_wait(dbg_ahb_ext_wait),
    .ahb_hwdata(HWDATA),
    .ahb_hrdataext(HRDATAEXT),

    // .dtb_window_req(dbg_dtb_window_req),
    // .dtb_word_0_req(dbg_dtb_word_0_req),
    // .dtb_word_8_req(dbg_dtb_word_8_req),
    // .dtb_word_10_req(dbg_dtb_word_10_req),
    // .dtb_word_18_req(dbg_dtb_word_18_req),

    .ext_req_count(dbg_ext_req_count)

    // AXI CPU-clock side, enable with matching probes in manta_cvw_debug.yaml.
    // .axi_awvalid(axi_awvalid),
    // .axi_awready(axi_awready),
    // .axi_wvalid(axi_wvalid),
    // .axi_wready(axi_wready),
    // .axi_bvalid(axi_bvalid),
    // .axi_bready(axi_bready),
    // .axi_arvalid(axi_arvalid),
    // .axi_arready(axi_arready),
    // .axi_rvalid(axi_rvalid),
    // .axi_rready(axi_rready),
    // .axi_rlast(axi_rlast),
    // .axi_aw_count(dbg_axi_aw_count),
    // .axi_w_count(dbg_axi_w_count),
    // .axi_b_count(dbg_axi_b_count),
    // .axi_ar_count(dbg_axi_ar_count),
    // .axi_r_count(dbg_axi_r_count),

    // URAM / bootrom banner probes.
    // .uram_haddr(uram_haddr),
    // .uram_ramaddr(uram_ramaddr),
    // .uram_word_index(uram_word_index),
    // .uram_byte_offset(uram_byte_offset),
    // .uram_hsel(uram_hsel),
    // .uram_hseld(uram_hseld),
    // .uram_hreadyram(uram_hreadyram),
    // .uram_hrespram(uram_hrespram),
    // .uram_hreadram(uram_hreadram),
    // .uram_read_req(uram_read_req),
    // .uram_banner_req(uram_banner_req),
    // .uram_banner_word_ok(uram_banner_word_ok),
    // .uram_banner_word_zero(uram_banner_word_zero),

    // SD/SPI probes.
    ,.sdc_entry(sdc_entry),
    .sdc_memwrite(sdc_memwrite),
    .sdc_din(sdc_din),
    .sdc_dout(sdc_dout),
    .sdc_tx_reg(sdc_tx_reg),
    .sdc_rx_data(sdc_rx_data),
    .sdc_sck(sdc_sck),
    .sdc_cmd(sdc_cmd),
    .sdc_cs(sdc_cs)

    // DEBUG PROBES (disabled because command-byte trigger is not reliable).
    // ,.sdc_txdata_write(sdc_txdata_write),
    // .sdc_cmd_byte_seen(sdc_cmd_byte_seen),
    // .sdc_cmd_byte(sdc_cmd_byte),
    // .sdc_cmd_index(sdc_cmd_index),
    // .sdc_prev_cmd_index(sdc_prev_cmd_index),
    // .sdc_cmd13_any(sdc_cmd13_any),
    // .sdc_acmd13_cmd_byte(sdc_acmd13_cmd_byte)

    // .kernel_serial_probe_pc(kernel_serial_probe_pc)

    // APB UART peripheral probes.
    // .uart_memwrite(uart_memwrite),
    // .uart_paddr(uart_paddr),
    // .uart_pwdata(uart_pwdata),
    // .uart_tx(uart_tx)
  );

endmodule

`default_nettype wire
