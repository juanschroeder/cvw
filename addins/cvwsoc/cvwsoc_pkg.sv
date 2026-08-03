// Shared AXI crossbar configuration for the FPGA top and cvwsoc testbench.
package cvwsoc_pkg;

  import cvw::*;

  // CVWSoC platform configuration.  Keep the Wally-visible logical SoC
  // configuration together with CVWSoC-only implementation choices so a
  // board top can select the latter without changing Wally's derivation flow.
  typedef enum logic [2:0] {
    CVWSOC_MEM_XILINX_DDR2,
    CVWSOC_MEM_LITEDRAM_NEXYSA7,
    CVWSOC_MEM_XILINX_DDR3,
    CVWSOC_MEM_LITEDRAM_GENESYS2,
    CVWSOC_MEM_UBERDDR3
  } cvwsoc_mem_type_t;

  typedef struct packed {
    bit             AxisDescReqCut; // cut req critical path
  } cvwsoc_idma_config_t;

  typedef struct packed {
    bit             CutSplitterPath; // Cut VGA Splitter critical path
    int unsigned    BufferDepth;
    int unsigned    MaxReadTxns;
  } cvwsoc_vga_config_t;

  typedef struct packed {
    bit             InsertRegClkBuf; // Xilinx 7-series SDHCI clock-mux hop
  } cvwsoc_sdhci_config_t;

  typedef struct packed {
    cvw_t                   wally;
    cvwsoc_mem_type_t       mem_type;
    cvwsoc_idma_config_t    idma_config;
    cvwsoc_vga_config_t     vga_config;
    cvwsoc_sdhci_config_t   sdhci_config;
  } cvwsoc_cfg_t;

  localparam int unsigned XBAR_MAX_SLV = 7;
  localparam int unsigned XBAR_MAX_MST = 13;
  localparam int unsigned XBAR_MAX_RULES = 19;
  localparam int unsigned XBAR_PORT_DISABLED = '1;

  typedef struct packed {
    int unsigned n_slv;
    int unsigned n_mst;
    int unsigned n_rules;

    int unsigned s_cpu;
    int unsigned s_cdma;
    int unsigned s_vga;
    int unsigned s_usb;
    int unsigned s_idma_fe;
    int unsigned s_idma_fe_axis;
    int unsigned s_idma_be;

    int unsigned m_ddr;
    int unsigned m_ahb;
    int unsigned m_wishbone;
    int unsigned m_cdma_reg;
    int unsigned m_vga_reg;
    int unsigned m_usb_reg;
    int unsigned m_eth_reg;
    int unsigned m_dram_csr;
    int unsigned m_sdhci;
    int unsigned m_dummy;
    int unsigned m_idma_desc;
    int unsigned m_idma_reg64;
    int unsigned m_idma_axis;

    int unsigned idma_n_slv;
    int unsigned idma_n_mst;
    logic [2:0][31:0] idma_slv_port;
    logic [2:0][31:0] idma_slv_req;
    logic [2:0][31:0] idma_mst_port;
    logic [2:0][31:0] idma_mst_resp;

    axi_pkg::xbar_rule_32_t [XBAR_MAX_RULES-1:0] addr_map;
  } xbar_out_t;

  function automatic xbar_out_t gen_xbar_out(input cvw_t cfg);
    xbar_out_t out;
    int unsigned slv_idx;
    int unsigned mst_idx;
    int unsigned rule_idx;

    out = '0;
    out.s_cdma         = XBAR_PORT_DISABLED;
    out.s_vga          = XBAR_PORT_DISABLED;
    out.s_usb          = XBAR_PORT_DISABLED;
    out.s_idma_fe      = XBAR_PORT_DISABLED;
    out.s_idma_fe_axis = XBAR_PORT_DISABLED;
    out.s_idma_be      = XBAR_PORT_DISABLED;
    out.m_cdma_reg     = XBAR_PORT_DISABLED;
    out.m_ahb          = XBAR_PORT_DISABLED;
    out.m_wishbone     = XBAR_PORT_DISABLED;
    out.m_vga_reg      = XBAR_PORT_DISABLED;
    out.m_usb_reg      = XBAR_PORT_DISABLED;
    out.m_eth_reg      = XBAR_PORT_DISABLED;
    out.m_dram_csr     = XBAR_PORT_DISABLED;
    out.m_sdhci        = XBAR_PORT_DISABLED;
    out.m_dummy        = XBAR_PORT_DISABLED;
    out.m_idma_desc    = XBAR_PORT_DISABLED;
    out.m_idma_reg64   = XBAR_PORT_DISABLED;
    out.m_idma_axis    = XBAR_PORT_DISABLED;

    slv_idx = 0;
    out.s_cpu = slv_idx;
    slv_idx++;
    if (cfg.XILINX_AXI_DMA_SUPPORTED) begin
      out.s_cdma = slv_idx;
      slv_idx++;
    end
    if (cfg.AXI_VGA_SUPPORTED) begin
      out.s_vga = slv_idx;
      slv_idx++;
    end
    if (cfg.AXI_USB_SUPPORTED) begin
      out.s_usb = slv_idx;
      slv_idx++;
    end
    if (cfg.AXI_IDMA_SUPPORTED) begin
      out.s_idma_fe = slv_idx;
      out.idma_slv_port[out.idma_n_slv] = slv_idx;
      out.idma_slv_req[out.idma_n_slv] = 0;
      out.idma_n_slv++;
      slv_idx++;
    end
    if (cfg.AXIS_IDMA_SUPPORTED) begin
      out.s_idma_fe_axis = slv_idx;
      out.idma_slv_port[out.idma_n_slv] = slv_idx;
      out.idma_slv_req[out.idma_n_slv] = 1;
      out.idma_n_slv++;
      slv_idx++;
    end
    if (cfg.AXI_IDMA_SUPPORTED || cfg.AXI_IDMA_REG64_SUPPORTED ||
        cfg.AXIS_IDMA_SUPPORTED) begin
      out.s_idma_be = slv_idx;
      out.idma_slv_port[out.idma_n_slv] = slv_idx;
      out.idma_slv_req[out.idma_n_slv] = 2;
      out.idma_n_slv++;
      slv_idx++;
    end

    mst_idx = 0;
    rule_idx = 0;
    out.m_ddr = mst_idx;
    out.addr_map[rule_idx] = '{
        idx:        mst_idx,
        start_addr: cfg.EXT_MEM_BASE[31:0],
        end_addr:   cfg.EXT_MEM_BASE[31:0] + cfg.EXT_MEM_RANGE[31:0] + 32'd1
    };
    mst_idx++;
    rule_idx++;
    // AHB peripherals share one AXI-to-AHB island.  Multiple
    // address rules select the same xbar master port.
    out.m_ahb = mst_idx;
    out.addr_map[rule_idx++] = '{idx: mst_idx, start_addr: cfg.BOOTROM_BASE[31:0], end_addr: cfg.BOOTROM_BASE[31:0] + cfg.BOOTROM_RANGE[31:0] + 32'd1};
    out.addr_map[rule_idx++] = '{idx: mst_idx, start_addr: cfg.UNCORE_RAM_BASE[31:0], end_addr: cfg.UNCORE_RAM_BASE[31:0] + cfg.UNCORE_RAM_RANGE[31:0] + 32'd1};
    out.addr_map[rule_idx++] = '{idx: mst_idx, start_addr: cfg.GPIO_BASE[31:0], end_addr: cfg.GPIO_BASE[31:0] + cfg.GPIO_RANGE[31:0] + 32'd1};
    out.addr_map[rule_idx++] = '{idx: mst_idx, start_addr: cfg.UART_BASE[31:0], end_addr: cfg.UART_BASE[31:0] + cfg.UART_RANGE[31:0] + 32'd1};
    out.addr_map[rule_idx++] = '{idx: mst_idx, start_addr: cfg.PLIC_BASE[31:0], end_addr: cfg.PLIC_BASE[31:0] + cfg.PLIC_RANGE[31:0] + 32'd1};
    out.addr_map[rule_idx++] = '{idx: mst_idx, start_addr: cfg.SDC_BASE[31:0], end_addr: cfg.SDC_BASE[31:0] + cfg.SDC_RANGE[31:0] + 32'd1};
    out.addr_map[rule_idx++] = '{idx: mst_idx, start_addr: cfg.SPI_BASE[31:0], end_addr: cfg.SPI_BASE[31:0] + cfg.SPI_RANGE[31:0] + 32'd1};
    mst_idx++;
    if (cfg.WISHBONE_SUPPORTED) begin
      out.m_wishbone = mst_idx;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.WISHBONE_BASE[31:0], end_addr: cfg.WISHBONE_BASE[31:0] + cfg.WISHBONE_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.XILINX_AXI_DMA_SUPPORTED) begin
      out.m_cdma_reg = mst_idx;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.XILINX_AXI_DMA_BASE[31:0], end_addr: cfg.XILINX_AXI_DMA_BASE[31:0] + cfg.XILINX_AXI_DMA_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.AXI_VGA_SUPPORTED) begin
      out.m_vga_reg = mst_idx;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.AXI_VGA_BASE[31:0], end_addr: cfg.AXI_VGA_BASE[31:0] + cfg.AXI_VGA_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.AXI_USB_SUPPORTED) begin
      out.m_usb_reg = mst_idx;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.AXI_USB_BASE[31:0], end_addr: cfg.AXI_USB_BASE[31:0] + cfg.AXI_USB_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.AXI_ETH_SUPPORTED) begin
      out.m_eth_reg = mst_idx;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.AXI_ETH_BASE[31:0], end_addr: cfg.AXI_ETH_BASE[31:0] + cfg.AXI_ETH_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.LITEDRAM_SUPPORTED) begin
      out.m_dram_csr = mst_idx;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.LITEDRAM_BASE[31:0], end_addr: cfg.LITEDRAM_BASE[31:0] + cfg.LITEDRAM_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.AXI_SDHCI_SUPPORTED) begin
      out.m_sdhci = mst_idx;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.AXI_SDHCI_BASE[31:0], end_addr: cfg.AXI_SDHCI_BASE[31:0] + cfg.AXI_SDHCI_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.AXI_DUMMY_SUPPORTED) begin
      out.m_dummy = mst_idx;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.AXI_DUMMY_BASE[31:0], end_addr: cfg.AXI_DUMMY_BASE[31:0] + cfg.AXI_DUMMY_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.AXI_IDMA_SUPPORTED) begin
      out.m_idma_desc = mst_idx;
      out.idma_mst_port[out.idma_n_mst] = mst_idx;
      out.idma_mst_resp[out.idma_n_mst] = 0;
      out.idma_n_mst++;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.AXI_IDMA_BASE[31:0], end_addr: cfg.AXI_IDMA_BASE[31:0] + cfg.AXI_IDMA_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.AXI_IDMA_REG64_SUPPORTED) begin
      out.m_idma_reg64 = mst_idx;
      out.idma_mst_port[out.idma_n_mst] = mst_idx;
      out.idma_mst_resp[out.idma_n_mst] = 1;
      out.idma_n_mst++;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.AXI_IDMA_REG64_BASE[31:0], end_addr: cfg.AXI_IDMA_REG64_BASE[31:0] + cfg.AXI_IDMA_REG64_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end
    if (cfg.AXIS_IDMA_SUPPORTED) begin
      out.m_idma_axis = mst_idx;
      out.idma_mst_port[out.idma_n_mst] = mst_idx;
      out.idma_mst_resp[out.idma_n_mst] = 2;
      out.idma_n_mst++;
      out.addr_map[rule_idx] = '{idx: mst_idx, start_addr: cfg.AXIS_IDMA_BASE[31:0], end_addr: cfg.AXIS_IDMA_BASE[31:0] + cfg.AXIS_IDMA_RANGE[31:0] + 32'd1};
      mst_idx++;
      rule_idx++;
    end

    out.n_slv = slv_idx;
    out.n_mst = mst_idx;
    out.n_rules = rule_idx;
    return out;
  endfunction

  // Connectivity is indexed as [crossbar slave input][crossbar master output].
  // Keep the full-size return type in the package; consumers select both packed
  // dimensions down to their configuration-dependent crossbar sizes.
  function automatic bit [XBAR_MAX_SLV-1:0][XBAR_MAX_MST-1:0]
      gen_xbar_connectivity(input cvw_t cfg);
    xbar_out_t out;
    bit [XBAR_MAX_SLV-1:0][XBAR_MAX_MST-1:0] conn;

    out = gen_xbar_out(cfg);
    conn = '0;

    // The CPU owns the system address map and can access every instantiated
    // crossbar target.
    conn[out.s_cpu][out.m_ddr] = 1'b1;
    conn[out.s_cpu][out.m_ahb] = 1'b1;
    if (cfg.WISHBONE_SUPPORTED)
      conn[out.s_cpu][out.m_wishbone] = 1'b1;
    if (cfg.XILINX_AXI_DMA_SUPPORTED)
      conn[out.s_cpu][out.m_cdma_reg] = 1'b1;
    if (cfg.AXI_VGA_SUPPORTED)
      conn[out.s_cpu][out.m_vga_reg] = 1'b1;
    if (cfg.AXI_USB_SUPPORTED)
      conn[out.s_cpu][out.m_usb_reg] = 1'b1;
    if (cfg.AXI_ETH_SUPPORTED)
      conn[out.s_cpu][out.m_eth_reg] = 1'b1;
    if (cfg.LITEDRAM_SUPPORTED)
      conn[out.s_cpu][out.m_dram_csr] = 1'b1;
    if (cfg.AXI_SDHCI_SUPPORTED)
      conn[out.s_cpu][out.m_sdhci] = 1'b1;
    if (cfg.AXI_DUMMY_SUPPORTED)
      conn[out.s_cpu][out.m_dummy] = 1'b1;
    if (cfg.AXI_IDMA_SUPPORTED)
      conn[out.s_cpu][out.m_idma_desc] = 1'b1;
    if (cfg.AXI_IDMA_REG64_SUPPORTED)
      conn[out.s_cpu][out.m_idma_reg64] = 1'b1;
    if (cfg.AXIS_IDMA_SUPPORTED)
      conn[out.s_cpu][out.m_idma_axis] = 1'b1;

    // Autonomous masters only access external memory.
    if (cfg.XILINX_AXI_DMA_SUPPORTED)
      conn[out.s_cdma][out.m_ddr] = 1'b1;
    if (cfg.AXI_VGA_SUPPORTED)
      conn[out.s_vga][out.m_ddr] = 1'b1;
    if (cfg.AXI_USB_SUPPORTED)
      conn[out.s_usb][out.m_ddr] = 1'b1;
    if (cfg.AXI_IDMA_SUPPORTED)
      conn[out.s_idma_fe][out.m_ddr] = 1'b1;
    if (cfg.AXIS_IDMA_SUPPORTED)
      conn[out.s_idma_fe_axis][out.m_ddr] = 1'b1;
    if (cfg.AXI_IDMA_SUPPORTED || cfg.AXI_IDMA_REG64_SUPPORTED ||
        cfg.AXIS_IDMA_SUPPORTED)
      conn[out.s_idma_be][out.m_ddr] = 1'b1;

    return conn;
  endfunction

endpackage
