namespace eval ::ila_util {
    variable probe0_used
    array set probe0_used {}
}

proc ila_resolve_one_net {p} {
    set m [get_nets -quiet [list $p]]
    if {[llength $m] == 0 && [string first "/" $p] >= 0} {
        set pf [string map [list "\\" "\\\\" "\"" "\\\""] $p]
        set m [get_nets -hier -quiet -filter "NAME == \"$pf\""]
    }
    if {[llength $m] == 0} { return "" }
    if {[llength $m] != 1} { error "ila_add_probe: '$p' matched [llength $m] nets; make it unique" }
    return [lindex $m 0]
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
        if {$msb eq "auto"} {
            if {$order ne "lsb2msb"} { error "ila_add_probe: -msb auto requires -order lsb2msb" }
            set seen_missing 0
            for {set b $lsb} {$b < 1024} {incr b} {
                set p "${bus_base}\[$b\]"
                set m [ila_resolve_one_net $p]
                if {$m eq ""} {
                    if {$b == $lsb} { error "ila_add_probe: matched 0 nets for '$p'" }
                    set seen_missing 1
                } else {
                    if {$seen_missing} { error "ila_add_probe: non-contiguous bus '$bus_base': found bit $b after a missing lower bit" }
                    lappend patterns $p
                }
            }
        } else {
            if {$order eq "lsb2msb"} {
                for {set b $lsb} {$b <= $msb} {incr b} { lappend patterns "${bus_base}\[$b\]" }
            } elseif {$order eq "msb2lsb"} {
                for {set b $msb} {$b >= $lsb} {incr b -1} { lappend patterns "${bus_base}\[$b\]" }
            } else {
                error "ila_add_probe: -order must be lsb2msb or msb2lsb"
            }
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
            set m [ila_resolve_one_net $p]
            if {$m eq ""} { error "ila_add_probe: matched 0 nets for '$p'" }
            lappend nets $m
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
