################################################################
# CVWSoC timing constraints
#
# This is a post-init Tcl hook, not an XDC file.  It is intentionally safe to
# use with different CVWSoC peripheral configurations: a rule is applied only
# when its implemented endpoint(s) exist.
################################################################

proc cvwsoc_pins {re} {
  return [get_pins -hier -quiet -regexp $re]
}

proc cvwsoc_cells {re} {
  return [get_cells -hier -quiet -regexp $re]
}

proc cvwsoc_false_path_to {label dst_re} {
  set dst [cvwsoc_pins $dst_re]
  if {[llength $dst]} {
    set_false_path -to $dst
  } else {
    puts "INFO: CVWSoC timing: $label not present; skipping"
  }
}

proc cvwsoc_false_path_from_to {label src_re dst_re} {
  set src [cvwsoc_cells $src_re]
  set dst [cvwsoc_pins $dst_re]
  if {[llength $src] && [llength $dst]} {
    set_false_path -from $src -to $dst
  } else {
    puts "INFO: CVWSoC timing: $label not present; skipping"
  }
}

proc cvwsoc_async_reg {label cell_re} {
  set cells [cvwsoc_cells $cell_re]
  if {[llength $cells]} {
    set_property ASYNC_REG TRUE $cells
  } else {
    puts "INFO: CVWSoC timing: $label not present; skipping"
  }
}


# ----------------------------------------------------------------
# UART: should not be necessary
#set_false_path -to [get_ports UARTSout]
#set_false_path -from [get_ports UARTSin]


# ----------------------------------------------------------------
# PLIC to CPU
cvwsoc_false_path_to "PLIC to CPU Machine External Interrupt Pending input" \
  {.*sync_meip/reg_q_reg\[0\]/D$}
cvwsoc_false_path_to "PLIC to CPU Supervisor External Interrupt Pending input" \
  {.*sync_seip/reg_q_reg\[0\]/D$}

# ----------------------------------------------------------------
# AHB-bridge
cvwsoc_false_path_to "CPU to AHB-axi bridge" \
  {.*bridge/pnd_valid_reg/D}

# ----------------------------------------------------------------
# SPI SD peripheral
set cvwsoc_sdspi_inputs  [get_ports -quiet {SDCIn}]
set cvwsoc_sdspi_outputs [get_ports -quiet {SDCCLK SDCCS SDCCmd}]

if {[llength $cvwsoc_sdspi_inputs]} {
  set_false_path -from $cvwsoc_sdspi_inputs
}

if {[llength $cvwsoc_sdspi_outputs]} {
  set_false_path -to $cvwsoc_sdspi_outputs
}

# ----------------------------------------------------------------
# Reset / MIG

cvwsoc_false_path_to "MIG init_calib_complete to sysrst" \
  {.*sysrst/U0/EXT_LPF/lpf_int_reg/D}

# ----------------------------------------------------------------
# Wishbone LiteEth

cvwsoc_false_path_to "Wishbone LiteEth async PRE" \
  {.*u_liteeth/FDPE(_[0-9]+)?/PRE}
cvwsoc_false_path_to "Wishbone LiteEth MultiReg stage 0 and RMII reset" \
  {.*(xilinxmultiregimpl.*_regs0_reg(\[[0-9]+\])?|rst_rmii_ff_reg\[0\])/D}

# ----------------------------------------------------------------
# AXI LiteEth

cvwsoc_false_path_to "AXI LiteEth IRQ synchronizer" \
  {(^|.*/)liteeth_irq_ff1_reg/D$}

# ----------------------------------------------------------------
# USB OHCI

cvwsoc_false_path_to "USB IRQ synchronizer" {.*usb_irq_ff1_reg.*/D}
cvwsoc_false_path_to "USB BufferCC stage 0" \
  {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/.*buffercc/buffers_0_reg/D$}
cvwsoc_false_path_to "USB ccToggle outputArea" \
  {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/output_.*_ccToggle/outputArea_.*_reg(\[[0-9]+\])?/D$}
cvwsoc_false_path_to "USB ccToggle popArea" \
  {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/.*_ccToggle/popArea_.*_reg(\[[0-9]+\])?/D$}
cvwsoc_false_path_to "USB async assert/sync deassert" \
  {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/.*_asyncAssertSyncDeassert_buffercc/buffers_[01]_reg/PRE$}
cvwsoc_false_path_to "USB tick BufferCC stage 0" \
  {.*usb_ohci_i/(gen_ohci_dma(32|64)\.)?u_ohci/cc/output_tick_pulseCCByToggle/inArea_target_buffercc/buffers_0_reg/D$}
cvwsoc_false_path_to "USB PHY reset synchronizer" \
  {.*gen_axi_usb\.usb_phy_resetn_ff_reg\[[01]\]/CLR$}
cvwsoc_async_reg "USB PHY reset synchronizer" {.*usb_phy_resetn_ff_reg\[[01]\]$}
cvwsoc_async_reg "USB low-speed BufferCC" {.*input_lowSpeed_buffercc/buffers_[01]_reg$}
cvwsoc_async_reg "USB outHitSignal BufferCC" {.*outHitSignal_buffercc/buffers_[01]_reg$}

# ----------------------------------------------------------------
# IDMA / AXI CDC
#
# The non-Xilinx axi_cdc uses Gray-coded asynchronous FIFOs.  The endpoint
# patterns are independent of CPU width and of the board; absent CDC instances
# are simply skipped.  The IDMA request/data path itself is synchronous and
# deliberately has no false-path exception here.

cvwsoc_false_path_to "IDMA IRQ synchronizer" {.*dma_irq_sync_reg\[0\]/D}

set cvwsoc_axi_cdc_async [get_nets -hier -quiet -regexp {.*u_axi_cdc/(.*/)?async_data_(aw|w|b|ar|r)_(data|wptr|rptr).*}]
set cvwsoc_axi_cdc_start [cvwsoc_pins {.*u_axi_cdc/.*/i_cdc_fifo_gray_(src|dst)_(aw|w|b|ar|r)/(data_q_reg.*|wptr_q_reg.*|rptr_q_reg.*)/C$}]
set cvwsoc_axi_cdc_end [concat \
  [cvwsoc_pins {.*u_axi_cdc/.*/i_cdc_fifo_gray_(src|dst)_(aw|w|b|ar|r)/gen_sync.*reg_q_reg\[0\]/D$}] \
  [cvwsoc_pins {.*u_axi_cdc/.*/i_cdc_fifo_gray_(src|dst)_(aw|w|b|ar|r)/i_spill_register/.*a_data_q_reg.*\/D$}]]
if {[llength $cvwsoc_axi_cdc_async] && [llength $cvwsoc_axi_cdc_start] && [llength $cvwsoc_axi_cdc_end]} {
  set cvwsoc_axi_cdc_clocks [get_clocks -quiet -of_objects $cvwsoc_axi_cdc_start]
  if {[llength $cvwsoc_axi_cdc_clocks] == 2} {
    set cvwsoc_axi_cdc_t_fast [lindex [lsort -real [get_property PERIOD $cvwsoc_axi_cdc_clocks]] 0]
    set_max_delay $cvwsoc_axi_cdc_t_fast -datapath_only \
      -from $cvwsoc_axi_cdc_start -through $cvwsoc_axi_cdc_async -to $cvwsoc_axi_cdc_end
    set_false_path -hold \
      -from $cvwsoc_axi_cdc_start -through $cvwsoc_axi_cdc_async -to $cvwsoc_axi_cdc_end
  } else {
    puts "WARNING: CVWSoC timing: AXI CDC has [llength $cvwsoc_axi_cdc_clocks] clocks; skipping"
  }
} else {
  puts "INFO: CVWSoC timing: non-Xilinx AXI CDC not present; skipping"
}

# ----------------------------------------------------------------
# SDHCI

set cvwsoc_sdhci_ports [get_ports -quiet {SD_CMD SD_DAT[*]}]
set cvwsoc_sdhci_aclk [cvwsoc_pins {.*u_cvwsoc_axi/gen_axi_sdhci\.sdhci_i/i_axi_sdhci/aclk$}]
set cvwsoc_sdhci_clocks [get_clocks -quiet -of_objects $cvwsoc_sdhci_aclk]
if {[llength $cvwsoc_sdhci_ports] && [llength $cvwsoc_sdhci_clocks] == 1} {
  # SD_CLK is clock-as-data: SDHCI generates it with a programmable divider,
  # while all CMD/DAT logic is synchronous to aclk.  Constrain the pads to
  # that actual bus clock instead of propagating a generated clock through
  # SD_CLK.  The external SD clock rate is selected by the controller's
  # implementation and software-programmable divider.
  set_input_delay  -clock $cvwsoc_sdhci_clocks -max -5.000 $cvwsoc_sdhci_ports
  set_input_delay  -clock $cvwsoc_sdhci_clocks -min  5.000 $cvwsoc_sdhci_ports
  set_output_delay -clock $cvwsoc_sdhci_clocks -max -3.000 $cvwsoc_sdhci_ports
  set_output_delay -clock $cvwsoc_sdhci_clocks -min  3.000 $cvwsoc_sdhci_ports
} else {
  puts "INFO: CVWSoC timing: SDHCI ports/aclk not present; skipping"
}
cvwsoc_false_path_to "SDHCI IRQ synchronizer" \
  {(^|.*/)sdhci_irq_ff1_reg(\[[01]\])?/D$}

# ----------------------------------------------------------------
# AXI VGA

cvwsoc_false_path_to "AXI VGA register reset synchronizer" \
  {.*gen_axi_vga\.axi_vga_wrap_i/i_axi_to_reg/.*spill_register_flushable_i.*/(CLR|R)$}

# ----------------------------------------------------------------
# I2S IDMA audio FIFO

set cvwsoc_audio_fifo_sync [cvwsoc_pins {.*axis_audio_fifo_i/fifo_inst/(wr|rd)_ptr_gray_sync[12]_reg_reg\[[0-9]+\]/D$}]
if {[llength $cvwsoc_audio_fifo_sync]} {
  set_property ASYNC_REG TRUE [get_cells -of_objects $cvwsoc_audio_fifo_sync]
  cvwsoc_false_path_to "I2S audio FIFO Gray-pointer stage 1" \
    {.*axis_audio_fifo_i/fifo_inst/(wr|rd)_ptr_gray_sync1_reg_reg\[[0-9]+\]/D$}
  set cvwsoc_audio_reset_pins [cvwsoc_pins {.*axis_audio_fifo_i/fifo_inst/[sm]_rst_sync[123]_reg_reg/D$}]
  if {[llength $cvwsoc_audio_reset_pins]} {
    set_property ASYNC_REG TRUE [get_cells -of_objects $cvwsoc_audio_reset_pins]
  }
  cvwsoc_false_path_to "I2S audio FIFO reset stage 2" \
    {.*axis_audio_fifo_i/fifo_inst/[sm]_rst_sync2_reg_reg/D$}
} else {
  puts "INFO: CVWSoC timing: I2S audio FIFO not present; skipping"
}

# ----------------------------------------------------------------
# Temporary debug cores

foreach cvwsoc_ila {u_ila_axi u_ila_spi} {
  set cvwsoc_ila_cells [cvwsoc_cells ".*${cvwsoc_ila}.*"]
  set cvwsoc_ila_pins [get_pins -quiet -of_objects $cvwsoc_ila_cells]
  if {[llength $cvwsoc_ila_pins]} {
    set_false_path -through $cvwsoc_ila_pins
  }
}
