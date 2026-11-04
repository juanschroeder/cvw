// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Shared, statically configured PULP/Cheshire last-level cache.
`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "axi_llc/typedef.svh"

module cvwsoc_llc #(
  parameter cvw::cvw_t P,
  parameter int unsigned AxiIdWidth = 2,
  parameter type axi_req_t = logic,
  parameter type axi_resp_t = logic
) (
  input logic clk_i,
  input logic rst_ni,
  input axi_req_t slv_req_i,
  output axi_resp_t slv_resp_o,
  output axi_req_t mst_req_o,
  input axi_resp_t mst_resp_i
);
  localparam int unsigned Ways = P.LLC_NUM_WAYS;
  localparam int unsigned Lines = P.LLC_NUM_LINES;
  localparam int unsigned Blocks = P.LLC_NUM_BLOCKS;
  localparam int unsigned LineBytes = Blocks * P.AHBW / 8;
  localparam longint unsigned CapacityBytes = 64'(Ways) * Lines * LineBytes;
  // the LLC range excludes cacheability of a subrange of EXT_MEM_RANGE.
  // REMARK: not really used for LLC for now.
  localparam logic [63:0] CacheEnd = P.EXT_MEM_BASE + P.EXT_MEM_RANGE + 64'd1;
  localparam logic [63:0] BypassStart = P.UNCACHED_MEM_SUPPORTED ?
      P.UNCACHED_MEM_BASE : 64'd0;
  localparam logic [63:0] BypassEnd = P.UNCACHED_MEM_SUPPORTED ?
      P.UNCACHED_MEM_BASE + P.UNCACHED_MEM_RANGE + 64'd1 : 64'd0;
  typedef logic [31:0] addr_t;
  typedef logic [P.AHBW-1:0] data_t;
  typedef logic [P.AHBW/8-1:0] strb_t;
  // Upstream uses four low ID bits in its per-ID miss counters. Pad narrow
  // fabrics before entering LLC rather than selecting beyond their ID width.
  localparam int unsigned CacheIdWidth = AxiIdWidth > axi_llc_pkg::UseIdBits ?
                                         AxiIdWidth : axi_llc_pkg::UseIdBits;
  typedef logic [CacheIdWidth:0] llc_id_t;
  typedef logic [CacheIdWidth-1:0] slv_id_t;
  typedef logic user_t;
  typedef logic [Ways-1:0] way_t;
  `AXI_TYPEDEF_ALL(slv, addr_t, slv_id_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_ALL(llc, addr_t, llc_id_t, data_t, strb_t, user_t)
  `AXI_LLC_TYPEDEF_ALL(llc, logic [63:0], way_t)
  llc_req_t mem_req;
  llc_resp_t mem_resp;
  slv_req_t padded_req, serial_req, cut_req;
  slv_resp_t padded_resp, serial_resp, cut_resp;
  // Field-wise assignments preserve layout when ID widths differ.
  `AXI_ASSIGN_REQ_STRUCT(padded_req, slv_req_i)
  `AXI_ASSIGN_RESP_STRUCT(slv_resp_o, padded_resp)
  llc_cfg_regs_d_t config_status;
  axi_llc_pkg::events_t events;

  // The LLC can merge cached and bypass R beats from different IDs. The
  // CVA6 HPDcache refill interface assembles each burst in one data FIFO and
  // cannot consume interleaved bursts. Use a shared ordered ID at the LLC
  // input, retaining original IDs in PULP's serializer response FIFOs. Multiple
  // bursts may remain outstanding, but AXI ordering keeps their beats together.
  // Atomics have already been resolved by the upstream DDR adapter.
  axi_serializer #(
    .MaxReadTxns(axi_llc_pkg::MaxTrans),
    .MaxWriteTxns(axi_llc_pkg::MaxTrans),
    .AxiIdWidth(CacheIdWidth), .axi_req_t(slv_req_t), .axi_resp_t(slv_resp_t)
  ) i_burst_order (
    .clk_i, .rst_ni,
    .slv_req_i(padded_req), .slv_resp_o(padded_resp),
    .mst_req_o(serial_req), .mst_resp_i(serial_resp)
  );

  // Cut the atomic-adapter/cache combinational path, as in Cheshire.
  axi_cut #(
    .aw_chan_t(slv_aw_chan_t), .w_chan_t(slv_w_chan_t),
    .b_chan_t(slv_b_chan_t), .ar_chan_t(slv_ar_chan_t),
    .r_chan_t(slv_r_chan_t), .axi_req_t(slv_req_t), .axi_resp_t(slv_resp_t)
  ) i_cut (
    .clk_i, .rst_ni, .slv_req_i(serial_req), .slv_resp_o(serial_resp),
    .mst_req_o(cut_req), .mst_resp_i(cut_resp)
  );

  // All ways start as cache. The LLC automatically initializes/tests its tag
  // SRAMs after reset and stalls requests until ready. No firmware init needed.
  // Static configuration: no SPM, software flush or runtime reconfiguration.
  axi_llc_top #(
    .SetAssociativity(Ways), .NumLines(Lines), .NumBlocks(Blocks),
    .AxiIdWidth(CacheIdWidth), .AxiAddrWidth(32), .AxiDataWidth(P.AHBW),
    .AxiUserWidth(1), .RegWidth(64),
    // Bypass for uncached region disabled for now (not needed in principle).
    //.BypassStartAddr(addr_t'(BypassStart)), .BypassEndAddr(addr_t'(BypassEnd)),
    .conf_regs_d_t(llc_cfg_regs_d_t), .conf_regs_q_t(llc_cfg_regs_q_t),
    .slv_req_t(slv_req_t), .slv_resp_t(slv_resp_t),
    .mst_req_t(llc_req_t), .mst_resp_t(llc_resp_t),
    .rule_full_t(axi_pkg::xbar_rule_32_t)
  ) i_cache (
    .clk_i, .rst_ni, .test_i(1'b0),
    .slv_req_i(cut_req), .slv_resp_o(cut_resp),
    .mst_req_o(mem_req), .mst_resp_i(mem_resp),
    .conf_regs_i(llc_cfg_regs_q_t'('0)), .conf_regs_o(config_status),
    .cached_start_addr_i(addr_t'(P.EXT_MEM_BASE)),
    .cached_end_addr_i(addr_t'(CacheEnd)),
    // Unreachable from the DDR crossbar output; no SPM address-map rule.
    .spm_start_addr_i(32'h0),
    .axi_llc_events_o(events)
  );

  // LLC adds a bypass-source bit to IDs. Remap it, never truncate it: cache
  // refills/evictions and bypass traffic can be outstanding simultaneously.
  // Four unique IDs and sixteen bursts per ID suffice for this initial setup;
  // excess requests are backpressured by the reusable PULP adapter.
  axi_id_remap #(
    .AxiSlvPortIdWidth(CacheIdWidth+1), .AxiSlvPortMaxUniqIds(4),
    .AxiMaxTxnsPerId(16), .AxiMstPortIdWidth(AxiIdWidth),
    .slv_req_t(llc_req_t), .slv_resp_t(llc_resp_t),
    .mst_req_t(axi_req_t), .mst_resp_t(axi_resp_t)
  ) i_id_remap (
    .clk_i, .rst_ni, .slv_req_i(mem_req), .slv_resp_o(mem_resp),
    .mst_req_o, .mst_resp_i
  );

  initial begin
    // The upstream demux routes whole AXI bursts from their start address.
    // 4 KiB- and cache-line-aligned fences cannot be crossed by a legal AXI
    // burst or an LLC refill. Partial-line carveouts require a different adapter.
    if (P.UNCACHED_MEM_SUPPORTED) begin
      assert (BypassStart < BypassEnd && BypassEnd < 64'h1_0000_0000 &&
              BypassStart % 4096 == 0 && BypassEnd % 4096 == 0 &&
              BypassStart % 64'(LineBytes) == 0 && BypassEnd % 64'(LineBytes) == 0)
        else $fatal(1, "LLC bypass window must be nonempty, below 4 GiB, and 4 KiB/cache-line aligned");
    end
    assert (Ways >= 1 && Ways <= 63)
      else $fatal(1, "LLC ways must be in [1,63] for 64-bit upstream config registers");
    assert (Lines >= 2 && (Lines & (Lines-1)) == 0)
      else $fatal(1, "LLC lines must be a power of two >=2");
    assert (Blocks >= 2 && Blocks <= 256 && (Blocks & (Blocks-1)) == 0)
      else $fatal(1, "LLC blocks must be a power of two in [2,256] (AXI burst length)");
    assert (LineBytes <= 4096 && $clog2(Lines) + $clog2(LineBytes) < 32)
      else $fatal(1, "LLC requires positive tag width and lines no larger than AXI's 4 KiB boundary");
    assert ($bits(slv_req_i.aw.addr) == 32 && $bits(slv_req_i.ar.addr) == 32 &&
            $bits(mst_req_o.aw.addr) == 32 && $bits(mst_req_o.ar.addr) == 32)
      else $fatal(1, "CVWSoC LLC currently requires 32-bit AXI addresses");
    assert (P.AHBW == 32 || P.AHBW == 64)
      else $fatal(1, "LLC requires a 32- or 64-bit data bus");
    assert (AxiIdWidth >= 2) else $fatal(1, "LLC ID remapper requires >=2 ID bits");
    assert (P.EXT_MEM_SUPPORTED && P.EXT_MEM_BASE < CacheEnd && CacheEnd < 64'h1_0000_0000)
      else $fatal(1, "LLC requires a nonempty DDR cache window below 4 GiB");
    assert (P.EXT_MEM_BASE >= CapacityBytes)
      else $fatal(1, "LLC SPM placeholder must be outside DDR");
    assert ((P.EXT_MEM_BASE % 64'(LineBytes)) == 0 && (CacheEnd % 64'(LineBytes)) == 0)
      else $fatal(1, "LLC cache window must be line aligned");
  end
endmodule
