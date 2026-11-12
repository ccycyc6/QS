# 工作流：真机 Ubuntu 训练 / Windows 上板

同一台机器双系统，仓库放在 NTFS 分区（Windows 侧的 `E:\qs\ScreenSense`）。
两边用同一份文件，不需要拷贝。

| 系统 | 路径 | 用途 |
|---|---|---|
| **Ubuntu（真机）** | `/mnt/e/qs/ScreenSense` | 采集、训练、量化、位精确预览、打包 |
| **Windows** | `E:\qs\ScreenSense` | PDS 综合、JTAG 烧写 |

---

## 1. Ubuntu 侧挂载 NTFS

桌面环境下点一下磁盘图标就能在 `/media/<user>/...` 看到，但路径每次都变。
**建议固定挂到 `/mnt/e`**，脚本和文档都按这个路径写：

```bash
# 找分区号
lsblk -f | grep -i ntfs

# 固定挂载（ntfs3 是内核驱动，比 ntfs-3g 快很多）
sudo mkdir -p /mnt/e
sudo mount -t ntfs3 /dev/nvme0n1p3 /mnt/e        # 换成你的分区
```

如果要开机自动挂载，写进 `/etc/fstab`：

```
/dev/nvme0n1p3  /mnt/e  ntfs3  defaults,uid=1000,gid=1000,umask=022  0 0
```

> 用 `uid/gid/umask` 让普通用户可读写，否则 git 会报权限错误。

---

## 2. NTFS 上的 git 有两个坑

```bash
cd /mnt/e/qs/ScreenSense
git config --global --add safe.directory /mnt/e/qs/ScreenSense   # 否则报 dubious ownership
git config core.filemode false                                    # NTFS 不保留可执行位
```

不做第二条，`git status` 会把所有文件标成已修改。

---

## 3. 装环境

```bash
cd /mnt/e/qs/ScreenSense/pcvision
bash setup.sh            # CPU 版 torch
# 或：bash setup.sh --cuda  # 有 NVIDIA 显卡时用这个，训练快很多
source .venv/bin/activate
bash doctor.sh           # 逐项自检，最后打印 READY 或 NOT READY
```

`doctor.sh` 会检查：python 包、CUDA、摄像头 `/dev/video*`、是否在 `video` 组、图形会话、仓库可写。

摄像头没权限时：

```bash
sudo usermod -aG video $USER    # 然后注销重新登录
```

---

## 4. 跑全流程

```bash
cd /mnt/e/qs/ScreenSense/pcvision
source .venv/bin/activate

# 采集：0-9 选类别，点物体中心，空格保存，q 退出
python capture.py --classes 4

# 训练
python train.py --data data/raw --classes 4 --epochs 40 --out ../build/model.pt

# 位精确预览（就是板子会看到的结果）
cd ../ml
python export_mat.py --ckpt ../build/model.pt --out ../build/mats --classes 4
cd ../pcvision
python preview.py --mat ../build/mats --frames data/raw --out ../build/preview
```

效果满意后打包成硬件文件：

```bash
cd /mnt/e/qs/ScreenSense/ml
python pack_model.py --mat ../build/mats \
    --gen ../fpga/python_script/CnnHardwareGenerator_pds.py \
    --out-mem ../fpga/rtl_pds/data_process/mem_data \
    --out-vh  ../fpga/rtl_pds/data_process/header
```

---

## 5. 回 Windows 上板

重启进 Windows，文件已经在盘上，直接：

```powershell
cd E:\qs\ScreenSense
powershell -File cam\run_build_cam.ps1        # 约 4 分钟
Copy-Item cam\fpga\pango\prj_tasks\pnr_1\generate_bitstream\video_fb_top.sbit bitstreams\cam_custom.sbit
powershell -File tools\program.ps1 -Bitstream bitstreams\cam_custom.sbit
```

---

## 6. 交接清单

| 产物 | 位置 | 生成方 |
|---|---|---|
| 训练权重 | `build/model.pt` | Ubuntu |
| 量化 `.mat` | `build/mats/` | Ubuntu |
| 硬件头文件 | `fpga/rtl_pds/data_process/header/` | Ubuntu（pack_model） |
| 权重 mem | `fpga/rtl_pds/data_process/mem_data/` | Ubuntu（pack_model） |
| 位流 | `bitstreams/` | Windows |

---

## 7. 已知约束

- **采集必须在 Ubuntu 桌面会话里跑**（`capture.py` 需要窗口和 `/dev/video`）；
- Ubuntu 下 `data/raw/`、`build/`、`.venv/` 都在 `.gitignore` 里，不会污染仓库；
- 训练完不要忘了把 `build/mats` 打包进硬件目录，否则 Windows 侧综合用的还是旧权重；
- 两侧不要同时写同一个文件（双系统不会同时运行，正常不会遇到）。
