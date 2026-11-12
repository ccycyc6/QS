# 线 B 展示线：FPGA 实时手势/动作识别 demo

> 定位：**展示技术能力**，不接游戏、不接手机、不接手柄。
> 线 A（手机 IMU + MediaPipe + 虚拟手柄）是另一条独立线，不在本文件范围。
> 本线也不修改线 A 的代码。

---

## 1. 展示什么

- HDMI 720p60 输入（PC 全屏摄像头画面，或带 HDMI 输出的摄像头）；
- 11 层 conv/ReLU CNN → 80×45 逐格手势热图；
- frame_argmax → 每帧的 class / gx / gy / conf；
- OSD 实时框 + 类别颜色；
- 自研 RV32 核作为**帧级调度器**：去抖、hold、swipe、动作码 → UART / OSD；
- 所有动作都来自“单帧视觉 + 格子时序”，不使用手机 IMU、MediaPipe 或人体姿态。

---

## 2. 数据路径

~~~text
PC webcam
  -> PC fullscreen 1280x720@60
  -> HDMI
  -> 板子 11 层 CNN
  -> frame_argmax {class, gx, gy, conf}
       |-> box_overlay -> HDMI OUT（框/颜色）
       |-> rv_mmio -> RV32 调度器 -> UART 事件 / OSD 动作码
~~~

为什么走 PC HDMI：板子的视觉输入是 HDMI 720p60，不是 USB 摄像头。
PC 把摄像头画面全屏输出到 1280×720@60，板子再采集。

**域差异**：摄像头 → PC 显示 → HDMI 采集，颜色、缩放、噪声都会变。
上板前用 HDMI 采集到的 100–200 帧做一次评估/微调；PC 摄像头的 89% 不能直接当作板端结果。

---

## 3. 动作定义（建议，属于展示语义）

单帧 CNN 稳定输出的是静态手势；“动作”由 RV 调度器从 class/cell/conf 的时序推导：

| 动作 | 条件（示例） | 输出 |
|---|---|---|
| HOLD | 同一类连续 N 帧且 conf ≥ 阈值 | 动作码 + UART |
| SWIPE_L / SWIPE_R | 同类且 gx 在时间窗内位移 ∓6 格 | 动作码 |
| SWIPE_U / SWIPE_D | 同类且 gy 位移 | 动作码 |
| SEQUENCE | 拳头→张掌 在 1 s 内 | COMBO |

这些是**演示语义**，不等于线 A 的游戏动作。
不要承诺：手机下挥、肘角、鼻速、左手识别——那些需要 IMU/Pose，属于线 A。

---

## 4. RV32 调度器合同

- 输入（rv_mmio）：valid、class、gx、gy、conf、frame_id；
- 输出：action_code、event_pulse；可选 UART 文本；
- 固件逻辑：环形窗口/多数投票、hold 计时、位移、冷却时间；
- 参考实现：pcvision/gesture/actions.py（PC 端同一套状态机，便于对照）；
- 资源：只读 MMIO + 小状态机，不碰数据通路；预计几百字节固件，LUT 影响可忽略；
- 时钟：可与视觉同频或 pixclk/2；它只做帧级调度，不需要高主频。

这一块正好是“自研 RISC-V 核做小调度器”的展示点：CNN 负责看，RV 负责判断动作。

---

## 5. 展示输出

- **HDMI**：沿用 box_overlay 的框；用框颜色/类别码区分手势；动作码可用颜色或位置表示；
- **UART**：每个动作事件输出一行文本/JSON，PC 串口终端展示；
- 当前 OSD 文本缓冲缺失（PROGRESS B6）。要显示文字标签需要另加 5×7 字库；
  第一版建议“框 + 颜色 + UART”，最稳。

---

## 6. 里程碑

1. PC 端训练手势，bit-exact 评估（已有工作台）；
2. 打包 .mem/.vh，出 gesture-only 位流（覆盖 11 层权重）；
3. HDMI 输入：PC 全屏摄像头 → 板子；采 100–200 帧做域适配；
4. RV 调度器：hold/swipe 状态机 + UART；
5. 演示脚本：固定动作序列，录屏/现场展示。

---

## 7. 不做什么

- 不接游戏、不接虚拟手柄；
- 不接手机 IMU、MediaPipe、Pose；
- 不做线 A 的 5 个游戏动作；
- 不做多目标 NMS、精确 bbox、目标跟踪；
- 不为了让“动作”好看而改 CNN 数据通路。

---

## 8. 需要确认

1. 动作词表：HOLD / SWIPE / SEQUENCE 具体想展示哪几个？
2. 板子输入：PC HDMI 全屏摄像头，还是 HDMI 摄像头？
3. 输出：UART 日志、HDMI 框，还是必须加 ASCII 文字？
4. RV 调度器：第一版就上板跑，还是先在 PC actions.py 里对照演示？
