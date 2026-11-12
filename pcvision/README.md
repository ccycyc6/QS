# pcvision — 上板前的 PC 训练与验证平台

用本机摄像头采集、训练、验证，**在不上板的情况下**确认算法与量化都成立。

> **当前主线是手势。** 请看 `pcvision/gesture/` 与 [docs/GESTURE.md](../docs/GESTURE.md)：
> 隔离环境、引导式采集、训练、量化校准、位精确评估、动作层、实时监测、打包。
> 本文余下部分是最早的“单格目标检测”模板（历史车牌 demo 用的流程），
> 只作参考；手势链路不读取旧车牌的权重/图片/标注。

---

## 为什么需要它

板子上改一次要 4 分钟综合 + 烧写，看不清中间状态。PC 上可以秒级迭代。
但 PC 上跑 PyTorch **不能代表板子**——所以这里有一个位精确模拟器 `hw_emulate.py`：

> 它用的整数运算、移位量化、逐格 argmax 与 RTL **完全一致**。
> 已经验证：11 层全部与导出器生成的参考输出 **逐位相同**。

所以 PC 上看到的框 = 板上会看到的框。

---

## 分工：Windows 采集，WSL 训练

| 环节 | 跑在哪 | 依赖 |
|---|---|---|
| `capture.py` 采集标注 | **Windows** | opencv（已装）、摄像头 |
| `train.py` 训练 | WSL | torch |
| `hw_emulate.py` 位精确推理 | WSL | numpy + scipy |
| `preview.py` 标注预览 | WSL | opencv-headless |

（WSL 里没有 `/dev/video`，所以采集必须在 Windows 侧。）

---

## 工作流

```powershell
# 1) 采集：点一下物体中心，选类别，空格保存
python pcvision/capture.py --classes 4
#    0-9 选类别   Space 保存   c 清除中心   q 退出
#    存到 pcvision/data/raw/  + labels.csv
```

```bash
# 2) 训练（WSL）
cd /mnt/e/qs/ScreenSense/pcvision
python3 train.py --data data/raw --classes 4 --epochs 40 --out ../build/model.pt

# 3) 导出量化 .mat
cd ../ml
python3 export_mat.py --ckpt ../build/model.pt --out ../build/mats --classes 4

# 4) 位精确预览（输出标注图）
cd ../pcvision
python3 preview.py --mat ../build/mats --frames data/raw --out ../build/preview
```

满意后，再用 `ml/pack_model.py` 打包、`cam/run_build_cam.ps1` 上板。

---

## 类别约定

**class 0 = 背景**。负样本（画面里没有目标）也标 0，每个格子都标背景。
所以你实际要检测的类别是 1..K-1。

---

## 域差异：PC 摄像头 ≠ OV5640

| 差异 | 影响 | 缓解 |
|---|---|---|
| 分辨率 640×480 vs 1280×720 | 目标像素尺寸不同 | 采集时 letterbox 到 1280×720（`capture.py` 已做） |
| 曝光/白平衡自动 | 颜色分布漂移 | 采集时锁定摄像头曝光；训练加颜色增广 |
| 镜头视场不同 | 同一物体在画面中占比不同 | 采集时覆盖远近；训练加缩放/裁剪增广 |
| 噪声与压缩 | 高频纹理不同 | 训练加噪声/模糊 |

**这些能缓解但不能消除。** 上板后建议再采 100–200 帧做一次域适配微调。

---

## 实测

用 4 张合成帧跑通全链路（2.6 秒）：

```
synthetic dataset ready
epoch   0  loss 0.7064  cell-acc 0.000
saved /tmp/m3.pt
4 frames
  s0.png -> class 2 (79,44) conf 35
```

（模型未训练，输出是随机的，只证明链路通。）

位精确验证：

```
node_conv2d ... node_conv2d_10   bit-exact=True
ALL MATCH
```

---

## 脚本

| 文件 | 作用 |
|---|---|
| `capture.py` | 摄像头 + 点击标注 + space 存样 |
| `train.py` | 读 labels.csv，训练 MundusDet |
| `hw_emulate.py` | 位精确整数推理（与 RTL 同算法） |
| `preview.py` | 在位精确结果上画框，输出标注图 |
| `smoke_test.sh` | 合成数据端到端自检 |
