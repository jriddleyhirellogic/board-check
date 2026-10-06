# ------------------------------------------------------------------------------
# Originator: S. Janamian
# Date: 10/25/2024
# Description: Script to generate libero project, build and export bitstream
# ------------------------------------------------------------------------------
proc create_target {args} {


# ------------------------------------------------------------------------------
# Get target board
# ------------------------------------------------------------------------------
    set supported_targes [list "mpf300ts-1fcg1152i"]

    set msg2 "Supported target boards are ${supported_targes}"

    array set argValues {
        -target_board ""
    }
    # Override default values with any provided arguments
    array set argValues $args

    if { $argValues(-target_board) eq "" } {
        set msg1 "No target board has been provided."
        error "$msg1\n$msg2"
    } elseif { [lsearch -exact "$supported_targes" "$argValues(-target_board)"] == -1} {
        set msg1 "Target board not supported. $argValues(-target_board)."
        error "$msg1\n$msg2"
    } else {
        set target_board $argValues(-target_board)
    }

# ------------------------------------------------------------------------------
# Source external util scripts
# ------------------------------------------------------------------------------
    source [file join [file dirname [info script]] ./script/common/proj_util.tcl]
    source [file join [file dirname [info script]] ./script/${target_board}/proj_config.tcl]
    source [file join [file dirname [info script]] ./script/${target_board}/download.tcl]
    source [file join [file dirname [info script]] ./script/common/builder.tcl]
    source [file join [file dirname [info script]] ./script/common/export.tcl]

# ------------------------------------------------------------------------------
# Project parameters
# ------------------------------------------------------------------------------
    # Get the current time as a Unix timestamp
    set current_time    [clock seconds]
    set origin_dir      [file normalize "."]

    # Format the timestamp into the desired format
    set formatted_time  [clock format $current_time -format {%Y%m%d_%H%M%S}]
    if {[catch {
        set commit_id [string range [exec git rev-parse HEAD] 0 5]
    } result]} {
        # Command failed, use fallback value
        set commit_id "FFFF"
        puts "Error getting commit ID: $result"
    } else {
        # Command succeeded
        puts "Using commit ID: $commit_id"
    }    
    set proj_name       "lvdt_${formatted_time}"
    set export_folder   "export_lvdt_dev_${formatted_time}"
    set bd_file         {top_recursive.tcl}
    set top_module_name {top}
    set top_module      "${top_module_name}::work"

    # Set project info
    ::proj::set_proj_info                      \
        -min_version  "2024"                   \
        -addr         "$origin_dir"            \
        -constr       "constr/${target_board}" \
        -bd_folder    "bd/${target_board}"     \
        -name         "$proj_name"             \
        -force  

# ------------------------------------------------------------------------------
# Create project
# ------------------------------------------------------------------------------
    # Create and configure new project
    new_project                                   \
        -name        "[proj::get_proj_name]"      \
        -location    "[proj::get_proj_location]"  \
        -family      "$proj::die_family"          \
        -die         "$proj::die_eval"            \
        -package     "$proj::eval_package"        \
        -die_voltage "$proj::die_voltage"         \
        -speed       "$proj::die_speed"           \
        -part_range  "$proj::eval_part_range"     \
        -hdl         "$proj::hdl_lang"

    # Set tool profiles
    select_profile -name "$proj::synprofile"
    select_profile -name "$proj::simuprofile"
    puts "Project created successfully\n"

    set lvdt_ip "[proj::get_proj_origin]/ip/lvdt_ip/"
    set stepper_ip "[proj::get_proj_origin]/ip/stepper_ip/"
    set watchdog_ip "[proj::get_proj_origin]/ip/watchdog_ip/"
    set focus_mech_ip "[proj::get_proj_origin]/ip/focus_mech_ip/"

# ------------------------------------------------------------------------------
# Set source files
# ------------------------------------------------------------------------------
    set hdl_rst_cdc_sync_ip_files [proj::set_src_files   \
       -folder_path "${lvdt_ip}/src"                \
       -top_module "${top_module}"]

    set hdl_rst_cdc_sync_ip_files [proj::set_src_files   \
       -folder_path "${stepper_ip}/src"             \
       -top_module "${top_module}"]

    set hdl_rst_cdc_sync_ip_files [proj::set_src_files   \
       -folder_path "${watchdog_ip}/src"             \
       -top_module "${top_module}"]


# ------------------------------------------------------------------------------
# Create Custom HDL cores
# ------------------------------------------------------------------------------
    # Clean up tcl source relative links issues
    proj::convert_source_path_to_absolute "[proj::get_proj_bd]"
    proj::convert_source_path_to_absolute "[proj::get_proj_ip]"

# ------------------------------------------------------------------------------
# Populate custom components
# ------------------------------------------------------------------------------
    source "${lvdt_ip}/LVDT_READOUT_recursive.tcl"
    source "${stepper_ip}/STEPPER_DRIVER_recursive.tcl"
    source "${watchdog_ip}/watchdog_ip.tcl"
    source "${focus_mech_ip}/focus_mech_recursive.tcl"
    save_project

# ------------------------------------------------------------------------------
# Create block design
# ------------------------------------------------------------------------------
    # To downgrade DRC errors to warning to prevent build termination
    smartdesign -memory_map_drc_change_error_to_warning true

    # Clean up tcl source relative links issues
    proj::convert_source_path_to_absolute "[proj::get_proj_bd]"
    proj::convert_hdl_file_abs_to_relative_path "[proj::get_proj_bd]/components/top.tcl"

    # Generate the block design
    source "[proj::get_proj_bd]/${bd_file}"
    
    build_design_hierarchy
    set_root -module "${top_module}"
    save_project

# ------------------------------------------------------------------------------
# Set constraints
# ------------------------------------------------------------------------------
    set pdc_files [proj::set_io_const  \
        -folder_path "[proj::get_proj_constr]/io" \
        -top_module "${top_module}"]
    
    set sdc_files [proj::set_sdc_const \
        -folder_path "[proj::get_proj_constr]/sdc" \
        -top_module "${top_module}"]

    # Derive SDC constraints from the design
    derive_constraints_sdc

    set pdc_sdc_list [concat $pdc_files $sdc_files]

    # TBD - to be change to be generic function
    organize_tool_files \
        -tool {SYNTHESIZE} \
        -file [proj::get_proj_constr]/sdc/timing_user_constraints.sdc \
        -file [proj::get_proj_location]/constraint/top_derived_constraints.sdc \
        -module ${top_module} \
        -input_type {constraint}

    organize_tool_files \
        -tool {PLACEROUTE} \
        -file [proj::get_proj_constr]/io/io_constraints.pdc \
        -file [proj::get_proj_constr]/sdc/timing_user_constraints.sdc \
        -file [proj::get_proj_location]/constraint/top_derived_constraints.sdc \
        -module ${top_module} \
        -input_type {constraint}

    organize_tool_files \
        -tool VERIFYTIMING \
        -file [proj::get_proj_constr]/sdc/timing_user_constraints.sdc \
        -file [proj::get_proj_location]/constraint/top_derived_constraints.sdc \
        -module ${top_module} \
        -input_type {constraint}

    proj::run_tool_wrapper "run_tool -name {CONSTRAINT_MANAGEMENT}"
    save_project

# ------------------------------------------------------------------------------
# Build project
# ------------------------------------------------------------------------------
    proj::synthesize_proj
    proj::place_and_route_proj
    proj::verify_timing

# ------------------------------------------------------------------------------
# Export project
# ------------------------------------------------------------------------------
    proj::create_export_folder ${export_folder}
    set export_dir ${origin_dir}/build/${export_folder}
    proj::generate_fpga_array_data
    proj::export_fpga_bitstream_file [proj::get_proj_name] ${export_dir}
    proj::export_project_job [proj::get_proj_name] ${export_dir}

}
