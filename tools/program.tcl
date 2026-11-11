# JTAG download for the Pangu 200Pro+ (PG2L200H).
#
#   D:/Pango/PDS_2025.2-SP3-EN-ads/bin/cdt_js.exe -port 65420
#   D:/Pango/PDS_2025.2-SP3-EN-ads/bin/cdt_cfg.exe -file tools/program.tcl -args {<abs path>.sbit}

cfg_connect -ip 127.0.0.1 -port 65420
cfg_scan_chain
cfg_assign_file -file %s -device_index 0
cfg_program -device_index 0
cfg_disconnect
cfg_close
