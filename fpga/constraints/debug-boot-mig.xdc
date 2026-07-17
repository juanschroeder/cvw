# crossbar side to DDR: same but in ddr3
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_arvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_arready
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_araddr -msb 29 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_arid -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_arlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_arsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# R channel
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_rvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_rready
# Check: is this one optimized?
# ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_rresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_rlast
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_rdata -msb 63 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_rid -msb 3 -lsb 0 -order lsb2msb
# AW channel
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_awvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_awready
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_awaddr -msb 29 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_awid -msb 3 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_awlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_awsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_awburst -msb 1 -lsb 0 -order lsb2msb

# W channel
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_wvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_wready
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_wlast
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_wstrb -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_wdata -msb 63 -lsb 0 -order lsb2msb

ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_bvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr3/s_axi_bready
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr3/s_axi_bid -msb 3 -lsb 0 -order lsb2msb
