source ./synth.tcl

if { $argc == 2 } {
    set target_board [lindex $argv 0]
    set project_name [lindex $argv 1]
    puts "Using provided arguments: -target_board $target_board -project_name $project_name"
    create_target                       \
        -target_board $target_board     \
        -project_name $project_name
} elseif { $argc == 3 } {
    set target_board [lindex $argv 0]
    set project_name [lindex $argv 1]
    set variant      [lindex $argv 2]
    puts "Using provided arguments: -target_board $target_board -project_name $project_name -variant $variant"
    create_target                       \
        -target_board $target_board     \
        -project_name $project_name     \
        -variant      $variant
} else {
    error "Expected 2 or 3 script arguments: <target_board> <project_name> \[variant\]"
}