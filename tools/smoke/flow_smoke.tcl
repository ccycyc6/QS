set root {E:/qs/ScreenSense/tools/smoke}
set_arch -family Logos2 -device PG2L200H -speedgrade -6 -package FBB676
add_constraint [file join $root blink.fdc]
add_design [file join $root blink_top.v]
compile -top_module {blink_top} -system_verilog
synthesize -ads
dev_map
pnr
gen_bit_stream -create_bit true
puts {=== SMOKE_DONE ===}
exit
