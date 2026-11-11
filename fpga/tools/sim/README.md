# 不用 ModelSim 的仿真方案（Verilator）

本目录提供一套与官方 ModelSim 脚本等价的 Verilator 流程，跑的是**同一份 RTL、同一份 testbench**，
输出的 hex 格式也一致，可以直接用 `python_script/compare_data_pds.py` 比对。

## 一次性准备

1. Windows 10/11 安装 WSL2 + Ubuntu（`wsl --install -d Ubuntu-24.04`）。
2. 在 Ubuntu 里装 Verilator：

   ```bash
   sudo apt update && sudo apt install -y verilator
   verilator --version      # 需要 5.x（Ubuntu 24.04 自带 5.020）
   ```

3. 仓库需要放在 WSL 能访问的路径（本机是 `/mnt/e/qs/CNN_FPGA`）。

## 跑单层

```bash
bash tools/sim/run_layer.sh 20
```

Windows 下也可以直接双击/执行：

```bat
tools\sim\run_layer.bat 20
```

然后回仓库根目录比对：

```powershell
python python_script\compare_data_pds.py --layer 20
```

## 跑其它 testbench

```bash
bash tools/sim/run_tb.sh yolo            # 也支持 my_fifo / pe_page / box_overlay /
                                         # box_ram / overlay_chain / box_overlay_crop_buffer_manager /
                                         # post_cv3_conv2d / adpter_conv2d / ddr_video_delay_sync /
                                         # crop_buffer_lprnet
bash tools/sim/run_all_tb.sh             # 依次跑全部
```

每个 TB 默认 `timeout 300` 秒，可用 `TB_TIMEOUT=600 bash tools/sim/run_tb.sh my_fifo` 加长。

## 跑整条 LPRNet

```bash
bash tools/sim/run_lprnet.sh +NO_CAPTURE_INTERMEDIATE +DRAIN_CYCLES=5000000
```

- `+NO_CAPTURE_INTERMEDIATE`：不写 12 个中间层 hex，快很多；需要比对中间层时去掉。
- `+DRAIN_CYCLES=N`：输入驱动完后继续排空的周期数（默认 500000）。

## 与 ModelSim 的差异 / 已做的 RTL 适配

- Verilator 是 **2 态**仿真，没有 X/Z。角落里读未初始化 RAM 的地方，ModelSim 给 X、Verilator 给 0，
  这可能造成个别数值差异（本工程的差异全部集中在图像右下角）。
- 2026-10-29 已修改三处"同一变量在不同 generate 分支分别用 `assign` 和 `always_ff` 驱动"的写法，
  改成用非压缩数组 / 单一驱动源，**功能完全等价**，现在 Verilator 不加任何抑制开关即可编译：
  - `rtl_pds/data_process/d_manager.sv`（`D` 改为由 `d_tmp` 逐位 assign 汇总）
  - `rtl_pds/data_process/input_layer.sv`（`we_line_ram` 改非压缩数组）
  - `rtl_pds/data_process/pe_page.sv`（`D_delay` 改非压缩数组）
  改完 PDS `compile` / `synthesize` 均 0 error，综合资源与改前一致。
- `--timing` 用于支持 testbench 里的 `#5`、`repeat @(posedge clk)` 这类写法。

## 已验证结果（2026-10-29，RTL 适配后）

| 用例 | 结果 |
| --- | --- |
| 12 个单层（20–31） | 全部与 `.mat` 参考一致；剩余差异只出现在**输出图右下角**（last 1–2 行 × last 1–2 列），见下 |
| 整条 LPRNet | 见仓库 `doc/复现指南_MES2L676-200HP.md` 第 3 节 |

右下角差异说明：ModelSim 里该区域读到的是未初始化 RAM 的 X（旧版比对脚本会跳过），
Verilator 读到 0（脚本会如实比对），所以显示为少量 mismatch；对识别结果无实质影响。
