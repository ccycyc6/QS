# 手势训练全链路（PC → 上板）

本文件描述在本机 Ubuntu 上，用本机摄像头采集手势、训练、量化、位精确验证，
最后再在 Windows 上打包上板的完整流程。

核心原则：**先在本机把算法和量化跑对，再上板**。`pcvision/hw_emulate.py`
按 RTL 的整数语义实现（算术右移 + 舍入 + 饱和/ReLU + 全帧 argmax），
所以 PC 上看到的量化结果与板端一致；它仍建议在上板后用真实画面复核一次。

---

## 1. 两条边界，先看清楚

| 能力 | 跑在哪 | 说明 |
|---|---|---|
| **静态手势分类**（拳头 / 张掌 / 指 / 剪刀手 …） | **PC 训练 → FPGA 推理** | 硬件是单帧 80×45 逐格分类，天然支持 |
| **手势动作**（按住、左划、右划 …） | **PC 后处理**（`actions.py`） | 需要多帧历史；今天是 PC 策略层，以后可搬进 RV 核 |
| 连续动作分割 / 时序网络 | 不在本期 | 现有 RTL 没有时序单元 |

类别约定：**class 0 = 背景/无手势**，手势从 1 开始，最多 **15 个手势**
（头部层固定 16 通道，`pack_model.py` 会自动补齐到 16）。

---

## 2. 环境隔离（重要）

训练环境**完全隔离**在仓库之外的一个工作区，不污染系统 Python、不写 `~/.cache`：

    /home/ccy/Documents/qs/gesture-env/      # 默认 $QS_GESTURE_HOME
    ├── env/            Python venv（torch cu124 + opencv …）
    ├── cache/          pip / torch / xdg 缓存（全部重定向到这里）
    ├── data/           classes.json、raw/ 图片与 labels.csv
    ├── runs/           checkpoint、训练日志
    ├── out/            .mat、eval.json、打包文件、冒烟测试
    ├── MANIFEST.md     自动生成的“装了哪些东西 + 各占多大”
    └── install_manifest.tsv

可用 `QS_GESTURE_HOME=/path/to/ws` 换位置。**仓库只保留脚本，不存图片和权重。**

> 工作区要放在 **ext4 本地盘**（默认就是）。不要放到 NTFS / `/mnt/e`
> 或 WSL 挂载上：venv 的权限位和文件锁会出问题，速度也差很多。

### 首次安装

```bash
cd /home/ccy/Documents/qs/QS
bash pcvision/gesture/setup_env.sh          # CUDA 版（本机 RTX 4060）
bash pcvision/gesture/doctor.sh             # 包 / CUDA / 摄像头 / 显示 自检
```

没有 NVIDIA 显卡时用 `--cpu`。安装脚本会把重定向的缓存目录、venv、
pip 包清单都记进工作区清单。

### 查看清单 / 清理

```bash
bash pcvision/gesture/manifest.sh           # 刷新 MANIFEST.md（含体积与包清单）
bash pcvision/gesture/cleanup.sh            # 只预览，不删除
bash pcvision/gesture/cleanup.sh --yes      # 删除整个工作区
bash pcvision/gesture/cleanup.sh --yes --keep-data   # 只删环境，保留数据
```

清理脚本只动 `$QS_GESTURE_HOME`，并拒绝删除仓库内路径。系统层面**没有**
安装任何 apt 包；如果以后装了（如 `v4l-utils`），手册里会补记。

---

## 3. 采集数据集

### 3.1 想清楚要几个手势

先改类别名（默认 6 个：fist / open_palm / point / victory / thumbs_up / ok）：

```bash
bash pcvision/gesture/record.sh --names fist,open_palm,point,victory
```

第一次运行会把类别写进 `data/classes.json`；之后不要再改，否则标签对不上。

### 3.2 引导式录制（推荐）

```bash
bash pcvision/gesture/record.sh
```

流程：每个类别按一次 **Space** → 3 秒倒计时 → 自动录 `--seconds` 秒
（默认 8 秒 × 5 帧/秒 = 40 张）→ 自动进入下一类。最后会自动录一类
**背景（无手势）**。窗口里绿框是建议手部区域，十字是标签中心。

录制要点：
- 手放在绿框内，**距离 0.3–0.6 m**，让手掌约占画面 1/5；
- 每类录 4–8 轮（40 张/轮），换一点角度、距离、背景，**总样本 150–300 张/类**；
- 背景类建议分 2 轮录（空画面 + 有手但不做手势），合计 80 张以上；
- 每轮录制是一个独立 `session`；**验证集按 session 切分**，避免同一段视频
  泄漏进验证集；
- 保持光照稳定，避免逆光和强背光。

采集工具选项：

| 选项 | 作用 |
|---|---|
| `--manual` | 自由模式：1–9 选类、Space 保存、0 背景、b 连拍、u 撤销 |
| `--camera N` | 换摄像头 |
| `--seconds 10 --save-fps 4` | 引导式录制的时长/帧率 |
| `--names a,b,c` | 覆盖类别名（仅首次） |
| `--roi 440` | 绿框大小 |
| `--tracker mediapipe` | 可选：自动跟踪手心（需另装 mediapipe） |

> 不装 mediapipe 时标签中心=画面中心/点击位置；训练用高斯软标签
> （σ=2 格，约 32 px）并对平移做增强，所以手小幅漂移不会毁掉标签。
>
> 想让标签自动跟手，可另装（会带 opencv-contrib，装完重跑 `doctor.sh`）：
>
> ```bash
> $QS_GESTURE_HOME/env/bin/pip install "mediapipe==0.10.35"
> ```
>
> 然后 `record.sh --tracker mediapipe`；检测不到手的帧会自动跳过。

先确认摄像头通路（不录手势、不弹窗，只存 3 张背景图）：

```bash
$QS_GESTURE_HOME/env/bin/python pcvision/gesture/capture_gestures.py --selftest 3 \
    --out $QS_GESTURE_HOME/out/selftest
# 看 out/selftest/selftest/*.jpg 正常后删掉：
rm -rf $QS_GESTURE_HOME/out/selftest
```

### 3.3 数据长什么样

`data/raw/labels.csv`：

    file,cls,x,y,session
    g_s20261112_190000_..._c1.jpg,1,642,355,s20261112_190000
    g_s20261112_190000_..._c0.jpg,0,-1,-1,s20261112_190000

图片是 **1280×720** 的 letterbox 结果，和板子输入几何一致；jpg 质量 95。

---

## 4. 训练

```bash
bash pcvision/gesture/run_pipeline.sh train
# 或自定义：
bash pcvision/gesture/run_pipeline.sh train --epochs 80 --batch 4 --lr 3e-4
```

- 网络：`ml/model_template.py` 的 **MundusDet**（conv/ReLU/maxpool，无 BN，
  无残差，无上采样），输出 80×45×K；
- 损失：逐格 focal loss（CenterNet 式）+ **整帧交叉熵**。整帧项直接优化
  “全帧 argmax 的类别”，因为板子就是这么判决的；
- 增广：旋转 ±8°、缩放 0.9–1.1、平移 ±36 px、亮度/对比度/HSV/模糊/噪声/JPEG；
  默认**不做水平翻转**（左右手含义会变，确需可加 `--hflip 0.1`）；
- 归一化：训练用 `(x-128)/128`；导出与 RTL 用 `x-128`。两者相差一个
  正标量，逐层量化缩放由 `shift_k` 吸收；偏置与舍入会带来少量偏差，
  **准确率以第 5 节的位精确评估为准，不要只看 float**；
- 自动按 session 切 20% 验证集，保存验证集整帧准确率最好的 checkpoint；
- 早停 patience 20；产物：`runs/gesture.pt`、`runs/gesture.json`、
  `runs/gesture.csv`、`runs/gesture_last.pt`。

看日志里的 `frame-acc`：整帧类别判对的比例。**先到 90%+ 再谈上板**。

---

## 5. 量化 + 位精确评估（这一步不能跳）

```bash
bash pcvision/gesture/run_pipeline.sh export   # 用真实帧做量化校准
bash pcvision/gesture/run_pipeline.sh eval     # float + 位精确对比
```

- `export` 会用 `data/raw` 里按类别均衡抽样 8 张做校准，逐层选幂次移位
  `shift_k`，并打印每层峰值与裁剪比例；
- `eval` 同时报告 **PyTorch float** 和 **hw_emulate 整数** 的准确率、
  每类召回、负样本误报率、混淆矩阵；
- 两者差距大 = 量化不可接受，先回到训练（加数据/调 `--sigma`），不要上板。

### 置信度阈值（必须一起看）

背景帧偶尔会被判成手势，但通常分数很低。`eval` 会自动找“最强负样本”
和“最弱真手势”之间的分界，报告**带阈值**的准确率：

    == bit-exact ... threshold 53.5 (clean gap) ==
    samples 32  frame-accuracy 100.00%

- `clean gap` = 负样本分数全部低于真手势，阈值能完全分开；
- 没有干净分界时会给 best-effort 阈值，并降低整体准确率；
- 阈值写进 `out/eval.json` 的 `threshold` 字段；`live_demo.py` 会自动读取
  float 阈值；板端对应 `frame_argmax` 的 `CONF_THRESH`（或 RV/PC 后处理）。
- 强制指定：`bash pcvision/gesture/run_pipeline.sh eval --thresh 50`。

结果：`out/eval.json`、`out/eval.csv`（逐帧 float/int 对照）。

单独校验每层 .mat 里存的 input/output 参考对与模拟器逐位一致
（这是导出器 ↔ 模拟器的自洽性检查，不是跑 RTL 仿真）：

```bash
$QS_GESTURE_HOME/env/bin/python pcvision/hw_emulate.py \
    --mat $QS_GESTURE_HOME/out/mats --verify
# 期望最后一行：ALL MATCH
```

---

## 6. 实时演示（可选）

```bash
$QS_GESTURE_HOME/env/bin/python pcvision/gesture/live_demo.py \
    --ckpt $QS_GESTURE_HOME/runs/gesture.pt
```

- 实时显示类别、置信度、命中的格子与框；
- `actions.py` 把逐帧结果变成 **hold / swipe_left / swipe_right / swipe_up /
  swipe_down** 事件；按 `s` 存截图，`p` 暂停，`r` 清状态，`q` 退出；
- `--events out/events.jsonl` 落盘事件；
- `--threshold T` 可提高“报告手势”的门槛（板子端对应 frame_argmax 的阈值）。

动作层参数在 `pcvision/gesture/actions.py` 的 `ActionConfig`：投票窗口 7 帧、
锁定 5 票、按住 0.8 s、滑动 6 格（96 px）/0.35 s、冷却 0.7 s。单元测试：

```bash
$QS_GESTURE_HOME/env/bin/python pcvision/gesture/test_actions.py
```

---

## 7. 上板（Windows，训练满意之后再做）

### 7.1 在 PC 上打包

```bash
bash pcvision/gesture/run_pipeline.sh pack
```

产物在 `$QS_GESTURE_HOME/out/hw/`：

    header/    layer*.vh（结构参数）
    mem_data/  weight_*.mem、bias_*.mem（权重/偏置）
    conv_data_hex_pds/  仿真激励 hex

K 类会自动补齐到 16 通道，多余通道偏置 −2²⁰，永远赢不了 argmax。

### 7.2 在 Windows 侧覆盖并综合

把 `out/hw/header/*` 和 `out/hw/mem_data/*` 拷到 Windows 仓库对应目录，
覆盖车牌权重（这正是“换模型”）。先备份，再覆盖：

```powershell
# 在 Windows 仓库根目录（先备份旧权重）
robocopy fpga\rtl_pds\data_process\header fpga\rtl_pds\data_process\header_backup /E
robocopy fpga\rtl_pds\data_process\mem_data fpga\rtl_pds\data_process\mem_data_backup /E
# 覆盖（源目录改成你从 PC 拷过来的 out\hw）
robocopy Z:\gesture-env\out\hw\header  fpga\rtl_pds\data_process\header  /E
robocopy Z:\gesture-env\out\hw\mem_data fpga\rtl_pds\data_process\mem_data /E
```

如果还要跑 RTL 仿真，把 `out/hw/conv_data_hex_pds` 一并拷到
`fpga/rtl_pds/conv_data_hex_pds`。

然后按原流程综合、烧写：

```powershell
powershell -File tools/make_build_tcl.ps1
D:/Pango/PDS_2025.2-SP3-EN-ads/bin/pds_shell.exe -file ../../tools/build_full.tcl
powershell -File tools/program.ps1 -Bitstream bitstreams/<xxx>.sbit
```

### 7.3 上板后必须做域适配

PC 摄像头 ≠ 板子 HDMI 输入（曝光、白平衡、镜头、噪声都不同）。
上板后录 100–200 帧板子输入画面，加入数据集做一次**微调**：

```bash
bash pcvision/gesture/run_pipeline.sh train --data $QS_GESTURE_HOME/data/board --epochs 20
```

（把板子采集帧和 labels.csv 放到 `data/board`；类别顺序必须与
`classes.json` 一致。）

### 7.4 板端行为

- 每帧输出全帧最强格：`{class, cell, conf}`；
- 框固定 64×40，画在格中心；
- class 0 或 conf 低于阈值时视为“无手势”；
- 动作（hold/swipe）目前由 PC 侧 `actions.py` 产生，若要板上闭环，需把
  同一状态机写进 RV 调度器固件（接口就是逐帧 class/cell/conf）。

---

## 8. 冒烟测试（不碰真实数据）

```bash
bash pcvision/gesture/run_pipeline.sh smoke
```

自动生成合成数据 → 训练 4 epoch → 量化校准 → 逐位校验 → float/int 评估
→ 打包 → 动作层单测。全程在 `out/smoke`，不会污染 `data/raw`。

> 4 epoch 只验证“链路通”，准确率数字没有意义（合成任务 20 epoch 可到 100%）。
> 冒烟通过后，用真实数据重新训练。

---

## 9. 排错

| 现象 | 先查 |
|---|---|
| 打不开摄像头 | 是否被浏览器/会议软件占用；`ls -l /dev/video*`；`doctor.sh` |
| 画面全黑 / 绿 | 换 `--camera 1`；确认不是 IR 摄像头；`--width/--height` 换原生分辨率 |
| 训练 loss 不降 | 类别是否只录了背景；`labels.csv` 的 cls 是否 1..K-1；学习率降到 1e-4 |
| 验证准确率高、实拍差 | 数据太少/太单一；补录不同背景、距离、光照；检查 session 切分 |
| float 好、位精确差 | `export` 的 `clip%` 是否过高；增加校准帧；回训练降低激活范围 |
| 所有帧都判背景 | 背景类样本占比过高；确认正样本有手；调大 `--frame-loss` 或补正样本 |
| 上板无框/全错 | 先跑 `hw_emulate --verify`；确认输入真是 720p60；再查域差异 |
| 训练很慢 | 确认 `doctor.sh` 里 CUDA available=True；`--workers 4`；batch 提到 8 |

---

## 10. 文件一览

    pcvision/gesture/
    ├── env.sh               环境变量（工作区、缓存重定向）
    ├── setup_env.sh         建 venv、装 torch/opencv
    ├── doctor.sh            环境 + 摄像头自检
    ├── manifest.sh          生成安装清单
    ├── cleanup.sh           一键清理工作区
    ├── record.sh            引导式/自由式采集入口
    ├── capture_gestures.py  摄像头 + 标签 + 保存
    ├── common.py            几何/标签/指标等共享代码
    ├── dataset.py           Dataset + 增广
    ├── train_gestures.py    训练（focal + 整帧 CE）
    ├── evaluate.py          float / 位精确评估
    ├── live_demo.py         实时演示 + 动作事件
    ├── actions.py           时序动作层（hold/swipe）
    ├── test_actions.py      动作层单测
    ├── smoke_test.py        合成数据全链路冒烟
    └── run_pipeline.sh      train / export / eval / pack / all
