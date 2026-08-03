`include "axi/typedef.svh"

module cvwsoc_cpu import cvw::*; #(
  parameter cvw_t P,
  parameter int unsigned AXI_ID_W = 2,
  parameter type cpu_axi_req_t = logic,
  parameter type cpu_axi_resp_t = logic
) (
  input logic clk_i, rst_ni, time_clk_i,
  input logic meip_i, seip_i, external_stall_i,
  output cpu_axi_req_t axi_req_o,
  input cpu_axi_resp_t axi_resp_i
);

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
  clint_apb_req_t [0:0] apb_req;
  clint_apb_resp_t [0:0] apb_resp;
  // rele for axil-to-apb
  localparam rule_t [0:0] CLINT_MAP = '{'{idx:0, start_addr:P.CLINT_BASE[31:0],
                                            end_addr:P.CLINT_BASE[31:0] + P.CLINT_RANGE[31:0] + 1}};
  logic [63:0] mtime;
  logic mtip, msip;
  logic aw_clint, ar_clint;
  assign aw_clint = (wally_req.aw.addr >= P.CLINT_BASE[31:0]) &&
                    (wally_req.aw.addr <= P.CLINT_BASE[31:0] + P.CLINT_RANGE[31:0]);
  assign ar_clint = (wally_req.ar.addr >= P.CLINT_BASE[31:0]) &&
                    (wally_req.ar.addr <= P.CLINT_BASE[31:0] + P.CLINT_RANGE[31:0]);


  // CDC: PLIC signals
  logic meip_synced_i, seip_synced_i, external_stall_synced_i;
  synchronizer sync_meip (clk_i, meip_i, meip_synced_i);
  synchronizer sync_seip (clk_i, seip_i, seip_synced_i);
  synchronizer sync_ext_stall (clk_i, external_stall_i, external_stall_synced_i);


  cvwsoc_cpu_wally #(.P(P), .AXI_ID_W(AXI_ID_W),
    .axi_req_t(cpu_int_req_t), .axi_resp_t(cpu_int_resp_t)
  )  wally (
    .clk_i, 
    .rst_ni, .mtime_i(mtime), .mtip_i(mtip), .msip_i(msip),
    .meip_i(meip_synced_i),
    .seip_i(seip_synced_i),
    .external_stall_i(external_stall_synced_i), 
    .axi_req_o(wally_req),
    .axi_resp_i(wally_resp) );

  axi_demux #(
    .AxiIdWidth(AXI_ID_W),
    .AxiLookBits(AXI_ID_W),
    .AtopSupport(1'b0),
    .aw_chan_t(cpu_int_aw_chan_t),
    .w_chan_t(cpu_int_w_chan_t),
    .b_chan_t(cpu_int_b_chan_t),
    .ar_chan_t(cpu_int_ar_chan_t),
    .r_chan_t(cpu_int_r_chan_t),
    .axi_req_t(cpu_int_req_t),
    .axi_resp_t(cpu_int_resp_t),
    .NoMstPorts(2),
    .MaxTrans(2)
  ) demux (
    .clk_i, .rst_ni, .test_i(1'b0), .slv_req_i(wally_req),
    .slv_aw_select_i(aw_clint ? 1'b0 : 1'b1),
    .slv_ar_select_i(ar_clint ? 1'b0 : 1'b1),
    .slv_resp_o(wally_resp),
    .mst_reqs_o(demux_req),
    .mst_resps_i(demux_resp) );

  assign axi_req_o = demux_req[1];
  assign demux_resp[1] = axi_resp_i;
  axi_to_axi_lite #(.AxiAddrWidth(32), .AxiDataWidth(P.AHBW),
    .AxiIdWidth(AXI_ID_W), 
    .AxiUserWidth(1), 
    .AxiMaxWriteTxns(1),
    .AxiMaxReadTxns(1), 
    .full_req_t(cpu_int_req_t),
    .full_resp_t(cpu_int_resp_t),
    .lite_req_t(clint_lite_req_t),
    .lite_resp_t(clint_lite_resp_t)
  ) clint_to_lite (
    .clk_i,
    .rst_ni,
    .test_i(1'b0),
    .slv_req_i(demux_req[0]),
    .slv_resp_o(demux_resp[0]),
    .mst_req_o(lite_req),
    .mst_resp_i(lite_resp) );

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

  if (P.CLINT_SUPPORTED) begin : gen_clint
    clint_apb #(P) 
    clint (
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
        .MSwInt(msip) );
    assign apb_resp[0].pslverr = 1'b0;
  end else begin : gen_no_clint
    assign mtime='0; 
    assign mtip=1'b0; 
    assign msip=1'b0;
    assign apb_resp[0] = '{pready:1'b1, prdata:'0, pslverr:1'b1};
  end


endmodule
