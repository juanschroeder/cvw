# source helper functions
source ../constraints/debug-defs.xdc

###################################################################################33
#### AXI ILA PROBES
###################################################################################33
create_debug_core u_ila_spi ila

# ILA settings
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_spi]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_spi]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_spi]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_spi]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_spi]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_spi]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_spi]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_spi]
# startgroup
# set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_spi ]
# set_property C_ADV_TRIGGER true [get_debug_cores u_ila_spi ]
# set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_spi ]
# set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_spi ]
# endgroup
# Test change (ChatGPT)
set_property port_width 1 [get_debug_ports u_ila_spi/clk]
connect_debug_port u_ila_spi/clk [get_nets CPUCLK]



# set_property port_width 64 [get_debug_ports u_ila_spi/probe0]
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_spi/probe0]
#connect_debug_port u_ila_spi/probe0 [get_nets [list {wallypipelinedsoc/core/PCM[0]} {wallypipelinedsoc/core/PCM[1]} {wallypipelinedsoc/core/PCM[2]} {wallypipelinedsoc/core/PCM[3]} {wallypipelinedsoc/core/PCM[4]} {wallypipelinedsoc/core/PCM[5]} {wallypipelinedsoc/core/PCM[6]} {wallypipelinedsoc/core/PCM[7]} {wallypipelinedsoc/core/PCM[8]} {wallypipelinedsoc/core/PCM[9]} {wallypipelinedsoc/core/PCM[10]} {wallypipelinedsoc/core/PCM[11]} {wallypipelinedsoc/core/PCM[12]} {wallypipelinedsoc/core/PCM[13]} {wallypipelinedsoc/core/PCM[14]} {wallypipelinedsoc/core/PCM[15]} {wallypipelinedsoc/core/PCM[16]} {wallypipelinedsoc/core/PCM[17]} {wallypipelinedsoc/core/PCM[18]} {wallypipelinedsoc/core/PCM[19]} {wallypipelinedsoc/core/PCM[20]} {wallypipelinedsoc/core/PCM[21]} {wallypipelinedsoc/core/PCM[22]} {wallypipelinedsoc/core/PCM[23]} {wallypipelinedsoc/core/PCM[24]} {wallypipelinedsoc/core/PCM[25]} {wallypipelinedsoc/core/PCM[26]} {wallypipelinedsoc/core/PCM[27]} {wallypipelinedsoc/core/PCM[28]} {wallypipelinedsoc/core/PCM[29]} {wallypipelinedsoc/core/PCM[30]} {wallypipelinedsoc/core/PCM[31]} {wallypipelinedsoc/core/PCM[32]} {wallypipelinedsoc/core/PCM[33]} {wallypipelinedsoc/core/PCM[34]} {wallypipelinedsoc/core/PCM[35]} {wallypipelinedsoc/core/PCM[36]} {wallypipelinedsoc/core/PCM[37]} {wallypipelinedsoc/core/PCM[38]} {wallypipelinedsoc/core/PCM[39]} {wallypipelinedsoc/core/PCM[40]} {wallypipelinedsoc/core/PCM[41]} {wallypipelinedsoc/core/PCM[42]} {wallypipelinedsoc/core/PCM[43]} {wallypipelinedsoc/core/PCM[44]} {wallypipelinedsoc/core/PCM[45]} {wallypipelinedsoc/core/PCM[46]} {wallypipelinedsoc/core/PCM[47]} {wallypipelinedsoc/core/PCM[48]} {wallypipelinedsoc/core/PCM[49]} {wallypipelinedsoc/core/PCM[50]} {wallypipelinedsoc/core/PCM[51]} {wallypipelinedsoc/core/PCM[52]} {wallypipelinedsoc/core/PCM[53]} {wallypipelinedsoc/core/PCM[54]} {wallypipelinedsoc/core/PCM[55]} {wallypipelinedsoc/core/PCM[56]} {wallypipelinedsoc/core/PCM[57]} {wallypipelinedsoc/core/PCM[58]} {wallypipelinedsoc/core/PCM[59]} {wallypipelinedsoc/core/PCM[60]} {wallypipelinedsoc/core/PCM[61]} {wallypipelinedsoc/core/PCM[62]} {wallypipelinedsoc/core/PCM[63]} ]]
ila_add_probe u_ila_spi -bus wallypipelinedsoc/core/PCM -msb 63 -lsb 0 -order lsb2msb

ila_add_probe u_ila_spi -net wallypipelinedsoc/core/TrapM
# ila_add_probe u_ila_0 -net wallypipelinedsoc/core/InstrValidM
# connect_debug_port u_ila_spi/probe3 [get_nets [list {wallypipelinedsoc/core/InstrM[0]} {wallypipelinedsoc/core/InstrM[1]} {wallypipelinedsoc/core/InstrM[2]} {wallypipelinedsoc/core/InstrM[3]} {wallypipelinedsoc/core/InstrM[4]} {wallypipelinedsoc/core/InstrM[5]} {wallypipelinedsoc/core/InstrM[6]} {wallypipelinedsoc/core/InstrM[7]} {wallypipelinedsoc/core/InstrM[8]} {wallypipelinedsoc/core/InstrM[9]} {wallypipelinedsoc/core/InstrM[10]} {wallypipelinedsoc/core/InstrM[11]} {wallypipelinedsoc/core/InstrM[12]} {wallypipelinedsoc/core/InstrM[13]} {wallypipelinedsoc/core/InstrM[14]} {wallypipelinedsoc/core/InstrM[15]} {wallypipelinedsoc/core/InstrM[16]} {wallypipelinedsoc/core/InstrM[17]} {wallypipelinedsoc/core/InstrM[18]} {wallypipelinedsoc/core/InstrM[19]} {wallypipelinedsoc/core/InstrM[20]} {wallypipelinedsoc/core/InstrM[21]} {wallypipelinedsoc/core/InstrM[22]} {wallypipelinedsoc/core/InstrM[23]} {wallypipelinedsoc/core/InstrM[24]} {wallypipelinedsoc/core/InstrM[25]} {wallypipelinedsoc/core/InstrM[26]} {wallypipelinedsoc/core/InstrM[27]} {wallypipelinedsoc/core/InstrM[28]} {wallypipelinedsoc/core/InstrM[29]} {wallypipelinedsoc/core/InstrM[30]} {wallypipelinedsoc/core/InstrM[31]} ]]

ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCLK
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCIn
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCS[0]
ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/InterruptPending -msb 1 -lsb 0 -order lsb2msb

# connect_debug_port u_ila_spi/probe12 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitFIFOWriteInc}]]
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitFIFOEmpty
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitFIFOReadInc
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitLoad
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/SDCCmd
# connect_debug_port u_ila_spi/probe17 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ShiftEdge}]]
# connect_debug_port u_ila_spi/probe18 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/SampleEdge}]]
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveShiftReg  -msb 7 -lsb 0 -order lsb2msb
# connect_debug_port u_ila_spi/probe20 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitReg[0]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitReg[1]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitReg[2]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitReg[3]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitReg[4]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitReg[5]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitReg[6]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitReg[7]} ]]
# connect_debug_port u_ila_spi/probe21 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitLoad}]]
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ShiftIn
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/SCLKenable
ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/CurrState  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/EndOfFrame
# connect_debug_port u_ila_spi/probe26 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/NextState[0]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/NextState[1]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/NextState[2]} ]]
# connect_debug_port u_ila_spi/probe27 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/BitNum[0]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/BitNum[1]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/BitNum[2]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/BitNum[3]} ]]
# connect_debug_port u_ila_spi/probe28 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/ContinueTransmit}]]
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/controller/SPICLK
# connect_debug_port u_ila_spi/probe33 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitData[0]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitData[1]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitData[2]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitData[3]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitData[4]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitData[5]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitData[6]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitData[7]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/TransmitData[8]} ]]
# connect_debug_port u_ila_spi/probe34 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveFIFOWriteInc}]]
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveFIFOReadInc
# connect_debug_port u_ila_spi/probe36 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveShiftRegEndian[0]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveShiftRegEndian[1]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveShiftRegEndian[2]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveShiftRegEndian[3]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveShiftRegEndian[4]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveShiftRegEndian[5]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveShiftRegEndian[6]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveShiftRegEndian[7]} ]]
ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveWatermark  -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveReadWatermarkLevel  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveWatermark  -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveReadWatermarkLevel  -msb 4 -lsb 0 -order lsb2msb
# connect_debug_port u_ila_spi/probe39 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveData[0]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveData[1]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveData[2]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveData[3]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveData[4]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveData[5]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveData[6]} {wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveData[7]} ]]
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveFIFOFull
ila_add_probe u_ila_spi -net wallypipelinedsoc/uncoregen.uncore/sdc.sdc/ReceiveFIFOEmpty

#######################################################
# This is a GLOBAL setting (not ILA instance specific)
# # the debug hub has issues with the clocks from the mmcm so lets give up an connect to the 100Mhz input clock.
# connect_debug_port dbg_hub/clk [get_nets default_100mhz_clk]
# #connect_debug_port dbg_hub/clk [get_nets CPUCLK]
connect_debug_port dbg_hub/clk [get_nets default_100mhz_clk]


