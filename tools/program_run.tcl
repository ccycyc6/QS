# JTAG download for the Pangu 200Pro+ (PG2L200H).
# Port is 60000 by default; the cdt_js server must be listening on it.
set port 60000
cfg_connect -ip 127.0.0.1 -port $port
cfg_scan_chain
cfg_assign_file -file E:/qs/ScreenSense/bitstreams/vision_2026-11-11_85631AFB.sbit -device_index 0
cfg_program -device_index 0
cfg_disconnect
cfg_close
