# pcvision/gesture — 手势全链路

从本机摄像头到 FPGA 位流的一站式手势训练工具。完整说明见
[docs/GESTURE.md](../../docs/GESTURE.md)。

## 最短路径

```bash
bash setup_env.sh                 # 一次性：隔离 venv（仓库外）
bash doctor.sh                    # CUDA / 摄像头 / 显示自检
bash app.sh                       # 网页工作台 http://127.0.0.1:8765
bash record.sh --rounds 4         # 引导式采集 4 轮（每类按一次空格）
bash run_pipeline.sh all          # 训练 -> 量化 -> 位精确评估 -> 打包
bash monitor.sh                   # 实时监测（q 退出）
bash manifest.sh                  # 看装了什么、占多大
bash cleanup.sh                   # 预览清理；--yes 真删
```

## 目录内容

| 文件 | 作用 |
|---|---|
| `app.sh` / `webapp.py` | 网页工作台（采集/训练/评估/监测） |
| `env.sh` | 工作区与缓存重定向（pip/torch/xdg 都进工作区） |
| `setup_env.sh` | 建 venv、装 torch（默认 cu124）+ opencv 等 |
| `doctor.sh` | 包 / CUDA / 摄像头 / DISPLAY 自检 |
| `record.sh` / `capture_gestures.py` | 采集与标注（引导式或手动） |
| `common.py` | 几何、标签、目标、指标 |
| `dataset.py` | Dataset 与增广（几何 + 光度） |
| `train_gestures.py` | 逐格 focal + 整帧 CE |
| `evaluate.py` | float / 位精确双评估 |
| `live_demo.py` | 实时摄像头监测与动作事件 |
| `monitor.sh` | 实时监测入口（默认读 `runs/gesture.pt`） |
| `actions.py` / `test_actions.py` | hold/swipe 时序动作层与单测 |
| `smoke_test.py` | 合成数据全链路自检 |
| `run_pipeline.sh` | train / export / eval / pack / all / smoke / status |
| `manifest.sh` / `cleanup.sh` | 安装清单与清理 |

## 环境位置

默认 `$QS_GESTURE_HOME = <repo>/../gesture-env`。所有体积都在这里，
删除它是安全的；仓库本身只有脚本。
