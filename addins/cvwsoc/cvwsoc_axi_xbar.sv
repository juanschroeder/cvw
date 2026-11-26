// Copyright (c) 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>
// - Andreas Kurth <akurth@iis.ee.ethz.ch>
// - Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// - Juan Carlos Schroeder<jcschroeder@gmail.com>

/// CVWSoC AXI4+ATOP crossbar based on PULP axi_xbar.
/// Keeps PULP's demuxes, DDR mux, pipeline cuts and error responders.
/// Only the CPU reaches peripherals, so those paths need no arbitration.
/// Other initiators go to DDR or an error responder. Passing the address map
/// as a parameter lets synthesis simplify range checks and drop unused rules.
module cvwsoc_axi_xbar
#(
  /// Configuration struct for the crossbar see `axi_pkg` for fields and definitions.
  parameter axi_pkg::xbar_cfg_t Cfg                                   = '0,
  /// Enable atomic operations support.
  parameter bit  ATOPs                                                = 1'b1,
  /// The CPU at input 0 reaches all targets. Other inputs reach only DDR.
  parameter bit [Cfg.NoSlvPorts-1:0][Cfg.NoMstPorts-1:0] Connectivity = '1,
  /// AXI4+ATOP AW channel struct type for the slave ports.
  parameter type slv_aw_chan_t                                        = logic,
  /// AXI4+ATOP AW channel struct type for the master ports.
  parameter type mst_aw_chan_t                                        = logic,
  /// AXI4+ATOP W channel struct type for all ports.
  parameter type w_chan_t                                             = logic,
  /// AXI4+ATOP B channel struct type for the slave ports.
  parameter type slv_b_chan_t                                         = logic,
  /// AXI4+ATOP B channel struct type for the master ports.
  parameter type mst_b_chan_t                                         = logic,
  /// AXI4+ATOP AR channel struct type for the slave ports.
  parameter type slv_ar_chan_t                                        = logic,
  /// AXI4+ATOP AR channel struct type for the master ports.
  parameter type mst_ar_chan_t                                        = logic,
  /// AXI4+ATOP R channel struct type for the slave ports.
  parameter type slv_r_chan_t                                         = logic,
  /// AXI4+ATOP R channel struct type for the master ports.
  parameter type mst_r_chan_t                                         = logic,
  /// AXI4+ATOP request struct type for the slave ports.
  parameter type slv_req_t                                            = logic,
  /// AXI4+ATOP response struct type for the slave ports.
  parameter type slv_resp_t                                           = logic,
  /// AXI4+ATOP request struct type for the master ports.
  parameter type mst_req_t                                            = logic,
  /// AXI4+ATOP response struct type for the master ports
  parameter type mst_resp_t                                           = logic,
  /// Address rule type for the address decoders from `common_cells:addr_decode`.
  /// Example types are provided in `axi_pkg`.
  /// Required struct fields:
  /// ```
  /// typedef struct packed {
  ///   int unsigned idx;
  ///   axi_addr_t   start_addr;
  ///   axi_addr_t   end_addr;
  /// } rule_t;
  /// ```
  parameter type rule_t                                               = axi_pkg::xbar_rule_64_t,
  /// Static address map. Higher-index rules take priority.
  parameter rule_t [Cfg.NoAddrRules-1:0] AddrMap                       = '0,
  localparam int unsigned MstPortsIdxWidth =
      cf_math_pkg::idx_width(Cfg.NoMstPorts)
) (
  /// Clock, positive edge triggered.
  input  logic                                                          clk_i,
  /// Asynchronous reset, active low.
  input  logic                                                          rst_ni,
  /// Testmode enable, active high.
  input  logic                                                          test_i,
  /// AXI4+ATOP requests to the slave ports.
  input  slv_req_t  [Cfg.NoSlvPorts-1:0]                                slv_ports_req_i,
  /// AXI4+ATOP responses of the slave ports.
  output slv_resp_t [Cfg.NoSlvPorts-1:0]                                slv_ports_resp_o,
  /// AXI4+ATOP requests of the master ports.
  output mst_req_t  [Cfg.NoMstPorts-1:0]                                mst_ports_req_o,
  /// AXI4+ATOP responses to the master ports.
  input  mst_resp_t [Cfg.NoMstPorts-1:0]                                mst_ports_resp_i,
  /// Enable default master port.
  input  logic      [Cfg.NoSlvPorts-1:0]                                en_default_mst_port_i,
  /// Enables a default master port for each slave port. When this is enabled unmapped
  /// transactions get issued at the master port given by `default_mst_port_i`.
  /// When not used, tie to `'0`.
  input  logic      [Cfg.NoSlvPorts-1:0][MstPortsIdxWidth-1:0]          default_mst_port_i
);

  localparam int unsigned CpuPort = 0;
  localparam int unsigned DdrPort = 0;


  // pragma translate_off
  initial begin : check_params
    if (Cfg.NoSlvPorts == 0 || Cfg.NoMstPorts == 0 || Cfg.NoAddrRules == 0)
      $fatal(1, "cvwsoc_axi_xbar requires at least one initiator, target and address rule");
    if (Connectivity[CpuPort] != '1)
      $fatal(1, "cvwsoc_axi_xbar requires initiator 0 (CPU) to reach all targets");
    for (int i = 1; i < Cfg.NoSlvPorts; i++) begin
      if (Connectivity[i] != Cfg.NoMstPorts'(1))
        $fatal(1, "cvwsoc_axi_xbar requires initiator %0d to reach only target 0 (DDR)", i);
    end
  end
  // pragma translate_on

  slv_req_t  [Cfg.NoMstPorts-1:0] cpu_reqs;
  slv_resp_t [Cfg.NoMstPorts-1:0] cpu_resps;
  slv_req_t  [Cfg.NoSlvPorts-1:0] ddr_reqs;
  slv_resp_t [Cfg.NoSlvPorts-1:0] ddr_resps;

  // PULP's fully connected CPU demux path uses the static address decoder.
  localparam int unsigned CpuSelectWidth = cf_math_pkg::idx_width(Cfg.NoMstPorts + 1);
  typedef logic [CpuSelectWidth-1:0] cpu_select_t;
  cpu_select_t cpu_aw_select, cpu_ar_select;
  slv_req_t  [Cfg.NoMstPorts:0] cpu_demux_reqs;
  slv_resp_t [Cfg.NoMstPorts:0] cpu_demux_resps;

  cvwsoc_cpu_addr_decode #(
    .AddrWidth (Cfg.AxiAddrWidth), .NoRules (Cfg.NoAddrRules),
    .NoTargets (Cfg.NoMstPorts), .rule_t (rule_t), .AddrMap (AddrMap)
  ) i_cpu_aw_decode (
    .addr_i           (slv_ports_req_i[CpuPort].aw.addr),
    .en_default_i     (en_default_mst_port_i[CpuPort]),
    .default_target_i (default_mst_port_i[CpuPort]),
    .select_o         (cpu_aw_select)
  );

  cvwsoc_cpu_addr_decode #(
    .AddrWidth (Cfg.AxiAddrWidth), .NoRules (Cfg.NoAddrRules),
    .NoTargets (Cfg.NoMstPorts), .rule_t (rule_t), .AddrMap (AddrMap)
  ) i_cpu_ar_decode (
    .addr_i           (slv_ports_req_i[CpuPort].ar.addr),
    .en_default_i     (en_default_mst_port_i[CpuPort]),
    .default_target_i (default_mst_port_i[CpuPort]),
    .select_o         (cpu_ar_select)
  );

  // pragma translate_off
  `ifndef VERILATOR
  `ifndef XSIM
  assert property (@(posedge clk_i) disable iff (!rst_ni)
      slv_ports_req_i[CpuPort].aw_valid && !slv_ports_resp_o[CpuPort].aw_ready |=>
      $stable({en_default_mst_port_i[CpuPort], default_mst_port_i[CpuPort]}));
  assert property (@(posedge clk_i) disable iff (!rst_ni)
      slv_ports_req_i[CpuPort].ar_valid && !slv_ports_resp_o[CpuPort].ar_ready |=>
      $stable({en_default_mst_port_i[CpuPort], default_mst_port_i[CpuPort]}));
  `endif
  `endif
  // pragma translate_on

  axi_demux #(
    .AxiIdWidth  (Cfg.AxiIdWidthSlvPorts),
    .AtopSupport (ATOPs),
    .aw_chan_t   (slv_aw_chan_t),
    .w_chan_t    (w_chan_t),
    .b_chan_t    (slv_b_chan_t),
    .ar_chan_t   (slv_ar_chan_t),
    .r_chan_t    (slv_r_chan_t),
    .axi_req_t   (slv_req_t),
    .axi_resp_t  (slv_resp_t),
    .NoMstPorts  (Cfg.NoMstPorts + 1),
    .MaxTrans    (Cfg.MaxMstTrans),
    .AxiLookBits (Cfg.AxiIdUsedSlvPorts),
    .UniqueIds   (Cfg.UniqueIds),
    .SpillAw     (Cfg.LatencyMode[9]),
    .SpillW      (Cfg.LatencyMode[8]),
    .SpillB      (Cfg.LatencyMode[7]),
    .SpillAr     (Cfg.LatencyMode[6]),
    .SpillR      (Cfg.LatencyMode[5])
  ) i_cpu_demux (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_req_i       (slv_ports_req_i[CpuPort]),
    .slv_aw_select_i (cpu_aw_select),
    .slv_ar_select_i (cpu_ar_select),
    .slv_resp_o      (slv_ports_resp_o[CpuPort]),
    .mst_reqs_o      (cpu_demux_reqs),
    .mst_resps_i     (cpu_demux_resps)
  );

  axi_err_slv #(
    .AxiIdWidth (Cfg.AxiIdWidthSlvPorts),
    .axi_req_t  (slv_req_t),
    .axi_resp_t (slv_resp_t),
    .Resp       (axi_pkg::RESP_DECERR),
    .ATOPs      (ATOPs),
    .MaxTrans   (4)
  ) i_cpu_error (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_req_i  (cpu_demux_reqs[Cfg.NoMstPorts]),
    .slv_resp_o (cpu_demux_resps[Cfg.NoMstPorts])
  );

  for (genvar j = 0; j < Cfg.NoMstPorts; j++) begin : gen_cpu_link
    axi_multicut #(
      .NoCuts     (Cfg.PipelineStages),
      .aw_chan_t  (slv_aw_chan_t),
      .w_chan_t   (w_chan_t),
      .b_chan_t   (slv_b_chan_t),
      .ar_chan_t  (slv_ar_chan_t),
      .r_chan_t   (slv_r_chan_t),
      .axi_req_t  (slv_req_t),
      .axi_resp_t (slv_resp_t)
    ) i_pipeline (
      .clk_i,
      .rst_ni,
      .slv_req_i  (cpu_demux_reqs[j]),
      .slv_resp_o (cpu_demux_resps[j]),
      .mst_req_o  (cpu_reqs[j]),
      .mst_resp_i (cpu_resps[j])
    );
  end

  assign ddr_reqs[CpuPort] = cpu_reqs[DdrPort];
  assign cpu_resps[DdrPort] = ddr_resps[CpuPort];

  if (Cfg.NoSlvPorts > 1) begin : gen_dma
    for (genvar i = 1; i < Cfg.NoSlvPorts; i++) begin : gen_initiator
      slv_req_t  [1:0] reqs;
      slv_resp_t [1:0] resps;
      logic aw_select, ar_select;
      logic default_is_error;

      assign default_is_error = !en_default_mst_port_i[i] ||
                                default_mst_port_i[i] != MstPortsIdxWidth'(DdrPort);

      cvwsoc_dma_addr_decode #(
        .AddrWidth (Cfg.AxiAddrWidth),
        .NoRules   (Cfg.NoAddrRules),
        .rule_t    (rule_t),
        .AddrMap   (AddrMap)
      ) i_aw_decode (
        .addr_i             (slv_ports_req_i[i].aw.addr),
        .default_is_error_i (default_is_error),
        .select_error_o     (aw_select)
      );

      cvwsoc_dma_addr_decode #(
        .AddrWidth (Cfg.AxiAddrWidth),
        .NoRules   (Cfg.NoAddrRules),
        .rule_t    (rule_t),
        .AddrMap   (AddrMap)
      ) i_ar_decode (
        .addr_i             (slv_ports_req_i[i].ar.addr),
        .default_is_error_i (default_is_error),
        .select_error_o     (ar_select)
      );

      axi_demux #(
        .AxiIdWidth  (Cfg.AxiIdWidthSlvPorts),
        .AtopSupport (ATOPs),
        .aw_chan_t   (slv_aw_chan_t),
        .w_chan_t    (w_chan_t),
        .b_chan_t    (slv_b_chan_t),
        .ar_chan_t   (slv_ar_chan_t),
        .r_chan_t    (slv_r_chan_t),
        .axi_req_t   (slv_req_t),
        .axi_resp_t  (slv_resp_t),
        .NoMstPorts  (2),
        .MaxTrans    (Cfg.MaxMstTrans),
        .AxiLookBits (Cfg.AxiIdUsedSlvPorts),
        .UniqueIds   (Cfg.UniqueIds),
        .SpillAw     (Cfg.LatencyMode[9]),
        .SpillW      (Cfg.LatencyMode[8]),
        .SpillB      (Cfg.LatencyMode[7]),
        .SpillAr     (Cfg.LatencyMode[6]),
        .SpillR      (Cfg.LatencyMode[5])
      ) i_demux (
        .clk_i,
        .rst_ni,
        .test_i,
        .slv_req_i       (slv_ports_req_i[i]),
        .slv_aw_select_i (aw_select),
        .slv_ar_select_i (ar_select),
        .slv_resp_o      (slv_ports_resp_o[i]),
        .mst_reqs_o      (reqs),
        .mst_resps_i     (resps)
      );

      axi_multicut #(
        .NoCuts     (Cfg.PipelineStages),
        .aw_chan_t  (slv_aw_chan_t),
        .w_chan_t   (w_chan_t),
        .b_chan_t   (slv_b_chan_t),
        .ar_chan_t  (slv_ar_chan_t),
        .r_chan_t   (slv_r_chan_t),
        .axi_req_t  (slv_req_t),
        .axi_resp_t (slv_resp_t)
      ) i_ddr_link (
        .clk_i,
        .rst_ni,
        .slv_req_i  (reqs[0]),
        .slv_resp_o (resps[0]),
        .mst_req_o  (ddr_reqs[i]),
        .mst_resp_i (ddr_resps[i])
      );

      // Unmapped and blocked DMA accesses return DECERR. The PULP ATOP
      // filter returns SLVERR on both channels for atomics that return data.
      axi_err_slv #(
        .AxiIdWidth (Cfg.AxiIdWidthSlvPorts),
        .axi_req_t  (slv_req_t),
        .axi_resp_t (slv_resp_t),
        .Resp       (axi_pkg::RESP_DECERR),
        .ATOPs      (ATOPs),
        .MaxTrans   (4)
      ) i_error (
        .clk_i,
        .rst_ni,
        .test_i,
        .slv_req_i  (reqs[1]),
        .slv_resp_o (resps[1])
      );
    end
  end

  // PULP's DDR mux arbitrates requests, routes write data and prefixes IDs.
  axi_mux #(
    .SlvAxiIDWidth (Cfg.AxiIdWidthSlvPorts),
    .slv_aw_chan_t (slv_aw_chan_t),
    .mst_aw_chan_t (mst_aw_chan_t),
    .w_chan_t      (w_chan_t),
    .slv_b_chan_t  (slv_b_chan_t),
    .mst_b_chan_t  (mst_b_chan_t),
    .slv_ar_chan_t (slv_ar_chan_t),
    .mst_ar_chan_t (mst_ar_chan_t),
    .slv_r_chan_t  (slv_r_chan_t),
    .mst_r_chan_t  (mst_r_chan_t),
    .slv_req_t     (slv_req_t),
    .slv_resp_t    (slv_resp_t),
    .mst_req_t     (mst_req_t),
    .mst_resp_t    (mst_resp_t),
    .NoSlvPorts    (Cfg.NoSlvPorts),
    .MaxWTrans     (Cfg.MaxSlvTrans),
    .FallThrough   (Cfg.FallThrough),
    .SpillAw       (Cfg.LatencyMode[4]),
    .SpillW        (Cfg.LatencyMode[3]),
    .SpillB        (Cfg.LatencyMode[2]),
    .SpillAr       (Cfg.LatencyMode[1]),
    .SpillR        (Cfg.LatencyMode[0])
  ) i_ddr_mux (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_reqs_i  (ddr_reqs),
    .slv_resps_o (ddr_resps),
    .mst_req_o   (mst_ports_req_o[DdrPort]),
    .mst_resp_i  (mst_ports_resp_i[DdrPort])
  );

  for (genvar j = 1; j < Cfg.NoMstPorts; j++) begin : gen_peripheral
    mst_req_t req;
    mst_resp_t resp;

    if (Cfg.NoSlvPorts == 1) begin : gen_same_id
      assign req = cpu_reqs[j];
      assign cpu_resps[j] = resp;
    end else begin : gen_cpu_id
      // The casts add or remove the CPU's zero prefix at the top of the ID.
      assign req = '{
        aw:       mst_aw_chan_t'(cpu_reqs[j].aw),
        aw_valid: cpu_reqs[j].aw_valid,
        w:        cpu_reqs[j].w,
        w_valid:  cpu_reqs[j].w_valid,
        b_ready:  cpu_reqs[j].b_ready,
        ar:       mst_ar_chan_t'(cpu_reqs[j].ar),
        ar_valid: cpu_reqs[j].ar_valid,
        r_ready:  cpu_reqs[j].r_ready
      };
      assign cpu_resps[j] = '{
        aw_ready: resp.aw_ready,
        ar_ready: resp.ar_ready,
        w_ready:  resp.w_ready,
        b:        slv_b_chan_t'(resp.b),
        b_valid:  resp.b_valid,
        r:        slv_r_chan_t'(resp.r),
        r_valid:  resp.r_valid
      };
    end

    // The CPU demux orders write bursts. Direct links keep the output cuts
    // and skip the mux's write FIFO and separate MaxSlvTrans limit.
    axi_cut #(
      .BypassAw   (~Cfg.LatencyMode[4]),
      .BypassW    (~Cfg.LatencyMode[3]),
      .BypassB    (~Cfg.LatencyMode[2]),
      .BypassAr   (~Cfg.LatencyMode[1]),
      .BypassR    (~Cfg.LatencyMode[0]),
      .aw_chan_t  (mst_aw_chan_t),
      .w_chan_t   (w_chan_t),
      .b_chan_t   (mst_b_chan_t),
      .ar_chan_t  (mst_ar_chan_t),
      .r_chan_t   (mst_r_chan_t),
      .axi_req_t  (mst_req_t),
      .axi_resp_t (mst_resp_t)
    ) i_cut (
      .clk_i,
      .rst_ni,
      .slv_req_i  (req),
      .slv_resp_o (resp),
      .mst_req_o  (mst_ports_req_o[j]),
      .mst_resp_i (mst_ports_resp_i[j])
    );
  end
endmodule


// DMA uses the same map and rule priority as the CPU to select DDR or DECERR.
module cvwsoc_dma_addr_decode #(
  parameter int unsigned AddrWidth = 32,
  parameter int unsigned NoRules = 1,
  parameter type rule_t = axi_pkg::xbar_rule_32_t,
  parameter rule_t [NoRules-1:0] AddrMap = '0
) (
  input  logic [AddrWidth-1:0] addr_i,
  input  logic                 default_is_error_i,
  output logic                 select_error_o
);
  typedef logic [AddrWidth:0] bound_t;

  function automatic bound_t end_bound(input logic [AddrWidth-1:0] end_addr);
    return end_addr == '0 ? {1'b1, {AddrWidth{1'b0}}} : bound_t'(end_addr);
  endfunction

  logic [NoRules-1:0] rule_match;
  for (genvar i = 0; i < NoRules; i++) begin : gen_rule
    localparam rule_t Rule = AddrMap[i];
    localparam bound_t Start = bound_t'(Rule.start_addr);
    localparam bound_t End = end_bound(Rule.end_addr);
    // With DECERR as the default, keep peripheral rules only if they can
    // override a lower-priority DDR rule.
    wire [NoRules-1:0] overrides_ddr;
    for (genvar j = 0; j < NoRules; j++) begin : gen_overlap
      assign overrides_ddr[j] = j < i && AddrMap[j].idx == 0 &&
          bound_t'(AddrMap[j].start_addr) < End &&
          Start < end_bound(AddrMap[j].end_addr);
    end
    logic hit;

    cvwsoc_addr_range_match #(
      .AddrWidth (AddrWidth), .StartAddr (Rule.start_addr), .EndAddr (Rule.end_addr)
    ) i_range (.addr_i, .hit_o(hit));
    assign rule_match[i] = hit && (Rule.idx == 0 || (|overrides_ddr) || !default_is_error_i);
  end

  always_comb begin
    select_error_o = default_is_error_i;
    for (int unsigned i = 0; i < NoRules; i++)
      if (rule_match[i]) select_error_o = (AddrMap[i].idx != 0);
  end
endmodule


// The highest-index matching rule wins. On a miss, use the default target
// if enabled, or select the decode-error responder.
module cvwsoc_cpu_addr_decode #(
  parameter int unsigned AddrWidth = 32,
  parameter int unsigned NoRules = 1,
  parameter int unsigned NoTargets = 1,
  parameter type rule_t = axi_pkg::xbar_rule_32_t,
  parameter rule_t [NoRules-1:0] AddrMap = '0,
  localparam int unsigned TargetWidth = cf_math_pkg::idx_width(NoTargets),
  localparam int unsigned SelectWidth = cf_math_pkg::idx_width(NoTargets + 1)
) (
  input  logic [AddrWidth-1:0]   addr_i,
  input  logic                   en_default_i,
  input  logic [TargetWidth-1:0] default_target_i,
  output logic [SelectWidth-1:0] select_o
);
  logic [NoRules-1:0] rule_match;
  for (genvar i = 0; i < NoRules; i++) begin : gen_rule
    cvwsoc_addr_range_match #(
      .AddrWidth (AddrWidth), .StartAddr (AddrMap[i].start_addr), .EndAddr (AddrMap[i].end_addr)
    ) i_range (.addr_i, .hit_o(rule_match[i]));
  end
  always_comb begin
    select_o = en_default_i ? SelectWidth'(default_target_i) : SelectWidth'(NoTargets);
    for (int unsigned i = 0; i < NoRules; i++)
      if (rule_match[i]) select_o = SelectWidth'(TargetWidth'(AddrMap[i].idx));
  end
endmodule

// An end address of zero means the exclusive top of the address space.
module cvwsoc_addr_range_match #(
  parameter int unsigned AddrWidth = 32,
  parameter logic [AddrWidth-1:0] StartAddr = '0,
  parameter logic [AddrWidth-1:0] EndAddr = '0
) (
  input  logic [AddrWidth-1:0] addr_i,
  output logic                 hit_o
);
  typedef logic [AddrWidth:0] bound_t;
  typedef logic [AddrWidth-1:0] addr_t;
  localparam bound_t Start = bound_t'(StartAddr);
  localparam bound_t End = EndAddr == '0 ? {1'b1, {AddrWidth{1'b0}}} : bound_t'(EndAddr);
  localparam bound_t Span = End - Start;
  localparam bound_t LowBits = Span - 1'b1;
  localparam addr_t Mask = addr_t'(~LowBits);

  if (End <= Start) begin : gen_empty
    assign hit_o = 1'b0;
  end else if ((Span & LowBits) == '0 && (Start & LowBits) == '0) begin : gen_mask
    assign hit_o = (addr_i & Mask) == StartAddr;
  end else begin : gen_range
    assign hit_o = bound_t'(addr_i) >= Start && bound_t'(addr_i) < End;
  end
endmodule
