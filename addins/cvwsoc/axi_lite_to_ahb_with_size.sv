`include "axi/typedef.svh"

// Small AXI-Lite to AHB-Lite bridge.  AXI-Lite is 32-bit, while
// the retained Wally AHB system may be wider.  The original AXI transfer size
// is carried separately because AXI-Lite itself has no SIZE signal.
module axi_lite_to_ahb_with_size #(
    parameter int unsigned ADDR_W = 32,
    parameter int unsigned DATA_W = 32,
    parameter int unsigned AHB_DATA_W = DATA_W,
    parameter type axi_lite_req_t = logic,
    parameter type axi_lite_resp_t = logic
  ) (
    input logic clk_i, rst_ni,
    input axi_lite_req_t axi_req_i,
    output axi_lite_resp_t axi_resp_o,
    input logic [2:0] awsize_i,
    input logic [2:0] arsize_i,
    output logic [ADDR_W-1:0] HADDR,
    output logic [AHB_DATA_W-1:0] HWDATA,
    output logic [AHB_DATA_W/8-1:0] HWSTRB,
    output logic HWRITE,
    output logic [2:0] HSIZE,
    output logic [2:0] HBURST,
    output logic [3:0] HPROT,
    output logic [1:0] HTRANS,
    output logic HMASTLOCK,
    input logic [AHB_DATA_W-1:0] HRDATA,
    input logic HREADY,
    input logic HRESP
  );
  typedef enum logic [2:0] {IDLE, WRITE_ADDR, WRITE, WRESP,
                            READ_ADDR, READ, RRESP} state_t;
  state_t state_q;
  logic aw_hold_q, w_hold_q;
  logic [ADDR_W-1:0] awaddr_q, araddr_q;
  logic [DATA_W-1:0] wdata_q;
  logic [DATA_W/8-1:0] wstrb_q;
  logic [2:0] awprot_q, arprot_q;
  logic [2:0] awsize_q, arsize_q;
  logic [DATA_W-1:0] rdata_q;
  logic [DATA_W-1:0] hrdata_selected;
  axi_pkg::resp_t resp_q;

  // The normal CVWSoC path keeps AXI-Lite and AHB equally wide.  Retain the
  // 32-to-64 lane mapping for an explicitly narrower AXI-Lite instantiation.
  generate
    if (AHB_DATA_W == DATA_W) begin : gen_equal_width
      assign HWDATA = wdata_q;
      assign HWSTRB = wstrb_q;
      assign hrdata_selected = HRDATA;
    end else if (AHB_DATA_W == 2 * DATA_W) begin : gen_half_width
      assign HWDATA = HADDR[2] ? {wdata_q, {DATA_W{1'b0}}} :
                                {{DATA_W{1'b0}}, wdata_q};
      assign HWSTRB = HADDR[2] ? {wstrb_q, {DATA_W/8{1'b0}}} :
                                {{DATA_W/8{1'b0}}, wstrb_q};
      assign hrdata_selected = HRDATA[(HADDR[2] ? DATA_W : 0) +: DATA_W];
    end else begin : gen_unsupported_width
      initial $fatal(1, "axi_lite_to_ahb_with_size   requires equal widths or AHB_DATA_W == 2*DATA_W");
      assign HWDATA = '0;
      assign HWSTRB = '0;
      assign hrdata_selected = '0;
    end
  endgenerate

  always_comb begin
    axi_resp_o = '0;
    axi_resp_o.aw_ready = (state_q == IDLE) && !aw_hold_q;
    axi_resp_o.w_ready  = (state_q == IDLE) && !w_hold_q;
    axi_resp_o.ar_ready = (state_q == IDLE) && !aw_hold_q && !w_hold_q;
    axi_resp_o.b.resp = resp_q;
    axi_resp_o.b_valid = (state_q == WRESP);
    axi_resp_o.r.data = rdata_q;
    axi_resp_o.r.resp = resp_q;
    axi_resp_o.r_valid = (state_q == RRESP);
    HADDR = ((state_q == READ_ADDR) || (state_q == READ)) ? araddr_q : awaddr_q;
    HWRITE = (state_q == WRITE_ADDR) || (state_q == WRITE);
    HSIZE = ((state_q == READ_ADDR) || (state_q == READ)) ? arsize_q : awsize_q;
    HBURST = 3'b000;
    HPROT = {1'b0, 1'b0,
             (((state_q == READ_ADDR) || (state_q == READ)) ? arprot_q[0] : awprot_q[0]),
             1'b1};
    // HTRANS describes the AHB address phase.  Once that address phase has
    // been accepted, drive IDLE while waiting for its data phase to complete.
    // Keeping NONSEQ asserted in WRITE/READ causes a slave that returns
    // HREADY to accept the same request as a second AHB transaction.
    HTRANS = ((state_q == WRITE_ADDR) || (state_q == READ_ADDR)) ?
             2'b10 : 2'b00;
    HMASTLOCK = 1'b0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      aw_hold_q <= 1'b0;
      w_hold_q <= 1'b0;
      resp_q <= axi_pkg::RESP_OKAY;
      rdata_q <= '0;
      awsize_q <= '0;
      arsize_q <= '0;
    end else begin
      if (axi_req_i.aw_valid && axi_resp_o.aw_ready) begin
        aw_hold_q <= 1'b1;
        awaddr_q <= axi_req_i.aw.addr;
        awprot_q <= axi_req_i.aw.prot;
        awsize_q <= awsize_i;
      end
      if (axi_req_i.w_valid && axi_resp_o.w_ready) begin
        w_hold_q <= 1'b1;
        wdata_q <= axi_req_i.w.data;
        wstrb_q <= axi_req_i.w.strb;
      end
      case (state_q)
        IDLE: begin
          if (axi_req_i.ar_valid && axi_resp_o.ar_ready) begin
            araddr_q <= axi_req_i.ar.addr;
            arprot_q <= axi_req_i.ar.prot;
            arsize_q <= arsize_i;
            state_q <= READ_ADDR;
          end else if ((aw_hold_q || (axi_req_i.aw_valid && axi_resp_o.aw_ready)) &&
                       (w_hold_q || (axi_req_i.w_valid && axi_resp_o.w_ready))) begin
            state_q <= WRITE_ADDR;
          end
        end
        WRITE_ADDR: state_q <= WRITE;
        WRITE: if (HREADY) begin
          resp_q <= HRESP ? axi_pkg::RESP_SLVERR : axi_pkg::RESP_OKAY;
          aw_hold_q <= 1'b0;
          w_hold_q <= 1'b0;
          state_q <= WRESP;
        end
        WRESP: if (axi_req_i.b_ready) state_q <= IDLE;
        READ_ADDR: state_q <= READ;
        READ: if (HREADY) begin
          rdata_q <= hrdata_selected;
          resp_q <= HRESP ? axi_pkg::RESP_SLVERR : axi_pkg::RESP_OKAY;
          state_q <= RRESP;
        end
        RRESP: if (axi_req_i.r_ready) state_q <= IDLE;
        default: state_q <= IDLE;
      endcase
    end
  end
endmodule
