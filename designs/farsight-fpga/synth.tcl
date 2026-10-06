# ------------------------------------------------------------------------------
# Originator: S. Janamian
# Date: 05/27/2025
# Description: Script to generate xilinx project, build and export bitstream
# ------------------------------------------------------------------------------
proc create_target {args} {


# ------------------------------------------------------------------------------
# Get target board
# ------------------------------------------------------------------------------
    set supported_targes [list mpf500ts-fc1152m]

    set msg2 "Supported target boards are ${supported_targes}"

    array set argValues {
        -target_board ""
        -project_name ""
        -no_synth ""
        -riscv_init ""
        -hw_major ""
        -hw_minor ""
        -hw_fix ""
        -hw_build ""
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

    if { $argValues(-project_name) eq ""} {
        set msg1 "No poject name was provided. Setting proj name to UNKNOWN".
        set project_name "UNKNOWN"
    } else {
        set project_name $argValues(-project_name)
    }

    if { $argValues(-no_synth) eq "" || $argValues(-no_synth) == 0 } {
        set no_synth 0
    } else {
        set no_synth 1
    }

    if { $argValues(-riscv_init) eq "" || $argValues(-riscv_init) == 0 } {
        set riscv_init 0
    } else {
        set riscv_init 1
    }

    # Hardware version bytes: MAJOR.MINOR.FIX and BUILD, each 0-255
    foreach {opt var} {-hw_major hw_major -hw_minor hw_minor -hw_fix hw_fix -hw_build hw_build} {
        set value $argValues($opt)
        if { $value eq "" } {
            error "No value provided for $opt. It is required and must be an integer in the range 0-255."
        }
        if { ![string is integer -strict $value] || $value < 0 || $value > 255 } {
            error "Invalid value for $opt: '$value'. It must be an integer in the range 0-255."
        }
        set $var $value
    }

# ------------------------------------------------------------------------------
# Source external util scripts
# ------------------------------------------------------------------------------
    source [file normalize [file join [file dirname [info script]] ./script/common/proj_util.tcl]]
    source [file normalize [file join [file dirname [info script]] ./script/${target_board}/proj_config.tcl]]
    source [file normalize [file join [file dirname [info script]] ./script/common/download.tcl]]
    source [file normalize [file join [file dirname [info script]] ./script/common/builder.tcl]]
    source [file normalize [file join [file dirname [info script]] ./script/common/export.tcl]]


# ------------------------------------------------------------------------------
# Project parameters
# ------------------------------------------------------------------------------
    # Get the current time as a Unix timestamp

    set origin_dir      [file normalize "."]
    set current_time    [clock seconds]
    set formatted_time  [clock format $current_time -format {%Y%m%d_%H%M%S}]
    set commit_id       [string range [exec git rev-parse HEAD] 0 7]

    set proj_name       "${target_board}_${project_name}_${formatted_time}_${commit_id}"
    set export_folder   "export_${target_board}_${project_name}_${formatted_time}_${commit_id}"
    set bd_file         {top_recursive.tcl}
    set top_module_name {top}
    set top_module      "${top_module_name}::work"

    # Set project info
    ::proj::set_proj_info                      \
        -min_version  "2024"                   \
        -addr         "$origin_dir"            \
        -constr       "constr/${target_board}" \
        -bd_folder    "bd"                     \
        -name         "$proj_name"             \
        -ip           "ip"                     \
        -force

# ------------------------------------------------------------------------------
# Create project
# ------------------------------------------------------------------------------
    # Create and configure new project
    new_project                                            \
        -name              "[proj::get_proj_name]"         \
        -location          "[proj::get_proj_location]"     \
        -family            "$proj::die_family"             \
        -die               "$proj::die_name"               \
        -package           "$proj::die_package"            \
        -die_voltage       "$proj::die_voltage"            \
        -speed             "$proj::die_speed"              \
        -part_range        "$proj::die_part_range"         \
        -hdl               "$proj::hdl_lang"               \
        -block_mode        "$proj::block_mode"             \
        -adv_options       "$proj::restrict_probe_pins"    \
        -adv_options       "$proj::restrict_spi_pins"      \
        -adv_options       "$proj::sys_ctrl_suspend"       \
        -adv_options       "$proj::reserve_migration_pins" \
        -adv_options       "$proj::io_default_std"         \
        -adv_options       "$proj::temp_range"             \
        -adv_options       "$proj::vcci_1p2_volt_range"    \
        -adv_options       "$proj::vcci_1p5_volt_range"    \
        -adv_options       "$proj::vcci_1p8_volt_range"    \
        -adv_options       "$proj::vcci_2p5_volt_range"    \
        -adv_options       "$proj::vcci_3p3_volt_range"    \
        -adv_options       "$proj::volt_range"

    set_device_simple \
        -family            "$proj::die_family"             \
        -die               "$proj::die_name"               \
        -package           "$proj::die_package"            \
        -speed             "$proj::die_speed"              \
        -adv_options       "$proj::restrict_probe_pins"    \
        -adv_options       "$proj::restrict_spi_pins"      \
        -adv_options       "$proj::sys_ctrl_suspend"       \
        -adv_options       "$proj::reserve_migration_pins" \
        -adv_options       "$proj::io_default_std"         \
        -adv_options       "$proj::temp_range"             \
        -adv_options       "$proj::vcci_1p2_volt_range"    \
        -adv_options       "$proj::vcci_1p5_volt_range"    \
        -adv_options       "$proj::vcci_1p8_volt_range"    \
        -adv_options       "$proj::vcci_2p5_volt_range"    \
        -adv_options       "$proj::vcci_3p3_volt_range"    \
        -adv_options       "$proj::volt_range"

    # Set tool profiles
    select_profile -name "$proj::synprofile"
    select_profile -name "$proj::simuprofile"
    save_project
    puts "Project created successfully\n"

# ------------------------------------------------------------------------------
# Update build version
# ------------------------------------------------------------------------------

    set ver_file_template "[proj::get_proj_ip]/hw_version_ip/template/hw_version_apb_reg.sv.template"
    set ver_folder "[proj::get_proj_ip]/hw_version_ip/src/"
    set ver_file "[proj::get_proj_ip]/hw_version_ip/src/hw_version_apb_reg.sv"

    proj::copy_template -src_file $ver_file_template -dest_folder $ver_folder

    proj::update_build_params \
        -file_addr $ver_file \
        -hw_major $hw_major \
        -hw_minor $hw_minor \
        -hw_fix $hw_fix \
        -hw_build $hw_build \
        -git_hash $commit_id \
        -time_utc $current_time

# ------------------------------------------------------------------------------
# Set source files
# ------------------------------------------------------------------------------
    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/cam_flow_sync_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/image_metadata_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/responder_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/dbg_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/hw_version_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/junc_temp_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/dma_read_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/dma_write_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/hbeat_runner/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/cam_mux_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/cam_fault_detector_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/dma_read_ctrl_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/cam_trig_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/udp_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/eth_pcie_mux_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/xcvr_disparity_correction/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/focus_mech_ip/hw/ip/stepper_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/focus_mech_ip/hw/ip/lvdt_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/focus_mech_ip/hw/ip/watchdog_ip/src" \
        -top_module "${top_module}"]


    set hdl_files [proj::set_src_files      \
        -folder_path "[proj::get_proj_ip]/pps_ip/src" \
        -top_module "${top_module}"]


# ------------------------------------------------------------------------------
# Create Custom HDL cores
# ------------------------------------------------------------------------------
    # Clean up tcl source relative links issues
    proj::convert_source_path_to_absolute "[proj::get_proj_bd]"
    # proj::convert_source_path_to_absolute "[proj::get_proj_ip]"

    source "[proj::get_proj_ip]/cam_flow_sync_ip/cam_flow_sync_ip.tcl"

    source "[proj::get_proj_ip]/image_metadata_ip/image_metadata_ip.tcl"

    source "[proj::get_proj_ip]/responder_ip/responder_ip.tcl"

    source "[proj::get_proj_ip]/dbg_ip/dbg_mux_ip.tcl"

    source "[proj::get_proj_ip]/hw_version_ip/hw_version_apb_reg_ip.tcl"

    source "[proj::get_proj_ip]/junc_temp_ip/junc_temp_ip.tcl"

    source "[proj::get_proj_ip]/hbeat_runner/hbeat_runner.tcl"

    source "[proj::get_proj_ip]/xcvr_disparity_correction/xcvr_disparity_correction.tcl"

    source "[proj::get_proj_ip]/cam_mux_ip/cam_mux_ip.tcl"

    source "[proj::get_proj_ip]/cam_fault_detector_ip/cam_fault_detector_ip.tcl"

    source "[proj::get_proj_ip]/cam_trig_ip/cam_trig_ip.tcl"

    source "[proj::get_proj_ip]/dma_write_ip/dma_write_ip.tcl"

    source "[proj::get_proj_ip]/dma_read_ip/dma_read_ip.tcl"

    source "[proj::get_proj_ip]/dma_read_ctrl_ip/dma_read_ctrl_ip.tcl"

    source "[proj::get_proj_ip]/udp_ip/udp_ip.tcl"

    source "[proj::get_proj_ip]/eth_pcie_mux_ip/eth_pcie_mux_ip.tcl"

    source "[proj::get_proj_ip]/pps_ip/pps_ip.tcl"


# ------------------------------------------------------------------------------
# Create block design
# ------------------------------------------------------------------------------
    # To downgrade DRC errors to warning to prevent build termination
    smartdesign -memory_map_drc_change_error_to_warning true
    build_design_hierarchy

    # Generate the block design

    source "[proj::get_proj_bd]/${target_board}/ddr4_16gb_hier/ddr4_16gb_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/ddr4_8gb_hier/ddr4_8gb_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/rst_hier/rst_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/riscv_hier/riscv_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/interconnect_hier/interconnect_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/pps_hier/pps_hier_recursive.tcl"
    
    save_project
    source "[proj::get_proj_ip]/focus_mech_ip/hw/ip/stepper_ip/STEPPER_DRIVER_recursive.tcl"

    save_project
    source "[proj::get_proj_ip]/focus_mech_ip/hw/ip/watchdog_ip/watchdog_ip.tcl"

    save_project
    source "[proj::get_proj_ip]/focus_mech_ip/hw/ip/lvdt_ip/LVDT_READOUT_recursive.tcl"

    save_project
    source "[proj::get_proj_ip]/focus_mech_ip/hw/ip/focus_mech_ip/focus_mech_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/cam_rx_hier/cam_rx_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/eth1_hier/eth1_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/hk_hier/hk_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/udp_hier/udp_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/eth_pcie_mux_hier/eth_pcie_mux_hier_recursive.tcl"

    save_project
    source "[proj::get_proj_bd]/${target_board}/pcie_hier/pcie_hier_recursive.tcl"

    save_project
    build_design_hierarchy

    source "[proj::get_proj_bd]/${target_board}/top/${bd_file}"

    save_project

    build_design_hierarchy
    set_root -module "${top_module}"
    save_project

# ------------------------------------------------------------------------------
# Set constraints
# ------------------------------------------------------------------------------
    set pdc_fp_files [proj::set_fp_const  \
        -folder_path "[proj::get_proj_constr]/fp" \
        -top_module "${top_module}"]

    set pdc_io_files [proj::set_io_const  \
        -folder_path "[proj::get_proj_constr]/io" \
        -top_module "${top_module}"]

    set sdc_files [proj::set_sdc_const \
        -folder_path "[proj::get_proj_constr]/sdc" \
        -top_module "${top_module}"]

    # Derive SDC constraints from the design
    derive_constraints_sdc

    set pdc_sdc_list [concat $pdc_fp_files $pdc_io_files $sdc_files]

    # TBD - to be change to be generic function
    organize_tool_files \
        -tool {SYNTHESIZE} \
        -file [proj::get_proj_constr]/sdc/timing_user_constraints.sdc \
        -file [proj::get_proj_location]/constraint/top_derived_constraints.sdc \
        -module ${top_module} \
        -input_type {constraint}

    organize_tool_files \
        -tool {PLACEROUTE} \
        -file [proj::get_proj_constr]/fp/fp_constraints.pdc \
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

    configure_tool \
        -name {PLACEROUTE} \
        -params {DELAY_ANALYSIS:MAX} \
        -params {EFFORT_LEVEL:true} \
        -params {GB_DEMOTION:true} \
        -params {INCRPLACEANDROUTE:false} \
        -params {IOREG_COMBINING:false} \
        -params {MULTI_PASS_CRITERIA:VIOLATIONS} \
        -params {MULTI_PASS_LAYOUT:true} \
        -params {NUM_MULTI_PASSES:20} \
        -params {PDPR:false} \
        -params {RANDOM_SEED:0} \
        -params {REPAIR_MIN_DELAY:true} \
        -params {REPLICATION:true} \
        -params {SLACK_CRITERIA:WORST_SLACK} \
        -params {SPECIFIC_CLOCK:} \
        -params {START_SEED_INDEX:92} \
        -params {STOP_ON_FIRST_PASS:true} \
        -params {TDPR:true}

    save_project

if {$no_synth} {
    return 0
}

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
    proj::generate_fpga_array_data $riscv_init
    proj::export_fpga_bitstream_file [proj::get_proj_name] ${export_dir}
    proj::export_project_job [proj::get_proj_name] ${export_dir}

    close_project -save 1
}
