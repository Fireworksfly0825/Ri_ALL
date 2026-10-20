# 历史手工快照（backups/）

在有了本仓库之前，改动是靠**改前手工拷一份**来留痕迹的。这些快照**保留在原处不动**，仅在此登记它们的位置与含义，以免日后有人看到一个叫 `backups/` 的目录不敢动。

它们的功能从今天起由 git 历史取代 —— 有 diff、能回到任意时间点、能看出两次之间改了什么，这些是快照做不到的。

---

## `/home/rsp/dji/psdk/backups/`

三份，共 7 个文件，约 380 KB。目录内部结构是 SDK 相对路径的**截断版**（只保留 `application/`、`flight_control/` 级），不是完整镜像。

| 快照 | 时间 | 内容 | 对应的开发阶段 |
|---|---|---|---|
| `direction-demo-20260712-103423/` | 2026-07-12 10:34 | `application/main.c` (32060 B)<br>`module_sample/flight_control/test_flight_control.c` (89273 B)<br>`module_sample/flight_control/test_flight_control.h` (3101 B) | 「方向演示」功能开始前的基线 |
| `flight-status-before-20260720-233315/` | 2026-07-20 23:33 | `application/main.c` (33389 B)<br>`flight_control/test_flight_control.c` (107257 B)<br>`flight_control/test_flight_control.h` (3165 B) | 「飞行状态上报」功能开始前的基线 |
| `flight-safety-before-20260721-151847/` | 2026-07-21 15:18 | `flight_control/test_flight_control.c` (118187 B) | 「飞行安全」改动开始前的基线；**只有 C 文件**，那次没动 main.c |

> 目录名里的时间戳是**备份动作**发生的时间；表格里的时间是文件自身的 mtime（`cp -p` 保留下来的原始修改时间），两者不一致是正常的。

按大小可以读出演进线索：`test_flight_control.c` 从 89 KB → 107 KB → 118 KB，现在 SDK 树里是约 120 KB。

---

## SDK 树里的两个 `.bak`

```
samples/sample_c/platform/linux/raspberry_pi/application/dji_sdk_config.h.bak-before-onlybulk-20260709-225541
samples/sample_c++/platform/linux/raspberry_pi/application/dji_sdk_config.h.bak-before-onlybulk-20260709-225541
```

2026-07-09 改「只用 USB Bulk、不走 UART 数据面」（onlybulk）之前的原始 `dji_sdk_config.h`。

此后该文件的**改动后版本**已经在本仓库里（`sdk-overlay/.../dji_sdk_config.h`），改动前的版本在这两个 `.bak` 里。也就是说这一处的前后对照，恰好是「仓库里是改后、`.bak` 是改前」。

---

## 要不要清理

**不用。** 合起来不到 400 KB，留着作为交叉验证的旁证有价值 —— 比如某天怀疑 git 历史里某个版本不对，可以拿快照来对。

真的想清理时，先在 SDK 树里确认这些路径确实已经被仓库覆盖，再删：

```bash
cd /home/rsp/dji/psdk/Payload-SDK-3.15.0
git -C /home/rsp/dji/psdk/m3e-psdk-payload log --oneline -- \
    sdk-overlay/samples/sample_c/module_sample/flight_control/test_flight_control.c
```

---

## 与本仓库的对应关系

仓库里 `sdk-overlay/` 下的文件是**当前** SDK 树的状态，等价于"最新的一份快照"。区别在于：

- 快照要人工判断该拷哪个目录、拷哪几个文件；仓库是完整清单（见 `scripts/sync-from-sdk.sh` 里的 `FILES`）
- 快照之间无法对比；`git diff <快照A的提交> <快照B的提交>` 可以
- 快照只有 3 个时间点；git 有每一次提交

历史快照**没有**导入 git 历史 —— 那会让早期历史变成一堆来源不明的大块新增，反而看不清真实演进。git 历史从 2026-09-15 建仓当天开始。
