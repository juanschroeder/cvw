// APB peripherals retained in the AHB island.  CLINT is deliberately absent:
// it is local to cvwsoc_cpu and is intercepted before the root AXI crossbar.
module cvwsoc_apb import cvw::*; #(parameter cvw_t P) (
  input  logic                 HCLK,
  input  logic                 HRESETn,
  input  logic [4:0]           HSEL,
  input  logic [P.PA_BITS-1:0] HADDR,
  input  logic [P.AHBW-1:0]    HWDATA,
  input  logic [P.AHBW/8-1:0]  HWSTRB,
  input  logic                 HWRITE,
  input  logic [1:0]           HTRANS,
  input  logic                 HREADY,
  output logic [P.AHBW-1:0]    HRDATA,
  output logic                 HRESP,
  output logic                 HREADYOUT,
  output logic                 MExtInt,
  output logic                 SExtInt,
  input  logic [31:0]          GPIOIN,
  output logic [31:0]          GPIOOUT,
  output logic [31:0]          GPIOEN,
  input  logic                 UARTSin,
  output logic                 UARTSout,
  input  logic                 SPIIn,
  output logic                 SPIOut,
  output logic [3:0]           SPICS,
  output logic                 SPICLK,
  input  logic                 SDCIn,
  output logic                 SDCCmd,
  output logic [3:0]           SDCCS,
  output logic                 SDCCLK,
  input  logic                 WBUartIntr,
  input  logic                 WBEthIntr,
  input  logic                 AXI_DMAIntr,
  input  logic                 AXI_USBIntr,
  input  logic                 AXI_EthIntr,
  input  logic                 AXI_DummyIntr,
  input  logic                 AXI_SDHCIIntr
);
  logic                        PCLK, PRESETn, PWRITE, PENABLE;
  logic [4:0]                  PSEL;
  logic [31:0]                 PADDR;
  logic [P.AHBW-1:0]           PWDATA;
  logic [P.AHBW/8-1:0]         PSTRB;
  logic [P.AHBW-1:0]           PWDATA_raw;
  logic [P.AHBW/8-1:0]         PSTRB_raw;
  logic [4:0]                  PREADY;
  logic [4:0][P.AHBW-1:0]      PRDATA;
  logic                        UARTIntr, GPIOIntr, SPIIntr, SDCIntr;
  localparam int unsigned APB_LANE_BITS = $clog2(P.AHBW / 8);
  logic [APB_LANE_BITS-1:0]    apb_byte_lane;

  ahbapbbridge #(P, 5) bridge (
    .HCLK, .HRESETn, .HSEL, .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HTRANS, .HREADY,
    .HRDATA, .HRESP, .HREADYOUT,

    .PCLK, .PRESETn, .PSEL, .PWRITE, .PENABLE,
    .PADDR, .PWDATA(PWDATA_raw), .PSTRB(PSTRB_raw), .PREADY, .PRDATA
  );

  // This is a fix specific for Wally APB peripherals and where data is assumed
  // for subword reads and writes.
  // Wally APB peripherals consume subword data in byte lane zero.  For
  // RV32/AHBW64 the bridge already selects PADDR[2]'s 32-bit half; normalize
  // only the remaining byte lane.
  if ((P.XLEN == 32) && (P.AHBW == 64)) begin : gen_rv32_w64_lanes
    assign apb_byte_lane = PADDR[1:0];
    assign PWDATA = PWDATA_raw >> (apb_byte_lane * 8);
    assign PSTRB  = PSTRB_raw  >> apb_byte_lane;
  end else begin : gen_normalize_cva6_lanes
    assign apb_byte_lane = PADDR[APB_LANE_BITS-1:0];
    assign PWDATA = PWDATA_raw >> (apb_byte_lane * 8);
    assign PSTRB  = PSTRB_raw  >> apb_byte_lane;
  end

  if (P.PLIC_SUPPORTED) begin : plic
    plic_apb #(P) plic (
      .PCLK, .PRESETn, .PSEL(PSEL[1]), .PADDR(PADDR[27:0]), .PWDATA, .PSTRB,
      .PWRITE, .PENABLE, .PRDATA(PRDATA[1]), .PREADY(PREADY[1]),
      .UARTIntr,
      .GPIOIntr,
      .SDCIntr,
      .SPIIntr,
      .WBUartIntr,
      .WBEthIntr,
      .DMAIntr(AXI_DMAIntr),
      .USBIntr(AXI_USBIntr),
      .AXIEthIntr(AXI_EthIntr),
      .AXIDummyIntr(AXI_DummyIntr),
      .AXISDHCIIntr(AXI_SDHCIIntr),
      .MExtInt,
      .SExtInt
    );
  end else begin : no_plic
    assign MExtInt = 1'b0;
    assign SExtInt = 1'b0;
  end

  if (P.GPIO_SUPPORTED) begin : gpio
    gpio_apb #(P) gpio (
      .PCLK, .PRESETn, .PSEL(PSEL[0]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB,
      .PWRITE, .PENABLE, .PRDATA(PRDATA[0]), .PREADY(PREADY[0]), .iof0(), .iof1(),
      .GPIOIN, .GPIOOUT, .GPIOEN, .GPIOIntr
    );
  end else begin : no_gpio
    assign GPIOOUT = '0;
    assign GPIOEN = '0;
    assign GPIOIntr = 1'b0;
  end

  if (P.UART_SUPPORTED) begin : uartgen
    uart_apb #(P) uart (
      .PCLK, .PRESETn, .PSEL(PSEL[2]), .PADDR(PADDR[2:0]), .PWDATA, .PSTRB,
      .PWRITE, .PENABLE, .PRDATA(PRDATA[2]), .PREADY(PREADY[2]), .SIN(UARTSin),
      .DSRb(1'b1), .DCDb(1'b1), .CTSb(1'b0), .RIb(1'b1), .SOUT(UARTSout),
      .RTSb(), .DTRb(), .OUT1b(), .OUT2b(), .INTR(UARTIntr), .TXRDYb(), .RXRDYb()
    );
  end else begin : no_uart
    assign UARTSout = 1'b0;
    assign UARTIntr = 1'b0;
  end

  if (P.SPI_SUPPORTED) begin : spi
    spi_apb #(P) spi (
      .PCLK, .PRESETn, .PSEL(PSEL[3]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB,
      .PWRITE, .PENABLE, .PREADY(PREADY[3]), .PRDATA(PRDATA[3]),
      .SPIOut, .SPIIn, .SPICS, .SPICLK, .SPIIntr
    );
  end else begin : no_spi
    assign SPIOut = 1'b0;
    assign SPICS = '0;
    assign SPICLK = 1'b0;
    assign SPIIntr = 1'b0;
  end

  if (P.SDC_SUPPORTED) begin : sdc
    spi_apb #(P) sdc (
      .PCLK, .PRESETn, .PSEL(PSEL[4]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB,
      .PWRITE, .PENABLE, .PREADY(PREADY[4]), .PRDATA(PRDATA[4]),
      .SPIOut(SDCCmd), .SPIIn(SDCIn), .SPICS(SDCCS), .SPICLK(SDCCLK), .SPIIntr(SDCIntr)
    );
  end else begin : no_sdc
    assign SDCCmd = '0;
    assign SDCCS = '0;
    assign SDCCLK = 1'b0;
    assign SDCIntr = 1'b0;
  end
endmodule
