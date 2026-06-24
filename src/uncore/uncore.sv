///////////////////////////////////////////
// uncore.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified: Ben Bracker 6 Mar 2021 to better fit AMBA 3 AHB-Lite spec
//
// Purpose: System-on-Chip components outside the core
//          Memories, peripherals, external bus control
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module uncore import cvw::*;  #(parameter cvw_t P)(
  // AHB Bus Interface
  input  logic                 HCLK, HRESETn,
  input  logic                 TIMECLK,
  input  logic [P.PA_BITS-1:0] HADDR,
  input  logic [P.AHBW-1:0]    HWDATA,
  input  logic [P.AHBW/8-1:0]  HWSTRB,
  input  logic                 HWRITE,
  input  logic [2:0]           HSIZE,
  input  logic [2:0]           HBURST,
  input  logic [3:0]           HPROT,
  input  logic [1:0]           HTRANS,
  input  logic                 HMASTLOCK,
  input  logic [P.AHBW-1:0]    HRDATAEXT,
  input  logic                 HREADYEXT, HRESPEXT,
  output logic [P.AHBW-1:0]    HRDATA,
  output logic                 HREADY, HRESP,
  output logic                 HSELEXT,
  // peripheral pins
  output logic                 MTimerInt, MSwInt,         // Timer and software interrupts from CLINT
  output logic                 MExtInt, SExtInt,          // External interrupts from PLIC
  output logic [63:0]          MTIME_CLINT,               // MTIME, from CLINT
  input  logic [31:0]          GPIOIN,                    // GPIO pin input value
  output logic [31:0]          GPIOOUT, GPIOEN,           // GPIO pin output value and enable
  input  logic                 UARTSin,                   // UART serial input
  output logic                 UARTSout,                  // UART serial output
  input  logic                 SPIIn,
  output logic                 SPIOut,
  output logic [3:0]           SPICS,
  output logic                 SPICLK,
  input  logic                 SDCIn,
  output logic                 SDCCmd,
  output logic [3:0]           SDCCS,
  output logic                 SDCCLK
  ,
  input logic WB_UART_RX,
  output logic WB_UART_TX,
  //, output logic WB_UART_IRQ
  input logic WB_RMII_REF_CLK,
  input logic WB_RMII_CRS_DV,
  input  logic [1:0]  WB_RMII_RX_DATA,
  output logic [1:0]  WB_RMII_TX_DATA,
  output logic        WB_RMII_TX_EN,
  output logic        WB_RMII_MDC,
  inout  wire         WB_RMII_MDIO,
  output logic        WB_RMII_RST_N,
  input logic        WB_RMII_PHY_IRQ, //coming from the PHY! (unused)
  input logic AXI_DMAIntr,
  input logic AXI_USBIntr,
  input logic AXI_EthIntr,
  input logic AXI_DummyIntr,
  input logic AXI_SDHCIIntr
);

  logic [P.AHBW-1:0]           HREADRam, HREADSDC;
  // Wishbone stuff
  logic [P.AHBW-1:0]  HREADWbIsland;
  logic               HRESPWbIsland, HREADYWbIsland;
  // AXI stuff
  logic [29:0]         wb_adr;
  logic [31:0]         wb_wdat, wb_rdat;
  logic [3:0]          wb_sel;
  logic                wb_we, wb_cyc, wb_stb, wb_ack, wb_err;

  logic [21:0]                 HSELRegions;
  logic                        HSELDTIM, HSELIROM, HSELRam, HSELCLINT, HSELPLIC, HSELGPIO, HSELUART,HSELSDC, HSELSPI;
  logic                        HSELDTIMD, HSELIROMD, HSELEXTD_DDR, HSELRamD, HSELCLINTD, HSELPLICD, HSELGPIOD, HSELUARTD, HSELSDCD, HSELSPID;
  // Wishbone extension
  logic                        HSELWbIsland;
  logic                        HSELWbIslandD;
  // AXI DMA
  logic                        HSELAXIDMA;
  logic                        HSELAXIDMAD;
  logic                        HSELEXTD_ALL;
  logic                        HSELEXT_DDR;
  logic                        HRESPRam,  HRESPSDC;
  logic                        HREADYRam, HRESPSDCD;
  logic [P.AHBW-1:0]           HREADBootRom;
  logic                        HSELBootRom, HSELBootRomD, HRESPBootRom, HREADYBootRom, HREADYSDC;
  logic                        HSELNoneD;
  logic                        UARTIntr,GPIOIntr, SPIIntr;
  logic                        WBUartIntr, WBEthIntr;
  logic                        SDCIntM;
  //VGA (AXI bus)
  logic                        HSELAXIVGA;
  logic                        HSELAXIVGAD;
  //USB (AXI bus)
  logic                        HSELAXIUSB;
  logic                        HSELAXIUSBD;
  //ETH (AXI bus)
  logic                        HSELAXIETH;
  logic                        HSELAXIETHD;
  //LITEDRAM Wishbone intf (AXI bus)
  logic                        HSELAXILITEDRAM;
  logic                        HSELAXILITEDRAMD;
  // Dummy AXI peripheral
  logic                        HSELAXIDUMMY;
  logic                        HSELAXIDUMMYD;
  // SDHCI AXI peripheral
  logic                        HSELAXISDHCI;
  logic                        HSELAXISDHCID;
  // iDMA desc64 AXI peripheral
  logic                        HSELAXIIDMA;
  logic                        HSELAXIIDMAD;
  // iDMA reg64 AXI peripheral
  logic                        HSELAXIIDMAREG64;
  logic                        HSELAXIIDMAREG64D;


  logic                        PCLK, PRESETn, PWRITE, PENABLE;
  logic [5:0]                  PSEL;
  logic [31:0]                 PADDR;
  logic [P.AHBW-1:0]           PWDATA;
  logic [P.AHBW/8-1:0]         PSTRB;
  /* verilator lint_off UNDRIVEN */ // undriven in rv32e configuration
  logic [5:0]                  PREADY;
  logic [5:0][P.AHBW-1:0]      PRDATA;
  /* verilator lint_on UNDRIVEN */
  logic [P.AHBW-1:0]           HREADBRIDGE;
  logic                        HRESPBRIDGE, HREADYBRIDGE, HSELBRIDGE, HSELBRIDGED;
  /* SDC Interrupt (SPI Controller) */
  logic                        SDCIntr;
  /* DMA INTR */
  logic                       DMAIntr;
  assign DMAIntr = AXI_DMAIntr;
  /* USB INTR */
  logic                       USBIntr;
  assign USBIntr = AXI_USBIntr;
  logic                       AXIEthIntr;
  assign AXIEthIntr = AXI_EthIntr;
  logic                       AXIDummyIntr;
  assign AXIDummyIntr = AXI_DummyIntr;
  logic                       AXISDHCIIntr;
  assign AXISDHCIIntr = AXI_SDHCIIntr;


  // Determine which region of physical memory (if any) is being accessed
  // Use a trimmed down portion of the PMA checker - only the address decoders
  // Set access types to all 1 as don't cares because the MMU has already done access checking
  adrdecs #(P) adrdecs(HADDR, 1'b1, 1'b1, 1'b1, HSIZE[1:0], HSELRegions);

  // unswizzle HSEL signals
  assign {HSELAXIIDMAREG64, HSELAXIIDMA, HSELAXISDHCI, HSELAXIDUMMY, HSELAXILITEDRAM, HSELAXIETH, HSELAXIUSB, HSELAXIVGA, HSELAXIDMA, HSELWbIsland, HSELSPI, HSELSDC, HSELPLIC, HSELUART, HSELGPIO, HSELCLINT, HSELRam, HSELBootRom, HSELEXT_DDR, HSELIROM, HSELDTIM} = HSELRegions[21:1];

  // AHB -> APB bridge
  ahbapbbridge #(P, 6) ahbapbbridge (
    .HCLK, .HRESETn, .HSEL({HSELSDC, HSELSPI, HSELUART, HSELPLIC, HSELCLINT, HSELGPIO}), .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HTRANS, .HREADY,
    .HRDATA(HREADBRIDGE), .HRESP(HRESPBRIDGE), .HREADYOUT(HREADYBRIDGE),
    .PCLK, .PRESETn, .PSEL, .PWRITE, .PENABLE, .PADDR, .PWDATA, .PSTRB, .PREADY, .PRDATA);
  assign HSELBRIDGE = HSELGPIO | HSELCLINT | HSELPLIC | HSELUART | HSELSPI | HSELSDC; // if any of the bridge signals are selected

  // on-chip RAM
  if (P.UNCORE_RAM_SUPPORTED) begin : ram
    ram_ahb #(.P(P), .RANGE(P.UNCORE_RAM_RANGE), .PRELOAD(P.UNCORE_RAM_PRELOAD)) ram (
      .HCLK, .HRESETn, .HSELRam, .HADDR, .HWRITE, .HREADY,
      .HTRANS, .HWDATA, .HWSTRB, .HREADRam, .HRESPRam, .HREADYRam);
  end else assign {HREADRam, HRESPRam, HREADYRam} = '0;

 if (P.BOOTROM_SUPPORTED) begin : bootrom
    rom_ahb #(.P(P), .RANGE(P.BOOTROM_RANGE), .PRELOAD(P.BOOTROM_PRELOAD))
    bootrom(.HCLK, .HRESETn, .HSELRom(HSELBootRom), .HADDR, .HREADY, .HTRANS,
      .HREADRom(HREADBootRom), .HRESPRom(HRESPBootRom), .HREADYRom(HREADYBootRom));
  end else assign {HREADBootRom, HRESPBootRom, HREADYBootRom} = '0;

  // memory-mapped I/O peripherals
  if (P.CLINT_SUPPORTED == 1) begin : clint
    clint_apb #(P) clint(.PCLK, .PRESETn, .PSEL(PSEL[1]), .PADDR(PADDR[15:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PRDATA(PRDATA[1]), .PREADY(PREADY[1]), .MTIME(MTIME_CLINT), .MTimerInt, .MSwInt);
  end else begin : clint
    assign MTIME_CLINT = '0;
    assign MTimerInt = 1'b0; assign MSwInt = 1'b0;
  end

  if (P.PLIC_SUPPORTED == 1) begin : plic
    plic_apb #(P) plic(.PCLK, .PRESETn, .PSEL(PSEL[2]), .PADDR(PADDR[27:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PRDATA(PRDATA[2]), .PREADY(PREADY[2]), .UARTIntr, .GPIOIntr, .SDCIntr, .SPIIntr, .WBUartIntr, .WBEthIntr, .DMAIntr, .USBIntr, .AXIEthIntr,  .AXIDummyIntr,  .AXISDHCIIntr, .MExtInt, .SExtInt);
  end else begin : plic
    assign MExtInt = 1'b0;
    assign SExtInt = 1'b0;
  end

  if (P.GPIO_SUPPORTED == 1) begin : gpio
    gpio_apb #(P) gpio(
      .PCLK, .PRESETn, .PSEL(PSEL[0]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PRDATA(PRDATA[0]), .PREADY(PREADY[0]),
      .iof0(), .iof1(), .GPIOIN, .GPIOOUT, .GPIOEN, .GPIOIntr);
  end else begin : gpio
    assign GPIOOUT = '0; assign GPIOEN = '0; assign GPIOIntr = 1'b0;
  end

  if (P.UART_SUPPORTED == 1) begin : uartgen // Hack to work around Verilator bug https://github.com/verilator/verilator/issues/4769
    uart_apb #(P) uart(
      .PCLK, .PRESETn, .PSEL(PSEL[3]), .PADDR(PADDR[2:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PRDATA(PRDATA[3]), .PREADY(PREADY[3]),
      .SIN(UARTSin), .DSRb(1'b1), .DCDb(1'b1), .CTSb(1'b0), .RIb(1'b1), // from E1A driver from RS232 interface
      .SOUT(UARTSout), .RTSb(), .DTRb(),                                // to E1A driver to RS232 interface
      .OUT1b(), .OUT2b(), .INTR(UARTIntr), .TXRDYb(), .RXRDYb());       // to CPU
  end else begin : uart
    assign UARTSout = 1'b0; assign UARTIntr = 1'b0;
  end

  if (P.SPI_SUPPORTED == 1) begin : spi
    spi_apb  #(P) spi (
      .PCLK, .PRESETn, .PSEL(PSEL[4]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PREADY(PREADY[4]), .PRDATA(PRDATA[4]),
      .SPIOut, .SPIIn, .SPICS, .SPICLK, .SPIIntr);
  end else begin : spi
    assign SPIOut = 1'b0; assign SPICS = '0; assign SPIIntr = 1'b0; assign SPICLK = 1'b0;
  end

  if (P.SDC_SUPPORTED == 1) begin : sdc
    spi_apb #(P) sdc(
      .PCLK, .PRESETn, .PSEL(PSEL[5]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PREADY(PREADY[5]), .PRDATA(PRDATA[5]),
      .SPIOut(SDCCmd), .SPIIn(SDCIn), .SPICS(SDCCS), .SPICLK(SDCCLK), .SPIIntr(SDCIntr));
  end else begin : sdc
    assign SDCCmd = '0; assign SDCCS = 4'b0; assign SDCIntr = 1'b0; assign SDCCLK = 1'b0;
  end

  if (P.WISHBONE_SUPPORTED == 1) begin : wb
    wb_ahb #(.P(P)) u_wb_ahb (
    .HCLK, .HRESETn,
    .HSELWb(HSELWbIsland), .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HTRANS, .HREADY,
    .HREADWb(HREADWbIsland), .HRESPWb(HRESPWbIsland), .HREADYWb(HREADYWbIsland),
    .wb_adr_o(wb_adr), .wb_dat_o(wb_wdat), .wb_dat_i(wb_rdat),
    .wb_sel_o(wb_sel), .wb_we_o(wb_we), .wb_cyc_o(wb_cyc), .wb_stb_o(wb_stb),
    .wb_ack_i(wb_ack), .wb_err_i(wb_err)
    );

    wb_island #(.P(P),.AW(30)) u_wb_island (
    .clk(HCLK), .rst(~HRESETn),
    .m_adr_i(wb_adr), .m_dat_i(wb_wdat), .m_dat_o(wb_rdat),
    .m_sel_i(wb_sel), .m_we_i(wb_we), .m_cyc_i(wb_cyc), .m_stb_i(wb_stb),
    .m_ack_o(wb_ack), .m_err_o(wb_err)
    , .uart_rx_i(WB_UART_RX)
    , .uart_tx_o(WB_UART_TX)
    , .uart_irq_o(WBUartIntr)

    ,.rmii_ref_clk(WB_RMII_REF_CLK),
    .rmii_crs_dv(WB_RMII_CRS_DV),
    .rmii_rx_data(WB_RMII_RX_DATA),
    .rmii_tx_data(WB_RMII_TX_DATA),
    .rmii_tx_en(WB_RMII_TX_EN),
    .rmii_mdc(WB_RMII_MDC),
    .rmii_mdio(WB_RMII_MDIO),
    .rmii_rst_n(WB_RMII_RST_N),
    .eth_irq(WBEthIntr)
    );

  end else begin
    assign {HREADWbIsland, HRESPWbIsland, HREADYWbIsland} = '0;
    assign {WB_RMII_TX_DATA, WB_RMII_TX_EN, WB_RMII_MDC, WB_RMII_RST_N} = '0;
    assign WBUartIntr = 1'b0; assign WBEthIntr = 1'b0;
  end

  // AXI Select signals
  assign HSELEXTD_ALL = HSELEXTD_DDR | HSELAXIDMAD | HSELAXIVGAD | HSELAXIUSBD | HSELAXIETHD | HSELAXILITEDRAMD | HSELAXIDUMMYD | HSELAXISDHCID | HSELAXIIDMAD | HSELAXIIDMAREG64D;
  assign HSELEXT = HSELEXT_DDR | HSELAXIDMA | HSELAXIVGA | HSELAXIUSB | HSELAXIETH | HSELAXILITEDRAM | HSELAXIDUMMY | HSELAXISDHCI | HSELAXIIDMA | HSELAXIIDMAREG64; // OUTPUT

  // AHB Read Multiplexer
  assign HRDATA = ({P.AHBW{HSELRamD}} & HREADRam) |
                  ({P.AHBW{HSELWbIslandD}} & HREADWbIsland) |
                  ({P.AHBW{HSELEXTD_ALL}} & HRDATAEXT) |
                  ({P.AHBW{HSELBRIDGED}} & HREADBRIDGE) |
                  ({P.AHBW{HSELBootRomD}} & HREADBootRom);

  assign HRESP = HSELRamD & HRESPRam |
                 HSELWbIslandD & HRESPWbIsland |
                 HSELEXTD_ALL & HRESPEXT |
                 HSELBRIDGED & HRESPBRIDGE |
                 HSELBootRomD & HRESPBootRom;

  assign HREADY = HSELRamD & HREADYRam |
                  HSELWbIslandD & HREADYWbIsland |
                  HSELEXTD_ALL & HREADYEXT |
                  HSELBRIDGED & HREADYBRIDGE |
                  HSELBootRomD & HREADYBootRom |
                  HSELNoneD; // don't lock up the bus if no region is being accessed

  // Address Decoder Delay (figure 4-2 in spec)
  // The select for HREADY needs to be based on the address phase address.  If the device
  // takes more than 1 cycle to respond it needs to hold on to the old select until the
  // device is ready.  Hence this register must be selectively enabled by HREADY.
  // However on reset None must be selected.
  flopenl #(22) hseldelayreg(HCLK, ~HRESETn, HREADY, HSELRegions, 22'b1,
    {HSELAXIIDMAREG64D, HSELAXIIDMAD, HSELAXISDHCID, HSELAXIDUMMYD, HSELAXILITEDRAMD, HSELAXIETHD, HSELAXIUSBD, HSELAXIVGAD, HSELAXIDMAD, HSELWbIslandD, HSELSPID, HSELSDCD, HSELPLICD, HSELUARTD, HSELGPIOD, HSELCLINTD,
      HSELRamD, HSELBootRomD, HSELEXTD_DDR, HSELIROMD, HSELDTIMD, HSELNoneD});
  flopenr #(1) hselbridgedelayreg(HCLK, ~HRESETn, HREADY, HSELBRIDGE, HSELBRIDGED);
endmodule
