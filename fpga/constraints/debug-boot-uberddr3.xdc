
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/i_s_axi_arvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/o_s_axi_arready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_araddr -msb 29 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_arid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# R channel
#ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/i_s_axi_rvalid
#ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/o_s_axi_rready
# Check: is this one optimized?
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/i_s_axi_rlast
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_rdata -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_rid -msb 3 -lsb 0 -order lsb2msb
# AW channel
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/i_s_axi_awvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/o_s_axi_awready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_awaddr -msb 29 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_awid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_awid -msb 3 -lsb 2 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_awburst -msb 1 -lsb 0 -order lsb2msb

# W channel
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/i_s_axi_wvalid
#ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/main_w_valid
#ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/user_port_axi_0_wready
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/o_s_axi_wready
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/i_s_axi_wlast
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_wstrb -msb auto -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/i_s_axi_wdata -msb auto -lsb 0 -order lsb2msb


#ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/user_port_axi_0_bvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/o_s_axi_bvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/i_s_axi_bready
#ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/main_b_param_id  -msb 3 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/main_b_payload_resp  -msb 1 -lsb 0 -order lsb2msb

# UberDDR3 wrapper internal 256-bit AXI adapter output.
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_awvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_awready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_awid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_awaddr_full -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_awsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_awburst -msb 1 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_wvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_wready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_wstrb -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_wlast

# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_bvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_bready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_bid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_bresp -msb 1 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_arvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_arready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_arid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_araddr_full -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_arsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_arburst -msb 1 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_rvalid
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_rready
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_rid -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/axi256_rlast
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/axi256_rresp -msb 1 -lsb 0 -order lsb2msb
