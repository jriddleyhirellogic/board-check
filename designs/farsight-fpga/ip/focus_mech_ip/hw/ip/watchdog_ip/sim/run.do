#-------------------------------------------------------------------------------
# @file      run.do
# @copyright Copyright (c) 2026 Turion Space. All rights reserved.
# @author    Saba Janamian (sjanamian@turionspace.com)
# @date      03/02/2026
#
# @brief     Simulation do file for testing watchdog IP
#
# @section changelog
# - 03/02/2026: Saba Janamian - Initial implementation
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Questa Lib config
#-------------------------------------------------------------------------------
set origin_dir [file normalize "."]
set build_folder ${origin_dir}/build
set src_folder [file normalize ".."]/src
set testbench_folder ${origin_dir}/tb

set work_lib_folder ${build_folder}/work

set testbench_file   ${testbench_folder}/watchdog_tb.sv
set testbench_module "watchdog_tb"

if {![file exists $build_folder]} {
    file mkdir $build_folder
}

#-------------------------------------------------------------------------------
# Generate QuestaSim working library
#-------------------------------------------------------------------------------
if {[file exists ${work_lib_folder}/_info]} {
   echo "INFO: Simulation library ${work_lib_folder} already exists"
} else {
   file delete -force ${work_lib_folder}
   vlib ${work_lib_folder}
}

vmap work ${work_lib_folder}

#-------------------------------------------------------------------------------
# Compile sources
#-------------------------------------------------------------------------------
vlog -sv +acc -work ${work_lib_folder} ${src_folder}/watchdog.sv
vlog -sv +acc -work ${work_lib_folder} ${src_folder}/watchdog_apb_reg.sv
vlog -sv +acc -work ${work_lib_folder} ${src_folder}/watchdog_top.sv
vlog -sv +acc -work ${work_lib_folder} ${testbench_file}

#-------------------------------------------------------------------------------
# Simulate
#-------------------------------------------------------------------------------
vsim -L work \
     -t 1ps \
     +acc \
     "work.${testbench_module}"

source ./wave.do

restart -force

run -all
