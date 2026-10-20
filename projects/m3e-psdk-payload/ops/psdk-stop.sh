#!/bin/bash
#
# 停掉 psdk-run.sh 拉起的 screen 会话。
# 由 systemd 单元 psdk.service 的 ExecStop 调用。
# 主要作用是兜底：正常情况下 systemd 按 cgroup 收尸就够了，
# 但 detached 的 screen 会话如果被 reparent 出去就得靠这里点名杀。
#
set -u

SESSION="psdk"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

screen -S "$SESSION" -X quit >/dev/null 2>&1
screen -wipe >/dev/null 2>&1
log "已请求结束 screen 会话 '$SESSION'"

exit 0
