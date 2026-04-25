

ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_arvalid
ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_arready
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_araddr -msb 29 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_arid -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_arlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_arsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_arburst -msb 1 -lsb 0 -order lsb2msb
# R channel
ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_rvalid
ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_rready
# Check: is this one optimized?
# ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_rresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus BUS_cb_axi_rresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_rlast
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_rdata -msb 63 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_rid -msb 3 -lsb 0 -order lsb2msb
# AW channel
ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_awvalid
ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_awready
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_awaddr -msb 29 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_awid -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_awid -msb 3 -lsb 2 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_awlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_awsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_awburst -msb 1 -lsb 0 -order lsb2msb

# W channel
#ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_wvalid
ila_add_probe u_ila_axi -net ddr3/main_w_valid
#ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_wready
ila_add_probe u_ila_axi -net ddr3/main_w_ready
#ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_wlast
ila_add_probe u_ila_axi -net ddr3/main_w_last
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_wstrb -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/user_port_axi_0_wdata -msb 63 -lsb 0 -order lsb2msb

#ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_bvalid
ila_add_probe u_ila_axi -net ddr3/main_b_valid
ila_add_probe u_ila_axi -net ddr3/main_b_ready
ila_add_probe u_ila_axi -bus ddr3/main_b_param_id  -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/main_b_payload_resp  -msb 1 -lsb 0 -order lsb2msb

################################
# THIS IS FOR LITEDRAM
################################

ila_add_probe u_ila_axi -net ddr3/main_write_w_buffer_source_valid
ila_add_probe u_ila_axi -net ddr3/main_write_w_buffer_source_ready
ila_add_probe u_ila_axi -net ddr3/main_write_w_buffer_source_last
ila_add_probe u_ila_axi -bus ddr3/main_write_w_buffer_source_payload_data  -msb 63 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/main_write_w_buffer_source_payload_strb -msb 7 -lsb 0 -order lsb2msb

ila_add_probe u_ila_axi -net ddr3/main_write_id_buffer_source_valid
ila_add_probe u_ila_axi -net ddr3/main_write_id_buffer_source_ready
ila_add_probe u_ila_axi -bus ddr3/main_write_id_buffer_source_payload_id -msb 3 -lsb 0 -order lsb2msb

ila_add_probe u_ila_axi -net ddr3/main_write_resp_buffer_sink_valid
ila_add_probe u_ila_axi -bus ddr3/main_write_resp_buffer_sink_payload_id -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/main_write_resp_buffer_sink_payload_resp -msb 1 -lsb 0 -order lsb2msb

ila_add_probe u_ila_axi -net ddr3/main_write_resp_buffer_source_valid
ila_add_probe u_ila_axi -net ddr3/main_write_resp_buffer_source_ready
ila_add_probe u_ila_axi -bus ddr3/main_write_resp_buffer_source_payload_id -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/main_write_resp_buffer_source_payload_resp -msb 1 -lsb 0 -order lsb2msb

ila_add_probe u_ila_axi -net ddr3/main_new_port_wdata_valid
ila_add_probe u_ila_axi -net ddr3/main_new_port_wdata_ready
#ila_add_probe u_ila_axi -net ddr3/main_new_port_wdata_last

ila_add_probe u_ila_axi -net ddr3/main_new_port_cmd_valid
ila_add_probe u_ila_axi -net ddr3/main_new_port_cmd_ready
ila_add_probe u_ila_axi -net ddr3/main_new_port_cmd_payload_we
ila_add_probe u_ila_axi -net ddr3/main_new_port_cmd_last
ila_add_probe u_ila_axi -bus ddr3/main_new_port_cmd_payload_addr  -msb 26 -lsb 0 -order lsb2msb

ila_add_probe u_ila_axi -net ddr3/main_port_cmd_valid
ila_add_probe u_ila_axi -net ddr3/main_port_cmd_ready
ila_add_probe u_ila_axi -net ddr3/main_port_cmd_payload_we
#ila_add_probe u_ila_axi -bus ddr3/main_port_cmd_payload_addr  -msb 26 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/main_port_cmd_payload_addr  -msb 24 -lsb 0 -order lsb2msb

ila_add_probe u_ila_axi -net ddr3/main_port_wdata_valid
ila_add_probe u_ila_axi -net ddr3/main_port_wdata_ready
ila_add_probe u_ila_axi -net ddr3/main_port_wdata_last


ila_add_probe u_ila_axi -net ddr3/main_w_last
ila_add_probe u_ila_axi -net ddr3/main_write_w_buffer_sink_valid
ila_add_probe u_ila_axi -net ddr3/main_write_w_buffer_sink_ready
ila_add_probe u_ila_axi -net ddr3/main_write_w_buffer_sink_last
ila_add_probe u_ila_axi -net ddr3/main_write_w_buffer_wrport_we
ila_add_probe u_ila_axi -net ddr3/main_write_w_buffer_fifo_in_last


ila_add_probe u_ila_axi -bus ddr3/main_write_beat_count  -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net ddr3/main_write_aw_last

#   user side reset / enable                user_rst
#                                           init_done
#                                           init_error
#                                           pll_locked
#                                           main_user_enable
ila_add_probe u_ila_axi -net init_error
ila_add_probe u_ila_axi -net ddr3/user_rst
ila_add_probe u_ila_axi -net ddr3/main_user_enable
################################
# UpConverter FSM & internals
ila_add_probe u_ila_axi -bus ddr3/builder_litedramcore_state -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/main_litedramnativeportconverter_port_to -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net ddr3/main_litedramnativeportconverter_next_cmd
ila_add_probe u_ila_axi -net ddr3/main_litedramnativeportconverter_cmd_we
ila_add_probe u_ila_axi -net ddr3/main_litedramnativeportconverter_cmd_last
# wdata_fifo internals
ila_add_probe u_ila_axi -bus ddr3/main_litedramnativeportconverter_wdata_fifo_level -msb 1 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus ddr3/main_litedramnativeportconverter_wdata_fifo_level -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net ddr3/main_litedramnativeportconverter_wdata_fifo_syncfifo_writable
ila_add_probe u_ila_axi -net ddr3/main_litedramnativeportconverter_wdata_fifo_syncfifo_readable
ila_add_probe u_ila_axi -bus ddr3/main_litedramnativeportconverter_wdata_chunk -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net ddr3/main_litedramnativeportconverter_wdata_chunk_valid
ila_add_probe u_ila_axi -net ddr3/main_litedramnativeportconverter_wdata_finished
# wdata path (fifo to bank machine)
ila_add_probe u_ila_axi -net ddr3/main_litedramnativeportconverter_wdata_buffer_pipe_valid_source_valid
ila_add_probe u_ila_axi -net ddr3/main_litedramnativeportconverter_wdata_converter_sink_valid
# AXI write frontend gates
ila_add_probe u_ila_axi -net ddr3/main_write_can_write
ila_add_probe u_ila_axi -bus ddr3/main_write_w_buffer_level0 -msb 4 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/main_write_w_buffer_level2 -msb 4 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net ddr3/main_write_aw_valid
ila_add_probe u_ila_axi -net ddr3/main_write_aw_first
################################
