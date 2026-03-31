# # Necessary for LiteDRAM
# set_property IODELAY_GROUP DDR3_DLY [get_cells -hier -regexp {^.*/ddr3/.*(IDELAYCTRL|IDELAYE2|ODELAYE2).*$}]
# # -------------------------
# # LiteDRAM DDR3 IODELAY group
# # -------------------------
# set_property IODELAY_GROUP DDR3_IO [get_cells {ddr3/IDELAYCTRL}]
# set_property IODELAY_GROUP DDR3_IO [get_cells -hier -regexp {^ddr3/(I|O)DELAYE2(_[0-9]+)?$}]


# LiteDRAM settings
set_property IODELAY_GROUP DDR3_IO [get_cells {ddr3/IDELAYCTRL}]
set_property IODELAY_GROUP DDR3_IO [get_cells -hier -regexp {^ddr3/(I|O)DELAYE2(_[0-9]+)?$}]


#########################
## LITEDRAM GENERATED   #
#########################
################################################################################
# False path constraints
################################################################################
set_false_path -quiet -through [get_nets -hierarchical -filter {mr_ff == TRUE}]
set_false_path -quiet -to [get_pins -filter {REF_PIN_NAME == PRE} -of_objects [get_cells -hierarchical -filter {ars_ff1 == TRUE || ars_ff2 == TRUE}]]
set_max_delay 2 -quiet -from [get_pins -filter {REF_PIN_NAME == C} -of_objects [get_cells -hierarchical -filter {ars_ff1 == TRUE}]] -to [get_pins -filter {REF_PIN_NAME == D} -of_objects [get_cells -hierarchical -filter {ars_ff2 == TRUE}]]

#
set_property INTERNAL_VREF 0.750 [get_iobanks 34]
