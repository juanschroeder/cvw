set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)

set ipName axicdma

create_project $ipName . -force -part $partNumber
if {$boardName!="ArtyA7"} {
    set_property board_part $boardName [current_project]
}

# AXI CDMA (MM2MM)
create_ip -name axi_cdma -vendor xilinx.com -library ip -module_name $ipName

# Keep this minimal:
# - Simple mode (no SG)
# - 64-bit M_AXI datapath to match your AXI4(64) crossbar/MIG world
# - 32-bit address space (Wally RV32)
# Parameter names match PG034 Table 4-1 ("User Parameters"). :contentReference[oaicite:3]{index=3}
# set_property -dict [list \
#   CONFIG.C_AXI_LITE_IS_ASYNC {0} \
#   CONFIG.C_M_AXI_DATA_WIDTH {64} \
#   CONFIG.C_M_AXI_MAX_BURST_LEN {16} \
#   CONFIG.C_USE_DATAMOVER_LITE {0} \
#   CONFIG.C_INCLUDE_DRE {0} \
#   CONFIG.C_INCLUDE_SG {0} \
#   CONFIG.C_ADDR_WIDTH {32} \
#   CONFIG.C_INCLUDE_SF {0} \
# ] [get_ips $ipName]

# setting C_M_AXI_MAX_BURST_LEN=256 to increase throughput
set_property -dict [list \
  CONFIG.C_AXI_LITE_IS_ASYNC {0} \
  CONFIG.C_M_AXI_DATA_WIDTH {64} \
  CONFIG.C_M_AXI_MAX_BURST_LEN {256} \
  CONFIG.C_USE_DATAMOVER_LITE {0} \
  CONFIG.C_INCLUDE_DRE {0} \
  CONFIG.C_INCLUDE_SG {0} \
  CONFIG.C_ADDR_WIDTH {32} \
  CONFIG.C_INCLUDE_SF {0} \
] [get_ips $ipName]


generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all                  [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run                        [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
