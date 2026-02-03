################################################################
# Eliminate all CDC-related timing violations that do not apply
################################################################

# Runs inside impl_1 after link_design. This is real Tcl (unlike XDC).

proc must_get_pins {re} {
  set p [get_pins -hier -quiet -regexp $re]
  if {[llength $p] == 0} { error "Missing pins (pattern): $re" }
  return $p
}

# 1) MIG init_calib_complete into proc_sys_reset LPF is asynchronous -> do NOT time it.
# Cut EVERYTHING into that LPF D pin (robust; doesn't depend on MIG internals).
set_false_path -to [must_get_pins {.*sysrst/U0/EXT_LPF/lpf_int_reg/D}]

# 2) LiteEth internal async PRE pins: already proved fanout only hits PRE pins.
#set_false_path -to [must_get_pins {.*u_liteeth/FDPE(_1)?/PRE}]
set_false_path -to [must_get_pins {.*u_liteeth/FDPE(_[0-9]+)?/PRE}]

# # LiteEth: ignore timing to async preset pins (PRE) of FDPE flops
# set pre_pins [get_pins -hier -quiet -regexp {.*u_liteeth/FDPE(_[0-9]+)?/PRE}]
# if {[llength $pre_pins]} {
#   set_false_path -to $pre_pins
# } else {
#   puts "WARNING: no LiteEth FDPE*/PRE pins matched"
# }

# LiteEth CDC: clk_out3_mmcm <-> clk_out4_mmcm are asynchronous domains
# set c3 [get_clocks -quiet -include_generated_clocks clk_out3_mmcm]
# set c4 [get_clocks -quiet -include_generated_clocks clk_out4_mmcm]
# if {[llength $c3] && [llength $c4]} {
#   set_clock_groups -asynchronous -name async_clkout3_clkout4 -group $c3 -group $c4
# } else {
#   puts "WARNING: clocks not found: clk_out3_mmcm=[llength $c3] clk_out4_mmcm=[llength $c4]"
# }
# this is the 'not generic' solution
# Cut only LiteEth CDC synchronizer endpoints (Gray counter -> MultiReg)
set_false_path \
  -from [get_cells -hier -regexp {.*u_liteeth/.*core_rx_cdc_cdc_graycounter.*_q_reg.*}] \
  -to   [get_cells -hier -regexp {.*u_liteeth/.*xilinxmultiregimpl[0-9]+_regs0_reg.*}]

set_false_path \
  -from [get_cells -hier -regexp {.*u_liteeth/.*core_pulsesynchronizer[0-9]+_toggle_i_reg.*}] \
  -to   [get_cells -hier -regexp {.*u_liteeth/.*xilinxmultiregimpl[0-9]+_regs0_reg.*}]


# Ignore async CDC into first-stage synchronizer flops (LiteEth MultiReg stage0 + RMII reset stage0)
set_false_path -to [get_pins -hier -regexp {.*(xilinxmultiregimpl.*_regs0_reg\[[0-9]+\]|rst_rmii_ff_reg\[0\])/D}]


# 3) CDC synchronizer endpoints (only apply if they exist; don't fail build)
set p [get_pins -hier -quiet -regexp {.*usb_irq_ff1_reg.*/D}]
if {[llength $p]} { set_false_path -to $p }

set p [get_pins -hier -quiet -regexp {.*dma_irq_sync_reg\[0\]/D}]
if {[llength $p]} { set_false_path -to $p }

# 4) DO NOT use broad clock_groups unless you really mean it.
# If you still want it, do it here (and only if both clocks exist):
#set a [get_clocks -quiet -include_generated_clocks clk_pll_i]
#set b [get_clocks -quiet -include_generated_clocks clk_out2_mmcm]
#if {[llength $a] && [llength $b]} { set_clock_groups -asynchronous -group $a -group $b }

# USB BuferCC
# CDC for: usb_ohci_i/u_ohci/cc/input_lowSpeed_buffercc/buffers_0_reg/D
#By listing all input pins connected to the net feeding buffers_0_reg/D and seeing no other loads, we 
# proved it’s an isolated synchronizer input, so set_false_path -to .../buffers_0_reg/D is the correct constraint.
#set_false_path -to [get_pins -hier -regexp {.*usb_ohci_i/u_ohci/cc/input_lowSpeed_buffercc/buffers_0_reg/D}]
set_false_path -to [get_pins -hier -regexp {.*input_usbResume_buffercc.*/buffers_0_reg/D}]
set_false_path -to [get_pins -hier -quiet -regexp {.*usb_ohci_i/u_ohci/cc/input_.*_buffercc.*/buffers_0_reg/D}]
# other CDC
set_false_path -to [get_pins -hier -quiet -regexp {.*usb_ohci_i/u_ohci/cc/input_tx_ccToggle/popArea_stream_rData_fragment_reg\[[0-9]+\]/D$}]

# After init_design (clocks exist here)
set c_pll  [get_clocks -quiet -include_generated_clocks clk_pll_i]
set c_out2 [get_clocks -quiet -include_generated_clocks clk_out2_mmcm]

if {[llength $c_pll] && [llength $c_out2]} {
  set_clock_groups -asynchronous -group $c_pll -group $c_out2
} else {
  puts "WARNING: clocks not found for async grouping: clk_pll_i=$c_pll clk_out2_mmcm=$c_out2"
}

