# pc/ — 上位机（继承自 Immersive_Controller）

来源：`E:/qs/Immersive_Controller/pc_host`。本目录是**元件准备**，尚未适配新的输入源。

## 内容

| 文件 | 作用 | 在新方案里的去留 |
|---|---|---|
| `host/main.py` | 主循环：融合 IMU/手势 → 更新虚拟手柄 | **保留**，输入源待改 |
| `host/core/network_process.py` | UDP 收包解析（`DATA,` / `CALIBRATE` / `CONFIG,`） | **保留**，扩展接收 FPGA 检测结果 |
| `host/core/shared_state.py` | 多进程共享状态 | **保留** |
| `host/core/virtual_controller.py` | vgamepad → Xbox 360 虚拟手柄 | **保留**（核心输出） |
| `host/core/cv_process.py` | MediaPipe 手/姿态识别 | **删除**（视觉改由 FPGA 承担） |
| `host/utils/config.py` | UDP 端口等常量 | 保留 |
| `host/tests/test_latency.py` | 共享内存与手柄注入延迟测试 | 保留，**需补真正的端到端测量** |
| `reference/` | 原项目 PRD / 技术设计 / 研究文档 | 参考 |

## 现有协议（必须保持兼容）

UDP，绑定 `0.0.0.0:5005`，文本包：

```
DATA,joyX,joyY,qx,qy,qz,qw,ax,ay,az,buttons
CALIBRATE
CONFIG,DODGE_SENSITIVITY,<0-100>
```

- `joyX/joyY`：−1.0 ~ 1.0，左摇杆
- `q*`：四元数 x,y,z,w（手机姿态）
- `a*`：线性加速度 m/s²
- `buttons`：位掩码 —— bit0=A bit1=B bit2=X bit3=Y bit4..7=方向十字
  bit8=Start bit9=Back bit10=Guide bit11=L3 bit12=R3 bit15=LB bit16=RB bit17=LT bit18=RT

完整解析见 `host/core/network_process.py`。

## 新方案要加的协议（FPGA → PC）

线 B 的检测结果建议复用同一条 UDP 通道：

```
TGT,<cls>,<x>,<y>,<conf>,<frame>     # 单目标，80x45 网格坐标
SCENE,<0|1>                          # 场景事件（如需）
LAT,<micros>,<frames>                # 板端推理耗时与对齐帧数
```

PC 侧只需在 `network_process.py` 加三个分支、`shared_state.py` 加三个字段。

## 已知问题（继承自原项目，改造时一并处理）

- `test_latency.py` 只测共享内存读写与 vgamepad 调用，**从未测过端到端**；
- 原 PRD 声称 <20 ms，但手机链路按采样率算下限就是 25 ms；
- `cv_process.py` 与 `main.py` 的输入处理耦合较紧，删除 CV 时要一并清理共享状态字段。
