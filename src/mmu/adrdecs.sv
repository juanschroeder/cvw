///////////////////////////////////////////
// adrdecs.sv
//
// Written: David_Harris@hmc.edu 22 June 2021
// Modified:
//
// Purpose: All the address decoders for peripherals
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

  // verilator lint_off UNOPTFLAT

module adrdecs import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.PA_BITS-1:0] PhysicalAddress,
  input  logic                 AccessRW, AccessRX, AccessRWXC,
  input  logic [1:0]           Size,
  output logic [21:0]          SelRegions
);

  localparam logic [3:0]       SUPPORTED_SIZE = (P.LLEN == 32 ? 4'b0111 : 4'b1111);
 // Determine which region of physical memory (if any) is being accessed
  adrdec #(P.PA_BITS) dtimdec(PhysicalAddress, P.DTIM_BASE[P.PA_BITS-1:0], P.DTIM_RANGE[P.PA_BITS-1:0], P.DTIM_SUPPORTED, AccessRW, Size, SUPPORTED_SIZE, SelRegions[1]);
  adrdec #(P.PA_BITS) iromdec(PhysicalAddress, P.IROM_BASE[P.PA_BITS-1:0], P.IROM_RANGE[P.PA_BITS-1:0], P.IROM_SUPPORTED, AccessRX, Size, SUPPORTED_SIZE, SelRegions[2]);
  adrdec #(P.PA_BITS) ddr4dec(PhysicalAddress, P.EXT_MEM_BASE[P.PA_BITS-1:0], P.EXT_MEM_RANGE[P.PA_BITS-1:0], P.EXT_MEM_SUPPORTED, AccessRWXC, Size, SUPPORTED_SIZE, SelRegions[3]);
  adrdec #(P.PA_BITS) bootromdec(PhysicalAddress, P.BOOTROM_BASE[P.PA_BITS-1:0], P.BOOTROM_RANGE[P.PA_BITS-1:0], P.BOOTROM_SUPPORTED, AccessRX, Size, SUPPORTED_SIZE, SelRegions[4]);
  adrdec #(P.PA_BITS) uncoreramdec(PhysicalAddress, P.UNCORE_RAM_BASE[P.PA_BITS-1:0], P.UNCORE_RAM_RANGE[P.PA_BITS-1:0], P.UNCORE_RAM_SUPPORTED, AccessRWXC, Size, SUPPORTED_SIZE, SelRegions[5]);
  adrdec #(P.PA_BITS) clintdec(PhysicalAddress, P.CLINT_BASE[P.PA_BITS-1:0], P.CLINT_RANGE[P.PA_BITS-1:0], P.CLINT_SUPPORTED, AccessRW, Size, SUPPORTED_SIZE, SelRegions[6]);
  adrdec #(P.PA_BITS) gpiodec(PhysicalAddress, P.GPIO_BASE[P.PA_BITS-1:0], P.GPIO_RANGE[P.PA_BITS-1:0], P.GPIO_SUPPORTED, AccessRW, Size, 4'b0100, SelRegions[7]);
  adrdec #(P.PA_BITS) uartdec(PhysicalAddress, P.UART_BASE[P.PA_BITS-1:0], P.UART_RANGE[P.PA_BITS-1:0], P.UART_SUPPORTED, AccessRW, Size, 4'b0001, SelRegions[8]);
  adrdec #(P.PA_BITS) plicdec(PhysicalAddress, P.PLIC_BASE[P.PA_BITS-1:0], P.PLIC_RANGE[P.PA_BITS-1:0], P.PLIC_SUPPORTED, AccessRW, Size, 4'b0100, SelRegions[9]);
  adrdec #(P.PA_BITS) sdcdec(PhysicalAddress, P.SDC_BASE[P.PA_BITS-1:0], P.SDC_RANGE[P.PA_BITS-1:0], P.SDC_SUPPORTED, AccessRW, Size, SUPPORTED_SIZE & 4'b1100, SelRegions[10]);
  adrdec #(P.PA_BITS) spidec(PhysicalAddress, P.SPI_BASE[P.PA_BITS-1:0], P.SPI_RANGE[P.PA_BITS-1:0], P.SPI_SUPPORTED, AccessRW, Size, 4'b0100, SelRegions[11]);
  adrdec #(P.PA_BITS) wbdec(PhysicalAddress, P.WISHBONE_BASE[P.PA_BITS-1:0], P.WISHBONE_RANGE[P.PA_BITS-1:0], P.WISHBONE_SUPPORTED, AccessRW, Size, 4'b0111, SelRegions[12]);
  adrdec #(P.PA_BITS) axicdmadec(PhysicalAddress, P.XILINX_AXI_DMA_BASE[P.PA_BITS-1:0], P.XILINX_AXI_DMA_RANGE[P.PA_BITS-1:0], P.XILINX_AXI_DMA_SUPPORTED, AccessRW, Size, 4'b0111, SelRegions[13]);
  adrdec #(P.PA_BITS) axivgadec(PhysicalAddress, P.AXI_VGA_BASE[P.PA_BITS-1:0], P.AXI_VGA_RANGE[P.PA_BITS-1:0], P.AXI_VGA_SUPPORTED, AccessRW, Size, 4'b0111, SelRegions[14]);
  adrdec #(P.PA_BITS) axiusbdec(PhysicalAddress, P.AXI_USB_BASE[P.PA_BITS-1:0], P.AXI_USB_RANGE[P.PA_BITS-1:0], P.AXI_USB_SUPPORTED, AccessRW, Size, 4'b0111, SelRegions[15]);
  adrdec #(P.PA_BITS) axiethdec(PhysicalAddress, P.AXI_ETH_BASE[P.PA_BITS-1:0], P.AXI_ETH_RANGE[P.PA_BITS-1:0], P.AXI_ETH_SUPPORTED, AccessRW, Size, 4'b0111, SelRegions[16]);
  adrdec #(P.PA_BITS) axilddec(PhysicalAddress, P.LITEDRAM_BASE[P.PA_BITS-1:0], P.LITEDRAM_RANGE[P.PA_BITS-1:0], P.LITEDRAM_SUPPORTED, AccessRW, Size, 4'b0111, SelRegions[17]);
  adrdec #(P.PA_BITS) axidummydec(PhysicalAddress, P.AXI_DUMMY_BASE[P.PA_BITS-1:0], P.AXI_DUMMY_RANGE[P.PA_BITS-1:0], P.AXI_DUMMY_SUPPORTED, AccessRW, Size, 4'b0111, SelRegions[18]);
  adrdec #(P.PA_BITS) axisdhcidec(PhysicalAddress, P.AXI_SDHCI_BASE[P.PA_BITS-1:0], P.AXI_SDHCI_RANGE[P.PA_BITS-1:0], P.AXI_SDHCI_SUPPORTED, AccessRW, Size, 4'b0111, SelRegions[19]);
  adrdec #(P.PA_BITS) axiidmadec(PhysicalAddress, P.AXI_IDMA_BASE[P.PA_BITS-1:0], P.AXI_IDMA_RANGE[P.PA_BITS-1:0], P.AXI_IDMA_SUPPORTED, AccessRW, Size, 4'b1111, SelRegions[20]);
  adrdec #(P.PA_BITS) axiidmareg64dec(PhysicalAddress, P.AXI_IDMA_REG64_BASE[P.PA_BITS-1:0], P.AXI_IDMA_REG64_RANGE[P.PA_BITS-1:0], P.AXI_IDMA_REG64_SUPPORTED, AccessRW, Size, 4'b0111, SelRegions[21]);

  assign SelRegions[0] = ~|(SelRegions[21:1]); // none of the regions are selected
endmodule

  // verilator lint_on UNOPTFLAT
