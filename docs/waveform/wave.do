onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /fifo_tb/clk
add wave -noupdate /fifo_tb/rst_n
add wave -noupdate -radix unsigned /fifo_tb/fill_level
add wave -noupdate /fifo_tb/full
add wave -noupdate /fifo_tb/empty
add wave -noupdate -expand -group write -radix decimal /fifo_tb/write/data
add wave -noupdate -expand -group write /fifo_tb/write/vld
add wave -noupdate -expand -group write /fifo_tb/write/rdy
add wave -noupdate -expand -group read -radix decimal /fifo_tb/read/data
add wave -noupdate -expand -group read /fifo_tb/read/vld
add wave -noupdate -expand -group read /fifo_tb/read/rdy
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {30 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 39
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
WaveRestoreZoom {0 ps} {88 ps}
