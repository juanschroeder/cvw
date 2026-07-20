# CVWSoC memory AXI boundary.  This is independent of the selected Xilinx
# DDR generation and of the controller instance hierarchy.
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_arvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_arready
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_araddr -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arid -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# R channel
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_rvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_rready
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_rlast
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_rdata -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_rid -msb auto -lsb 0 -order lsb2msb
# AW channel
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_awvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_awready
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awaddr -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awid -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_awburst -msb 1 -lsb 0 -order lsb2msb

# W channel
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_wvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_wready
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_wlast
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_wstrb -msb auto -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_wdata -msb auto -lsb 0 -order lsb2msb

ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_bvalid
ila_add_probe u_ila_axi -net u_cvwsoc_axi/ddr_axi_bready
ila_add_probe u_ila_axi -bus u_cvwsoc_axi/ddr_axi_bid -msb auto -lsb 0 -order lsb2msb
