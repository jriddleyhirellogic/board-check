# ------------------------------------------------------------------------------
# Originator : Saba Janamian
# Date       : 01/14/2025
# Description: Script to generate libero project, build and export bitstream
# ------------------------------------------------------------------------------

proc create_target {args} {

# ------------------------------------------------------------------------------
# Get target board
# ------------------------------------------------------------------------------
    set supported_targes [list a3pe3000l-fg484m]

    set msg2 "Supported target boards are ${supported_targes}"

    array set argValues {
        -target_board ""
        -project_name ""
        -variant      ""
    }
    # Override default values with any provided arguments
    array set argValues $args

    if { $argValues(-target_board) eq "" } {
        set msg1 "No target board has been provided."
        error "$msg1\n$msg2"
    } elseif { [lsearch -exact "$supported_targes" "$argValues(-target_board)"] == -1} {
        set msg1 "Target board not supported. $argValues(-target_board)."
        error "$msg1\n$msg2"
    } elseif { $argValues(-project_name) eq "" } {
        error "No project name has been provided."
    } else {
        set target_board $argValues(-target_board)
        set proj_prefix $argValues(-project_name)
        set variant $argValues(-variant)
    }

# ------------------------------------------------------------------------------
# Validate build variant
# ------------------------------------------------------------------------------
    # The variant now selects the build's inputs, not merely the folder the
    # .pdb is filed under. Nothing edits a tracked file: the pinout comes from
    # constr/<board>/io/<pinout>/, and TMR from src/build_variant.vh, which
    # script/build_variant.py writes before Libero runs. That is what makes
    # the commit id recorded below describe the source that produced the image.
    set supported_variants [list em em_tmr fm fm_tmr]

    if { $variant eq "" } {
        set variant "fm_tmr"
        puts "No build variant provided, defaulting to ${variant}"
    } elseif { [lsearch -exact $supported_variants $variant] == -1 } {
        error "Build variant not supported: ${variant}.\nSupported variants are ${supported_variants}"
    }

    # em/em_tmr -> em pinout; fm/fm_tmr -> fm pinout. The RS-422 transmit and
    # receive pins are swapped between the two boards, so an image built with
    # the wrong one has a dead command link.
    if { [string match "em*" $variant] } {
        set pinout "em"
    } else {
        set pinout "fm"
    }
    puts "Variant ${variant}: pinout constraints from constr/${target_board}/io/${pinout}/"

    # The image must describe the source that built it. Nothing patches a
    # tracked file any more, so a dirty tree is the only remaining way for the
    # two to disagree -- and it is the way that looks cleanest, because
    # `git rev-parse HEAD` reports a clean commit either way.
    #
    # `build_variant.vh` is generated and gitignored, so it does not count.
    set dirty [exec git status --porcelain -- src constr script config synth.tcl synth_farsight_hk.tcl]
    set allow_dirty [expr {[info exists env(ALLOW_DIRTY_BUILD)] && $env(ALLOW_DIRTY_BUILD) ne "0"}]
    if { $dirty ne "" } {
        puts "Working tree is not clean:"
        puts $dirty
        if { !$allow_dirty } {
            error "Refusing to build from a modified tree. The programming file records\nthe commit id, and an image built from uncommitted source would record one\nthat does not describe it. Commit or stash, or set ALLOW_DIRTY_BUILD=1 to\nstamp the image -dirty instead."
        }
        puts "ALLOW_DIRTY_BUILD is set: the image will be stamped -dirty and must not be flown."
    }

# ------------------------------------------------------------------------------
# Source external util scripts
# ------------------------------------------------------------------------------
    source [file normalize [file join [file dirname [info script]] ./script/common/proj_util.tcl]]
    source [file normalize [file join [file dirname [info script]] ./config/${target_board}/proj_config.tcl]]
    source [file normalize [file join [file dirname [info script]] ./config/common/download.tcl]]
    source [file normalize [file join [file dirname [info script]] ./config/common/builder.tcl]]
    source [file normalize [file join [file dirname [info script]] ./config/common/export.tcl]]

# ------------------------------------------------------------------------------
# Project parameters
# ------------------------------------------------------------------------------
    # Get the current time as a Unix timestamp
    set current_time    [clock seconds]
    set origin_dir      [file normalize "."]

    # Format the timestamp into the desired format
    set formatted_time  [clock format $current_time -format {%Y%m%d_%H%M%S}]
    # Twelve characters, not six: six is short enough to collide, and this is
    # the only durable link between an image and the source that made it.
    set commit_id       [string range [exec git rev-parse HEAD] 0 11]
    if { $dirty ne "" } { append commit_id "-dirty" }
    # The variant is in the name because the folder it is filed under is not
    # carried with the file. Four images that differ only by their parent
    # directory are four images nobody can tell apart once one is moved.
    set proj_name       "${proj_prefix}_${target_board}_${variant}_${formatted_time}_${commit_id}"
    set bd_file         {top_recursive.tcl}
    set top_module_name {top}
    set top_module      "${top_module_name}::work"

    # Set project info
    ::proj::set_proj_info                      \
        -min_version  "11"                     \
        -addr         "$origin_dir"            \
        -constr       "constr/${target_board}" \
        -bd_folder    "bd/${target_board}"     \
        -src          "src/"                   \
        -name         "$proj_name"             \
        -ip_repo      "ip_repo"                \
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
        -hdl         "$proj::hdl_lang"            \
        -adv_options "$proj::io_deft_std"         \
        -adv_options "$proj::restric_prob_pins"   \
        -adv_options "$proj::ristric_spi_pins"    \
        -adv_options "$proj::temp_rate"           \
        -adv_options "$proj::vcci_1p5"            \
        -adv_options "$proj::vcci_1p8"            \
        -adv_options "$proj::vcci_2p5"            \
        -adv_options "$proj::vcci_3p3"            \
        -adv_options "$proj::volt_rate"


    # Check tool version
    proj::check_libero_tool -min_version [dict get $proj::proj_dict "min_version"]
    
    # Set tool profiles
    select_profile -name "$proj::synprofile"
    # select_profile -name "$proj::simuprofile"
    puts "Project created successfully\n"

# ------------------------------------------------------------------------------
# Create block design
# ------------------------------------------------------------------------------
    # # To downgrade DRC errors to warning to prevent build termination
    # smartdesign -memory_map_drc_change_error_to_warning true

    # Clean up tcl source relative links issues
    proj::convert_source_path_to_absolute "[proj::get_proj_bd]"

    # Generate the block design
    source "[proj::get_proj_bd]/${bd_file}"

# ------------------------------------------------------------------------------
# Set source files
# ------------------------------------------------------------------------------
    set hdl_files [proj::set_src_files -folder_path "[proj::get_proj_src]"]
    set_root -module "${top_module}"

# ------------------------------------------------------------------------------
# Set constraints
# ------------------------------------------------------------------------------
    # set fpc_files [proj::set_fp_const \
    #     -folder_path "[proj::get_proj_constr]/fp" \
    #     -top_module "${top_module}"]

    set pdc_files [proj::set_io_const  \
        -folder_path "[proj::get_proj_constr]/io/${pinout}" \
        -top_module "${top_module}"]

    set sdc_files [proj::set_sdc_const \
        -folder_path "[proj::get_proj_constr]/sdc" \
        -top_module "${top_module}"]

    # Derive SDC constraints from the design
    

    set pdc_sdc_list [concat $pdc_files $sdc_files]

    organize_tool_files \
        -tool {SYNTHESIZE} \
        -file [proj::get_proj_constr]/sdc/timing_user_constraints.sdc \
        -module ${top_module} \
        -input_type {constraint}

    organize_tool_files \
        -tool {COMPILE} \
        -file [proj::get_proj_constr]/io/${pinout}/io_constraints.pdc \
        -file [proj::get_proj_constr]/sdc/timing_user_constraints.sdc \
        -module ${top_module}\
        -input_type {constraint} 

    save_project
    

    # ------------------------------------------------------------------------------
    # Build project
    # ------------------------------------------------------------------------------
    proj::synthesize_proj
    proj::place_and_route_proj
    proj::verify_timing

    # ------------------------------------------------------------------------------
    # Generate programming file
    # ------------------------------------------------------------------------------
    proj::generate_fpga_array_data
    proj::export_project_job

    # Captured before the project closes. `get_libero_version` needs an open
    # project, and the manifest below is written after `close_project` -- the
    # first build with a manifest failed here, having already produced and
    # copied a perfectly good image.
    set libero_version [get_libero_version]

    close_project -save 1

    # ------------------------------------------------------------------------------
    # Copy generated programming file to programming_files/<variant>/
    # ------------------------------------------------------------------------------
    set pdb_src  "[proj::get_proj_location]/designer/impl1/${top_module_name}.pdb"
    set pdb_dest "${origin_dir}/programming_files/${variant}/${proj_name}.pdb"
    if {[file exists $pdb_src]} {
        file mkdir [file dirname $pdb_dest]
        file copy -force $pdb_src $pdb_dest
        puts "Copied ${pdb_src} to ${pdb_dest}\n"

        # A manifest beside the image, describing what it is and what made it.
        # The filename carries the variant and the commit, but a filename can
        # be changed by anyone who moves the file; this cannot be produced by
        # accident, and it is the beginning of what BUILD-01 asks a build to
        # retain. `script/record_build.py` adds the digest afterwards.
        if { [string match "*_tmr" $variant] } { set tmr true } else { set tmr false }
        set manifest [open "${origin_dir}/programming_files/${variant}/${proj_name}.json" w]
        puts $manifest "{"
        puts $manifest "  \"image\": \"${proj_name}.pdb\","
        puts $manifest "  \"variant\": \"${variant}\","
        puts $manifest "  \"tmr\": ${tmr},"
        puts $manifest "  \"pinout\": \"${pinout}\","
        puts $manifest "  \"target_board\": \"${target_board}\","
        puts $manifest "  \"commit\": \"${commit_id}\","
        puts $manifest "  \"tree_clean\": [expr {$dirty eq "" ? "true" : "false"}],"
        puts $manifest "  \"built_utc\": \"${formatted_time}\","
        puts $manifest "  \"libero_version\": \"${libero_version}\","
        puts $manifest "  \"pin_constraints\": \"constr/${target_board}/io/${pinout}/io_constraints.pdc\""
        puts $manifest "}"
        close $manifest
        puts "Wrote manifest ${proj_name}.json\n"
    } else {
        puts "WARNING: programming file not found at ${pdb_src}, skipping copy\n"
    }

}
