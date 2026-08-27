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
ila_add_probe u_ila_spi -bus cpu/PCM -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/InstrM -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net cpu/TrapM
ila_add_probe u_ila_spi -net cpu/InstrValidM
ila_add_probe u_ila_spi -net cpu/StallM
ila_add_probe u_ila_spi -net cpu/FlushM

# AHB bus signals
ila_add_probe u_ila_spi -bus cpu/HSIZE -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/HWDATA -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/HRDATAEXT -msb auto -lsb 0 -order lsb2msb

ila_add_probe u_ila_spi -net cpu/HREADY
ila_add_probe u_ila_spi -net cpu/HWRITE
ila_add_probe u_ila_spi -bus cpu/HTRANS -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/HADDR -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net cpu/HSELEXT
ila_add_probe u_ila_spi -bus cpu/HPROT -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus cpu/HBURST -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net cpu/HREADYEXT
ila_add_probe u_ila_spi -net cpu/HRESPEXT
# ila_add_probe u_ila_spi -net HMASTLOCK
#ila_add_probe u_ila_spi -bus HWSTRB -msb 7 -lsb 0 -order lsb2msb

# Additional CPU-to-AXI probes live under cpu/m_axi_* after the CVWSOC split.
# Keep this boot ILA small; use debug-boot-cvwsoc.xdc for the full AXI capture.
ila_add_probe u_ila_spi -net peripheral_aresetn
#ila_add_probe u_ila_spi -net u_cvwsoc_axi/BUSCORERSTn


#######################################################
# This is a GLOBAL setting (not ILA instance specific)
#connect_debug_port dbg_hub/clk [get_nets default_200mhz_clk_n]
connect_debug_port dbg_hub/clk [get_nets clk200]
