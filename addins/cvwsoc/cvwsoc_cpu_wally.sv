module cvwsoc_cpu_wally import cvw::*; #(
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
  logic reset;
  logic HCLK, HRESETn;
  // AHB
  (* mark_debug = "true" *)logic HWRITE, HMASTLOCK, HREADY, HRESP;
  (* mark_debug = "true" *)logic [P.PA_BITS-1:0] HADDR;
  (* mark_debug = "true" *)logic [P.AHBW-1:0] HWDATA, HRDATA;
  (* mark_debug = "true" *)logic [P.AHBW/8-1:0] HWSTRB;
  (* mark_debug = "true" *)logic [2:0] HSIZE, HBURST;
  (* mark_debug = "true" *)logic [3:0] HPROT;
  (* mark_debug = "true" *)logic [1:0] HTRANS;

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
  (* mark_debug = "true" *) logic hsel_axi, hready_axi;
  logic hsel_axi_d, hresp_axi;
  logic [P.AHBW-1:0] hrdata_axi;

  function automatic logic in_range(
      input logic [31:0] addr, input logic [63:0] base, input logic [63:0] range);
    logic [63:0] end_addr;
    begin
      end_addr = base + range;
      return (addr >= base[31:0]) && (addr <= end_addr[31:0]);
    end
  endfunction

  // Replacement for uncore's HSELEXT.  Do not send speculative
  // or unmapped AHB address phases to AXI: unlike the legacy uncore's
  // HSELNoneD path, an AXI error response can arrive after the IFU has moved
  // on and poison a later cache refill.
  always_comb begin
    hsel_axi =
      in_range(HADDR[31:0], P.EXT_MEM_BASE, P.EXT_MEM_RANGE) ||
      (P.BOOTROM_SUPPORTED && in_range(HADDR[31:0], P.BOOTROM_BASE, P.BOOTROM_RANGE)) ||
      (P.UNCORE_RAM_SUPPORTED && in_range(HADDR[31:0], P.UNCORE_RAM_BASE, P.UNCORE_RAM_RANGE)) ||
      (P.GPIO_SUPPORTED && in_range(HADDR[31:0], P.GPIO_BASE, P.GPIO_RANGE)) ||
      (P.UART_SUPPORTED && in_range(HADDR[31:0], P.UART_BASE, P.UART_RANGE)) ||
      (P.PLIC_SUPPORTED && in_range(HADDR[31:0], P.PLIC_BASE, P.PLIC_RANGE)) ||
      (P.SDC_SUPPORTED && in_range(HADDR[31:0], P.SDC_BASE, P.SDC_RANGE)) ||
      (P.SPI_SUPPORTED && in_range(HADDR[31:0], P.SPI_BASE, P.SPI_RANGE)) ||
      (P.CLINT_SUPPORTED && in_range(HADDR[31:0], P.CLINT_BASE, P.CLINT_RANGE)) ||
      (P.WISHBONE_SUPPORTED && in_range(HADDR[31:0], P.WISHBONE_BASE, P.WISHBONE_RANGE)) ||
      (P.XILINX_AXI_DMA_SUPPORTED && in_range(HADDR[31:0], P.XILINX_AXI_DMA_BASE, P.XILINX_AXI_DMA_RANGE)) ||
      (P.AXI_VGA_SUPPORTED && in_range(HADDR[31:0], P.AXI_VGA_BASE, P.AXI_VGA_RANGE)) ||
      (P.AXI_USB_SUPPORTED && in_range(HADDR[31:0], P.AXI_USB_BASE, P.AXI_USB_RANGE)) ||
      (P.AXI_ETH_SUPPORTED && in_range(HADDR[31:0], P.AXI_ETH_BASE, P.AXI_ETH_RANGE)) ||
      (P.LITEDRAM_SUPPORTED && in_range(HADDR[31:0], P.LITEDRAM_BASE, P.LITEDRAM_RANGE)) ||
      (P.AXI_SDHCI_SUPPORTED && in_range(HADDR[31:0], P.AXI_SDHCI_BASE, P.AXI_SDHCI_RANGE)) ||
      (P.AXI_DUMMY_SUPPORTED && in_range(HADDR[31:0], P.AXI_DUMMY_BASE, P.AXI_DUMMY_RANGE)) ||
      (P.AXI_IDMA_SUPPORTED && in_range(HADDR[31:0], P.AXI_IDMA_BASE, P.AXI_IDMA_RANGE)) ||
      (P.AXI_IDMA_REG64_SUPPORTED && in_range(HADDR[31:0], P.AXI_IDMA_REG64_BASE, P.AXI_IDMA_REG64_RANGE)) ||
      (P.AXIS_IDMA_SUPPORTED && in_range(HADDR[31:0], P.AXIS_IDMA_BASE, P.AXIS_IDMA_RANGE));
  end

  assign reset = ~rst_ni;
  wallypipelinedcore #(P) core (
    .clk(clk_i), .reset, .MTimerInt(mtip_i), .MExtInt(meip_i), .SExtInt(seip_i),
    .MSwInt(msip_i), .MTIME_CLINT(mtime_i), .HRDATA, .HREADY, .HRESP,
    .HCLK, .HRESETn, .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST,
    .HPROT, .HTRANS, .HMASTLOCK, .ExternalStall(external_stall_i));

  ahb_to_axi4_burst #(.AW(32), .DW(P.AHBW), .IW(AXI_ID_W)
  ) bridge (
    .clk(clk_i),
    .resetn(rst_ni),

    .HSEL(hsel_axi),
    .HREADYIN(HREADY),
    .HADDR(HADDR[31:0]),
    .HBURST, .HMASTLOCK,
    .HPROT,
    .HSIZE,
    .HTRANS,
    .HWDATA,
    .HWRITE,
    .HRDATA(hrdata_axi),
    .HREADY(hready_axi),
    .HRESP(hresp_axi),

    .AWID(awid),
    .AWADDR(awaddr),
    .AWLEN(awlen),
    .AWSIZE(awsize),
    .AWBURST(awburst),
    .AWLOCK(awlock),
    .AWCACHE(awcache),
    .AWPROT(awprot),
    .AWQOS(awqos),
    .AWVALID(awvalid),
    .AWREADY(awready),
    .WDATA(wdata),
    .WSTRB(wstrb),
    .WLAST(wlast),
    .WVALID(wvalid),
    .WREADY(wready),
    .BID(bid),
    .BRESP(bresp),
    .BVALID(bvalid),
    .BREADY(bready),
    .ARID(arid),
    .ARADDR(araddr),
    .ARLEN(arlen),
    .ARSIZE(arsize),
    .ARBURST(arburst),
    .ARLOCK(arlock),
    .ARCACHE(arcache),
    .ARPROT(arprot),
    .ARQOS(arqos),
    .ARVALID(arvalid),
    .ARREADY(arready),
    .RID(rid),
    .RDATA(rdata),
    .RRESP(rresp),
    .RLAST(rlast),
    .RVALID(rvalid),
    .RREADY(rready) );

  // AHB responses belong to the preceding address phase.  This is the same
  // HSEL delay used by Wally uncore
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) 
        hsel_axi_d <= 1'b0;
    else if (HREADY) 
        hsel_axi_d <= hsel_axi;
  end
  always_comb begin
    HRDATA = '0;
    HREADY = 1'b1;
    HRESP = 1'b0;
    if (hsel_axi_d) begin
      HRDATA = hrdata_axi;
      HREADY = hready_axi;
      HRESP = hresp_axi;
    end
  end

  always_comb begin
    axi_req_o = '0;
    axi_req_o.aw = '{id:awid, addr:awaddr, len:awlen, size:awsize, burst:awburst,
                    lock:awlock, cache:awcache, prot:awprot, qos:awqos, region:'0, atop:'0, user:'0};
    axi_req_o.aw_valid = awvalid;
    axi_req_o.w = '{data:wdata, strb:wstrb, last:wlast, user:'0};
    axi_req_o.w_valid = wvalid;
    axi_req_o.b_ready = bready;
    axi_req_o.ar = '{id:arid, addr:araddr, len:arlen, size:arsize, burst:arburst,
                    lock:arlock, cache:arcache, prot:arprot, qos:arqos, region:'0, user:'0};
    axi_req_o.ar_valid = arvalid;
    axi_req_o.r_ready = rready;
    awready = axi_resp_i.aw_ready;
    wready = axi_resp_i.w_ready;
    bid = axi_resp_i.b.id;
    bresp = axi_resp_i.b.resp;
    bvalid = axi_resp_i.b_valid;
    arready = axi_resp_i.ar_ready;
    rid = axi_resp_i.r.id;
    rdata = axi_resp_i.r.data;
    rresp = axi_resp_i.r.resp;
    rlast = axi_resp_i.r.last;
    rvalid = axi_resp_i.r_valid;
  end
endmodule
