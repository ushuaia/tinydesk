#!/bin/bash
# 鸿蒙 Flutter 开发环境：source 本文件后即可使用 flutter-ohos / ohpm / hdc
# 用法：source scripts/env-ohos.sh

export PATH="$HOME/flutter-ohos/bin:$PATH"
export FLUTTER_GIT_URL="https://gitcode.com/openharmony-sig/flutter_flutter.git"

DEVECO_APP="/Applications/DevEco-Studio.app"

if [ -d "$DEVECO_APP" ]; then
  export DEVECO_SDK_HOME="$DEVECO_APP/Contents/sdk"
  export PATH="$DEVECO_APP/Contents/tools/ohpm/bin:$PATH"
  export PATH="$DEVECO_SDK_HOME/default/openharmony/toolchains:$PATH"
  export PATH="$DEVECO_APP/Contents/tools/hvigor/bin:$PATH"
fi

# 新版 DevEco 也可能把 SDK 放在用户目录
if [ -d "$HOME/Library/Huawei/Sdk" ] && [ ! -d "$DEVECO_SDK_HOME" ]; then
  export DEVECO_SDK_HOME="$HOME/Library/Huawei/Sdk"
fi

echo "flutter : $(command -v flutter || echo missing)"
echo "ohpm    : $(command -v ohpm || echo missing)"
echo "hdc     : $(command -v hdc || echo missing)"
echo "sdk     : ${DEVECO_SDK_HOME:-missing}"
