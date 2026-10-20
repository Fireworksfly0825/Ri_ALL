#!/usr/bin/env bash
# 本仓库  →  SDK 树
#
# 换机器 / 重装 SDK 之后跑这个，把仓库里的覆盖层写回 SDK 树。
# 目录结构是镜像的，所以一次 cp 就位，不需要手工对路径。
#
# 安全约定：含凭据的 dji_sdk_app_info.h **只在目标不存在时**才从模板生成，
#          已经存在的绝不覆盖（那里面是真实凭据）。

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${PSDK_ROOT:-/home/rsp/dji/psdk/current}"

if [ ! -d "$SDK/samples" ]; then
    echo "错误：找不到 SDK 树（$SDK/samples 不存在）。" >&2
    echo "      请先按 README 的「新机器 / 重装后恢复」下载同版本 SDK，" >&2
    echo "      或用 PSDK_ROOT=/path/to/Payload-SDK-3.15.0 覆盖。" >&2
    exit 1
fi

echo "仓库：$REPO"
echo "SDK ：$SDK"
echo

N=0
while IFS= read -r src; do
    rel="${src#$REPO/sdk-overlay/}"
    dst="$SDK/$rel"
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    echo "写入  $rel"
    N=$((N + 1))
done < <(find "$REPO/sdk-overlay" -type f ! -name '*.template' | sort)

echo
echo "共写入 $N 个文件。"

# --- 含凭据的文件：只补缺，不覆盖 --------------------------------------------
missing=()
while IFS= read -r src; do
    rel="${src#$REPO/sdk-overlay/}"
    rel="${rel%.template}"
    dst="$SDK/$rel"
    if [ -e "$dst" ]; then
        echo "保留  $rel（已存在，不覆盖真实凭据）"
    else
        mkdir -p "$(dirname "$dst")"
        cp -p "$src" "$dst"
        missing+=("$dst")
    fi
done < <(find "$REPO/sdk-overlay" -type f -name '*.template' | sort)

if [ "${#missing[@]}" -gt 0 ]; then
    echo
    echo "！！以下文件是刚从模板生成的，里面还是占位符，**必须手工填真实凭据**："
    for f in "${missing[@]}"; do
        echo "    $f"
    done
    echo
    echo "  需要填的字段：USER_APP_ID / USER_APP_KEY / USER_APP_LICENSE / USER_DEVELOPER_ACCOUNT"
    echo "  去 https://developer.dji.com/user/apps/#all 查。"
    echo "  这两个文件在 .gitignore 里，不会被提交。"
fi

echo
echo "接下来：cd $SDK/build && make"
