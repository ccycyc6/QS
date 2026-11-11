# 执行计划

来源：PITCH-ScreenSense.md（双线方案）。这里只保留**要做的事**和**判据**。

---

## 线 B：视觉展示（本工程承载的部分）

目标：摄像头 → 720p60 → 加速器 → OSD → HDMI，屏幕上出现框、类别、实时延迟。

### B0 部署 ✅

- 从 CNN_FPGA 取 rtl_pds / prj_pds / 权重 / 生成器 / 仿真 TB
- 判据：目录结构与相对路径完整，prj_pds/hdmi_loop.pds 中的源文件均为相对路径

### B1 构建验证（进行中）

- 用现有工程跑一次 compile → synthesize
- 判据：0 error；资源与 README 记录（LUT 51.76%）基本吻合
- **风险**：工程由 PDS 2022.2-SP6.4 生成，本机仅 2025.2

### B2 数据

- 720p60 录屏抽帧，**只标目标中心点**，不画框
- 3–4 类（普通敌 / Boss / 可交互 / 背景）
- 判据：≥3000 帧，按 session 划分验证集（不随机分帧）

### B3 输出头与训练

- 末层改为 K+1 通道热图；ReLU（不是 LeakyReLU）；BN 折叠
- 判据：浮点 mAP 达标 → INT8 不掉超过 3 个点

### B4 生成器与综合

- 改 CnnHardwareGenerator_pds.py 的 layer map，重设 PE 参数
- 约束：pe_page_num×cyc_in ≥ 输入通道；相邻层 pe_col == 下层 pe_page
- 判据：单层 compare 差异为 0（角落未初始化除外）

### B5 全局 argmax

- 现有 post_cv3_conv2d 是**逐格**取最大，需要**全帧**取最大
- 判据：仿真里与 Python 参考实现逐位一致

### B6 OSD 仪表盘

- 框（现成）+ 16×16 字符（现成，128 字形）+ 数值格式化（新增）
- 显示 LAT（周期换算）+ ALIGN（帧数）
- 判据：无撕裂（双缓冲翻页）、不占 >5% LUT

---

## 线 A：控制（imu/，待建）

- 纯 RTL 采集块（约 200 行，1–2% LUT），不引入 RV32 SoC
- 高通/低通分离：低频→倾斜，高频→冲击
- 判据：端到端 <10 ms（包内时间戳 + PC 直方图）；空挥误触发 <5%

---

## 明确不做

- 多目标 NMS（观感提升≈0，复杂度翻倍）
- 精确 bbox 回归
- 跟踪 / ID
- 中文 OSD（3500 字形，110 KB BRAM）
- ARES + 视觉合并成一颗芯片（实测：34% + 52%，装不下；砍加速器只省 1.75%）

---

## RISC-V 控制面（档 2，见 DECISIONS D-004）

目标：核只做控制面与文本面，不碰 CNN 数据通路。

### R1 备料 ✅

- `fpga/ares/` 放入 ARES 的 rtl / pango / abstract-machine / docs
- `pc/host/` 放入 Immersive_Controller 的上位机
- 判据：文件齐全，互不引用，不影响现有视觉工程的构建

### R2 裁剪

- 砍 `rtl/accel/*`、I$/D$、256 KiB DRAM 阵列、多核顶层
- IROM 缩到 4–8 KiB
- 判据：单独综合出 < 6k LUT；DRM 增量 < 10

### R3 接入（`ifdef WITH_RV`）

- 独立 50 MHz 时钟域 + 异步 FIFO（复用 `my_fifo`）
- MMIO 寄存器块：置信度门限 / ROI / 类别屏蔽
- 判据：**WITH_RV=0 与 =1 两次构建对比**，资源增量 < 5% LUT，WNS 仍为正

### R4 固件

- 读寄存器、把检测结果格式化成 ASCII 写进 OSD 文本缓冲、UART 上行
- 判据：屏幕上出现由 CPU 生成的数字；串口能收到 `TGT,` 行

### R3 状态：✅ 综合验证通过（2026-11-11）

- 复用 `pixclk_video`，不新增时钟域；ARES 源码零修改；
- 面积：LUT 49.29% → 54.34%，DRM 53.61% → 60.0%，APM 35.27% → 38.0%；
- 待办：PnR 时序验证、真实固件、MMIO 打通。

### R2 状态：⬜ 未做

三个 CoreMark 加速器仍在设计里（约 2,799 LUT / 16 APM / 6 DRM）。
