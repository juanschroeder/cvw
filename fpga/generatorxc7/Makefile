PROJECT       ?= wally_genesys2soc_xc7
TOP_MODULE    ?= fpgaTopXc7Genesys2SoC
PART          ?= xc7k325tffg900-2
FAMILY        ?= kintex7
BOARD         ?= genesys2
DERIV         ?= fpgagenesys2soc
RUN_DERIV     ?= 0
MEM_WIDTH     ?= 64

BUILD_DIR     ?= build
SRC_COPY      := $(BUILD_DIR)/src
PREPROCESS_STAMP := $(BUILD_DIR)/.preprocess.stamp
TOP_SV        := fpgaTopXc7Genesys2SoC.sv
#TOP_SV        := fpgaTopXc7Genesys2SoC_v6.sv
XDC           ?= constraints-genesys2soc-xc7.xdc
CONFIG_VH     ?= ../../config/deriv/$(DERIV)/config.vh
CHIPDB        ?= $(BUILD_DIR)/chipdb
BITFILE       ?= $(BUILD_DIR)/$(PROJECT).bit
JSONFILE      ?= $(BUILD_DIR)/$(PROJECT).json
POST_SYNTH_V  ?= $(BUILD_DIR)/post_synth.v
POST_SYNTH_LOG ?= $(BUILD_DIR)/post_synth_yosys.log
NEXTPNR_LOG   ?= $(BUILD_DIR)/nextpnr.log
NEXTPNR_JSON_LOG ?= $(BUILD_DIR)/nextpnr-json.log
# go ahead even when timing is not met
NEXTPNR_ALLOW_TIMING_FAIL ?= 1
BOOTROM_MEM   ?= ../../fpga/src/boot.mem
DATA_MEM      ?= ../../fpga/src/data.mem
#MANTA_V       ?= manta_cvw_debug.v
#MANTA_V       ?= manta_cvw_debug_spi.v
MANTA_V        ?= manta_cvw_debug_startup.v
MANTA_SRC     := debug/manta/$(MANTA_V)
SYSTEMCLOCK   ?= 12500000
MAXSDCCLOCK   ?= 1000000
EXT_MEM_BASE  ?= $(shell grep 'EXT_MEM_BASE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')
EXT_MEM_RANGE ?= $(shell grep 'EXT_MEM_RANGE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/\1/g' | sed 's/\(.*\)/base=16;\1+1/g' | bc | sed 's/\(.*\)/0x\1/g')
LITEDRAM_SUPPORTED ?= $(shell grep 'LITEDRAM_SUPPORTED' $(CONFIG_VH) | sed -n 's/.*=[[:space:]]*\([[:alnum:]_]*\);/\1/p')
LITEDRAM_BASE ?= $(shell grep 'LITEDRAM_BASE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')
UNCORE_RAM_BASE ?= $(shell grep 'UNCORE_RAM_BASE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')
UNCORE_RAM_RANGE ?= $(shell grep 'UNCORE_RAM_RANGE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/\1/g' | sed 's/\(.*\)/base=16;\1+1/g' | bc | sed 's/\(.*\)/0x\1/g')
UBERDDR3_SUPPORTED ?= $(shell grep 'UBERDDR3_SUPPORTED' $(CONFIG_VH) | sed -n 's/.*=[[:space:]]*\([[:alnum:]_]*\);/\1/p')
BOOTROM_BASE = $(shell grep 'BOOTROM_BASE' $(CONFIG_VH) | sed 's/.*=.*h\([[:alnum:]]*\);/0x\1/g')
REBUILD_ZSBL  ?= 0
PULP_AXI_CDC_SRCS := \
	../../addins/pulp/axi/src/axi_pkg.sv \
	../../addins/pulp/axi/src/axi_cdc.sv \
	../../addins/pulp/axi/src/axi_cdc_src.sv \
	../../addins/pulp/axi/src/axi_cdc_dst.sv \
	../../addins/pulp/common_cells/src/cdc_fifo_gray.sv \
	../../addins/pulp/common_cells/src/sync.sv \
	../../addins/pulp/common_cells/src/binary_to_gray.sv \
	../../addins/pulp/common_cells/src/gray_to_binary.sv \
	../../addins/pulp/common_cells/src/spill_register.sv \
	../../addins/pulp/common_cells/src/spill_register_flushable.sv

YOSYS         ?= yosys
NEXTPNR       ?= nextpnr-xilinx
FASM2FRAMES   ?= fasm2frames
XC7FRAMES2BIT ?= xc7frames2bit
PYPY3         ?= pypy3
BBASM         ?= bbasm
OPENFPGALOADER ?= openFPGALoader
JTAG_LINK     ?= --board $(BOARD)
JTAG_SPEED    ?= 5000000
DOCKER        ?= docker
DOCKER_IMAGE  ?= jsch1/openxc7:slang
DOCKER_USER   ?= $(shell id -u):$(shell id -g)
YOSYS_SKIP_SHARE ?= 1
YOSYS_NODSP   ?= 0
RISCV         ?= /yocto/fpga/cvw_deps/riscv
RISCV_PREFIX  ?= $(RISCV)/bin/riscv64-unknown-elf-
RISCV_BIN     := $(dir $(RISCV_PREFIX))
TARGET_FREQ   ?= 12.5

# nextpnr extra params
NEXTPNR_TARGET_FREQ := --freq $(TARGET_FREQ)
NEXTPNR_EXTRA_PARAMS     ?= $(NEXTPNR_TARGET_FREQ)

NEXTPNR_XILINX_DIR ?= /nextpnr-xilinx/xilinx
NEXTPNR_XILINX_PYTHON_DIR ?= $(NEXTPNR_XILINX_DIR)/python
PRJXRAY_DB_DIR ?= $(NEXTPNR_XILINX_DIR)/external/prjxray-db

DBPART     := $(shell echo $(PART) | sed -e 's/-[0-9]//g')
RTL_INPUTS := $(shell find ../../src ../../addins/cvwsoc ../../addins/ahb-to-axi/rtl ../../addins/uberddr3 ../../addins/verilog-axi/rtl ../../config/deriv/$(DERIV) -type f \( -name '*.sv' -o -name '*.v' -o -name '*.vh' \) 2>/dev/null)
READ_FLAGS := -sv -DSYNTHESIS \
	-I$(SRC_COPY)/config \
	-I../../config/shared \
	-I$(SRC_COPY)/cvwsoc \
	-I$(SRC_COPY)/generic/mem \
	-I$(SRC_COPY)/uberddr3/rtl \
	-I$(SRC_COPY)/uberddr3/rtl/axi \
	-I$(SRC_COPY)/pulp/axi/include \
	-I$(SRC_COPY)/pulp/common_cells/include

SLANG_FLAGS := -DSYNTHESIS --single-unit --ignore-unknown-modules --allow-use-before-declare --ignore-initial --top $(TOP_MODULE) \
	-I$(SRC_COPY)/config \
	-I../../config/shared \
	-I$(SRC_COPY)/cvwsoc \
	-I$(SRC_COPY)/generic/mem \
	-I$(SRC_COPY)/uberddr3/rtl \
	-I$(SRC_COPY)/uberddr3/rtl/axi \
	-I$(SRC_COPY)/pulp/axi/include \
	-I$(SRC_COPY)/pulp/common_cells/include

SYNTH_XILINX_FLAGS := -abc9 -family xc7 -top $(TOP_MODULE)
ifeq ($(YOSYS_NODSP),1)
SYNTH_XILINX_FLAGS += -nodsp
endif

.PHONY: all synth pnr bit pnr-json bit-json bit-from-fasm check-json-fresh check-fasm-fresh program flash flash-local post-synth-existing check-dataram-init preprocess zsblsoc clean distclean docker-shell docker-synth docker-synth-force docker-pnr docker-pnr-json docker-bit docker-bit-json docker-bit-from-fasm docker-post-synth-existing docker-program docker-flash

all: synth

synth: $(BUILD_DIR)/$(PROJECT).json

pnr: $(BUILD_DIR)/$(PROJECT).fasm

bit: $(BUILD_DIR)/$(PROJECT).bit

check-json-fresh:
	test -f $(BUILD_DIR)/$(PROJECT).json
	test $(BUILD_DIR)/$(PROJECT).json -nt $(TOP_SV)
	test $(BUILD_DIR)/$(PROJECT).json -nt $(SRC_COPY)/manta.v
	test $(BUILD_DIR)/$(PROJECT).json -nt $(SRC_COPY)/generic/mem/bootrom_case_xc7.svh
	test $(BUILD_DIR)/$(PROJECT).json -nt $(SRC_COPY)/generic/mem/dataram_init_xc7.svh

check-fasm-fresh: check-json-fresh
	test -s $(BUILD_DIR)/$(PROJECT).fasm
	test $(BUILD_DIR)/$(PROJECT).fasm -nt $(BUILD_DIR)/$(PROJECT).json

pnr-json: $(CHIPDB)/$(DBPART).bin check-json-fresh
	bash -o pipefail -c '$(NEXTPNR) --chipdb $(CHIPDB)/$(DBPART).bin --xdc $(XDC) --json $(BUILD_DIR)/$(PROJECT).json $(NEXTPNR_EXTRA_PARAMS) --fasm $(BUILD_DIR)/$(PROJECT).fasm  2>&1 | tee $(NEXTPNR_JSON_LOG); status=$${PIPESTATUS[0]}; if [ $$status -ne 0 ]; then if [ "$(NEXTPNR_ALLOW_TIMING_FAIL)" = "1" ] && [ -s "$(BUILD_DIR)/$(PROJECT).fasm" ]; then echo "WARNING: nextpnr exited $$status; continuing because NEXTPNR_ALLOW_TIMING_FAIL=1 and FASM exists"; else exit $$status; fi; fi'

bit-json: pnr-json
	$(FASM2FRAMES) --part $(PART) --db-root $(PRJXRAY_DB_DIR)/$(FAMILY) $(BUILD_DIR)/$(PROJECT).fasm > $(BUILD_DIR)/$(PROJECT).frames
	$(XC7FRAMES2BIT) --part_file $(PRJXRAY_DB_DIR)/$(FAMILY)/$(PART)/part.yaml --part_name $(PART) --frm_file $(BUILD_DIR)/$(PROJECT).frames --output_file $(BUILD_DIR)/$(PROJECT).bit

bit-from-fasm: check-fasm-fresh
	$(FASM2FRAMES) --part $(PART) --db-root $(PRJXRAY_DB_DIR)/$(FAMILY) $(BUILD_DIR)/$(PROJECT).fasm > $(BUILD_DIR)/$(PROJECT).frames
	$(XC7FRAMES2BIT) --part_file $(PRJXRAY_DB_DIR)/$(FAMILY)/$(PART)/part.yaml --part_name $(PART) --frm_file $(BUILD_DIR)/$(PROJECT).frames --output_file $(BUILD_DIR)/$(PROJECT).bit

program: $(BUILD_DIR)/$(PROJECT).bit
	$(OPENFPGALOADER) --freq $(JTAG_SPEED) $(JTAG_LINK) --bitstream $<

flash: program

flash-local:
	test -f $(BITFILE)
	$(OPENFPGALOADER) --freq $(JTAG_SPEED) $(JTAG_LINK) --bitstream $(BITFILE)

post-synth-existing:
	test -f $(JSONFILE)
	$(YOSYS) -l $(POST_SYNTH_LOG) -p 'read_json $(JSONFILE); hierarchy -top $(TOP_MODULE); stat; check; write_verilog -noattr $(POST_SYNTH_V)'

check-dataram-init: $(JSONFILE)
	./check_dataram_init.py $(JSONFILE) $(DATA_MEM)


$(BUILD_DIR):
	mkdir -p $@

preprocess: $(PREPROCESS_STAMP)

ifeq ($(REBUILD_ZSBL),1)
ZSBL_PREREQ := zsblsoc
else
ZSBL_PREREQ := $(BOOTROM_MEM)
endif

zsblsoc:
	PATH=$(RISCV_BIN):../../bin:$$PATH RISCV=$(RISCV) SYSTEMCLOCK=$(SYSTEMCLOCK) MAXSDCCLOCK=$(MAXSDCCLOCK) EXT_MEM_BASE=$(EXT_MEM_BASE) EXT_MEM_RANGE=$(EXT_MEM_RANGE) LITEDRAM_SUPPORTED=$(LITEDRAM_SUPPORTED) LITEDRAM_BASE=$(LITEDRAM_BASE) UNCORE_RAM_BASE=$(UNCORE_RAM_BASE) UNCORE_RAM_RANGE=$(UNCORE_RAM_RANGE) UBERDDR3_SUPPORTED=$(UBERDDR3_SUPPORTED) BOOTROM_BASE=$(BOOTROM_BASE) MEM_WIDTH=$(MEM_WIDTH) $(MAKE) -C ../../fpga/zsbl clean all

$(PREPROCESS_STAMP): $(RTL_INPUTS) $(PULP_AXI_CDC_SRCS) $(TOP_SV) $(MANTA_SRC) $(ZSBL_PREREQ) $(DATA_MEM) | $(BUILD_DIR)
	if [ "$(RUN_DERIV)" = "1" ]; then WALLY=$(abspath ../..) PATH=$(abspath ../../bin):$$PATH $(MAKE) -C ../../sim deriv; fi
	rm -rf $(SRC_COPY)
	mkdir -p $(SRC_COPY)/config
	cp -r ../../src/* $(SRC_COPY)/
	cp ../../config/deriv/$(DERIV)/config.vh $(SRC_COPY)/config/config.vh
	cp -r ../../addins/cvwsoc $(SRC_COPY)/
	cp $(MANTA_SRC) $(SRC_COPY)/manta.v
	mkdir -p $(SRC_COPY)/ahb-to-axi/rtl
	cp ../../addins/ahb-to-axi/rtl/*.sv $(SRC_COPY)/ahb-to-axi/rtl/
	cp -r ../../addins/uberddr3 $(SRC_COPY)/
	mkdir -p $(SRC_COPY)/verilog-axi/rtl
	cp ../../addins/verilog-axi/rtl/*.v $(SRC_COPY)/verilog-axi/rtl/
	mkdir -p $(SRC_COPY)/pulp/axi/src $(SRC_COPY)/pulp/axi/include $(SRC_COPY)/pulp/common_cells/src $(SRC_COPY)/pulp/common_cells/include
	cp -r ../../addins/pulp/axi/include/axi $(SRC_COPY)/pulp/axi/include/
	cp -r ../../addins/pulp/common_cells/include/common_cells $(SRC_COPY)/pulp/common_cells/include/
	cp $(PULP_AXI_CDC_SRCS) $(SRC_COPY)/pulp/axi/src/
	mv $(SRC_COPY)/pulp/axi/src/cdc_fifo_gray.sv $(SRC_COPY)/pulp/common_cells/src/
	mv $(SRC_COPY)/pulp/axi/src/sync.sv $(SRC_COPY)/pulp/common_cells/src/
	mv $(SRC_COPY)/pulp/axi/src/binary_to_gray.sv $(SRC_COPY)/pulp/common_cells/src/
	mv $(SRC_COPY)/pulp/axi/src/gray_to_binary.sv $(SRC_COPY)/pulp/common_cells/src/
	mv $(SRC_COPY)/pulp/axi/src/spill_register.sv $(SRC_COPY)/pulp/common_cells/src/
	mv $(SRC_COPY)/pulp/axi/src/spill_register_flushable.sv $(SRC_COPY)/pulp/common_cells/src/
	cp rom1p1r_xc7.sv $(SRC_COPY)/generic/mem/rom1p1r.sv
	cp ram1p1rwbe_xc7.sv $(SRC_COPY)/generic/mem/ram1p1rwbe.sv
	awk 'NR <= 8192 { printf "          13'\''h%03x: dout <= 64'\''h%s;\n", NR-1, $$1 }' $(BOOTROM_MEM) > $(SRC_COPY)/generic/mem/bootrom_case_xc7.svh
	awk 'NR <= 4096 { printf "          %d: 64'\''h%s,\n", NR-1, $$1 }' $(DATA_MEM) > $(SRC_COPY)/generic/mem/dataram_init_xc7.svh
	sed -i 's/$$WALLY/\.\.\/\.\./g' $(SRC_COPY)/generic/mem/rom1p1r.sv
	sed -i 's/$$WALLY/\.\.\/\.\./g' $(SRC_COPY)/generic/mem/ram1p1rwbe.sv
	perl -0pi -e 's/localparam PRELOAD_START = P\.BOOTROM_BASE >> 3;/localparam PRELOAD_START = 0;\n  localparam logic [ADDR_WIDTH-1:0] ROM_BASE_INDEX = P.BOOTROM_BASE[ADDR_WIDTH+OFFSET-1:OFFSET];/' $(SRC_COPY)/uncore/rom_ahb.sv
	sed -i 's/\.addr(HADDR\[ADDR_WIDTH+OFFSET-1:OFFSET\])/.addr(HADDR[ADDR_WIDTH+OFFSET-1:OFFSET] - ROM_BASE_INDEX)/' $(SRC_COPY)/uncore/rom_ahb.sv
	perl -0pi -e 's/localparam\s+ADDR_WIDTH = \$$clog2\(RANGE\/8\);/localparam                   RAM_DEPTH = (RANGE + 1)\/8;\n  localparam                   ADDR_WIDTH = \$$clog2(RAM_DEPTH);/' $(SRC_COPY)/uncore/ram_ahb.sv
	sed -i 's/ram1p1rwbe #(P.USE_SRAM, RANGE\/8, P.XLEN, PRELOAD)/ram1p1rwbe #(P.USE_SRAM, RAM_DEPTH, P.XLEN, PRELOAD)/' $(SRC_COPY)/uncore/ram_ahb.sv
	sed -i 's/\.WB_RMII_MDIO,/\.WB_RMII_MDIO(),/' $(SRC_COPY)/wally/wallypipelinedsoc.sv
	perl -0pi -e 's/\n`default_nettype wire\nendmodule\n/\nendmodule\n\n`default_nettype wire\n/' $(SRC_COPY)/ahb-to-axi/rtl/ahb_to_axi4_burst.sv
	perl -0pi -e 's|assign TransmitDataEndian = Format\[0\] \? \{<<\{TransmitReadData\[7:0\]\}\} : TransmitReadData\[7:0\];|// yosys-slang rejects streaming operators in ternaries; this is the same 8-bit bit reversal as {<<{TransmitReadData[7:0]}}.\n  assign TransmitDataEndian = Format[0] ? {TransmitReadData[0], TransmitReadData[1], TransmitReadData[2], TransmitReadData[3], TransmitReadData[4], TransmitReadData[5], TransmitReadData[6], TransmitReadData[7]} : TransmitReadData[7:0];|' $(SRC_COPY)/uncore/spi_apb.sv
	perl -0pi -e 's|assign ReceiveShiftRegEndian = Format\[0\] \? \{<<\{ASR\[7:0\]\}\} : ASR\[7:0\];|// yosys-slang rejects streaming operators in ternaries; this is the same 8-bit bit reversal as {<<{ASR[7:0]}}.\n  assign ReceiveShiftRegEndian = Format[0] ? {ASR[0], ASR[1], ASR[2], ASR[3], ASR[4], ASR[5], ASR[6], ASR[7]} : ASR[7:0];|' $(SRC_COPY)/uncore/spi_apb.sv
	sed -i -E 's/(localparam logic WISHBONE_SUPPORTED[[:space:]]*=[[:space:]]*)1;/\10;/' $(SRC_COPY)/config/config.vh
	sed -i -E 's/(localparam logic WISHBONE_UART_SUPPORTED[[:space:]]*=[[:space:]]*)1;/\10;/' $(SRC_COPY)/config/config.vh
	sed -i -E 's/(localparam logic WISHBONE_STUB_SUPPORTED[[:space:]]*=[[:space:]]*)1;/\10;/' $(SRC_COPY)/config/config.vh
	sed -i -E 's/(localparam logic AXI_SDHCI_SUPPORTED[[:space:]]*=[[:space:]]*)1;/\10;/' $(SRC_COPY)/config/config.vh
	sed -i -E 's/(localparam logic AXI_DMA_SUPPORTED[[:space:]]*=[[:space:]]*)1;/\10;/' $(SRC_COPY)/config/config.vh
	sed -i -E 's/(localparam logic AXI_VGA_SUPPORTED[[:space:]]*=[[:space:]]*)1;/\10;/' $(SRC_COPY)/config/config.vh
	sed -i -E 's/(localparam logic AXI_USB_SUPPORTED[[:space:]]*=[[:space:]]*)1;/\10;/' $(SRC_COPY)/config/config.vh
	sed -i -E 's/(localparam logic AXI_ETH_SUPPORTED[[:space:]]*=[[:space:]]*)1;/\10;/' $(SRC_COPY)/config/config.vh
	touch $@

$(BUILD_DIR)/sources.ys: $(PREPROCESS_STAMP)
	@mkdir -p $(BUILD_DIR)
	@printf 'plugin -i slang\n' > $@
	@printf 'read_slang $(SLANG_FLAGS) $(SRC_COPY)/cvw.sv $(SRC_COPY)/pulp/axi/src/axi_pkg.sv $(TOP_SV)' >> $@
	@find $(SRC_COPY) -type f -name '*.sv' ! -name 'cvw.sv' \
	  ! -path '$(SRC_COPY)/pulp/axi/src/axi_pkg.sv' \
	  ! -path '$(SRC_COPY)/cvwsoc/sdhci/*' \
	  ! -path '$(SRC_COPY)/cvwsoc/vga/*' \
	  ! -path '$(SRC_COPY)/cvwsoc/usb/*' \
	  ! -path '$(SRC_COPY)/cvwsoc/liteeth/*' \
	  ! -path '$(SRC_COPY)/cvwsoc/litedram/*' \
	  ! -path '$(SRC_COPY)/cvwsoc/wishbone/*' \
	  ! -path '$(SRC_COPY)/cvwsoc/*.sv' \
	  ! -path '$(SRC_COPY)/uberddr3/rtl/ecp5_phy/*' \
	  ! -path '$(SRC_COPY)/uberddr3/rtl/spd/*' \
	  ! -path '$(SRC_COPY)/uberddr3/testbench/*' \
	  ! -path '$(SRC_COPY)/uberddr3/example_demo/*' \
	  | sort | xargs printf ' %s' >> $@
	@printf '\n' >> $@
	@printf 'read_verilog %s\n' \
	  $(SRC_COPY)/manta.v \
	  $(SRC_COPY)/verilog-axi/rtl/axi_adapter.v \
	  $(SRC_COPY)/verilog-axi/rtl/axi_adapter_rd.v \
	  $(SRC_COPY)/verilog-axi/rtl/axi_adapter_wr.v \
	  $(SRC_COPY)/uberddr3/rtl/axi/axi_addr.v \
	  $(SRC_COPY)/uberddr3/rtl/axi/axim2wbsp.v \
	  $(SRC_COPY)/uberddr3/rtl/axi/aximrd2wbsp.v \
	  $(SRC_COPY)/uberddr3/rtl/axi/aximwr2wbsp.v \
	  $(SRC_COPY)/uberddr3/rtl/axi/ddr3_top_axi.v \
	  $(SRC_COPY)/uberddr3/rtl/axi/sfifo.v \
	  $(SRC_COPY)/uberddr3/rtl/axi/skidbuffer.v \
	  $(SRC_COPY)/uberddr3/rtl/axi/wbarbiter.v \
	  $(SRC_COPY)/uberddr3/rtl/ddr3_controller.v \
	  $(SRC_COPY)/uberddr3/rtl/ddr3_phy.v \
	  $(SRC_COPY)/uberddr3/rtl/ddr3_top.v >> $@
	@printf 'read_verilog -lib /usr/local/share/yosys/xilinx/cells_sim.v\n' >> $@
	@printf 'read_verilog -lib /usr/local/share/yosys/xilinx/cells_xtra.v\n' >> $@
	@printf 'read_verilog -sv $(SRC_COPY)/cvwsoc/uberddr3/uberddr3_wrapper.sv\n' >> $@
	@printf 'hierarchy -top $(TOP_MODULE)\n' >> $@
ifeq ($(YOSYS_SKIP_SHARE),1)
	@printf 'synth_xilinx -flatten $(SYNTH_XILINX_FLAGS) -run begin:coarse\n' >> $@
	@printf 'techmap -map +/cmp2lut.v -map +/cmp2lcu.v -D LUT_WIDTH=6\n' >> $@
	@printf 'alumacc\n' >> $@
	@printf 'opt\n' >> $@
	@printf 'memory -nomap\n' >> $@
	@printf 'opt_clean\n' >> $@
	@printf 'synth_xilinx $(SYNTH_XILINX_FLAGS) -run map_memory:check\n' >> $@
else
	@printf 'synth_xilinx -flatten $(SYNTH_XILINX_FLAGS)\n' >> $@
endif
	@printf 'proc\n' >> $@
	@printf 'select $(TOP_MODULE)\n' >> $@
	@printf 'delete t:$$print\n' >> $@
	@printf 'write_json -selected $(BUILD_DIR)/$(PROJECT).json\n' >> $@

$(BUILD_DIR)/$(PROJECT).json: $(BUILD_DIR)/sources.ys $(TOP_SV)
	$(YOSYS) -l $(BUILD_DIR)/yosys.log -s $(BUILD_DIR)/sources.ys

$(CHIPDB)/$(DBPART).bin: | $(BUILD_DIR)
	mkdir -p $(CHIPDB)
	$(PYPY3) $(NEXTPNR_XILINX_PYTHON_DIR)/bbaexport.py --device $(PART) --bba $(BUILD_DIR)/$(DBPART).bba
	$(BBASM) -l $(BUILD_DIR)/$(DBPART).bba $@

$(BUILD_DIR)/$(PROJECT).fasm: $(BUILD_DIR)/$(PROJECT).json $(CHIPDB)/$(DBPART).bin $(XDC)
	bash -o pipefail -c '$(NEXTPNR) --chipdb $(CHIPDB)/$(DBPART).bin --xdc $(XDC) --json $(BUILD_DIR)/$(PROJECT).json $(NEXTPNR_EXTRA_PARAMS) --fasm $@  2>&1 | tee $(NEXTPNR_LOG); status=$${PIPESTATUS[0]}; if [ $$status -ne 0 ]; then if [ "$(NEXTPNR_ALLOW_TIMING_FAIL)" = "1" ] && [ -s "$@" ]; then echo "WARNING: nextpnr exited $$status; continuing because NEXTPNR_ALLOW_TIMING_FAIL=1 and FASM exists"; else exit $$status; fi; fi'

$(BUILD_DIR)/$(PROJECT).frames: $(BUILD_DIR)/$(PROJECT).fasm
	$(FASM2FRAMES) --part $(PART) --db-root $(PRJXRAY_DB_DIR)/$(FAMILY) $< > $@

$(BUILD_DIR)/$(PROJECT).bit: $(BUILD_DIR)/$(PROJECT).frames
	$(XC7FRAMES2BIT) --part_file $(PRJXRAY_DB_DIR)/$(FAMILY)/$(PART)/part.yaml --part_name $(PART) --frm_file $< --output_file $@

docker-shell:
	$(DOCKER) run --rm -it --user $(DOCKER_USER) -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) bash

docker-synth: zsblsoc
	$(DOCKER) run --rm --user $(DOCKER_USER) -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) make -j$$(nproc) YOSYS_NODSP=$(YOSYS_NODSP) REBUILD_ZSBL=0 synth

docker-synth-force: zsblsoc
	$(DOCKER) run --rm --user $(DOCKER_USER) -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) make -B -j$$(nproc) YOSYS_NODSP=$(YOSYS_NODSP) REBUILD_ZSBL=0 synth

docker-pnr:
	$(DOCKER) run --rm --user $(DOCKER_USER) -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) make YOSYS_NODSP=$(YOSYS_NODSP) REBUILD_ZSBL=0 NEXTPNR_ALLOW_TIMING_FAIL=$(NEXTPNR_ALLOW_TIMING_FAIL) pnr

docker-pnr-json:
	$(DOCKER) run --rm --user $(DOCKER_USER) -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) make YOSYS_NODSP=$(YOSYS_NODSP) REBUILD_ZSBL=0 NEXTPNR_ALLOW_TIMING_FAIL=$(NEXTPNR_ALLOW_TIMING_FAIL) pnr-json

docker-bit: zsblsoc
	$(DOCKER) run --rm --user $(DOCKER_USER) -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) make -j$$(nproc) YOSYS_NODSP=$(YOSYS_NODSP) REBUILD_ZSBL=0 NEXTPNR_ALLOW_TIMING_FAIL=$(NEXTPNR_ALLOW_TIMING_FAIL) bit

docker-bit-json:
	$(DOCKER) run --rm --user $(DOCKER_USER) -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) make REBUILD_ZSBL=0 NEXTPNR_ALLOW_TIMING_FAIL=$(NEXTPNR_ALLOW_TIMING_FAIL) bit-json

docker-bit-from-fasm:
	$(DOCKER) run --rm --user $(DOCKER_USER) -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) make REBUILD_ZSBL=0 bit-from-fasm

# force rebuild
docker-bit-force: docker-synth-force docker-pnr-json docker-bit-from-fasm

docker-post-synth-existing:
	$(DOCKER) run --rm --user $(DOCKER_USER) -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) make post-synth-existing

docker-program:
	$(DOCKER) run --rm --privileged --user root -v /dev/bus/usb:/dev/bus/usb -v $(abspath ../../):/work -w /work/fpga/generatorxc7 $(DOCKER_IMAGE) make JTAG_LINK="$(JTAG_LINK)" program

docker-flash: docker-program

clean:
	rm -rf $(BUILD_DIR)

distclean: clean
