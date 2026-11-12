# 动作控制器评估（手机 IMU + MediaPipe）

> **这是线 A（游戏控制）的评估，不属于线 B 展示线。**
> 本展示线不依赖、不修改线 A；这里只保留评估结论，方便以后回看。

评估日期：2026-11-12
评估对象：手机加速度 + MediaPipe Hands/Pose + 时序速度 → Xbox 手柄按键
结论：**PC/Windows 上可以做，而且仓库里已经有实现；当前 FPGA 手势 CNN 做不了这套。**

---

## 1. 先说清两条线

| 线 | 输入 | 输出 | 能否做表里的动作 |
|---|---|---|---|
| **手势 CNN / 工作台** | 单帧摄像头 1280×720 | 80×45 逐格类别 + 格子 | 只能做静态手势；没有关键点、没有头/肘角度 |
| **Immersive Controller（pc/host）** | 手机 IMU UDP + MediaPipe Hands/Pose | 5 个布尔动作 + Xbox 手柄 | **就是表里的 5 个动作** |

所以这张表不是“再训练一个手势模型”，而是 pc/host 这条 PC 上位机线的规格。
它和刚做的 FPGA 手势模型是两套东西，不要混在一起。

---

## 2. 表与代码对照

| # | 表里的动作 | 现有实现 | 位置 |
|---|---|---|---|
| 1 | 手机向下挥（攻击）→ RB | acc_y < -30.0 or acc_z < -30.0 | pc/host/main.py 第 147 行 |
| 2 | 左手握拳 + 抬起（治疗）→ X | 至少 2 根手指弯曲 + wrist.y < 0.45 + 左手 | pc/host/core/cv_process.py 第 133 行 |
| 3 | 左臂弯曲举在头下（举盾）→ LB | 手腕低于鼻子 + 肘角 < 90° | pc/host/core/cv_process.py 第 225–249 行 |
| 4 | 左臂向外快速挥（弹反）→ LT | 左腕 x 速度 < -2.5 | pc/host/core/cv_process.py 第 213 行 |
| 5 | 头部快速下压/下蹲（闪避）→ B | 鼻子 y 速度 > 阈值（默认 2.5） | pc/host/core/cv_process.py 第 185–194 行 |
| — | 按键映射 | X / B / LB / LT / RB | pc/host/core/virtual_controller.py |

所以你表里的阈值和映射不是设想，是代码里已经写好的 MVP。

---

## 3. 本机实测（Ubuntu 24.04 / RTX 4060 / Python 3.12）

MediaPipe 版本兼容性：

| 版本 | Python 3.12 轮子 | 还有 mp.solutions | 结果 |
|---|---|---|---|
| 0.10.9 | **没有**（只到 cp311） | 有 | 当前 Python 3.12 装不上 |
| **0.10.21** | **有** | **有** | **实测可用** |
| 0.10.35 | 有（py3-none） | **没有** | 现有代码直接报 AttributeError: module 'mediapipe' has no attribute 'solutions' |

0.10.21 隔离环境实测：

- 1280×720 静帧：Hands 检出 1 只手；Pose 检出上半身；
- 640×480 连续推理（Hands complexity=1 + Pose complexity=0）：
  **45.1 ms/帧，约 22 fps**（CPU/XNNPACK；Python MediaPipe 没用上 GPU delegate）；
- 端到端估计：摄像头 + 推理 + 网络 + 手柄更新，**约 50–120 ms**；
- 因此 PRD 的 **<20 ms 不现实**。攻击/举盾可以接受，**弹反（LT）会偏慢**。

> 测试用的临时 venv 已删除，没有动主手势环境。

---

## 4. 现在缺什么 / 风险

1. **没有 Android 手机端 App**
   仓库只有 PC 端；UDP 包格式在 pc/host/core/network_process.py：
   DATA,joyX,joyY,qx,qy,qz,qw,ax,ay,az,buttons（60 Hz）。
   没有手机 App 就没有摇杆、加速度、校准按钮，第 1 行无法真正触发。

2. **vgamepad 是 Windows 专用**
   依赖 ViGEmBus；Ubuntu 上不能直接注入 Xbox 手柄。要么在 Windows 跑 host，
   要么在 Linux 用 uinput/evdev 重写 virtual_controller.py。

3. **没有断连看门狗**
   PRD 要求 500 ms 没收到手机数据就松开所有键；当前 network_process /
   main.py 没有 last-packet 超时。手机断线时按键可能卡住，游戏里有风险。

4. **启发式阈值不够稳**
   - 手指弯曲只看 2D y，手旋转后会误判；
   - wrist.y < 0.45 是绝对画面坐标，换机位/距离就漂；
   - 肘角在 2D 归一化坐标里算，透视会偏差；
   - 速度是相邻帧差分，landmark 抖动会误触发（代码里没有 One Euro/Kalman）；
   - 镜像画面下手性（Left/Right）需要现场校验。

5. **摄像头参数**
   config.py 是 640×480；当前工作台是 1280×720。换分辨率要同步调阈值。

6. **没有校准流程**
   PRD 有“零点校准”，代码只有 CALIBRATE 标志，手机端要配合发送。

---

## 5. 逐项可行性

| # | 动作 | PC / Windows | Ubuntu 原型 | 当前 FPGA |
|---|---|---|---|---|
| 1 | 手机下挥 | 可行（需手机 App） | 可行（UDP 模拟器可测） | 不行：IMU 未接，线 A 只有桩 |
| 2 | 握拳抬起 | 可行（Hands） | 可行 | 只能识别“拳头”静态类；左手/抬起时序没有 |
| 3 | 举盾 | 可行但易受遮挡 | 可行 | 不行：需要 Pose 关键点 |
| 4 | 弹反 | 可行但延迟/抖动 | 可行 | 不行：需要 Pose + 时序 |
| 5 | 闪避 | 可行但易受镜头晃动 | 可行 | 不行：需要 Pose/头部关键点 |

**FPGA 结论**：2–5 需要完整姿态/手部关键点模型，远超现在 11 层 80×45 CNN 的
预算和接口；第 1 行需要先有真实 IMU + UART 引脚。不要把这张表当成 FPGA 需求。

---

## 6. 工作量估计

| 事项 | 估计 |
|---|---|
| Windows 环境 + 现有 host 跑通（已有手机 App） | 0.5–1 天 |
| 写一个最小 Android App（摇杆 + 传感器 + UDP + 校准） | 3–5 天 |
| 看门狗 + One Euro/3D 角度 + 阈值调参 | 1–2 天 |
| Ubuntu 虚拟手柄（uinput/evdev） | 1–2 天 |
| 端到端延迟/稳定性验收 | 1–2 天 |
| FPGA 做这套 | 不建议；数周起步且要换模型 |

结论：**PC/Windows 上约 1 周可到“能玩”的原型**（若手机 App 已有则 2 天）；
要做到“识别准、延迟可接受”约 2 周。

---

## 7. 推荐路线

1. **主机选 Windows**（vgamepad + ViGEmBus 最省事）；Python 3.12 +
   mediapipe==0.10.21 + numpy<2 + opencv-contrib-python。
2. **先补手机端 App**（或确认你已有）：虚拟摇杆、加速度/陀螺仪、校准按钮，
   按上面的 UDP 文本格式 60 Hz 发送。
3. **加安全看门狗**：500 ms 无包 → 松开所有键、摇杆归零。
4. **替换不稳定启发式**：手指弯曲用 3D 关节角；手腕高度相对鼻子/肩膀；
   速度用 100–200 ms 窗口 + One Euro 平滑。
5. **先 dry-run 再进游戏**：用 UDP 模拟器 + 屏幕 HUD 验证 5 个动作；
   再用 joy.cpl 确认虚拟手柄；最后进游戏调阈值。
6. **FPGA 不参与这套动作**；手势 CNN 继续做静态手势/可选辅助输入即可。

---

## 8. 复现实验

隔离环境（不要装进手势 venv）：

~~~bash
python3 -m venv ~/action-env
. ~/action-env/bin/activate
pip install "mediapipe==0.10.21" "numpy<2" opencv-contrib-python
python - <<'PY'
import mediapipe as mp
print(mp.__version__, hasattr(mp, "solutions"))
PY
~~~

Windows 额外装：

~~~powershell
pip install vgamepad
# 再安装 ViGEmBus 驱动
~~~
