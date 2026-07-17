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
#connect_debug_port u_ila_spi/probe0 [get_nets [list {wallypipelinedsoc/core/PCM[0]} {wallypipelinedsoc/core/PCM[1]} {wallypipelinedsoc/core/PCM[2]} {wallypipelinedsoc/core/PCM[3]} {wallypipelinedsoc/core/PCM[4]} {wallypipelinedsoc/core/PCM[5]} {wallypipelinedsoc/core/PCM[6]} {wallypipelinedsoc/core/PCM[7]} {wallypipelinedsoc/core/PCM[8]} {wallypipelinedsoc/core/PCM[9]} {wallypipelinedsoc/core/PCM[10]} {wallypipelinedsoc/core/PCM[11]} {wallypipelinedsoc/core/PCM[12]} {wallypipelinedsoc/core/PCM[13]} {wallypipelinedsoc/core/PCM[14]} {wallypipelinedsoc/core/PCM[15]} {wallypipelinedsoc/core/PCM[16]} {wallypipelinedsoc/core/PCM[17]} {wallypipelinedsoc/core/PCM[18]} {wallypipelinedsoc/core/PCM[19]} {wallypipelinedsoc/core/PCM[20]} {wallypipelinedsoc/core/PCM[21]} {wallypipelinedsoc/core/PCM[22]} {wallypipelinedsoc/core/PCM[23]} {wallypipelinedsoc/core/PCM[24]} {wallypipelinedsoc/core/PCM[25]} {wallypipelinedsoc/core/PCM[26]} {wallypipelinedsoc/core/PCM[27]} {wallypipelinedsoc/core/PCM[28]} {wallypipelinedsoc/core/PCM[29]} {wallypipelinedsoc/core/PCM[30]} {wallypipelinedsoc/core/PCM[31]} {wallypipelinedsoc/core/PCM[32]} {wallypipelinedsoc/core/PCM[33]} {wallypipelinedsoc/core/PCM[34]} {wallypipelinedsoc/core/PCM[35]} {wallypipelinedsoc/core/PCM[36]} {wallypipelinedsoc/core/PCM[37]} {wallypipelinedsoc/core/PCM[38]} {wallypipelinedsoc/core/PCM[39]} {wallypipelinedsoc/core/PCM[40]} {wallypipelinedsoc/core/PCM[41]} {wallypipelinedsoc/core/PCM[42]} {wallypipelinedsoc/core/PCM[43]} {wallypipelinedsoc/core/PCM[44]} {wallypipelinedsoc/core/PCM[45]} {wallypipelinedsoc/core/PCM[46]} {wallypipelinedsoc/core/PCM[47]} {wallypipelinedsoc/core/PCM[48]} {wallypipelinedsoc/core/PCM[49]} {wallypipelinedsoc/core/PCM[50]} {wallypipelinedsoc/core/PCM[51]} {wallypipelinedsoc/core/PCM[52]} {wallypipelinedsoc/core/PCM[53]} {wallypipelinedsoc/core/PCM[54]} {wallypipelinedsoc/core/PCM[55]} {wallypipelinedsoc/core/PCM[56]} {wallypipelinedsoc/core/PCM[57]} {wallypipelinedsoc/core/PCM[58]} {wallypipelinedsoc/core/PCM[59]} {wallypipelinedsoc/core/PCM[60]} {wallypipelinedsoc/core/PCM[61]} {wallypipelinedsoc/core/PCM[62]} {wallypipelinedsoc/core/PCM[63]} ]]
ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/PCM -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/InstrM -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net wallypipelinedsoc/core/TrapM
ila_add_probe u_ila_spi -net wallypipelinedsoc/core/InstrValidM
# connect_debug_port u_ila_spi/probe3 [get_nets [list {wallypipelinedsoc/core/InstrM[0]} {wallypipelinedsoc/core/InstrM[1]} {wallypipelinedsoc/core/InstrM[2]} {wallypipelinedsoc/core/InstrM[3]} {wallypipelinedsoc/core/InstrM[4]} {wallypipelinedsoc/core/InstrM[5]} {wallypipelinedsoc/core/InstrM[6]} {wallypipelinedsoc/core/InstrM[7]} {wallypipelinedsoc/core/InstrM[8]} {wallypipelinedsoc/core/InstrM[9]} {wallypipelinedsoc/core/InstrM[10]} {wallypipelinedsoc/core/InstrM[11]} {wallypipelinedsoc/core/InstrM[12]} {wallypipelinedsoc/core/InstrM[13]} {wallypipelinedsoc/core/InstrM[14]} {wallypipelinedsoc/core/InstrM[15]} {wallypipelinedsoc/core/InstrM[16]} {wallypipelinedsoc/core/InstrM[17]} {wallypipelinedsoc/core/InstrM[18]} {wallypipelinedsoc/core/InstrM[19]} {wallypipelinedsoc/core/InstrM[20]} {wallypipelinedsoc/core/InstrM[21]} {wallypipelinedsoc/core/InstrM[22]} {wallypipelinedsoc/core/InstrM[23]} {wallypipelinedsoc/core/InstrM[24]} {wallypipelinedsoc/core/InstrM[25]} {wallypipelinedsoc/core/InstrM[26]} {wallypipelinedsoc/core/InstrM[27]} {wallypipelinedsoc/core/InstrM[28]} {wallypipelinedsoc/core/InstrM[29]} {wallypipelinedsoc/core/InstrM[30]} {wallypipelinedsoc/core/InstrM[31]} ]]
ila_add_probe u_ila_spi -net wallypipelinedsoc/core/StallM
ila_add_probe u_ila_spi -net wallypipelinedsoc/core/FlushM
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/RdE -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/RdM -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/ieu/RdW -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net wallypipelinedsoc/core/ieu/RegWriteW
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/ieu/dp/ResultW  -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net wallypipelinedsoc/core/ieu/dp/regf/we3
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/ieu/dp/regf/a3 -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/ieu/dp/regf/wd3 -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/lsu/IEUAdrM -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/WriteDataM -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/MemRWM  -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/lsu/ReadDataM  -msb 63 -lsb 0 -order lsb2msb

# SD card (SPI bus) signals
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCLK
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCIn
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCS[0]
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCmd
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/CurrState  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveFIFOReadInc

# AHB bus signals
#ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/ebu.ebu/HTRANS -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus HSIZE -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/HSIZE -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/HWDATA -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/HRDATA  -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/lsu/LSUHWSTRB -msb auto -lsb 0 -order lsb2msb

ila_add_probe u_ila_spi -net HREADY
ila_add_probe u_ila_spi -net HWRITE
ila_add_probe u_ila_spi -bus HTRANS -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus HADDR -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net HSELEXT
ila_add_probe u_ila_spi -bus HRDATAEXT -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus HPROT -msb 3 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus HPROT -msb 0 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus HTRANS -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus HBURST -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net HREADYEXT
ila_add_probe u_ila_spi -net HRESPEXT
# ila_add_probe u_ila_spi -net HMASTLOCK
#ila_add_probe u_ila_spi -bus HWSTRB -msb 7 -lsb 0 -order lsb2msb

# AHB-AXI bridge minimal signals
# AXI bridge output signals required by bridge_trace_analyzer
# ila_add_probe u_ila_spi -bus m_axi_awid    -msb 3  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus m_axi_awaddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_awlen   -msb 7  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_awsize  -msb 2  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_awburst -msb 1  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_awlock
# ila_add_probe u_ila_spi -bus m_axi_awcache -msb 3  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_awprot  -msb 2  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net m_axi_awvalid
ila_add_probe u_ila_spi -net m_axi_awready

# ila_add_probe u_ila_spi -bus m_axi_wdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_wstrb -msb 7  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net m_axi_wlast
ila_add_probe u_ila_spi -net m_axi_wvalid
ila_add_probe u_ila_spi -net m_axi_wready

ila_add_probe u_ila_spi -bus m_axi_bid -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net m_axi_bvalid
ila_add_probe u_ila_spi -net m_axi_bready

ila_add_probe u_ila_spi -bus m_axi_arid    -msb 3  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus m_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_arlen   -msb 7  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_arsize  -msb 2  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_arburst -msb 1  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_arlock
# ila_add_probe u_ila_spi -bus m_axi_arcache -msb 3  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_arprot  -msb 2  -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net m_axi_arvalid
ila_add_probe u_ila_spi -net m_axi_arready

# ila_add_probe u_ila_spi -bus m_axi_rid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_rdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_rlast
ila_add_probe u_ila_spi -net m_axi_rvalid
ila_add_probe u_ila_spi -net m_axi_rready

ila_add_probe u_ila_spi -bus m_axi_bresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus m_axi_rresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net peripheral_aresetn
#ila_add_probe u_ila_spi -net BUSCORERSTn

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
connect_debug_port u_ila_axi/clk [get_nets BUSCLK]


# USB
# ila_add_probe u_ila_axi -bus   usb_m_axi_awid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus  usb_m_axi_awaddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   usb_m_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   usb_m_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   usb_m_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net usb_m_axi_awlock
# ila_add_probe u_ila_axi -bus   usb_m_axi_awcache  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   usb_m_axi_awprot  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net usb_m_axi_awvalid
# ila_add_probe u_ila_axi -net usb_m_axi_awready

# ila_add_probe u_ila_axi -bus  usb_m_axi_wdata  -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   usb_m_axi_wstrb  -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net usb_m_axi_wlast
# ila_add_probe u_ila_axi -net usb_m_axi_wvalid
# ila_add_probe u_ila_axi -net usb_m_axi_wready

# ila_add_probe u_ila_axi -bus   usb_m_axi_bid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus   usb_m_axi_bresp  -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net usb_m_axi_bvalid
# ila_add_probe u_ila_axi -net usb_m_axi_bready

# ila_add_probe u_ila_axi -bus usb_m_axi_arid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus usb_m_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus usb_m_axi_arlen  -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus usb_m_axi_arsize  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus usb_m_axi_arburst  -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net usb_m_axi_arlock
# ila_add_probe u_ila_axi -bus usb_m_axi_arcache  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus usb_m_axi_arprot  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net usb_m_axi_arvalid
# ila_add_probe u_ila_axi -net usb_m_axi_arready

# ila_add_probe u_ila_axi -bus  usb_m_axi_rid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus usb_m_axi_rdata  -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus usb_m_axi_rresp  -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net usb_m_axi_rlast
# ila_add_probe u_ila_axi -net usb_m_axi_rvalid
# ila_add_probe u_ila_axi -net usb_m_axi_rready


# SDHCI probes
# ila_add_probe u_ila_axi -net sd_clk_o
# ila_add_probe u_ila_axi -net sd_cd_ni
# ila_add_probe u_ila_axi -net sd_cmd_en
# ila_add_probe u_ila_axi -net sd_cmd_o
# ila_add_probe u_ila_axi -net sd_cmd_i
# ila_add_probe u_ila_axi -net sd_dat_en
# ila_add_probe u_ila_axi -bus sd_dat_o -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus sd_dat_i -msb 3 -lsb 0 -order lsb2msb

# # SDHCI debug taps: command path
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_current_cmd -msb 5 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_current_arg -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_started
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_data_present
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_xfer_dir
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_needs_busy
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_sd_cmd_done
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_sd_rsp_done

# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_result_valid
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_timeout_error
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_crc_error
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_index_error
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_end_bit_error

# # SDHCI debug taps: mode / register-derived state
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_bus_width_4
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_block_size -msb 9 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_block_count -msb 15 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_read_transfer_active
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_write_transfer_active
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_buffer_read_enable
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_buffer_write_enable
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_pause_sd_clk

# # SDHCI debug taps: data FSM
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_dat_state -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_read_state -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_write_state -msb 2 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_start_read
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_read_valid
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_read_done
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_read_crc_err
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_read_end_bit_err
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_timeout_elapsed

# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_buffer_write_valid
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_buffer_write_ready
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_buffer_write_data -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_buffer_read_valid
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_buffer_read_ready
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_buffer_read_data -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_buffer_empty

# # SDHCI debug taps: dat_buffer / SRAM shift register
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_reg_push
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_reg_push_data -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_reg_pop
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_reg_pop_data -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_reg_empty
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_reg_length -msb 8 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_has_block
# # Newer SDHCI RTL no longer has the source signal for this debug tap.
# # ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_has_space
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_current_word_counter -msb 9 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_sram_en
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_sram_pop_front_i
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_sram_pop_front_q
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_sram_push_back_i
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_sram_back_data_i -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_sram_front_data_o -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_sram_empty_o
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_sram_length_o -msb 8 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_cmd_state -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_cmd_cycles_waiting -msb 6 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_accepted_rsp_type -msb 1 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_rsp_rx_state -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_rsp_bit_cnt -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp_long
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp_receiving
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp_start_bit_observed
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp_all_bits_received
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp_capture_bit
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp_capture_word_bit
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp_crc_start
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp_crc_end_output
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_rsp_crc7_calc -msb 6 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp_crc_corr
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_rsp0 -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_rsp1 -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_rsp2 -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_rsp3 -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp0_de
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp1_de
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp2_de
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_rsp3_de

# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_cmd_resp_shift -msb 159 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_axi_sdhci.dbg_sdhci_cmd_resp_shift_count -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_cmd_resp_shift_active
# ila_add_probe u_ila_axi -net gen_axi_sdhci.dbg_sdhci_sd_clk_en_p

# AXI side of AHB-AXI bridge
# REMARK: This is wrong here, it's different clock domain. Yet, it works.
# ila_add_probe u_ila_axi -bus m_axi_awaddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus m_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus m_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus m_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net m_axi_awvalid
# ila_add_probe u_ila_axi -net m_axi_awready
# ila_add_probe u_ila_axi -bus m_axi_wdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net m_axi_wvalid
# ila_add_probe u_ila_axi -net m_axi_wready
# ila_add_probe u_ila_axi -net m_axi_wlast
# ila_add_probe u_ila_axi -net m_axi_bvalid
# ila_add_probe u_ila_axi -net m_axi_bready
# #ila_add_probe u_ila_axi -bus m_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus m_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus m_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus m_axi_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus m_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net m_axi_arvalid
# ila_add_probe u_ila_axi -net m_axi_arready
# ila_add_probe u_ila_axi -bus m_axi_rdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net m_axi_rvalid
# ila_add_probe u_ila_axi -net m_axi_rready
# ila_add_probe u_ila_axi -bus m_axi_rdata -msb 63 -lsb 0 -order lsb2msb



# between CDC and crossbar
ila_add_probe u_ila_axi -bus BUS_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus BUS_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# some bits are optimized away?
# ila_add_probe u_ila_axi -bus BUS_axi_arlen -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_arvalid
# ila_add_probe u_ila_axi -net BUS_axi_arready
# ila_add_probe u_ila_axi -bus BUS_axi_arid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_rvalid
# ila_add_probe u_ila_axi -net BUS_axi_rready
# ila_add_probe u_ila_axi -bus BUS_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_rlast
# ila_add_probe u_ila_axi -bus BUS_axi_rdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_rid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awaddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_awvalid
# ila_add_probe u_ila_axi -net BUS_axi_awready
# ila_add_probe u_ila_axi -bus BUS_axi_wdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_wstrb -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_wvalid
# ila_add_probe u_ila_axi -net BUS_axi_wready
# ila_add_probe u_ila_axi -net BUS_axi_wlast
# ila_add_probe u_ila_axi -bus BUS_axi_bid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_bvalid
# ila_add_probe u_ila_axi -net BUS_axi_bready


# crossbar side to DDR
# these ones repeat the DDR3 ones below
# ila_add_probe u_ila_axi -bus BUS_cb_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_arvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_arready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_rvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_rready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_rlast
# ila_add_probe u_ila_axi -bus BUS_cb_axi_rdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_rid -msb 3 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -net BUS_cb_axi_awvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_awready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awaddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_wvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_wready
# ila_add_probe u_ila_axi -net BUS_cb_axi_wlast
# ila_add_probe u_ila_axi -bus BUS_cb_axi_wdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_bvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_bready




# ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_bready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_bid -msb 3 -lsb 0 -order lsb2msb

# CPU CDC output -> XBAR CPU-master input: cpu_cdc_to_xbar_axi_*
# ila_add_probe u_ila_axi -bus BUS_axi_awid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awaddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_awlock
# ila_add_probe u_ila_axi -bus BUS_axi_awcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awqos -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awregion -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_awvalid
# ila_add_probe u_ila_axi -net BUS_axi_awready
# ila_add_probe u_ila_axi -bus BUS_axi_wdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_wstrb -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_wlast
# ila_add_probe u_ila_axi -net BUS_axi_wvalid
# ila_add_probe u_ila_axi -net BUS_axi_wready
# ila_add_probe u_ila_axi -bus BUS_axi_bid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_bvalid
# ila_add_probe u_ila_axi -net BUS_axi_bready
# ila_add_probe u_ila_axi -bus BUS_axi_arid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_araddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_arlock
# ila_add_probe u_ila_axi -bus BUS_axi_arcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_arprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_arqos -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_arregion -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_arvalid
# ila_add_probe u_ila_axi -net BUS_axi_arready
# ila_add_probe u_ila_axi -bus BUS_axi_rid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_rdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_axi_rlast
# ila_add_probe u_ila_axi -net BUS_axi_rvalid
# ila_add_probe u_ila_axi -net BUS_axi_rready
#ila_add_probe u_ila_axi -net BUSCORERSTn

# XBAR -> iDMA register-slave port at 0x10080000: xbar_to_idma_cfg_axi_*
# Packed crossbar M07 == CB_M_IDMA_DESC.
# ila_add_probe u_ila_axi -bus cb_m_axi_awid -msb 39 -lsb 35 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awaddr -msb 255 -lsb 224 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awlen -msb 63 -lsb 56 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awsize -msb 23 -lsb 21 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awburst -msb 15 -lsb 14 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awlock -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awcache -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awprot -msb 23 -lsb 21 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awqos -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awregion -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_awready -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_wdata -msb 511 -lsb 448 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_wstrb -msb 63 -lsb 56 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_wlast -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_wvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_wready -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_bid -msb 39 -lsb 35 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_bresp -msb 15 -lsb 14 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_bvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_bready -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arid -msb 39 -lsb 35 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_araddr -msb 255 -lsb 224 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arlen -msb 63 -lsb 56 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arsize -msb 23 -lsb 21 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arburst -msb 15 -lsb 14 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arlock -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arcache -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arprot -msb 23 -lsb 21 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arqos -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arregion -msb 31 -lsb 28 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arready -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_rid -msb 39 -lsb 35 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_rdata -msb 511 -lsb 448 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_rresp -msb 15 -lsb 14 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_rlast -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_rvalid -msb 7 -lsb 7 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_rready -msb 7 -lsb 7 -order lsb2msb

# iDMA master -> XBAR master-input port: idma_m_axi_* descriptor fetch.
# Packed crossbar S04 == CB_S_IDMA_FE, iDMA descriptor frontend AXI master.
# ila_add_probe u_ila_axi -bus cb_s_axi_awid -msb 24 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awaddr -msb 159 -lsb 128 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awlen -msb 39 -lsb 32 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awsize -msb 14 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awburst -msb 9 -lsb 8 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awlock -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awcache -msb 19 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awprot -msb 14 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awqos -msb 19 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awready -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wdata -msb 319 -lsb 256 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wstrb -msb 39 -lsb 32 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wlast -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wready -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_bid -msb 24 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_bresp -msb 9 -lsb 8 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_bvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_bready -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arid -msb 24 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_araddr -msb 159 -lsb 128 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arlen -msb 39 -lsb 32 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arsize -msb 14 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arburst -msb 9 -lsb 8 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arlock -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arcache -msb 19 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arprot -msb 14 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arqos -msb 19 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arready -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rid -msb 24 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rdata -msb 319 -lsb 256 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rresp -msb 9 -lsb 8 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rlast -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rvalid -msb 4 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rready -msb 4 -lsb 4 -order lsb2msb

# AXI->AXIS desc64 descriptor-fetch frontend.
# Packed crossbar S05 == CB_S_IDMA_FE_AXIS.
# ila_add_probe u_ila_axi -bus cb_s_axi_awid -msb 29 -lsb 25 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awaddr -msb 191 -lsb 160 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awlen -msb 47 -lsb 40 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awsize -msb 17 -lsb 15 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awburst -msb 11 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awlock -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awcache -msb 23 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awprot -msb 17 -lsb 15 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awqos -msb 23 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_awready -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wdata -msb 383 -lsb 320 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wstrb -msb 47 -lsb 40 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wlast -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_wready -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_bid -msb 29 -lsb 25 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_bresp -msb 11 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_bvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_bready -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arid -msb 29 -lsb 25 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_araddr -msb 191 -lsb 160 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arlen -msb 47 -lsb 40 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arsize -msb 17 -lsb 15 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arburst -msb 11 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arlock -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arcache -msb 23 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arprot -msb 17 -lsb 15 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arqos -msb 23 -lsb 20 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arready -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rid -msb 29 -lsb 25 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rdata -msb 383 -lsb 320 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rresp -msb 11 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rlast -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rvalid -msb 5 -lsb 5 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rready -msb 5 -lsb 5 -order lsb2msb

# VGA framebuffer scanout master read path.
# Packed crossbar S02 == CB_S_VGA.
# ila_add_probe u_ila_axi -bus cb_s_axi_arid -msb 14 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_araddr -msb 95 -lsb 64 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arlen -msb 23 -lsb 16 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arsize -msb 8 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arburst -msb 5 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arvalid -msb 2 -lsb 2 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arready -msb 2 -lsb 2 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rid -msb 14 -lsb 10 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rresp -msb 5 -lsb 4 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rlast -msb 2 -lsb 2 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rvalid -msb 2 -lsb 2 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rready -msb 2 -lsb 2 -order lsb2msb

# Shared iDMA backend payload-data read path.
# Packed crossbar S06 == CB_S_IDMA_BE.
# ila_add_probe u_ila_axi -bus cb_s_axi_arid -msb 34 -lsb 30 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_araddr -msb 223 -lsb 192 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arlen -msb 55 -lsb 48 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arsize -msb 20 -lsb 18 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arburst -msb 13 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arvalid -msb 6 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_arready -msb 6 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rid -msb 34 -lsb 30 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rresp -msb 13 -lsb 12 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rlast -msb 6 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rvalid -msb 6 -lsb 6 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_s_axi_rready -msb 6 -lsb 6 -order lsb2msb

# XBAR -> DDR slave port: xbar_to_ddr_axi_*
# Use the named DDR/MIG-facing slice of packed crossbar M00.
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awaddr -msb 29 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_awlock
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awqos -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awregion -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_awvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_awready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_wdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_wstrb -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_wlast
# ila_add_probe u_ila_axi -net BUS_cb_axi_wvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_wready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_bid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_bvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_bready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_araddr -msb 29 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_arlock
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arqos -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arregion -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_arvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_arready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_rid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_rdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_rlast
# ila_add_probe u_ila_axi -net BUS_cb_axi_rvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_rready


# iDMA internal signals.
# ila_add_probe u_ila_axi -net dma_irq_raw
# ila_add_probe u_ila_axi -net gen_idma.idma_i/idma_req_valid
# ila_add_probe u_ila_axi -net gen_idma.idma_i/idma_req_ready
# ila_add_probe u_ila_axi -net gen_idma.idma_i/idma_rsp_valid
# ila_add_probe u_ila_axi -net gen_idma.idma_i/idma_rsp_ready
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/dbg_idma_req_src_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/dbg_idma_req_length -msb 31 -lsb 0 -order lsb2msb

# Exact VGA visible-pixel underrun and response FIFO occupancy.
ila_add_probe u_ila_axi -net gen_axi_vga.axi_vga_wrap_i/i_axi_vga/pixel_underrun
ila_add_probe u_ila_axi -bus gen_axi_vga.axi_vga_wrap_i/i_axi_vga/pixel_underrun_count_q -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus axi_vga_wrap_i/i_axi_vga/r_fifo_usage -msb auto -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -net gen_idma.idma_i/rst_ni
#ila_add_probe u_ila_axi -bus gen_idma.idma_i/busy -msb 7 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -net gen_idma.idma_i/idma_req_valid
#ila_add_probe u_ila_axi -net gen_idma.idma_i/idma_req_ready
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/dbg_idma_req_src_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/dbg_idma_req_dst_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/dbg_idma_req_length -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_idma.idma_i/idma_rsp_valid
# ila_add_probe u_ila_axi -net gen_idma.idma_i/idma_rsp_ready
# ila_add_probe u_ila_axi -net gen_idma.idma_i/gen_desc64.desc64_irq_pulse
# ila_add_probe u_ila_axi -net gen_idma.idma_i/gen_desc64.desc64_irq_pending
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/gen_desc64.desc64_i/input_addr -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_idma.idma_i/gen_desc64.desc64_i/input_addr_valid
# ila_add_probe u_ila_axi -net gen_idma.idma_i/gen_desc64.desc64_i/input_addr_ready
# ila_add_probe u_ila_axi -net gen_idma.idma_i/gen_desc64.desc64_i/dbg_desc_arvalid
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/gen_desc64.desc64_i/dbg_desc_araddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/gen_desc64.desc64_i/dbg_desc_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_idma.idma_i/gen_desc64.desc_req_valid
# ila_add_probe u_ila_axi -net gen_idma.idma_i/gen_desc64.desc_req_ready
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/gen_desc64.dbg_desc_req_src_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/gen_desc64.dbg_desc_req_dst_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/gen_desc64.dbg_desc_req_length -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net gen_idma.idma_i/fe_arb_i/is_new_idma_req
# ila_add_probe u_ila_axi -net gen_idma.idma_i/fe_arb_i/is_new_idma_rsp
# ila_add_probe u_ila_axi -bus gen_idma.idma_i/fe_arb_i/ongoing_req_cnt_q -msb 5 -lsb 0 -order lsb2msb

# DDR calibration
ila_add_probe u_ila_axi -net mmcm_locked
ila_add_probe u_ila_axi -net c0_init_calib_complete

## REMOVE THIS: CPU clock domain
# ila_add_probe u_ila_axi -bus wallypipelinedsoc/core/InstrM -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus wallypipelinedsoc/core/PCM -msb auto -lsb 0 -order lsb2msb
##################################################################
##################################################################
##################################################################
# for extra debugging
# ila_add_probe u_ila_axi -bus BUS_axi_arprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_arcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_axi_awcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awprot -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arcache -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awcache -msb 3 -lsb 0 -order lsb2msb


#######################################################
# This is a GLOBAL setting (not ILA instance specific)
#connect_debug_port dbg_hub/clk [get_nets default_200mhz_clk_n]
connect_debug_port dbg_hub/clk [get_nets clk200]
