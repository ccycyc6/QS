# fpga/ares — RISC-V 核（档 2：裁剪版）

来源：`E:/qs/ARES`（自研 ARES-L RV32IM，5 级单发射流水线，Pango PG2L200H）。
本目录是**元件准备**，尚未接入视觉工程。原始说明见 `README-ARES.md`。

## 内容

| 路径 | 内容 |
|---|---|
| `rtl/pipeline/` | 5 级核（Mundus）+ I$/D$/SoC/板级顶层 |
| `rtl/accel/` | mtx9 / state9 / list9 三个 CoreMark 加速器（**档 2 要砍**） |
| `rtl/video/` | 视频相关（本工程不用） |
| `pango/` | 板级约束 pipeline_board.fdc、流程 tcl |
| `abstract-machine/` | 裸机运行时与链接脚本（编固件用） |
| `docs/` | 原仓库微架构/加速器文档 |
| `Makefile` / `common.mk` | 原仓库构建入口（参考用） |

## 档 2 的裁剪清单

按 `docs/DECISIONS.md` D-004，保留控制面，砍掉与 CoreMark 相关的部分：

| 砍掉 | 原因 | 实测影响 |
|---|---|---|
| `rtl/accel/*`（三个引擎） | 线 B 不需要 CoreMark 加速 | −2,799 LUT、−16 APM、−6 DRM |
| 4 KiB I$ / 8 KiB D$ | 控制面程序很小，不需要缓存 | −8.5 DRM |
| 256 KiB DRAM 阵列 | 只需要几 KiB RAM | −64 DRM |
| 多核 AMP / mc 顶层 | 单核足够 | — |
| 32 KiB IROM | 缩到 4–8 KiB | −约 6 DRM |

裁剪后预估：**约 4–5k LUT（占视觉设计的 4–5%）、DRM 增加 <10 块**。
（依据：去掉三个加速器的 ARES 实测为 5,365 LUT / 5,045 FF / 80.5 DRM，其中 72 DRM 是 IROM+DRAM 阵列。）

## 目标形态

```
独立 50 MHz 时钟域（视觉工程 GPLL 已用 4/10 路，还有余量）
  RV32 核 ── MMIO ──► 寄存器块（置信度门限 / ROI / 类别屏蔽）
          ── 读写 ──► OSD 文本缓冲（检测结果格式化成 ASCII）
          ── UART ──► 上位机
跨域：异步 FIFO（视觉工程已有 my_fifo）
```

**不碰 CNN 数据通路**。数据面（148.5 MHz、WNS +116 ps）保持原样。

## 注意

- 原仓库 PnR 的 WNS −1.527 ns 来自 `mtx9_engine`，砍掉加速器后该问题随之消失。
- 原工程用 `GTP_GPLL` 直连产生 100/50 MHz；视觉工程已有自己的 PLL 与时钟树（BKCL 已用 5/10）。
- 编译工具链：`E:/qs/toolchain/riscv`（riscv64-unknown-elf-gcc）。
- 本目录代码尚未接入 `rtl_pds/`，独立存在，互不影响。
