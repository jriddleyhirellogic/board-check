# ------------------------------------------------------------------------------
# Author     : Saba Janamian
# Origin date: 12/10/2025
# Description: Utility script to apply timing constraint in Libero
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Proc to apply input false path constraints
# ------------------------------------------------------------------------------
proc apply_input_false_path_constraints {port_list} {
    foreach port_dict $port_list {
        set port_name    [dict get $port_dict port_name]
        set clock        [dict get $port_dict clock]
        set max_delay_ns [dict get $port_dict max_delay_ns]
        set min_delay_ns [dict get $port_dict min_delay_ns]

        set_false_path  -from [get_ports $port_name]
        set_input_delay -max $max_delay_ns -clock $clock [get_ports $port_name]
        set_input_delay -min $min_delay_ns -clock $clock [get_ports $port_name]
    }
}

# ------------------------------------------------------------------------------
# Proc to apply output false path constraints
# ------------------------------------------------------------------------------
proc apply_output_false_path_constraints {port_list} {
    foreach port_dict $port_list {
        set port_name    [dict get $port_dict port_name]
        set clock        [dict get $port_dict clock]
        set max_delay_ns [dict get $port_dict max_delay_ns]
        set min_delay_ns [dict get $port_dict min_delay_ns]

        set_false_path -to [get_ports $port_name]
        set_output_delay -max $max_delay_ns -clock $clock [get_ports $port_name]
        set_output_delay -min $min_delay_ns -clock $clock [get_ports $port_name]
    }
}
