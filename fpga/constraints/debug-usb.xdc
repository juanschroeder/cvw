# source helper functions
source ../constraints/debug-defs.xdc

###################################################################################33
#### AXI ILA PROBES
###################################################################################33
create_debug_core u_ila_usb ila

# ILA settings
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_usb]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_usb]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_usb]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_usb]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_usb]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_usb]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_usb]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_usb]
# startgroup
# set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0 ]
# set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0 ]
# set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0 ]
# set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0 ]
# endgroup
# Test change (ChatGPT)
set_property port_width 1 [get_debug_ports u_ila_usb/clk]
# changed for sampling AXI STUFF!!

connect_debug_port u_ila_usb/clk [get_nets BUSCLK]


# ila_add_probe u_ila_usb -net usb0_dp_IBUF
# ila_add_probe u_ila_usb -net usb0_dm_IBUF
# ila_add_probe u_ila_usb -net usb1_dp_IBUF
# ila_add_probe u_ila_usb -net usb1_dm_IBUF
# ila_add_probe u_ila_usb -net usb0_dp_TRI
# ila_add_probe u_ila_usb -net usb0_dm_TRI
# ila_add_probe u_ila_usb -net usb1_dp_TRI
# ila_add_probe u_ila_usb -net usb1_dm_TRI

ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/u_ohci/back_native_0_dp_writeEnable_delay_1
#ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/u_ohci/back_native_0_dp_write
#ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/u_ohci/back_native_0_dm_write
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/u_ohci/back_native_1_dp_writeEnable_delay_1
#ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/u_ohci/back_native_1_dp_write
#ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/u_ohci/back_native_1_dm_write

# NEW STUFF TO ADD (??)
# ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb0_dp_read
# ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb0_dm_read
# ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb1_dp_read
# ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb1_dm_read

ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb0_dp_oe
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb0_dm_oe
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb1_dp_oe
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb1_dm_oe
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb0_dp_read
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb0_dm_read
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb1_dp_read
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb1_dm_read
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb0_dp_write
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb0_dm_write
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb1_dp_write
ila_add_probe u_ila_usb -net gen_axi_usb.usb_ohci_i/usb1_dm_write
##########################################################3

# This is a GLOBAL setting (not ILA instance specific)
# # the debug hub has issues with the clocks from the mmcm so lets give up an connect to the 100Mhz input clock.
# connect_debug_port dbg_hub/clk [get_nets default_100mhz_clk]
# #connect_debug_port dbg_hub/clk [get_nets CPUCLK]
connect_debug_port dbg_hub/clk [get_nets default_100mhz_clk]
