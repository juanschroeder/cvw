dst := IP

all: ArtyA7

.PHONY: ArtyA7 vcu118 vcu108 genesys2 nexysa7

ArtyA7: export XILINX_PART := xc7a100tcsg324-1
ArtyA7: export XILINX_BOARD := digilentinc.com:arty-a7-100:part0:1.1
ArtyA7: export board := ArtyA7
ArtyA7: export SYSTEMCLOCK := 20000000
ArtyA7: export MAXSDCCLOCK  :=  5000000
ArtyA7: FPGA_Arty

vcu118: export XILINX_PART := xcvu9p-flga2104-2L-e
vcu118: export XILINX_BOARD := xilinx.com:vcu118:part0:2.4
vcu118: export board := vcu118
vcu118: export SYSTEMCLOCK := 71000000
vcu118: export MAXSDCCLOCK  :=  1000000
vcu118: FPGA_VCU

vcu108: export XILINX_PART := xcvu095-ffva2104-2-e
vcu108: export XILINX_BOARD := xilinx.com:vcu108:part0:1.7
vcu108: export board := vcu108
vcu108: export SYSTEMCLOCK := 50000000
vcu108: export MAXSDCCLOCK  := 12500000
vcu108: FPGA_VCU

genesys2: export XILINX_PART := xc7k325tffg900-2
genesys2: export XILINX_BOARD := digilentinc.com:genesys2:part0:1.1
genesys2: export board := genesys2
genesys2: export SYSTEMCLOCK := 40000000
genesys2: export MAXSDCCLOCK  := 10000000
genesys2: FPGA_GENESYS2

nexysa7: export XILINX_PART := xc7a100tcsg324-1
nexysa7: export XILINX_BOARD := digilentinc.com:nexys-a7-100t:part0:1.0
nexysa7: export board := nexysa7
nexysa7: export SYSTEMCLOCK := 20000000
nexysa7: export MAXSDCCLOCK  :=  10000000
nexysa7: FPGA_NEXYSA7

boardconfig = $(board)
litedramconfig = genesys2soc

nexysa7soc: export XILINX_PART := xc7a100tcsg324-1
nexysa7soc: export XILINX_BOARD := digilentinc.com:nexys-a7-100t:part0:1.0
nexysa7soc: export board := nexysa7soc
nexysa7soc: export SYSTEMCLOCK := 20000000
nexysa7soc: export MAXSDCCLOCK  :=  10000000
nexysa7soc: export MIG_ADDR_WIDTH  :=  27
nexysa7soc: FPGA_NEXYSA7SOC

genesys2soc: export XILINX_PART := xc7k325tffg900-2
genesys2soc: export XILINX_BOARD := digilentinc.com:genesys2:part0:1.1
genesys2soc: export board := genesys2soc
genesys2soc: export SYSTEMCLOCK := 40000000
genesys2soc: export MAXSDCCLOCK  := 5000000
genesys2soc: export MIG_ADDR_WIDTH  :=  30
genesys2soc: export MEM_WIDTH  :=  64
genesys2soc: FPGA_GENESYS2SOC

genesys2socxlnx: export XILINX_PART := xc7k325tffg900-2
genesys2socxlnx: export XILINX_BOARD := digilentinc.com:genesys2:part0:1.1
genesys2socxlnx: export board := genesys2socxlnx
genesys2socxlnx: export SYSTEMCLOCK := 40000000
genesys2socxlnx: export MAXSDCCLOCK  := 5000000
genesys2socxlnx: export MIG_ADDR_WIDTH  :=  30
genesys2socxlnx: FPGA_GENESYS2SOCXLNX

genesys2rv32soc: export XILINX_PART := xc7k325tffg900-2
genesys2rv32soc: export XILINX_BOARD := digilentinc.com:genesys2:part0:1.1
genesys2rv32soc: export board := genesys2rv32soc
genesys2rv32soc: export SYSTEMCLOCK := 55000000
genesys2rv32soc: export MAXSDCCLOCK  := 5000000
genesys2rv32soc: export MIG_ADDR_WIDTH  :=  30
genesys2rv32soc: export MEM_WIDTH  :=  32
genesys2rv32soc: export litedramconfig := genesys2w32soc
genesys2rv32soc: FPGA_GENESYS2RV32SOC

# same build as rv32soc but different config (no changes beyond this)
genesys2rv32minsoc: export XILINX_PART := xc7k325tffg900-2
genesys2rv32minsoc: export XILINX_BOARD := digilentinc.com:genesys2:part0:1.1
genesys2rv32minsoc: export board := genesys2rv32soc
genesys2rv32minsoc: export boardconfig := genesys2rv32minsoc
genesys2rv32minsoc: export SYSTEMCLOCK := 55000000
genesys2rv32minsoc: export MAXSDCCLOCK  := 5000000
genesys2rv32minsoc: export MIG_ADDR_WIDTH  :=  30
genesys2rv32minsoc: export MEM_WIDTH  :=  32
genesys2rv32minsoc: export litedramconfig := genesys2w32soc
genesys2rv32minsoc: FPGA_GENESYS2RV32SOC

# same FPGA build as rv32 with different config
genesys2rv32w64soc: export XILINX_PART := xc7k325tffg900-2
genesys2rv32w64soc: export XILINX_BOARD := digilentinc.com:genesys2:part0:1.1
genesys2rv32w64soc: export board := genesys2rv32w64soc
genesys2rv32w64soc: export SYSTEMCLOCK := 55000000
genesys2rv32w64soc: export MAXSDCCLOCK  := 5000000
genesys2rv32w64soc: export MIG_ADDR_WIDTH  :=  30
genesys2rv32w64soc: export MEM_WIDTH  :=  64
genesys2rv32w64soc: FPGA_GENESYS2RV32SOC


CONFIG_VH = ../../config/deriv/fpga$(boardconfig)/config.vh

# variables computed from config
EXT_MEM_BASE = $(shell grep 'EXT_MEM_BASE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')
EXT_MEM_RANGE = $(shell grep 'EXT_MEM_RANGE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/\1/g' | sed 's/\(.*\)/base=16;\1+1/g' | bc | sed 's/\(.*\)/0x\1/g')
_LITEDRAM_SUPPORTED = $(shell grep 'LITEDRAM_SUPPORTED' $(CONFIG_VH) | sed -n 's/.*=[[:space:]]*\([[:alnum:]_]*\);/\1/p')
_SDHCI_SUPPORTED = $(shell grep 'AXI_SDHCI_SUPPORTED' $(CONFIG_VH) | sed -n 's/.*=[[:space:]]*\([[:alnum:]_]*\);/\1/p')
LITEDRAM_BASE = $(shell grep 'LITEDRAM_BASE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')
SDHCI_BASE = $(shell grep 'AXI_SDHCI_BASE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')
BOOTROM_BASE = $(shell grep 'BOOTROM_BASE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')
UNCORE_RAM_BASE = $(shell grep 'UNCORE_RAM_BASE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')
UNCORE_RAM_RANGE = $(shell grep 'UNCORE_RAM_RANGE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/\1/g' | sed 's/\(.*\)/base=16;\1+1/g' | bc | sed 's/\(.*\)/0x\1/g')
_UBERDDR3_SUPPORTED = $(shell grep 'UBERDDR3_SUPPORTED' $(CONFIG_VH) | sed -n 's/.*=[[:space:]]*\([[:alnum:]_]*\);/\1/p')
genesys2soc: export LITEDRAM_SUPPORTED = $(_LITEDRAM_SUPPORTED)
genesys2soc: export SDHCI_SUPPORTED = $(_SDHCI_SUPPORTED)
genesys2soc: export UBERDDR3_SUPPORTED = $(_UBERDDR3_SUPPORTED)
genesys2rv32soc: export LITEDRAM_SUPPORTED = $(_LITEDRAM_SUPPORTED)
genesys2rv32soc: export SDHCI_SUPPORTED = $(_SDHCI_SUPPORTED)
genesys2rv32soc: export UBERDDR3_SUPPORTED = $(_UBERDDR3_SUPPORTED)
genesys2rv32w64soc: export LITEDRAM_SUPPORTED = $(_LITEDRAM_SUPPORTED)
genesys2rv32w64soc: export SDHCI_SUPPORTED = $(_SDHCI_SUPPORTED)
genesys2rv32w64soc: export UBERDDR3_SUPPORTED = $(_UBERDDR3_SUPPORTED)
genesys2rv32minsoc: export LITEDRAM_SUPPORTED = $(_LITEDRAM_SUPPORTED)
genesys2rv32minsoc: export SDHCI_SUPPORTED = $(_SDHCI_SUPPORTED)
genesys2rv32minsoc: export UBERDDR3_SUPPORTED = $(_UBERDDR3_SUPPORTED)

.PHONY: FPGA_Arty FPGA_VCU
FPGA_Arty: PreProcessFiles IP_Arty zsbl
	vivado -mode tcl -source wally.tcl 2>&1 | tee wally.log
FPGA_VCU: PreProcessFiles IP_VCU zsbl
	vivado -mode tcl -source wally.tcl 2>&1 | tee wally.log

FPGA_GENESYS2: PreProcessFiles IP_GENESYS2 zsbl
	vivado -mode tcl -source wally.tcl 2>&1 | tee wally.log

FPGA_NEXYSA7: PreProcessFiles IP_NEXYSA7 zsbl
	vivado -mode tcl -source wally.tcl 2>&1 | tee wally.log

VIVADO_COLOR := awk '\
  /^ERROR:/            {print "\033[31;1m" $$0 "\033[0m"; next} \
  /^CRITICAL WARNING:/ {print "\033[31m"   $$0 "\033[0m"; next} \
  /^WARNING:/          {print "\033[33m"   $$0 "\033[0m"; next} \
  /^INFO:/             {print "\033[32m"   $$0 "\033[0m"; next} \
  {print $$0} \
'
define VIVADO_TCL
script -q -c "vivado -mode tcl -source $(1)" /dev/null 2>&1 | tee $(2) | $(VIVADO_COLOR)
endef

FPGA_NEXYSA7SOC: PreProcessFilesSoC IP_NEXYSA7SOC zsbl
	@$(call VIVADO_TCL,wally.tcl,wally.log)

FPGA_GENESYS2SOC: PreProcessFilesSoC IP_GENESYS2SOC liblitedram zsblsoc
	@$(call VIVADO_TCL,wally.tcl,wally.log)

FPGA_GENESYS2SOCXLNX: PreProcessFilesSoC IP_GENESYS2SOCXLNX zsbl
	@$(call VIVADO_TCL,wally.tcl,wally.log)

FPGA_GENESYS2RV32SOC: PreProcessFilesSoC IP_GENESYS2RV32SOC liblitedram32 zsbl32soc
	@$(call VIVADO_TCL,wally.tcl,wally.log)

# Generate IP Blocks
.PHONY: IP_Arty IP_VCU
IP_VCU: $(dst)/sysrst.log \
	MEM_VCU \
	$(dst)/clkconverter.log \
	$(dst)/ahbaxibridge.log
IP_Arty: $(dst)/sysrst.log \
	MEM_Arty \
	$(dst)/mmcm.log \
	$(dst)/clkconverter.log \
	$(dst)/ahbaxibridge.log

IP_GENESYS2: $(dst)/sysrst.log \
	MEM_GENESYS2 \
	$(dst)/mmcm-genesys2.log \
	$(dst)/clkconverter.log \
	$(dst)/ahbaxibridge.log

IP_NEXYSA7: $(dst)/sysrst.log \
	MEM_NEXYSA7 \
	$(dst)/mmcm-nexysa7.log \
	$(dst)/clkconverter.log \
	$(dst)/ahbaxibridge.log

IP_NEXYSA7SOC: $(dst)/sysrst.log \
	MEM_NEXYSA7 \
	$(dst)/mmcm-nexysa7.log \
	$(dst)/clkconverter.log \
	$(dst)/ahbaxibridge.log \
	$(dst)/axicrossbar.log \
	$(dst)/axicdma.log

IP_GENESYS2SOC: $(dst)/sysrst.log \
	MEM_GENESYS2 \
	$(dst)/mmcm-genesys2soc.log \
	$(dst)/axicdma.log

IP_GENESYS2SOCXLNX: $(dst)/sysrst.log \
	MEM_GENESYS2SOCXLNX \
	$(dst)/mmcm-genesys2soc.log \
	$(dst)/ahbaxibridge.log \
	$(dst)/axicdma.log \
	$(dst)/axicrossbar.log  \
	$(dst)/clkconverter.log

IP_GENESYS2RV32SOC: $(dst)/sysrst.log \
	$(dst)/mmcm-genesys2soc.log \
	$(dst)/axicdma.log

# Generate Memory IP Blocks
.PHONY: MEM_VCU MEM_Arty
MEM_VCU:
	$(MAKE) $(dst)/ddr4-$(board).log
MEM_Arty:
	$(MAKE) $(dst)/ddr3-$(board).log

MEM_GENESYS2:
	$(MAKE) $(dst)/ddr3-$(board).log

MEM_GENESYS2SOCXLNX:
	$(MAKE) $(dst)/ddr3-genesys2soc.log

# MEM_GENESYS2RV32SOC: No MIG IP for RV32
# MEM_GENESYS2RV32SOC:
# 	$(MAKE) $(dst)/ddr3-genesys2soc.log

MEM_NEXYSA7:
	$(MAKE) $(dst)/ddr2-$(board).log

# MEM_NEXYSA7SOC:
# 	$(MAKE) $(dst)/ddr2-$(board).log

# Copy files and make necessary modifications
.PHONY: PreProcessFiles
PreProcessFiles:
	$(MAKE) -C ../../sim deriv
	rm -rf ../src/CopiedFiles_do_not_add_to_repo/
	cp -r ../../src/ ../src/CopiedFiles_do_not_add_to_repo/
	cp -r ../../addins/verilog-ethernet/*/*.sv ../src/CopiedFiles_do_not_add_to_repo/rvvi
	cp -r ../../addins/verilog-ethernet/*/*/*/*.sv ../src/CopiedFiles_do_not_add_to_repo/rvvi
	mkdir ../src/CopiedFiles_do_not_add_to_repo/config/
	cp ../../config/deriv/fpga$(board)/config.vh ../src/CopiedFiles_do_not_add_to_repo/config/
	./insert_debug_comment.sh
	# This line allows the Bootloader to be loaded in a Block RAM on the FPGA
	sed -i "s/bit \[DATA_WIDTH-1:0\].*ROM.*/(\* rom_style=\"block\" \*) &/g" ../src/CopiedFiles_do_not_add_to_repo/generic/mem/rom1p1r.sv
	sed -i 's/$$WALLY/\.\.\/\.\.\//g' ../src/CopiedFiles_do_not_add_to_repo/generic/mem/rom1p1r.sv
	sed -i 's/$$WALLY/\.\.\/\.\.\//g' ../src/CopiedFiles_do_not_add_to_repo/generic/mem/ram1p1rwbe.sv


PULP_DIR := ../src/CopiedFiles_do_not_add_to_repo/pulp
PULP_LZC := $(PULP_DIR)/common_cells/src/lzc.sv
.PHONY: PreProcessFilesSoC
PreProcessFilesSoC: PreProcessFiles
	cp ../../config/deriv/fpga$(boardconfig)/config.vh ../src/CopiedFiles_do_not_add_to_repo/config/config.vh
	# Copy Wishbone stuff
	# ahb3lite_wb_bridge
	mkdir ../src/CopiedFiles_do_not_add_to_repo/ahb3lite_wb_bridge
	cp -r ../../addins/ahb3lite_wb_bridge/*.v ../src/CopiedFiles_do_not_add_to_repo/ahb3lite_wb_bridge/
	# missing Opencores UART stuff here
	mkdir -p ../src/CopiedFiles_do_not_add_to_repo/oc_uart_16550/
	cp -r ../../addins/oc_uart_16550/rtl/verilog/*.v ../src/CopiedFiles_do_not_add_to_repo/oc_uart_16550/
	# Copy verilog-axi stuff
	cp -r ../../addins/verilog-axi  ../src/CopiedFiles_do_not_add_to_repo/
	# Copy Pulp project stuff
	cp -r ../../addins/pulp/ ../src/CopiedFiles_do_not_add_to_repo/
	# Copy cvwsoc stuff
	cp -r ../../addins/cvwsoc/  ../src/CopiedFiles_do_not_add_to_repo
	# Apply patches
	# modify PULP files to prevent name collision for 'lzc'
	# 1) rename the module itself (only in the defining file)
	sed -i -E 's/^([[:space:]]*module[[:space:]]+)lzc([[:space:]]*#)/\1lzc_pulp\2/' $(PULP_LZC)
	sed -i -E 's/^([[:space:]]*module[[:space:]]+)lzc([[:space:]]*\()/\1lzc_pulp\2/' $(PULP_LZC)
	sed -i -E 's/(endmodule[[:space:]]*:[[:space:]]*)lzc\b/\1lzc_pulp/' $(PULP_LZC)
	# 2) rename instantiations that look like: lzc #( ... )
	find $(PULP_DIR) -type f \( -name "*.sv" -o -name "*.svh" -o -name "*.v" \) -print0 | \
	  xargs -0 sed -i -E 's/\<lzc\>([[:space:]]*#[[:space:]]*\()/lzc_pulp\1/g'
	# 3) patch AXI
	patch -d "$(PULP_DIR)/axi" -p1 -N --forward < "$(PULP_DIR)/0001-axi-burst-splitter-max-burst-beats.patch"
	# 4) patch AXI VGA
	patchdir="$(PULP_DIR)/axi-vga"; \
	find "$(PULP_DIR)" -type f -name "*vga*.patch" -print0 | sort -z | \
	  xargs -0 -r -I{} sh -c 'echo "Applying {} -> '"$$patchdir"'"; patch -d "'"$$patchdir"'" -p1 -N --forward < "{}"'
	# 5) patch USB OHCI
	patchdir="../src/CopiedFiles_do_not_add_to_repo"; \
	find ../../addins/cvwsoc/usb -type f -name "*.patch" -print0 | sort -z | \
	  xargs -0 -r -I{} sh -c 'echo "Applying {} -> '"$$patchdir"'"; patch -d "'"$$patchdir"'" -p1 -N --forward < "{}"'
	# copy AHB-AXI4 bridge from VeeR EL2
	#mkdir -p ../src/CopiedFiles_do_not_add_to_repo/ahb_to_axi4/
	#cp ../../addins/veer-el2/design/lib/ahb_to_axi4.sv ../src/CopiedFiles_do_not_add_to_repo/ahb_to_axi4/
	#cp ../../addins/veer-el2/design/lib/beh_lib.sv ../src/CopiedFiles_do_not_add_to_repo/ahb_to_axi4/
	# copy AHB-Lite-to-AXI4 bridge (only what's needed)
	mkdir -p ../src/CopiedFiles_do_not_add_to_repo/ahb-to-axi/rtl
	cp -r ../../addins/ahb-to-axi/rtl/* ../src/CopiedFiles_do_not_add_to_repo/ahb-to-axi/rtl
	# copy Wb2axi
	cp -r ../../addins/wb2axip ../src/CopiedFiles_do_not_add_to_repo/
	# copy uberddr3
	cp -r ../../addins/uberddr3 ../src/CopiedFiles_do_not_add_to_repo/
	# copy sdhci
	cp -r ../../addins/sdhci ../src/CopiedFiles_do_not_add_to_repo/
	patch -d ../src/CopiedFiles_do_not_add_to_repo/sdhci -p1 -N --forward < ../../addins/cvwsoc/sdhci/zsbl_cheshire_stub.patch

	# LITTLE_ENDIAN for UART core
	grep -q 'define LITLE_ENDIAN' ../src/CopiedFiles_do_not_add_to_repo/oc_uart_16550/uart_defines.v || sed -i '1i`define LITLE_ENDIAN' ../src/CopiedFiles_do_not_add_to_repo/oc_uart_16550/uart_defines.v

# build the Zero stage boot loader (ZSBL)
.PHONY: zsbl
zsbl:
	$(MAKE) -C ../zsbl clean
	SYSTEMCLOCK=$(SYSTEMCLOCK) EXT_MEM_BASE=$(EXT_MEM_BASE) EXT_MEM_RANGE=$(EXT_MEM_RANGE) \
		BOOTROM_BASE=$(BOOTROM_BASE) UNCORE_RAM_BASE=$(UNCORE_RAM_BASE) $(MAKE) -C ../zsbl

export LIBLITEDRAM_SRC_DIR =  $(PWD)/../../addins/litex/litex/soc/software/liblitedram
LITEDRAM_INC_DIRS = "$(PWD)/../../addins/cvwsoc/litedram/$(litedramconfig)/include \
					$(PWD)/../../addins/cvwsoc/litedram/$(litedramconfig)          \
					$(PWD)/../../addins/cvwsoc/litedram                   \
					$(LIBLITEDRAM_DIRECTORY)/../include                   \
					$(LIBLITEDRAM_DIRECTORY)/.. $(LIBLITEDRAM_SRC_DIR)"
LIBS = "-L$(PWD)/../../addins/cvwsoc/litedram -llitedram"
SDHCI_SRC_DIR = ../src/CopiedFiles_do_not_add_to_repo/sdhci/sw
# build the Zero stage boot loader (ZSBL)
.PHONY: zsblsoc zsbl32soc liblitedram liblitedram32
zsblsoc:
	$(MAKE) -C ../zsbl clean
	SYSTEMCLOCK=$(SYSTEMCLOCK) EXT_MEM_BASE=$(EXT_MEM_BASE) EXT_MEM_RANGE=$(EXT_MEM_RANGE) \
		LITEDRAM_SUPPORTED=$(LITEDRAM_SUPPORTED) LITEDRAM_BASE=$(LITEDRAM_BASE)            \
		SDHCI_SUPPORTED=$(SDHCI_SUPPORTED) SDHCI_BASE=$(SDHCI_BASE)                       \
		SDHCI_SRC_DIR=$(SDHCI_SRC_DIR)                                                    \
		BOOTROM_BASE=$(BOOTROM_BASE) UNCORE_RAM_BASE=$(UNCORE_RAM_BASE) UNCORE_RAM_RANGE=$(UNCORE_RAM_RANGE) \
		LIBS=$(LIBS) INC_DIRS=$(LITEDRAM_INC_DIRS) $(MAKE) -C ../zsbl

ZSBL32SOC_CC      ?= riscv64-unknown-elf-gcc
ZSBL32SOC_AS      ?= riscv64-unknown-elf-as
ZSBL32SOC_AR      ?= riscv64-unknown-elf-ar
ZSBL32SOC_MARCH   ?= -march=rv32imac_zicsr_zifencei
ZSBL32SOC_MABI    ?= -mabi=ilp32
ZSBL32SOC_LIBDIR  ?= $(RISCV)/riscv64-unknown-elf/lib/rv32imac/ilp32
ZSBL32SOC_SYSROOT ?= $(RISCV)/riscv64-unknown-elf
ZSBL32SOC_MEM_WIDTH ?= $(MEM_WIDTH)
# 32-bit CPU build
zsbl32soc:
	$(MAKE) -C ../zsbl clean
	sed 's/elf64-littleriscv/elf32-littleriscv/g' ../zsbl/linker1000.x > ../zsbl/linker1000_32.x
	$(MAKE) -C ../zsbl                                                                 \
		SYSTEMCLOCK=$(SYSTEMCLOCK) EXT_MEM_BASE=$(EXT_MEM_BASE) EXT_MEM_RANGE=$(EXT_MEM_RANGE) \
		LITEDRAM_SUPPORTED=$(LITEDRAM_SUPPORTED) LITEDRAM_BASE=$(LITEDRAM_BASE)          \
		SDHCI_SUPPORTED=$(SDHCI_SUPPORTED) SDHCI_BASE=$(SDHCI_BASE)                     \
		SDHCI_SRC_DIR=$(SDHCI_SRC_DIR)                                                  \
		BOOTROM_BASE=$(BOOTROM_BASE) UNCORE_RAM_BASE=$(UNCORE_RAM_BASE) UNCORE_RAM_RANGE=$(UNCORE_RAM_RANGE) \
		LIBS=$(LIBS) INC_DIRS=$(LITEDRAM_INC_DIRS)                                       \
		CC=$(ZSBL32SOC_CC) AS=$(ZSBL32SOC_AS) AR=$(ZSBL32SOC_AR)                         \
		MARCH=$(ZSBL32SOC_MARCH) MABI=$(ZSBL32SOC_MABI) MEM_WIDTH=$(ZSBL32SOC_MEM_WIDTH) \
		LINKER=linker1000_32.x                                                           \
		LINK_FLAGS="$(ZSBL32SOC_MARCH) $(ZSBL32SOC_MABI) -nostartfiles -L $(ZSBL32SOC_LIBDIR) -L $(ZSBL32SOC_SYSROOT)/lib"

LIBLITEDRAM_DIRECTORY = $(LIBLITEDRAM_SRC_DIR)
liblitedram:
	$(MAKE) -C ../../addins/cvwsoc/litedram -f liblitedram.mk clean
	$(MAKE) -C ../../addins/cvwsoc/litedram -f liblitedram.mk EXT_MEM_BASE=$(EXT_MEM_BASE) LITEDRAM_BASE=$(LITEDRAM_BASE) \
		LIBLITEDRAM_DIRECTORY=$(LIBLITEDRAM_DIRECTORY) LITEDRAM_CONFIG=$(litedramconfig)


liblitedram32:
	$(MAKE) -C ../../addins/cvwsoc/litedram -f liblitedram.mk clean
	$(MAKE) -C ../../addins/cvwsoc/litedram -f liblitedram.mk EXT_MEM_BASE=$(EXT_MEM_BASE) LITEDRAM_BASE=$(LITEDRAM_BASE) \
		LIBLITEDRAM_DIRECTORY=$(LIBLITEDRAM_DIRECTORY) LITEDRAM_CONFIG=$(litedramconfig) \
		MARCH=$(ZSBL32SOC_MARCH) MABI=$(ZSBL32SOC_MABI)

# Generate Individual IP Blocks
$(dst)/%.log: %.tcl
	mkdir -p IP
	cd IP;\
	vivado -mode batch -source ../$*.tcl | tee $*.log

# Clean
.PHONY: cleanIP cleanLogs cleanFPGA cleanAll
cleanIP:
	rm -rf IP
cleanLogs:
	rm -rf  *.jou *.log
cleanFPGA:
	rm -rf WallyFPGA.* reports sim .Xil
cleanAll: cleanIP cleanLogs cleanFPGA

# Aliases
.PHONY: arty artya7 VCU118 VCU108 nexys nexysa7
arty artya7: ArtyA7
VCU118: vcu118
VCU108: vcu108
