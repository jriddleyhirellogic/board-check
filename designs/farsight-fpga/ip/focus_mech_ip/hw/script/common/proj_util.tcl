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
            proj_ip             "ip"      \
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
                "-ip" {
                    dict set proj proj_ip [lindex $args [expr $i+1]]
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
                    puts "  -ip            ip relative address"
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
        check_libero_tool -min_version [dict get $proj_dict "min_version"]
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

    # Create build folder if it does not exist
    proc create_export_folder {addr} {
        variable proj_dict
        set proj_addr  [dict get $proj_dict "proj_addr"]
        set build_folder [dict get $proj_dict "proj_build_dir_name"]

        set folder_path "$proj_addr/$build_folder"
        if {![file exists $folder_path]} {
            file mkdir $folder_path
        }
        set export_path "$proj_addr/$build_folder/$addr"
        file mkdir $export_path
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

    proc get_proj_ip {} {
        variable proj_dict
        set proj_addr  [dict get $proj_dict "proj_addr"]
        set ip_folder [dict get $proj_dict "proj_ip"]
        return "$proj_addr/$ip_folder"
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
                create_links -convert_EDN_to_HDL 0 -io_pdc ${pdc_file}
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
            set hdl_file [file normalize ${file}]
            create_links              \
                -convert_EDN_to_HDL 0 \
                -hdl_source ${hdl_file}
            lappend hdl_file_list [file tail $hdl_file]
        }

        build_design_hierarchy

        return $hdl_file_list
    }

    #  use the constraint for differnt build phases
    # proc constr_files_organize {args} {
    #     array set argValues {
    #         -proj_location ""
    #         -file_list ""
    #         -top_module ""
    #         -build_phase ""
    #     }
    #     array set argValues $args

    #     set proj_location   $argValues(-proj_location)
    #     set file_list       $argValues(-file_list)
    #     set top_module      $argValues(-top_module)
    #     set build_phase     $argValues(-build_phase)

    #     set files {}
    #     foreach file $file_list {
    #         lappend files "\-file \{${proj_location}/constraint/${file}\} "
    #     }

    #     set files_str [string trimright [join $files ""]]
    #     set cmd [list organize_tool_files -tool ${build_phase} ${files_str} -module ${top_module} -input_type {constraint}]
    #     uplevel $cmd
    #     # organize_tool_files -tool ${build_phase} ${files_str} -module ${top_module} -input_type {constraint}
    # }

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

    proc get_relative_path {base target} {
        set base [file normalize $base]
        set target [file normalize $target]

        set base_list [file split $base]
        set target_list [file split $target]

        # Find the common path length
        set i 0
        foreach b $base_list t $target_list {
            if {$b ne $t} {
                break
            }
            incr i
        }

        # Compute how many directories to go up
        set up_count [expr {[llength $base_list] - $i}]
        set up_path ""
        for {set j 0} {$j < $up_count} {incr j} {
            append up_path "../"
        }

        # Append the remaining target path
        set remaining_path [join [lrange $target_list $i end] "/"]

        return "${up_path}${remaining_path}"
    }

    # Use this to convert absolute paths in the TOP TCL file to relative paths
    proc convert_hdl_file_abs_to_relative_path {file_path} {
        # Backup the original file
        set backup_file "${file_path}.bkp"
        file copy -force $file_path $backup_file

        set file_dir [file dirname [file normalize $file_path]]

        # Open the file for reading
        set fp [open $file_path r]

        # Read all lines into a list
        set lines [split [read $fp] "\n"]
        close $fp  ;# Close the file after reading

        # Regex pattern to match -hdl_file {path}
        set pattern {^(.*?)\-hdl_file\s+\{(/.*?)\}(.*?)$}

        # Open the file for writing
        set fp [open $file_path w]

        foreach line $lines {
            # This extracts only the second capture group (hdl_path) and keeps other parts intact
            if {[regexp $pattern $line match prefix hdl_path suffix]} {
                puts "------> Found: $hdl_path"
                set relative_path [proj::get_relative_path $file_dir $hdl_path]
                puts "------> Relative path: $relative_path"
                # Construct the updated line while preserving the original structure
                set new_line "$prefix-hdl_file \"\[file normalize \[file join \[file dirname \[info script\]\] $relative_path\]\]\" $suffix"
                puts $fp $new_line
            } else {
                # If no match, write the original line back to the file
                puts $fp $line
            }
        }

        # Close the file
        close $fp
    }


    # # Use this to convert absolute paths in the TOP TCL file to relative paths
    # proc convert_hdl_file_abs_to_relative_path_file_pattern {file_path} {
    #     # Backup the original file
    #     set backup_file "${file_path}.bkp"
    #     file copy -force $file_path $backup_file

    #     set file_dir [file dirname [file normalize $file_path]]

    #     # Open the file for reading
    #     set fp [open $file_path r]

    #     # Read all lines into a list
    #     set lines [split [read $fp] "\n"]
    #     close $fp  ;# Close the file after reading

    #     # Regex pattern to match -hdl_file {path}
    #     set pattern {^(.*?)\-file\s+\{(/.*?)\}(.*?)$}

    #     # Open the file for writing
    #     set fp [open $file_path w]

    #     foreach line $lines {
    #         # This extracts only the second capture group (hdl_path) and keeps other parts intact
    #         if {[regexp $pattern $line match prefix hdl_path suffix]} {
    #             puts "------> Found: $hdl_path"
    #             set relative_path [proj::get_relative_path $file_dir $hdl_path]
    #             puts "------> Relative path: $relative_path"
    #             # Construct the updated line while preserving the original structure
    #             set new_line "$prefix-file \"\[file normalize \[file join \[file dirname \[info script\]\] $relative_path\]\]\" $suffix"
    #             puts $fp $new_line
    #         } else {
    #             # If no match, write the original line back to the file
    #             puts $fp $line
    #         }
    #     }

    #     # Close the file
    #     close $fp
    # }


    # # Process all files in a folder and convert absolute paths to relative paths
    # proc convert_folder_abs_to_relative_paths {folder_path} {
    #     set folder_list [glob -directory $folder_path **]

    #     foreach folder_path $folder_list {
    #         set file_list [get_tcl_files $folder_path]
    #         foreach file_path $file_list {
    #             if {[file isfile $file_path]} {
    #                 puts "Checking for absolute path ----> $file_path"
    #                 convert_hdl_file_abs_to_relative_path $file_path
    #                 convert_hdl_file_abs_to_relative_path_file_pattern $file_path
    #             }
    #         }
    #     }
    # }


    # This function reads all the files in a given folder and creates hdl core
    # IPs for each file and adds them to the design
    proc create_custom_hdl_core {args} {

        array set argValues {
            -folder_path ""
        }

        array set argValues $args
        set folder_path $argValues(-folder_path)
        set file_list [glob -directory $folder_path *]

        foreach file $file_list {
            if {[string match *.v $file] || [string match *.sv $file] || [string match *.vhd $file]} {
                set src_file [file normalize ${file}]
                set module_name [file rootname [file tail $src_file]]
                puts "create_hdl_core -file ${src_file} -module ${module_name} -library {work} -package {}"
                create_hdl_core -file "${src_file}" -module ${module_name} -library {work} -package {}

            }
        }

    }

    # Remove "source hdl_source.tcl" from a given tcl script
    proc cleanup_bd_file {args} {
        array set argValues {
            -file_path ""
        }

        array set argValues $args
        set file_path $argValues(-file_path)

        # Check if file path is provided
        if {$file_path eq ""} {
            puts "Error: No file path provided. Use -file_path option."
            return -1
        }

        # Check if file exists
        if {![file exists $file_path]} {
            puts "Error: File '$file_path' does not exist."
            return -1
        }

        set file_handle [open $file_path r]
        set file_content [read $file_handle]
        close $file_handle

        # Split content into lines
        set lines [split $file_content "\n"]

        # Look for the target line
        set target_line "source hdl_source.tcl"
        set line_found 0
        set new_lines {}

        foreach line $lines {
            # Trim whitespace and check if line contains our target
            set trimmed_line [string trim $line]
            if {$trimmed_line eq $target_line} {
                set line_found 1
                puts "Found line: '$target_line'"
                # Skip this line (don't add it to new_lines)
                continue
            }
            lappend new_lines $line
        }

        if {$line_found} {
            # Create backup file
            set backup_path "${file_path}.bkp"
            puts "Creating backup: $backup_path"

            file copy -force $file_path $backup_path

            set file_handle [open $file_path w]
            puts -nonewline $file_handle [join $new_lines "\n"]
            close $file_handle

            puts "Successfully removed '$target_line' from $file_path"
            puts "Original file backed up as $backup_path"
            return 0
        } else {
            puts "Line '$target_line' not found in $file_path"
            return 1
        }
    }

}
