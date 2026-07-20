source ../constraints/debug-defs.xdc

#######################################################
# CPU side ILA
#######################################################


create_debug_core u_ila_spi ila

# ILA settings
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_spi]
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
#ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/InstrM -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net wallypipelinedsoc/core/TrapM
ila_add_probe u_ila_spi -net wallypipelinedsoc/core/InstrValidM
# connect_debug_port u_ila_spi/probe3 [get_nets [list {wallypipelinedsoc/core/InstrM[0]} {wallypipelinedsoc/core/InstrM[1]} {wallypipelinedsoc/core/InstrM[2]} {wallypipelinedsoc/core/InstrM[3]} {wallypipelinedsoc/core/InstrM[4]} {wallypipelinedsoc/core/InstrM[5]} {wallypipelinedsoc/core/InstrM[6]} {wallypipelinedsoc/core/InstrM[7]} {wallypipelinedsoc/core/InstrM[8]} {wallypipelinedsoc/core/InstrM[9]} {wallypipelinedsoc/core/InstrM[10]} {wallypipelinedsoc/core/InstrM[11]} {wallypipelinedsoc/core/InstrM[12]} {wallypipelinedsoc/core/InstrM[13]} {wallypipelinedsoc/core/InstrM[14]} {wallypipelinedsoc/core/InstrM[15]} {wallypipelinedsoc/core/InstrM[16]} {wallypipelinedsoc/core/InstrM[17]} {wallypipelinedsoc/core/InstrM[18]} {wallypipelinedsoc/core/InstrM[19]} {wallypipelinedsoc/core/InstrM[20]} {wallypipelinedsoc/core/InstrM[21]} {wallypipelinedsoc/core/InstrM[22]} {wallypipelinedsoc/core/InstrM[23]} {wallypipelinedsoc/core/InstrM[24]} {wallypipelinedsoc/core/InstrM[25]} {wallypipelinedsoc/core/InstrM[26]} {wallypipelinedsoc/core/InstrM[27]} {wallypipelinedsoc/core/InstrM[28]} {wallypipelinedsoc/core/InstrM[29]} {wallypipelinedsoc/core/InstrM[30]} {wallypipelinedsoc/core/InstrM[31]} ]]
ila_add_probe u_ila_spi -net wallypipelinedsoc/core/StallM
ila_add_probe u_ila_spi -net wallypipelinedsoc/core/FlushM

# AHB bus signals
#ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/ebu.ebu/HTRANS -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus HSIZE -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/HSIZE -msb 2 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/HWDATA -msb auto -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/HRDATA  -msb auto -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/lsu/LSUHWSTRB -msb auto -lsb 0 -order lsb2msb

ila_add_probe u_ila_spi -net HREADY
ila_add_probe u_ila_spi -net HWRITE
#ila_add_probe u_ila_spi -bus HTRANS -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus HADDR -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net HSELEXT
#ila_add_probe u_ila_spi -bus HRDATAEXT -msb auto -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus HPROT -msb 3 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus HPROT -msb 0 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus HTRANS -msb 1 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_spi -bus HBURST -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net HREADYEXT
ila_add_probe u_ila_spi -net HRESPEXT
# ila_add_probe u_ila_spi -net HMASTLOCK
#ila_add_probe u_ila_spi -bus HWSTRB -msb 7 -lsb 0 -order lsb2msb

# AHB-AXI bridge minimal signals
# AXI bridge output signals required by bridge_trace_analyzer
# ila_add_probe u_ila_spi -bus m_axi_awid    -msb 3  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_awaddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_awlen   -msb 7  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_awsize  -msb 2  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_awburst -msb 1  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_awlock
# ila_add_probe u_ila_spi -bus m_axi_awcache -msb 3  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_awprot  -msb 2  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_awvalid
# ila_add_probe u_ila_spi -net m_axi_awready

# ila_add_probe u_ila_spi -bus m_axi_wdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_wstrb -msb 7  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_wlast
# ila_add_probe u_ila_spi -net m_axi_wvalid
# ila_add_probe u_ila_spi -net m_axi_wready

# ila_add_probe u_ila_spi -bus m_axi_bid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_bvalid
# ila_add_probe u_ila_spi -net m_axi_bready

# ila_add_probe u_ila_spi -bus m_axi_arid    -msb 3  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_arlen   -msb 7  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_arsize  -msb 2  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_arburst -msb 1  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_arlock
# ila_add_probe u_ila_spi -bus m_axi_arcache -msb 3  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_arprot  -msb 2  -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_arvalid
# ila_add_probe u_ila_spi -net m_axi_arready

# ila_add_probe u_ila_spi -bus m_axi_rid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_rdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net m_axi_rlast
# ila_add_probe u_ila_spi -net m_axi_rvalid
# ila_add_probe u_ila_spi -net m_axi_rready

# ila_add_probe u_ila_spi -bus m_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus m_axi_rresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net peripheral_aresetn
#ila_add_probe u_ila_spi -net u_cvwsoc_axi/BUSCORERSTn


#######################################################
# This is a GLOBAL setting (not ILA instance specific)
#connect_debug_port dbg_hub/clk [get_nets default_200mhz_clk_n]
connect_debug_port dbg_hub/clk [get_nets clk200]
