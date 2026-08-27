// VexriscvCVWSoC wrapper for the CVWSoC CPU AXI port.
//
// The core has independent AXI instruction and data master ports.  The AXI
// mux extends their one-bit IDs with the source-port index before presenting
// the shared CPU AXI port.
`include "axi/typedef.svh"

module cvwsoc_cpu_vexriscv import cvw::*; #(
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
  typedef logic [0:0]  vex_id_t;
  typedef logic [AXI_ID_W-1:0] axi_id_t;
  typedef logic [63:0] data_t;
  typedef logic [7:0]  strb_t;
  typedef logic        user_t;
  `AXI_TYPEDEF_ALL(vex_axi, addr_t, vex_id_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_ALL(cpu_axi, addr_t, axi_id_t, data_t, strb_t, user_t)

  logic reset;
  logic debug_reset_out;
  logic jtag_tdo;

  vex_axi_req_t  [1:0] vex_axi_req;
  vex_axi_resp_t [1:0] vex_axi_resp;
  cpu_axi_req_t        cpu_axi_req;
  cpu_axi_resp_t       cpu_axi_resp;

  // Instruction AXI master.
  logic i_arvalid, i_arready, i_rvalid, i_rready, i_rlast;
  logic [31:0] i_araddr;
  logic [63:0] i_rdata;
  logic i_arid, i_rid, i_arlock;
  logic [3:0] i_arregion, i_arcache, i_arqos;
  logic [7:0] i_arlen;
  logic [2:0] i_arsize, i_arprot;
  logic [1:0] i_arburst, i_rresp;

  // Data AXI master.
  logic d_awvalid, d_awready, d_wvalid, d_wready, d_wlast;
  logic d_bvalid, d_bready, d_arvalid, d_arready, d_rvalid, d_rready, d_rlast;
  logic [31:0] d_awaddr, d_araddr;
  logic [63:0] d_wdata, d_rdata;
  logic d_awid, d_bid, d_arid, d_rid, d_awlock, d_arlock;
  logic [7:0] d_awlen, d_arlen;
  logic [3:0] d_awregion, d_awcache, d_awqos, d_arregion, d_arcache, d_arqos;
  logic [2:0] d_awsize, d_awprot, d_arsize, d_arprot;
  logic [1:0] d_awburst, d_bresp, d_arburst, d_rresp;
  logic [7:0] d_wstrb;

  assign reset = ~rst_ni;

  // VexriscvCVWSoC has a 64-bit data AXI port.  CVWSoC must therefore use
  // its 64-bit CPU AXI configuration for this core.
  initial begin
    if (P.AHBW != 64) $fatal(1, "VexriscvCVWSoC requires P.AHBW == 64");
    if (AXI_ID_W < 2) $fatal(1, "VexriscvCVWSoC requires AXI_ID_W >= 2");
  end

  VexriscvCVWSoC core (
    .debug_resetOut(debug_reset_out),
    .timerInterrupt(mtip_i),
    .externalInterrupt(meip_i),
    .softwareInterrupt(msip_i),
    .externalInterruptS(seip_i),
    .utime(mtime_i),
    .iBusAxi_arvalid(i_arvalid), .iBusAxi_arready(i_arready),
    .iBusAxi_araddr(i_araddr), .iBusAxi_arid(i_arid), .iBusAxi_arregion(i_arregion),
    .iBusAxi_arlen(i_arlen), .iBusAxi_arsize(i_arsize), .iBusAxi_arburst(i_arburst),
    .iBusAxi_arlock(i_arlock), .iBusAxi_arcache(i_arcache), .iBusAxi_arqos(i_arqos),
    .iBusAxi_arprot(i_arprot), .iBusAxi_rvalid(i_rvalid), .iBusAxi_rready(i_rready),
    .iBusAxi_rdata(i_rdata), .iBusAxi_rid(i_rid), .iBusAxi_rresp(i_rresp),
    .iBusAxi_rlast(i_rlast),
    .dBusAxi_awvalid(d_awvalid), .dBusAxi_awready(d_awready),
    .dBusAxi_awaddr(d_awaddr), .dBusAxi_awid(d_awid), .dBusAxi_awregion(d_awregion),
    .dBusAxi_awlen(d_awlen), .dBusAxi_awsize(d_awsize), .dBusAxi_awburst(d_awburst),
    .dBusAxi_awlock(d_awlock), .dBusAxi_awcache(d_awcache), .dBusAxi_awqos(d_awqos),
    .dBusAxi_awprot(d_awprot), .dBusAxi_wvalid(d_wvalid), .dBusAxi_wready(d_wready),
    .dBusAxi_wdata(d_wdata), .dBusAxi_wstrb(d_wstrb), .dBusAxi_wlast(d_wlast),
    .dBusAxi_bvalid(d_bvalid), .dBusAxi_bready(d_bready), .dBusAxi_bid(d_bid),
    .dBusAxi_bresp(d_bresp), .dBusAxi_arvalid(d_arvalid), .dBusAxi_arready(d_arready),
    .dBusAxi_araddr(d_araddr), .dBusAxi_arid(d_arid), .dBusAxi_arregion(d_arregion),
    .dBusAxi_arlen(d_arlen), .dBusAxi_arsize(d_arsize), .dBusAxi_arburst(d_arburst),
    .dBusAxi_arlock(d_arlock), .dBusAxi_arcache(d_arcache), .dBusAxi_arqos(d_arqos),
    .dBusAxi_arprot(d_arprot), .dBusAxi_rvalid(d_rvalid), .dBusAxi_rready(d_rready),
    .dBusAxi_rdata(d_rdata), .dBusAxi_rid(d_rid), .dBusAxi_rresp(d_rresp),
    .dBusAxi_rlast(d_rlast),
    //.jtag_tms(1'b0), .jtag_tdi(1'b0), .jtag_tdo(jtag_tdo), .jtag_tck(1'b0),
    .clk(clk_i), .reset(reset), .debugReset(1'b0)
  );

  // VexriscvCVWSoC data is 64-bit, matching the required P.AHBW setting.
  // The instruction master is read-only; unused write fields stay at zero.
  always_comb begin
    vex_axi_req = '{default:'0};
    vex_axi_req[0].ar = '{id:i_arid, addr:i_araddr, len:i_arlen, size:i_arsize,
                          burst:i_arburst, lock:i_arlock, cache:i_arcache,
                          prot:i_arprot, qos:i_arqos, region:i_arregion, user:'0};
    vex_axi_req[0].ar_valid = i_arvalid;
    vex_axi_req[0].r_ready = i_rready;

    vex_axi_req[1].aw = '{id:d_awid, addr:d_awaddr, len:d_awlen, size:d_awsize,
                          burst:d_awburst, lock:d_awlock, cache:d_awcache,
                          prot:d_awprot, qos:d_awqos, region:d_awregion, atop:'0, user:'0};
    vex_axi_req[1].aw_valid = d_awvalid;
    vex_axi_req[1].w = '{data:d_wdata, strb:d_wstrb, last:d_wlast, user:'0};
    vex_axi_req[1].w_valid = d_wvalid;
    vex_axi_req[1].b_ready = d_bready;
    vex_axi_req[1].ar = '{id:d_arid, addr:d_araddr, len:d_arlen, size:d_arsize,
                          burst:d_arburst, lock:d_arlock, cache:d_arcache,
                          prot:d_arprot, qos:d_arqos, region:d_arregion, user:'0};
    vex_axi_req[1].ar_valid = d_arvalid;
    vex_axi_req[1].r_ready = d_rready;

    i_arready = vex_axi_resp[0].ar_ready;
    i_rvalid = vex_axi_resp[0].r_valid;
    i_rdata = vex_axi_resp[0].r.data;
    i_rid = vex_axi_resp[0].r.id;
    i_rresp = vex_axi_resp[0].r.resp;
    i_rlast = vex_axi_resp[0].r.last;

    d_awready = vex_axi_resp[1].aw_ready;
    d_wready = vex_axi_resp[1].w_ready;
    d_bvalid = vex_axi_resp[1].b_valid;
    d_bid = vex_axi_resp[1].b.id;
    d_bresp = vex_axi_resp[1].b.resp;
    d_arready = vex_axi_resp[1].ar_ready;
    d_rvalid = vex_axi_resp[1].r_valid;
    d_rdata = vex_axi_resp[1].r.data;
    d_rid = vex_axi_resp[1].r.id;
    d_rresp = vex_axi_resp[1].r.resp;
    d_rlast = vex_axi_resp[1].r.last;

    axi_req_o = '0;
    axi_req_o.aw = '{id:cpu_axi_req.aw.id, addr:cpu_axi_req.aw.addr, len:cpu_axi_req.aw.len,
                    size:cpu_axi_req.aw.size, burst:cpu_axi_req.aw.burst, lock:cpu_axi_req.aw.lock,
                    cache:cpu_axi_req.aw.cache, prot:cpu_axi_req.aw.prot, qos:cpu_axi_req.aw.qos,
                    region:cpu_axi_req.aw.region, atop:cpu_axi_req.aw.atop, user:'0};
    axi_req_o.aw_valid = cpu_axi_req.aw_valid;
    axi_req_o.w = '{data:cpu_axi_req.w.data, strb:cpu_axi_req.w.strb,
                   last:cpu_axi_req.w.last, user:'0};
    axi_req_o.w_valid = cpu_axi_req.w_valid;
    axi_req_o.b_ready = cpu_axi_req.b_ready;
    axi_req_o.ar = '{id:cpu_axi_req.ar.id, addr:cpu_axi_req.ar.addr, len:cpu_axi_req.ar.len,
                    size:cpu_axi_req.ar.size, burst:cpu_axi_req.ar.burst, lock:cpu_axi_req.ar.lock,
                    cache:cpu_axi_req.ar.cache, prot:cpu_axi_req.ar.prot, qos:cpu_axi_req.ar.qos,
                    region:cpu_axi_req.ar.region, user:'0};
    axi_req_o.ar_valid = cpu_axi_req.ar_valid;
    axi_req_o.r_ready = cpu_axi_req.r_ready;

    cpu_axi_resp = '0;
    cpu_axi_resp.aw_ready = axi_resp_i.aw_ready;
    cpu_axi_resp.w_ready = axi_resp_i.w_ready;
    cpu_axi_resp.b_valid = axi_resp_i.b_valid;
    cpu_axi_resp.b = '{id:axi_resp_i.b.id, resp:axi_resp_i.b.resp, user:'0};
    cpu_axi_resp.ar_ready = axi_resp_i.ar_ready;
    cpu_axi_resp.r_valid = axi_resp_i.r_valid;
    cpu_axi_resp.r = '{id:axi_resp_i.r.id, data:axi_resp_i.r.data,
                      resp:axi_resp_i.r.resp, last:axi_resp_i.r.last, user:'0};
  end

  axi_mux #(
    .SlvAxiIDWidth(1),
    .slv_aw_chan_t(vex_axi_aw_chan_t), .mst_aw_chan_t(cpu_axi_aw_chan_t),
    .w_chan_t(vex_axi_w_chan_t),
    .slv_b_chan_t(vex_axi_b_chan_t), .mst_b_chan_t(cpu_axi_b_chan_t),
    .slv_ar_chan_t(vex_axi_ar_chan_t), .mst_ar_chan_t(cpu_axi_ar_chan_t),
    .slv_r_chan_t(vex_axi_r_chan_t), .mst_r_chan_t(cpu_axi_r_chan_t),
    .slv_req_t(vex_axi_req_t), .slv_resp_t(vex_axi_resp_t),
    .mst_req_t(cpu_axi_req_t), .mst_resp_t(cpu_axi_resp_t),
    .NoSlvPorts(2), .MaxWTrans(8)
  ) axi_i_d_mux (
    .clk_i(clk_i), .rst_ni(rst_ni), .test_i(1'b0),
    .slv_reqs_i(vex_axi_req), .slv_resps_o(vex_axi_resp),
    .mst_req_o(cpu_axi_req), .mst_resp_i(cpu_axi_resp)
  );

endmodule
