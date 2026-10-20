# Ri_ALL — 树莓派内容整合仓库

把树莓派上的两类内容统一放在一个仓库里：

## 目录结构

- **仓库根目录** — 家目录配置与环境备份
  - `Settings/` — XDG 配置、vim 配置、SSH 公钥与 config（不含私钥）
  - `.bashrc` / `.profile` / `.gitconfig` / `.vimrc` 等 dotfiles
  - `soffn_watch.py`、`work/`、`ws/`、`Desktop/` 中的脚本和文档
- **`projects/m3e-psdk-payload/`** — DJI PSDK 项目的快照（overlay 模式）
  - 原项目仓库：<https://github.com/Fireworksfly0825/m3e-psdk-payload>
  - 这里是副本，日常开发仍在 `~/dji/psdk/m3e-psdk-payload` 进行

## 不包含的内容

- SSH 私钥、`authorized_keys`、`.bash_history`、`.claude*` 数据
- Chromium / Pulse / dconf 登录态、Wi‑Fi 配置备份
- IDE 缓存（`.vscode-server`、`.cursor-server`）、`opencv/`、`dji/`（DJI SDK 源码，519 MB）、`Bookshelf/`

## 同步方式

家目录配置：

```bash
git -C /home/rsp add -A
git -C /home/rsp commit -m "更新说明"
git -C /home/rsp push
```

项目快照（从原项目仓库重新导出）：

```bash
/home/rsp/scripts/sync-project.sh
git -C /home/rsp add -A
git -C /home/rsp commit -m "同步 PSDK 项目快照"
git -C /home/rsp push
```
