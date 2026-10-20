# m3e-psdk-payload

树莓派（CUBE）作为**载荷计算机**，通过 E-Port 接 **DJI Mavic 3 Enterprise**，基于 **DJI Payload SDK** 的定制飞控程序。

应用名 `UwbPosition`，MountPosition = Extension Port。

---

## 这个仓库装什么 / 不装什么

**装**：属于我们自己的代码与配置 —— 对 PSDK 样例的定制改动、运维脚本、排查文档。

**不装**：**DJI Payload SDK 源码**。

DJI SDK 每个源文件头部都写明 *"未经 DJI 书面同意，禁止传播"*，把它推上 GitHub（即便私有仓）也属于分发。所以本仓只保存**覆盖层**：文件按 SDK 的原始相对路径镜像存放，配合 `scripts/` 下的同步脚本工作。

**不装**（同样重要）：**开发者凭据**。见下面"凭据"一节。

### 外部依赖

| 项 | 版本 / 位置 |
|---|---|
| DJI Payload SDK | `3.15.0-beta.0-build.2318` |
| SDK 本地路径 | `/home/rsp/dji/psdk/Payload-SDK-3.15.0`（`current` 软链指向它） |
| 硬件 | 树莓派（Debian 11 / arm64）+ CH340 USB-TTL + DJI M3E E-Port |
| 串口 | `/dev/ttyUSB0` @ **921600**（M3E/M3T 只支持这个波特率） |

---

## 目录结构

```
sdk-overlay/          # 按 SDK 原始相对路径镜像的自有改动，可一键覆盖回 SDK 树
  samples/sample_c/...        #   核心飞控逻辑（C 版，也被 C++ 版编入）
  samples/sample_c++/...      #   C++ 版配置与入口
ops/                  # 运维与诊断
  systemd/psdk.service        #   开机自启动单元（装在 /etc/systemd/system/）
  psdk-run.sh / psdk-stop.sh  #   看门狗与清理脚本
  soffn_watch.py              #   USB 链路 SOF 诊断脚本
scripts/
  sync-from-sdk.sh            #   SDK 树 → 仓库（改完代码跑这个）
  apply-to-sdk.sh             #   仓库 → SDK 树（换机器/重装时跑）
  install-ops.sh              #   安装 systemd 服务与运维脚本
docs/                 # 排查记录与日报
.githooks/pre-commit  # 拦截凭据泄露
```

> `sdk-overlay/samples/sample_c/module_sample/flight_control/test_flight_control.c` 是**最重要**的文件 —— 飞控逻辑都在这里，且 `sample_c++/.../CMakeLists.txt` 会把 `sample_c/module_sample/*.c` 一并编进 `dji_sdk_demo_on_rpi_cxx`，所以**两个二进制共用它**。

---

## 日常工作流

**改动仍然在 SDK 树里做**（跟以前完全一样，因为编译就在那儿），改完把改动拉回仓库：

```bash
# 1. 在 SDK 树里改代码
cd /home/rsp/dji/psdk/Payload-SDK-3.15.0
vim samples/sample_c/module_sample/flight_control/test_flight_control.c

# 2. 编译验证
cd build && make dji_sdk_demo_on_rpi_cxx

# 3. 把改动同步回本仓库
cd /home/rsp/dji/psdk/m3e-psdk-payload
./scripts/sync-from-sdk.sh

# 4. 看 diff、提交、推送
git diff
git commit -m "FIX: 修正降落确认逻辑

DETAILS: ...
JIRA:
TEST: 模拟器实测通过"
git push
```

提交信息沿用 `~/Settings/.git_commit_template` 的格式（`FIX:` / `DETAILS:` / `JIRA:` / `TEST:`）。

### 这台仓库替代了什么

以前靠 `backups/` 下手工拷贝快照做"版本管理"：

```
direction-demo-20260712-103423/
flight-status-before-20260720-233315/
flight-safety-before-20260721-151847/
```

那种方式没有 diff、无法回到任意时间点、也看不出两次快照之间改了什么。那些快照**保留在原处不动**，详见 [`docs/legacy-backups.md`](docs/legacy-backups.md)。

回滚现在就是普通的 git 操作：
```bash
git log --oneline -- sdk-overlay/samples/.../test_flight_control.c
git checkout <sha> -- sdk-overlay/samples/.../test_flight_control.c
./scripts/apply-to-sdk.sh
```

---

## 凭据（重要）

`dji_sdk_app_info.h` 里有 **`USER_APP_KEY`**、**`USER_APP_LICENSE`** 和开发者邮箱。这些是真实凭据，**不进仓库**。

- 仓库里只有 `dji_sdk_app_info.h.template`，值是 `YOUR_APP_KEY` / `YOUR_APP_LICENSE` / `YOUR_DEVELOPER_ACCOUNT` 占位符
- 真实文件留在 SDK 树里，`sync-from-sdk.sh` 会**主动跳过**它
- `.githooks/pre-commit` 会在提交时扫描，一旦发现真实值就**拒绝提交**

三处防护，任何一条生效都能挡住。**如果你发现凭据进了 git 历史，立即去 DJI 开发者后台重置 App Key**，并告诉我清理历史。

---

## 新机器 / 重装后恢复

```bash
# 1. 拿到同版本 SDK
#    (DJI 开发者后台下载 Payload-SDK 3.15.0-beta.0-build.2318)
#    解压到 /home/rsp/dji/psdk/Payload-SDK-3.15.0

# 2. 克隆本仓库
git clone git@github-lemonade:lemonade052/m3e-psdk-payload.git /home/rsp/dji/psdk/m3e-psdk-payload

# 3. 把覆盖层写回 SDK 树
cd /home/rsp/dji/psdk/m3e-psdk-payload
./scripts/apply-to-sdk.sh

# 4. 填凭据（脚本会提示，不会覆盖已有文件）
vim /home/rsp/dji/psdk/Payload-SDK-3.15.0/samples/sample_c/.../dji_sdk_app_info.h

# 5. 编译
cd /home/rsp/dji/psdk/Payload-SDK-3.15.0/build && make

# 6. 装运维脚本与自启动
sudo ./scripts/install-ops.sh
```

---

## 相关文档

- [`docs/2026-09-15-日报.md`](docs/2026-09-15-日报.md) —— 飞控样例验证、降落死锁根因、PSDK 自启动修复
- [`docs/2026-09-14-USB链路排查.md`](docs/2026-09-14-USB链路排查.md) —— DUML 协议解析与 USB Bulk 链路诊断
- [`docs/legacy-backups.md`](docs/legacy-backups.md) —— 手工快照的历史说明
