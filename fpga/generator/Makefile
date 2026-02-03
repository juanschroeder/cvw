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

# variables computed from config
EXT_MEM_BASE = $(shell grep 'EXT_MEM_BASE' ../../config/deriv/fpga$(board)/config.vh | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')

EXT_MEM_RANGE = $(shell grep 'EXT_MEM_RANGE' ../../config/deriv/fpga$(board)/config.vh | sed 's/.*=.*h\([[:alnum:]]*\);/\1/g' | sed 's/\(.*\)/base=16;\1+1/g' | bc | sed 's/\(.*\)/0x\1/g')


.PHONY: FPGA_Arty FPGA_VCU
FPGA_Arty: PreProcessFiles IP_Arty zsbl
	vivado -mode tcl -source wally.tcl 2>&1 | tee wally.log
FPGA_VCU: PreProcessFiles IP_VCU zsbl
	vivado -mode tcl -source wally.tcl 2>&1 | tee wally.log

FPGA_GENESYS2: PreProcessFiles IP_GENESYS2 zsbl
	vivado -mode tcl -source wally.tcl 2>&1 | tee wally.log

# FPGA_NEXYSA7: PreProcessFiles IP_NEXYSA7 zsbl
# 	vivado -mode tcl -source wally.tcl 2>&1 | tee wally.log

# adding colouring to Vivado output
# ANSI colors
CLR_RED    := \033[31;1m
CLR_RED2   := \033[31m
CLR_YELLOW := \033[33m
CLR_GREEN  := \033[32m
CLR_RESET  := \033[0m

# Vivado log colorizer (terminal only; keep logs clean by tee'ing before this)
VIVADO_COLOR_AWK := awk ' \
  /^ERROR:/            {print "$(CLR_RED)"$$0"$(CLR_RESET)"; next} \
  /^CRITICAL WARNING:/ {print "$(CLR_RED2)"$$0"$(CLR_RESET)"; next} \
  /^WARNING:/          {print "$(CLR_YELLOW)"$$0"$(CLR_RESET)"; next} \
  /^INFO:/             {print "$(CLR_GREEN)"$$0"$(CLR_RESET)"; next} \
  {print $$0} \
'

FPGA_NEXYSA7: PreProcessFiles IP_NEXYSA7 zsbl
	@vivado -mode tcl -source wally.tcl 2>&1 | tee wally.log | $(VIVADO_COLOR_AWK)

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
	$(dst)/ahbaxibridge.log \
	$(dst)/axicrossbar.log \
	$(dst)/axicdma.log

# Generate Memory IP Blocks
.PHONY: MEM_VCU MEM_Arty
MEM_VCU:
	$(MAKE) $(dst)/ddr4-$(board).log
MEM_Arty:
	$(MAKE) $(dst)/ddr3-$(board).log

MEM_GENESYS2:
	$(MAKE) $(dst)/ddr3-$(board).log

MEM_NEXYSA7:
	$(MAKE) $(dst)/ddr2-$(board).log


PULP_DIR := ../src/CopiedFiles_do_not_add_to_repo/pulp
PULP_LZC := $(PULP_DIR)/common_cells/src/lzc.sv
# Copy files and make necessary modifications
.PHONY: PreProcessFiles
PreProcessFiles:
	$(MAKE) -C ../../sim deriv
	rm -rf ../src/CopiedFiles_do_not_add_to_repo/
	cp -r ../../src/ ../src/CopiedFiles_do_not_add_to_repo/
	cp -r ../../addins/verilog-ethernet/*/*.sv ../src/CopiedFiles_do_not_add_to_repo/rvvi
	cp -r ../../addins/verilog-ethernet/*/*/*/*.sv ../src/CopiedFiles_do_not_add_to_repo/rvvi
	# Copy Wishbone stuff
	cp -r ../../addins/ahb3lite_wb_bridge/*.v ../src/CopiedFiles_do_not_add_to_repo/uncore
	# missing Opencores UART stuff here
	# Copy Pulp project stuff
	cp -r ../../addins/pulp/ ../src/CopiedFiles_do_not_add_to_repo/
	# modify PULP files to prevent name collision for 'lzc'
	# 1) rename the module itself (only in the defining file)
	sed -i -E 's/^([[:space:]]*module[[:space:]]+)lzc([[:space:]]*#)/\1lzc_pulp\2/' $(PULP_LZC)
	sed -i -E 's/^([[:space:]]*module[[:space:]]+)lzc([[:space:]]*\()/\1lzc_pulp\2/' $(PULP_LZC)
	sed -i -E 's/(endmodule[[:space:]]*:[[:space:]]*)lzc\b/\1lzc_pulp/' $(PULP_LZC)
	# 2) rename instantiations that look like: lzc #( ... )
	find $(PULP_DIR) -type f \( -name "*.sv" -o -name "*.svh" -o -name "*.v" \) -print0 | \
	  xargs -0 sed -i -E 's/\<lzc\>([[:space:]]*#[[:space:]]*\()/lzc_pulp\1/g'

	mkdir ../src/CopiedFiles_do_not_add_to_repo/config/
	cp ../../config/deriv/fpga$(board)/config.vh ../src/CopiedFiles_do_not_add_to_repo/config/
	# LITTLE_ENDIAN for UART core
	grep -q 'define LITLE_ENDIAN' ../src/CopiedFiles_do_not_add_to_repo/uncore/uart_16550/uart_defines.v || sed -i '1i`define LITLE_ENDIAN' ../src/CopiedFiles_do_not_add_to_repo/uncore/uart_16550/uart_defines.v
	./insert_debug_comment.sh
	# This line allows the Bootloader to be loaded in a Block RAM on the FPGA
	sed -i "s/bit \[DATA_WIDTH-1:0\].*ROM.*/(\* rom_style=\"block\" \*) &/g" ../src/CopiedFiles_do_not_add_to_repo/generic/mem/rom1p1r.sv
	sed -i 's/$$WALLY/\.\.\/\.\.\//g' ../src/CopiedFiles_do_not_add_to_repo/generic/mem/rom1p1r.sv
	sed -i 's/$$WALLY/\.\.\/\.\.\//g' ../src/CopiedFiles_do_not_add_to_repo/generic/mem/ram1p1rwbe.sv

# build the Zero stage boot loader (ZSBL)
.PHONY: zsbl
zsbl:
	$(MAKE) -C ../zsbl clean
	SYSTEMCLOCK=$(SYSTEMCLOCK) EXT_MEM_BASE=$(EXT_MEM_BASE) EXT_MEM_RANGE=$(EXT_MEM_RANGE) $(MAKE) -C ../zsbl

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
