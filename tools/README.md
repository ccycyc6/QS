# tools

## 构建（PDS 2025.2-SP3）

```
# 1. 重新生成源清单（改过 RTL 或 .pds 后执行）
powershell -NoProfile -ExecutionPolicy Bypass -File make_build_tcl.ps1

# 2. 跑完整流程（compile -> synthesize -> dev_map -> pnr -> timing -> bitstream）
cd ../fpga/prj_pds
D:/Pango/PDS_2025.2-SP3-EN-ads/bin/pds_shell.exe -file ../../tools/build_full.tcl ^
    > ../../tools/build_full.log 2>&1
```

源清单从 `fpga/prj_pds/hdmi_loop.pds` 解析（37 个 RTL + 4 个 IP），不依赖 GUI 工程，
因为工程文件里记录的综合器路径指向 2022.2 安装位置。

## 实测耗时（本机，2025-11-11）

| 阶段 | 时间 |
|---|---|
| compile | 约 48 s |
| synthesize | 5 m 24 s |
| dev_map + pnr + timing | 约 10 m |
| gen_bit_stream | 1 m 2 s |
| **合计** | **17 m 23 s** |

峰值内存 4.95 GB。

## 产物

- 位流：`fpga/prj_pds/prj_tasks/pnr_1/generate_bitstream/hdmi_loop.sbit`（9,188,552 B）
- 时序：`.../report_timing/hdmi_loop.rtr`
- 日志：`tools/build_full.log`

## 仿真（WSL + Verilator）

```
wsl -e sh -c "cd /mnt/e/qs/ScreenSense && verilator --binary --timing \
  --top-module tb_frame_argmax -o argmax_sim \
  fpga/sim_pds/tb_frame_argmax.sv fpga/rtl_pds/target/frame_argmax.sv && ./obj_dir/argmax_sim"
```
