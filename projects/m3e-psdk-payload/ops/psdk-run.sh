#!/bin/bash
#
# PSDK 采样程序看门狗。
#
# 由 systemd 单元 psdk.service 以用户 rsp 拉起，前台常驻。职责：
#   1. 等 CH340 串口 /dev/ttyUSB0 就绪
#   2. 在一个 detached 的 screen 会话里跑 dji_sdk_demo_on_rpi_cxx
#   3. 程序退出就重新拉起（对应 DJI 原版 psdk-alive.sh 的语义）
#
# 为什么用 screen：demo 的顶层菜单是 std::cin >> inputChar 阻塞读。
# 如果用 /dev/null 当 stdin，读会立刻 EOF 失败并 2 秒一轮无限刷菜单；
# 用 pty（screen 会话）则阻塞等待，既不刷屏也没有被误喂指令的风险。
# 需要交互时 screen -r psdk 挂上去即可。
#
set -u

BIN_DIR="/home/rsp/dji/psdk/current/build/bin"
EXE="./dji_sdk_demo_on_rpi_cxx"
SESSION="psdk"
UART="/dev/ttyUSB0"
LOG_KEEP=10                 # Logs/ 里最多保留多少个 DJI_*.log

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

# demo 初始化失败走的是 throw std::runtime_error -> abort，关掉 coredump 免得刷满磁盘
ulimit -c 0

# screen 会话是否存在
alive() { screen -S "$SESSION" -Q select . >/dev/null 2>&1; }

# --- 1. 等串口 ----------------------------------------------------------
# 不能靠 systemd 的 After=dev-ttyUSB0.device：CH340 没插时那个 job 会一直挂着，
# 拖死整个 multi-user.target。这里自己等，最多 60 秒。
for _ in $(seq 1 60); do
    [ -c "$UART" ] && break
    sleep 1
done
if [ ! -c "$UART" ]; then
    log "ERROR: $UART 60 秒内没出现，退出（systemd 会按 Restart 策略重试）"
    exit 1
fi
log "$UART 就绪"

# --- 2. 工作目录必须是 build/bin ----------------------------------------
# Logs/ 在代码里是相对路径（application.cpp:52 DJI_LOG_PATH "Logs/DJI"），
# cwd 错了就会在别处建 Logs 或者直接报 file system init error。
cd "$BIN_DIR" || { log "ERROR: 进不去 $BIN_DIR"; exit 1; }

# --- 3. 清理上一轮残留 --------------------------------------------------
screen -wipe >/dev/null 2>&1
if alive; then
    log "发现残留的 screen 会话 '$SESSION'，先杀掉"
    screen -S "$SESSION" -X quit >/dev/null 2>&1
    sleep 2
fi

# 只保留最近 LOG_KEEP 个日志（旧的 rc.local 是 sudo rm -rf Logs，会把属主搞坏）
# shellcheck disable=SC2012
ls -1t Logs/DJI_*.log 2>/dev/null | tail -n "+$((LOG_KEEP + 1))" | while read -r f; do
    rm -f -- "$f"
done

# --- 4. 看门狗主循环 ----------------------------------------------------
fails=0
while true; do
    start=$(date +%s)

    # -c /dev/null：忽略用户 screenrc，避免里面一句 zombie 让会话在程序死后残留、
    #              导致下面的存活判断永远为真而不再拉起。
    screen -c /dev/null -dmS "$SESSION" -t psdk bash -c "cd '$BIN_DIR' && exec $EXE"
    sleep 3                                     # 等 screen 把会话登记上，避免误判
    if ! alive; then
        log "WARN: screen 会话没起来"
    else
        log "已拉起 screen 会话 '$SESSION'（screen -r $SESSION 可挂上去交互）"
    fi

    # 阻塞到会话结束
    while alive; do
        sleep 5
    done

    ran=$(( $(date +%s) - start ))
    if [ "$ran" -lt 60 ]; then
        fails=$((fails + 1))
    else
        fails=0
    fi
    delay=$(( fails * 10 ))
    [ "$delay" -gt 300 ] && delay=300

    log "demo 退出（存活 ${ran}s，连续短命 $fails 次），${delay}s 后重启"
    sleep "$delay"
done
