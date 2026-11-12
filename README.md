# ScreenSense

> **当前主线：实时手势监测。** 见 [docs/GESTURE.md](docs/GESTURE.md)。
> 下文的车牌 YOLO / LPRNet 是历史视觉 demo，手势链路不读取它的权重、
> 图片或标注；上板时只复用 11 层卷积骨架，并用你训练的手势权重覆盖。

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
    ├── cam/                        摄像头 → DDR3 → HDMI（可构建，4 分钟出位流）
    │   ├── rtl/video/              37 个 RTL + yolo_stream / det_to_box / yolo_pll
    │   └── fpga/pango/             约束 + DDR3 IP + flow_cam.tcl
    ├── fpga/
    │   ├── rtl_pds/                只留 YOLO 前端（top_yolo + 13 个层模块 + 权重 mem）
    │   ├── python_script/          权重打包生成器
    │   └── ares/                   RISC-V 核（另一条线，本线未使用）
    ├── ml/                         训练模板 / .mat 导出 / 硬件打包
    ├── pcvision/gesture/           手势全链路：采集→训练→量化→位精确→打包
    ├── pc/host/                    手机 IMU + MediaPipe 动作控制器（PC/Windows）
    ├── docs/                       MODEL.md（模型合同）/ PROGRESS.md（进度）
    │                               GESTURE.md（手势训练与上板）
    │                               ACTION_CONTROLLER.md（动作控制器评估）
    ├── bitstreams/cam_yolo.sbit    当前位流
    └── tools/                      烧写脚本

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

## 两个系统怎么用

| 系统 | 路径 | 用途 |
|---|---|---|
| **Ubuntu**（真机，双系统） | `/mnt/e/qs/ScreenSense` | 采集、训练、量化、位精确预览、打包 |
| **Windows** | `E:\qs\ScreenSense` | PDS 综合、JTAG 烧写 |

仓库在同一个 NTFS 分区上，两侧共用，不用拷文件。
完整步骤见 [docs/WORKFLOW.md](docs/WORKFLOW.md)。

Ubuntu 侧第一次用先跑：

```bash
cd /mnt/e/qs/ScreenSense/pcvision
bash setup.sh          # 建 venv、装依赖（--cuda 可装 GPU 版 torch）
bash doctor.sh         # 逐项自检：包、CUDA、摄像头、权限、图形会话
```

### 手势训练（本机 PC 摄像头）

训练环境隔离在仓库外（默认 `<repo>/../gesture-env`），可整体删除腾空间：

```bash
bash pcvision/gesture/setup_env.sh              # 一次性：venv + torch/cu124
bash pcvision/gesture/doctor.sh                 # 摄像头/CUDA 自检
bash pcvision/gesture/app.sh                    # 网页工作台（推荐）
bash pcvision/gesture/record.sh --rounds 4      # 引导式采集（每类按一次空格）
bash pcvision/gesture/run_pipeline.sh all       # 训练→量化→位精确评估→打包
bash pcvision/gesture/manifest.sh               # 安装清单（体积）
bash pcvision/gesture/cleanup.sh                # 预览清理；--yes 执行
```

训练满意后再按 [docs/GESTURE.md](docs/GESTURE.md) 第 7 节在 Windows 上综合、烧写。

---

## 构建（Windows）

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

模型怎么训、怎么插进来见 [docs/MODEL.md](docs/MODEL.md)；
进度、实测数据、踩过的坑见 [docs/PROGRESS.md](docs/PROGRESS.md)。