#!/usr/bin/env python3
"""
soffn_watch.py —— 判断 Pi 的 USB-C 数据链路通不通（只读，不修改任何东西）

原理
    dwc2 每收到一帧 SOF 就把一个 14 位计数器 +1。USB 全速下主机每秒发 1000 帧。
        链路通   -> 计数器飞快上涨，约 1000 帧/秒
        链路不通 -> 计数器冻住不动（就是现在的状态：一直停在 1809）
    所以不用看 dmesg、不用理解协议，只盯这一个数字就够了。

用法
    sudo python3 ~/soffn_watch.py
    然后去轻推 / 重压 线A 两端的 USB-C 接头（Pi 上的、转接板上的），不要拔。
    屏幕上只要冒出 ★ 就说明有变化。Ctrl-C 结束，会打印判读结论。

这份脚本只是读 /sys/kernel/debug，不会改动任何配置。删掉它就是 rm ~/soffn_watch.py
"""

import re
import subprocess
import sys
import time

REG = "/sys/kernel/debug/usb/fe980000.usb/regdump"
SPD = {0: "high-speed", 1: "full-speed", 2: "low-speed"}
WINDOW = 1.0     # 速率统计窗口（秒）
INTERVAL = 0.1   # 采样间隔（秒）


def sample():
    try:
        txt = open(REG).read()
    except PermissionError:
        sys.exit("权限不足：请用  sudo python3 ~/soffn_watch.py  运行")
    except FileNotFoundError:
        sys.exit(f"读不到 {REG}（debugfs 没挂？）")
    d = int(re.search(r'DSTS = 0x([0-9a-f]+)', txt).group(1), 16)
    c = int(re.search(r'DCFG = 0x([0-9a-f]+)', txt).group(1), 16)
    return {"spd": (d >> 1) & 3, "sofn": (d >> 8) & 0x3FFF, "addr": (c >> 4) & 0x7F}


def reset_count():
    try:
        out = subprocess.run(["dmesg"], capture_output=True, text=True).stdout
        return out.count("new device is")
    except Exception:
        return -1


def main():
    t0 = time.time()
    prev = sample()
    frames = 0                      # 累计正向收到的 SOF 帧数
    win_start = t0
    frames_at_win_start = 0
    best_rate = 0.0
    best_rate_at = None
    saw_hs = prev["spd"] == 0
    saw_addr = prev["addr"] != 0
    resets_at_start = reset_count()
    last_spd = prev["spd"]
    back_steps = 0                  # 计数器被总线 reset 打回次数

    print("=" * 62)
    print(" 盯着 dwc2 的 SOF 计数器。链路通的话速率应接近 1000 帧/秒。")
    print(" 现在去轻推 / 重压 线A 两端的 USB-C 接头（别拔）。")
    print(" 看到 ★ 就是有变化。Ctrl-C 结束。")
    print("=" * 62)
    print(f"起始状态：速率={SPD[prev['spd']]}  SOFFN={prev['sofn']}  "
          f"设备地址={prev['addr']}  主机reset累计={resets_at_start}\n")

    try:
        while True:
            time.sleep(INTERVAL)
            s = sample()

            raw = (s["sofn"] - prev["sofn"]) % 16384
            if raw > 8192:
                back_steps += 1     # 被打回 = 期间发生过总线 reset，不算进度
            else:
                frames += raw
            prev = s

            now = time.time()
            rate = 0.0
            if now - win_start >= WINDOW:
                rate = (frames - frames_at_win_start) / (now - win_start)
                frames_at_win_start = frames
                win_start = now
                if rate > best_rate:
                    best_rate = rate
                    best_rate_at = now - t0
                    if rate > 0:
                        print(f"\n★ 出现 SOF！速率 {rate:.0f} 帧/秒   "
                              f"(第 {best_rate_at:.0f} 秒)  ← 就现在，记下你手在哪儿")

            if s["spd"] != last_spd:
                tag = "★ 速率变成 " + SPD[s["spd"]]
                if s["spd"] == 0:
                    tag += "   ←←← 这就是成功，HS 握手过了！"
                print(f"\n{tag}")
                last_spd = s["spd"]
                if s["spd"] == 0:
                    saw_hs = True

            if s["addr"] != 0 and not saw_addr:
                saw_addr = True
                print(f"\n★ 设备地址变成 {s['addr']}   ←←← 主机开始枚举了！")

            rst = reset_count()
            sys.stdout.write(
                f"\r 速率={SPD[s['spd']]:<10s} SOF速率={rate:6.0f}/s "
                f"累计={frames:8d} 最好={best_rate:6.0f}/s 地址={s['addr']} "
                f"reset={rst} "
            )
            sys.stdout.flush()
    except KeyboardInterrupt:
        pass

    dur = time.time() - t0
    rst_end = reset_count()
    print("\n\n" + "=" * 62)
    print(" 判读结论")
    print("=" * 62)
    print(f" 观测时长              : {dur:.1f} 秒")
    print(f" 最高 SOF 速率         : {best_rate:.0f} 帧/秒   (正常应≈1000)")
    print(f" 累计收到 SOF          : {frames} 帧")
    print(f" 出现过 high-speed     : {'是' if saw_hs else '否'}")
    print(f" 设备地址变成过非 0    : {'是' if saw_addr else '否'}")
    print(f" 期间主机 reset 次数   : {max(rst_end - resets_at_start, 0)}")
    print(f" 计数器被打回次数      : {back_steps}")
    print("-" * 62)
    if saw_hs or saw_addr:
        print(" ★★ 通了！说明是接触问题，部位 = 你刚才动过的那个接头。")
    elif best_rate > 0:
        print(" ★ 有微弱变化：接触时好时坏，仍指向接头接触不良。")
    else:
        print(" 全程没有任何变化 —— 推接头没用。")
        print(" 结论：问题不在『接触压力』，而在这条通路本身。")
        print(" 下一步换一根确定能传数据的 C-to-C 线，然后重跑这个脚本对比。")
    print("=" * 62)


if __name__ == "__main__":
    main()
