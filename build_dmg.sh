#!/bin/bash
set -euo pipefail

echo "📦 Loading environment..."
set -a
source .env
set +a

BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_DIR="dmg"
DMG_NAME="${APP_NAME}_Release.dmg"

echo "🧹 Cleaning..."
rm -rf build dmg "${DMG_NAME}"

mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

echo "🔨 Building Swift package..."
swift build -c release --product "${APP_NAME}"

BIN_PATH="$(find .build -type f -path "*/release/${APP_NAME}" | head -n 1)"
if [[ -z "${BIN_PATH}" ]]; then
  echo "❌ Could not locate built binary for ${APP_NAME}."
  exit 1
fi

cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

echo "📋 Creating Info.plist..."
cat > "${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>${DEPLOY_TARGET}</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

echo "🎨 Building assets..."
xcrun actool Assets.xcassets \
  --compile "${APP_DIR}/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target "${DEPLOY_TARGET}" \
  --app-icon AppIcon \
  --output-partial-info-plist "${BUILD_DIR}/partial.plist" >/dev/null 2>&1

echo "📦 Creating PkgInfo..."
echo "APPL????" > "${APP_DIR}/Contents/PkgInfo"

echo "🔏 Signing..."
codesign \
  --force \
  --deep \
  --timestamp \
  --options runtime \
  --sign "${SIGN_IDENTITY}" \
  --entitlements RemindMe.entitlements \
  "${APP_DIR}"

echo "🔍 Verifying..."
codesign --verify --deep --strict "${APP_DIR}"

echo "📂 Preparing DMG..."
mkdir -p "${DMG_DIR}"
cp -R "${APP_DIR}" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

echo "💿 Creating DMG..."
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_NAME}"

echo "🔏 Signing DMG..."
codesign \
  --force \
  --sign "${SIGN_IDENTITY}" \
  "${DMG_NAME}"

echo "📤 Notarizing DMG..."
xcrun notarytool submit "${DMG_NAME}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait

echo "📎 Stapling DMG..."
xcrun stapler staple "${DMG_NAME}"

echo "🧼 Cleanup..."
rm -rf "${DMG_DIR}"

echo ""
echo "✅ BUILD COMPLETE"
echo "DMG: ${DMG_NAME}"
