#!/usr/bin/env bash
# 把 PSDK 项目仓库当前的 HEAD 导出到本备份仓库的 projects/ 目录。
set -euo pipefail

SRC=/home/rsp/dji/psdk/m3e-psdk-payload
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DST="$ROOT/projects/m3e-psdk-payload"

if [[ ! -d "$SRC/.git" ]]; then
    echo "错误：找不到项目仓库 $SRC" >&2
    exit 1
fi

rm -rf "$DST"
mkdir -p "$DST"
git -C "$SRC" archive HEAD | tar -x -C "$DST"
echo "已同步 $SRC -> $DST"
