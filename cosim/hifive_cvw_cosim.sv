`timescale 1ns/1ps

`include "config.vh"
`include "axi/typedef.svh"
`include "axi_stream/typedef.svh"

import cvw::*;
import cvwsoc_pkg::*;
import renode_pkg::renode_runtime;
`include "parameter-defs.vh"

module hifive_cvw_cosim;
  localparam int unsigned AXI_ADDR_WIDTH = 32;
  localparam int unsigned AXI_DATA_WIDTH = P.AHBW;
  localparam int unsigned CPU_AXI_ID_WIDTH = 2;
  localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;
  localparam time BUS_HALF_PERIOD = 250ns; // 2 MHz
  //localparam time BUS_HALF_PERIOD = 100ns; // 5 MHz
  localparam logic [31:0] CVWSOC_APERTURE_BASE = 32'h1008_0000;

  function automatic cvw_t make_cosim_p(input cvw_t p_in);
    cvw_t p_out;
    p_out = p_in;
    //p_out.AXI_SDHCI_SUPPORTED   = 1'b0;
    //p_out.AXI_USB_SUPPORTED     = 1'b0;
    //p_out.AXI_ETH_SUPPORTED     = 1'b1;
    //p_out.AXI_ETH_SUPPORTED     = 1'b0;
    //p_out.AXIS_I2S_SUPPORTED    = 1'b0;
    return p_out;
  endfunction

  localparam cvw_t P_COSIM = make_cosim_p(P);
  localparam cvwsoc_cfg_t C = '{
    wally: P_COSIM,
    mem_type: CVWSOC_MEM_XILINX_DDR2, // semantic only; cvwsoc_ram is absent
    idma_config: '{AxisDescReqCut: 1'b1},
    vga_config:  '{CutSplitterPath: 1'b1},
    sdhci_config:'{InsertRegClkBuf: 1'b0}
  };

  localparam xbar_out_t XBAR_OUT = gen_xbar_out(P_COSIM);
  localparam int unsigned DDR_AXI_ID_WIDTH =
      CPU_AXI_ID_WIDTH + $clog2(XBAR_OUT.n_slv);

  typedef logic [AXI_ADDR_WIDTH-1:0] cpu_axi_addr_t;
  typedef logic [CPU_AXI_ID_WIDTH-1:0] cpu_axi_id_t;
  typedef logic [AXI_DATA_WIDTH-1:0] cpu_axi_data_t;
  typedef logic [AXI_STRB_WIDTH-1:0] cpu_axi_strb_t;
  typedef logic cpu_axi_user_t;
  `AXI_TYPEDEF_ALL_CT(cpu_axi, cpu_axi_req_t, cpu_axi_resp_t,
                      cpu_axi_addr_t, cpu_axi_id_t, cpu_axi_data_t,
                      cpu_axi_strb_t, cpu_axi_user_t)

  typedef logic [DDR_AXI_ID_WIDTH-1:0] ddr_axi_id_t;
  `AXI_TYPEDEF_ALL_CT(ddr_axi, ddr_axi_req_t, ddr_axi_resp_t,
                      cpu_axi_addr_t, ddr_axi_id_t, cpu_axi_data_t,
                      cpu_axi_strb_t, cpu_axi_user_t)
  `AXI_TYPEDEF_ALL_CT(ddr_csr_axi, ddr_csr_axi_req_t, ddr_csr_axi_resp_t,
                      cpu_axi_addr_t, ddr_axi_id_t, cpu_axi_data_t,
                      cpu_axi_strb_t, cpu_axi_user_t)

  localparam int unsigned RenodeToCosimCount = 1;
  localparam int unsigned CosimToRenodeCount = 1;
  localparam int unsigned RenodeInputsCount  = 4;
  localparam int unsigned RenodeOutputsCount = 0;

  logic clk = 1'b0;
  logic [RenodeInputsCount-1:0] renode_inputs;
  logic [3:0] cpu_axi_irq;
  logic resetn;

  //logic clk_sdhci;
  logic clk_200M = 1'b0; // needs initialization
  logic clk_audio = 1'b0; // needs initialization
  logic clk_48M = 1'b0; // needs initialization

  cpu_axi_req_t cpu_axi_req;
  cpu_axi_resp_t cpu_axi_resp;
  ddr_axi_req_t ddr_axi_req;
  ddr_axi_resp_t ddr_axi_resp;
  ddr_csr_axi_req_t ddr_csr_axi_req;
  ddr_csr_axi_resp_t ddr_csr_axi_resp;

  renode_runtime runtime = new(RenodeToCosimCount, CosimToRenodeCount);

  renode #(
    .RenodeInputsCount(RenodeInputsCount),
    .RenodeOutputsCount(RenodeOutputsCount),
    .RenodeToCosimCount(RenodeToCosimCount),
    .CosimToRenodeCount(CosimToRenodeCount)
  ) renode_i (
    .runtime(runtime),
    .clk(clk),
    .renode_inputs(renode_inputs),
    .renode_outputs()
  );

  renode_axi_if #(
    .AddressWidth(AXI_ADDR_WIDTH),
    .DataWidth(AXI_DATA_WIDTH),
    .TransactionIdWidth(CPU_AXI_ID_WIDTH)
  ) cpu_bus(clk);

  renode_axi_manager #(.RenodeToCosimIndex(0)) cpu_manager_i (
    .runtime(runtime),
    .bus(cpu_bus)
  );

  renode_axi_if #(
    .AddressWidth(AXI_ADDR_WIDTH),
    .DataWidth(AXI_DATA_WIDTH),
    .TransactionIdWidth(DDR_AXI_ID_WIDTH)
  ) ddr_bus(clk);

  renode_axi_subordinate #(.CosimToRenodeIndex(0)) ddr_subordinate_i (
    .runtime(runtime),
    .bus(ddr_bus)
  );

  initial begin
    runtime.connect_plus_args();
    renode_i.reset();
  end

  always @(posedge clk) begin
    renode_i.receive_and_handle_message();
    if (!runtime.is_connected()) $finish;
  end

  always #(BUS_HALF_PERIOD) clk = ~clk;  

  //-----------------------
  // Other clocks generation
  //-----------------------
//   generate
//    if (P_COSIM.AXI_ETH_SUPPORTED) begin : gen_eth_clock
//        always #2.5ns clk_200M = ~clk_200M;     // 200 MHz
//    end
//   endgenerate  
  // Disabled for performance reasons
//   generate
//     if (P_COSIM.AXIS_I2S_SUPPORTED) begin : gen_audio_clock
//         always #22.1443ns clk_audio = ~clk_audio; // 22.5792 MHz  
//     end
//   endgenerate  
  // 48 MHz clk disabled: disabled for performance reasons
//   generate
//     if (P_COSIM.AXI_USB_SUPPORTED) begin : gen_usb_clock
//         always #10.417ns clk_48M = ~clk_48M; // approximately 48 MHz
//     end
//   endgenerate  


  assign resetn = cpu_bus.areset_n & ddr_bus.areset_n;
  assign renode_inputs = cpu_axi_irq;

  // Renode gives the co-sim peripheral an offset within its aperture.
  always_comb begin
    cpu_axi_req = '0;
    cpu_axi_req.aw.id     = cpu_bus.awid;
    //cpu_axi_req.aw.addr   = cpu_bus.awaddr + CVWSOC_APERTURE_BASE;
    cpu_axi_req.aw.addr   = cpu_bus.awaddr;
    cpu_axi_req.aw.len    = cpu_bus.awlen;
    cpu_axi_req.aw.size   = cpu_bus.awsize;
    cpu_axi_req.aw.burst  = cpu_bus.awburst;
    cpu_axi_req.aw.lock   = cpu_bus.awlock;
    cpu_axi_req.aw.cache  = cpu_bus.awcache;
    cpu_axi_req.aw.prot   = cpu_bus.awprot;
    //cpu_axi_req.aw.qos    = cpu_bus.awqos;
    //cpu_axi_req.aw.region = cpu_bus.awregion;
    //cpu_axi_req.aw.atop   = cpu_bus.awatop;
    cpu_axi_req.aw.qos    = '0;
    cpu_axi_req.aw.region = '0;
    cpu_axi_req.aw.atop   = '0;
    cpu_axi_req.aw.user   = '0;
    cpu_axi_req.aw_valid  = cpu_bus.awvalid;
    cpu_axi_req.w.data    = cpu_bus.wdata;
    cpu_axi_req.w.strb    = cpu_bus.wstrb;
    cpu_axi_req.w.last    = cpu_bus.wlast;
    cpu_axi_req.w.user    = '0;
    cpu_axi_req.w_valid   = cpu_bus.wvalid;
    cpu_axi_req.b_ready   = cpu_bus.bready;
    cpu_axi_req.ar.id     = cpu_bus.arid;
    //cpu_axi_req.ar.addr   = cpu_bus.araddr + CVWSOC_APERTURE_BASE;
    cpu_axi_req.ar.addr   = cpu_bus.araddr;
    cpu_axi_req.ar.len    = cpu_bus.arlen;
    cpu_axi_req.ar.size   = cpu_bus.arsize;
    cpu_axi_req.ar.burst  = cpu_bus.arburst;
    cpu_axi_req.ar.lock   = cpu_bus.arlock;
    cpu_axi_req.ar.cache  = cpu_bus.arcache;
    cpu_axi_req.ar.prot   = cpu_bus.arprot;
    //cpu_axi_req.ar.qos    = cpu_bus.arqos;
    //cpu_axi_req.ar.region = cpu_bus.arregion;
    cpu_axi_req.ar.qos    = '0;
    cpu_axi_req.ar.region = '0;
    cpu_axi_req.ar.user   = '0;
    cpu_axi_req.ar_valid  = cpu_bus.arvalid;
    cpu_axi_req.r_ready   = cpu_bus.rready;
  end

  assign cpu_bus.awready = cpu_axi_resp.aw_ready;
  assign cpu_bus.wready  = cpu_axi_resp.w_ready;
  assign cpu_bus.bid     = cpu_axi_resp.b.id;
  assign cpu_bus.bresp   = cpu_axi_resp.b.resp;
  assign cpu_bus.bvalid  = cpu_axi_resp.b_valid;
  assign cpu_bus.arready = cpu_axi_resp.ar_ready;
  assign cpu_bus.rid     = cpu_axi_resp.r.id;
  assign cpu_bus.rdata   = cpu_axi_resp.r.data;
  assign cpu_bus.rresp   = cpu_axi_resp.r.resp;
  assign cpu_bus.rlast   = cpu_axi_resp.r.last;
  assign cpu_bus.rvalid  = cpu_axi_resp.r_valid;

  // RTL masters (VGA/iDMA) access full Renode physical addresses.
  assign ddr_bus.awid     = ddr_axi_req.aw.id;
  assign ddr_bus.awaddr   = ddr_axi_req.aw.addr;
  assign ddr_bus.awlen    = ddr_axi_req.aw.len;
  assign ddr_bus.awsize   = ddr_axi_req.aw.size;
  assign ddr_bus.awburst  = ddr_axi_req.aw.burst;
  assign ddr_bus.awlock   = ddr_axi_req.aw.lock;
  assign ddr_bus.awcache  = ddr_axi_req.aw.cache;
  assign ddr_bus.awprot   = ddr_axi_req.aw.prot;
  //assign ddr_bus.awqos    = ddr_axi_req.aw.qos;
  //assign ddr_bus.awregion = ddr_axi_req.aw.region;
  //assign ddr_bus.awatop   = ddr_axi_req.aw.atop;
  assign ddr_bus.awvalid  = ddr_axi_req.aw_valid;
  assign ddr_bus.wdata    = ddr_axi_req.w.data;
  assign ddr_bus.wstrb    = ddr_axi_req.w.strb;
  assign ddr_bus.wlast    = ddr_axi_req.w.last;
  assign ddr_bus.wvalid   = ddr_axi_req.w_valid;
  assign ddr_bus.bready   = ddr_axi_req.b_ready;
  assign ddr_bus.arid     = ddr_axi_req.ar.id;
  assign ddr_bus.araddr   = ddr_axi_req.ar.addr;
  assign ddr_bus.arlen    = ddr_axi_req.ar.len;
  assign ddr_bus.arsize   = ddr_axi_req.ar.size;
  assign ddr_bus.arburst  = ddr_axi_req.ar.burst;
  assign ddr_bus.arlock   = ddr_axi_req.ar.lock;
  assign ddr_bus.arcache  = ddr_axi_req.ar.cache;
  assign ddr_bus.arprot   = ddr_axi_req.ar.prot;
  //assign ddr_bus.arqos    = ddr_axi_req.ar.qos;
  //assign ddr_bus.arregion = ddr_axi_req.ar.region;
  assign ddr_bus.arvalid  = ddr_axi_req.ar_valid;
  assign ddr_bus.rready   = ddr_axi_req.r_ready;

  always_comb begin
    ddr_axi_resp = '0;
    ddr_axi_resp.aw_ready = ddr_bus.awready;
    ddr_axi_resp.w_ready  = ddr_bus.wready;
    ddr_axi_resp.b.id     = ddr_bus.bid;
    ddr_axi_resp.b.resp   = ddr_bus.bresp;
    ddr_axi_resp.b.user   = '0;
    ddr_axi_resp.b_valid  = ddr_bus.bvalid;
    ddr_axi_resp.ar_ready = ddr_bus.arready;
    ddr_axi_resp.r.id     = ddr_bus.rid;
    ddr_axi_resp.r.data   = ddr_bus.rdata;
    ddr_axi_resp.r.resp   = ddr_bus.rresp;
    ddr_axi_resp.r.last   = ddr_bus.rlast;
    ddr_axi_resp.r.user   = '0;
    ddr_axi_resp.r_valid  = ddr_bus.rvalid;
  end

  // LiteDRAM CSR is disabled in P_COSIM.
  assign ddr_csr_axi_resp = '0;

  wire usb0_dp, usb0_dm, usb1_dp, usb1_dm;
  wire sd_clk;
  // Match testbench_cvwsoc's sd_card wrapper: an SD bus has pull-ups on CMD
  // and DAT lines whenever neither host nor card is actively driving them.
  tri1 sd_cmd;
  tri1 [3:0] sd_dat;
  wire rgmii_mdio;

  cvwsoc_axi #(
    .C(C),
    .CPU_AXI_ID_WIDTH(CPU_AXI_ID_WIDTH),
    .cpu_axi_req_t(cpu_axi_req_t),
    .cpu_axi_resp_t(cpu_axi_resp_t),
    .ddr_axi_req_t(ddr_axi_req_t),
    .ddr_axi_resp_t(ddr_axi_resp_t),
    .ddr_csr_axi_req_t(ddr_csr_axi_req_t),
    .ddr_csr_axi_resp_t(ddr_csr_axi_resp_t)
  ) u_cvwsoc_axi (
    .CPUCLK_i(clk), .clk167_i(clk),
    // Disabled for performance
    //.clk200_i(clk_200M), // Not needed for now
    .clk200_i(clk),
    //.clk48MHz_raw_i(clk_48M), 
    .clk48MHz_raw_i(clk), 

    //.audio_clk_i(clk_audio), // disabled for performance reasons
    .audio_clk_i(clk),
    .cpu_clk_locked_i(resetn),
    .peripheral_reset_i(~resetn),
    .peripheral_aresetn_i(resetn),
    .rst_req_i(~resetn), .resetn_comb_i(resetn),

    .rgmii_clocks_rx(1'b0), .rgmii_clocks_tx(), .rgmii_int_n(1'b1),
    .rgmii_mdc(), .rgmii_mdio(rgmii_mdio), .rgmii_rst_n(),
    .rgmii_rx_ctl(1'b0), .rgmii_rx_data('0),
    .rgmii_tx_ctl(), .rgmii_tx_data(),

    .vga_hsync(), .vga_vsync(), .vga_r_5(), .vga_g_6(), .vga_b_5(),
    .usb0_dp(usb0_dp), .usb0_dm(usb0_dm),
    .usb1_dp(usb1_dp), .usb1_dm(usb1_dm),
    .SD_CLK(sd_clk), .SD_CD_N(1'b0), .SD_CMD(sd_cmd), .SD_DAT(sd_dat),
    .i2s_tx_mclk(), .i2s_tx_lrck(), .i2s_tx_sclk(), .i2s_tx_sdout(),

    .cpu_axi_req_i(cpu_axi_req), .cpu_axi_resp_o(cpu_axi_resp),
    .ddr_axi_req_o(ddr_axi_req), .ddr_axi_resp_i(ddr_axi_resp),
    .ddr_csr_axi_req_o(ddr_csr_axi_req),
    .ddr_csr_axi_resp_i(ddr_csr_axi_resp),
    .BUSCLK_i(clk), .BUSCORERSTn_i(resetn), .BUSRSTn_i(resetn),
    .cpu_axi_irq_o(cpu_axi_irq)
  );

  // cvwsoc_axi already resolves the host's output-enable signals onto these
  // board-level bidirectional pins. Attach the card model directly; the
  // sd_card wrapper used by testbench_cvwsoc is only needed for its separate
  // host input/output signal pairs.
  generate
    if (P_COSIM.AXI_SDHCI_SUPPORTED) begin : gen_sd_card
      sdModel i_sd_card (
        .sdClk (sd_clk),
        .cmd   (sd_cmd),
        .dat   (sd_dat)
      );
    end
  endgenerate

  initial begin
    assert (AXI_DATA_WIDTH == 64)
      else $fatal(1, "hifive-cvw v6 requires P.AHBW=64");
    assert ($bits(cpu_axi_req.aw.id) == CPU_AXI_ID_WIDTH);
    assert ($bits(ddr_axi_req.aw.id) == DDR_AXI_ID_WIDTH);
  end
endmodule
