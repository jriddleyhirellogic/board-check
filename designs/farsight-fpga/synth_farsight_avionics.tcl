source ./synth.tcl

if { $argc == 8 } {
    set target_board [lindex $argv 0]
    set project_name [lindex $argv 1]
    set no_synth     [lindex $argv 2]
    set riscv_init   [lindex $argv 3]
    set hw_major     [lindex $argv 4]
    set hw_minor     [lindex $argv 5]
    set hw_fix       [lindex $argv 6]
    set hw_build     [lindex $argv 7]
    puts "Using provided arguments: -target_board $target_board -project_name $project_name -no_synth $no_synth -riscv_init $riscv_init -hw_major $hw_major -hw_minor $hw_minor -hw_fix $hw_fix -hw_build $hw_build"
    create_target                       \
        -target_board $target_board     \
        -project_name $project_name     \
        -no_synth     $no_synth         \
        -riscv_init   $riscv_init       \
        -hw_major     $hw_major         \
        -hw_minor     $hw_minor         \
        -hw_fix       $hw_fix           \
        -hw_build     $hw_build
} else {
    error "Expected 8 script arguments: <target_board> <project_name> <no_synth> <riscv_init> <hw_major> <hw_minor> <hw_fix> <hw_build>.\nBuild through the Makefile, e.g.: make VERSION=2.0.1 BUILD=4"
}
