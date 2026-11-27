#!/bin/bash
# 本地安装 macOS 构建：构建 -> 替换 /Applications -> 用稳定证书重签 -> 启动。
#
# 为什么需要重签：flutter build 默认产出 ad-hoc 签名，而 ad-hoc 的签名哈希
# 每次构建都会变。Keychain 条目的 ACL 记录的是创建它的签名，于是每次重装后
# 读取私钥都会重新弹授权（甚至反复弹到超时）。用开发者证书重签后签名标识
# 稳定，Keychain 的“始终允许”可以长期生效。
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
flutter build macos --release

osascript -e 'tell application "TinyDesk" to quit' 2>/dev/null || true
pkill -f "TinyDesk.app/Contents/MacOS/TinyDesk" 2>/dev/null || true
sleep 2

rm -rf /Applications/TinyDesk.app
cp -R build/macos/Build/Products/Release/TinyDesk.app /Applications/

IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' 'NR==1{print $2}')
if [ -n "${IDENTITY:-}" ]; then
  codesign --force --deep --sign "$IDENTITY" /Applications/TinyDesk.app
  echo "signed with: $IDENTITY"
else
  echo "no codesigning identity found; keeping the ad-hoc signature"
fi

open /Applications/TinyDesk.app
echo "installed /Applications/TinyDesk.app"
