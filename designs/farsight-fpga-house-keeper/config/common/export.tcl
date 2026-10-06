namespace eval ::proj {
    proc generate_fpga_array_data {} {
        # Generate FPGA Array Data
        run_tool -name GENERATEPROGRAMMINGDATA
        # run_tool_wrapper "run_tool -name GENERATEPROGRAMMINGDATA"

                        
        # Configure and generate Design Initialization Data and Memories
        # The following can be configured:
        #   - Design initialization source - sNVM/uPROM/SPI-Flash
        #   - sNVM user clients
        #   - uPROM user clients
        #   - Fabric RAM initialization content
        #   - SPI-Flash user clients

        # generate_design_initialization_data
            
        # configure_tool \
        #         -name {GENERATEPROGRAMMINGFILE} \
        #         -params {program_fabric:true} \
        #         -params {program_security:false} \
        #         -params {program_snvm:false} \
        #         -params {sanitize_snvm:false}
                
        ## run_tool -name GENERATEPROGRAMMINGFILE
        # run_tool_wrapper "run_tool -name GENERATEPROGRAMMINGFILE"

        puts "Programmingfile generated successfully\n"
    }

    proc export_project_job {} {
        # Export Programming Job
        # Programming job files can be imported in FlasPro Express standalone for programming the device
        run_tool -name EXPORTPROGRAMMINGFILE
        puts "Exported job file successfully\n"

        puts "Full design flow passed execution\n"	
    }
}
