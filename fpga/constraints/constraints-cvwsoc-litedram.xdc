# Constraints shared by all CVWSoC LiteDRAM configurations.
#
# cvwsoc_ram gives every LiteDRAM controller the elaborated hierarchy
# u_cvwsoc_ram/gen_litedram.ddr.  DDR2 and DDR3 both use the same 7-series
# IDELAYCTRL/IDELAYE2/ODELAYE2 primitives, so their delay group is common.
# On Genesys 2, the DDR and RGMII IODELAY cells share bank 33; they must use
# the same group name.  DDR3_IO is therefore retained for compatibility.
set_property IODELAY_GROUP DDR3_IO [get_cells {u_cvwsoc_ram/gen_litedram.ddr/IDELAYCTRL}]
set_property IODELAY_GROUP DDR3_IO [get_cells -hier -regexp {^u_cvwsoc_ram/gen_litedram\.ddr/(I|O)DELAYE2(_[0-9]+)?$}]

################################################################################
# LiteX-generated CDC/reset constraints
################################################################################
# A design need not instantiate MultiReg cells.  Quiet the empty query, while
# retaining LiteX's canonical constraint when they are present.
set_false_path -quiet -to [get_nets -quiet -filter {mr_ff == TRUE}]
set_false_path -quiet -to [get_pins -filter {REF_PIN_NAME == PRE} -of_objects [get_cells -hierarchical -filter {ars_ff1 == TRUE || ars_ff2 == TRUE}]]
set_max_delay 2 -quiet -from [get_pins -filter {REF_PIN_NAME == Q} -of_objects [get_cells -hierarchical -filter {ars_ff1 == TRUE}]] -to [get_pins -filter {REF_PIN_NAME == D} -of_objects [get_cells -hierarchical -filter {ars_ff2 == TRUE}]]
