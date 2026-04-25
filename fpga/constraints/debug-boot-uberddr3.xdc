
ila_add_probe u_ila_axi -net ddr3/i_s_axi_arvalid
ila_add_probe u_ila_axi -net ddr3/o_s_axi_arready
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_araddr -msb 29 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_arid -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_arlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_arsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# R channel
#ila_add_probe u_ila_axi -net ddr3/i_s_axi_rvalid
#ila_add_probe u_ila_axi -net ddr3/o_s_axi_rready
# Check: is this one optimized?
# ila_add_probe u_ila_axi -bus ddr3/i_s_axi_rresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus BUS_cb_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net ddr3/i_s_axi_rlast
# ila_add_probe u_ila_axi -bus ddr3/i_s_axi_rdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus ddr3/i_s_axi_rid -msb 3 -lsb 0 -order lsb2msb
# AW channel
ila_add_probe u_ila_axi -net ddr3/i_s_axi_awvalid
ila_add_probe u_ila_axi -net ddr3/o_s_axi_awready
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_awaddr -msb 29 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus ddr3/i_s_axi_awid -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_awid -msb 3 -lsb 2 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_awlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_awsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_awburst -msb 1 -lsb 0 -order lsb2msb

# W channel
ila_add_probe u_ila_axi -net ddr3/i_s_axi_wvalid
#ila_add_probe u_ila_axi -net ddr3/main_w_valid
#ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_wready
ila_add_probe u_ila_axi -net ddr3/o_s_axi_wready
ila_add_probe u_ila_axi -net ddr3/i_s_axi_wlast
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_wstrb -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus ddr3/i_s_axi_wdata -msb 63 -lsb 0 -order lsb2msb


#ila_add_probe u_ila_axi -net ddr3/user_port_axi_0_bvalid
ila_add_probe u_ila_axi -net ddr3/o_s_axi_bvalid
ila_add_probe u_ila_axi -net ddr3/i_s_axi_bready
#ila_add_probe u_ila_axi -bus ddr3/main_b_param_id  -msb 3 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus ddr3/main_b_payload_resp  -msb 1 -lsb 0 -order lsb2msb
