namespace eval ::proj {
    proc generate_fpga_array_data {} {
        # Generate FPGA Array Data
        ## run_tool -name GENERATEPROGRAMMINGDATA
        run_tool_wrapper "run_tool -name GENERATEPROGRAMMINGDATA"

                        
        # Configure and generate Design Initialization Data and Memories
        # The following can be configured:
        #   - Design initialization source - sNVM/uPROM/SPI-Flash
        #   - sNVM user clients
        #   - uPROM user clients
        #   - Fabric RAM initialization content
        #   - SPI-Flash user clients

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
        # Export STAPL file
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

        puts "Exported bit stream successfully\n"    
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
