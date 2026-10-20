#!/usr/bin/env bash
# 把 ops/ 里的运维脚本与 systemd 单元装到系统上。
# 换机器 / 重装系统之后跑一次即可。需要 sudo（写 /etc/systemd/system）。
#
# 不会删除任何现有文件；已存在的目标会被覆盖前先备份成 .bak-<时间戳>。

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
START_DIR="/home/rsp/dji/psdk/start"
UNIT_DST="/etc/systemd/system/psdk.service"

if [ "$(id -u)" -ne 0 ]; then
    echo "需要 root。用法：sudo $0" >&2
    exit 1
fi

stamp="$(date +%Y%m%d-%H%M%S)"

backup() {
    [ -e "$1" ] || return 0
    cp -p "$1" "$1.bak-$stamp"
    echo "备份  $1  →  $1.bak-$stamp"
}

echo "== 1. 运维脚本 → $START_DIR =="
install -d -o rsp -g rsp "$START_DIR"
for f in psdk-run.sh psdk-stop.sh; do
    backup "$START_DIR/$f"
    install -o rsp -g rsp -m 755 "$REPO/ops/$f" "$START_DIR/$f"
    echo "安装  $START_DIR/$f"
done

if [ -f "$REPO/ops/soffn_watch.py" ]; then
    backup /home/rsp/soffn_watch.py
    install -o rsp -g rsp -m 755 "$REPO/ops/soffn_watch.py" /home/rsp/soffn_watch.py
    echo "安装  /home/rsp/soffn_watch.py"
fi

echo
echo "== 2. systemd 单元 → $UNIT_DST =="
backup "$UNIT_DST"
install -m 644 "$REPO/ops/systemd/psdk.service" "$UNIT_DST"
echo "安装  $UNIT_DST"

echo
echo "== 3. 启用并启动 =="
systemctl daemon-reload
systemctl enable psdk.service
systemctl restart psdk.service
sleep 3
systemctl --no-pager --lines=0 status psdk.service || true

echo
echo "完成。常用操作："
echo "    screen -r psdk                        # 看实时输出（须以 rsp 身份）"
echo "    sudo systemctl stop psdk              # 停"
echo "    PSDK_FILE_LOG_LEVEL=DEBUG             # 需要抓链路细节时抬高日志级别"
