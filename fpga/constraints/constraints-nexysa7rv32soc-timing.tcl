################################################################
# Nexys A7 RV32 CVWSoC timing additions
################################################################

# Keep the frozen Nexys A7 SoC constraints as the common baseline.  Resolve
# the path relative to this hook, not to Vivado's current working directory.
source [file join [file dirname [file normalize [info script]]] constraints-nexysa7soc-timing.tcl]

# I2S IDMA audio FIFO Gray-pointer and reset CDC.
# This is the same non-Xilinx FIFO CDC scheme used by the Genesys2 build.
set audio_fifo_sync [get_pins -hier -quiet -regexp {.*axis_audio_fifo_i/fifo_inst/(wr|rd)_ptr_gray_sync[12]_reg_reg\[[0-9]+\]/D$}]
if {[llength $audio_fifo_sync]} {
  set_property ASYNC_REG TRUE [get_cells -of_objects $audio_fifo_sync]
  set_false_path -to [must_get_pins {.*axis_audio_fifo_i/fifo_inst/(wr|rd)_ptr_gray_sync1_reg_reg\[[0-9]+\]/D$}]
  set_property ASYNC_REG TRUE [get_cells -of_objects [must_get_pins {.*axis_audio_fifo_i/fifo_inst/[sm]_rst_sync[123]_reg_reg/D$}]]
  set_false_path -to [must_get_pins {.*axis_audio_fifo_i/fifo_inst/[sm]_rst_sync2_reg_reg/D$}]
} else {
  puts "INFO: I2S audio FIFO not present; skipping audio FIFO CDC constraints"
}

# The reported gen_idma/.../i_idma_request_fifo -> i_aw_addrs path is a
# clk_pll_i-to-clk_pll_i synchronous path, not a CDC.  Do not constrain it
# away here; it requires normal timing closure if it remains critical.
