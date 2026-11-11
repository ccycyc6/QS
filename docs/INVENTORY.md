# 物料清单：有什么、缺什么

更新时间：2026-11-11

判定标准：**“齐”= 源码在仓库里、能直接构建或运行**；外部安装的驱动/工具链不算。

---

## 线 B：视觉展示

| 物料 | 状态 | 位置 |
|---|---|---|
| 视觉 RTL（11 层网络、overlay、DDR 延迟、HDMI） | ✅ | `fpga/rtl_pds/`（360 文件） |
| PDS 工程 + 4 个 IP（ms72/PLL/ip_fifo/ddr3_test） | ✅ | `fpga/prj_pds/` + `ipcore/` |
| 网络权重 `.mat` | ✅ | `fpga/conv_data_yolov3_new_pds/`（133 MB） |
| 已生成的 `.mem` / `.vh` | ✅ | `fpga/rtl_pds/data_process/` |
| 权重生成器 | ✅ | `fpga/python_script/CnnHardwareGenerator_pds.py` |
| 仿真 testbench（16 个） | ✅ | `fpga/sim_pds/*.sv` |
| 仿真运行脚本 | ✅ | `fpga/tools/sim/` |
| 仿真输入 hex | ✅ | `fpga/conv_data_hex_pds/`（43 MB） |
| 引脚映射生成脚本 | ✅ | `fpga/tools/pinmap/` |
| 参考图片 / 测试输入 | ✅ | `fpga/data_pics/`（23 张）、`fpga/usb_data/` |
| 构建脚本 | ✅ | `tools/build_full.tcl` + `tools/make_build_tcl.ps1` |
| 位流 | ✅ | `bitstreams/cnn_2025.2_02EFD676.sbit` |
| 全局 argmax | ✅ | `fpga/rtl_pds/target/frame_argmax.sv` + TB |
| **烧写脚本** | ❌ | PDS 自带 program 工具，需补一个 `tools/program.tcl` |
| **OSD 文本缓冲** | ❌ | B6 要新写：双口 BRAM + vsync 翻页 + 数值格式化 |
| **OSD 布局/仪表盘** | ❌ | 要新写 |

---

## RISC-V 核（档 2）

| 物料 | 状态 | 位置 |
|---|---|---|
| ARES 核 RTL（5 级 Mundus + SoC + 板级） | ✅ | `fpga/ares/rtl/`（178 文件） |
| 板级约束 + 流程 tcl | ✅ | `fpga/ares/pango/` |
| 裸机运行时 + 链接脚本 | ✅ | `fpga/ares/abstract-machine/` |
| 原仓库构建入口（参考） | ✅ | `fpga/ares/Makefile`、`common.mk` |
| 编译工具链 | ⚠️ 外部 | `E:/qs/toolchain/riscv`，不入库 |
| **裁剪后的核** | ❌ | R2 待做：砍加速器/缓存/DRAM 阵列/IROM |
| **MMIO 寄存器块** | ❌ | R3 要新写 |
| **固件（C）** | ❌ | R4 要新写 |

---

## 上位机

| 物料 | 状态 | 位置 |
|---|---|---|
| PC host（UDP 接收 + vgamepad 注入） | ✅ | `pc/host/`（10 文件） |
| 原项目 PRD / 技术设计 | ✅ | `pc/reference/` |
| Python 依赖清单 | ✅ | `pc/host/requirements.txt` |
| ViGEmBus 驱动 | ⚠️ 外部 | 需单独安装（github.com/nefarius/ViGEmBus） |
| **适配 FPGA 输入** | ❌ | 删 `cv_process.py`、加 `TGT/SCENE/LAT` 解析 |

---

## 线 A：IMU 控制

| 物料 | 状态 |
|---|---|
| I2C 采集 RTL | ❌ 完全没有 |
| 高通/低通滤波 | ❌ |
| PC 侧解析与融合 | ❌ |
| 加速度计型号确认 | ❌ 需要你提供型号（是否 6 轴） |

---

## 模型重训管线（B2–B4）

| 物料 | 状态 | 说明 |
|---|---|---|
| 下游：`.mat` → `.vh/.mem` | ✅ | `CnnHardwareGenerator_pds.py` |
| 下游：单层比对脚本 | ✅ | `fpga/python_script/compare_data_pds.py` |
| **上游：录屏抽帧** | ❌ | 要新写 |
| **上游：中心点标注工具** | ❌ | 要新写 |
| **上游：热图训练脚本** | ❌ | 要新写（可参考 `report/5-stage-baseline/yolo_gesture/ml/`） |
| **数据集** | ❌ | 要采（约 3000 帧） |

---

## 一句话总结

**“能复现现有视觉工程”，源码齐了**——RTL、IP、权重、仿真、构建、位流全在，且已实测跑通（17 分 23 秒出位流，时序收敛）。

**“做出新东西”，还差三块新代码**：OSD 文本/仪表盘、裁剪后的核 + MMIO + 固件、线 A 的 IMU 采集。
训练侧的上游（采集 / 标注 / 训练）也要新写，只有下游打包能用。
