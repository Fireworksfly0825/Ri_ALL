#!/usr/bin/env bash
# SDK 树  →  本仓库
#
# 在 SDK 树里改完代码、编译验证通过之后跑这个，把改动拉回仓库，然后 git diff / commit。
# 只碰下面 FILES 里列出的 10 个文件，不动 SDK 树里任何东西。

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${PSDK_ROOT:-/home/rsp/dji/psdk/current}"

if [ ! -d "$SDK/samples" ]; then
    echo "错误：找不到 SDK 树（$SDK/samples 不存在）。" >&2
    echo "      可用 PSDK_ROOT=/path/to/Payload-SDK-3.15.0 覆盖。" >&2
    exit 1
fi

# 普通文件：直接覆盖
FILES=(
    samples/sample_c/module_sample/flight_control/test_flight_control.c
    samples/sample_c/module_sample/flight_control/test_flight_control.h
    samples/sample_c/platform/linux/raspberry_pi/application/main.c
    samples/sample_c/platform/linux/raspberry_pi/application/dji_sdk_config.h
    samples/sample_c/platform/linux/raspberry_pi/hal/hal_uart.h
    samples/sample_c++/platform/linux/raspberry_pi/application/application.cpp
    samples/sample_c++/platform/linux/raspberry_pi/application/dji_sdk_config.h
    samples/sample_c++/platform/linux/raspberry_pi/hal/hal_uart.h
)

# 含凭据的文件：脱敏后存成 .template
SECRET_FILES=(
    samples/sample_c/platform/linux/raspberry_pi/application/dji_sdk_app_info.h
    samples/sample_c++/platform/linux/raspberry_pi/application/dji_sdk_app_info.h
)

TEMPLATE_HEADER='/* NOTE: 本文件是模板。真实凭据请填在 SDK 树里的 dji_sdk_app_info.h，
 *       不要提交到仓库（.githooks/pre-commit 会拦截）。
 *       本文件由 scripts/sync-from-sdk.sh 从 SDK 树脱敏生成，勿手工编辑。 */
'

changed=0

for f in "${FILES[@]}"; do
    src="$SDK/$f"
    dst="$REPO/sdk-overlay/$f"
    if [ ! -f "$src" ]; then
        echo "跳过（SDK 树里不存在）：$f" >&2
        continue
    fi
    mkdir -p "$(dirname "$dst")"
    if ! cmp -s "$src" "$dst"; then
        cp -p "$src" "$dst"
        echo "更新  $f"
        changed=1
    fi
done

for f in "${SECRET_FILES[@]}"; do
    src="$SDK/$f"
    dst="$REPO/sdk-overlay/$f.template"
    if [ ! -f "$src" ]; then
        echo "跳过（SDK 树里不存在）：$f" >&2
        continue
    fi
    mkdir -p "$(dirname "$dst")"
    tmp="$(mktemp)"
    {
        printf '%s' "$TEMPLATE_HEADER"
        sed -E \
            -e 's/^(#define[[:space:]]+USER_APP_KEY[[:space:]]+)".*"/\1"YOUR_APP_KEY"/' \
            -e 's/^(#define[[:space:]]+USER_APP_LICENSE[[:space:]]+)".*"/\1"YOUR_APP_LICENSE"/' \
            -e 's/^(#define[[:space:]]+USER_DEVELOPER_ACCOUNT[[:space:]]+)".*"/\1"YOUR_DEVELOPER_ACCOUNT"/' \
            "$src"
    } > "$tmp"
    if ! cmp -s "$tmp" "$dst"; then
        mv "$tmp" "$dst"
        echo "更新  $f  →  ${dst#$REPO/}（已脱敏）"
        changed=1
    else
        rm -f "$tmp"
    fi
done

echo
if [ "$changed" -eq 0 ]; then
    echo "仓库已是最新，无改动。"
else
    echo "同步完成。接下来："
    echo "    cd $REPO && git diff && git commit && git push"
fi

if command -v git >/dev/null && [ -d "$REPO/.git" ]; then
    echo
    echo "--- git status ---"
    git -C "$REPO" status --short
fi
