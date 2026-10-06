onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group CLK_RST /watchdog_tb/pclk
add wave -noupdate -expand -group CLK_RST /watchdog_tb/presetn
add wave -noupdate -expand -group APB /watchdog_tb/psel
add wave -noupdate -expand -group APB /watchdog_tb/penable
add wave -noupdate -expand -group APB /watchdog_tb/pwrite
add wave -noupdate -expand -group APB -radix unsigned /watchdog_tb/paddr
add wave -noupdate -expand -group APB -radix unsigned /watchdog_tb/pwdata
add wave -noupdate -expand -group APB -radix unsigned /watchdog_tb/prdata
add wave -noupdate -expand -group APB /watchdog_tb/pready
add wave -noupdate -expand -group APB /watchdog_tb/pslverr
add wave -noupdate -expand -group WD_CTRL -color Gold -itemcolor Gold /watchdog_tb/dut/wd_clear
add wave -noupdate -expand -group WD_CTRL -radix unsigned /watchdog_tb/dut/wd_timeout_val
add wave -noupdate -expand -group WD_CTRL -color {Cornflower Blue} -itemcolor {Cornflower Blue} /watchdog_tb/dut/wd_refresh
add wave -noupdate -expand -group WD_STATUS /watchdog_tb/wd_active
add wave -noupdate -expand -group WD_INTERNAL /watchdog_tb/dut/watchdog_inst/curr_state
add wave -noupdate -expand -group WD_INTERNAL /watchdog_tb/dut/watchdog_inst/next_state
add wave -noupdate -expand -group WD_INTERNAL -radix unsigned /watchdog_tb/dut/watchdog_inst/counter
add wave -noupdate -expand -group TEST -radix unsigned /watchdog_tb/fail_count
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {3469381 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 488
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {18076800 ps}
