# ScreenSense

**两条互不依赖的线，跑在同一颗 FPGA 上。**

- **线 A（控制）** 加速度计 → FPGA 采集 → 串口 → PC → 虚拟手柄 → 游戏。
- **线 B（展示）** 摄像头/PC 画面 720p60 → FPGA 加速器 → OSD → HDMI 实时 UI。

目标形态：一块盘古 200Pro+（PG2L200H），同时完成**体感控制**和**实时视觉展示**，
并用自研 RISC-V 核（Mundus，**8 级流水**：IF/ID/IS/EX1/EX2/EX3/EX4/WB）做帧级调度。

---

## 架构

```
线 B（视觉）
  HDMI 720p60 ─► 11 层卷积（车牌 YOLOv3）─► post_cv3 ─► frame_argmax
                                                  │            │
                                                  ▼            ▼
                                            box_overlay    rv_mmio ──► RV32 调度器
                                                  │            │
                                                  ▼            ▼
                                             HDMI OUT      UART（待仲裁）

线 A（控制）
  加速度计（待接）─► ctrl_frame ─► uart_tx ─► 串口 ─► PC ─► vgamepad ─► 游戏
```

---

## 目录

    ScreenSense/
    ├── fpga/
    │   ├── rtl_pds/                  视觉 RTL（11 层网络 + overlay + DDR + HDMI）
    │   ├── prj_pds/                  PDS 工程 + 4 个 IP（ms72/PLL/ip_fifo/ddr3_test）
    │   ├── conv_data_yolov3_new_pds/ YOLO 权重 .mat（133 MB）
    │   ├── conv_data_hex_pds/        仿真输入 hex（43 MB）
    │   ├── python_script/            权重生成器
    │   ├── sim_pds/                  16 个 testbench
    │   ├── ares/                     ARES RV32IM 核（未改源码）
    │   ├── rtl_rv/                   新增：rv_top / rv_mmio / frame_argmax / uart_tx / ctrl_frame / 固件
    │   ├── tools/                    引脚脚本 + 仿真脚本
    │   └── doc/                      原复现指南
    ├── pc/
    │   ├── host/                     上位机（UDP + vgamepad）
    │   └── reference/                原项目 PRD / 技术设计
    ├── bitstreams/                   已生成位流
    ├── tools/                        构建脚本
    └── docs/PROGRESS.md              进度记录

---

## 关键事实

| 项 | 值 |
|---|---|
| 器件 | PG2L200H-6IFBB676（盘古 200Pro+） |
| 视觉输入 | **1280×720@60 硬约束**（H_TOTAL 1650 / V_TOTAL 750） |
| 网络 | 11 层 conv/ReLU/maxpool + LPRNet，输出 80×45 |
| 推理延迟 | 1.14 ms @148.5 MHz |
| 工具链 | PDS **2025.2-SP3**，全流程 17 分 23 秒 |
| 当前资源 | LUT **54.35%**、DRM 58%、APM 38%（视觉 + RV 核 + 串口） |
| 时序 | 视觉线 TNS=0、WNS +116 ps；**加核后尚未重测** |
| 位流 | bitstreams/vision_2026-11-11_85631AFB.sbit（视觉线，可用于上板） |

---

## 构建

```
# 基线（仅视觉）
powershell -File tools/make_build_tcl.ps1
cd fpga/prj_pds
D:/Pango/PDS_2025.2-SP3-EN-ads/bin/pds_shell.exe -file ../../tools/build_full.tcl

# 全量（视觉 + RISC-V 核 + 控制器串口）
powershell -File tools/make_build_rv_tcl.ps1
D:/Pango/PDS_2025.2-SP3-EN-ads/bin/pds_shell.exe -file ../../tools/build_rv.tcl

# 固件（39 条指令，156 字节）
powershell -File fpga/rtl_rv/fw/build_fw.ps1
```

开关在 `fpga/rtl_rv/cfg_on|cfg_off/rv_cfg.vh`：定义 `WITH_RV` 与 `WITH_CTRL`。

---

## 边界（明确不做）

- 多目标 NMS、精确 bbox 回归、目标跟踪 —— 观感提升≈0，复杂度翻倍；
- 中文 OSD（3500 字形，110 KB BRAM）；
- 辅助代打 —— 视觉只提示/门控，不进控制环。

---

详细进度、实测数据、踩过的坑、决策记录见 [docs/PROGRESS.md](docs/PROGRESS.md)。
