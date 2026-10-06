# Generate the design's vendor IP for simulation, without a synthesis run.
#
#   libero SCRIPT:gen_ip.tcl SCRIPT_ARGS:"<target_board> <out_dir>"
#
# The design instantiates cores that Libero generates from the component
# definitions in `bd/<board>/components/`. Synthesis produces them as a side
# effect, into a timestamped build directory; simulation needs the same RTL
# without a place-and-route and without a synthesis licence.
#
# Every `*.tcl` in the components directory is generated. Dropping a new
# component definition in is all that is required -- nothing here, in the
# Makefile, or in the verification environment names a particular core.
#
# Each generated core is accompanied by a lockfile recording what it was
# generated from, so a later run can tell whether it is still the core the
# definition asks for. See `verification/fsverif/ip.py`.

set target_board [lindex $argv 0]
set out_dir      [lindex $argv 1]

if {$target_board eq "" || $out_dir eq ""} {
    puts "usage: SCRIPT_ARGS:\"<target_board> <out_dir>\""
    exit 1
}

set origin_dir     [file normalize "."]
set components_dir "${origin_dir}/bd/${target_board}/components"
set work_dir       "${origin_dir}/.ip-build"

set definitions [lsort [glob -nocomplain -directory $components_dir *.tcl]]
if {[llength $definitions] == 0} {
    puts "ERROR: no component definitions in $components_dir"
    exit 1
}

# A scratch project. It exists only to give the core generator somewhere to
# run, and `make ip` deletes it afterwards: keeping it would leave a second
# copy of the generated RTL that nothing checks and somebody eventually
# compiles.
file delete -force $work_dir

# The same device settings the synthesis build uses, read from the same file.
# Restating them here would be a second definition of the device, and a core
# generated for a different part is exactly the staleness this prevents.
source "${origin_dir}/config/${target_board}/proj_config.tcl"

new_project \
    -name        "ip_gen" \
    -location    "$work_dir" \
    -family      "$proj::die_family" \
    -die         "$proj::die_eval" \
    -package     "$proj::eval_package" \
    -die_voltage "$proj::die_voltage" \
    -speed       "$proj::die_speed" \
    -part_range  "$proj::eval_part_range" \
    -hdl         "$proj::hdl_lang" \
    -adv_options "$proj::io_deft_std"

# create_design generates the RTL as it runs, so there is no separate generate
# step. Definitions are sourced rather than copied: a copy is a second
# definition, and the two diverge the first time one is edited.
foreach definition $definitions {
    puts "Generating [file rootname [file tail $definition]]"
    source $definition
}

file delete -force $out_dir
file mkdir $out_dir

# Libero writes each component to <project>/component/work/<name>. Move them
# all out, whatever they are called.
set generated_root "${work_dir}/component/work"
set produced [glob -nocomplain -directory $generated_root -type d *]
if {[llength $produced] == 0} {
    puts "ERROR: no components were generated under $generated_root"
    exit 1
}

foreach component $produced {
    set name [file tail $component]
    file rename $component [file join $out_dir $name]
    puts "  -> [file join $out_dir $name]"
}

# The scratch project is not deleted here: Libero writes the project file out
# again after the script returns, which would recreate it. `make ip` removes
# it once Libero has exited.

puts "Generated [llength $produced] component(s) into $out_dir"
