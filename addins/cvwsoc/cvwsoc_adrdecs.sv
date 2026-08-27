// Address decoder for the AHB island.
module cvwsoc_adrdecs import cvw::*; #(parameter cvw_t P) (
  input logic [P.PA_BITS-1:0] PhysicalAddress,
  input logic AccessRW, AccessRX, AccessRWXC,
  input logic [1:0] Size,
  output logic [7:0] SelRegions
);

  localparam logic [3:0] SUPPORTED_SIZE = 4'b1111;
  adrdec #(P.PA_BITS) bootrom(PhysicalAddress, P.BOOTROM_BASE[P.PA_BITS-1:0], P.BOOTROM_RANGE[P.PA_BITS-1:0], P.BOOTROM_SUPPORTED, AccessRX, Size, SUPPORTED_SIZE, SelRegions[0]);
  adrdec #(P.PA_BITS) ram(PhysicalAddress, P.UNCORE_RAM_BASE[P.PA_BITS-1:0], P.UNCORE_RAM_RANGE[P.PA_BITS-1:0], P.UNCORE_RAM_SUPPORTED, AccessRWXC, Size, SUPPORTED_SIZE, SelRegions[1]);
  adrdec #(P.PA_BITS) gpio(PhysicalAddress, P.GPIO_BASE[P.PA_BITS-1:0], P.GPIO_RANGE[P.PA_BITS-1:0], P.GPIO_SUPPORTED, AccessRW, Size, 4'b0100, SelRegions[2]);
  adrdec #(P.PA_BITS) uart(PhysicalAddress, P.UART_BASE[P.PA_BITS-1:0], P.UART_RANGE[P.PA_BITS-1:0], P.UART_SUPPORTED, AccessRW, Size, 4'b0001, SelRegions[3]);
  adrdec #(P.PA_BITS) plic(PhysicalAddress, P.PLIC_BASE[P.PA_BITS-1:0], P.PLIC_RANGE[P.PA_BITS-1:0], P.PLIC_SUPPORTED, AccessRW, Size, 4'b0100, SelRegions[4]);
  adrdec #(P.PA_BITS) sdc(PhysicalAddress, P.SDC_BASE[P.PA_BITS-1:0], P.SDC_RANGE[P.PA_BITS-1:0], P.SDC_SUPPORTED, AccessRW, Size, SUPPORTED_SIZE & 4'b1100, SelRegions[5]);
  adrdec #(P.PA_BITS) spi(PhysicalAddress, P.SPI_BASE[P.PA_BITS-1:0], P.SPI_RANGE[P.PA_BITS-1:0], P.SPI_SUPPORTED, AccessRW, Size, 4'b0100, SelRegions[6]);
  assign SelRegions[7] = ~|SelRegions[6:0];
endmodule
