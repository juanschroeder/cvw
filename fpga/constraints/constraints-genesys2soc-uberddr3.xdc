# UberDDR3 settings.
set_property IODELAY_GROUP DDR3_IO [get_cells u_cvwsoc_axi/ddr3/u_uberddr3/ddr3_top_inst/ddr3_phy_inst/IDELAYCTRL_inst]
set_property IODELAY_GROUP DDR3_IO [get_cells -hier -regexp {^u_cvwsoc_axi/ddr3/u_uberddr3/ddr3_top_inst/ddr3_phy_inst/.*(IDELAYE2|ODELAYE2).*$}]
