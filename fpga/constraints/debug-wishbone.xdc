# Helper functions
# Safe ILA probe helper:

# reuse probe0 version
# Internal state (per ILA core) to ensure probe0 is consumed only once
namespace eval ::ila_util {
    variable probe0_used
    array set probe0_used {}
}

proc ila_add_probe {ila args} {
    # ---- persistent state (per ILA core instance) ----
    global ila_probe0_used ila_core_obj
    set core_obj [get_debug_cores -quiet $ila]
    if {$core_obj eq ""} { error "ila_add_probe: debug core '$ila' not found" }

    # Reset state if this ILA core object changed (core recreated / new run context)
    if {![info exists ila_core_obj($ila)] || $ila_core_obj($ila) ne $core_obj} {
        set ila_core_obj($ila) $core_obj
        set ila_probe0_used($ila) 0
    }
    if {![info exists ila_probe0_used($ila)]} { set ila_probe0_used($ila) 0 }

    # ---- args ----
    set width ""
    set ptype "DATA_AND_TRIGGER"
    set patterns [list]
    set net_objs ""
    set bus_base ""
    set msb ""
    set lsb ""
    set order "lsb2msb"

    set i 0
    set argc [llength $args]
    while {$i < $argc} {
        set opt [lindex $args $i]
        incr i

        if {$opt eq "-width"} {
            if {$i >= $argc} { error "ila_add_probe: -width needs a value" }
            set width [lindex $args $i]; incr i
        } elseif {$opt eq "-type"} {
            if {$i >= $argc} { error "ila_add_probe: -type needs a value" }
            set ptype [lindex $args $i]; incr i
        } elseif {$opt eq "-net"} {
            if {$i >= $argc} { error "ila_add_probe: -net needs a value" }
            set patterns [list [lindex $args $i]]; incr i
        } elseif {$opt eq "-nets"} {
            if {$i >= $argc} { error "ila_add_probe: -nets needs a value (list)" }
            set patterns [lindex $args $i]; incr i
        } elseif {$opt eq "-objs"} {
            if {$i >= $argc} { error "ila_add_probe: -objs needs a value" }
            set net_objs [lindex $args $i]; incr i
        } elseif {$opt eq "-bus"} {
            if {$i >= $argc} { error "ila_add_probe: -bus needs a value" }
            set bus_base [lindex $args $i]; incr i
        } elseif {$opt eq "-msb"} {
            if {$i >= $argc} { error "ila_add_probe: -msb needs a value" }
            set msb [lindex $args $i]; incr i
        } elseif {$opt eq "-lsb"} {
            if {$i >= $argc} { error "ila_add_probe: -lsb needs a value" }
            set lsb [lindex $args $i]; incr i
        } elseif {$opt eq "-order"} {
            if {$i >= $argc} { error "ila_add_probe: -order needs a value" }
            set order [lindex $args $i]; incr i
        } else {
            error "ila_add_probe: unknown option '$opt'"
        }
    }

    # ---- bus expand ----
    if {$bus_base ne ""} {
        if {$msb eq "" || $lsb eq ""} { error "ila_add_probe: -bus requires -msb and -lsb" }
        set patterns [list]
        if {$order eq "lsb2msb"} {
            for {set b $lsb} {$b <= $msb} {incr b} { lappend patterns "${bus_base}\[$b\]" }
        } elseif {$order eq "msb2lsb"} {
            for {set b $msb} {$b >= $lsb} {incr b -1} { lappend patterns "${bus_base}\[$b\]" }
        } else {
            error "ila_add_probe: -order must be lsb2msb or msb2lsb"
        }
    }

    # ---- resolve nets ----
    if {$net_objs ne ""} {
        set nets $net_objs
    } else {
        if {[llength $patterns] == 0} { error "ila_add_probe: provide -net/-nets/-objs or -bus/-msb/-lsb" }
        set nets [list]
        foreach p $patterns {
            # literal match for names containing [n]
            set m [get_nets -quiet [list $p]]
            if {[llength $m] == 0} { set m [get_nets -hier -quiet [list $p]] }
            if {[llength $m] == 0} { error "ila_add_probe: matched 0 nets for '$p'" }
            if {[llength $m] != 1} { error "ila_add_probe: '$p' matched [llength $m] nets; make it unique" }
            lappend nets [lindex $m 0]
        }
    }

    set n [llength $nets]
    if {$width eq ""} { set width $n }
    if {$width != $n} { error "ila_add_probe: width $width but resolved $n nets" }

    # ---- choose port: reuse probe0 ONCE, then create new probes ----
    set probes [get_debug_ports -quiet ${ila}/probe*]
    if {$ila_probe0_used($ila) == 0 &&
        [llength $probes] == 1 &&
        [lindex $probes 0] eq "${ila}/probe0"} {

        set port_obj [get_debug_ports ${ila}/probe0]
        set ila_probe0_used($ila) 1
    } else {
        set port_obj [create_debug_port $ila probe]   ;# returns object
    }

    set_property port_width $width $port_obj
    set_property PROBE_TYPE  $ptype $port_obj
    connect_debug_port $port_obj $nets

    return $port_obj
}

create_debug_core u_ila_0 ila

# ILA settings
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
# startgroup
# set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0 ]
# set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0 ]
# set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0 ]
# set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0 ]
# endgroup
# Test change (ChatGPT)
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets CPUCLK]
# changed for sampling AXI STUFF!!
#connect_debug_port u_ila_0/clk [get_nets BUSCLK]


# PC
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/core/PCM -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -net wallypipelinedsoc/core/TrapM
# ila_add_probe u_ila_0 -net wallypipelinedsoc/core/InstrValidM

# # One-line bus expansion (matches your original 0..31 bit ordering)
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/core/InstrM -msb 31 -lsb 0 -order lsb2msb
# AHB signals
ila_add_probe u_ila_0 -bus wallypipelinedsoc/core/ebu.ebu/HADDR -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/core/ebu.ebu/HTRANS -msb 1 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_0 -bus wallypipelinedsoc/core/ebu.ebu/HSIZE -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/core/HSIZE -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/core/HWDATA -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/LSUHWSTRB -msb 7 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_0 -net wallypipelinedsoc/core/HREADY
ila_add_probe u_ila_0 -net wallypipelinedsoc/HREADY
#ila_add_probe u_ila_0 -net wallypipelinedsoc/core/HRESP
#ila_add_probe u_ila_0 -net wallypipelinedsoc/core/HSELEXT
# ila_add_probe u_ila_0 -net HSELEXT
# ila_add_probe u_ila_0 -net HWRITE
#ila_add_probe u_ila_0 -net HSELAXIDMA
ila_add_probe u_ila_0 -net HSELAXIVGA
#ila_add_probe u_ila_0 -bus HRDATAEXT -msb 63 -lsb 0 -order lsb2msb



# WB signals?
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/HREADWbIsland -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/HRESPWbIsland
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/HREADYWbIsland
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/HSELWbIsland
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/HSELWbIslandD
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/wb_adr -msb 29 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/wb_wdat -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/wb_rdat -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/wb_sel -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb_we
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb_cyc
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb_stb
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb_ack
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb_err

# WB UART probes
# wb_adr_i: [4:3] are optimized away
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/u_uart/u_uart/wb_adr_i -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/u_uart/u_uart/wb_sel_i -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/u_uart/u_uart/wb_dat_i -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/u_uart/u_uart/wb_dat_o -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/u_uart/u_uart/we_o
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/u_uart/u_uart/wb_interface/wb_we_i
# WB Ethernet probes
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/eth_cyc
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/eth_stb
# ila_add_probe u_ila_0 -bus wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/eth_dat_r -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/eth_ack
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/eth_err
# ila_add_probe u_ila_0 -net wallypipelinedsoc/uncoregen.uncore/wb.u_wb_island/hit_eth


# # the debug hub has issues with the clocks from the mmcm so lets give up an connect to the 100Mhz input clock.
# connect_debug_port dbg_hub/clk [get_nets default_100mhz_clk]
# #connect_debug_port dbg_hub/clk [get_nets CPUCLK]



###################################################################################33
###################################################################################33
###################################################################################33
#### AXI ILA PROBES
###################################################################################33
create_debug_core u_ila_axi ila

# ILA settings
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_axi]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_axi]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_axi]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_axi]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_axi]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_axi]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_axi]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_axi]
# startgroup
# set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0 ]
# set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0 ]
# set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0 ]
# set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0 ]
# endgroup
# Test change (ChatGPT)
set_property port_width 1 [get_debug_ports u_ila_axi/clk]
# changed for sampling AXI STUFF!!
#connect_debug_port u_ila_axi/clk [get_nets CPUCLK]
connect_debug_port u_ila_axi/clk [get_nets BUSCLK]


# Crossbar slave side


# AXI CROSSBAR PROBES
# BUS_cb_axi_*: (master) signals going from crossbar to MIG (DDR)
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arregion -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arqos  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awregion  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awqos  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awsize  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awcache  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_awaddr   -msb 31 -lsb 0 -order lsb2msb
# # ila_add_probe u_ila_axi -bus BUS_cb_axi_awprot  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_awvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_awready
# ila_add_probe u_ila_axi -net BUS_cb_axi_awlock
# ila_add_probe u_ila_axi -bus BUS_cb_axi_wdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_wstrb -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_wlast
# ila_add_probe u_ila_axi -net BUS_cb_axi_wvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_wready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_bid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_bvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_bready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arsize  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_arprot  -msb 2 -lsb 0 -order lsb2msb
#   ila_add_probe u_ila_axi -bus BUS_cb_axi_arcache  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_arvalid
# ila_add_probe u_ila_axi -bus BUS_cb_axi_araddr  -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_arlock
# ila_add_probe u_ila_axi -net BUS_cb_axi_arready
# ila_add_probe u_ila_axi -bus BUS_cb_axi_rid  -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_rdata -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus BUS_cb_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net BUS_cb_axi_rvalid
# ila_add_probe u_ila_axi -net BUS_cb_axi_rlast
# ila_add_probe u_ila_axi -net BUS_cb_axi_rready


# ** cb_m_axi signals ** : full master side of crossbar (slave side of peripherals) ()
# ila_add_probe u_ila_axi -bus cb_m_axi_awvalid  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_wvalid  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_wready  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_bready -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_bvalid -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus cb_m_axi_arvalid -msb 2 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus cb_m_axi_arlen -msb 23 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_arlen -msb 23 -lsb 16 -order lsb2msb
ila_add_probe u_ila_axi -bus cb_m_axi_arsize -msb 8 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus cb_m_axi_arburst -msb 5 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus cb_m_axi_arid -msb 3 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus cb_m_axi_araddr -msb 95 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_araddr -msb 95 -lsb 64 -order lsb2msb
ila_add_probe u_ila_axi -bus cb_m_axi_arready -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus cb_m_axi_rready -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus cb_m_axi_rvalid -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus cb_m_axi_rresp -msb 5 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus cb_m_axi_rdata -msb 191 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_rdata -msb 191 -lsb 128 -order lsb2msb
ila_add_probe u_ila_axi -bus cb_m_axi_rlast -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cb_m_axi_wlast -msb 2 -lsb 0 -order lsb2msb
#CDMA
# ila_add_probe u_ila_axi -net cdma_m_axi_awvalid
# ila_add_probe u_ila_axi -net cdma_m_axi_awready 
# ila_add_probe u_ila_axi -bus cdma_m_axi_awaddr -msb 31 -lsb 0 -order lsb2msb 
# ila_add_probe u_ila_axi -bus cdma_m_axi_awlen -msb 7 -lsb 0 -order lsb2msb 
# ila_add_probe u_ila_axi -net cdma_m_axi_wvalid 
# ila_add_probe u_ila_axi -net cdma_m_axi_wready 
# ila_add_probe u_ila_axi -net cdma_m_axi_wlast
# ila_add_probe u_ila_axi -net cdma_m_axi_bvalid 
# ila_add_probe u_ila_axi -bus cdma_m_axi_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net cdma_m_axi_arvalid 
# ila_add_probe u_ila_axi -net cdma_m_axi_arready 
# ila_add_probe u_ila_axi -bus cdma_m_axi_araddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cdma_m_axi_arlen -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net cdma_m_axi_rvalid
# ila_add_probe u_ila_axi -net cdma_m_axi_rready
# ila_add_probe u_ila_axi -net cdma_m_axi_rlast
# ila_add_probe u_ila_axi -bus cdma_m_axi_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cdma_m_axi_arsize  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cdma_m_axi_arburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cdma_m_axi_awsize  -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cdma_m_axi_awburst -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus cdma_m_axi_wstrb   -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net cdma_m_axi_bready


# ila_add_probe u_ila_axi -net reg_arready

# ila_add_probe u_ila_axi -net dw_m_arvalid
# ila_add_probe u_ila_axi -net dw_m_arready
# ila_add_probe u_ila_axi -bus dw_m_araddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net pc_lite_arready
# ila_add_probe u_ila_axi -net pc_lite_arvalid
# ila_add_probe u_ila_axi -bus pc_lite_araddr -msb 31 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_axi -net pc_lite_awvalid 
# ila_add_probe u_ila_axi -net pc_lite_awready 
# ila_add_probe u_ila_axi -bus pc_lite_awaddr -msb 5 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net pc_lite_wvalid 
# ila_add_probe u_ila_axi -net pc_lite_wready 
# ila_add_probe u_ila_axi -bus pc_lite_wdata -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net pc_lite_bvalid
# ila_add_probe u_ila_axi -bus pc_lite_bresp -msb 1 -lsb 0 -order lsb2msb

# VGA AXI regbus signals

# ila_add_probe u_ila_axi -net vga_reg_awready
# ila_add_probe u_ila_axi -net vga_reg_wready
# ila_add_probe u_ila_axi -net vga_reg_arready
# ila_add_probe u_ila_axi -net vga_reg_bvalid
# ila_add_probe u_ila_axi -bus vga_reg_bresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus vga_reg_bid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -net vga_reg_rvalid
# ila_add_probe u_ila_axi -net vga_reg_rlast
# ila_add_probe u_ila_axi -bus vga_reg_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus vga_reg_rid -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus vga_reg_rdata -msb 63 -lsb 0 -order lsb2msb

# AXI-regbus converter signals
#ila_add_probe u_ila_axi -net reg_req.valid
#ila_add_probe u_ila_axi -net axi_vga_wrap_i/i_axi_vga/reg_req_i[valid]
# ila_add_probe u_ila_axi -net axi_vga_wrap_i/i_axi_vga/reg_req_i[valid]
#ila_add_probe u_ila_axi -net [get_nets -hier -regexp {^axi_vga_wrap_i/i_axi_vga/reg_req_i\[valid\]$}]
ila_add_probe u_ila_axi -net axi_vga_wrap_i/dbg_reg_req_valid
#ila_add_probe u_ila_axi -net [get_nets -hier -regexp {^axi_vga_wrap_i/i_axi_vga/reg_req_i\[write\]$}]
ila_add_probe u_ila_axi -net axi_vga_wrap_i/dbg_reg_req_write
#ila_add_probe u_ila_axi -bus axi_vga_wrap_i/i_axi_vga/reg_req_i[addr] -msb 11 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus [get_nets -hier -regexp {axi_vga_wrap_i/i_axi_vga/reg_req_i\[addr\]\[[0-9]+\]$}] -msb 11 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus axi_vga_wrap_i/dbg_reg_req_addr -msb 11 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -bus [get_nets -hier -regexp {axi_vga_wrap_i/i_axi_vga/reg_req_i\[wdata\]\[[0-9]+\]$}] -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_axi -bus dbg_reg_req_wdata -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus axi_vga_wrap_i/dbg_reg_rsp_rdata -msb 31 -lsb 0 -order lsb2msb
#ila_add_probe u_ila_axi -net [get_nets -hier -regexp {^axi_vga_wrap_i/i_axi_vga/reg_rsp_o\[error\]$}]
ila_add_probe u_ila_axi -net axi_vga_wrap_i/dbg_reg_rsp_error
#ila_add_probe u_ila_axi -net axi_vga_wrap_i/i_axi_vga/reg_rsp_i[ready]
#ila_add_probe u_ila_axi -net [get_nets -hier -regexp {^axi_vga_wrap_i/i_axi_vga/reg_rsp_o\[ready\]$}]
ila_add_probe u_ila_axi -net dbg_reg_rsp_ready

# AXI bus from VGA master
ila_add_probe u_ila_axi -bus vga_m_axi_araddr -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus vga_m_axi_arlen -msb 7 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -bus vga_m_axi_arsize -msb 2 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net vga_m_axi_arvalid
ila_add_probe u_ila_axi -net vga_m_axi_arready
ila_add_probe u_ila_axi -bus vga_m_axi_rresp -msb 1 -lsb 0 -order lsb2msb
ila_add_probe u_ila_axi -net vga_m_axi_rlast
ila_add_probe u_ila_axi -net vga_m_axi_rvalid
ila_add_probe u_ila_axi -net vga_m_axi_rready

##########################################################3

# This is a GLOBAL setting (not ILA instance specific)
# # the debug hub has issues with the clocks from the mmcm so lets give up an connect to the 100Mhz input clock.
# connect_debug_port dbg_hub/clk [get_nets default_100mhz_clk]
# #connect_debug_port dbg_hub/clk [get_nets CPUCLK]
connect_debug_port dbg_hub/clk [get_nets default_100mhz_clk]


