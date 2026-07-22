##### clock #####
# Nexys A7-100T CLK100MHZ
set_property PACKAGE_PIN E3 [get_ports default_100mhz_clk]
set_property IOSTANDARD LVCMOS33 [get_ports default_100mhz_clk]

##### UART #####
set_property PACKAGE_PIN C4 [get_ports UARTSin]
set_property PACKAGE_PIN D4 [get_ports UARTSout]
set_property IOSTANDARD LVCMOS33 [get_ports UARTSin]
set_property IOSTANDARD LVCMOS33 [get_ports UARTSout]
set_property DRIVE 4 [get_ports UARTSout]

##### Simple GPI/GPO mapping to on-board buttons/LEDs #####
# Map GPO[0..4] to LD0..LD4
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {GPO[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {GPO[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {GPO[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {GPO[3]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {GPO[4]}]

# Map GPI[0..3] to BTNC/BTNU/BTNL/BTNR
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {GPI[0]}] ;# BTNC
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports {GPI[1]}] ;# BTNU
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports {GPI[2]}] ;# BTNL
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports {GPI[3]}] ;# BTNR

##### reset #####
set_property PACKAGE_PIN C12 [get_ports resetn]
set_property IOSTANDARD LVCMOS33 [get_ports resetn]


# Micro SD Connector
# ## Digilent Micro SD adapter in PMOD D ##
# 1: JD1 = H4 = CSn
# 2: JD2 = H1 = MOSI/CMD
# 3: JD3 = G1 = MISO = DATA0
# 4: JD4 = G3 = SCK
# 5: GND
# 6: 3V3
# 7: JD7 = H2 = DATA1
# 8: JD8 = G4 = DATA2
# 9: JD9 = G2 = CD
# 10: JD10 = F3 = NC
# 11: GND
# 12: 3V3
set_property -dict { PACKAGE_PIN G3 IOSTANDARD LVCMOS33 } [get_ports SDCCLK]  ;# SD_SCK
set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 } [get_ports SDCCmd]  ;# SD_CMD
set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 } [get_ports SDCIn]   ;# SD_DAT0 (MISO)
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 } [get_ports SDCCS]   ;# SD_DAT3 (CS)
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports SDCCD]   ;# SD
# pull up/down
set_property PULLTYPE PULLUP [get_ports SDCCS]
set_property PULLTYPE PULLUP [get_ports SDCIn]
set_property PULLTYPE PULLUP [get_ports SDCCmd]
set_property PULLTYPE PULLUP [get_ports SDCCD]
#set_property PULLTYPE PULLUP [get_ports SDCCLK]
#set_property PULLTYPE PULLUP [get_ports SDCWP]
create_generated_clock -name SPISDCClock -source [get_pins mmcm/clk_out3] \
  -multiply_by 1 -divide_by 1 [get_pins wallypipelinedsoc/SPICLK]
set_output_delay -clock [get_clocks SPISDCClock] -min -add_delay 2.500 [get_ports {SDCCS}]
set_output_delay -clock [get_clocks SPISDCClock] -max -add_delay 10.000 [get_ports {SDCCS}]
set_input_delay -clock [get_clocks SPISDCClock] -min -add_delay 2.500 [get_ports {SDCIn}]
set_input_delay -clock [get_clocks SPISDCClock] -max -add_delay 10.000 [get_ports {SDCIn}]
set_output_delay -clock [get_clocks SPISDCClock] -min -add_delay 2.000 [get_ports {SDCCmd}]
set_output_delay -clock [get_clocks SPISDCClock] -max -add_delay 6.000 [get_ports {SDCCmd}]
set_output_delay -clock [get_clocks SPISDCClock] 0.000 [get_ports SDCCLK]

# SD SPI signals on Nexys A7 on-board micro SD connector (disabled)
# set_property -dict { PACKAGE_PIN B1 IOSTANDARD LVCMOS33 } [get_ports SDCCLK]  ;# SD_SCK
# set_property -dict { PACKAGE_PIN C1 IOSTANDARD LVCMOS33 } [get_ports SDCCmd]  ;# SD_CMD
# set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports SDCIn]   ;# SD_DAT0 (MISO)
# set_property -dict { PACKAGE_PIN D2 IOSTANDARD LVCMOS33 } [get_ports SDCCS]   ;# SD_DAT3 (CS)
# set_property -dict { PACKAGE_PIN A1 IOSTANDARD LVCMOS33 } [get_ports SDCCD]   ;# SD_CD
# no SDCWP



##### Ethernet #####
# Nexys A7 has LAN8720A in RMII (not the MII-style pinout Arty assumes),
# keep the whole Arty “phy_*” block DISABLED

##### DDR2 #####
set_property IO_BUFFER_TYPE NONE [get_ports {ddr2_ck_n[*]} ]
set_property IO_BUFFER_TYPE NONE [get_ports {ddr2_ck_p[*]} ]

#create_clock -period 5 [get_ports sys_clk_i]

# PadFunction: IO_L23P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[0]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[0]}]
set_property PACKAGE_PIN R7 [get_ports {ddr2_dq[0]}]

# PadFunction: IO_L20N_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[1]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[1]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[1]}]
set_property PACKAGE_PIN V6 [get_ports {ddr2_dq[1]}]

# PadFunction: IO_L24P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[2]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[2]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[2]}]
set_property PACKAGE_PIN R8 [get_ports {ddr2_dq[2]}]

# PadFunction: IO_L22P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[3]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[3]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[3]}]
set_property PACKAGE_PIN U7 [get_ports {ddr2_dq[3]}]

# PadFunction: IO_L20P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[4]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[4]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[4]}]
set_property PACKAGE_PIN V7 [get_ports {ddr2_dq[4]}]

# PadFunction: IO_L19P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[5]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[5]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[5]}]
set_property PACKAGE_PIN R6 [get_ports {ddr2_dq[5]}]

# PadFunction: IO_L22N_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[6]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[6]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[6]}]
set_property PACKAGE_PIN U6 [get_ports {ddr2_dq[6]}]

# PadFunction: IO_L19N_T3_VREF_34
set_property SLEW FAST [get_ports {ddr2_dq[7]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[7]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[7]}]
set_property PACKAGE_PIN R5 [get_ports {ddr2_dq[7]}]

# PadFunction: IO_L12P_T1_MRCC_34
set_property SLEW FAST [get_ports {ddr2_dq[8]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[8]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[8]}]
set_property PACKAGE_PIN T5 [get_ports {ddr2_dq[8]}]

# PadFunction: IO_L8N_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[9]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[9]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[9]}]
set_property PACKAGE_PIN U3 [get_ports {ddr2_dq[9]}]

# PadFunction: IO_L10P_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[10]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[10]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[10]}]
set_property PACKAGE_PIN V5 [get_ports {ddr2_dq[10]}]

# PadFunction: IO_L8P_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[11]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[11]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[11]}]
set_property PACKAGE_PIN U4 [get_ports {ddr2_dq[11]}]

# PadFunction: IO_L10N_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[12]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[12]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[12]}]
set_property PACKAGE_PIN V4 [get_ports {ddr2_dq[12]}]

# PadFunction: IO_L12N_T1_MRCC_34
set_property SLEW FAST [get_ports {ddr2_dq[13]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[13]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[13]}]
set_property PACKAGE_PIN T4 [get_ports {ddr2_dq[13]}]

# PadFunction: IO_L7N_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[14]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[14]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[14]}]
set_property PACKAGE_PIN V1 [get_ports {ddr2_dq[14]}]

# PadFunction: IO_L11N_T1_SRCC_34
set_property SLEW FAST [get_ports {ddr2_dq[15]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[15]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[15]}]
set_property PACKAGE_PIN T3 [get_ports {ddr2_dq[15]}]

# PadFunction: IO_L18N_T2_34
set_property SLEW FAST [get_ports {ddr2_addr[12]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[12]}]
set_property PACKAGE_PIN N6 [get_ports {ddr2_addr[12]}]

# PadFunction: IO_L5P_T0_34
set_property SLEW FAST [get_ports {ddr2_addr[11]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[11]}]
set_property PACKAGE_PIN K5 [get_ports {ddr2_addr[11]}]

# PadFunction: IO_L15N_T2_DQS_34
set_property SLEW FAST [get_ports {ddr2_addr[10]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[10]}]
set_property PACKAGE_PIN R2 [get_ports {ddr2_addr[10]}]

# PadFunction: IO_L13P_T2_MRCC_34
set_property SLEW FAST [get_ports {ddr2_addr[9]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[9]}]
set_property PACKAGE_PIN N5 [get_ports {ddr2_addr[9]}]

# PadFunction: IO_L5N_T0_34
set_property SLEW FAST [get_ports {ddr2_addr[8]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[8]}]
set_property PACKAGE_PIN L4 [get_ports {ddr2_addr[8]}]

# PadFunction: IO_L3N_T0_DQS_34
set_property SLEW FAST [get_ports {ddr2_addr[7]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[7]}]
set_property PACKAGE_PIN N1 [get_ports {ddr2_addr[7]}]

# PadFunction: IO_L4N_T0_34
set_property SLEW FAST [get_ports {ddr2_addr[6]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[6]}]
set_property PACKAGE_PIN M2 [get_ports {ddr2_addr[6]}]

# PadFunction: IO_L13N_T2_MRCC_34
set_property SLEW FAST [get_ports {ddr2_addr[5]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[5]}]
set_property PACKAGE_PIN P5 [get_ports {ddr2_addr[5]}]

# PadFunction: IO_L2N_T0_34
set_property SLEW FAST [get_ports {ddr2_addr[4]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[4]}]
set_property PACKAGE_PIN L3 [get_ports {ddr2_addr[4]}]

# PadFunction: IO_L17N_T2_34
set_property SLEW FAST [get_ports {ddr2_addr[3]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[3]}]
set_property PACKAGE_PIN T1 [get_ports {ddr2_addr[3]}]

# PadFunction: IO_L18P_T2_34
set_property SLEW FAST [get_ports {ddr2_addr[2]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[2]}]
set_property PACKAGE_PIN M6 [get_ports {ddr2_addr[2]}]

# PadFunction: IO_L14P_T2_SRCC_34
set_property SLEW FAST [get_ports {ddr2_addr[1]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[1]}]
set_property PACKAGE_PIN P4 [get_ports {ddr2_addr[1]}]

# PadFunction: IO_L16P_T2_34
set_property SLEW FAST [get_ports {ddr2_addr[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[0]}]
set_property PACKAGE_PIN M4 [get_ports {ddr2_addr[0]}]

# PadFunction: IO_L17P_T2_34
set_property SLEW FAST [get_ports {ddr2_ba[2]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_ba[2]}]
set_property PACKAGE_PIN R1 [get_ports {ddr2_ba[2]}]

# PadFunction: IO_L14N_T2_SRCC_34
set_property SLEW FAST [get_ports {ddr2_ba[1]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_ba[1]}]
set_property PACKAGE_PIN P3 [get_ports {ddr2_ba[1]}]

# PadFunction: IO_L15P_T2_DQS_34
set_property SLEW FAST [get_ports {ddr2_ba[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_ba[0]}]
set_property PACKAGE_PIN P2 [get_ports {ddr2_ba[0]}]

# PadFunction: IO_L16N_T2_34
set_property SLEW FAST [get_ports {ddr2_ras_n}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_ras_n}]
set_property PACKAGE_PIN N4 [get_ports {ddr2_ras_n}]

# PadFunction: IO_L1P_T0_34
set_property SLEW FAST [get_ports {ddr2_cas_n}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_cas_n}]
set_property PACKAGE_PIN L1 [get_ports {ddr2_cas_n}]

# PadFunction: IO_L3P_T0_DQS_34
set_property SLEW FAST [get_ports {ddr2_we_n}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_we_n}]
set_property PACKAGE_PIN N2 [get_ports {ddr2_we_n}]

# PadFunction: IO_L1N_T0_34
set_property SLEW FAST [get_ports {ddr2_cke[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_cke[0]}]
set_property PACKAGE_PIN M1 [get_ports {ddr2_cke[0]}]

# PadFunction: IO_L4P_T0_34
set_property SLEW FAST [get_ports {ddr2_odt[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_odt[0]}]
set_property PACKAGE_PIN M3 [get_ports {ddr2_odt[0]}]

# PadFunction: IO_0_34
set_property SLEW FAST [get_ports {ddr2_cs_n[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_cs_n[0]}]
set_property PACKAGE_PIN K6 [get_ports {ddr2_cs_n[0]}]

# PadFunction: IO_L23N_T3_34
set_property SLEW FAST [get_ports {ddr2_dm[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dm[0]}]
set_property PACKAGE_PIN T6 [get_ports {ddr2_dm[0]}]

# PadFunction: IO_L7P_T1_34
set_property SLEW FAST [get_ports {ddr2_dm[1]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dm[1]}]
set_property PACKAGE_PIN U1 [get_ports {ddr2_dm[1]}]

# PadFunction: IO_L21P_T3_DQS_34
set_property SLEW FAST [get_ports {ddr2_dqs_p[0]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dqs_p[0]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_dqs_p[0]}]
set_property PACKAGE_PIN U9 [get_ports {ddr2_dqs_p[0]}]

# PadFunction: IO_L21N_T3_DQS_34
set_property SLEW FAST [get_ports {ddr2_dqs_n[0]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dqs_n[0]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_dqs_n[0]}]
set_property PACKAGE_PIN V9 [get_ports {ddr2_dqs_n[0]}]

# PadFunction: IO_L9P_T1_DQS_34
set_property SLEW FAST [get_ports {ddr2_dqs_p[1]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dqs_p[1]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_dqs_p[1]}]
set_property PACKAGE_PIN U2 [get_ports {ddr2_dqs_p[1]}]

# PadFunction: IO_L9N_T1_DQS_34
set_property SLEW FAST [get_ports {ddr2_dqs_n[1]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dqs_n[1]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_dqs_n[1]}]
set_property PACKAGE_PIN V2 [get_ports {ddr2_dqs_n[1]}]

# PadFunction: IO_L6P_T0_34
set_property SLEW FAST [get_ports {ddr2_ck_p[0]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_ck_p[0]}]
set_property PACKAGE_PIN L6 [get_ports {ddr2_ck_p[0]}]

# PadFunction: IO_L6N_T0_VREF_34
set_property SLEW FAST [get_ports {ddr2_ck_n[0]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_ck_n[0]}]
set_property PACKAGE_PIN L5 [get_ports {ddr2_ck_n[0]}]


set_property INTERNAL_VREF  0.900 [get_iobanks 34]



#####################################33
# WISHBONE peripherals
#####################################

# UART: PMOD A, RX=JA1=C17 TX=JA2=D18
set_property PACKAGE_PIN C17 [get_ports WB_UART_RX]
set_property PACKAGE_PIN D18 [get_ports WB_UART_TX]
set_property IOSTANDARD LVCMOS33 [get_ports WB_UART_RX]
set_property IOSTANDARD LVCMOS33 [get_ports WB_UART_TX]
# fixme: check this
set_property DRIVE 4 [get_ports WB_UART_TX]


# Ethernet
##SMSC Ethernet PHY ()
set_property -dict { PACKAGE_PIN C9    IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_MDC }]; #IO_L11P_T1_SRCC_16 Sch=eth_mdc
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_MDIO }]; #IO_L14N_T2_SRCC_16 Sch=eth_mdio
set_property -dict { PACKAGE_PIN B3    IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_RST_N }]; #IO_L10P_T1_AD15P_35 Sch=eth_rstn
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_CRS_DV }]; #IO_L6N_T0_VREF_16 Sch=eth_crsdv
# RXERR not used?
# ETH_RXERR is not a port of fpgaTop; leave its board pin unconstrained.
#set_property -dict { PACKAGE_PIN C10   IOSTANDARD LVCMOS33 } [get_ports { ETH_RXERR }]; #IO_L13N_T2_MRCC_16 Sch=eth_rxerr
set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_RX_DATA[0] }]; #IO_L13P_T2_MRCC_16 Sch=eth_rxd[0]
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_RX_DATA[1] }]; #IO_L19N_T3_VREF_16 Sch=eth_rxd[1]
set_property -dict { PACKAGE_PIN B9    IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_TX_EN }]; #IO_L11N_T1_SRCC_16 Sch=eth_txen
set_property -dict { PACKAGE_PIN A10   IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_TX_DATA[0] }]; #IO_L14P_T2_SRCC_16 Sch=eth_txd[0]
set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_TX_DATA[1] }]; #IO_L12N_T1_MRCC_16 Sch=eth_txd[1]
#set_property -dict { PACKAGE_PIN D5    IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_REF_CLK }]; #IO_L11P_T1_SRCC_35 Sch=eth_refclk
set_property PACKAGE_PIN D5 [get_ports {WB_RMII_REF_CLK}]
set_property IOSTANDARD LVCMOS33 [get_ports {WB_RMII_REF_CLK}]
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rmii_ref_clk]
# PHY interrupt
set_property -dict { PACKAGE_PIN B8    IOSTANDARD LVCMOS33 } [get_ports { WB_RMII_PHY_IRQ }]; #IO_L12P_T1_MRCC_16 Sch=eth_intn


# AXI VGA
##VGA Connector
set_property -dict { PACKAGE_PIN A3    IOSTANDARD LVCMOS33 } [get_ports { vga_r_4[0] }]; #IO_L8N_T1_AD14N_35 Sch=vga_r[0]
set_property -dict { PACKAGE_PIN B4    IOSTANDARD LVCMOS33 } [get_ports { vga_r_4[1] }]; #IO_L7N_T1_AD6N_35 Sch=vga_r[1]
set_property -dict { PACKAGE_PIN C5    IOSTANDARD LVCMOS33 } [get_ports { vga_r_4[2] }]; #IO_L1N_T0_AD4N_35 Sch=vga_r[2]
set_property -dict { PACKAGE_PIN A4    IOSTANDARD LVCMOS33 } [get_ports { vga_r_4[3] }]; #IO_L8P_T1_AD14P_35 Sch=vga_r[3]
set_property -dict { PACKAGE_PIN C6    IOSTANDARD LVCMOS33 } [get_ports { vga_g_4[0] }]; #IO_L1P_T0_AD4P_35 Sch=vga_g[0]
set_property -dict { PACKAGE_PIN A5    IOSTANDARD LVCMOS33 } [get_ports { vga_g_4[1] }]; #IO_L3N_T0_DQS_AD5N_35 Sch=vga_g[1]
set_property -dict { PACKAGE_PIN B6    IOSTANDARD LVCMOS33 } [get_ports { vga_g_4[2] }]; #IO_L2N_T0_AD12N_35 Sch=vga_g[2]
set_property -dict { PACKAGE_PIN A6    IOSTANDARD LVCMOS33 } [get_ports { vga_g_4[3] }]; #IO_L3P_T0_DQS_AD5P_35 Sch=vga_g[3]
set_property -dict { PACKAGE_PIN B7    IOSTANDARD LVCMOS33 } [get_ports { vga_b_4[0] }]; #IO_L2P_T0_AD12P_35 Sch=vga_b[0]
set_property -dict { PACKAGE_PIN C7    IOSTANDARD LVCMOS33 } [get_ports { vga_b_4[1] }]; #IO_L4N_T0_35 Sch=vga_b[1]
set_property -dict { PACKAGE_PIN D7    IOSTANDARD LVCMOS33 } [get_ports { vga_b_4[2] }]; #IO_L6N_T0_VREF_35 Sch=vga_b[2]
set_property -dict { PACKAGE_PIN D8    IOSTANDARD LVCMOS33 } [get_ports { vga_b_4[3] }]; #IO_L4P_T0_35 Sch=vga_b[3]
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { vga_hsync }]; #IO_L4P_T0_15 Sch=vga_hs
set_property -dict { PACKAGE_PIN B12   IOSTANDARD LVCMOS33 } [get_ports { vga_vsync }]; #IO_L3N_T0_DQS_AD1N_15 Sch=vga_vs

# AXI USB: JC: JC1=K1=V2P JC2=F6=V1P JC7=E7=V2N JC8=J3=V1N
set_property -dict { PACKAGE_PIN F6    IOSTANDARD LVCMOS33 } [get_ports { usb0_dp }];
set_property -dict { PACKAGE_PIN J3    IOSTANDARD LVCMOS33 } [get_ports { usb0_dm }];
set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { usb1_dp }];
set_property -dict { PACKAGE_PIN E7    IOSTANDARD LVCMOS33 } [get_ports { usb1_dm }];
# Not enough but helps
set_property PULLDOWN true [get_ports {usb0_dp usb0_dm usb1_dp usb1_dm}]

# I2S2: PMOD JB
# Tested: Dollatek PCM5102A, not exactly but similar to: https://github.com/pschatzmann/arduino-audio-tools/discussions/1641
# 1:    JB1 => D14 => LCLK (44.12 KHz)
# 2:    JB2 => F16 => BCK (bit clock, 2.824 Mhz)
# 3:    JB3 => G16 => DIN (data)
# 4:    JB4 => H14 => MCLK (22.59 MHz) => SHOULD NOT be connected in Dollatek board
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports {i2s_tx_lrck}]
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports {i2s_tx_sclk}]
set_property -dict { PACKAGE_PIN G16 IOSTANDARD LVCMOS33 } [get_ports {i2s_tx_sdout}]
# For the DAC tested this signal is not connected (derived), but it needed XMT=3.3V
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports {i2s_tx_mclk}]


# SDHCI
##Micro SD Connector
set_property -dict { PACKAGE_PIN E2    IOSTANDARD LVCMOS33 } [get_ports { SD_RESET }]; #IO_L14P_T2_SRCC_35 Sch=sd_reset
set_property -dict { PACKAGE_PIN A1    IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_CD_N }]; #IO_L9N_T1_DQS_AD7N_35 Sch=sd_cd
#set_property -dict { PACKAGE_PIN B1    IOSTANDARD LVCMOS33 } [get_ports { SD_SCK }]; #IO_L9P_T1_DQS_AD7P_35 Sch=sd_sck
set_property -dict { PACKAGE_PIN B1    IOSTANDARD LVCMOS33 } [get_ports { SD_CLK }]; #IO_L9P_T1_DQS_AD7P_35 Sch=sd_sck
set_property -dict { PACKAGE_PIN C1    IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_CMD }]; #IO_L16N_T2_35 Sch=sd_cmd
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_DAT[0] }]; #IO_L16P_T2_35 Sch=sd_dat[0]
set_property -dict { PACKAGE_PIN E1    IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_DAT[1] }]; #IO_L18N_T2_35 Sch=sd_dat[1]
set_property -dict { PACKAGE_PIN F1    IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_DAT[2] }]; #IO_L18P_T2_35 Sch=sd_dat[2]
set_property -dict { PACKAGE_PIN D2    IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_DAT[3] }]; #IO_L14N_T2_SRCC_35 Sch=sd_dat[3]


# # SDHCI onboard microSD connector I/Os
# set_property -dict { PACKAGE_PIN P28   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_CD_N }];   #IO_L8N_T1_D12_14 Sch=sd_cd
# set_property -dict { PACKAGE_PIN R29   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_CMD }];    #IO_L7N_T1_D10_14 Sch=sd_cmd
# set_property -dict { PACKAGE_PIN R26   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_DAT[0] }]; #IO_L10N_T1_D15_14 Sch=sd_dat[0]
# set_property -dict { PACKAGE_PIN R30   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_DAT[1] }]; #IO_L9P_T1_DQS_14 Sch=sd_dat[1]
# set_property -dict { PACKAGE_PIN P29   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_DAT[2] }]; #IO_L7P_T1_D09_14 Sch=sd_dat[2]
# set_property -dict { PACKAGE_PIN T30   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { SD_DAT[3] }]; #IO_L9N_T1_DQS_D13_14 Sch=sd_dat[3]
# set_property -dict { PACKAGE_PIN R28   IOSTANDARD LVCMOS33 } [get_ports { SD_CLK }];                    #IO_L11P_T1_SRCC_14 Sch=sd_sclk
