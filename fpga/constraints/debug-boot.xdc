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
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCLK
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCIn
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCS[0]
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCmd
ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/CurrState  -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveFIFOReadInc

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
ila_add_probe u_ila_spi -bus HTRANS -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus HBURST -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -net HREADYEXT
ila_add_probe u_ila_spi -net HRESPEXT
ila_add_probe u_ila_spi -net HMASTLOCK
#ila_add_probe u_ila_spi -bus HWSTRB -msb 7 -lsb 0 -order lsb2msb


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
ila_add_probe u_ila_axi -bus   usb_m_axi_awid -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus  usb_m_axi_awaddr -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus   usb_m_axi_awlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus   usb_m_axi_awsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus   usb_m_axi_awburst -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net usb_m_axi_awlock
ila_add_probe u_ila_axi -bus   usb_m_axi_awcache  -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus   usb_m_axi_awprot  -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net usb_m_axi_awvalid
ila_add_probe u_ila_axi -net usb_m_axi_awready

ila_add_probe u_ila_axi -bus  usb_m_axi_wdata  -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus   usb_m_axi_wstrb  -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net usb_m_axi_wlast
ila_add_probe u_ila_axi -net usb_m_axi_wvalid
ila_add_probe u_ila_axi -net usb_m_axi_wready

ila_add_probe u_ila_axi -bus   usb_m_axi_bid  -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus   usb_m_axi_bresp  -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net usb_m_axi_bvalid
ila_add_probe u_ila_axi -net usb_m_axi_bready

ila_add_probe u_ila_axi -bus usb_m_axi_arid  -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus usb_m_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus usb_m_axi_arlen  -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus usb_m_axi_arsize  -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus usb_m_axi_arburst  -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net usb_m_axi_arlock
ila_add_probe u_ila_axi -bus usb_m_axi_arcache  -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus usb_m_axi_arprot  -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net usb_m_axi_arvalid
ila_add_probe u_ila_axi -net usb_m_axi_arready

ila_add_probe u_ila_axi -bus  usb_m_axi_rid  -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus usb_m_axi_rdata  -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus usb_m_axi_rresp  -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net usb_m_axi_rlast
ila_add_probe u_ila_axi -net usb_m_axi_rvalid
ila_add_probe u_ila_axi -net usb_m_axi_rready


# SDHCI probes
ila_add_probe u_ila_axi -net sd_clk_o
ila_add_probe u_ila_axi -net sd_cd_ni
ila_add_probe u_ila_axi -net sd_cmd_en
ila_add_probe u_ila_axi -net sd_cmd_o
ila_add_probe u_ila_axi -net sd_cmd_i
ila_add_probe u_ila_axi -net sd_dat_en
ila_add_probe u_ila_axi -bus sd_dat_o -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus sd_dat_i -msb 3 -lsb 0 -order lsb2msb

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
ila_add_probe u_ila_axi -bus m_axi_awaddr  -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus m_axi_awlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus m_axi_awsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus m_axi_awburst -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net m_axi_awvalid
ila_add_probe u_ila_axi -net m_axi_awready
ila_add_probe u_ila_axi -bus m_axi_wdata -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net m_axi_wvalid
ila_add_probe u_ila_axi -net m_axi_wready
ila_add_probe u_ila_axi -net m_axi_wlast
ila_add_probe u_ila_axi -net m_axi_bvalid
ila_add_probe u_ila_axi -net m_axi_bready
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
