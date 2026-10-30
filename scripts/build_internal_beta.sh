#!/bin/bash
# Local Apple-silicon beta only. No upload, Developer ID or notarization.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$repo_root"
xcodebuild -project Nivlet.xcodeproj -scheme Nivlet -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/Phase6Beta \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=- build
beta_app="$repo_root/build/Phase6Beta/Build/Products/Release/Nivlet.app"
codesign --verify --strict "$beta_app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$beta_app" "$repo_root/build/Nivlet-InternalBeta-arm64.zip"
shasum -a 256 build/Nivlet-InternalBeta-arm64.zip > build/Nivlet-InternalBeta-arm64.zip.sha256
