#set_multicycle_path -from [get_pins xlnx_ddr3_c0/u_xlnx_ddr3_mig/u_memc_ui_top_axi/mem_intfc0/ddr_phy_top0/u_ddr_calib_top/init_calib_complete_reg/C] -to [get_pins xlnx_proc_sys_reset_0/U0/EXT_LPF/lpf_int_reg/D] 10
# Only for MIG, not for LiteDRAM
set_max_delay -datapath_only -from [get_pins xlnx_ddr3_c0/u_xlnx_ddr3_mig/u_memc_ui_top_axi/mem_intfc0/ddr_phy_top0/u_ddr_calib_top/init_calib_complete_reg/C] -to [get_pins xlnx_proc_sys_reset_0/U0/EXT_LPF/lpf_int_reg/D] 20.000
