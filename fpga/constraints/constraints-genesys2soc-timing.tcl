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

# # LiteEth CDC: clk_out3_mmcm <-> clk_out4_mmcm are asynchronous domains
# # set c3 [get_clocks -quiet -include_generated_clocks clk_out3_mmcm]
# # set c4 [get_clocks -quiet -include_generated_clocks clk_out4_mmcm]
# # if {[llength $c3] && [llength $c4]} {
# #   set_clock_groups -asynchronous -name async_clkout3_clkout4 -group $c3 -group $c4
# # } else {
# #   puts "WARNING: clocks not found: clk_out3_mmcm=[llength $c3] clk_out4_mmcm=[llength $c4]"
# # }
# # this is the 'not generic' solution
# # Cut only LiteEth CDC synchronizer endpoints (Gray counter -> MultiReg)
# set_false_path \
#   -from [get_cells -hier -regexp {.*u_liteeth/.*core_rx_cdc_cdc_graycounter.*_q_reg.*}] \
#   -to   [get_cells -hier -regexp {.*u_liteeth/.*xilinxmultiregimpl[0-9]+_regs0_reg.*}]

# set_false_path \
#   -from [get_cells -hier -regexp {.*u_liteeth/.*core_pulsesynchronizer[0-9]+_toggle_i_reg.*}] \
#   -to   [get_cells -hier -regexp {.*u_liteeth/.*xilinxmultiregimpl[0-9]+_regs0_reg.*}]


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
set dst [get_pins -hier -quiet -regexp {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/.*buffercc/buffers_0_reg/D$}]
if {[llength $dst]} {
  set_false_path -to $dst
} else {
  error "Did not match any OHCI BufferCC stage-0 D pins"
}

# After init_design (clocks exist here)
set c_pll  [get_clocks -quiet -include_generated_clocks clk_pll_i]
set c_out2 [get_clocks -quiet -include_generated_clocks clk_out2_mmcm]

if {[llength $c_pll] && [llength $c_out2]} {
  set_clock_groups -asynchronous -group $c_pll -group $c_out2
} else {
  puts "WARNING: clocks not found for async grouping: clk_pll_i=$c_pll clk_out2_mmcm=$c_out2"
}



# ------------------------------------------------------------
# USB OHCI: IRQ synchronizer (clk_pll_i -> clk_out3_mmcm)
# Cut timing into the FIRST sync FF in the destination domain.
set dst [get_pins -hier -quiet -regexp {.*usb_irq_ff1_reg.*/D}]
if {[llength $dst]} { set_false_path -to $dst }


# ------------------------------------------------------------
# USB OHCI: ccToggle crossings (clk_out2_mmcm <-> clk_pll_i)
# These are toggle-based CDC blocks; Vivado still reports reg->reg across domains.
# Cut timing into the destination "outputArea" regs.
set_false_path -to [must_get_pins {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/output_.*_ccToggle/outputArea_.*_reg(\[[0-9]+\])?/D$}]

# # ------------------------------------------------------------
# # LiteEth: async reset pins (PRE) recovery/removal checks across RMII/system clocks
# # Your old rule only matched FDPE or FDPE_1; this covers FDPE, FDPE_1, FDPE_2, ...
# set dst [get_pins -hier -quiet -regexp {.*u_liteeth/FDPE(_[0-9]+)?/PRE}]
# if {[llength $dst]} { set_false_path -to $dst }

# # ------------------------------------------------------------
# # LiteEth: CDC synchronizers (graycounter/pulse sync -> XilinxMultiReg)
# # ASYNC_REG / MultiReg does NOT automatically “false-path” timing.
# # Cut timing from CDC source regs into the destination multireg D pins.
# set dst_mr [get_pins -hier -quiet -regexp {.*u_liteeth/.*xilinxmultiregimpl[0-9]+_regs0_reg\[[0-9]+\]/D}]

# set src [get_cells -hier -quiet -regexp {.*u_liteeth/.*cdc_.*graycounter[01]_q_reg.*}]
# if {[llength $src] && [llength $dst_mr]} { set_false_path -from $src -to $dst_mr }

# set src [get_cells -hier -quiet -regexp {.*u_liteeth/.*core_pulsesynchronizer[0-9]+_toggle_i_reg.*}]
# if {[llength $src] && [llength $dst_mr]} { set_false_path -from $src -to $dst_mr }


set f [open "HOOK_RAN.txt" w]
puts $f "HOOK RAN at [clock format [clock seconds]]"
close $f

# ANY OHCI BufferCC first-stage flop
set dst [get_pins -hier -quiet -regexp {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/.*buffercc/buffers_0_reg/D$}]
if {[llength $dst]} {
  set_false_path -to $dst
} else {
  error "Did not match any OHCI BufferCC stage-0 D pins"
}

set_false_path -to [must_get_pins {(^|.*/)usb_phy_resetn_ff_reg\[[01]\]/CLR$}]


# ccToggle -> BufferCC first stage (this one was NOT covered by your old regexes)
set_false_path -to [must_get_pins {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/.*_ccToggle/popArea_.*_reg(\[[0-9]+\])?/D$}]
if {[llength $p]} { set_false_path -to $p }
set_false_path -to [must_get_pins {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/.*_asyncAssertSyncDeassert_buffercc/buffers_[01]_reg/PRE$}]

set dst [get_pins -hier -quiet -regexp {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/output_tick_pulseCCByToggle/inArea_target_buffercc/buffers_0_reg/D$}]
if {[llength $dst]} { set_false_path -to $dst }


# USB reset synchronizer
set_property ASYNC_REG TRUE [get_cells -hier -regexp {.*usb_phy_resetn_ff_reg\[[01]\]$}]
# OHCI CDC synchronizer: input_lowSpeed_buffercc
set_property ASYNC_REG TRUE [get_cells -hier -regexp {.*input_lowSpeed_buffercc/buffers_[01]_reg$}]
# OHCI CDC synchronizer: outHitSignal_buffercc
set_property ASYNC_REG TRUE [get_cells -hier -regexp {.*outHitSignal_buffercc/buffers_[01]_reg$}]

# Temporary debug ILAs from debug-boot.xdc.
foreach ila {u_ila_axi u_ila_spi} {
  set ila_cells [get_cells -hier -quiet -regexp ".*${ila}.*"]
  set ila_pins  [get_pins -quiet -of_objects $ila_cells]
  if {[llength $ila_pins]} {
    puts "INFO: false-pathing timing through temporary debug core ${ila} ([llength $ila_pins] pins)"
    set_false_path -through $ila_pins
  } else {
    puts "WARNING: temporary debug core ${ila} not found; no ILA false path applied"
  }
}

# SDHCI
set sdhci_io_ports [get_ports -quiet {SD_CMD SD_DAT[*]}]
set sdclk_obuf_o [get_pins -hier -quiet -regexp {.*SD_CLK.*OBUF.*\/O$}]

if {[llength $sdclk_obuf_o] != 1} {
  puts "ERROR: SD_CLK OBUF output candidates:"
  puts [get_pins -hier -regexp {.*SD_CLK.*}]
  error "Expected exactly one SD_CLK OBUF/O pin, got [llength $sdclk_obuf_o]: $sdclk_obuf_o"
}

create_generated_clock -name SDHCIDClk -source $sdclk_obuf_o -divide_by 1 [get_ports SD_CLK]

# Card -> FPGA
set_input_delay  -clock [get_clocks SDHCIDClk] -max -5.000 $sdhci_io_ports
set_input_delay  -clock [get_clocks SDHCIDClk] -min  5.000 $sdhci_io_ports

# FPGA -> Card
set_output_delay -clock [get_clocks SDHCIDClk] -max -3.000 $sdhci_io_ports
set_output_delay -clock [get_clocks SDHCIDClk] -min  3.000 $sdhci_io_ports
