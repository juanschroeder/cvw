source ../constraints/debug-defs.xdc

#######################################################
# CPU side ILA
#######################################################


create_debug_core u_ila_spi ila

# ILA settings
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_spi]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_spi]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_spi]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_spi]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_spi]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_spi]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_spi]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_spi]
# startgroup
# set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_spi ]
# set_property C_ADV_TRIGGER true [get_debug_cores u_ila_spi ]
# set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_spi ]
# set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_spi ]
# endgroup
# Test change (ChatGPT)
set_property port_width 1 [get_debug_ports u_ila_spi/clk]
connect_debug_port u_ila_spi/clk [get_nets CPUCLK]

# set_property port_width 64 [get_debug_ports u_ila_spi/probe0]
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_spi/probe0]
#connect_debug_port u_ila_spi/probe0 [get_nets [list {cpu/wally/core/PCM[0]} {cpu/wally/core/PCM[1]} {cpu/wally/core/PCM[2]} {cpu/wally/core/PCM[3]} {cpu/wally/core/PCM[4]} {cpu/wally/core/PCM[5]} {cpu/wally/core/PCM[6]} {cpu/wally/core/PCM[7]} {cpu/wally/core/PCM[8]} {cpu/wally/core/PCM[9]} {cpu/wally/core/PCM[10]} {cpu/wally/core/PCM[11]} {cpu/wally/core/PCM[12]} {cpu/wally/core/PCM[13]} {cpu/wally/core/PCM[14]} {cpu/wally/core/PCM[15]} {cpu/wally/core/PCM[16]} {cpu/wally/core/PCM[17]} {cpu/wally/core/PCM[18]} {cpu/wally/core/PCM[19]} {cpu/wally/core/PCM[20]} {cpu/wally/core/PCM[21]} {cpu/wally/core/PCM[22]} {cpu/wally/core/PCM[23]} {cpu/wally/core/PCM[24]} {cpu/wally/core/PCM[25]} {cpu/wally/core/PCM[26]} {cpu/wally/core/PCM[27]} {cpu/wally/core/PCM[28]} {cpu/wally/core/PCM[29]} {cpu/wally/core/PCM[30]} {cpu/wally/core/PCM[31]} {cpu/wally/core/PCM[32]} {cpu/wally/core/PCM[33]} {cpu/wally/core/PCM[34]} {cpu/wally/core/PCM[35]} {cpu/wally/core/PCM[36]} {cpu/wally/core/PCM[37]} {cpu/wally/core/PCM[38]} {cpu/wally/core/PCM[39]} {cpu/wally/core/PCM[40]} {cpu/wally/core/PCM[41]} {cpu/wally/core/PCM[42]} {cpu/wally/core/PCM[43]} {cpu/wally/core/PCM[44]} {cpu/wally/core/PCM[45]} {cpu/wally/core/PCM[46]} {cpu/wally/core/PCM[47]} {cpu/wally/core/PCM[48]} {cpu/wally/core/PCM[49]} {cpu/wally/core/PCM[50]} {cpu/wally/core/PCM[51]} {cpu/wally/core/PCM[52]} {cpu/wally/core/PCM[53]} {cpu/wally/core/PCM[54]} {cpu/wally/core/PCM[55]} {cpu/wally/core/PCM[56]} {cpu/wally/core/PCM[57]} {cpu/wally/core/PCM[58]} {cpu/wally/core/PCM[59]} {cpu/wally/core/PCM[60]} {cpu/wally/core/PCM[61]} {cpu/wally/core/PCM[62]} {cpu/wally/core/PCM[63]} ]]
ila_add_probe u_ila_spi -bus cpu/wally/core/PCM -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/wally/core/InstrM -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net cpu/wally/core/TrapM
ila_add_probe u_ila_spi -net cpu/wally/core/InstrValidM
# connect_debug_port u_ila_spi/probe3 [get_nets [list {cpu/wally/core/InstrM[0]} {cpu/wally/core/InstrM[1]} {cpu/wally/core/InstrM[2]} {cpu/wally/core/InstrM[3]} {cpu/wally/core/InstrM[4]} {cpu/wally/core/InstrM[5]} {cpu/wally/core/InstrM[6]} {cpu/wally/core/InstrM[7]} {cpu/wally/core/InstrM[8]} {cpu/wally/core/InstrM[9]} {cpu/wally/core/InstrM[10]} {cpu/wally/core/InstrM[11]} {cpu/wally/core/InstrM[12]} {cpu/wally/core/InstrM[13]} {cpu/wally/core/InstrM[14]} {cpu/wally/core/InstrM[15]} {cpu/wally/core/InstrM[16]} {cpu/wally/core/InstrM[17]} {cpu/wally/core/InstrM[18]} {cpu/wally/core/InstrM[19]} {cpu/wally/core/InstrM[20]} {cpu/wally/core/InstrM[21]} {cpu/wally/core/InstrM[22]} {cpu/wally/core/InstrM[23]} {cpu/wally/core/InstrM[24]} {cpu/wally/core/InstrM[25]} {cpu/wally/core/InstrM[26]} {cpu/wally/core/InstrM[27]} {cpu/wally/core/InstrM[28]} {cpu/wally/core/InstrM[29]} {cpu/wally/core/InstrM[30]} {cpu/wally/core/InstrM[31]} ]]
ila_add_probe u_ila_spi -net cpu/wally/core/StallM
ila_add_probe u_ila_spi -net cpu/wally/core/FlushM
# ila_add_probe u_ila_spi -bus cpu/wally/core/RdE -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu/wally/core/RdM -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu/wally/core/ieu/RdW -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net cpu/wally/core/ieu/RegWriteW
# ila_add_probe u_ila_spi -bus cpu/wally/core/ieu/dp/ResultW  -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net cpu/wally/core/ieu/dp/regf/we3
# ila_add_probe u_ila_spi -bus cpu/wally/core/ieu/dp/regf/a3 -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu/wally/core/ieu/dp/regf/wd3 -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu/wally/core/lsu/IEUAdrM -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu/wally/core/WriteDataM -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu/wally/core/MemRWM  -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu/wally/core/lsu/ReadDataM  -msb 63 -lsb 0 -order lsb2msb

# SD card (SPI bus) signals
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCLK
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCIn
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCS[0]
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCmd
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/CurrState  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveFIFOReadInc

# AHB bus signals
#ila_add_probe u_ila_spi -bus cpu/wally/core/ebu.ebu/HTRANS -msb 1 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus HSIZE -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/wally/core/HSIZE -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/wally/core/lsu/LSUHWSTRB -msb auto -lsb 0 -order lsb2msb

ila_add_probe u_ila_spi -bus cpu/wally/HSIZE -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/wally/HWDATA -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/wally/HRDATA  -msb auto -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus cpu/wally/core/lsu/LSUHWSTRB -msb auto -lsb 0 -order lsb2msb



ila_add_probe u_ila_spi -net cpu/wally/HREADY
ila_add_probe u_ila_spi -net cpu/wally/HWRITE
ila_add_probe u_ila_spi -bus cpu/wally/HTRANS -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/wally/HADDR -msb 31 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus cpu/wally/HRDATAEXT -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/wally/HPROT -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/wally/HBURST -msb 2 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -net HREADYEXT
ila_add_probe u_ila_spi -net cpu/wally/hready_axi
ila_add_probe u_ila_spi -net cpu/wally/hsel_axi
#ila_add_probe u_ila_spi -net HRESPEXT
# ila_add_probe u_ila_spi -net HMASTLOCK
#ila_add_probe u_ila_spi -bus HWSTRB -msb 7 -lsb 0 -order lsb2msb

# AHB-AXI bridge minimal signals
# AXI bridge output signals required by bridge_trace_analyzer
# ila_add_probe u_ila_spi -bus cpu_m_axi_awid    -msb 3  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu_m_axi_awaddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_awlen   -msb 7  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_awsize  -msb 2  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_awburst -msb 1  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net cpu_m_axi_awlock
# ila_add_probe u_ila_spi -bus cpu_m_axi_awcache -msb 3  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_awprot  -msb 2  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net cpu_m_axi_awvalid
ila_add_probe u_ila_spi -net cpu_m_axi_awready

# ila_add_probe u_ila_spi -bus cpu_m_axi_wdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_wstrb -msb 7  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net cpu_m_axi_wlast
ila_add_probe u_ila_spi -net cpu_m_axi_wvalid
ila_add_probe u_ila_spi -net cpu_m_axi_wready

ila_add_probe u_ila_spi -bus cpu_m_axi_bid -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net cpu_m_axi_bvalid
ila_add_probe u_ila_spi -net cpu_m_axi_bready

ila_add_probe u_ila_spi -bus cpu_m_axi_arid    -msb 3  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu_m_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_arlen   -msb 7  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_arsize  -msb 2  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_arburst -msb 1  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net cpu_m_axi_arlock
# ila_add_probe u_ila_spi -bus cpu_m_axi_arcache -msb 3  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_arprot  -msb 2  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net cpu_m_axi_arvalid
ila_add_probe u_ila_spi -net cpu_m_axi_arready

# ila_add_probe u_ila_spi -bus cpu_m_axi_rid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus cpu_m_axi_rdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net cpu_m_axi_rlast
ila_add_probe u_ila_spi -net cpu_m_axi_rvalid
ila_add_probe u_ila_spi -net cpu_m_axi_rready

ila_add_probe u_ila_spi -bus cpu_m_axi_bresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu_m_axi_rresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net peripheral_aresetn
#ila_add_probe u_ila_spi -net u_cvwsoc_axi/BUSCORERSTn


##############################
## DELETE THIS!!!
###################
ila_add_probe u_ila_spi -net bus_struct_reset
ila_add_probe u_ila_spi -net peripheral_reset
ila_add_probe u_ila_spi -net interconnect_aresetn
ila_add_probe u_ila_spi -net ddr_buscorerstn
ila_add_probe u_ila_spi -net ddr_busrstn
ila_add_probe u_ila_spi -net cpu_clk_locked

ila_add_probe u_ila_spi -net rst_req
ila_add_probe u_ila_spi -net resetn_comb


#############################

#######################################################
# AXI side ILA
#######################################################

create_debug_core u_ila_axi ila

# ILA settings
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_axi]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_axi]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_axi]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_axi]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_axi]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_axi]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_axi]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_axi]
# startgroup
# set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_axi ]
# set_property C_ADV_TRIGGER true [get_debug_cores u_ila_axi ]
# set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_axi ]
# set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_axi ]
# endgroup
# Test change (ChatGPT)
set_property port_width 1 [get_debug_ports u_ila_axi/clk]
connect_debug_port u_ila_axi/clk [get_nets u_cvwsoc_axi/BUSCLK_i]


# USB
# ila_add_probe u_ila_axi -bus   u_cvwsoc_axi/usb_m_axi_awid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus  u_cvwsoc_axi/usb_m_axi_awaddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   u_cvwsoc_axi/usb_m_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   u_cvwsoc_axi/usb_m_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   u_cvwsoc_axi/usb_m_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_awlock
# ila_add_probe u_ila_axi -bus   u_cvwsoc_axi/usb_m_axi_awcache  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   u_cvwsoc_axi/usb_m_axi_awprot  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_awvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_awready

# ila_add_probe u_ila_axi -bus  u_cvwsoc_axi/usb_m_axi_wdata  -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   u_cvwsoc_axi/usb_m_axi_wstrb  -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_wlast
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_wvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_wready

# ila_add_probe u_ila_axi -bus   u_cvwsoc_axi/usb_m_axi_bid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   u_cvwsoc_axi/usb_m_axi_bresp  -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_bvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_bready

# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/usb_m_axi_arid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/usb_m_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/usb_m_axi_arlen  -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/usb_m_axi_arsize  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/usb_m_axi_arburst  -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_arlock
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/usb_m_axi_arcache  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/usb_m_axi_arprot  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_arvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_arready

# ila_add_probe u_ila_axi -bus  u_cvwsoc_axi/usb_m_axi_rid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/usb_m_axi_rdata  -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/usb_m_axi_rresp  -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_rlast
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_rvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/usb_m_axi_rready


# SDHCI probes
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/sd_clk_o
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/sd_cd_ni
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/sd_cmd_en
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/sd_cmd_o
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/sd_cmd_i
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/sd_dat_en
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/sd_dat_o -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/sd_dat_i -msb 3 -lsb 0 -order lsb2msb

# # SDHCI debug taps: command path
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_current_cmd -msb 5 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_current_arg -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_started
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_data_present
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_xfer_dir
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_needs_busy
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sd_cmd_done
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sd_rsp_done

# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_result_valid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_timeout_error
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_crc_error
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_index_error
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_end_bit_error

# # SDHCI debug taps: mode / register-derived state
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_bus_width_4
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_block_size -msb 9 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_block_count -msb 15 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_read_transfer_active
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_write_transfer_active
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_buffer_read_enable
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_buffer_write_enable
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_pause_sd_clk

# # SDHCI debug taps: data FSM
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_dat_state -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_read_state -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_write_state -msb 2 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_start_read
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_read_valid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_read_done
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_read_crc_err
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_read_end_bit_err
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_timeout_elapsed

# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_buffer_write_valid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_buffer_write_ready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_buffer_write_data -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_buffer_read_valid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_buffer_read_ready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_buffer_read_data -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_buffer_empty

# # SDHCI debug taps: dat_buffer / SRAM shift register
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_reg_push
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_reg_push_data -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_reg_pop
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_reg_pop_data -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_reg_empty
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_reg_length -msb 8 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_has_block
# # Newer SDHCI RTL no longer has the source signal for this debug tap.
# # ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_has_space
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_current_word_counter -msb 9 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sram_en
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sram_pop_front_i
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sram_pop_front_q
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sram_push_back_i
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sram_back_data_i -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sram_front_data_o -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sram_empty_o
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sram_length_o -msb 8 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_state -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_cycles_waiting -msb 6 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_accepted_rsp_type -msb 1 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_rx_state -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_bit_cnt -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_long
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_receiving
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_start_bit_observed
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_all_bits_received
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_capture_bit
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_capture_word_bit
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_crc_start
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_crc_end_output
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_crc7_calc -msb 6 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp_crc_corr
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp0 -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp1 -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp2 -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp3 -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp0_de
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp1_de
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp2_de
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_rsp3_de

# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_resp_shift -msb 159 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_resp_shift_count -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_cmd_resp_shift_active
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_sdhci.dbg_sdhci_sd_clk_en_p


# between CDC and crossbar (FIX! Naming has changed)
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# some bits are optimized away?
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arlen -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_arvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_arready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_rvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_rready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_rlast
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_rdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_rid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awaddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_awvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_awready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_wdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_wstrb -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_wvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_wready
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_wlast
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_bid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_bvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_bready


# crossbar side to DDR
# these ones repeat the DDR3 ones below




# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/user_port_axi_0_bready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/user_port_axi_0_bid -msb 3 -lsb 0 -order lsb2msb

# CPU CDC output -> XBAR CPU-master input: cpu_cdc_to_xbar_axi_*
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awaddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_awlock
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awqos -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awregion -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_awvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_awready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_wdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_wstrb -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_wlast
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_wvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_wready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_bid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_bvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_bready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_araddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_arlock
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arqos -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arregion -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_arvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_arready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_rid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_rdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_rlast
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_rvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUS_axi_rready
#ila_add_probe u_ila_axi -net u_cvwsoc_axi/BUSCORERSTn

# XBAR -> iDMA register-slave port at 0x10080000: xbar_to_idma_cfg_axi_*
# Packed crossbar M07 == CB_M_IDMA_DESC.
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awid -msb 39 -lsb 35 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awaddr -msb 255 -lsb 224 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awlen -msb 63 -lsb 56 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awsize -msb 23 -lsb 21 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awburst -msb 15 -lsb 14 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awlock -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awcache -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awprot -msb 23 -lsb 21 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awqos -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awregion -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_awready -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_wdata -msb 511 -lsb 448 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_wstrb -msb 63 -lsb 56 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_wlast -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_wvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_wready -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_bid -msb 39 -lsb 35 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_bresp -msb 15 -lsb 14 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_bvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_bready -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arid -msb 39 -lsb 35 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_araddr -msb 255 -lsb 224 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arlen -msb 63 -lsb 56 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arsize -msb 23 -lsb 21 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arburst -msb 15 -lsb 14 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arlock -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arcache -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arprot -msb 23 -lsb 21 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arqos -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arregion -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_arready -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_rid -msb 39 -lsb 35 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_rdata -msb 511 -lsb 448 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_rresp -msb 15 -lsb 14 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_rlast -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_rvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_m_axi_rready -msb 7 -lsb 7 -order lsb2msb

# iDMA master -> XBAR master-input port: idma_m_axi_* descriptor fetch.
# Packed crossbar S04 == CB_S_IDMA_FE, iDMA descriptor frontend AXI master.
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awid -msb 24 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awaddr -msb 159 -lsb 128 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awlen -msb 39 -lsb 32 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awsize -msb 14 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awburst -msb 9 -lsb 8 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awlock -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awcache -msb 19 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awprot -msb 14 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awqos -msb 19 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awready -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wdata -msb 319 -lsb 256 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wstrb -msb 39 -lsb 32 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wlast -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wready -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_bid -msb 24 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_bresp -msb 9 -lsb 8 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_bvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_bready -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arid -msb 24 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_araddr -msb 159 -lsb 128 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arlen -msb 39 -lsb 32 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arsize -msb 14 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arburst -msb 9 -lsb 8 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arlock -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arcache -msb 19 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arprot -msb 14 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arqos -msb 19 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arready -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rid -msb 24 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rdata -msb 319 -lsb 256 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rresp -msb 9 -lsb 8 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rlast -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rready -msb 4 -lsb 4 -order lsb2msb

# AXI->AXIS desc64 descriptor-fetch frontend.
# Packed crossbar S05 == CB_S_IDMA_FE_AXIS.
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awid -msb 29 -lsb 25 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awaddr -msb 191 -lsb 160 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awlen -msb 47 -lsb 40 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awsize -msb 17 -lsb 15 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awburst -msb 11 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awlock -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awcache -msb 23 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awprot -msb 17 -lsb 15 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awqos -msb 23 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_awready -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wdata -msb 383 -lsb 320 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wstrb -msb 47 -lsb 40 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wlast -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_wready -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_bid -msb 29 -lsb 25 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_bresp -msb 11 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_bvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_bready -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arid -msb 29 -lsb 25 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_araddr -msb 191 -lsb 160 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arlen -msb 47 -lsb 40 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arsize -msb 17 -lsb 15 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arburst -msb 11 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arlock -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arcache -msb 23 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arprot -msb 17 -lsb 15 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arqos -msb 23 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arready -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rid -msb 29 -lsb 25 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rdata -msb 383 -lsb 320 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rresp -msb 11 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rlast -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rready -msb 5 -lsb 5 -order lsb2msb

# VGA framebuffer scanout master read path.
# Packed crossbar S02 == CB_S_VGA.
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arid -msb 14 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_araddr -msb 95 -lsb 64 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arlen -msb 23 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arsize -msb 8 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arburst -msb 5 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arvalid -msb 2 -lsb 2 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arready -msb 2 -lsb 2 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rid -msb 14 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rresp -msb 5 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rlast -msb 2 -lsb 2 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rvalid -msb 2 -lsb 2 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rready -msb 2 -lsb 2 -order lsb2msb

# Shared iDMA backend payload-data read path.
# Packed crossbar S06 == CB_S_IDMA_BE.
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arid -msb 34 -lsb 30 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_araddr -msb 223 -lsb 192 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arlen -msb 55 -lsb 48 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arsize -msb 20 -lsb 18 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arburst -msb 13 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arvalid -msb 6 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_arready -msb 6 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rid -msb 34 -lsb 30 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rresp -msb 13 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rlast -msb 6 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rvalid -msb 6 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_xilinx_xbar/cb_s_axi_rready -msb 6 -lsb 6 -order lsb2msb

# XBAR -> DDR slave port: xbar_to_ddr_axi_*
# Current packed-crossbar DDR boundary: ddr_axi_* aliases of ddr_req/ddr_rsp.
# These are valid probe names; leave them commented until this ILA needs them.
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awaddr -msb 29 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_awlock
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awqos -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awregion -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_awvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_awready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_wdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_wstrb -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_wlast
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_wvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_wready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_bid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_bvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_bready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_araddr -msb 29 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_arlock
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arqos -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arregion -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_arvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_arready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_rid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_rdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_rlast
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_rvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_rready


# iDMA internal signals.
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/dma_irq_raw
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/idma_req_valid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/idma_req_ready
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/idma_rsp_valid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/idma_rsp_ready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/dbg_idma_req_src_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/dbg_idma_req_length -msb 31 -lsb 0 -order lsb2msb

# Exact VGA visible-pixel underrun and response FIFO occupancy.
ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_axi_vga.axi_vga_wrap_i/i_axi_vga/pixel_underrun
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_axi_vga.axi_vga_wrap_i/i_axi_vga/pixel_underrun_count_q -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/axi_vga_wrap_i/i_axi_vga/r_fifo_usage -msb auto -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/rst_ni
#ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/busy -msb 7 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/idma_req_valid
#ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/idma_req_ready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/dbg_idma_req_src_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/dbg_idma_req_dst_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/dbg_idma_req_length -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/idma_rsp_valid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/idma_rsp_ready
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc64_irq_pulse
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc64_irq_pending
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc64_i/input_addr -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc64_i/input_addr_valid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc64_i/input_addr_ready
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc64_i/dbg_desc_arvalid
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc64_i/dbg_desc_araddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc64_i/dbg_desc_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc_req_valid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.desc_req_ready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.dbg_desc_req_src_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.dbg_desc_req_dst_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/gen_desc64.dbg_desc_req_length -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/fe_arb_i/is_new_idma_req
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/gen_idma.idma_i/fe_arb_i/is_new_idma_rsp
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/gen_idma.idma_i/fe_arb_i/ongoing_req_cnt_q -msb 5 -lsb 0 -order lsb2msb

# DDR calibration
ila_add_probe u_ila_axi -net u_cvwsoc_ram/ddr_clk_locked
ila_add_probe u_ila_axi -net u_cvwsoc_ram/c0_init_calib_complete

## REMOVE THIS: CPU clock domain
# ila_add_probe u_ila_axi -bus cpu/wally/core/InstrM -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cpu/wally/core/PCM -msb auto -lsb 0 -order lsb2msb
##################################################################
##################################################################
##################################################################
# for extra debugging
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_arcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/BUS_axi_awcache -msb 3 -lsb 0 -order lsb2msb


#######################################################
# This is a GLOBAL setting (not ILA instance specific)
#connect_debug_port dbg_hub/clk [get_nets default_200mhz_clk_n]
connect_debug_port dbg_hub/clk [get_nets clk200]
