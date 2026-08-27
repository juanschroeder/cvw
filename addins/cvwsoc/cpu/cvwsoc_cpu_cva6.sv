import cvwsoc_cva6_pkg::*;

`include "cva6/typedef.svh"

module cvwsoc_cpu_cva6 import cvw::*; #(
  parameter cvw_t P,
  parameter cvwsoc_pkg::cvwsoc_cfg_t C,
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

  // No test mode input here
  logic        test_mode_i;
  assign test_mode_i = 1'b0;

  logic reset;
  assign reset = ~rst_ni;

  // AXI
  logic [AXI_ID_W-1:0] awid, bid, arid, rid;
  logic [31:0] awaddr, araddr;
  logic [7:0] awlen, arlen;
  logic [2:0] awsize, arsize;
  logic [1:0] awburst, arburst, bresp, rresp;
  logic awlock, arlock, awvalid, awready, wlast, wvalid, wready;
  logic bvalid, bready, arvalid, arready, rlast, rvalid, rready;
  logic [3:0] awcache, arcache, awqos, arqos;
  logic [2:0] awprot, arprot;
  logic [P.AHBW-1:0] wdata, rdata;
  logic [P.AHBW/8-1:0] wstrb;

  //-----------------------
  // Cheshire defines
  //-----------------------

  // Configure cheshire for FPGA mapping
  localparam cheshire_cfg_t FPGACfg = gen_cheshire_xilinx_cfg();
  localparam cheshire_cfg_t Cfg = FPGACfg;
  // Declare interface types internally
  `CVWSOC_CVA6_TYPEDEF_ALL(, Cfg)

//   // LLC
//   typedef axi_llc_rsp_t axi_ext_llc_rsp_t;
//   typedef axi_llc_req_t axi_ext_llc_req_t;


  //////////////////
  //  Interrupts  //
  //////////////////

  // Genesys2 CVA6 integration is currently single-hart.
  localparam int unsigned NumIntHarts     = 1;
  localparam int unsigned NumIrqHarts     = NumIntHarts;
  localparam int unsigned NumClicSysIntrs = NumIntIntrs + Cfg.NumExtClicIntrs;
  localparam int unsigned NumClicIntrs    = NumCoreIrqs + NumClicSysIntrs;

  // Interrupt requests to all interruptible harts
  cheshire_xeip_t [NumIrqHarts-1:0] xeip;

  // Generate indices and get maps for all ports
  localparam axi_in_cvwsoc_t AxiIn = gen_cvwsoc_axi_in(Cfg);
  //localparam int unsigned AxiSlvIdWidth = Cfg.AxiMstIdWidth + $clog2(AxiIn.num_in);

//   // Type for address map entries
//   typedef struct packed {
//     logic [$bits(aw_bt)-1:0] idx;
//     addr_t start_addr;
//     addr_t end_addr;
//   } addr_rule_t;  

  // Connectivity of Xbar
  axi_mst_req_t [AxiIn.num_in-1:0]    axi_in_req;
  axi_mst_rsp_t [AxiIn.num_in-1:0]    axi_in_rsp;


  /////////////////
  //  Reg Demux  //
  /////////////////

  // Generate indices and get maps for all ports
//   localparam reg_out_t  RegOut = gen_reg_out(Cfg);
//   reg_req_t [RegOut.num_out-1:0] reg_out_req;
//   reg_rsp_t [RegOut.num_out-1:0] reg_out_rsp;


  //////////////////////////////////////////////////////////////////
  // FIXME: LLC is currently not connected. It should be moved to cvwsoc_axi
  // FIXME: LLC is currently not connected. It should be moved to cvwsoc_axi
  //////////////////////////////////////////////////////////////////

  ///////////
  //  LLC  //
  ///////////

//   axi_slv_req_t axi_llc_cut_req;
//   axi_slv_rsp_t axi_llc_cut_rsp;

//   if (Cfg.LlcOutConnect) begin : gen_llc_atomics

//     axi_slv_req_t axi_llc_amo_req;
//     axi_slv_rsp_t axi_llc_amo_rsp;

//     // Shim atomics, which are not supported by LLC
//     // TODO: This should be a filter, but how do we filter RISC-V atomics?
//     axi_riscv_atomics_structs #(
//       .AxiAddrWidth     ( Cfg.AddrWidth    ),
//       .AxiDataWidth     ( Cfg.AxiDataWidth ),
//       .AxiIdWidth       ( AxiSlvIdWidth    ),
//       .AxiUserWidth     ( Cfg.AxiUserWidth ),
//       .AxiMaxReadTxns   ( Cfg.LlcMaxReadTxns  ),
//       .AxiMaxWriteTxns  ( Cfg.LlcMaxWriteTxns ),
//       .AxiUserAsId      ( 1 ),
//       .AxiUserIdMsb     ( Cfg.AxiUserAmoMsb ),
//       .AxiUserIdLsb     ( Cfg.AxiUserAmoLsb ),
//       .RiscvWordWidth   ( 64 ),
//       .NAxiCuts         ( Cfg.LlcAmoNumCuts ),
//       .axi_req_t        ( axi_slv_req_t ),
//       .axi_rsp_t        ( axi_slv_rsp_t )
//     ) i_llc_atomics (
//       .clk_i,
//       .rst_ni,
//       .axi_slv_req_i ( axi_out_req[AxiOut.llc] ),
//       .axi_slv_rsp_o ( axi_out_rsp[AxiOut.llc] ),
//       .axi_mst_req_o ( axi_llc_amo_req ),
//       .axi_mst_rsp_i ( axi_llc_amo_rsp )
//     );

//     axi_cut #(
//       .Bypass     ( ~Cfg.LlcAmoPostCut ),
//       .aw_chan_t  ( axi_slv_aw_chan_t ),
//       .w_chan_t   ( axi_slv_w_chan_t  ),
//       .b_chan_t   ( axi_slv_b_chan_t  ),
//       .ar_chan_t  ( axi_slv_ar_chan_t ),
//       .r_chan_t   ( axi_slv_r_chan_t  ),
//       .axi_req_t  ( axi_slv_req_t ),
//       .axi_resp_t ( axi_slv_rsp_t )
//     ) i_llc_atomics_cut (
//       .clk_i,
//       .rst_ni,
//       .slv_req_i  ( axi_llc_amo_req ),
//       .slv_resp_o ( axi_llc_amo_rsp ),
//       .mst_req_o  ( axi_llc_cut_req ),
//       .mst_resp_i ( axi_llc_cut_rsp )
//     );

//   end

//   if (Cfg.LlcOutConnect && Cfg.LlcNotBypass) begin : gen_llc

//     axi_slv_req_t axi_llc_remap_req;
//     axi_slv_rsp_t axi_llc_remap_rsp;

//     // Remap both cached and uncached accesses to single base.
//     // This is necessary for routing in the LLC-internal interconnect.
//     always_comb begin
//       axi_llc_remap_req = axi_llc_cut_req;
//       if ((axi_llc_cut_req.aw.addr & ~AmSpmRegionMask) == (SPM_UNC_BASE_ADDR & ~AmSpmRegionMask))
//         axi_llc_remap_req.aw.addr  = SPM_BASE_ADDR | (AmSpmRegionMask & axi_llc_cut_req.aw.addr);
//       if ((axi_llc_cut_req.ar.addr & ~AmSpmRegionMask) == (SPM_UNC_BASE_ADDR & ~AmSpmRegionMask))
//         axi_llc_remap_req.ar.addr = SPM_BASE_ADDR | (AmSpmRegionMask & axi_llc_cut_req.ar.addr);
//       axi_llc_cut_rsp = axi_llc_remap_rsp;
//     end

//     axi_llc_reg_wrap #(
//       .SetAssociativity ( Cfg.LlcSetAssoc  ),
//       .NumLines         ( Cfg.LlcNumLines  ),
//       .NumBlocks        ( Cfg.LlcNumBlocks ),
//       .AxiIdWidth       ( AxiSlvIdWidth    ),
//       .AxiAddrWidth     ( Cfg.AddrWidth    ),
//       .AxiDataWidth     ( Cfg.AxiDataWidth ),
//       .AxiUserWidth     ( Cfg.AxiUserWidth ),
//       .slv_req_t        ( axi_slv_req_t ),
//       .slv_resp_t       ( axi_slv_rsp_t ),
//       .mst_req_t        ( axi_ext_llc_req_t ),
//       .mst_resp_t       ( axi_ext_llc_rsp_t ),
//       .reg_req_t        ( reg_req_t ),
//       .reg_resp_t       ( reg_rsp_t ),
//       .rule_full_t      ( addr_rule_t )
//     ) i_llc (
//       .clk_i,
//       .rst_ni,
//       .test_i              ( test_mode_i ),
//       .slv_req_i           ( axi_llc_remap_req ),
//       .slv_resp_o          ( axi_llc_remap_rsp ),
//       .mst_req_o           ( axi_llc_mst_req_o ),
//       .mst_resp_i          ( axi_llc_mst_rsp_i ),
//       .conf_req_i          ( reg_out_req[RegOut.llc] ),
//       .conf_resp_o         ( reg_out_rsp[RegOut.llc] ),
//       .cached_start_addr_i ( addr_t'(Cfg.LlcOutRegionStart) ),
//       .cached_end_addr_i   ( addr_t'(Cfg.LlcOutRegionEnd)   ),
//       .spm_start_addr_i    ( addr_t'(SPM_BASE_ADDR) ),
//       .axi_llc_events_o    ( /* TODO: connect me to regs? */ )
//     );

//   end else if (Cfg.LlcOutConnect) begin : gen_llc_bypass

//     assign axi_llc_mst_req_o  = axi_llc_cut_req;
//     assign axi_llc_cut_rsp    = axi_llc_mst_rsp_i;

//   end else begin : gen_llc_stubout

    // assign axi_llc_mst_req_o  = '0;

//   end


  /////////////
  //  Cores  //
  /////////////

  `CVWSOC_CVA6_TYPEDEF_AXI_CT(axi_cva6, addr_t, cva6_id_t, axi_data_t, axi_strb_t, axi_user_t)
  // Build CVA6 user config from Cheshire config
  localparam config_pkg::cva6_user_cfg_t Cva6Cfg = gen_cva6_cfg(Cfg);
  // Override base CVA6 config with CVWSoC settings
  localparam config_pkg::cva6_user_cfg_t Cva6CvwsocCfg = apply_cvwsoc_cfg(C, Cva6Cfg);
  // Generate CVA6 full config from user config
  localparam config_pkg::cva6_cfg_t Cva6CfgBuilt = build_config_pkg::build_config(Cva6CvwsocCfg);

  // Boot from boot ROM only if available, otherwise from platform ROM
  localparam logic [P.XLEN-1:0] BootAddr = P.XLEN'(Cfg.Bootrom ? BOOTROM_BASE_ADDR : Cfg.PlatformRom);

  // Debug disabled for now
  logic          [NumIntHarts-1:0] dbg_int_req;


  // RVFI Probes
  typedef `RVFI_PROBES_INSTR_T(Cva6CfgBuilt) rvfi_probes_instr_t;
  typedef `RVFI_PROBES_CSR_T(Cva6CfgBuilt)   rvfi_probes_csr_t;
  typedef struct packed {
      rvfi_probes_csr_t   csr;
      rvfi_probes_instr_t instr;
  } rvfi_probes_t;
  rvfi_probes_t  [NumIntHarts-1:0] rvfi_probes;


  // Cores generation (only one core for now)
  for (genvar i = 0; i < NumIntHarts; i++) begin : gen_cva6_cores
    axi_cva6_req_t core_out_req, core_ur_req;
    axi_cva6_rsp_t core_out_rsp, core_ur_rsp;

    // CLIC interface (NOT USED)
    logic clic_irq_valid, clic_irq_ready;
    logic clic_irq_kill_req, clic_irq_kill_ack;
    logic clic_irq_shv;
    logic [$clog2(NumClicIntrs)-1:0] clic_irq_id;
    logic [7:0]        clic_irq_level;
    riscv::priv_lvl_t  clic_irq_priv;
    logic              clic_irq_v;
    logic [5:0]        clic_irq_vsid;

    // PLIC interrupt lines coming from outside this module
    assign xeip[i].m = meip_i;
    assign xeip[i].s = seip_i;    

    cva6 #(
      .CVA6Cfg        ( Cva6CfgBuilt ),
      .axi_ar_chan_t  ( axi_cva6_ar_chan_t ),
      .axi_aw_chan_t  ( axi_cva6_aw_chan_t ),
      .axi_w_chan_t   ( axi_cva6_w_chan_t  ),
      .b_chan_t       ( axi_cva6_b_chan_t  ),
      .r_chan_t       ( axi_cva6_r_chan_t  ),
      .noc_req_t      ( axi_cva6_req_t ),
      .noc_resp_t     ( axi_cva6_rsp_t )
    ) i_core_cva6 (
      .clk_i,
      .rst_ni,
      .boot_addr_i      ( BootAddr ),
      .hart_id_i        ( 64'(i) ),
      .irq_i            ( xeip[i] ),
      //.ipi_i            ( msip[i] ),
      .ipi_i            ( msip_i ), // Wally CLINT
      //.time_irq_i       ( mtip[i] ),
      .time_irq_i       ( mtip_i ), // Wally CLINT
      //.debug_req_i      ( dbg_int_req[i] ),
      .debug_req_i      ( 1'b0 ), // No debug module
      // CLIC is not enabled for Cheshire Xilinx build -------------
      .clic_irq_valid_i ( clic_irq_valid ),
      .clic_irq_id_i    ( clic_irq_id    ),
      .clic_irq_level_i ( clic_irq_level ),
      .clic_irq_priv_i  ( clic_irq_priv  ),
      .clic_irq_v_i     ( clic_irq_v     ),
      .clic_irq_vsid_i  ( clic_irq_vsid  ),
      .clic_irq_shv_i   ( clic_irq_shv   ),
      .clic_irq_ready_o ( clic_irq_ready ),
      .clic_kill_req_i  ( clic_irq_kill_req ),
      .clic_kill_ack_o  ( clic_irq_kill_ack ),
      //----------------------------------------------
      .rvfi_probes_o    ( rvfi_probes[i] ),
      .cvxif_req_o      ( ),
      .cvxif_resp_i     ( '0 ),
      .noc_req_o        ( core_out_req ),
      .noc_resp_i       ( core_out_rsp )
    );

    // NO CLIC enabled
    assign clic_irq_valid    = '0;
    assign clic_irq_id       = '0;
    assign clic_irq_level    = '0;
    assign clic_irq_shv      = '0;
    assign clic_irq_priv     = riscv::priv_lvl_t'(0);
    assign clic_irq_v        = '0;
    assign clic_irq_vsid     = '0;
    assign clic_irq_kill_req = '0;

    // Map user to AMO domain as we are an atomics-capable master.
    // Within the provided AMO user range, we count up from the provided core AMO offset.
    always_comb begin
      core_ur_req         = core_out_req;
      core_ur_req.aw.user = Cfg.AxiUserDefault;
      core_ur_req.ar.user = Cfg.AxiUserDefault;
      core_ur_req.w.user  = Cfg.AxiUserDefault;
      core_ur_req.aw.user [Cfg.AxiUserAmoMsb:Cfg.AxiUserAmoLsb] = Cfg.CoreUserAmoOffs + i;
      core_ur_req.ar.user [Cfg.AxiUserAmoMsb:Cfg.AxiUserAmoLsb] = Cfg.CoreUserAmoOffs + i;
      core_ur_req.w.user  [Cfg.AxiUserAmoMsb:Cfg.AxiUserAmoLsb] = Cfg.CoreUserAmoOffs + i;
      core_out_rsp        = core_ur_rsp;
    end

    // CVA6's ID encoding is wasteful; remap it statically pack into available bits
    axi_id_serialize #(
      .AxiSlvPortIdWidth      ( Cva6IdWidth     ),
      .AxiSlvPortMaxTxns      ( Cfg.CoreMaxTxns ),
      .AxiMstPortIdWidth      ( Cfg.AxiMstIdWidth      ),
      .AxiMstPortMaxUniqIds   ( 2 ** Cfg.AxiMstIdWidth ),
      .AxiMstPortMaxTxnsPerId ( Cfg.CoreMaxTxnsPerId   ),
      .AxiAddrWidth           ( Cfg.AddrWidth    ),
      .AxiDataWidth           ( Cfg.AxiDataWidth ),
      .AxiUserWidth           ( Cfg.AxiUserWidth ),
      .AtopSupport            ( 1 ),
      .slv_req_t              ( axi_cva6_req_t ),
      .slv_resp_t             ( axi_cva6_rsp_t ),
      .mst_req_t              ( axi_mst_req_t  ),
      .mst_resp_t             ( axi_mst_rsp_t  ),
      .MstIdBaseOffset        ( '0 ),
      .IdMapNumEntries        ( Cva6IdsUsed ),
      .IdMap                  ( gen_cva6_id_map(Cfg) )
    ) i_axi_id_serialize (
      .clk_i,
      .rst_ni,
      .slv_req_i  ( core_ur_req ),
      .slv_resp_o ( core_ur_rsp ),
      .mst_req_o  ( axi_in_req[AxiIn.cores[i]] ),
      .mst_resp_i ( axi_in_rsp[AxiIn.cores[i]] )
    );
  end

  // NO Cheshire XBAR: connect the first CVA6 AXI port to CVWSoC AXI port
  always_comb begin
    axi_req_o = '0;
    axi_req_o.aw.id     = axi_in_req[AxiIn.cores[0]].aw.id;
    axi_req_o.aw.addr   = axi_in_req[AxiIn.cores[0]].aw.addr[31:0];
    axi_req_o.aw.len    = axi_in_req[AxiIn.cores[0]].aw.len;
    axi_req_o.aw.size   = axi_in_req[AxiIn.cores[0]].aw.size;
    axi_req_o.aw.burst  = axi_in_req[AxiIn.cores[0]].aw.burst;
    axi_req_o.aw.lock   = axi_in_req[AxiIn.cores[0]].aw.lock;
    axi_req_o.aw.cache  = axi_in_req[AxiIn.cores[0]].aw.cache;
    axi_req_o.aw.prot   = axi_in_req[AxiIn.cores[0]].aw.prot;
    axi_req_o.aw.qos    = axi_in_req[AxiIn.cores[0]].aw.qos;
    axi_req_o.aw.region = axi_in_req[AxiIn.cores[0]].aw.region;
    axi_req_o.aw.atop   = axi_in_req[AxiIn.cores[0]].aw.atop;
    axi_req_o.aw.user   = axi_in_req[AxiIn.cores[0]].aw.user[0];
    axi_req_o.aw_valid  = axi_in_req[AxiIn.cores[0]].aw_valid;

    axi_req_o.w.data    = axi_in_req[AxiIn.cores[0]].w.data;
    axi_req_o.w.strb    = axi_in_req[AxiIn.cores[0]].w.strb;
    axi_req_o.w.last    = axi_in_req[AxiIn.cores[0]].w.last;
    axi_req_o.w.user    = axi_in_req[AxiIn.cores[0]].w.user[0];
    axi_req_o.w_valid   = axi_in_req[AxiIn.cores[0]].w_valid;

    axi_req_o.b_ready   = axi_in_req[AxiIn.cores[0]].b_ready;

    axi_req_o.ar.id     = axi_in_req[AxiIn.cores[0]].ar.id;
    axi_req_o.ar.addr   = axi_in_req[AxiIn.cores[0]].ar.addr[31:0];
    axi_req_o.ar.len    = axi_in_req[AxiIn.cores[0]].ar.len;
    axi_req_o.ar.size   = axi_in_req[AxiIn.cores[0]].ar.size;
    axi_req_o.ar.burst  = axi_in_req[AxiIn.cores[0]].ar.burst;
    axi_req_o.ar.lock   = axi_in_req[AxiIn.cores[0]].ar.lock;
    axi_req_o.ar.cache  = axi_in_req[AxiIn.cores[0]].ar.cache;
    axi_req_o.ar.prot   = axi_in_req[AxiIn.cores[0]].ar.prot;
    axi_req_o.ar.qos    = axi_in_req[AxiIn.cores[0]].ar.qos;
    axi_req_o.ar.region = axi_in_req[AxiIn.cores[0]].ar.region;
    axi_req_o.ar.user   = axi_in_req[AxiIn.cores[0]].ar.user[0];
    axi_req_o.ar_valid  = axi_in_req[AxiIn.cores[0]].ar_valid;

    axi_req_o.r_ready   = axi_in_req[AxiIn.cores[0]].r_ready;
  end

  always_comb begin
    axi_in_rsp[AxiIn.cores[0]] = '0;
    axi_in_rsp[AxiIn.cores[0]].aw_ready = axi_resp_i.aw_ready;
    axi_in_rsp[AxiIn.cores[0]].w_ready  = axi_resp_i.w_ready;
    axi_in_rsp[AxiIn.cores[0]].b.id     = axi_resp_i.b.id;
    axi_in_rsp[AxiIn.cores[0]].b.resp   = axi_resp_i.b.resp;
    axi_in_rsp[AxiIn.cores[0]].b.user   = axi_resp_i.b.user;
    axi_in_rsp[AxiIn.cores[0]].b_valid  = axi_resp_i.b_valid;
    axi_in_rsp[AxiIn.cores[0]].ar_ready = axi_resp_i.ar_ready;
    axi_in_rsp[AxiIn.cores[0]].r.id     = axi_resp_i.r.id;
    axi_in_rsp[AxiIn.cores[0]].r.data   = axi_resp_i.r.data;
    axi_in_rsp[AxiIn.cores[0]].r.resp   = axi_resp_i.r.resp;
    axi_in_rsp[AxiIn.cores[0]].r.last   = axi_resp_i.r.last;
    axi_in_rsp[AxiIn.cores[0]].r.user   = axi_resp_i.r.user;
    axi_in_rsp[AxiIn.cores[0]].r_valid  = axi_resp_i.r_valid;
  end

endmodule
