# -----------------------------------------------------------------------------
# Originator: S. Janamian
# Date: 10/25/2024
#
# This TCL file contains general procs to set a Libero project info
# and populate the project based on the given parameters
#
# -----------------------------------------------------------------------------

namespace eval ::proj {

# Declare proj_dict within the namespace
    variable proj_dict
    variable _proj_name_

    proc set_proj_info {args} {
        variable proj_dict
        set proj [dict create             \
            force               0         \
            proj_name           "proj_"   \
            proj_addr           "."       \
            proj_src            "src"     \
            proj_sim            "sim"     \
            proj_constr         "constr"  \
            proj_bd             "bd"      \
            proj_ip_repo        "ip_repo" \
            proj_build_dir_name "build"
        ]

        # Parse command-line arguments
        set i 0
        while {$i < [llength $args]} {
            set arg [lindex $args $i]
            switch -- $arg {
                "-min_version" {
                    dict set proj min_version [lindex $args [expr $i+1]]
                    incr i
                }
                "-force" {
                    dict set proj force 1
                }
                "-name" {
                    dict set proj proj_name [lindex $args [expr $i+1]]
                    incr i
                }
                "-addr" {
                    dict set proj proj_addr [lindex $args [expr $i+1]]
                    incr i
                }
                "-src" {
                    dict set proj proj_src [lindex $args [expr $i+1]]
                    incr i
                }
                "-sim" {
                    dict set proj proj_sim [lindex $args [expr $i+1]]
                    incr i
                }
                "-constr" {
                    dict set proj proj_constr [lindex $args [expr $i+1]]
                    incr i
                }
                "-bd_folder" {
                    dict set proj proj_bd [lindex $args [expr $i+1]]
                    incr i
                }
                "-ip_repo" {
                    dict set proj proj_ip_repo [lindex $args [expr $i+1]]
                    incr i
                }
                "-proj_build_dir" {
                    dict set proj proj_build_dir_name [lindex $args [expr $i+1]]
                    incr i
                }                

                "-help" {
                    puts "Usage: generate_project ?options?\n"
                    puts "Options:"
                    puts "  -min_version   Minimum required version of the tool"
                    puts "  -force         Force overwrite of existing project"
                    puts "  -name          name of the project"
                    puts "  -addr          address of the project"
                    puts "  -src           relative path to the source folder"
                    puts "  -sim           relative path to the simulation folder"
                    puts "  -constr        relative path to the constraint folder"
                    puts "  -bd_folder     relative path to folder containing block design tcl files"
                    puts "  -ip_repo       ip repo relative address"
                    puts "  -help          Display this help message"
                    return
                }
                default {
                    puts "Warning: Unknown argument $arg"
                }
            }
            incr i
        }

        set proj_dict $proj

        create_build_folder 
    }


    # Create build folder if it does not exist
    proc create_build_folder {} {
        variable proj_dict
        set proj_addr  [dict get $proj_dict "proj_addr"]
        set build_folder [dict get $proj_dict "proj_build_dir_name"]
        
        set folder_path "$proj_addr/$build_folder"
        if {![file exists $folder_path]} {
            file mkdir $folder_path
        }
    }

    proc proj_close {} {
        # Close any open project (including the one created by this script)
        catch {close_project -save 1}

        # Clear existing project settings
        if {[info exists project]} {
            unset project
        }
    }

    proc get_toolversion {} {
        # Vivado version
        set toolversion [lindex [split [get_libero_version] .] 0]

        if {![string length $toolversion]} {
            error "Error: tool version could not be detected!"
        }
        return $toolversion
    }

    proc check_libero_tool {args} {

        array set argValues {
            -min_version ""
        }

        # Override default values with any provided arguments
        array set argValues $args

        if { $argValues(-min_version) eq "" } {
            error "check_libero_tool function requires -min_version arg"
        } else {
            set min_version $argValues(-min_version)
        }

        set toolversion [get_toolversion]

        # version requirement check
        if {$toolversion < $min_version} {
            error "Error, this project requires ${min_version} or newer!"
        }
    }

    proc get_proj_origin {} {
        variable proj_dict
        return  [dict get $proj_dict "proj_addr"]
    }

    proc get_proj_name {} {
        variable proj_dict
        return [dict get $proj_dict "proj_name"]
    }

    proc get_proj_location {} {
        variable proj_dict
        set proj_addr  [dict get $proj_dict "proj_addr"]
        set build_folder [dict get $proj_dict "proj_build_dir_name"]
        set proj_name  [dict get $proj_dict "proj_name"]
        return "$proj_addr/$build_folder/$proj_name"
    }

    proc get_proj_src {} {
        variable proj_dict
        set proj_addr  [dict get $proj_dict "proj_addr"]
        set src_folder [dict get $proj_dict "proj_src"]
        return "$proj_addr/$src_folder"
    }

    proc get_proj_bd {} {
        variable proj_dict
        set proj_addr  [dict get $proj_dict "proj_addr"]
        set bd_folder [dict get $proj_dict "proj_bd"]
        return "$proj_addr/$bd_folder"
    }

    proc get_proj_constr {} {
        variable proj_dict
        set proj_addr  [dict get $proj_dict "proj_addr"]
        set constr_folder [dict get $proj_dict "proj_constr"]
        return "$proj_addr/$constr_folder"
    }

    proc get_proj_ip_repo {} {
        variable proj_dict
        set proj_addr  [dict get $proj_dict "proj_addr"]
        set ip_repo_folder [dict get $proj_dict "proj_ip_repo"]
        return "$proj_addr/$ip_repo_folder"
    }


    proc convert_source_path_to_absolute {directory} {
    set files [get_tcl_files $directory]

    foreach file $files {
        set file_data [read_file $file]
        set updated_data $file_data

        while {[regexp -nocase -all {source\s+(\S+\.tcl)} $updated_data match source_file]} {
            if {![string match "*file join*" $source_file]} {
                set updated_line "source \[file join \[file dirname \[info script\]\] $source_file]"
                set updated_data [string map [list $match $updated_line] $updated_data]
            }
        }

        if {$updated_data ne $file_data} {
            set backup_file "${file}.bkp"
            if {![file exists $backup_file]} {
                write_file $backup_file $file_data
            }
            write_file $file $updated_data
        }
    }
}

    # Helper proc to get .tcl files recursively
    proc get_tcl_files {directory} {
        set files {}
        foreach file [glob -nocomplain -directory $directory *] {
            if {[file isdirectory $file]} {
                # Recurse into subdirectory
                lappend files {*}[get_tcl_files $file]
            } elseif {[string match *.tcl $file]} {
                # Add .tcl file to list
                lappend files $file
            }
        }
        return $files
    }

    # Helper proc to read file
    proc read_file {filepath} {
        set file_id [open $filepath r]
        set file_data [read $file_id]
        close $file_id
        return $file_data
    }

    # Helper proc to write file
    proc write_file {filepath data} {
        set file_id [open $filepath w]
        puts $file_id $data
        close $file_id
    }

    # Set io constarints
    proc set_io_const {args} {

        array set argValues {
            -folder_path ""
        }
        
        array set argValues $args
        set folder_path $argValues(-folder_path)
        set pdc_file_list {}

        set file_list [glob -directory $folder_path *]

        foreach file $file_list {
            if {[string match *.pdc ${file}]} {
                set pdc_file [file normalize ${file}]
                create_links -convert_EDN_to_HDL 0 -pdc ${pdc_file}
                lappend pdc_file_list [file tail $pdc_file]
            } 
        }

        return $pdc_file_list
    }

    # Set sdc constraint
    proc set_sdc_const {args} {

        array set argValues {
            -folder_path ""
        }
        
        array set argValues $args
        set folder_path $argValues(-folder_path)
        set sdc_file_list {}
        set file_list [glob -directory $folder_path *]

        foreach file $file_list {
            if {[string match *.sdc $file]} {
                create_links -convert_EDN_to_HDL 0 -sdc $file
                lappend sdc_file_list [file tail $file]
            }
        }
        return $sdc_file_list
    }

    # Set fp constarints
    proc set_fp_const {args} {

        array set argValues {
            -folder_path ""
        }
        
        array set argValues $args
        set folder_path $argValues(-folder_path)
        set pdc_file_list {}

        set file_list [glob -directory $folder_path *]

        foreach file $file_list {
            if {[string match *.pdc ${file}]} {
                set pdc_file [file normalize ${file}]
                create_links -convert_EDN_to_HDL 0 -fp_pdc ${pdc_file}
                lappend pdc_file_list [file tail $pdc_file]
            } 
        }

        return $pdc_file_list
    }

    proc set_src_files {args} {

        array set argValues {
            -folder_path ""
        }

        array set argValues $args
        set folder_path $argValues(-folder_path)
        set hdl_file_list {}

        set file_list [glob -directory $folder_path *]

        foreach file $file_list {
            # Only link HDL sources. Anything else in the folder (editor swap
            # files, build backups, notes) is not valid input to create_links.
            if {![string match *.sv ${file}] &&
                ![string match *.v ${file}]  &&
                ![string match *.vhd ${file}]} {
                continue
            }
            set hdl_file [file normalize ${file}]
            create_links              \
                -convert_EDN_to_HDL 0 \
                -hdl_source ${hdl_file}
            lappend hdl_file_list [file tail $hdl_file]
        }

        save_project
        return $hdl_file_list
    }

    # Adapted from Microchip script. Report time used to execute a command
    proc run_tool_wrapper { cmd } {
        regexp {run_tool\s+-name\s+\{*(\w*)\}*} $cmd full1 tool;
        puts "Starting $tool command";

        set full_cmd "time \{ $cmd \}";

        set TIME_start [clock seconds];
        set runtime [ eval $full_cmd ];
        set TIME_taken [expr [clock seconds] - $TIME_start];
        puts "\nRUNTIME:$tool=$TIME_taken secs\n";

        set runtime_secs [ expr [lindex $runtime 0]/1000000 ];

        puts "\nRUNTIME_bytime:$tool=$runtime_secs secs\n";
    }
}
