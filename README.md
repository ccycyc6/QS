# ScreenSense

两条互不依赖的线：

- **线 A（控制）** 加速度计 → FPGA 采集 → PC → 游戏。延迟目标 7–10 ms。
- **线 B（展示）** 摄像头 720p60 → FPGA 加速器 → OSD 合成 → HDMI 实时 UI。

线 B 的加速器底座已复现（PDS 2025.2，位流已生成）；RISC-V 核与上位机已备料，尚未接入。

---

## 目录

    ScreenSense/
    ├── fpga/
    │   ├── rtl_pds/                  视觉 RTL（顶层 + 11 层网络 + overlay）
    │   ├── prj_pds/                  PDS 工程（相对路径） + 4 个 IP
    │   ├── conv_data_yolov3_new_pds/ YOLO 权重 .mat（133 MB）
    │   ├── conv_data_hex_pds/        仿真输入 hex（43 MB）
    │   ├── python_script/            权重生成器
    │   ├── sim_pds/                  16 个 testbench
    │   ├── ares/                     ← RISC-V 核（档 2 备料，未接入）
    │   └── doc/                      原复现指南
    ├── pc/
    │   ├── host/                     ← 上位机（继承 Immersive_Controller）
    │   └── reference/                原项目 PRD / 技术设计
    ├── bitstreams/                   已生成位流（含 sha256）
    ├── docs/                         PLAN / STATUS / DECISIONS
    ├── tools/                        构建与仿真脚本
    └── imu/                          线 A（待建）

---

## 关键事实

| 项 | 值 |
|---|---|
| 器件 | PG2L200H-6IFBB676（盘古 200Pro+） |
| 输入 | **1280×720@60 硬约束**，H_TOTAL 1650 / V_TOTAL 750 |
| 网络 | 11 层 conv/ReLU/maxpool，输出 80×45 × 16 通道 |
| 推理延迟 | 1.14 ms @148.5 MHz |
| PnR 资源 | CLMA 62% / LUT 53% / DRM36K 47% / APM 36% |
| 时序 | WNS **+116 ps**、TNS 0（裕量很薄） |
| 构建 | PDS **2025.2-SP3**，全流程 17 分 23 秒 |
| 现所有权重 | **车牌检测器**，改用途必须重训 |
| 后处理 | 逐格取通道最大；**无 NMS、无 bbox 回归、无跟踪** |

---

## 状态

| 部分 | 状态 |
|---|---|
| 视觉底座复现 | ✅ 位流已生成，时序收敛 |
| 全局 argmax（B5） | ✅ Verilator 仿真通过 |
| RISC-V 核备料 | ✅ 已放入 `fpga/ares/`，未接入 |
| 上位机备料 | ✅ 已放入 `pc/host/`，未适配 |
| OSD 仪表盘（B6） | ⬜ |
| 模型重训（B2–B4） | ⬜ |
| 线 A（IMU） | ⬜ |

详见 [docs/PLAN.md](docs/PLAN.md)、[docs/STATUS.md](docs/STATUS.md)、[docs/DECISIONS.md](docs/DECISIONS.md)。
