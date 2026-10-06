namespace eval ::proj {
    proc _count_hex_bytes {file} {
        set _count 0
        set _fh [open $file r]
        while {[gets $_fh _line] >= 0} {
            if {[string index $_line 0] eq ":"} {
                scan [string range $_line 7 8] %x _rt
                if {$_rt == 0} { scan [string range $_line 1 2] %x _bc; incr _count $_bc }
            }
        }
        close $_fh
        return $_count
    }

    proc generate_fpga_array_data {{riscv_init 0}} {
        # Generate FPGA Array Data
        ## run_tool -name GENERATEPROGRAMMINGDATA
        run_tool_wrapper "run_tool -name GENERATEPROGRAMMINGDATA"

        if {$riscv_init} {
            # Configure and generate Design Initialization Data and Memories
            set _hex_file    [file join [::proj::get_proj_origin] riscv_init bootloader.hex]
            set _impl_dir    [file join [::proj::get_proj_location] designer top]
            set _bytes_riscv [::proj::_count_hex_bytes $_hex_file]

            # Copy cfg templates from riscv_init/, filling in the two dynamic values
            foreach {_src _dst} [list \
                [file join [::proj::get_proj_origin] riscv_init SNVM.cfg] [file join $_impl_dir SNVM.cfg] \
                [file join [::proj::get_proj_origin] riscv_init RAM.cfg]  [file join $_impl_dir RAM.cfg]  \
            ] {
                set _fh [open $_src r]; set _content [read $_fh]; close $_fh
                set _content [string map [list @HEX_FILE@ $_hex_file @HEX_BYTES@ $_bytes_riscv] $_content]
                set _fh [open $_dst w]; puts -nonewline $_fh $_content; close $_fh
            }

            configure_snvm -cfg_file [file join $_impl_dir SNVM.cfg]
            configure_ram  -cfg_file [file join $_impl_dir RAM.cfg]
        }

        generate_design_initialization_data

        configure_tool \
                -name {GENERATEPROGRAMMINGFILE} \
                -params {program_fabric:true} \
                -params {program_security:false} \
                -params {program_snvm:false} \
                -params {sanitize_snvm:false}

        ## run_tool -name GENERATEPROGRAMMINGFILE
        run_tool_wrapper "run_tool -name GENERATEPROGRAMMINGFILE"

        puts "Programmingfile generated successfully\n"
    }

    proc export_fpga_bitstream_file {filename addr} {
        # Export STAPL file (for JTAG programming via a STAPL player)
        export_bitstream_file \
                -file_name ${filename} \
                -export_dir ${addr} \
                -format {STP} \
                -for_ihp 0 \
                -limit_SVF_file_size 0 \
                -limit_SVF_file_by_max_filesize_or_vectors {} \
                -svf_max_filesize {} \
                -svf_max_vectors {} \
                -master_file 0 \
                -master_file_components {} \
                -encrypted_uek1_file 0 \
                -encrypted_uek1_file_components {} \
                -encrypted_uek2_file 0 \
                -encrypted_uek2_file_components {} \
                -trusted_facility_file 1 \
                -trusted_facility_file_components {FABRIC SNVM} \
                -zeroization_likenew_action 0 \
                -zeroization_unrecoverable_action 0 \
                -master_backlevel_bypass 0 \
                -uek1_backlevel_bypass 0 \
                -uek2_backlevel_bypass 0 \
                -master_include_plaintext_passkey 0 \
                -uek1_include_plaintext_passkey 0 \
                -uek2_include_plaintext_passkey 0 \
                -sanitize_snvm 0

        puts "Exported STAPL (.stp) bitstream successfully\n"

        # Export DAT file (for SPI-Slave programming from an external SPI master)
        export_bitstream_file \
                -file_name ${filename} \
                -export_dir ${addr} \
                -format {DAT} \
                -for_ihp 0 \
                -limit_SVF_file_size 0 \
                -limit_SVF_file_by_max_filesize_or_vectors {} \
                -svf_max_filesize {} \
                -svf_max_vectors {} \
                -master_file 0 \
                -master_file_components {} \
                -encrypted_uek1_file 0 \
                -encrypted_uek1_file_components {} \
                -encrypted_uek2_file 0 \
                -encrypted_uek2_file_components {} \
                -trusted_facility_file 1 \
                -trusted_facility_file_components {FABRIC SNVM} \
                -zeroization_likenew_action 0 \
                -zeroization_unrecoverable_action 0 \
                -master_backlevel_bypass 0 \
                -uek1_backlevel_bypass 0 \
                -uek2_backlevel_bypass 0 \
                -master_include_plaintext_passkey 0 \
                -uek1_include_plaintext_passkey 0 \
                -uek2_include_plaintext_passkey 0 \
                -sanitize_snvm 0

        puts "Exported SPI-Slave (.dat) bitstream successfully\n"
    }

    proc export_project_job {filename addr} {
        # Export Programming Job
        # Programming job files can be imported in FlasPro Express standalone for programming the device
        export_prog_job \
            -job_file_name ${filename} \
            -export_dir ${addr} \
            -bitstream_file_type {TRUSTED_FACILITY} \
            -bitstream_file_components {FABRIC SNVM} \
            -program_design 1 \
            -program_spi_flash 0 \
            -zeroization_likenew_action 0 \
            -zeroization_unrecoverable_action 0 \
            -include_plaintext_passkey 0 \
            -design_bitstream_format {PPD} \
            -prog_optional_procedures {} \
            -skip_recommended_procedures {} \
            -sanitize_snvm 0

        puts "Exported job file successfully\n"

        puts "Full design flow passed execution\n"
    }
}
