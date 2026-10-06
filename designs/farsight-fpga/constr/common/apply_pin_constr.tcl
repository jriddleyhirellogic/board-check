# ------------------------------------------------------------------------------
# Author     : Saba Janamian
# Origin date: 6/26/2024
# Description: Utility script to populate pin constraint in Libero
# ------------------------------------------------------------------------------

proc apply_pin_constraints { ports pin_map } {
    puts [string repeat "~*" 20]

    foreach port $ports {

        set fw_port  [lindex $port 0]
        set pcb_port [lindex $port 1]

        if {[llength $port] >= 3} {
            # The third element should be dictionary of properties
            set prop [lindex $port 2]
        } else {
            set prop {}
        }

        # Look for the pcb_port in the pin_map
        if {[dict exists $pin_map $pcb_port]} {
            set constr [dict get $pin_map $pcb_port]

            if {[string length $constr] > 0} {

                set pin_name [dict get $constr pin_name]

                set args_dict [dict create]

                dict for {key value} $constr {
                    if {$key != "pin_name"} {
                        dict set args_dict $key $value
                    }
                }

                if {[dict size $prop] > 0} {
                    dict for {key value} $prop {
                        dict set args_dict $key $value
                    }
                }

                set args_list {}

                lappend args_list -port_name $fw_port
                lappend args_list -pin_name $pin_name

                dict for {key value} $args_dict {
                    lappend args_list "-$key" $value
                }

                puts $args_list

                set_io {*}$args_list

            } else {
                error "ERROR: No constraints found for $pcb_port in pin_map"
            }
        } else {
            error "ERROR: Could not find $pcb_port in pin_map"
        }
    }
   puts [string repeat "~*" 20]
}
