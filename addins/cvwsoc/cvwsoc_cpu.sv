`include "axi/typedef.svh"

module cvwsoc_cpu import cvw::*; #(
  parameter cvwsoc_cfg_t C,
  parameter int unsigned AXI_ID_W = 2,
  parameter type cpu_axi_req_t = logic,
  parameter type cpu_axi_resp_t = logic
) (
  input logic clk_i, rst_ni, time_clk_i,
  input logic meip_i, seip_i, external_stall_i,
  output cpu_axi_req_t axi_req_o,
  input cpu_axi_resp_t axi_resp_i
);

  localparam cvw_t P = C.wally;
  function automatic cvw_t clint_cfg(input cvw_t cfg);
    clint_cfg = cfg;
    // The AXI-Lite-to-APB bridge aligns accesses to the APB data width.
    // Let this bus-facing CLINT instance use the 64-bit register view on RV32/W64.
    if ((cfg.XLEN == 32) && (cfg.AHBW == 64)) clint_cfg.XLEN = 64;
  endfunction
  localparam cvw_t CLINT_P = clint_cfg(P);
  typedef logic [31:0] addr_t;
  typedef logic [AXI_ID_W-1:0] id_t;
  typedef logic [P.AHBW-1:0] data_t;
  typedef logic [P.AHBW/8-1:0] strb_t;
  typedef logic user_t;
  `AXI_TYPEDEF_ALL(cpu_int, addr_t, id_t, data_t, strb_t, user_t)
  `AXI_LITE_TYPEDEF_ALL(clint_lite, addr_t, data_t, strb_t)
  typedef struct packed { addr_t paddr; axi_pkg::prot_t pprot; logic psel;
    logic penable; logic pwrite; data_t pwdata; strb_t pstrb; } clint_apb_req_t;
  typedef struct packed { logic pready; data_t prdata; logic pslverr; } clint_apb_resp_t;
  typedef struct packed { int unsigned idx; addr_t start_addr; addr_t end_addr; } rule_t;

  cpu_int_req_t wally_req;
  cpu_int_resp_t wally_resp;
  cpu_int_req_t [1:0] demux_req;
  cpu_int_resp_t [1:0] demux_resp;
  clint_lite_req_t lite_req;
  clint_lite_resp_t lite_resp;
  //------------------------------
  //------------------------------
  //------------------------------
  //------------------------------
  //------------------------------
  // TEST
  cpu_int_req_t  clint_axi_req_cut;
  cpu_int_resp_t clint_axi_resp_cut;  
  //------------------------------
  //------------------------------
  //------------------------------
  //------------------------------
  clint_apb_req_t [0:0] apb_req;
  clint_apb_resp_t [0:0] apb_resp;
  // rele for axil-to-apb
  localparam rule_t [0:0] CLINT_MAP = '{'{idx:0, start_addr:P.CLINT_BASE[31:0],
                                            end_addr:P.CLINT_BASE[31:0] + P.CLINT_RANGE[31:0] + 1}};
  // CLINT mtime is architecturally 64-bit; XLEN/AHBW only affect its accesses.
  logic [63:0] mtime;
  logic mtip, msip;
  logic aw_clint, ar_clint;
  assign aw_clint = (wally_req.aw.addr >= P.CLINT_BASE[31:0]) &&
                    (wally_req.aw.addr <= P.CLINT_BASE[31:0] + P.CLINT_RANGE[31:0]);
  assign ar_clint = (wally_req.ar.addr >= P.CLINT_BASE[31:0]) &&
                    (wally_req.ar.addr <= P.CLINT_BASE[31:0] + P.CLINT_RANGE[31:0]);


  // CDC: PLIC signals.  PULP's sync preserves the two FFs as an ASYNC_REG chain
  logic meip_synced_i, seip_synced_i, external_stall_synced_i;
  sync #(.STAGES(2)) sync_meip (
    .clk_i, .rst_ni, .serial_i(meip_i), .serial_o(meip_synced_i));
  sync #(.STAGES(2)) sync_seip (
    .clk_i, .rst_ni, .serial_i(seip_i), .serial_o(seip_synced_i));
  sync #(.STAGES(2)) sync_ext_stall (
    .clk_i, .rst_ni, .serial_i(external_stall_i), .serial_o(external_stall_synced_i));

  // Debug signals
  (* mark_debug = "true" *) logic HSELEXT;
  (* mark_debug = "true" *) logic [P.PA_BITS-1:0] HADDR;
  (* mark_debug = "true" *) logic [P.AHBW-1:0] HWDATA, HRDATAEXT;
  (* mark_debug = "true" *) logic [P.AHBW/8-1:0] HWSTRB;
  (* mark_debug = "true" *) logic HWRITE, HREADY, HREADYEXT, HRESPEXT;
  (* mark_debug = "true" *) logic [2:0] HSIZE, HBURST;
  (* mark_debug = "true" *) logic [1:0] HTRANS;
  (* mark_debug = "true" *) logic hsel_axi, hready_axi;
  (* mark_debug = "true" *) logic [3:0] HPROT;

  
  localparam int ID_W = 2; //FIXME
  logic [ID_W-1:0] m_axi_awid, m_axi_bid, m_axi_arid, m_axi_rid;
  logic [31:0] m_axi_awaddr, m_axi_araddr;
  logic [7:0] m_axi_awlen, m_axi_arlen;
  logic [2:0] m_axi_awsize, m_axi_arsize;
  logic [1:0] m_axi_awburst, m_axi_arburst, m_axi_bresp, m_axi_rresp;
  logic m_axi_awvalid, m_axi_awready, m_axi_wlast, m_axi_wvalid, m_axi_wready;
  logic m_axi_bvalid, m_axi_bready, m_axi_arvalid, m_axi_arready;
  logic m_axi_rlast, m_axi_rvalid, m_axi_rready;
  logic [P.AHBW-1:0] m_axi_wdata, m_axi_rdata;
  logic [P.AHBW/8-1:0] m_axi_wstrb;

  (* mark_debug = "true" *) logic [P.XLEN-1:0] PCM;
  (* mark_debug = "true" *) logic InstrValidM, TrapM, StallM, FlushM;
  (* mark_debug = "true" *) logic [31:0] InstrM;
  // IFU/cache observation: distinguishes a bad AXI refill from corruption
  // introduced while selecting, spilling, or decoding a cached instruction.
  logic [P.XLEN-1:0] dbg_pcf, dbg_pcd;
  logic [31:0] dbg_icache_instr_f, dbg_instr_raw_f, dbg_postspill_instr_raw_f;
  logic [31:0] dbg_instr_raw_d, dbg_instr_d;
  logic dbg_icache_miss_f, dbg_icache_stall_f, dbg_cacheable_f;
  logic dbg_load_misaligned_fault_m, dbg_load_access_fault_m, dbg_load_page_fault_m;
  logic dbg_store_amo_misaligned_fault_m, dbg_store_amo_access_fault_m, dbg_store_amo_page_fault_m;
  logic dbg_instr_misaligned_fault_m, dbg_instr_access_fault_m, dbg_instr_page_fault_m;
  logic [3:0] dbg_trap_cause_m;
  logic dbg_trap_exception_m, dbg_trap_interrupt_m;
  logic [P.XLEN-1:0] dbg_trap_epc_m, dbg_trap_vector_m, dbg_trap_tval_src_m;
  logic [P.XLEN-1:0] dbg_gpr_ra, dbg_gpr_sp, dbg_gpr_s1, dbg_gpr_a0, dbg_gpr_a1, dbg_gpr_a2;
  logic [P.XLEN-1:0] dbg_gpr_s2, dbg_gpr_s3, dbg_gpr_s4, dbg_gpr_result_w;
  logic dbg_gpr_regwrite_w;
  logic [4:0] dbg_gpr_rd_w;



  if (C.cpu == CVWSOC_CPU_WALLY) begin : gen_cpu
    cvwsoc_cpu_wally #(
        .P(P),
        .AXI_ID_W(AXI_ID_W),
        .axi_req_t(cpu_int_req_t),
        .axi_resp_t(cpu_int_resp_t)
    )  wally (
        .clk_i, 
        .rst_ni,
        .mtime_i(mtime),
        .mtip_i(mtip),
        .msip_i(msip),
        .meip_i(meip_synced_i),
        .seip_i(seip_synced_i),
        .external_stall_i(external_stall_synced_i), 
        .axi_req_o(wally_req),
        .axi_resp_i(wally_resp) );

    // Debug signals
    assign HSELEXT = wally.hsel_axi;
    assign HADDR = wally.HADDR;
    assign HWDATA = wally.HWDATA;
    assign HWSTRB = wally.HWSTRB;
    assign HWRITE = wally.HWRITE;
    assign HSIZE = wally.HSIZE;
    assign HBURST = wally.HBURST;
    assign HTRANS = wally.HTRANS;
    assign HPROT = wally.HPROT;
    assign HREADY = wally.HREADY;
    assign HRDATAEXT = wally.HRDATA;
    assign HREADYEXT = wally.HREADY;
    assign HRESPEXT = wally.HRESP;
    assign hready_axi = wally.hready_axi;
    assign hsel_axi = wally.hsel_axi;


    assign m_axi_awid = wally.awid;
    assign m_axi_awaddr = wally.awaddr;
    assign m_axi_awlen = wally.awlen;
    assign m_axi_awsize = wally.awsize;
    assign m_axi_awburst = wally.awburst;
    assign m_axi_awvalid = wally.awvalid;
    assign m_axi_awready = wally.awready;
    assign m_axi_wdata = wally.wdata;
    assign m_axi_wstrb = wally.wstrb;
    assign m_axi_wlast = wally.wlast;
    assign m_axi_wvalid = wally.wvalid;
    assign m_axi_wready = wally.wready;
    assign m_axi_bid = wally.bid;
    assign m_axi_bresp = wally.bresp;
    assign m_axi_bvalid = wally.bvalid;
    assign m_axi_bready = wally.bready;
    assign m_axi_arid = wally.arid;
    assign m_axi_araddr = wally.araddr;
    assign m_axi_arlen = wally.arlen;
    assign m_axi_arsize = wally.arsize;
    assign m_axi_arburst = wally.arburst;
    assign m_axi_arvalid = wally.arvalid;
    assign m_axi_arready = wally.arready;
    assign m_axi_rid = wally.rid;
    assign m_axi_rdata = wally.rdata;
    assign m_axi_rresp = wally.rresp;
    assign m_axi_rlast = wally.rlast;
    assign m_axi_rvalid = wally.rvalid;
    assign m_axi_rready = wally.rready;


    assign PCM = wally.core.ifu.PCM;
    assign dbg_pcf = wally.core.ifu.PCF;
    assign dbg_pcd = wally.core.ifu.PCD;
    assign dbg_icache_instr_f = wally.core.ifu.ICacheInstrF;
    assign dbg_instr_raw_f = wally.core.ifu.InstrRawF;
    assign dbg_postspill_instr_raw_f = wally.core.ifu.PostSpillInstrRawF;
    assign dbg_instr_raw_d = wally.core.ifu.InstrRawD;
    assign dbg_instr_d = wally.core.ifu.InstrD;
    assign dbg_icache_miss_f = wally.core.ifu.ICacheMiss;
    assign dbg_icache_stall_f = wally.core.ifu.ICacheStallF;
    assign dbg_cacheable_f = wally.core.ifu.CacheableF;
    assign InstrValidM = wally.core.ieu.InstrValidM;
    assign InstrM = wally.core.InstrM;
    assign TrapM = wally.core.TrapM;
    assign StallM = wally.core.StallM;
    assign FlushM = wally.core.FlushM;
    assign dbg_load_misaligned_fault_m = wally.core.LoadMisalignedFaultM;
    assign dbg_load_access_fault_m = wally.core.LoadAccessFaultM;
    assign dbg_load_page_fault_m = wally.core.LoadPageFaultM;
    assign dbg_store_amo_misaligned_fault_m = wally.core.StoreAmoMisalignedFaultM;
    assign dbg_store_amo_access_fault_m = wally.core.StoreAmoAccessFaultM;
    assign dbg_store_amo_page_fault_m = wally.core.StoreAmoPageFaultM;
    assign dbg_instr_misaligned_fault_m = wally.core.InstrMisalignedFaultM;
    assign dbg_instr_access_fault_m = wally.core.priv.priv.InstrAccessFaultM;
    assign dbg_instr_page_fault_m = wally.core.priv.priv.InstrPageFaultM;
    assign dbg_trap_cause_m = wally.core.priv.priv.CauseM;
    assign dbg_trap_exception_m = wally.core.priv.priv.ExceptionM;
    assign dbg_trap_interrupt_m = wally.core.priv.priv.InterruptM;
    assign dbg_trap_epc_m = wally.core.EPCM;
    assign dbg_trap_vector_m = wally.core.TrapVectorM;
    assign dbg_trap_tval_src_m = wally.core.IEUAdrxTvalM;
    assign dbg_gpr_ra = wally.core.ieu.dp.regf.rf[1];
    assign dbg_gpr_sp = wally.core.ieu.dp.regf.rf[2];
    assign dbg_gpr_s1 = wally.core.ieu.dp.regf.rf[9];
    assign dbg_gpr_a0 = wally.core.ieu.dp.regf.rf[10];
    assign dbg_gpr_a1 = wally.core.ieu.dp.regf.rf[11];
    assign dbg_gpr_a2 = wally.core.ieu.dp.regf.rf[12];
    assign dbg_gpr_s2 = wally.core.ieu.dp.regf.rf[18];
    assign dbg_gpr_s3 = wally.core.ieu.dp.regf.rf[19];
    assign dbg_gpr_s4 = wally.core.ieu.dp.regf.rf[20];
    assign dbg_gpr_regwrite_w = wally.core.ieu.RegWriteW;
    assign dbg_gpr_rd_w = wally.core.ieu.RdW;
    assign dbg_gpr_result_w = wally.core.ieu.dp.ResultW;

  end else if (C.cpu == CVWSOC_CPU_VEXRISCV) begin : gen_cpu_vexriscv

    cvwsoc_cpu_vexriscv #(
        .P(P),
        .AXI_ID_W(AXI_ID_W),
        .axi_req_t(cpu_int_req_t),
        .axi_resp_t(cpu_int_resp_t)
    ) vexriscv (
        .clk_i,
        .rst_ni,
        .mtime_i(mtime),
        .mtip_i(mtip),
        .msip_i(msip),
        .meip_i(meip_synced_i),
        .seip_i(seip_synced_i),
        .external_stall_i(external_stall_synced_i),
        .axi_req_o(wally_req),
        .axi_resp_i(wally_resp) );

    // VexriscvCVWSoC is AXI-native and has no AHB debug port.
    assign HSELEXT = 1'b0;
    assign HADDR = '0;
    assign HWDATA = '0;
    assign HWSTRB = '0;
    assign HWRITE = 1'b0;
    assign HSIZE = '0;
    assign HBURST = '0;
    assign HPROT = '0;
    assign HTRANS = '0;
    assign HREADY = 1'b0;
    assign HRDATAEXT = '0;
    assign HREADYEXT = 1'b0;
    assign HRESPEXT = 1'b0;
    assign hsel_axi = 1'b0;
    assign hready_axi = 1'b0;

    // Preserve the existing testbench-visible AXI probes.
    assign m_axi_awid = vexriscv.cpu_axi_req.aw.id;
    assign m_axi_awaddr = vexriscv.cpu_axi_req.aw.addr;
    assign m_axi_awlen = vexriscv.cpu_axi_req.aw.len;
    assign m_axi_awsize = vexriscv.cpu_axi_req.aw.size;
    assign m_axi_awburst = vexriscv.cpu_axi_req.aw.burst;
    assign m_axi_awvalid = vexriscv.cpu_axi_req.aw_valid;
    assign m_axi_awready = vexriscv.cpu_axi_resp.aw_ready;
    assign m_axi_wdata = vexriscv.cpu_axi_req.w.data;
    assign m_axi_wstrb = vexriscv.cpu_axi_req.w.strb;
    assign m_axi_wlast = vexriscv.cpu_axi_req.w.last;
    assign m_axi_wvalid = vexriscv.cpu_axi_req.w_valid;
    assign m_axi_wready = vexriscv.cpu_axi_resp.w_ready;
    assign m_axi_bid = vexriscv.cpu_axi_resp.b.id;
    assign m_axi_bresp = vexriscv.cpu_axi_resp.b.resp;
    assign m_axi_bvalid = vexriscv.cpu_axi_resp.b_valid;
    assign m_axi_bready = vexriscv.cpu_axi_req.b_ready;
    assign m_axi_arid = vexriscv.cpu_axi_req.ar.id;
    assign m_axi_araddr = vexriscv.cpu_axi_req.ar.addr;
    assign m_axi_arlen = vexriscv.cpu_axi_req.ar.len;
    assign m_axi_arsize = vexriscv.cpu_axi_req.ar.size;
    assign m_axi_arburst = vexriscv.cpu_axi_req.ar.burst;
    assign m_axi_arvalid = vexriscv.cpu_axi_req.ar_valid;
    assign m_axi_arready = vexriscv.cpu_axi_resp.ar_ready;
    assign m_axi_rid = vexriscv.cpu_axi_resp.r.id;
    assign m_axi_rdata = vexriscv.cpu_axi_resp.r.data;
    assign m_axi_rresp = vexriscv.cpu_axi_resp.r.resp;
    assign m_axi_rlast = vexriscv.cpu_axi_resp.r.last;
    assign m_axi_rvalid = vexriscv.cpu_axi_resp.r_valid;
    assign m_axi_rready = vexriscv.cpu_axi_req.r_ready;

    // Map the generated VexRiscv pipeline's memory stage onto the existing
    // CPU debug convention.  These signals are retained by mark_debug above
    // and are consequently available in the FPGA ILA just as for Wally.
    assign PCM         = vexriscv.core.memory_PC;
    assign InstrM      = vexriscv.core.memory_INSTRUCTION;
    assign InstrValidM = vexriscv.core.memory_arbitration_isValid;
    assign StallM      = vexriscv.core.memory_arbitration_isStuck;
    assign FlushM      = vexriscv.core.memory_arbitration_isFlushed;
    assign TrapM       = vexriscv.core.CsrPlugin_exceptionPortCtrl_exceptionValids_memory;

  end else begin : gen_cpu_cva6

    // CVA6-only probes.
    logic        dbg_cva6_amo_req;
    logic [3:0]  dbg_cva6_amo_op;
    logic [1:0]  dbg_cva6_amo_size;
    logic [P.XLEN-1:0] dbg_cva6_amo_addr;
    logic [P.XLEN-1:0] dbg_cva6_amo_wdata;
    logic        dbg_cva6_amo_resp_ack;
    logic [P.XLEN-1:0] dbg_cva6_amo_resp_rdata;
    logic        dbg_cva6_amo_valid_commit;
    logic        dbg_cva6_commit_ack;
    logic        dbg_cva6_commit_drop;
    logic [P.XLEN-1:0] dbg_cva6_commit_pc;
    logic        dbg_cva6_exception_valid;
    logic [P.XLEN-1:0] dbg_cva6_exception_cause;
    logic [P.XLEN-1:0] dbg_cva6_exception_tval;
    logic        dbg_cva6_flush_commit;
    logic [P.XLEN-1:0] dbg_cva6_pc_id_ex;
    logic [31:0] dbg_cva6_orig_instr_id_issue;

    // debug: AMO/cache progress probes.  These expose the CVA6 AMO status
    logic [3:0]  dbg_cva6_miss_handler_state;
    logic        dbg_cva6_cache_busy;
    logic        dbg_cva6_amo_bypass_req;
    logic [3:0]  dbg_cva6_amo_bypass_op;
    logic [1:0]  dbg_cva6_amo_bypass_size;
    logic [P.XLEN-1:0] dbg_cva6_amo_bypass_addr;
    logic [P.XLEN-1:0] dbg_cva6_amo_bypass_wdata;
    logic [7:0]  dbg_cva6_amo_bypass_be;
    logic        dbg_cva6_amo_bypass_we;
    logic        dbg_cva6_amo_bypass_gnt;
    logic        dbg_cva6_amo_bypass_valid;
    logic [P.XLEN-1:0] dbg_cva6_amo_bypass_rdata;
    logic        dbg_cva6_bypass_axi_arvalid;
    logic        dbg_cva6_bypass_axi_arready;
    logic [P.XLEN-1:0] dbg_cva6_bypass_axi_araddr;
    logic [2:0]  dbg_cva6_bypass_axi_arsize;
    logic [3:0]  dbg_cva6_bypass_axi_arid;
    logic        dbg_cva6_bypass_axi_awvalid;
    logic [5:0]  dbg_cva6_bypass_axi_awatop;
    logic        dbg_cva6_bypass_axi_wvalid;
    logic        dbg_cva6_bypass_axi_bvalid;
    logic        dbg_cva6_bypass_axi_rvalid;
    logic        dbg_cva6_bypass_axi_rready;

    cvwsoc_cpu_cva6 #(
        .P(P),
        .C(C),
        .AXI_ID_W(AXI_ID_W),
        .axi_req_t(cpu_int_req_t),
        .axi_resp_t(cpu_int_resp_t)
    )  wally (
        .clk_i, 
        .rst_ni,
        .mtime_i(mtime),
        .mtip_i(mtip),
        .msip_i(msip),
        .meip_i(meip_synced_i),
        .seip_i(seip_synced_i),
        .external_stall_i(external_stall_synced_i), 
        .axi_req_o(wally_req),
        .axi_resp_i(wally_resp) );

    // No AHB bus for CVA6
    assign HSELEXT = 1'b0;
    assign HADDR =  1'b0;
    assign HWDATA =  1'b0;
    assign HWSTRB =  1'b0;
    assign HWRITE =  1'b0;
    assign HSIZE =  1'b0;
    assign HBURST =  1'b0;
    assign HTRANS =  1'b0;
    assign HREADY =  1'b0;
    assign HRDATAEXT = 1'b0;
    assign HREADYEXT = 1'b0;
    assign HRESPEXT = 1'b0;

    wire dbg_commit_fire =
                wally.rvfi_probes[0].instr.commit_ack[0] &&
                !wally.rvfi_probes[0].instr.commit_drop[0];

    assign InstrValidM = dbg_commit_fire;
    assign PCM = dbg_commit_fire
            ? wally.rvfi_probes[0].instr.commit_instr_pc[0]
            : '0;
    // No commit-stage raw instruction exists in rvfi_probes.
    assign InstrM = 32'b0;

    assign dbg_cva6_amo_req =
        wally.gen_cva6_cores[0].i_core_cva6.amo_req.req;
    assign dbg_cva6_amo_op =
        wally.gen_cva6_cores[0].i_core_cva6.amo_req.amo_op;
    assign dbg_cva6_amo_size =
        wally.gen_cva6_cores[0].i_core_cva6.amo_req.size;
    assign dbg_cva6_amo_addr =
        wally.gen_cva6_cores[0].i_core_cva6.amo_req.operand_a;
    assign dbg_cva6_amo_wdata =
        wally.gen_cva6_cores[0].i_core_cva6.amo_req.operand_b;
    assign dbg_cva6_amo_resp_ack =
        wally.gen_cva6_cores[0].i_core_cva6.amo_resp.ack;
    assign dbg_cva6_amo_resp_rdata =
        wally.gen_cva6_cores[0].i_core_cva6.amo_resp.result;
    assign dbg_cva6_amo_valid_commit =
        wally.gen_cva6_cores[0].i_core_cva6.amo_valid_commit;
    assign dbg_cva6_commit_ack =
        wally.gen_cva6_cores[0].i_core_cva6.commit_ack_commit_id[0];
    assign dbg_cva6_commit_drop =
        wally.gen_cva6_cores[0].i_core_cva6.commit_drop_id_commit[0];
    assign dbg_cva6_commit_pc =
        wally.gen_cva6_cores[0].i_core_cva6.commit_instr_id_commit[0].pc;
    assign dbg_cva6_exception_valid =
        wally.gen_cva6_cores[0].i_core_cva6.ex_commit.valid;
    assign dbg_cva6_exception_cause =
        wally.gen_cva6_cores[0].i_core_cva6.ex_commit.cause;
    assign dbg_cva6_exception_tval =
        wally.gen_cva6_cores[0].i_core_cva6.ex_commit.tval;
    assign dbg_cva6_flush_commit =
        wally.gen_cva6_cores[0].i_core_cva6.flush_commit;
    assign dbg_cva6_pc_id_ex =
        wally.gen_cva6_cores[0].i_core_cva6.pc_id_ex;
    assign dbg_cva6_orig_instr_id_issue =
        wally.gen_cva6_cores[0].i_core_cva6.orig_instr_id_issue;

    //FIXME: These are WB cache dependent
    // assign dbg_cva6_miss_handler_state =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.state_q;
    // assign dbg_cva6_cache_busy =
    //     wally.gen_cva6_cores[0].i_core_cva6.busy_cache_ctrl;

    // assign dbg_cva6_amo_bypass_req =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_req.req;
    // assign dbg_cva6_amo_bypass_op =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_req.amo;
    // assign dbg_cva6_amo_bypass_size =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_req.size;
    // assign dbg_cva6_amo_bypass_addr =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_req.addr;
    // assign dbg_cva6_amo_bypass_wdata =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_req.wdata;
    // assign dbg_cva6_amo_bypass_be =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_req.be;
    // assign dbg_cva6_amo_bypass_we =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_req.we;
    // assign dbg_cva6_amo_bypass_gnt =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_rsp.gnt;
    // assign dbg_cva6_amo_bypass_valid =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_rsp.valid;
    // assign dbg_cva6_amo_bypass_rdata =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.amo_bypass_rsp.rdata;

    // assign dbg_cva6_bypass_axi_arvalid =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_req_o.ar_valid;
    // assign dbg_cva6_bypass_axi_arready =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_resp_i.ar_ready;
    // assign dbg_cva6_bypass_axi_araddr =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_req_o.ar.addr;
    // assign dbg_cva6_bypass_axi_arsize =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_req_o.ar.size;
    // assign dbg_cva6_bypass_axi_arid =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_req_o.ar.id;
    // assign dbg_cva6_bypass_axi_awvalid =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_req_o.aw_valid;
    // assign dbg_cva6_bypass_axi_awatop =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_req_o.aw.atop;
    // assign dbg_cva6_bypass_axi_wvalid =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_req_o.w_valid;
    // assign dbg_cva6_bypass_axi_bvalid =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_resp_i.b_valid;
    // assign dbg_cva6_bypass_axi_rvalid =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_resp_i.r_valid;
    // assign dbg_cva6_bypass_axi_rready =
    //     wally.gen_cva6_cores[0].i_core_cva6.gen_cache_wb.i_cache_subsystem.i_nbdcache.i_miss_handler.i_bypass_axi_adapter.axi_req_o.r_ready;

  end


  if (P.CLINT_SUPPORTED) begin : gen_clint
    axi_demux #(
        .AxiIdWidth(AXI_ID_W),
        .AxiLookBits(AXI_ID_W),
        .AtopSupport(C.bus.AtopsEnabled),
        .aw_chan_t(cpu_int_aw_chan_t),
        .w_chan_t(cpu_int_w_chan_t),
        .b_chan_t(cpu_int_b_chan_t),
        .ar_chan_t(cpu_int_ar_chan_t),
        .r_chan_t(cpu_int_r_chan_t),
        .axi_req_t(cpu_int_req_t),
        .axi_resp_t(cpu_int_resp_t),
        .NoMstPorts(2),
        // value > 2 needed for CVA6, to prevent serialization from limiting throughput
        .MaxTrans(8)
    ) demux (
        .clk_i, .rst_ni, .test_i(1'b0), .slv_req_i(wally_req),
        .slv_aw_select_i(aw_clint ? 1'b0 : 1'b1),
        .slv_ar_select_i(ar_clint ? 1'b0 : 1'b1),
        .slv_resp_o(wally_resp),
        .mst_reqs_o(demux_req),
        .mst_resps_i(demux_resp) );

    assign axi_req_o     = demux_req[1];
    assign demux_resp[1] = axi_resp_i;


    // Fully register ONLY the CLINT branch.
    axi_cut #(
        .Bypass     (1'b0),
        .aw_chan_t  (cpu_int_aw_chan_t),
        .w_chan_t   (cpu_int_w_chan_t),
        .b_chan_t   (cpu_int_b_chan_t),
        .ar_chan_t  (cpu_int_ar_chan_t),
        .r_chan_t   (cpu_int_r_chan_t),
        .axi_req_t  (cpu_int_req_t),
        .axi_resp_t (cpu_int_resp_t)
    ) i_clint_axi_cut (
        .clk_i,
        .rst_ni,

        .slv_req_i  (demux_req[0]),
        .slv_resp_o (demux_resp[0]),

        .mst_req_o  (clint_axi_req_cut),
        .mst_resp_i (clint_axi_resp_cut)
    );


    axi_to_axi_lite #(
        .AxiAddrWidth    (32),
        .AxiDataWidth    (P.AHBW),
        .AxiIdWidth      (AXI_ID_W),
        .AxiUserWidth    (1),
        .AxiMaxWriteTxns (1),
        .AxiMaxReadTxns  (1),
        .full_req_t      (cpu_int_req_t),
        .full_resp_t     (cpu_int_resp_t),
        .lite_req_t      (clint_lite_req_t),
        .lite_resp_t     (clint_lite_resp_t)
    ) clint_to_lite (
        .clk_i,
        .rst_ni,
        .test_i(1'b0),

        .slv_req_i  (clint_axi_req_cut),
        .slv_resp_o (clint_axi_resp_cut),

        .mst_req_o  (lite_req),
        .mst_resp_i (lite_resp)
    );

    axi_lite_to_apb #(
        .NoApbSlaves(1),
        .NoRules(1),
        .AddrWidth(32),
        .DataWidth(P.AHBW),
        .PipelineRequest  (1'b1), // prevent combinational loop reported
        .PipelineResponse (1'b1), // prevent combinational loop reported
        .axi_lite_req_t(clint_lite_req_t),
        .axi_lite_resp_t(clint_lite_resp_t),
        .apb_req_t(clint_apb_req_t),
        .apb_resp_t(clint_apb_resp_t),
        .rule_t(rule_t)
    ) clint_to_apb (
        .clk_i,
        .rst_ni,
        .axi_lite_req_i(lite_req),
        .axi_lite_resp_o(lite_resp),
        .apb_req_o(apb_req),
        .apb_resp_i(apb_resp),
        .addr_map_i(CLINT_MAP) );

    clint_apb #(CLINT_P) clint (
      .PCLK(clk_i),
      .PRESETn(rst_ni),
      .PSEL(apb_req[0].psel),
      .PADDR(apb_req[0].paddr[15:0]),
      .PWDATA(apb_req[0].pwdata),
      .PSTRB(apb_req[0].pstrb),
      .PWRITE(apb_req[0].pwrite),
      .PENABLE(apb_req[0].penable),
      .PRDATA(apb_resp[0].prdata),
      .PREADY(apb_resp[0].pready),
      .MTIME(mtime),
      .MTimerInt(mtip),
      .MSwInt(msip)
    );
    assign apb_resp[0].pslverr = 1'b0;
  end else begin : gen_no_clint
    // No CLINT address range is present, so preserve the direct CPU-to-AXI path.
    assign axi_req_o  = wally_req;
    assign wally_resp = axi_resp_i;
    assign mtime      = '0;
    assign mtip       = 1'b0;
    assign msip       = 1'b0;
  end


endmodule
