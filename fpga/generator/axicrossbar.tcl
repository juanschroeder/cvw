set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)

set ipName axicrossbar

create_project $ipName . -force -part $partNumber
if {$boardName!="ArtyA7"} {
    set_property board_part $boardName [current_project]
}

create_ip -name axi_crossbar -vendor xilinx.com -library ip -module_name $ipName

# IMPORTANT (current reality for Wally DDR2/MIG on Nexys A7):
# - Use PROTOCOL=AXI4.
# - Keep ID_WIDTH and S00_THREAD_ID_WIDTH non-zero so the crossbar exposes the AXI ID ports.
# - Vivado’s AXI Crossbar insists that each MI has at least one connected SI. Therefore, we keep NUM_MI=2
#   and DO NOT try to set M01_S00_*_CONNECTIVITY=0 (that fails validation and Vivado reverts the IP to a
#   previous “valid” configuration, causing port/width mismatches).
# - The practical fix is to give M00 and M01 NON-OVERLAPPING address segments:
#     * M00 maps DDR (128MB) at AXI 0x0000_0000 .. 0x07FF_FFFF  (BASE=0x0, ADDR_WIDTH=27)
#     * M01 maps an unused “dummy” window at AXI 0x0800_0000 .. 0x0FFF_FFFF (BASE=0x0800_0000, ADDR_WIDTH=27)
# - Crossbar ADDR_WIDTH must be wide enough to represent both segments (>= 28; we use 32).
# - Do NOT truncate addresses into the crossbar (no [26:0] slicing on the S_AXI side). Feed full-width
#   BUS_axi_awaddr/araddr into the crossbar so it can decode M00 vs M01 correctly.
# - Only truncate to 27 bits at the MIG port (since the MIG’s AXI addr width is 27 for 128MB DDR2).

# The config commented below was working before the CDMA changes
# set_property -dict [list \
#   CONFIG.PROTOCOL {AXI4} \
#   CONFIG.NUM_SI {1} \
#   CONFIG.NUM_MI {2} \
#   CONFIG.ADDR_WIDTH {32} \
#   CONFIG.DATA_WIDTH {64} \
#   CONFIG.ID_WIDTH {4} \
#   CONFIG.S00_THREAD_ID_WIDTH {4} \
#   CONFIG.S00_SINGLE_THREAD {0} \
#   CONFIG.ADDR_RANGES {1} \
#   CONFIG.M00_A00_BASE_ADDR {0x0000000000000000} \
#   CONFIG.M00_A00_ADDR_WIDTH {27} \
#   CONFIG.M01_A00_BASE_ADDR {0x0000000008000000} \
#   CONFIG.M01_A00_ADDR_WIDTH {27} \
#   CONFIG.M00_S00_READ_CONNECTIVITY {1} \
#   CONFIG.M00_S00_WRITE_CONNECTIVITY {1} \
#   CONFIG.M01_S00_READ_CONNECTIVITY {1} \
#   CONFIG.M01_S00_WRITE_CONNECTIVITY {1} \
# ] [get_ips $ipName]

# # Adding CDMA
# set_property -dict [list \
#   CONFIG.PROTOCOL {AXI4} \
#   CONFIG.NUM_SI {2} \
#   CONFIG.NUM_MI {2} \
#   CONFIG.ADDR_WIDTH {32} \
#   CONFIG.DATA_WIDTH {64} \
#   CONFIG.ID_WIDTH {4} \
#   CONFIG.S00_THREAD_ID_WIDTH {3} \
#   CONFIG.S01_THREAD_ID_WIDTH {3} \
#   CONFIG.S00_BASE_ID {0x0} \
#   CONFIG.S01_BASE_ID {0x8} \
#   CONFIG.S00_SINGLE_THREAD {0} \
#   CONFIG.S01_SINGLE_THREAD {0} \
#     CONFIG.ADDR_RANGES {2} \
#     CONFIG.M00_A00_BASE_ADDR {0x0000000000000000} \
#     CONFIG.M00_A00_ADDR_WIDTH {27} \
#     CONFIG.M00_A01_BASE_ADDR {0x0000000080000000} \
#     CONFIG.M00_A01_ADDR_WIDTH {27} \
#     CONFIG.M01_A00_BASE_ADDR {0x00000000100A0000} \
#     CONFIG.M01_A00_ADDR_WIDTH {12} \
#   CONFIG.M00_S00_READ_CONNECTIVITY  {1} \
#   CONFIG.M00_S00_WRITE_CONNECTIVITY {1} \
#   CONFIG.M00_S01_READ_CONNECTIVITY  {1} \
#   CONFIG.M00_S01_WRITE_CONNECTIVITY {1} \
#   CONFIG.M01_S00_READ_CONNECTIVITY  {1} \
#   CONFIG.M01_S00_WRITE_CONNECTIVITY {1} \
#   CONFIG.M01_S01_READ_CONNECTIVITY  {0} \
#   CONFIG.M01_S01_WRITE_CONNECTIVITY {0} \
# ] [get_ips $ipName]
# #  CONFIG.M01_A00_ADDR_WIDTH {27}
# #   CONFIG.M01_A00_BASE_ADDR {0x0000000008000000}
# #   CONFIG.M01_A00_ADDR_WIDTH {12}

# CDMA with increased READ_ACCEPTANCE and WRITE_ACCEPTANCE
set_property -dict [list \
  CONFIG.PROTOCOL {AXI4} \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {2} \
  CONFIG.ADDR_WIDTH {32} \
  CONFIG.DATA_WIDTH {64} \
  CONFIG.ID_WIDTH {4} \
  CONFIG.S00_WRITE_ACCEPTANCE {16} \
  CONFIG.S01_WRITE_ACCEPTANCE {16} \
  CONFIG.S00_READ_ACCEPTANCE  {16} \
  CONFIG.S01_READ_ACCEPTANCE  {16} \
  CONFIG.M00_WRITE_ISSUING {16} \
  CONFIG.M00_READ_ISSUING  {16} \
  CONFIG.M01_WRITE_ISSUING {16} \
  CONFIG.M01_READ_ISSUING  {16} \
  CONFIG.S00_THREAD_ID_WIDTH {3} \
  CONFIG.S01_THREAD_ID_WIDTH {3} \
  CONFIG.S00_BASE_ID {0x0} \
  CONFIG.S01_BASE_ID {0x8} \
  CONFIG.S00_SINGLE_THREAD {0} \
  CONFIG.S01_SINGLE_THREAD {0} \
    CONFIG.ADDR_RANGES {2} \
    CONFIG.M00_A00_BASE_ADDR {0x0000000000000000} \
    CONFIG.M00_A00_ADDR_WIDTH {27} \
    CONFIG.M00_A01_BASE_ADDR {0x0000000080000000} \
    CONFIG.M00_A01_ADDR_WIDTH {27} \
    CONFIG.M01_A00_BASE_ADDR {0x00000000100A0000} \
    CONFIG.M01_A00_ADDR_WIDTH {12} \
  CONFIG.M00_S00_READ_CONNECTIVITY  {1} \
  CONFIG.M00_S00_WRITE_CONNECTIVITY {1} \
  CONFIG.M00_S01_READ_CONNECTIVITY  {1} \
  CONFIG.M00_S01_WRITE_CONNECTIVITY {1} \
  CONFIG.M01_S00_READ_CONNECTIVITY  {1} \
  CONFIG.M01_S00_WRITE_CONNECTIVITY {1} \
  CONFIG.M01_S01_READ_CONNECTIVITY  {0} \
  CONFIG.M01_S01_WRITE_CONNECTIVITY {0} \
] [get_ips $ipName]



generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]

create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1

