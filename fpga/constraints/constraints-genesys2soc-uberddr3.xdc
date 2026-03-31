# UberDDR3 settings
# For UberDDR3 the default group is 'DDR3-GROUP'
# UberDDR3 delay primitives live below ddr3/u_uberddr3/... and use suffixes
# like ODELAYE2_clk / ODELAYE2_data, so match the full sub-hierarchy.
set_property IODELAY_GROUP DDR3_IO [get_cells {ddr3/u_uberddr3/ddr3_top_inst/ddr3_phy_inst/IDELAYCTRL_inst}]
set_property IODELAY_GROUP DDR3_IO [get_cells -hier -regexp {^ddr3/u_uberddr3/ddr3_top_inst/ddr3_phy_inst/.*(IDELAYE2|ODELAYE2).*$}]
