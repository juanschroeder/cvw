package cvwsoc_cva6_pkg;

  import cvw::*;

  //copied from cheshire
  `include "cva6/typedef.svh"
  `include "rvfi_types.svh"

  //-------------------------------------------------------------------
  // CHESHIRE STUFF
  //---------------------------------------------------------------------

  // ** cheshire_addrmap_pkg.sv
  //-----------------------------------------------------------
    localparam longint unsigned BASE_ADDR = 64'h0;
    localparam longint unsigned SIZE = 64'h80800000;

    // Debug ROM (not used in CVWSoC)
    localparam longint unsigned EXTROM_BASE_ADDR = 64'h0;
    localparam longint unsigned EXTROM_SIZE = 64'h40000;

    // localparam longint unsigned DMA_BASE_ADDR = 64'h1000000;
    // localparam longint unsigned DMA_SIZE = 64'h1000;

    //localparam longint unsigned BOOTROM_BASE_ADDR = 64'h2000000;
    //localparam longint unsigned BOOTROM_SIZE = 64'h40000;
    localparam longint unsigned BOOTROM_BASE_ADDR = 64'h1000;
    localparam longint unsigned BOOTROM_SIZE = 64'h20000;

    // localparam longint unsigned CLINT_BASE_ADDR = 64'h2040000;
    // localparam longint unsigned CLINT_SIZE = 64'h40000;

    // localparam longint unsigned IRQ_ROUTER_BASE_ADDR = 64'h2080000;
    // localparam longint unsigned IRQ_ROUTER_SIZE = 64'h40000;

    // localparam longint unsigned AXIRT_BASE_ADDR = 64'h20C0000;
    // localparam longint unsigned AXIRT_SIZE = 64'h40000;

    // localparam longint unsigned REGS_BASE_ADDR = 64'h3000000;
    // localparam longint unsigned REGS_SIZE = 64'h5C;

    localparam longint unsigned LLC_BASE_ADDR = 64'h3001000;
    localparam longint unsigned LLC_SIZE = 64'h1000;

    // localparam longint unsigned UART_BASE_ADDR = 64'h3002000;
    // localparam longint unsigned UART_SIZE = 64'h1000;

    // localparam longint unsigned I2C_BASE_ADDR = 64'h3003000;
    // localparam longint unsigned I2C_SIZE = 64'h1000;

    // localparam longint unsigned SPIH_BASE_ADDR = 64'h3004000;
    // localparam longint unsigned SPIH_SIZE = 64'h1000;

    // localparam longint unsigned GPIO_BASE_ADDR = 64'h3005000;
    // localparam longint unsigned GPIO_SIZE = 64'h1000;

    // localparam longint unsigned SLINK_BASE_ADDR = 64'h3006000;
    // localparam longint unsigned SLINK_SIZE = 64'h804;

    // localparam longint unsigned VGA_BASE_ADDR = 64'h3007000;
    // localparam longint unsigned VGA_SIZE = 64'h1000;

    // localparam longint unsigned USB_BASE_ADDR = 64'h3008000;
    // localparam longint unsigned USB_SIZE = 64'h1000;

    // localparam longint unsigned BUS_ERR_BASE_ADDR = 64'h3009000;
    // localparam longint unsigned BUS_ERR_SIZE = 64'h40;

    // localparam longint unsigned PLIC_BASE_ADDR = 64'h4000000;
    // localparam longint unsigned PLIC_SIZE = 64'h4000000;

    // localparam longint unsigned CLIC_BASE_ADDR = 64'h8000000;
    // localparam longint unsigned CLIC_SIZE = 64'h40000;

    // FIXME: This changes for CVWSOC. IT SHOULD NOT BE HARDCODED
    //localparam longint unsigned SPM_BASE_ADDR = 64'h10000000;
    //localparam longint unsigned SPM_BASE_ADDR = 64'h20000;  
    localparam longint unsigned SPM_BASE_ADDR = 64'h50000000; // TEST!! REMOVE!
    localparam longint unsigned SPM_SIZE = 64'h10000;

    localparam longint unsigned SPM_UNC_BASE_ADDR = 64'h14000000;
    localparam longint unsigned SPM_UNC_SIZE = 64'h4000000;

    // localparam longint unsigned DRAM_BASE_ADDR = 64'h80000000;
    // localparam longint unsigned DRAM_SIZE = 64'h800000;

    // localparam longint unsigned DMA_STATUS_BASE_ADDR = 64'h1000000;
    // localparam longint unsigned DMA__END_BASE_ADDR = 64'h1000FFC;
    // localparam longint unsigned CLINT_STATUS_BASE_ADDR = 64'h2040000;
    // localparam longint unsigned CLINT__END_BASE_ADDR = 64'h207FFFC;
    // localparam longint unsigned IRQ_ROUTER_STATUS_BASE_ADDR = 64'h2080000;
    // localparam longint unsigned IRQ_ROUTER__END_BASE_ADDR = 64'h20BFFFC;
    // localparam longint unsigned AXIRT_STATUS_BASE_ADDR = 64'h20C0000;
    // localparam longint unsigned AXIRT__END_BASE_ADDR = 64'h20FFFFC;
    // function automatic longint unsigned REGS_SCRATCH_BASE_ADDR(input int unsigned scratch_idx);
    //     return 64'h3000000 + (scratch_idx * 64'h4);
    // endfunction
    // localparam longint unsigned REGS_SCRATCH_NUM = 64'h10;
    // localparam longint unsigned REGS_BOOT_MODE_BASE_ADDR = 64'h3000040;
    // localparam longint unsigned REGS_RTC_FREQ_BASE_ADDR = 64'h3000044;
    // localparam longint unsigned REGS_PLATFORM_ROM_BASE_ADDR = 64'h3000048;
    // localparam longint unsigned REGS_NUM_INT_HARTS_BASE_ADDR = 64'h300004C;
    // localparam longint unsigned REGS_HW_FEATURES_BASE_ADDR = 64'h3000050;
    // localparam longint unsigned REGS_LLC_SIZE_BASE_ADDR = 64'h3000054;
    // localparam longint unsigned REGS_VGA_PARAMS_BASE_ADDR = 64'h3000058;
    localparam longint unsigned LLC_STATUS_BASE_ADDR = 64'h3001000;
    localparam longint unsigned LLC__END_BASE_ADDR = 64'h3001FFC;
    // localparam longint unsigned UART_STATUS_BASE_ADDR = 64'h3002000;
    // localparam longint unsigned UART__END_BASE_ADDR = 64'h3002FFC;
    // localparam longint unsigned I2C_STATUS_BASE_ADDR = 64'h3003000;
    // localparam longint unsigned I2C__END_BASE_ADDR = 64'h3003FFC;
    // localparam longint unsigned SPIH_STATUS_BASE_ADDR = 64'h3004000;
    // localparam longint unsigned SPIH__END_BASE_ADDR = 64'h3004FFC;
    // localparam longint unsigned GPIO_STATUS_BASE_ADDR = 64'h3005000;
    // localparam longint unsigned GPIO__END_BASE_ADDR = 64'h3005FFC;
    // localparam longint unsigned SLINK_CTRL_BASE_ADDR = 64'h3006000;
    // localparam longint unsigned SLINK_ISOLATED_BASE_ADDR = 64'h3006004;
    // localparam longint unsigned SLINK_RAW_MODE_EN_BASE_ADDR = 64'h3006008;
    // localparam longint unsigned SLINK_RAW_MODE_IN_DATA_BASE_ADDR = 64'h300600C;
    // localparam longint unsigned SLINK_RAW_MODE_IN_CH_SEL_BASE_ADDR = 64'h3006010;
    // localparam longint unsigned SLINK_RAW_MODE_OUT_DATA_FIFO_BASE_ADDR = 64'h3006014;
    // localparam longint unsigned SLINK_RAW_MODE_OUT_DATA_FIFO_CTRL_BASE_ADDR = 64'h3006018;
    // localparam longint unsigned SLINK_RAW_MODE_OUT_EN_BASE_ADDR = 64'h300601C;
    // localparam longint unsigned SLINK_FLOW_CONTROL_FIFO_CLEAR_BASE_ADDR = 64'h3006020;
    // function automatic longint unsigned SLINK_RAW_MODE_IN_DATA_VALID_BASE_ADDR(input int unsigned raw_mode_in_data_valid_idx);
    //     return 64'h3006100 + (raw_mode_in_data_valid_idx * 64'h4);
    // endfunction
    // localparam longint unsigned SLINK_RAW_MODE_IN_DATA_VALID_NUM = 64'h1;
    // function automatic longint unsigned SLINK_RAW_MODE_OUT_CH_MASK_BASE_ADDR(input int unsigned raw_mode_out_ch_mask_idx);
    //     return 64'h3006200 + (raw_mode_out_ch_mask_idx * 64'h4);
    // endfunction
    // localparam longint unsigned SLINK_RAW_MODE_OUT_CH_MASK_NUM = 64'h1;
    // function automatic longint unsigned SLINK_TX_PHY_CLK_DIV_BASE_ADDR(input int unsigned tx_phy_clk_div_idx);
    //     return 64'h3006300 + (tx_phy_clk_div_idx * 64'h4);
    // endfunction
    // localparam longint unsigned SLINK_TX_PHY_CLK_DIV_NUM = 64'h1;
    // function automatic longint unsigned SLINK_TX_PHY_CLK_START_BASE_ADDR(input int unsigned tx_phy_clk_start_idx);
    //     return 64'h3006400 + (tx_phy_clk_start_idx * 64'h4);
    // endfunction
    // localparam longint unsigned SLINK_TX_PHY_CLK_START_NUM = 64'h1;
    // function automatic longint unsigned SLINK_TX_PHY_CLK_END_BASE_ADDR(input int unsigned tx_phy_clk_end_idx);
    //     return 64'h3006500 + (tx_phy_clk_end_idx * 64'h4);DMA_BASE_ADDR
    // endfunction
    // localparam longint unsigned SLINK_TX_PHY_CLK_END_NUM = 64'h1;
    // localparam longint unsigned SLINK_CHANNEL_ALLOC_TX_CFG_BASE_ADDR = 64'h3006600;
    // localparam longint unsigned SLINK_CHANNEL_ALLOC_TX_CTRL_BASE_ADDR = 64'h3006604;
    // localparam longint unsigned SLINK_CHANNEL_ALLOC_RX_CFG_BASE_ADDR = 64'h3006608;
    // localparam longint unsigned SLINK_CHANNEL_ALLOC_RX_CTRL_BASE_ADDR = 64'h300660C;
    // function automatic longint unsigned SLINK_CHANNEL_ALLOC_TX_CH_EN_BASE_ADDR(input int unsigned channel_alloc_tx_ch_en_idx);
    //     return 64'h3006700 + (channel_alloc_tx_ch_en_idx * 64'h4);
    // endfunction
    // localparam longint unsigned SLINK_CHANNEL_ALLOC_TX_CH_EN_NUM = 64'h1;
    // function automatic longint unsigned SLINK_CHANNEL_ALLOC_RX_CH_EN_BASE_ADDR(input int unsigned channel_alloc_rx_ch_en_idx);
    //     return 64'h3006800 + (channel_alloc_rx_ch_en_idx * 64'h4);
    // endfunction
    // localparam longint unsigned SLINK_CHANNEL_ALLOC_RX_CH_EN_NUM = 64'h1;
    // localparam longint unsigned VGA_STATUS_BASE_ADDR = 64'h3007000;
    // localparam longint unsigned VGA__END_BASE_ADDR = 64'h3007FFC;
    // localparam longint unsigned USB_STATUS_BASE_ADDR = 64'h3008000;
    // localparam longint unsigned USB__END_BASE_ADDR = 64'h3008FFC;
    // localparam longint unsigned BUS_ERR_STATUS_BASE_ADDR = 64'h3009000;
    // localparam longint unsigned BUS_ERR__END_BASE_ADDR = 64'h300903C;
    // localparam longint unsigned PLIC_STATUS_BASE_ADDR = 64'h4000000;
    // localparam longint unsigned PLIC__END_BASE_ADDR = 64'h7FFFFFC;
    // localparam longint unsigned CLIC_STATUS_BASE_ADDR = 64'h8000000;
    // localparam longint unsigned CLIC__END_BASE_ADDR = 64'h803FFFC;

    // typedef enum logic [1:0] {
    //     PASSIVE = 2'd0,
    //     SPI_SDCARD = 2'd1,
    //     SPI_S25FS512S = 2'd2,
    //     I2C_24XX1025 = 2'd3
    // } BootMode_e;  
  //-----------------------------------------------------------

  // ** cheshire_pkg.sv **

  // Return either the argument minus 1 or 0 if 0; useful for IO vector width declaration
  function automatic integer unsigned iomsb (input integer unsigned width);
      return (width != 32'd0) ? unsigned'(width-1) : 32'd0;
  endfunction

  // Parameterization constants
  localparam int unsigned MaxCoresWidth     = 5;
  localparam int unsigned MaxExtAxiMstWidth = 4;
  localparam int unsigned MaxExtAxiSlvWidth = 4;
  localparam int unsigned MaxExtRegSlvWidth = 4;

  // Default JTAG ID code type
  typedef struct packed {
    bit [ 3:0]  version;
    bit [15:0]  part_num;
    bit [10:0]  manufacturer;
    bit         _one;
  } jtag_idcode_t;

  // PULP Platform manufacturer and default Cheshire part number
  localparam bit [10:0] JtagPulpManufacturer  = 11'h6d9;
  localparam bit [15:0] JtagCheshirePartNum   = 16'hc5e5;
  localparam bit [ 3:0] JtagCheshireVersion   = 4'h1;
  localparam jtag_idcode_t CheshireIdCode = '{
    _one          : 1,
    manufacturer  : JtagPulpManufacturer,
    part_num      : JtagCheshirePartNum,
    version       : JtagCheshireVersion
  };


  // Bit vector types for parameters.
  //We limit range to keep parameters sane.
  typedef bit [ 7:0] byte_bt;
  typedef bit [15:0] shrt_bt;
  typedef bit [31:0] word_bt;
  typedef bit [63:0] doub_bt;
  typedef bit [ 9:0] dw_bt;   // data widths
  typedef bit [ 5:0] aw_bt;   // address, ID widths or small buffers

  localparam CHESHIRE_SOC_REGS_DATA_WIDTH = 32;
  localparam CHESHIRE_SOC_REGS_MIN_ADDR_WIDTH = 7;
  //localparam CHESHIRE_SOC_REGS_SIZE = 'h5c;
  //typedef bit [cheshire_soc_regs_pkg::CHESHIRE_SOC_REGS_MIN_ADDR_WIDTH-1:0] reg_aw_bt; // Address widths for reg APB bus
//   typedef bit [CHESHIRE_SOC_REGS_MIN_ADDR_WIDTH-1:0] reg_aw_bt; // Address widths for reg APB bus


  // Externally controllable parameters
  typedef struct packed {
    // CVA6 parameters
    shrt_bt Cva6RASDepth;
    shrt_bt Cva6BTBEntries;
    shrt_bt Cva6BHTEntries;
    shrt_bt Cva6NrPMPEntries;
    // To reduce parameterization entropy, the range [0x2.., 0x8..) is defined to contain exactly
    // one cached, idempotent, and executable (CIE) and one non-CIE region. The parameters below
    // control the CIE region's size and whether it abuts with the top or bottom of this range.
    doub_bt Cva6ExtCieLength;
    bit     Cva6ExtCieOnTop;
    // Hart parameters
    bit [MaxCoresWidth-1:0] NumCores;
    doub_bt NumExtIrqHarts;
    doub_bt NumExtDbgHarts;
    doub_bt CoreUserAmoOffs;
    dw_bt   CoreMaxTxns;
    dw_bt   CoreMaxTxnsPerId;
    // Interrupt parameters
    doub_bt NumExtInIntrs;
    shrt_bt NumExtClicIntrs;
    byte_bt NumExtOutIntrTgts;
    shrt_bt NumExtOutIntrs;
    shrt_bt ClicIntCtlBits;
    shrt_bt NumExtIntrSyncs;
    // AXI parameters
    aw_bt   AddrWidth;
    dw_bt   AxiDataWidth;
    dw_bt   AxiUserWidth;
    aw_bt   AxiMstIdWidth;
    dw_bt   AxiMaxMstTrans;
    dw_bt   AxiMaxSlvTrans;
    // User signals identify atomics masters.
    // A '0 user signal indicates no atomics.
    dw_bt   AxiUserAmoMsb;
    dw_bt   AxiUserAmoLsb;
    dw_bt   AxiUserErrBits;
    dw_bt   AxiUserErrLsb;
    doub_bt AxiUserDefault; // Default user assignment, adjusted by user features (AMO)
    // Reg parameters
    dw_bt   RegMaxReadTxns;
    dw_bt   RegMaxWriteTxns;
    aw_bt   RegAmoNumCuts;
    bit     RegAmoPostCut;
    bit     RegAdaptMemCut;
    // External AXI ports (limited number of ports and rules)
    bit     [MaxExtAxiMstWidth-1:0]     AxiExtNumMst;
    bit     [MaxExtAxiSlvWidth-1:0]     AxiExtNumSlv;
    bit     [MaxExtAxiSlvWidth-1:0]     AxiExtNumRules;
    byte_bt [2**MaxExtAxiSlvWidth-1:0]  AxiExtRegionIdx;
    doub_bt [2**MaxExtAxiSlvWidth-1:0]  AxiExtRegionStart;
    doub_bt [2**MaxExtAxiSlvWidth-1:0]  AxiExtRegionEnd;
    // External reg slaves (limited number of ports and rules)
    bit     [MaxExtRegSlvWidth-1:0]     RegExtNumSlv;
    bit     [MaxExtRegSlvWidth-1:0]     RegExtNumRules;
    byte_bt [2**MaxExtRegSlvWidth-1:0]  RegExtRegionIdx;
    doub_bt [2**MaxExtRegSlvWidth-1:0]  RegExtRegionStart;
    doub_bt [2**MaxExtRegSlvWidth-1:0]  RegExtRegionEnd;
    // Real-time clock speed
    word_bt RtcFreq;
    // Address of platform ROM
    word_bt PlatformRom;
    // Enabled hardware features
    bit     Bootrom;
    bit     Uart;
    bit     I2c;
    bit     SpiHost;
    bit     Gpio;
    bit     Dma;
    bit     SerialLink;
    bit     Vga;
    bit     Usb;
    bit     AxiRt;
    bit     Clic;
    bit     IrqRouter;
    bit     BusErr;
    // Parameters for Debug Module
    jtag_idcode_t DbgIdCode;
    dw_bt   DbgMaxReqs;
    dw_bt   DbgMaxReadTxns;
    dw_bt   DbgMaxWriteTxns;
    aw_bt   DbgAmoNumCuts;
    bit     DbgAmoPostCut;
    // Parameters for LLC
    bit     LlcNotBypass;
    shrt_bt LlcSetAssoc;
    shrt_bt LlcNumLines;
    shrt_bt LlcNumBlocks;
    dw_bt   LlcMaxReadTxns;
    dw_bt   LlcMaxWriteTxns;
    aw_bt   LlcAmoNumCuts;
    bit     LlcAmoPostCut;
    bit     LlcOutConnect;
    doub_bt LlcOutRegionStart;
    doub_bt LlcOutRegionEnd;
    // Parameters for VGA
    byte_bt VgaRedWidth;
    byte_bt VgaGreenWidth;
    byte_bt VgaBlueWidth;
    aw_bt   VgaHCountWidth;
    aw_bt   VgaVCountWidth;
    dw_bt   VgaBufferDepth;
    dw_bt   VgaMaxReadTxns;
    // Parameters for Serial Link
    dw_bt   SlinkMaxTxnsPerId;
    dw_bt   SlinkMaxUniqIds;
    shrt_bt SlinkMaxClkDiv;
    doub_bt SlinkRegionStart;
    doub_bt SlinkRegionEnd;
    doub_bt SlinkTxAddrMask;
    doub_bt SlinkTxAddrDomain;
    dw_bt   SlinkUserAmoBit;
    // Parameters for USB
    dw_bt   UsbDmaMaxReads;
    doub_bt UsbAddrMask;
    doub_bt UsbAddrDomain;
    // Parameters for DMA
    dw_bt   DmaConfMaxReadTxns;
    dw_bt   DmaConfMaxWriteTxns;
    aw_bt   DmaConfAmoNumCuts;
    bit     DmaConfAmoPostCut;
    bit     DmaConfEnableTwoD;
    dw_bt   DmaNumAxInFlight;
    dw_bt   DmaMemSysDepth;
    aw_bt   DmaJobFifoDepth;
    bit     DmaRAWCouplingAvail;
    // Parameters for GPIO
    bit     GpioInputSyncs;
    // Parameters for AXI RT
    aw_bt   AxiRtNumPending;
    dw_bt   AxiRtWBufferDepth;
    aw_bt   AxiRtNumAddrRegions;
    bit     AxiRtCutPaths;
    bit     AxiRtEnableChecks;
    // Parameters for CLIC
    bit     ClicVsclic;
    bit     ClicVsprio;
    byte_bt ClicNumVsctxts;
    aw_bt   ClicPrioWidth;
  } cheshire_cfg_t;

  //////////////////
  //  Interrupts  //
  //////////////////

  // Bus Error interrupts
  typedef struct packed {
    logic r;
    logic w;
  } axi_err_intr_t;

  typedef struct packed {
    axi_err_intr_t cores;
    axi_err_intr_t dma;
    axi_err_intr_t vga;
  } cheshire_bus_err_intr_t;  

  // Defined interrupts
  typedef struct packed {
    cheshire_bus_err_intr_t bus_err;
    logic [31:0] gpio;
    logic usb;
    logic spih_spi_event;
    logic spih_error;
    logic i2c_host_timeout;
    logic i2c_unexp_stop;
    logic i2c_acq_full;
    logic i2c_tx_overflow;
    logic i2c_tx_stretch;
    logic i2c_cmd_complete;
    logic i2c_sda_unstable;
    logic i2c_stretch_timeout;
    logic i2c_sda_interference;
    logic i2c_scl_interference;
    logic i2c_nak;
    logic i2c_rx_overflow;
    logic i2c_fmt_overflow;
    logic i2c_rx_threshold;
    logic i2c_fmt_threshold;
    logic uart;
    logic zero;
  } cheshire_int_intr_t;

  typedef struct packed {
    logic [3:0] _rsvd_15to12;
    logic       meip;
    logic       _rsvd_10;
    logic       seip;
    logic       _rsvd_8;
    logic       mtip;
    logic [2:0] _rsvd_6to4;
    logic       msip;
    logic [2:0] _rsvd_2to0;
  } cheshire_core_ip_t;

  typedef struct packed {
    logic s;
    logic m;
  } cheshire_xeip_t;


  // Interrupt parameters
  localparam int unsigned NumIntIntrs     = $bits(cheshire_int_intr_t);
  localparam int unsigned NumIrqCtxts     = $bits(cheshire_xeip_t);
  localparam int unsigned NumCoreIrqs     = $bits(cheshire_core_ip_t);
  //FIXME!!!! Not really sure where this comes from (CHECK)
  localparam int NumSrc = 58; //rv_plic_reg_pkg::NumSrc;
  //localparam int unsigned NumExtPlicIntrs = rv_plic_reg_pkg::NumSrc - NumIntIntrs;
  localparam int unsigned NumExtPlicIntrs = NumSrc - NumIntIntrs;



  localparam cheshire_cfg_t DefaultCfg = '{
    // CVA6 parameters
    Cva6RASDepth      : 2,
    Cva6BTBEntries    : 32,
    Cva6BHTEntries    : 128,
    Cva6NrPMPEntries  : 0,
    Cva6ExtCieLength  : 'h2000_0000,  // [0x2.., 0x4..) is CIE, [0x4.., 0x8..) is non-CIE
    Cva6ExtCieOnTop   : 0,
    // Harts
    NumCores          : 1,
    CoreMaxTxns       : 8,
    CoreMaxTxnsPerId  : 4,
    CoreUserAmoOffs   : 0, // Convention: lower AMO bits for cores, MSB for serial link
    // Interrupts
    NumExtInIntrs     : 0,
    NumExtClicIntrs   : NumExtPlicIntrs,
    NumExtOutIntrTgts : 0,
    NumExtOutIntrs    : 0,
    ClicIntCtlBits    : 8,
    NumExtIntrSyncs   : 2,
    // Interconnect
    AddrWidth         : 48,
    AxiDataWidth      : 64,
    AxiUserWidth      : 2,  // AMO(2)
    AxiMstIdWidth     : 2,
    AxiMaxMstTrans    : 24,
    AxiMaxSlvTrans    : 24,
    AxiUserAmoMsb     : 1, // Convention: lower AMO bits for cores, MSB for serial link
    AxiUserAmoLsb     : 0, // Convention: lower AMO bits for cores, MSB for serial link
    AxiUserErrBits    : 0,
    AxiUserErrLsb     : 0,
    AxiUserDefault    : 0,
    RegMaxReadTxns    : 8,
    RegMaxWriteTxns   : 8,
    RegAmoNumCuts     : 1,
    RegAmoPostCut     : 1,
    RegAdaptMemCut    : 1,
    // RTC
    RtcFreq           : 32768,
    // Features
    Bootrom           : 1,
    Uart              : 1,
    I2c               : 1,
    SpiHost           : 1,
    Gpio              : 1,
    Dma               : 1,
    SerialLink        : 1,
    Vga               : 1,
    Usb               : 1,
    AxiRt             : 0,
    Clic              : 0,
    IrqRouter         : 0,
    BusErr            : 1,
    // Debug
    DbgIdCode         : CheshireIdCode,
    DbgMaxReqs        : 4,
    DbgMaxReadTxns    : 4,
    DbgMaxWriteTxns   : 4,
    DbgAmoNumCuts     : 1,
    DbgAmoPostCut     : 1,
    // LLC: 128 KiB, up to 2 GiB DRAM
    LlcNotBypass      : 1,
    LlcSetAssoc       : 8,
    LlcNumLines       : 256,
    LlcNumBlocks      : 8,
    LlcMaxReadTxns    : 16,
    LlcMaxWriteTxns   : 16,
    LlcAmoNumCuts     : 1,
    LlcAmoPostCut     : 1,
    LlcOutConnect     : 1,
    LlcOutRegionStart : 'h8000_0000,
    LlcOutRegionEnd   : 64'h1_0000_0000,
    // VGA: RGB565
    VgaRedWidth       : 5,
    VgaGreenWidth     : 6,
    VgaBlueWidth      : 5,
    VgaHCountWidth    : 24, // TODO: Default is 32; is this needed?
    VgaVCountWidth    : 24, // TODO: See above
    VgaBufferDepth    : 16,
    VgaMaxReadTxns    : 24,
    // Serial Link: map other chip's lower 32bit to 'h1_000_0000
    SlinkMaxTxnsPerId : 4,
    SlinkMaxUniqIds   : 4,
    SlinkMaxClkDiv    : 1024,
    SlinkRegionStart  : 64'h1_0000_0000,
    SlinkRegionEnd    : 64'h2_0000_0000,
    SlinkTxAddrMask   : 'hFFFF_FFFF,
    SlinkTxAddrDomain : 'h0000_0000,
    SlinkUserAmoBit   : 1,  // Convention: lower AMO bits for cores, MSB for serial link
    // USB config
    UsbDmaMaxReads    : 16,
    UsbAddrMask       : 'hFFFF_FFFF,
    UsbAddrDomain     : 'h0000_0000,
    // DMA config
    DmaConfMaxReadTxns  : 4,
    DmaConfMaxWriteTxns : 4,
    DmaConfAmoNumCuts   : 1,
    DmaConfAmoPostCut   : 1,
    DmaConfEnableTwoD   : 1,
    DmaNumAxInFlight    : 16,
    DmaMemSysDepth      : 8,
    DmaJobFifoDepth     : 2,
    DmaRAWCouplingAvail : 1,
    // GPIOs
    GpioInputSyncs    : 1,
    // AXI RT
    AxiRtNumPending     : 16,
    AxiRtWBufferDepth   : 16,
    AxiRtNumAddrRegions : 2,
    AxiRtCutPaths       : 1,
    // CLIC
    ClicVsclic        : 0,
    ClicVsprio        : 0,
    ClicNumVsctxts    : 4,
    ClicPrioWidth     : 1,
    // All non-set values should be zero
    default: '0
  };


  function automatic config_pkg::cva6_cfg_t build_config(config_pkg::cva6_user_cfg_t CVA6Cfg);
    bit IS_XLEN32 = (CVA6Cfg.XLEN == 32) ? 1'b1 : 1'b0;
    bit IS_XLEN64 = (CVA6Cfg.XLEN == 32) ? 1'b0 : 1'b1;
    bit FpPresent = CVA6Cfg.RVF | CVA6Cfg.RVD | CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8 | CVA6Cfg.XF8ALT;
    bit NSX = CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8 | CVA6Cfg.XF8ALT | CVA6Cfg.XFVec;  // Are non-standard extensions present?
    int unsigned FLen = CVA6Cfg.RVD ? 64 :  // D ext.
    CVA6Cfg.RVF ? 32 :  // F ext.
    CVA6Cfg.XF16 ? 16 :  // Xf16 ext.
    CVA6Cfg.XF16ALT ? 16 :  // Xf16alt ext.
    CVA6Cfg.XF8 ? 8 :  // Xf8 ext.
    CVA6Cfg.XF8ALT ? 8 :  // Xf8alt ext.
    1;  // Unused in case of no FP

    // Transprecision floating-point extensions configuration
    bit RVFVec     = CVA6Cfg.RVF     & CVA6Cfg.XFVec & FLen>32; // FP32 vectors available if vectors and larger fmt enabled
    bit XF16Vec    = CVA6Cfg.XF16    & CVA6Cfg.XFVec & FLen>16; // FP16 vectors available if vectors and larger fmt enabled
    bit XF16ALTVec = CVA6Cfg.XF16ALT & CVA6Cfg.XFVec & FLen>16; // FP16ALT vectors available if vectors and larger fmt enabled
    bit XF8Vec     = CVA6Cfg.XF8     & CVA6Cfg.XFVec & FLen>8;  // FP8 vectors available if vectors and larger fmt enabled
    bit XF8ALTVec  = CVA6Cfg.XF8ALT  & CVA6Cfg.XFVec & FLen>8;  // FP8ALT vectors available if vectors and larger fmt enabled

    bit EnableAccelerator = CVA6Cfg.RVV;  // Currently only used by V extension (Ara)
    int unsigned NrWbPorts = (CVA6Cfg.CvxifEn || EnableAccelerator) ? 5 : 4;

    int unsigned ICACHE_INDEX_WIDTH = $clog2(CVA6Cfg.IcacheByteSize / CVA6Cfg.IcacheSetAssoc);
    int unsigned DCACHE_INDEX_WIDTH = $clog2(CVA6Cfg.DcacheByteSize / CVA6Cfg.DcacheSetAssoc);
    int unsigned DCACHE_OFFSET_WIDTH = $clog2(CVA6Cfg.DcacheLineWidth / 8);

    // MMU
    int unsigned VpnLen = (CVA6Cfg.XLEN == 64) ? (CVA6Cfg.RVH ? 29 : 27) : 20;
    int unsigned PtLevels = (CVA6Cfg.XLEN == 64) ? 3 : 2;

    config_pkg::cva6_cfg_t cfg;

    cfg.XLEN = CVA6Cfg.XLEN;
    cfg.VLEN = CVA6Cfg.VLEN;
    cfg.PLEN = (CVA6Cfg.XLEN == 32) ? 34 : 56;
    cfg.GPLEN = (CVA6Cfg.XLEN == 32) ? 34 : 41;
    cfg.IS_XLEN32 = IS_XLEN32;
    cfg.IS_XLEN64 = IS_XLEN64;
    cfg.XLEN_ALIGN_BYTES = $clog2(CVA6Cfg.XLEN / 8);
    cfg.ASID_WIDTH = (CVA6Cfg.XLEN == 64) ? 16 : 1;
    cfg.VMID_WIDTH = (CVA6Cfg.XLEN == 64) ? 14 : 1;

    cfg.FpgaEn = CVA6Cfg.FpgaEn;
    cfg.FpgaAlteraEn = CVA6Cfg.FpgaAlteraEn;
    cfg.TechnoCut = CVA6Cfg.TechnoCut;

    cfg.SuperscalarEn = CVA6Cfg.SuperscalarEn;
    cfg.NrCommitPorts = CVA6Cfg.SuperscalarEn ? unsigned'(2) : CVA6Cfg.NrCommitPorts;
    cfg.NrIssuePorts = unsigned'(CVA6Cfg.SuperscalarEn ? 2 : 1);
    cfg.SpeculativeSb = CVA6Cfg.SuperscalarEn;

    cfg.NrLoadPipeRegs = CVA6Cfg.NrLoadPipeRegs;
    cfg.NrStorePipeRegs = CVA6Cfg.NrStorePipeRegs;
    cfg.AxiAddrWidth = CVA6Cfg.AxiAddrWidth;
    cfg.AxiDataWidth = CVA6Cfg.AxiDataWidth;
    cfg.AxiIdWidth = CVA6Cfg.AxiIdWidth;
    cfg.AxiUserWidth = CVA6Cfg.AxiUserWidth;
    cfg.MEM_TID_WIDTH = CVA6Cfg.MemTidWidth;
    cfg.NrLoadBufEntries = CVA6Cfg.NrLoadBufEntries;
    cfg.RVF = CVA6Cfg.RVF;
    cfg.RVD = CVA6Cfg.RVD;
    cfg.XF16 = CVA6Cfg.XF16;
    cfg.XF16ALT = CVA6Cfg.XF16ALT;
    cfg.XF8 = CVA6Cfg.XF8;
    cfg.XF8ALT = CVA6Cfg.XF8ALT;
    cfg.RVA = CVA6Cfg.RVA;
    cfg.RVB = CVA6Cfg.RVB;
    cfg.ZKN = CVA6Cfg.ZKN;
    cfg.RVV = CVA6Cfg.RVV;
    cfg.RVC = CVA6Cfg.RVC;
    cfg.RVH = CVA6Cfg.RVH;
    cfg.RVZCB = CVA6Cfg.RVZCB;
    cfg.RVZCMT = CVA6Cfg.RVZCMT;
    cfg.RVZCMP = CVA6Cfg.RVZCMP;
    cfg.RVSCLIC = CVA6Cfg.RVSCLIC;
    cfg.RVXHCLIC = CVA6Cfg.RVXHCLIC;
    cfg.XFVec = CVA6Cfg.XFVec;
    cfg.CvxifEn = CVA6Cfg.CvxifEn;
    cfg.CoproType = CVA6Cfg.CoproType;
    cfg.RVZiCond = CVA6Cfg.RVZiCond;
    cfg.RVZicntr = CVA6Cfg.RVZicntr;
    cfg.RVZihpm = CVA6Cfg.RVZihpm;
    cfg.NR_SB_ENTRIES = CVA6Cfg.NrScoreboardEntries;
    cfg.TRANS_ID_BITS = $clog2(CVA6Cfg.NrScoreboardEntries);

    cfg.FpPresent = bit'(FpPresent);
    cfg.NSX = bit'(NSX);
    cfg.FLen = unsigned'(FLen);
    cfg.RVFVec = bit'(RVFVec);
    cfg.XF16Vec = bit'(XF16Vec);
    cfg.XF16ALTVec = bit'(XF16ALTVec);
    cfg.XF8Vec = bit'(XF8Vec);
    cfg.XF8ALTVec = bit'(XF8ALTVec);
    // Can take 2 or 3 in single issue. 4 or 6 in dual issue.
    cfg.NrRgprPorts = unsigned'(CVA6Cfg.SuperscalarEn ? 4 : 2);
    // cfg.NrRgprPorts = unsigned'(CVA6Cfg.SuperscalarEn ? 6 : 3);
    cfg.NrWbPorts = unsigned'(NrWbPorts);
    cfg.EnableAccelerator = bit'(EnableAccelerator);
    cfg.PerfCounterEn = CVA6Cfg.PerfCounterEn;
    cfg.MmuPresent = CVA6Cfg.MmuPresent;
    cfg.RVS = CVA6Cfg.RVS;
    cfg.RVU = CVA6Cfg.RVU;
    cfg.SoftwareInterruptEn = CVA6Cfg.SoftwareInterruptEn;

    cfg.HaltAddress = CVA6Cfg.HaltAddress;
    cfg.ExceptionAddress = CVA6Cfg.ExceptionAddress;
    cfg.RASDepth = CVA6Cfg.RASDepth;
    cfg.BTBEntries = CVA6Cfg.BTBEntries;
    cfg.BPType = CVA6Cfg.BPType;
    cfg.BHTEntries = CVA6Cfg.BHTEntries;
    cfg.BHTHist = CVA6Cfg.BHTHist;
    cfg.DmBaseAddress = CVA6Cfg.DmBaseAddress;
    cfg.TvalEn = CVA6Cfg.TvalEn;
    cfg.DirectVecOnly = CVA6Cfg.DirectVecOnly;
    cfg.NrPMPEntries = CVA6Cfg.NrPMPEntries;
    cfg.PMPCfgRstVal = CVA6Cfg.PMPCfgRstVal;
    cfg.PMPAddrRstVal = CVA6Cfg.PMPAddrRstVal;
    cfg.PMPEntryReadOnly = CVA6Cfg.PMPEntryReadOnly;
    cfg.PMPNapotEn = CVA6Cfg.PMPNapotEn;
    cfg.NOCType = CVA6Cfg.NOCType;
    cfg.CLICNumInterruptSrc = CVA6Cfg.CLICNumInterruptSrc;
    cfg.NrNonIdempotentRules = CVA6Cfg.NrNonIdempotentRules;
    cfg.NonIdempotentAddrBase = CVA6Cfg.NonIdempotentAddrBase;
    cfg.NonIdempotentLength = CVA6Cfg.NonIdempotentLength;
    cfg.NrExecuteRegionRules = CVA6Cfg.NrExecuteRegionRules;
    cfg.ExecuteRegionAddrBase = CVA6Cfg.ExecuteRegionAddrBase;
    cfg.ExecuteRegionLength = CVA6Cfg.ExecuteRegionLength;
    cfg.NrCachedRegionRules = CVA6Cfg.NrCachedRegionRules;
    cfg.CachedRegionAddrBase = CVA6Cfg.CachedRegionAddrBase;
    cfg.CachedRegionLength = CVA6Cfg.CachedRegionLength;
    cfg.MaxOutstandingStores = CVA6Cfg.MaxOutstandingStores;
    cfg.DebugEn = CVA6Cfg.DebugEn;
    cfg.NonIdemPotenceEn = (CVA6Cfg.NrNonIdempotentRules > 0) && (CVA6Cfg.NonIdempotentLength > 0);
    cfg.AxiBurstWriteEn = CVA6Cfg.AxiBurstWriteEn;

    cfg.ICACHE_SET_ASSOC = CVA6Cfg.IcacheSetAssoc;
    cfg.ICACHE_SET_ASSOC_WIDTH = CVA6Cfg.IcacheSetAssoc > 1 ? $clog2(CVA6Cfg.IcacheSetAssoc) :
        CVA6Cfg.IcacheSetAssoc;
    cfg.ICACHE_INDEX_WIDTH = ICACHE_INDEX_WIDTH;
    cfg.ICACHE_TAG_WIDTH = cfg.PLEN - ICACHE_INDEX_WIDTH;
    cfg.ICACHE_LINE_WIDTH = CVA6Cfg.IcacheLineWidth;
    cfg.ICACHE_USER_LINE_WIDTH = (CVA6Cfg.AxiUserWidth == 1) ? 4 : CVA6Cfg.IcacheLineWidth;
    cfg.DCacheType = CVA6Cfg.DCacheType;
    cfg.DcacheIdWidth = CVA6Cfg.DcacheIdWidth;
    cfg.DCACHE_SET_ASSOC = CVA6Cfg.DcacheSetAssoc;
    cfg.DCACHE_SET_ASSOC_WIDTH = CVA6Cfg.DcacheSetAssoc > 1 ? $clog2(CVA6Cfg.DcacheSetAssoc) :
        CVA6Cfg.DcacheSetAssoc;
    cfg.DCACHE_INDEX_WIDTH = DCACHE_INDEX_WIDTH;
    cfg.DCACHE_TAG_WIDTH = cfg.PLEN - DCACHE_INDEX_WIDTH;
    cfg.DCACHE_LINE_WIDTH = CVA6Cfg.DcacheLineWidth;
    cfg.DCACHE_USER_LINE_WIDTH = (CVA6Cfg.AxiUserWidth == 1) ? 4 : CVA6Cfg.DcacheLineWidth;
    cfg.DCACHE_USER_WIDTH = CVA6Cfg.AxiUserWidth;
    cfg.DCACHE_OFFSET_WIDTH = DCACHE_OFFSET_WIDTH;
    cfg.DCACHE_NUM_WORDS = 2 ** (DCACHE_INDEX_WIDTH - DCACHE_OFFSET_WIDTH);

    cfg.DCACHE_MAX_TX = unsigned'(2 ** CVA6Cfg.MemTidWidth);

    cfg.DcacheFlushOnFence = CVA6Cfg.DcacheFlushOnFence;
    cfg.DcacheInvalidateOnFlush = CVA6Cfg.DcacheInvalidateOnFlush;

    cfg.DATA_USER_EN = CVA6Cfg.DataUserEn;
    cfg.WtDcacheWbufDepth = CVA6Cfg.WtDcacheWbufDepth;
    cfg.FETCH_USER_WIDTH = CVA6Cfg.FetchUserWidth;
    cfg.FETCH_USER_EN = CVA6Cfg.FetchUserEn;
    cfg.AXI_USER_EN = CVA6Cfg.DataUserEn | CVA6Cfg.FetchUserEn;

    cfg.FETCH_WIDTH = unsigned'(CVA6Cfg.SuperscalarEn ? 64 : 32);
    cfg.FETCH_ALIGN_BITS = $clog2(cfg.FETCH_WIDTH / 8);
    cfg.INSTR_PER_FETCH = cfg.FETCH_WIDTH / (CVA6Cfg.RVC ? 16 : 32);
    cfg.LOG2_INSTR_PER_FETCH = cfg.INSTR_PER_FETCH > 1 ? $clog2(cfg.INSTR_PER_FETCH) : 1;

    cfg.ModeW = (CVA6Cfg.XLEN == 32) ? 1 : 4;
    cfg.ASIDW = (CVA6Cfg.XLEN == 32) ? 9 : 16;
    cfg.VMIDW = (CVA6Cfg.XLEN == 32) ? 7 : 14;
    cfg.PPNW = (CVA6Cfg.XLEN == 32) ? 22 : 44;
    cfg.GPPNW = (CVA6Cfg.XLEN == 32) ? 22 : 29;
    cfg.MODE_SV = (CVA6Cfg.XLEN == 32) ? config_pkg::ModeSv32 : config_pkg::ModeSv39;
    cfg.SV = (cfg.MODE_SV == config_pkg::ModeSv32) ? 32 : 39;
    cfg.SVX = (cfg.MODE_SV == config_pkg::ModeSv32) ? 34 : 41;
    cfg.InstrTlbEntries = CVA6Cfg.InstrTlbEntries;
    cfg.DataTlbEntries = CVA6Cfg.DataTlbEntries;
    cfg.UseSharedTlb = CVA6Cfg.UseSharedTlb;
    cfg.SharedTlbDepth = CVA6Cfg.SharedTlbDepth;
    cfg.VpnLen = VpnLen;
    cfg.PtLevels = PtLevels;

    cfg.X_NUM_RS = cfg.NrRgprPorts / cfg.NrIssuePorts;
    cfg.X_ID_WIDTH = cfg.TRANS_ID_BITS;
    cfg.X_RFR_WIDTH = cfg.XLEN;
    cfg.X_RFW_WIDTH = cfg.XLEN;
    cfg.X_NUM_HARTS = 1;
    cfg.X_HARTID_WIDTH = cfg.XLEN;
    cfg.X_DUALREAD = 0;
    cfg.X_DUALWRITE = 0;
    cfg.X_ISSUE_REGISTER_SPLIT = 0;

    return cfg;
  endfunction

  

  ////////////////////
  //  Interconnect  //
  ////////////////////  

  // Copied from Cheshire. LLC=Last Level Cache
  // Return total size of LLC in bytes; this is equal to the maximum LLC SPM capacity.
  function automatic int unsigned get_llc_size(cheshire_cfg_t cfg);
    return cfg.LlcSetAssoc * cfg.LlcNumLines * cfg.LlcNumBlocks * cfg.AxiDataWidth / 8;
  endfunction

  // Static masks
//   localparam doub_bt AmSpmRegionMask = 'h03FF_FFFF;

  // Reg bus error unit indices
  localparam int unsigned RegBusErrVga        = 0;
  localparam int unsigned RegBusErrDma        = 1;
  localparam int unsigned RegBusErrCoresBase  = 2;


  // AXI Xbar master indices
  typedef struct packed {
    aw_bt [2**MaxCoresWidth-1:0] cores;
    aw_bt dbg;
    aw_bt dma;
    aw_bt slink;
    aw_bt vga;
    aw_bt usb;
    aw_bt ext_base;
    aw_bt num_in;
  } axi_in_t;

  typedef struct packed {
    aw_bt [2**MaxCoresWidth-1:0] cores;
    aw_bt num_in;
  } axi_in_cvwsoc_t;

//   function automatic axi_in_t gen_axi_in(cheshire_cfg_t cfg);
//     axi_in_t ret = '{default: '0};
//     int unsigned i = 0;
//     for (int j = 0; j < cfg.NumCores; j++) begin ret.cores[i] = i; i++; end
//     ret.dbg = i;
//     if (cfg.Dma)        begin i++; ret.dma   = i; end
//     if (cfg.SerialLink) begin i++; ret.slink = i; end
//     if (cfg.Vga)        begin i++; ret.vga   = i; end
//     if (cfg.Usb)        begin i++; ret.usb   = i; end
//     i++;
//     ret.ext_base = i;
//     ret.num_in = i + cfg.AxiExtNumMst;
//     return ret;
//   endfunction

  function automatic axi_in_cvwsoc_t gen_cvwsoc_axi_in(cheshire_cfg_t cfg);
    axi_in_cvwsoc_t ret = '{default: '0};
    int unsigned i = 0;
    for (int j = 0; j < cfg.NumCores; j++) begin ret.cores[i] = i; i++; end
    ret.num_in = i;
    return ret;
  endfunction


  // A generic address rule type (max-width addresses)
  typedef struct packed {
    aw_bt   idx;
    doub_bt start;
    doub_bt pte;
  } arul_t;

//   // AXI Xbar slave indices and map
//   typedef struct packed {
//     aw_bt dbg;
//     aw_bt reg_demux;
//     aw_bt llc;
//     aw_bt spm;
//     aw_bt dma;
//     aw_bt slink;
//     aw_bt ext_base;
//     aw_bt num_out;
//     aw_bt num_rules;
//     arul_t [aw_bt'(-1):0] map;
//   } axi_out_t;

//   function automatic axi_out_t gen_axi_out(cheshire_cfg_t cfg);
//     doub_bt SizeSpm = get_llc_size(cfg);
//     axi_out_t ret = '{dbg: 0, reg_demux: 1, default: '0};
//     int unsigned i = 1, r = 1;
//     ret.map[0] = '{0, EXTROM_BASE_ADDR,   EXTROM_BASE_ADDR   + EXTROM_SIZE};
//     ret.map[1] = '{1, BOOTROM_BASE_ADDR,  'h0C00_0000};
//     // Whether we have an LLC or a bypass, the output port is has its
//     // own Xbar output with the specified region iff it is connected.
//     if (cfg.LlcOutConnect) begin i++; r++; ret.llc = i;
//         ret.map[r] = '{i, cfg.LlcOutRegionStart, cfg.LlcOutRegionEnd}; end
//     // We can only internally map the SPM region if an LLC exists.
//     // Otherwise, we assume external ports map and back the SPM region.
//     // We map both the cached and uncached regions.
//     if (cfg.LlcNotBypass) begin
//       ret.spm = i;
//       r++; ret.map[r] = '{i, SPM_BASE_ADDR,     SPM_BASE_ADDR     + SizeSpm};
//       r++; ret.map[r] = '{i, SPM_UNC_BASE_ADDR, SPM_UNC_BASE_ADDR + SizeSpm};
//     end
//     if (cfg.Dma)          begin i++; r++; ret.dma = i; ret.map[r] = '{i, DMA_BASE_ADDR, DMA_BASE_ADDR + DMA_SIZE}; end
//     if (cfg.SerialLink)   begin i++; r++; ret.slink = i;
//         ret.map[r] = '{i, cfg.SlinkRegionStart, cfg.SlinkRegionEnd}; end
//     // External port indices start after internal ones
//     i++; r++;
//     ret.ext_base  = i;
//     ret.num_out   = i + cfg.AxiExtNumSlv;
//     ret.num_rules = r + cfg.AxiExtNumRules + cfg.RegExtNumRules;
//     // Append external AXI rules to map
//     for (int k = 0; k < cfg.AxiExtNumRules; ++k) begin
//       ret.map[r] = '{ret.ext_base + cfg.AxiExtRegionIdx[k],
//           cfg.AxiExtRegionStart[k], cfg.AxiExtRegionEnd[k]};
//       r++;
//     end
//     // Append external reg rules to map; these are directed to the reg demux
//     for (int j = 0; j < cfg.RegExtNumRules; ++j) begin
//       ret.map[r] = '{1, cfg.RegExtRegionStart[j], cfg.RegExtRegionEnd[j]};
//       r++;
//     end
//     return ret;
//   endfunction


//   // Reg demux slave indices and map
//   typedef struct packed {
//     aw_bt err;    // Error slave for decoder; has no rules
//     aw_bt clint;
//     aw_bt plic;
//     aw_bt regs;
//     aw_bt bootrom;
//     aw_bt llc;
//     aw_bt uart;
//     aw_bt i2c;
//     aw_bt spi_host;
//     aw_bt gpio;
//     aw_bt slink;
//     aw_bt vga;
//     aw_bt usb;
//     aw_bt axirt;
//     aw_bt irq_router;
//     aw_bt [2**MaxCoresWidth-1:0] bus_err;
//     aw_bt [2**MaxCoresWidth-1:0] clic;
//     aw_bt ext_base;
//     aw_bt num_out;
//     aw_bt num_rules;
//     bit [2**$bits(aw_bt)-1:0] apb_mask;  // Bit i set iff reg-bus port i uses APB
//     arul_t [aw_bt'(-1):0] map;
//   } reg_out_t;


//   function automatic reg_out_t gen_reg_out(cheshire_cfg_t cfg);
//     reg_out_t ret = '{err: 0, clint: 1, plic: 2, regs: 3, default: '0};
//     int unsigned i = 3, r = 2;
//     ret.map[0] = '{1, CLINT_BASE_ADDR, CLINT_BASE_ADDR + CLINT_SIZE};
//     ret.map[1] = '{2, PLIC_BASE_ADDR,  PLIC_BASE_ADDR  + PLIC_SIZE};
//     ret.map[2] = '{3, REGS_BASE_ADDR,  REGS_BASE_ADDR  + REGS_SIZE};
//     if (cfg.Bootrom)      begin i++; ret.bootrom    = i; r++; ret.map[r] = '{i, BOOTROM_BASE_ADDR,    BOOTROM_BASE_ADDR    + BOOTROM_SIZE }; end
//     if (cfg.LlcNotBypass) begin i++; ret.llc        = i; r++; ret.map[r] = '{i, LLC_BASE_ADDR,        LLC_BASE_ADDR        + LLC_SIZE}; end
//     if (cfg.Uart)         begin i++; ret.uart       = i; r++; ret.map[r] = '{i, UART_BASE_ADDR,       UART_BASE_ADDR       + UART_SIZE}; end
//     if (cfg.I2c)          begin i++; ret.i2c        = i; r++; ret.map[r] = '{i, I2C_BASE_ADDR,        I2C_BASE_ADDR        + I2C_SIZE}; end
//     if (cfg.SpiHost)      begin i++; ret.spi_host   = i; r++; ret.map[r] = '{i, SPIH_BASE_ADDR,       SPIH_BASE_ADDR       + SPIH_SIZE}; end
//     if (cfg.Gpio)         begin i++; ret.gpio       = i; r++; ret.map[r] = '{i, GPIO_BASE_ADDR,       GPIO_BASE_ADDR       + GPIO_SIZE}; end
//     if (cfg.SerialLink)   begin i++; ret.slink      = i; r++; ret.map[r] = '{i, SLINK_BASE_ADDR,      SLINK_BASE_ADDR      + SLINK_SIZE}; end
//     if (cfg.Vga)          begin i++; ret.vga        = i; r++; ret.map[r] = '{i, VGA_BASE_ADDR,        VGA_BASE_ADDR        + VGA_SIZE}; end
//     if (cfg.Usb)          begin i++; ret.usb        = i; r++; ret.map[r] = '{i, USB_BASE_ADDR,        USB_BASE_ADDR        + USB_SIZE}; end
//     if (cfg.IrqRouter)    begin i++; ret.irq_router = i; r++; ret.map[r] = '{i, IRQ_ROUTER_BASE_ADDR, IRQ_ROUTER_BASE_ADDR + IRQ_ROUTER_SIZE}; end
//     if (cfg.AxiRt)        begin i++; ret.axirt      = i; r++; ret.map[r] = '{i, AXIRT_BASE_ADDR,      AXIRT_BASE_ADDR      + AXIRT_SIZE}; end
//     if (cfg.Clic) for (int j = 0; j < cfg.NumCores; j++) begin
//       i++; ret.clic[j]    = i; r++; ret.map[r] = '{i, CLIC_BASE_ADDR + j*CLIC_SIZE, CLIC_BASE_ADDR + (j+1)*CLIC_SIZE};
//     end
//     if (cfg.BusErr) for (int j = 0; j < 2 + cfg.NumCores; j++) begin
//       i++; ret.bus_err[j] = i; r++; ret.map[r] = '{i, BUS_ERR_BASE_ADDR + j*BUS_ERR_SIZE, BUS_ERR_BASE_ADDR + (j+1)*BUS_ERR_SIZE};
//     end
//     i++; r++;
//     ret.ext_base  = i;
//     ret.num_out   = i + cfg.RegExtNumSlv;
//     ret.num_rules = r + cfg.RegExtNumRules;
//     // Append external slaves at end of map
//     for (int k = 0; k < cfg.RegExtNumRules; ++k) begin
//       ret.map[r] = '{ret.ext_base + cfg.RegExtRegionIdx[k],
//           cfg.RegExtRegionStart[k], cfg.RegExtRegionEnd[k]};
//       r++;
//       end
//     // Set APB mask for all reg-bus ports whose IP uses an APB4-flat interface
//     ret.apb_mask = '0;
//     ret.apb_mask[ret.regs] = 1'b1;
//     ret.apb_mask[ret.slink] = 1'b1;
//     return ret;
//   endfunction

  ////////////
  //  CVA6  //
  ////////////

  // CVA6 imposes an ID width of 4, but only 7 of 16 IDs are ever used
  localparam int unsigned Cva6IdWidth = 4;
  localparam int unsigned Cva6IdsUsed = 7;
  typedef logic [Cva6IdWidth-1:0] cva6_id_t;
  typedef int unsigned cva6_id_map_t [Cva6IdsUsed-1:0][0:1];

  // Symbols for used CVA6 IDs
  typedef enum cva6_id_t {
    Cva6IdBypMmu    = 'b1000,
    Cva6IdBypLoad   = 'b1001,
    Cva6IdBypAccel  = 'b1010,
    Cva6IdBypStore  = 'b1011,
    Cva6IdBypAmo    = 'b1100,
    Cva6IdICache    = 'b0000,
    Cva6IdDCache    = 'b0111
  } cva6_id_e;

  // Choose static colocation of IDs based on how heavily used and/or critical they are
  function automatic cva6_id_map_t gen_cva6_id_map(cheshire_cfg_t cfg);
    int unsigned DefaultMapEntry[2] = '{0, 0};
    case (cfg.AxiMstIdWidth)
      // Provide exclusive ID to I-cache to prevent fetch blocking
      1: return '{'{Cva6IdBypMmu, 0}, '{Cva6IdBypLoad, 0}, '{Cva6IdBypAccel, 0}, '{Cva6IdBypStore, 0},
                  '{Cva6IdBypAmo, 0}, '{Cva6IdICache,  1}, '{Cva6IdDCache,   0}};
      // Colocate Load/Store and MMU/AMO bypasses, respectively
      2: return '{'{Cva6IdBypMmu, 0}, '{Cva6IdBypLoad, 1}, '{Cva6IdBypAccel, 1}, '{Cva6IdBypStore, 1},
                  '{Cva6IdBypAmo, 0}, '{Cva6IdICache,  2}, '{Cva6IdDCache,   3}};
      // Compress output ID space without any serialization
      3: return '{'{Cva6IdBypMmu, 0}, '{Cva6IdBypLoad, 1}, '{Cva6IdBypAccel, 6}, '{Cva6IdBypStore, 2},
                  '{Cva6IdBypAmo, 3}, '{Cva6IdICache,  4}, '{Cva6IdDCache,   5}};
      // With 4b of ID or more, no remapping is necessary; return redundant 0 -> 0 ID remaps.
      // This leaves ID mapping unaltered only if `MstIdBaseOffset` in `axi_id_serialize` is 0.
      default: return '{Cva6IdsUsed {DefaultMapEntry}};
    endcase
  endfunction

  function automatic config_pkg::cva6_user_cfg_t gen_cva6_cfg(cheshire_cfg_t cfg);
    doub_bt SizeSpm = get_llc_size(cfg);
    doub_bt SizeLlcOut = cfg.LlcOutRegionEnd - cfg.LlcOutRegionStart;
    doub_bt CieBase   = cfg.Cva6ExtCieOnTop ? 64'h8000_0000 - cfg.Cva6ExtCieLength : 64'h2000_0000;
    doub_bt NoCieBase = cfg.Cva6ExtCieOnTop ? 64'h2000_0000 : 64'h2000_0000 + cfg.Cva6ExtCieLength;
    // Base our config on the upstream default for this variant
    config_pkg::cva6_user_cfg_t ret = cva6_config_pkg::cva6_cfg;
    // Modify what we need to
    ret.AxiAddrWidth          = cfg.AddrWidth;
    ret.AxiDataWidth          = cfg.AxiDataWidth;
    ret.AxiIdWidth            = Cva6IdWidth;
    ret.AxiUserWidth          = cfg.AxiUserWidth;
    ret.CvxifEn               = 0;
    ret.DmBaseAddress         = EXTROM_BASE_ADDR;
    ret.HaltAddress           = 'h800; // Relative to EXTROM_BASE_ADDR
    ret.ExceptionAddress      = 'h810; // Relative to EXTROM_BASE_ADDR
    ret.NrNonIdempotentRules  = 2;   // Periphs, ExtNonCI;
    ret.NonIdempotentAddrBase = {EXTROM_BASE_ADDR, NoCieBase};
    ret.NOCType               = config_pkg::NOC_TYPE_AXI4_ATOP;
    ret.NonIdempotentLength   = {SPM_BASE_ADDR, 64'h6000_0000 - cfg.Cva6ExtCieLength};
    ret.NrExecuteRegionRules  = 6;   // Debug, Bootrom, SPM, SPM Uncached, LLCOut, ExtCI;
    ret.ExecuteRegionAddrBase = {EXTROM_BASE_ADDR, BOOTROM_BASE_ADDR, SPM_BASE_ADDR, SPM_UNC_BASE_ADDR, cfg.LlcOutRegionStart, CieBase};
    ret.ExecuteRegionLength   = {EXTROM_SIZE,      BOOTROM_SIZE     , SizeSpm      , SizeSpm          , SizeLlcOut           , cfg.Cva6ExtCieLength};

    ret.NrCachedRegionRules   = 3;   // CachedSPM, LLCOut, ExtCI;
    ret.CachedRegionAddrBase  = {SPM_BASE_ADDR, cfg.LlcOutRegionStart,  CieBase};
    ret.CachedRegionLength    = {SizeSpm,       SizeLlcOut,             cfg.Cva6ExtCieLength};


    ret.DebugEn               = 1;
    ret.RVSCLIC               = cfg.Clic;
    ret.RVXHCLIC              = cfg.ClicVsclic;
    ret.CLICNumInterruptSrc   = NumCoreIrqs + NumIntIntrs + cfg.NumExtClicIntrs;
    // TODO: Should some things be removed from the main config?
    // TODO: Should other things be added to the main config?
    // TODO: Tune missing parameters of interest (esp. cache and interconnect) properly
    ret.RASDepth              = cfg.Cva6RASDepth;
    ret.BTBEntries            = cfg.Cva6BTBEntries;
    ret.BHTEntries            = cfg.Cva6BHTEntries;
    ret.NrPMPEntries          = cfg.Cva6NrPMPEntries;
    // Return modified config
    return ret;
  endfunction

  // Apply only CVWSoC-specific overrides on top of the Cheshire-derived CVA6 config.
  function automatic config_pkg::cva6_user_cfg_t apply_cvwsoc_cfg(
      input cvwsoc_pkg::cvwsoc_cfg_t cvwsoc_cfg,
      input config_pkg::cva6_user_cfg_t cfg
  );
    config_pkg::cva6_user_cfg_t ret;
    doub_bt ExtMemBase;
    doub_bt ExtMemSize;
    doub_bt UncachedBase;
    doub_bt UncachedSize;
    doub_bt CachedHiBase;

    ret = cfg;
    ExtMemBase   = cvwsoc_cfg.wally.EXT_MEM_BASE;
    ExtMemSize   = cvwsoc_cfg.wally.EXT_MEM_RANGE + 64'd1;
    UncachedBase = cvwsoc_cfg.wally.UNCACHED_MEM_BASE;
    UncachedSize = cvwsoc_cfg.wally.UNCACHED_MEM_RANGE + 64'd1;
    CachedHiBase = UncachedBase + UncachedSize;

    // Remark: Default CVA6 16-byte cache line is too small for our setup
    // Map Wally's cache geometry to the equivalent CVA6 user configuration.
    // Wally specifies capacity per way; CVA6 specifies total cache capacity.
    ret.IcacheByteSize  = unsigned'(cvwsoc_cfg.wally.ICACHE_NUMWAYS * cvwsoc_cfg.wally.ICACHE_WAYSIZEINBYTES);
    ret.IcacheSetAssoc  = unsigned'(cvwsoc_cfg.wally.ICACHE_NUMWAYS);
    ret.IcacheLineWidth = unsigned'(cvwsoc_cfg.wally.ICACHE_LINELENINBITS);
    ret.DcacheByteSize  = unsigned'(cvwsoc_cfg.wally.DCACHE_NUMWAYS * cvwsoc_cfg.wally.DCACHE_WAYSIZEINBYTES);
    ret.DcacheSetAssoc  = unsigned'(cvwsoc_cfg.wally.DCACHE_NUMWAYS);
    ret.DcacheLineWidth = unsigned'(cvwsoc_cfg.wally.DCACHE_LINELENINBITS);

    // Bring the RV32 CVA6 ISA in line with what's used by the 
    // CVWSoC/CVA6 integration.  The upstream RV32 base package is
    // IMAF C only, while the CV64 package also enables D, Zicond, and Zcb.
    // C together with D also provides Zcd.
    // CVA6 RV32 configuration does not support the hypervisor extension.
    ret.RVB      = 1;
    ret.RVZCB    = 1;
    ret.RVZiCond = 1;
    // CV32A6 officially doesn't support D extension for CV32A6
    //cfg.RVD      = 1;
    ret.RVZicntr = 1;
    ret.RVZihpm  = 1;

    // Default 48 bits not supported in current cvwsoc infrastructure
    ret.AxiAddrWidth = 32;

    // The LLC sits in front of external memory, so its CPU-visible range is
    // exactly the CVWSoC external-memory range, whether or not the LLC is
    // currently instantiated.
    ret.NrExecuteRegionRules  = 2;
    ret.ExecuteRegionAddrBase = {cvwsoc_cfg.wally.BOOTROM_BASE, ExtMemBase};
    ret.ExecuteRegionLength   = {cvwsoc_cfg.wally.BOOTROM_RANGE + 64'd1, ExtMemSize};

    if (cvwsoc_cfg.wally.UNCACHED_MEM_SUPPORTED) begin
      ret.NrCachedRegionRules  = 2;
      ret.CachedRegionAddrBase = {ExtMemBase, CachedHiBase};
      ret.CachedRegionLength   = {UncachedBase - ExtMemBase,
                                  (ExtMemBase + ExtMemSize) - CachedHiBase};
    end else begin
      ret.NrCachedRegionRules  = 1;
      ret.CachedRegionAddrBase = {ExtMemBase};
      ret.CachedRegionLength   = {ExtMemSize};
    end

    ret.NrNonIdempotentRules  = 0;
    ret.NonIdempotentAddrBase = '0;
    ret.NonIdempotentLength   = '0;

    // No Debug for now
    ret.DebugEn          = 1'b0;
    ret.DmBaseAddress    = '0;
    ret.HaltAddress      = '0;
    ret.ExceptionAddress = '0;

    // Return modified config
    return ret;
  endfunction

  //------------------------
  // Cheshire Xilinx config

  // Use default config as far as possible
  function automatic cheshire_cfg_t gen_cheshire_xilinx_cfg();
    cheshire_cfg_t ret  = DefaultCfg;
    ret.RtcFreq         = 1000000;
    ret.SerialLink      = 0;
//   `ifdef USE_USB
//     ret.Usb = 1;
//   `else
    ret.Usb = 0;
//   `endif
//   `ifdef USE_CFG_REGS
//     ret.RegExtNumSlv   = 1;
//     ret.RegExtNumRules = 1;
//     // Mirror the address map of the internal configuration registers.
//     // * 256K @ AXI: 0x4000_0000
//     // * 4K   @ AXI: 0x4100_0000
//     // * 256K @ Reg: 0x4200_0000
//     // * 4K   @ Reg: 0x4300_0000
//     ret.RegExtRegionIdx   [0] = 0;
//     ret.RegExtRegionStart [0] = 32'h4300_0000;
//     ret.RegExtRegionEnd   [0] = 32'h4300_1000;
//   `endif
//   `ifdef USE_VCLIC
//     ret.Clic = 1;
//     ret.ClicVsclic = 1;
//     ret.ClicVsprio = 1;
//     ret.ClicNumVsctxts = 4;
//     ret.ClicPrioWidth = 1;
//   `endif
    return ret;
  endfunction





endpackage
