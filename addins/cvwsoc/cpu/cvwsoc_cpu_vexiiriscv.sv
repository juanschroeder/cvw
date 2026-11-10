// CPU-only VexiiRiscv, configuration pinned by addins/cvwsoc/cpu/vexiiriscv/generate.sh.
// Three independent 64-bit AXI ports: fetch, cached LSU, uncached LSU.
// RVA executes in the noncoherent L1; there are no AXI ATOPs/exclusives.
`include "axi/typedef.svh"
module cvwsoc_cpu_vexiiriscv import cvw::*; #(
  parameter cvw_t P,
  parameter int unsigned AXI_ID_W = 2,
  parameter type axi_req_t = logic,
  parameter type axi_resp_t = logic
) (
  input logic clk_i, rst_ni,
  input logic [63:0] mtime_i,
  input logic mtip_i, msip_i, meip_i, seip_i,
  input logic external_stall_i,
  output axi_req_t axi_req_o,
  input axi_resp_t axi_resp_i
);
  typedef logic [31:0] addr_t;
  typedef logic [0:0] vex_id_t;
  typedef logic [2:0] mux_id_t;
  typedef logic [63:0] data_t;
  typedef logic [7:0] strb_t;
  typedef logic user_t;
  `AXI_TYPEDEF_ALL(vex_axi, addr_t, vex_id_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_ALL(mux_axi, addr_t, mux_id_t, data_t, strb_t, user_t)
  vex_axi_req_t [2:0] vex_req;
  vex_axi_resp_t [2:0] vex_resp;
  mux_axi_req_t mux_req;
  mux_axi_resp_t mux_resp;
  // Keep the same debug names as the other CPU wrappers.
  axi_req_t cpu_axi_req;
  axi_resp_t cpu_axi_resp;
  logic [P.XLEN-1:0] dbg_pc, core_pc;
  logic [31:0] dbg_instr;
  logic dbg_retire, dbg_trap, dbg_interrupt;
  logic [4:0] dbg_cause;
  initial begin
    if ((P.XLEN != 32 && P.XLEN != 64) || P.AHBW != 64 || AXI_ID_W < 2)
      $fatal(1, "VexiiRiscv requires RV32 or RV64 with W64 and at least two AXI ID bits");
    if (P.RESET_VECTOR != 64'h1000)
      $fatal(1, "Regenerate VexiiRiscv for the selected reset vector");
  end
  logic  p1_aw_valid;
  logic [31:0] p1_aw_addr;
  logic [7:0] p1_aw_len;
  logic [2:0] p1_aw_size;
  logic [1:0] p1_aw_burst;
  logic [3:0] p1_aw_cache;
  logic [2:0] p1_aw_prot;
  logic  p1_w_valid;
  logic [63:0] p1_w_data;
  logic [7:0] p1_w_strb;
  logic  p1_w_last;
  logic  p1_b_ready;
  logic  p1_ar_valid;
  logic [31:0] p1_ar_addr;
  logic [7:0] p1_ar_len;
  logic [2:0] p1_ar_size;
  logic [1:0] p1_ar_burst;
  logic [3:0] p1_ar_cache;
  logic [2:0] p1_ar_prot;
  logic  p1_r_ready;
  logic  p0_ar_valid;
  logic [31:0] p0_ar_addr;
  logic [7:0] p0_ar_len;
  logic [2:0] p0_ar_size;
  logic [1:0] p0_ar_burst;
  logic [3:0] p0_ar_cache;
  logic [2:0] p0_ar_prot;
  logic  p0_r_ready;
  logic  p2_aw_valid;
  logic [31:0] p2_aw_addr;
  logic [2:0] p2_aw_size;
  logic [3:0] p2_aw_cache;
  logic [2:0] p2_aw_prot;
  logic  p2_w_valid;
  logic [63:0] p2_w_data;
  logic [7:0] p2_w_strb;
  logic  p2_w_last;
  logic  p2_b_ready;
  logic  p2_ar_valid;
  logic [31:0] p2_ar_addr;
  logic [2:0] p2_ar_size;
  logic [3:0] p2_ar_cache;
  logic [2:0] p2_ar_prot;
  logic  p2_r_ready;

  // Both generated variants have identical AXI/control ports. Keep one
  // connection list; unused whitebox outputs are intentionally unconnected.
  `define CVWSOC_VEXII_PORTS \
    .LsuL1Axi4Plugin_logic_axi_aw_valid(p1_aw_valid), \
    .LsuL1Axi4Plugin_logic_axi_aw_ready(vex_resp[1].aw_ready), \
    .LsuL1Axi4Plugin_logic_axi_aw_payload_addr(p1_aw_addr), \
    .LsuL1Axi4Plugin_logic_axi_aw_payload_len(p1_aw_len), \
    .LsuL1Axi4Plugin_logic_axi_aw_payload_size(p1_aw_size), \
    .LsuL1Axi4Plugin_logic_axi_aw_payload_burst(p1_aw_burst), \
    .LsuL1Axi4Plugin_logic_axi_aw_payload_cache(p1_aw_cache), \
    .LsuL1Axi4Plugin_logic_axi_aw_payload_prot(p1_aw_prot), \
    .LsuL1Axi4Plugin_logic_axi_w_valid(p1_w_valid), \
    .LsuL1Axi4Plugin_logic_axi_w_ready(vex_resp[1].w_ready), \
    .LsuL1Axi4Plugin_logic_axi_w_payload_data(p1_w_data), \
    .LsuL1Axi4Plugin_logic_axi_w_payload_strb(p1_w_strb), \
    .LsuL1Axi4Plugin_logic_axi_w_payload_last(p1_w_last), \
    .LsuL1Axi4Plugin_logic_axi_b_valid(vex_resp[1].b_valid), \
    .LsuL1Axi4Plugin_logic_axi_b_ready(p1_b_ready), \
    .LsuL1Axi4Plugin_logic_axi_b_payload_resp(vex_resp[1].b.resp), \
    .LsuL1Axi4Plugin_logic_axi_ar_valid(p1_ar_valid), \
    .LsuL1Axi4Plugin_logic_axi_ar_ready(vex_resp[1].ar_ready), \
    .LsuL1Axi4Plugin_logic_axi_ar_payload_addr(p1_ar_addr), \
    .LsuL1Axi4Plugin_logic_axi_ar_payload_len(p1_ar_len), \
    .LsuL1Axi4Plugin_logic_axi_ar_payload_size(p1_ar_size), \
    .LsuL1Axi4Plugin_logic_axi_ar_payload_burst(p1_ar_burst), \
    .LsuL1Axi4Plugin_logic_axi_ar_payload_cache(p1_ar_cache), \
    .LsuL1Axi4Plugin_logic_axi_ar_payload_prot(p1_ar_prot), \
    .LsuL1Axi4Plugin_logic_axi_r_valid(vex_resp[1].r_valid), \
    .LsuL1Axi4Plugin_logic_axi_r_ready(p1_r_ready), \
    .LsuL1Axi4Plugin_logic_axi_r_payload_data(vex_resp[1].r.data), \
    .LsuL1Axi4Plugin_logic_axi_r_payload_resp(vex_resp[1].r.resp), \
    .LsuL1Axi4Plugin_logic_axi_r_payload_last(vex_resp[1].r.last), \
    .PrivilegedPlugin_logic_rdtime(mtime_i), \
    .PrivilegedPlugin_logic_harts_0_int_m_timer(mtip_i), \
    .PrivilegedPlugin_logic_harts_0_int_m_software(msip_i), \
    .PrivilegedPlugin_logic_harts_0_int_m_external(meip_i), \
    .PrivilegedPlugin_logic_harts_0_int_s_external(seip_i), \
    .FetchL1Axi4Plugin_logic_axi_ar_valid(p0_ar_valid), \
    .FetchL1Axi4Plugin_logic_axi_ar_ready(vex_resp[0].ar_ready), \
    .FetchL1Axi4Plugin_logic_axi_ar_payload_addr(p0_ar_addr), \
    .FetchL1Axi4Plugin_logic_axi_ar_payload_len(p0_ar_len), \
    .FetchL1Axi4Plugin_logic_axi_ar_payload_size(p0_ar_size), \
    .FetchL1Axi4Plugin_logic_axi_ar_payload_burst(p0_ar_burst), \
    .FetchL1Axi4Plugin_logic_axi_ar_payload_cache(p0_ar_cache), \
    .FetchL1Axi4Plugin_logic_axi_ar_payload_prot(p0_ar_prot), \
    .FetchL1Axi4Plugin_logic_axi_r_valid(vex_resp[0].r_valid), \
    .FetchL1Axi4Plugin_logic_axi_r_ready(p0_r_ready), \
    .FetchL1Axi4Plugin_logic_axi_r_payload_data(vex_resp[0].r.data), \
    .FetchL1Axi4Plugin_logic_axi_r_payload_resp(vex_resp[0].r.resp), \
    .FetchL1Axi4Plugin_logic_axi_r_payload_last(vex_resp[0].r.last), \
    .LsuCachelessAxi4Plugin_logic_axi_aw_valid(p2_aw_valid), \
    .LsuCachelessAxi4Plugin_logic_axi_aw_ready(vex_resp[2].aw_ready), \
    .LsuCachelessAxi4Plugin_logic_axi_aw_payload_addr(p2_aw_addr), \
    .LsuCachelessAxi4Plugin_logic_axi_aw_payload_size(p2_aw_size), \
    .LsuCachelessAxi4Plugin_logic_axi_aw_payload_cache(p2_aw_cache), \
    .LsuCachelessAxi4Plugin_logic_axi_aw_payload_prot(p2_aw_prot), \
    .LsuCachelessAxi4Plugin_logic_axi_w_valid(p2_w_valid), \
    .LsuCachelessAxi4Plugin_logic_axi_w_ready(vex_resp[2].w_ready), \
    .LsuCachelessAxi4Plugin_logic_axi_w_payload_data(p2_w_data), \
    .LsuCachelessAxi4Plugin_logic_axi_w_payload_strb(p2_w_strb), \
    .LsuCachelessAxi4Plugin_logic_axi_w_payload_last(p2_w_last), \
    .LsuCachelessAxi4Plugin_logic_axi_b_valid(vex_resp[2].b_valid), \
    .LsuCachelessAxi4Plugin_logic_axi_b_ready(p2_b_ready), \
    .LsuCachelessAxi4Plugin_logic_axi_b_payload_resp(vex_resp[2].b.resp), \
    .LsuCachelessAxi4Plugin_logic_axi_ar_valid(p2_ar_valid), \
    .LsuCachelessAxi4Plugin_logic_axi_ar_ready(vex_resp[2].ar_ready), \
    .LsuCachelessAxi4Plugin_logic_axi_ar_payload_addr(p2_ar_addr), \
    .LsuCachelessAxi4Plugin_logic_axi_ar_payload_size(p2_ar_size), \
    .LsuCachelessAxi4Plugin_logic_axi_ar_payload_cache(p2_ar_cache), \
    .LsuCachelessAxi4Plugin_logic_axi_ar_payload_prot(p2_ar_prot), \
    .LsuCachelessAxi4Plugin_logic_axi_r_valid(vex_resp[2].r_valid), \
    .LsuCachelessAxi4Plugin_logic_axi_r_ready(p2_r_ready), \
    .LsuCachelessAxi4Plugin_logic_axi_r_payload_data(vex_resp[2].r.data), \
    .LsuCachelessAxi4Plugin_logic_axi_r_payload_resp(vex_resp[2].r.resp), \
    .LsuCachelessAxi4Plugin_logic_axi_r_payload_last(vex_resp[2].r.last), \
    .WhiteboxerPlugin_logic_fetchs_0_fire(), \
    .WhiteboxerPlugin_logic_fetchs_0_fetchId(), \
    .WhiteboxerPlugin_logic_fetchs_1_fire(), \
    .WhiteboxerPlugin_logic_fetchs_1_fetchId(), \
    .WhiteboxerPlugin_logic_fetchs_2_fire(), \
    .WhiteboxerPlugin_logic_fetchs_2_fetchId(), \
    .WhiteboxerPlugin_logic_decodes_0_fire(), \
    .WhiteboxerPlugin_logic_decodes_0_spawn(), \
    .WhiteboxerPlugin_logic_decodes_0_pc(), \
    .WhiteboxerPlugin_logic_decodes_0_fetchId(), \
    .WhiteboxerPlugin_logic_decodes_0_decodeId(), \
    .WhiteboxerPlugin_logic_decodes_1_fire(), \
    .WhiteboxerPlugin_logic_decodes_1_spawn(), \
    .WhiteboxerPlugin_logic_decodes_1_pc(), \
    .WhiteboxerPlugin_logic_decodes_1_fetchId(), \
    .WhiteboxerPlugin_logic_decodes_1_decodeId(), \
    .WhiteboxerPlugin_logic_serializeds_0_fire(), \
    .WhiteboxerPlugin_logic_serializeds_0_decodeId(), \
    .WhiteboxerPlugin_logic_serializeds_0_microOpId(), \
    .WhiteboxerPlugin_logic_serializeds_0_microOp(), \
    .WhiteboxerPlugin_logic_dispatches_0_fire(), \
    .WhiteboxerPlugin_logic_dispatches_0_microOpId(), \
    .WhiteboxerPlugin_logic_executes_0_fire(), \
    .WhiteboxerPlugin_logic_executes_0_microOpId(), \
    .WhiteboxerPlugin_logic_executes_1_fire(), \
    .WhiteboxerPlugin_logic_executes_1_microOpId(), \
    .WhiteboxerPlugin_logic_executes_2_fire(), \
    .WhiteboxerPlugin_logic_executes_2_microOpId(), \
    .WhiteboxerPlugin_logic_executes_3_fire(), \
    .WhiteboxerPlugin_logic_executes_3_microOpId(), \
    .WhiteboxerPlugin_logic_executes_4_fire(), \
    .WhiteboxerPlugin_logic_executes_4_microOpId(), \
    .WhiteboxerPlugin_logic_executes_5_fire(), \
    .WhiteboxerPlugin_logic_executes_5_microOpId(), \
    .WhiteboxerPlugin_logic_executes_6_fire(), \
    .WhiteboxerPlugin_logic_executes_6_microOpId(), \
    .WhiteboxerPlugin_logic_executes_7_fire(), \
    .WhiteboxerPlugin_logic_executes_7_microOpId(), \
    .WhiteboxerPlugin_logic_executes_8_fire(), \
    .WhiteboxerPlugin_logic_executes_8_microOpId(), \
    .WhiteboxerPlugin_logic_executes_9_fire(), \
    .WhiteboxerPlugin_logic_executes_9_microOpId(), \
    .WhiteboxerPlugin_logic_executes_10_fire(), \
    .WhiteboxerPlugin_logic_executes_10_microOpId(), \
    .WhiteboxerPlugin_logic_csr_port_valid(), \
    .WhiteboxerPlugin_logic_csr_port_payload_uopId(), \
    .WhiteboxerPlugin_logic_csr_port_payload_address(), \
    .WhiteboxerPlugin_logic_csr_port_payload_write(), \
    .WhiteboxerPlugin_logic_csr_port_payload_read(), \
    .WhiteboxerPlugin_logic_csr_port_payload_writeDone(), \
    .WhiteboxerPlugin_logic_csr_port_payload_readDone(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_0_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_0_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_0_payload_data(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_1_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_1_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_1_payload_data(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_2_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_2_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_2_payload_data(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_3_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_3_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_3_payload_data(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_4_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_4_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_4_payload_data(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_5_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_5_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_5_payload_data(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_6_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_6_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_6_payload_data(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_7_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_7_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_7_payload_data(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_8_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_8_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_8_payload_data(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_9_valid(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_9_payload_uopId(), \
    .WhiteboxerPlugin_logic_rfWrites_ports_9_payload_data(), \
    .WhiteboxerPlugin_logic_completions_ports_0_valid(), \
    .WhiteboxerPlugin_logic_completions_ports_0_payload_uopId(), \
    .WhiteboxerPlugin_logic_completions_ports_0_payload_trap(), \
    .WhiteboxerPlugin_logic_completions_ports_0_payload_commit(), \
    .WhiteboxerPlugin_logic_completions_ports_1_valid(), \
    .WhiteboxerPlugin_logic_completions_ports_1_payload_uopId(), \
    .WhiteboxerPlugin_logic_completions_ports_1_payload_trap(), \
    .WhiteboxerPlugin_logic_completions_ports_1_payload_commit(), \
    .WhiteboxerPlugin_logic_completions_ports_2_valid(), \
    .WhiteboxerPlugin_logic_completions_ports_2_payload_uopId(), \
    .WhiteboxerPlugin_logic_completions_ports_2_payload_trap(), \
    .WhiteboxerPlugin_logic_completions_ports_2_payload_commit(), \
    .WhiteboxerPlugin_logic_completions_ports_3_valid(), \
    .WhiteboxerPlugin_logic_completions_ports_3_payload_uopId(), \
    .WhiteboxerPlugin_logic_completions_ports_3_payload_trap(), \
    .WhiteboxerPlugin_logic_completions_ports_3_payload_commit(), \
    .WhiteboxerPlugin_logic_completions_ports_4_valid(), \
    .WhiteboxerPlugin_logic_completions_ports_4_payload_uopId(), \
    .WhiteboxerPlugin_logic_completions_ports_4_payload_trap(), \
    .WhiteboxerPlugin_logic_completions_ports_4_payload_commit(), \
    .WhiteboxerPlugin_logic_completions_ports_5_valid(), \
    .WhiteboxerPlugin_logic_completions_ports_5_payload_uopId(), \
    .WhiteboxerPlugin_logic_completions_ports_5_payload_trap(), \
    .WhiteboxerPlugin_logic_completions_ports_5_payload_commit(), \
    .WhiteboxerPlugin_logic_completions_ports_6_valid(), \
    .WhiteboxerPlugin_logic_completions_ports_6_payload_uopId(), \
    .WhiteboxerPlugin_logic_completions_ports_6_payload_trap(), \
    .WhiteboxerPlugin_logic_completions_ports_6_payload_commit(), \
    .WhiteboxerPlugin_logic_completions_ports_7_valid(), \
    .WhiteboxerPlugin_logic_completions_ports_7_payload_uopId(), \
    .WhiteboxerPlugin_logic_completions_ports_7_payload_trap(), \
    .WhiteboxerPlugin_logic_completions_ports_7_payload_commit(), \
    .WhiteboxerPlugin_logic_commits_ports_0_valid(dbg_retire), \
    .WhiteboxerPlugin_logic_commits_ports_0_pc(core_pc), \
    .WhiteboxerPlugin_logic_commits_ports_0_uop(dbg_instr), \
    .WhiteboxerPlugin_logic_reschedules_flushes_0_valid(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_0_payload_self(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_1_valid(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_1_payload_uopId(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_1_payload_self(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_2_valid(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_2_payload_uopId(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_2_payload_self(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_3_valid(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_3_payload_uopId(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_3_payload_self(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_4_valid(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_4_payload_uopId(), \
    .WhiteboxerPlugin_logic_reschedules_flushes_4_payload_self(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_valid(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_payload_pcOnLastSlice(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_payload_pcTarget(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_payload_taken(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_payload_isBranch(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_payload_isPush(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_payload_isPop(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_payload_wasWrong(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_payload_badPredictedTarget(), \
    .WhiteboxerPlugin_logic_prediction_learns_0_payload_uopId(), \
    .WhiteboxerPlugin_logic_wfi(), \
    .WhiteboxerPlugin_logic_perf_executeFreezed(), \
    .WhiteboxerPlugin_logic_perf_dispatchHazards(), \
    .WhiteboxerPlugin_logic_perf_candidatesCount(), \
    .WhiteboxerPlugin_logic_perf_executeFreezedCounter(), \
    .WhiteboxerPlugin_logic_perf_dispatchHazardsCounter(), \
    .WhiteboxerPlugin_logic_perf_candidatesCountCounters_0(), \
    .WhiteboxerPlugin_logic_perf_candidatesCountCounters_1(), \
    .WhiteboxerPlugin_logic_perf_dispatchFeedCounters_0(), \
    .WhiteboxerPlugin_logic_perf_dispatchFeedCounters_1(), \
    .WhiteboxerPlugin_logic_trap_ports_0_valid(dbg_trap), \
    .WhiteboxerPlugin_logic_trap_ports_0_interrupt(dbg_interrupt), \
    .WhiteboxerPlugin_logic_trap_ports_0_cause(dbg_cause), \
    .clk(clk_i), \
    .reset(~rst_ni)

  if (P.XLEN == 64) begin : gen_rv64
    VexiiRiscv64 core (`CVWSOC_VEXII_PORTS);
    // Upstream whitebox zero-extends its internal 40-bit PC to XLEN.
    // Expose canonical Sv39 addresses to the existing trace/testbench probes.
    assign dbg_pc = {{25{core_pc[38]}}, core_pc[38:0]};
  end else begin : gen_rv32
    VexiiRiscv core (`CVWSOC_VEXII_PORTS);
    assign dbg_pc = core_pc;
  end
  `undef CVWSOC_VEXII_PORTS

  always_comb begin
    vex_req = '0;
    // No generated port has an ID (one transaction per native master).
    // AXI mux adds source identity; remap retains it on the two-bit SoC port.
    // Uncached AXI omits AxLEN/AxBURST: single-beat INCR, preserving AxSIZE.
    vex_req[2].aw.burst = axi_pkg::BURST_INCR;
    vex_req[2].ar.burst = axi_pkg::BURST_INCR;
    vex_req[1].aw_valid = p1_aw_valid;
    vex_req[1].aw.addr = p1_aw_addr;
    vex_req[1].aw.len = p1_aw_len;
    vex_req[1].aw.size = p1_aw_size;
    vex_req[1].aw.burst = p1_aw_burst;
    vex_req[1].aw.cache = p1_aw_cache;
    vex_req[1].aw.prot = p1_aw_prot;
    vex_req[1].w_valid = p1_w_valid;
    vex_req[1].w.data = p1_w_data;
    vex_req[1].w.strb = p1_w_strb;
    vex_req[1].w.last = p1_w_last;
    vex_req[1].b_ready = p1_b_ready;
    vex_req[1].ar_valid = p1_ar_valid;
    vex_req[1].ar.addr = p1_ar_addr;
    vex_req[1].ar.len = p1_ar_len;
    vex_req[1].ar.size = p1_ar_size;
    vex_req[1].ar.burst = p1_ar_burst;
    vex_req[1].ar.cache = p1_ar_cache;
    vex_req[1].ar.prot = p1_ar_prot;
    vex_req[1].r_ready = p1_r_ready;
    vex_req[0].ar_valid = p0_ar_valid;
    vex_req[0].ar.addr = p0_ar_addr;
    vex_req[0].ar.len = p0_ar_len;
    vex_req[0].ar.size = p0_ar_size;
    vex_req[0].ar.burst = p0_ar_burst;
    vex_req[0].ar.cache = p0_ar_cache;
    vex_req[0].ar.prot = p0_ar_prot;
    vex_req[0].r_ready = p0_r_ready;
    vex_req[2].aw_valid = p2_aw_valid;
    vex_req[2].aw.addr = p2_aw_addr;
    vex_req[2].aw.size = p2_aw_size;
    vex_req[2].aw.cache = p2_aw_cache;
    vex_req[2].aw.prot = p2_aw_prot;
    vex_req[2].w_valid = p2_w_valid;
    vex_req[2].w.data = p2_w_data;
    vex_req[2].w.strb = p2_w_strb;
    vex_req[2].w.last = p2_w_last;
    vex_req[2].b_ready = p2_b_ready;
    vex_req[2].ar_valid = p2_ar_valid;
    vex_req[2].ar.addr = p2_ar_addr;
    vex_req[2].ar.size = p2_ar_size;
    vex_req[2].ar.cache = p2_ar_cache;
    vex_req[2].ar.prot = p2_ar_prot;
    vex_req[2].r_ready = p2_r_ready;
  end
  axi_mux #(
    .SlvAxiIDWidth(1), .NoSlvPorts(3), .MaxWTrans(8),
    .slv_aw_chan_t(vex_axi_aw_chan_t), .mst_aw_chan_t(mux_axi_aw_chan_t),
    .w_chan_t(vex_axi_w_chan_t),
    .slv_b_chan_t(vex_axi_b_chan_t), .mst_b_chan_t(mux_axi_b_chan_t),
    .slv_ar_chan_t(vex_axi_ar_chan_t), .mst_ar_chan_t(mux_axi_ar_chan_t),
    .slv_r_chan_t(vex_axi_r_chan_t), .mst_r_chan_t(mux_axi_r_chan_t),
    .slv_req_t(vex_axi_req_t), .slv_resp_t(vex_axi_resp_t),
    .mst_req_t(mux_axi_req_t), .mst_resp_t(mux_axi_resp_t)
  ) axi_ports_mux (
    .clk_i, .rst_ni, .test_i(1'b0),
    .slv_reqs_i(vex_req), .slv_resps_o(vex_resp),
    .mst_req_o(mux_req), .mst_resp_i(mux_resp)
  );
  axi_id_remap #(
    .AxiSlvPortIdWidth(3), .AxiSlvPortMaxUniqIds(3), .AxiMaxTxnsPerId(8),
    .AxiMstPortIdWidth(AXI_ID_W),
    .slv_req_t(mux_axi_req_t), .slv_resp_t(mux_axi_resp_t),
    .mst_req_t(axi_req_t), .mst_resp_t(axi_resp_t)
  ) id_remap (
    .clk_i, .rst_ni, .slv_req_i(mux_req), .slv_resp_o(mux_resp),
    .mst_req_o(cpu_axi_req), .mst_resp_i(cpu_axi_resp)
  );
  assign axi_req_o = cpu_axi_req;
  assign cpu_axi_resp = axi_resp_i;

  // Opt-in, bounded by the testbench MAX_CYCLES. No waveforms required.
`ifndef SYNTHESIS
  bit trace_retire, trace_axi;
  longint unsigned debug_cycle = 0;
  longint unsigned trace_from = 0, trace_to = 64'hffffffffffffffff;
  initial begin
    void'($value$plusargs("VEXII_TRACE_FROM=%d", trace_from));
    void'($value$plusargs("VEXII_TRACE_TO=%d", trace_to));
    trace_retire = $test$plusargs("VEXII_TRACE");
    trace_axi = $test$plusargs("VEXII_AXI_TRACE");
  end
  always @(posedge clk_i) begin
    debug_cycle <= debug_cycle + 1;
    if (rst_ni && debug_cycle >= trace_from && debug_cycle <= trace_to) begin
      if (trace_retire && dbg_retire)
        $display("VEXII retire pc=%08x insn=%08x", dbg_pc, dbg_instr);
      if (trace_retire && dbg_trap)
        $display("VEXII trap irq=%b cause=%d", dbg_interrupt, dbg_cause);
      if (trace_axi && cpu_axi_req.ar_valid && cpu_axi_resp.ar_ready)
        $display("VEXII AR addr=%08x size=%d len=%d id=%d", cpu_axi_req.ar.addr, cpu_axi_req.ar.size, cpu_axi_req.ar.len, cpu_axi_req.ar.id);
      if (trace_axi && cpu_axi_req.aw_valid && cpu_axi_resp.aw_ready)
        $display("VEXII AW addr=%08x size=%d len=%d id=%d", cpu_axi_req.aw.addr, cpu_axi_req.aw.size, cpu_axi_req.aw.len, cpu_axi_req.aw.id);
    end
  end
`endif
endmodule
