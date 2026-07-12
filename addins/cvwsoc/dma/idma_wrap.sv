///////////////////////////////////////////
// idma_wrap.sv
//
// Combined AXI descriptor/register frontends and shared AXI backend for PULP iDMA.
///////////////////////////////////////////

module idma_wrap #(
  parameter int unsigned AxiAddrWidth      = 32,
  parameter int unsigned AxiDataWidth      = 64,
  parameter int unsigned AxiIdWidth        = 4,
  parameter int unsigned AxiUserWidth      = 1,
  parameter int unsigned AxiSlvIdWidth     = 5,
  parameter int unsigned AxiMaxReadTxns    = 4,
  parameter int unsigned AxiMaxWriteTxns   = 4,
  parameter int unsigned NumAxInFlight     = 4,
  parameter int unsigned MemSysDepth       = 0,
  parameter int unsigned JobFifoDepth      = 2,
  parameter bit          RAWCouplingAvail  = 1'b0,
  parameter bit          EnableDesc64      = 1'b1,
  parameter bit          EnableDesc64Axis  = 1'b1,
  parameter bit          EnableReg64       = 1'b0,
  parameter bit          EnableReg64TwoD   = 1'b0,
  parameter type         axi_mst_req_t     = logic,
  parameter type         axi_mst_rsp_t     = logic,
  parameter type         axi_slv_req_t     = logic,
  parameter type         axi_slv_rsp_t     = logic,
  parameter type         axis_t_chan_t     = logic,
  parameter type         axis_req_t        = logic,
  parameter type         axis_rsp_t        = logic
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   testmode_i,
  output axi_mst_req_t  [1:0]    axi_mst_fe_req_o,
  input  axi_mst_rsp_t  [1:0]    axi_mst_fe_rsp_i,
  output axi_mst_req_t           axi_mst_be_req_o,
  input  axi_mst_rsp_t           axi_mst_be_rsp_i,
  input  axi_slv_req_t  [2:0]    axi_slv_req_i,
  output axi_slv_rsp_t [2:0]     axi_slv_rsp_o,
  output axis_req_t              axis_write_req_o,
  input  axis_rsp_t              axis_write_rsp_i,
  output logic                   irq_o,
  output logic                   axis_irq_o
);

  `include "axi/typedef.svh"
  `include "idma/typedef.svh"
  `include "register_interface/typedef.svh"

  localparam int unsigned IdCounterWidth = 32;
  localparam int unsigned NumFrontends = 3;
  localparam int unsigned Desc64MemIdx = 0;
  localparam int unsigned Reg64Idx = 1;
  localparam int unsigned Desc64AxisIdx = 2;
  localparam int unsigned TfLenWidth = 32;
  localparam int unsigned RegDataWidth = 32;
  localparam int unsigned DmaInputFifoDepth = 8;
  localparam int unsigned DmaPendingFifoDepth = 8;
  localparam int unsigned DmaNSpeculation = 4;
  //localparam int unsigned DmaNSpeculation = 0; // Break the combinational loop
  //localparam int unsigned DmaBufferDepth = 3;
  // TEST: Prevent UberDDR3 arbiter deadlock
  localparam int unsigned DmaBufferDepth = 256;
  localparam int unsigned DmaBackendDepth = NumAxInFlight + DmaBufferDepth;

  typedef logic [AxiDataWidth-1:0]      data_t;
  typedef logic [AxiDataWidth/8-1:0]    strb_t;
  typedef logic [AxiAddrWidth-1:0]      addr_t;
  typedef logic [AxiIdWidth-1:0]        id_t;
  typedef logic [AxiSlvIdWidth-1:0]     slv_id_t;
  typedef logic [AxiUserWidth-1:0]      user_t;
  typedef logic [TfLenWidth-1:0]        tf_len_t;
  typedef logic [IdCounterWidth-1:0]    tf_id_t;
  typedef logic [RegDataWidth-1:0]      reg_data_t;
  typedef logic [RegDataWidth/8-1:0]    reg_strb_t;

  function automatic int unsigned max_width(input int unsigned a, b);
    return (a > b) ? a : b;
  endfunction

  `AXI_TYPEDEF_AW_CHAN_T(axi_aw_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T (axi_w_chan_t,  data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T (axi_b_chan_t,  id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_ar_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_r_chan_t, data_t, id_t, user_t)
  `AXI_TYPEDEF_AW_CHAN_T(axi_slv_aw_chan_t, addr_t, slv_id_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T (axi_slv_b_chan_t,  slv_id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_slv_ar_chan_t, addr_t, slv_id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T (axi_slv_r_chan_t,  data_t, slv_id_t, user_t)
  `AXI_LITE_TYPEDEF_ALL(axi_lite, addr_t, data_t, strb_t)
  `REG_BUS_TYPEDEF_ALL(desc_regs, addr_t, data_t, strb_t)
  `REG_BUS_TYPEDEF_ALL(dma_regs, addr_t, reg_data_t, reg_strb_t)
  `IDMA_TYPEDEF_FULL_REQ_T(idma_req_t, id_t, addr_t, tf_len_t)
  `IDMA_TYPEDEF_FULL_RSP_T(idma_rsp_t, addr_t)

  localparam int unsigned AxiAwChanWidth = $bits(axi_aw_chan_t);
  localparam int unsigned AxiArChanWidth = $bits(axi_ar_chan_t);
  localparam int unsigned AxisTChanWidth = $bits(axis_t_chan_t);

  typedef struct packed {
    axi_ar_chan_t ar_chan;
    logic [max_width(AxiArChanWidth, AxisTChanWidth)-AxiArChanWidth:0] padding;
  } axi_read_ar_chan_padded_t;

  typedef struct packed {
    axis_t_chan_t t_chan;
    logic [max_width(AxiArChanWidth, AxisTChanWidth)-AxisTChanWidth:0] padding;
  } axis_read_t_chan_padded_t;

  typedef union packed {
    axi_read_ar_chan_padded_t axi;
    axis_read_t_chan_padded_t axis;
  } read_meta_channel_t;

  typedef struct packed {
    axi_aw_chan_t aw_chan;
    logic [max_width(AxiAwChanWidth, AxisTChanWidth)-AxiAwChanWidth:0] padding;
  } axi_write_aw_chan_padded_t;

  typedef struct packed {
    axis_t_chan_t t_chan;
    logic [max_width(AxiAwChanWidth, AxisTChanWidth)-AxisTChanWidth:0] padding;
  } axis_write_t_chan_padded_t;

  typedef union packed {
    axi_write_aw_chan_padded_t axi;
    axis_write_t_chan_padded_t axis;
  } write_meta_channel_t;

  (* mark_debug = "true" *) idma_req_t [NumFrontends-1:0] idma_req_fe;
  (* mark_debug = "true" *) logic [NumFrontends-1:0] idma_req_fe_valid;
  (* mark_debug = "true" *) logic [NumFrontends-1:0] idma_req_fe_ready;
  (* mark_debug = "true" *) idma_rsp_t [NumFrontends-1:0] idma_rsp_fe;
  (* mark_debug = "true" *) logic [NumFrontends-1:0] idma_rsp_fe_valid;
  (* mark_debug = "true" *) logic [NumFrontends-1:0] idma_rsp_fe_ready;

  (* mark_debug = "true" *) idma_req_t idma_req;
  (* mark_debug = "true" *) idma_rsp_t idma_rsp;
  (* mark_debug = "true" *) logic idma_req_valid;
  (* mark_debug = "true" *) logic idma_req_ready;
  (* mark_debug = "true" *) logic idma_rsp_valid;
  (* mark_debug = "true" *) logic idma_rsp_ready;
  (* mark_debug = "true" *) idma_pkg::idma_busy_t busy;
  logic me_busy;
  (* mark_debug = "true" *) addr_t dbg_idma_req_src_addr;
  (* mark_debug = "true" *) addr_t dbg_idma_req_dst_addr;
  (* mark_debug = "true" *) tf_len_t dbg_idma_req_length;

  axi_mst_req_t axi_read_req;
  axi_mst_req_t axi_write_req;
  axi_mst_rsp_t axi_read_rsp;
  axi_mst_rsp_t axi_write_rsp;
  axis_req_t axis_write_req;
  axis_req_t axis_read_req;
  axis_rsp_t axis_read_rsp;

  (* mark_debug = "true" *) logic desc64_irq;
  (* mark_debug = "true" *) logic desc64_irq_pulse;
  (* mark_debug = "true" *) logic desc64_irq_pending;
  logic desc64_irq_enable;
  logic desc64_irq_clear_wr;
  logic desc64_irq_enable_wr;
  logic desc64_sel_irq_status;
  logic desc64_sel_irq_enable;
  logic desc64_sel_irq;
  logic reg64_irq;
  logic desc64_axis_irq_pulse;

  if (EnableDesc64) begin : gen_desc64
    axi_lite_req_t desc_axi_lite_req;
    axi_lite_resp_t desc_axi_lite_rsp;
    desc_regs_req_t desc_reg_req;
    desc_regs_rsp_t desc_reg_rsp;
    desc_regs_req_t desc_idma_reg_req;
    desc_regs_rsp_t desc_idma_reg_rsp;
    (* mark_debug = "true" *) idma_req_t desc_req;
    (* mark_debug = "true" *) idma_rsp_t desc_rsp;
    (* mark_debug = "true" *) logic desc_req_valid;
    (* mark_debug = "true" *) logic desc_req_ready;
    (* mark_debug = "true" *) logic desc_rsp_valid;
    (* mark_debug = "true" *) logic desc_rsp_ready;
    (* mark_debug = "true" *) addr_t dbg_desc_req_src_addr;
    (* mark_debug = "true" *) addr_t dbg_desc_req_dst_addr;
    (* mark_debug = "true" *) tf_len_t dbg_desc_req_length;

    axi_to_axi_lite #(
      .AxiAddrWidth    ( AxiAddrWidth       ),
      .AxiDataWidth    ( AxiDataWidth       ),
      .AxiIdWidth      ( AxiSlvIdWidth      ),
      .AxiUserWidth    ( AxiUserWidth       ),
      .AxiMaxWriteTxns ( AxiMaxWriteTxns    ),
      .AxiMaxReadTxns  ( AxiMaxReadTxns     ),
      .FallThrough     ( 1'b0               ),
      .full_req_t      ( axi_slv_req_t      ),
      .full_resp_t     ( axi_slv_rsp_t      ),
      .lite_req_t      ( axi_lite_req_t     ),
      .lite_resp_t     ( axi_lite_resp_t    )
    ) axi_to_axi_lite_i (
      .clk_i      ( clk_i                    ),
      .rst_ni     ( rst_ni                   ),
      .test_i     ( testmode_i               ),
      .slv_req_i  ( axi_slv_req_i[Desc64MemIdx] ),
      .slv_resp_o ( axi_slv_rsp_o[Desc64MemIdx] ),
      .mst_req_o  ( desc_axi_lite_req        ),
      .mst_resp_i ( desc_axi_lite_rsp        )
    );

    axi_lite_to_reg #(
      .ADDR_WIDTH     ( AxiAddrWidth       ),
      .DATA_WIDTH     ( AxiDataWidth       ),
      .axi_lite_req_t ( axi_lite_req_t     ),
      .axi_lite_rsp_t ( axi_lite_resp_t    ),
      .reg_req_t      ( desc_regs_req_t    ),
      .reg_rsp_t      ( desc_regs_rsp_t    )
    ) axi_lite_to_reg_i (
      .clk_i          ( clk_i              ),
      .rst_ni         ( rst_ni             ),
      .axi_lite_req_i ( desc_axi_lite_req  ),
      .axi_lite_rsp_o ( desc_axi_lite_rsp  ),
      .reg_req_o      ( desc_reg_req       ),
      .reg_rsp_i      ( desc_reg_rsp       )
    );

    idma_desc64_top #(
      .AddrWidth        ( 64                  ),
      .DataWidth        ( AxiDataWidth        ),
      .AxiIdWidth       ( AxiIdWidth          ),
      .idma_req_t       ( idma_req_t          ),
      .idma_rsp_t       ( idma_rsp_t          ),
      .reg_rsp_t        ( desc_regs_rsp_t     ),
      .reg_req_t        ( desc_regs_req_t     ),
      .axi_rsp_t        ( axi_mst_rsp_t       ),
      .axi_req_t        ( axi_mst_req_t       ),
      .axi_ar_chan_t    ( axi_ar_chan_t       ),
      .axi_r_chan_t     ( axi_r_chan_t        ),
      .InputFifoDepth   ( DmaInputFifoDepth   ),
      .PendingFifoDepth ( DmaPendingFifoDepth ),
      .BackendDepth     ( DmaBackendDepth     ),
      .NSpeculation     ( DmaNSpeculation     )
    ) desc64_i (
      .clk_i,
      .rst_ni,
      .master_req_o      ( axi_mst_fe_req_o[0] ),
      .master_rsp_i      ( axi_mst_fe_rsp_i[0] ),
      .axi_ar_id_i       ( '0               ),
      .axi_aw_id_i       ( '0               ),
      .slave_req_i       ( desc_idma_reg_req ),
      .slave_rsp_o       ( desc_idma_reg_rsp ),
      .idma_req_o        ( desc_req         ),
      .idma_req_valid_o  ( desc_req_valid   ),
      .idma_req_ready_i  ( desc_req_ready   ),
      .idma_rsp_i        ( desc_rsp         ),
      .idma_rsp_valid_i  ( desc_rsp_valid   ),
      .idma_rsp_ready_o  ( desc_rsp_ready   ),
      .idma_busy_i       ( |busy            ),
      .irq_o             ( desc64_irq_pulse )
    );

    localparam logic [15:0] DescIrqStatusOffset = 16'h100;
    localparam logic [15:0] DescIrqEnableOffset = 16'h104;
    localparam int unsigned DescRegBytes = AxiDataWidth / 8;
    localparam int unsigned DescRegByteOffWidth = $clog2(DescRegBytes);
    localparam logic [15:0] DescRegByteMask = 16'(DescRegBytes - 1);
    localparam logic [15:0] DescIrqStatusWordOffset = DescIrqStatusOffset & ~DescRegByteMask;
    localparam logic [15:0] DescIrqEnableWordOffset = DescIrqEnableOffset & ~DescRegByteMask;
    localparam int unsigned DescIrqStatusLane = DescIrqStatusOffset % DescRegBytes;
    localparam int unsigned DescIrqEnableLane = DescIrqEnableOffset % DescRegBytes;

    logic desc64_sel_irq_status_word;
    logic desc64_sel_irq_enable_word;
    logic desc64_sel_irq_status_lane;
    logic desc64_sel_irq_enable_lane;
    logic desc64_irq_wbit;
    logic desc64_irq_wstrb;

    assign desc64_sel_irq_status_word =
        desc_reg_req.valid && ((desc_reg_req.addr[15:0] & ~DescRegByteMask) == DescIrqStatusWordOffset);
    assign desc64_sel_irq_enable_word =
        desc_reg_req.valid && ((desc_reg_req.addr[15:0] & ~DescRegByteMask) == DescIrqEnableWordOffset);
    assign desc64_sel_irq_status_lane =
        desc_reg_req.write ? desc_reg_req.wstrb[DescIrqStatusLane] :
                             (desc_reg_req.addr[DescRegByteOffWidth-1:0] == DescRegByteOffWidth'(DescIrqStatusLane));
    assign desc64_sel_irq_enable_lane =
        desc_reg_req.write ? desc_reg_req.wstrb[DescIrqEnableLane] :
                             (desc_reg_req.addr[DescRegByteOffWidth-1:0] == DescRegByteOffWidth'(DescIrqEnableLane));
    assign desc64_sel_irq_status =
        desc64_sel_irq_status_word && desc64_sel_irq_status_lane;
    assign desc64_sel_irq_enable =
        desc64_sel_irq_enable_word && desc64_sel_irq_enable_lane;
    assign desc64_sel_irq = desc64_sel_irq_status || desc64_sel_irq_enable;
    assign desc64_irq_wbit =
        desc64_sel_irq_enable ? desc_reg_req.wdata[DescIrqEnableLane*8] :
                                desc_reg_req.wdata[DescIrqStatusLane*8];
    assign desc64_irq_wstrb =
        desc64_sel_irq_enable ? desc_reg_req.wstrb[DescIrqEnableLane] :
                                desc_reg_req.wstrb[DescIrqStatusLane];
    assign desc64_irq_clear_wr =
        desc64_sel_irq_status && desc_reg_req.write && desc64_irq_wstrb && desc64_irq_wbit;
    assign desc64_irq_enable_wr =
        desc64_sel_irq_enable && desc_reg_req.write && desc64_irq_wstrb;

    always_comb begin
      desc_idma_reg_req = desc_reg_req;
      desc_idma_reg_req.valid = desc_reg_req.valid && !desc64_sel_irq;

      desc_reg_rsp = desc_idma_reg_rsp;
      if (desc64_sel_irq) begin
        desc_reg_rsp.ready = 1'b1;
        desc_reg_rsp.error = 1'b0;
        desc_reg_rsp.rdata = '0;

        if (!desc_reg_req.write) begin
          unique case (1'b1)
            desc64_sel_irq_status: desc_reg_rsp.rdata = {{(AxiDataWidth-1){1'b0}}, desc64_irq_pending};
            desc64_sel_irq_enable: begin
              desc_reg_rsp.rdata = '0;
              desc_reg_rsp.rdata[DescIrqEnableLane*8] = desc64_irq_enable;
            end
            default: desc_reg_rsp.rdata = '0;
          endcase
        end
      end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        desc64_irq_enable <= 1'b0;
        desc64_irq_pending <= 1'b0;
      end else begin
        if (desc64_irq_enable_wr)
          desc64_irq_enable <= desc64_irq_wbit;
        if (desc64_irq_clear_wr)
          desc64_irq_pending <= 1'b0;
        if (desc64_irq_pulse)
          desc64_irq_pending <= 1'b1;
      end
    end

    assign desc64_irq = desc64_irq_pending && desc64_irq_enable;

    assign idma_req_fe[Desc64MemIdx] = desc_req;
    assign idma_req_fe_valid[Desc64MemIdx] = desc_req_valid;
    assign desc_req_ready = idma_req_fe_ready[Desc64MemIdx];
    assign desc_rsp = idma_rsp_fe[Desc64MemIdx];
    assign desc_rsp_valid = idma_rsp_fe_valid[Desc64MemIdx];
    assign idma_rsp_fe_ready[Desc64MemIdx] = desc_rsp_ready;

    assign dbg_desc_req_src_addr = desc_req.src_addr;
    assign dbg_desc_req_dst_addr = desc_req.dst_addr;
    assign dbg_desc_req_length = desc_req.length;
  end else begin : gen_no_desc64
    assign axi_mst_fe_req_o[0] = '0;
    assign axi_slv_rsp_o[Desc64MemIdx] = '0;
    assign idma_req_fe[Desc64MemIdx] = '0;
    assign idma_req_fe_valid[Desc64MemIdx] = 1'b0;
    assign idma_rsp_fe_ready[Desc64MemIdx] = 1'b0;
    assign desc64_irq_pulse = 1'b0;
    assign desc64_irq_pending = 1'b0;
    assign desc64_irq_enable = 1'b0;
    assign desc64_irq_clear_wr = 1'b0;
    assign desc64_irq_enable_wr = 1'b0;
    assign desc64_sel_irq_status = 1'b0;
    assign desc64_sel_irq_enable = 1'b0;
    assign desc64_sel_irq = 1'b0;
    assign desc64_irq = 1'b0;
  end

  // Dedicated desc64 frontend for DDR-to-AXI-Stream playback.  The descriptor
  // ABI is identical to the memory-to-memory frontend; only the protocol tags
  // are overridden before the shared frontend arbiter.
  if (EnableDesc64Axis) begin : gen_desc64_axis
    axi_lite_req_t axis_desc_axi_lite_req;
    axi_lite_resp_t axis_desc_axi_lite_rsp;
    desc_regs_req_t axis_desc_reg_req;
    desc_regs_rsp_t axis_desc_reg_rsp;
    idma_req_t axis_desc_req_raw;
    idma_req_t axis_desc_req;
    idma_rsp_t axis_desc_rsp;
    logic axis_desc_req_valid;
    logic axis_desc_req_ready;
    logic axis_desc_rsp_valid;
    logic axis_desc_rsp_ready;

    axi_to_axi_lite #(
      .AxiAddrWidth    ( AxiAddrWidth       ),
      .AxiDataWidth    ( AxiDataWidth       ),
      .AxiIdWidth      ( AxiSlvIdWidth      ),
      .AxiUserWidth    ( AxiUserWidth       ),
      .AxiMaxWriteTxns ( AxiMaxWriteTxns    ),
      .AxiMaxReadTxns  ( AxiMaxReadTxns     ),
      .FallThrough     ( 1'b0               ),
      .full_req_t      ( axi_slv_req_t      ),
      .full_resp_t     ( axi_slv_rsp_t      ),
      .lite_req_t      ( axi_lite_req_t     ),
      .lite_resp_t     ( axi_lite_resp_t    )
    ) axi_to_axi_lite_i (
      .clk_i,
      .rst_ni,
      .test_i     ( testmode_i                         ),
      .slv_req_i  ( axi_slv_req_i[Desc64AxisIdx]       ),
      .slv_resp_o ( axi_slv_rsp_o[Desc64AxisIdx]       ),
      .mst_req_o  ( axis_desc_axi_lite_req             ),
      .mst_resp_i ( axis_desc_axi_lite_rsp             )
    );

    axi_lite_to_reg #(
      .ADDR_WIDTH     ( AxiAddrWidth       ),
      .DATA_WIDTH     ( AxiDataWidth       ),
      .axi_lite_req_t ( axi_lite_req_t     ),
      .axi_lite_rsp_t ( axi_lite_resp_t    ),
      .reg_req_t      ( desc_regs_req_t    ),
      .reg_rsp_t      ( desc_regs_rsp_t    )
    ) axi_lite_to_reg_i (
      .clk_i,
      .rst_ni,
      .axi_lite_req_i ( axis_desc_axi_lite_req ),
      .axi_lite_rsp_o ( axis_desc_axi_lite_rsp ),
      .reg_req_o      ( axis_desc_reg_req      ),
      .reg_rsp_i      ( axis_desc_reg_rsp      )
    );

    idma_desc64_top #(
      .AddrWidth        ( 64                  ),
      .DataWidth        ( AxiDataWidth        ),
      .AxiIdWidth       ( AxiIdWidth          ),
      .idma_req_t       ( idma_req_t          ),
      .idma_rsp_t       ( idma_rsp_t          ),
      .reg_rsp_t        ( desc_regs_rsp_t     ),
      .reg_req_t        ( desc_regs_req_t     ),
      .axi_rsp_t        ( axi_mst_rsp_t       ),
      .axi_req_t        ( axi_mst_req_t       ),
      .axi_ar_chan_t    ( axi_ar_chan_t       ),
      .axi_r_chan_t     ( axi_r_chan_t        ),
      .InputFifoDepth   ( DmaInputFifoDepth   ),
      .PendingFifoDepth ( DmaPendingFifoDepth ),
      .BackendDepth     ( DmaBackendDepth     ),
      .NSpeculation     ( DmaNSpeculation     )
    ) desc64_axis_i (
      .clk_i,
      .rst_ni,
      .master_req_o      ( axi_mst_fe_req_o[1] ),
      .master_rsp_i      ( axi_mst_fe_rsp_i[1] ),
      .axi_ar_id_i       ( '0                  ),
      .axi_aw_id_i       ( '0                  ),
      .slave_req_i       ( axis_desc_reg_req    ),
      .slave_rsp_o       ( axis_desc_reg_rsp    ),
      .idma_req_o        ( axis_desc_req_raw    ),
      .idma_req_valid_o  ( axis_desc_req_valid  ),
      .idma_req_ready_i  ( axis_desc_req_ready  ),
      .idma_rsp_i        ( axis_desc_rsp        ),
      .idma_rsp_valid_i  ( axis_desc_rsp_valid  ),
      .idma_rsp_ready_o  ( axis_desc_rsp_ready  ),
      .idma_busy_i       ( |busy                ),
      .irq_o             ( desc64_axis_irq_pulse )
    );

    always_comb begin
      axis_desc_req = axis_desc_req_raw;
      axis_desc_req.opt.src_protocol = idma_pkg::AXI;
      axis_desc_req.opt.dst_protocol = idma_pkg::AXI_STREAM;
    end

    assign idma_req_fe[Desc64AxisIdx] = axis_desc_req;
    assign idma_req_fe_valid[Desc64AxisIdx] = axis_desc_req_valid;
    assign axis_desc_req_ready = idma_req_fe_ready[Desc64AxisIdx];
    assign axis_desc_rsp = idma_rsp_fe[Desc64AxisIdx];
    assign axis_desc_rsp_valid = idma_rsp_fe_valid[Desc64AxisIdx];
    assign idma_rsp_fe_ready[Desc64AxisIdx] = axis_desc_rsp_ready;
  end else begin : gen_no_desc64_axis
    assign axi_mst_fe_req_o[1] = '0;
    assign axi_slv_rsp_o[Desc64AxisIdx] = '0;
    assign idma_req_fe[Desc64AxisIdx] = '0;
    assign idma_req_fe_valid[Desc64AxisIdx] = 1'b0;
    assign idma_rsp_fe_ready[Desc64AxisIdx] = 1'b0;
    assign desc64_axis_irq_pulse = 1'b0;
  end

  dma_regs_req_t dma_reg_req;
  dma_regs_rsp_t dma_reg_rsp;
  dma_regs_req_t idma_reg_req;
  dma_regs_rsp_t idma_reg_rsp;
  dma_regs_req_t [0:0] dma_reg_req_array;
  dma_regs_rsp_t [0:0] dma_reg_rsp_array;
  logic issue_id;
  logic retire_id;
  tf_id_t done_id;
  tf_id_t next_id;
  logic irq_pending;
  logic irq_enable;
  logic irq_clear_wr;
  logic irq_enable_wr;
  logic sel_irq_status;
  logic sel_irq_enable;
  logic sel_irq;

  if (EnableReg64) begin : gen_reg64
    idma_req_t reg64_req_in;
    idma_req_t reg64_req;
    idma_rsp_t reg64_rsp;
    logic reg64_req_in_valid;
    logic reg64_req_in_ready;
    logic reg64_req_valid;
    logic reg64_req_ready;
    logic reg64_rsp_valid;
    logic reg64_rsp_ready;
    tf_id_t [0:0] done_id_array;
    idma_pkg::idma_busy_t [0:0] busy_array;
    logic [0:0] midend_busy;

    assign done_id_array[0] = done_id;
    assign busy_array[0] = busy;
    assign midend_busy = '0;

    axi_to_reg_v2 #(
      .AxiAddrWidth ( AxiAddrWidth   ),
      .AxiDataWidth ( AxiDataWidth   ),
      .AxiIdWidth   ( AxiSlvIdWidth  ),
      .AxiUserWidth ( AxiUserWidth   ),
      .RegDataWidth ( RegDataWidth   ),
      .CutMemReqs   ( 1'b1           ),
      .axi_req_t    ( axi_slv_req_t  ),
      .axi_rsp_t    ( axi_slv_rsp_t  ),
      .reg_req_t    ( dma_regs_req_t ),
      .reg_rsp_t    ( dma_regs_rsp_t )
    ) axi_to_reg_i (
      .clk_i,
      .rst_ni,
      .axi_req_i ( axi_slv_req_i[Reg64Idx] ),
      .axi_rsp_o ( axi_slv_rsp_o[Reg64Idx] ),
      .reg_req_o ( dma_reg_req             ),
      .reg_rsp_i ( dma_reg_rsp             ),
      .reg_id_o  (                         ),
      .busy_o    (                         )
    );

    if (!EnableReg64TwoD) begin : gen_1d
      assign dma_reg_req_array[0] = idma_reg_req;
      assign idma_reg_rsp = dma_reg_rsp_array[0];

      idma_reg64_1d #(
        .NumRegs        ( 1              ),
        .NumStreams     ( 1              ),
        .IdCounterWidth ( IdCounterWidth ),
        .reg_req_t      ( dma_regs_req_t ),
        .reg_rsp_t      ( dma_regs_rsp_t ),
        .dma_req_t      ( idma_req_t     )
      ) frontend_i (
        .clk_i,
        .rst_ni,
        .dma_ctrl_req_i ( dma_reg_req_array ),
        .dma_ctrl_rsp_o ( dma_reg_rsp_array ),
        .dma_req_o      ( reg64_req_in      ),
        .req_valid_o    ( reg64_req_in_valid ),
        .req_ready_i    ( reg64_req_in_ready ),
        .next_id_i      ( next_id           ),
        .stream_idx_o   (                   ),
        .done_id_i      ( done_id_array     ),
        .busy_i         ( busy_array        ),
        .midend_busy_i  ( midend_busy       )
      );

      stream_fifo_optimal_wrap #(
        .Depth     ( JobFifoDepth ),
        .type_t    ( idma_req_t   ),
        .PrintInfo ( 1'b0         )
      ) job_fifo_i (
        .clk_i,
        .rst_ni,
        .testmode_i,
        .flush_i ( 1'b0               ),
        .usage_o (                    ),
        .data_i  ( reg64_req_in       ),
        .valid_i ( reg64_req_in_valid ),
        .ready_o ( reg64_req_in_ready ),
        .data_o  ( reg64_req          ),
        .valid_o ( reg64_req_valid    ),
        .ready_i ( reg64_req_ready    )
      );
    end else begin : gen_unsupported_2d
      assign idma_reg_rsp = '0;
      assign reg64_req = '0;
      assign reg64_req_valid = 1'b0;
      assign reg64_req_in_valid = 1'b0;
      assign reg64_req_in_ready = 1'b0;
      initial $fatal(1, "idma_wrap: EnableReg64TwoD is reserved for future integration");
    end

    assign issue_id = reg64_req_in_valid && reg64_req_in_ready;
    assign retire_id = reg64_rsp_valid && reg64_rsp_ready;
    assign reg64_rsp_ready = 1'b1;

    idma_transfer_id_gen #(
      .IdWidth ( IdCounterWidth )
    ) transfer_id_i (
      .clk_i,
      .rst_ni,
      .issue_i     ( issue_id  ),
      .retire_i    ( retire_id ),
      .next_o      ( next_id   ),
      .completed_o ( done_id   )
    );

    assign idma_req_fe[Reg64Idx] = reg64_req;
    assign idma_req_fe_valid[Reg64Idx] = reg64_req_valid;
    assign reg64_req_ready = idma_req_fe_ready[Reg64Idx];
    assign reg64_rsp = idma_rsp_fe[Reg64Idx];
    assign reg64_rsp_valid = idma_rsp_fe_valid[Reg64Idx];
    assign idma_rsp_fe_ready[Reg64Idx] = reg64_rsp_ready;

    localparam logic [15:0] IrqStatusOffset = 16'h100;
    localparam logic [15:0] IrqEnableOffset = 16'h104;

    assign sel_irq_status = dma_reg_req.valid && (dma_reg_req.addr[15:0] == IrqStatusOffset);
    assign sel_irq_enable = dma_reg_req.valid && (dma_reg_req.addr[15:0] == IrqEnableOffset);
    assign sel_irq = sel_irq_status || sel_irq_enable;
    assign irq_clear_wr =
        sel_irq_status && dma_reg_req.write && dma_reg_req.wstrb[0] && dma_reg_req.wdata[0];
    assign irq_enable_wr =
        sel_irq_enable && dma_reg_req.write && dma_reg_req.wstrb[0];

    always_comb begin
      idma_reg_req = dma_reg_req;
      idma_reg_req.valid = dma_reg_req.valid && !sel_irq;

      dma_reg_rsp = idma_reg_rsp;
      if (sel_irq) begin
        dma_reg_rsp.ready = 1'b1;
        dma_reg_rsp.error = 1'b0;
        dma_reg_rsp.rdata = '0;

        if (!dma_reg_req.write) begin
          unique case (dma_reg_req.addr[15:0])
            IrqStatusOffset: dma_reg_rsp.rdata = {31'b0, irq_pending};
            IrqEnableOffset: dma_reg_rsp.rdata = {31'b0, irq_enable};
            default:         dma_reg_rsp.rdata = '0;
          endcase
        end
      end
    end

    logic retire_id_q;
    logic retire_pulse;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)
        retire_id_q <= 1'b0;
      else
        retire_id_q <= retire_id;
    end

    assign retire_pulse = retire_id && !retire_id_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        irq_enable  <= 1'b0;
        irq_pending <= 1'b0;
      end else begin
        if (irq_enable_wr)
          irq_enable <= dma_reg_req.wdata[0];
        if (irq_clear_wr)
          irq_pending <= 1'b0;
        if (retire_pulse)
          irq_pending <= 1'b1;
      end
    end

    assign reg64_irq = irq_pending && irq_enable;
  end else begin : gen_no_reg64
    assign axi_slv_rsp_o[Reg64Idx] = '0;
    assign idma_req_fe[Reg64Idx] = '0;
    assign idma_req_fe_valid[Reg64Idx] = 1'b0;
    assign idma_rsp_fe_ready[Reg64Idx] = 1'b0;
    assign dma_reg_req = '0;
    assign dma_reg_rsp = '0;
    assign idma_reg_req = '0;
    assign idma_reg_rsp = '0;
    assign issue_id = 1'b0;
    assign retire_id = 1'b0;
    assign done_id = '0;
    assign next_id = '0;
    assign irq_pending = 1'b0;
    assign irq_enable = 1'b0;
    assign irq_clear_wr = 1'b0;
    assign irq_enable_wr = 1'b0;
    assign sel_irq_status = 1'b0;
    assign sel_irq_enable = 1'b0;
    assign sel_irq = 1'b0;
    assign reg64_irq = 1'b0;
  end

  idma_fe_arb #(
    .NumFrontends ( NumFrontends ),
    .idma_req_t   ( idma_req_t   ),
    .idma_rsp_t   ( idma_rsp_t   )
  ) fe_arb_i (
    .clk_i,
    .rst_ni,
    .idma_req_fe_i        ( idma_req_fe        ),
    .idma_req_fe_valid_i  ( idma_req_fe_valid  ),
    .idma_req_fe_ready_o  ( idma_req_fe_ready  ),
    .idma_rsp_fe_o        ( idma_rsp_fe        ),
    .idma_rsp_fe_valid_o  ( idma_rsp_fe_valid  ),
    .idma_rsp_fe_ready_i  ( idma_rsp_fe_ready  ),
    .idma_req_be_o        ( idma_req           ),
    .idma_req_be_valid_o  ( idma_req_valid     ),
    .idma_req_be_ready_i  ( idma_req_ready     ),
    .idma_rsp_be_i        ( idma_rsp           ),
    .idma_rsp_be_valid_i  ( idma_rsp_valid     ),
    .idma_rsp_be_ready_o  ( idma_rsp_ready     )
  );

  idma_backend_rw_axi_rw_axis #(
    .CombinedShifter      ( 1'b0                       ),
    .DataWidth            ( AxiDataWidth               ),
    .AddrWidth            ( AxiAddrWidth               ),
    .AxiIdWidth           ( AxiIdWidth                 ),
    .UserWidth            ( AxiUserWidth               ),
    .TFLenWidth           ( TfLenWidth                 ),
    .MaskInvalidData      ( 1'b1                       ),
    .BufferDepth          ( DmaBufferDepth             ),
    .RAWCouplingAvail     ( RAWCouplingAvail           ),
    .HardwareLegalizer    ( 1'b1                       ),
    .RejectZeroTransfers  ( 1'b1                       ),
    .ErrorCap             ( idma_pkg::NO_ERROR_HANDLING ),
    .PrintFifoInfo        ( 1'b0                       ),
    .NumAxInFlight        ( NumAxInFlight              ),
    .MemSysDepth          ( MemSysDepth                ),
    .idma_req_t           ( idma_req_t                 ),
    .idma_rsp_t           ( idma_rsp_t                 ),
    .idma_eh_req_t        ( idma_pkg::idma_eh_req_t    ),
    .idma_busy_t          ( idma_pkg::idma_busy_t      ),
    .axi_req_t            ( axi_mst_req_t              ),
    .axi_rsp_t            ( axi_mst_rsp_t              ),
    .axis_req_t           ( axis_req_t                 ),
    .axis_rsp_t           ( axis_rsp_t                 ),
    .write_meta_channel_t ( write_meta_channel_t       ),
    .read_meta_channel_t  ( read_meta_channel_t        )
  ) backend_i (
    .clk_i,
    .rst_ni,
    .testmode_i,
    .idma_req_i      ( idma_req       ),
    .req_valid_i     ( idma_req_valid ),
    .req_ready_o     ( idma_req_ready ),
    .idma_rsp_o      ( idma_rsp       ),
    .rsp_valid_o     ( idma_rsp_valid ),
    .rsp_ready_i     ( idma_rsp_ready ),
    .idma_eh_req_i   ( '0             ),
    .eh_req_valid_i  ( 1'b0           ),
    .eh_req_ready_o  (                ),
    .axi_read_req_o  ( axi_read_req   ),
    .axi_read_rsp_i  ( axi_read_rsp   ),
    .axis_read_req_i ( '0             ),
    .axis_read_rsp_o (                ), // Not used for now
    .axi_write_req_o ( axi_write_req  ),
    .axi_write_rsp_i ( axi_write_rsp  ),
    .axis_write_req_o ( axis_write_req   ),
    .axis_write_rsp_i ( axis_write_rsp_i ),
    .busy_o          ( busy           )
  );

  // This first playback implementation has no descriptor-level packet
  // semantics.  Suppress the backend's end-of-transfer TLAST until those
  // semantics are deliberately added.
  always_comb begin
    axis_write_req_o = axis_write_req;
    axis_write_req_o.t.last = 1'b0;
  end

  assign me_busy = 1'b0;

  axi_rw_join #(
    .axi_req_t  ( axi_mst_req_t ),
    .axi_resp_t ( axi_mst_rsp_t )
  ) axi_join_i (
    .clk_i,
    .rst_ni,
    .slv_read_req_i   ( axi_read_req     ),
    .slv_read_resp_o  ( axi_read_rsp     ),
    .slv_write_req_i  ( axi_write_req    ),
    .slv_write_resp_o ( axi_write_rsp    ),
    .mst_req_o        ( axi_mst_be_req_o ),
    .mst_resp_i       ( axi_mst_be_rsp_i )
  );

  assign irq_o = desc64_irq | reg64_irq;
  assign axis_irq_o = desc64_axis_irq_pulse;
  assign dbg_idma_req_src_addr = idma_req.src_addr;
  assign dbg_idma_req_dst_addr = idma_req.dst_addr;
  assign dbg_idma_req_length = idma_req.length;

endmodule

module idma_fe_arb #(
  parameter int unsigned NumFrontends = 0,
  parameter type idma_req_t = logic,
  parameter type idma_rsp_t = logic
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  idma_req_t [NumFrontends-1:0] idma_req_fe_i,
  input  logic [NumFrontends-1:0] idma_req_fe_valid_i,
  output logic [NumFrontends-1:0] idma_req_fe_ready_o,
  output idma_rsp_t [NumFrontends-1:0] idma_rsp_fe_o,
  output logic [NumFrontends-1:0] idma_rsp_fe_valid_o,
  input  logic [NumFrontends-1:0] idma_rsp_fe_ready_i,
  output idma_req_t idma_req_be_o,
  output logic idma_req_be_valid_o,
  input  logic idma_req_be_ready_i,
  input  idma_rsp_t idma_rsp_be_i,
  input  logic idma_rsp_be_valid_i,
  output logic idma_rsp_be_ready_o
);

  `include "common_cells/registers.svh"

  localparam int unsigned FrontendIdxWidth =
      (NumFrontends > 32'd1) ? unsigned'($clog2(NumFrontends)) : 32'd1;

  (* mark_debug = "true" *) logic [NumFrontends-1:0] idma_req_fe_valid;
  (* mark_debug = "true" *) logic [NumFrontends-1:0] idma_req_fe_ready;
  (* mark_debug = "true" *) logic idma_req_be_valid;
  (* mark_debug = "true" *) logic idma_rsp_be_ready;
  (* mark_debug = "true" *) logic [FrontendIdxWidth-1:0] idma_fe_idx;
  (* mark_debug = "true" *) logic [FrontendIdxWidth-1:0] idma_fe_idx_q;
  (* mark_debug = "true" *) logic [5:0] ongoing_req_cnt_d;
  (* mark_debug = "true" *) logic [5:0] ongoing_req_cnt_q;
  (* mark_debug = "true" *) bit is_new_idma_req;
  (* mark_debug = "true" *) bit is_new_idma_rsp;

  rr_arb_tree #(
    .NumIn     ( NumFrontends ),
    .DataType  ( idma_req_t   ),
    .ExtPrio   ( 1'b0         ),
    .AxiVldRdy ( 1'b1         ),
    .LockIn    ( 1'b1         )
  ) rr_arb_tree_i (
    .clk_i,
    .rst_ni,
    .flush_i ( 1'b0              ),
    .rr_i    ( '0                ),
    .req_i   ( idma_req_fe_valid ),
    .gnt_o   ( idma_req_fe_ready ),
    .data_i  ( idma_req_fe_i     ),
    .gnt_i   ( idma_req_be_ready_i ),
    .req_o   ( idma_req_be_valid ),
    .data_o  ( idma_req_be_o     ),
    .idx_o   ( idma_fe_idx       )
  );

  assign idma_req_be_valid_o = idma_req_be_valid;
  assign idma_rsp_be_ready_o = idma_rsp_be_ready;
  assign is_new_idma_req = idma_req_be_valid && idma_req_be_ready_i;
  assign is_new_idma_rsp = idma_rsp_be_valid_i && idma_rsp_be_ready;

  always_comb begin
    idma_req_fe_valid = '0;
    idma_req_fe_ready_o = '0;
    if (ongoing_req_cnt_q > 0) begin
      idma_req_fe_valid[idma_fe_idx_q] = idma_req_fe_valid_i[idma_fe_idx_q];
      idma_req_fe_ready_o[idma_fe_idx_q] = idma_req_fe_ready[idma_fe_idx_q];
    end else begin
      idma_req_fe_valid = idma_req_fe_valid_i;
      idma_req_fe_ready_o = idma_req_fe_ready;
    end
  end

  always_comb begin
    idma_rsp_fe_o = '0;
    idma_rsp_fe_valid_o = '0;
    idma_rsp_be_ready = '0;
    if (ongoing_req_cnt_q > 0) begin
      idma_rsp_fe_o[idma_fe_idx_q] = idma_rsp_be_i;
      idma_rsp_fe_valid_o[idma_fe_idx_q] = idma_rsp_be_valid_i;
      idma_rsp_be_ready = idma_rsp_fe_ready_i[idma_fe_idx_q];
    end else begin
      idma_rsp_fe_o[idma_fe_idx] = idma_rsp_be_i;
      idma_rsp_fe_valid_o[idma_fe_idx] = idma_rsp_be_valid_i;
      idma_rsp_be_ready = idma_rsp_fe_ready_i[idma_fe_idx];
    end
  end

  always_comb begin
    ongoing_req_cnt_d = ongoing_req_cnt_q;
    if (ongoing_req_cnt_q > 0) begin
      if (is_new_idma_req && !is_new_idma_rsp)
        ongoing_req_cnt_d = ongoing_req_cnt_q + 1;
      else if (!is_new_idma_req && is_new_idma_rsp)
        ongoing_req_cnt_d = ongoing_req_cnt_q - 1;
    end else if (is_new_idma_req) begin
      ongoing_req_cnt_d = ongoing_req_cnt_q + 1;
    end
  end

  `FF(ongoing_req_cnt_q, ongoing_req_cnt_d, '0, clk_i, rst_ni)
  `FFL(idma_fe_idx_q, idma_fe_idx, ongoing_req_cnt_q == 0, '0, clk_i, rst_ni)

endmodule
