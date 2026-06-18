#!/bin/bash
set -euo pipefail

echo "📦 Loading environment..."
set -a
source .env
set +a

BUILD_DIR="build"

echo "🧹 Cleaning..."
rm -rf build dmg_* ${APP_NAME}_*.dmg ${APP_NAME}_*.zip

mkdir -p ${BUILD_DIR}

echo "🔨 Compiling Swift package for arm64 (Apple Silicon)..."
swift build -c release --product "${APP_NAME}" --arch arm64

echo "🔨 Compiling Swift package for x86_64 (Intel)..."
swift build -c release --product "${APP_NAME}" --arch x86_64

package_app() {
    local ARCH_BIN=$1
    local SUFFIX=$2
    
    echo ""
    echo "======================================"
    echo "🚀 Packaging ${APP_NAME} for ${SUFFIX}..."
    echo "======================================"
    
    local ARCH_BUILD_DIR="${BUILD_DIR}/${SUFFIX}"
    local APP_DIR="${ARCH_BUILD_DIR}/${APP_NAME}.app"
    local DMG_DIR="dmg_${SUFFIX}"
    local DMG_NAME="${APP_NAME}_${SUFFIX}.dmg"
    
    mkdir -p ${ARCH_BUILD_DIR}
    mkdir -p ${APP_DIR}/Contents/MacOS
    mkdir -p ${APP_DIR}/Contents/Resources
    
    cp ${ARCH_BIN} ${APP_DIR}/Contents/MacOS/${APP_NAME}
    chmod +x ${APP_DIR}/Contents/MacOS/${APP_NAME}
    
    echo "📋 Creating Info.plist..."
    cat > ${APP_DIR}/Contents/Info.plist <<EOF
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
  <string>2.2.0-beta.1</string>
  <key>CFBundleVersion</key>
  <string>5</string>
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
    --compile ${APP_DIR}/Contents/Resources \
    --platform macosx \
    --minimum-deployment-target ${DEPLOY_TARGET} \
    --app-icon AppIcon \
    --output-partial-info-plist ${BUILD_DIR}/partial_${SUFFIX}.plist >/dev/null 2>&1

    echo "📦 Creating PkgInfo..."
    echo "APPL????" > ${APP_DIR}/Contents/PkgInfo

    echo "🔏 Signing..."
    SIGN_OK=false
    for attempt in 1 2 3; do
        if codesign \
            --force \
            --deep \
            --timestamp \
            --options runtime \
            --sign "${SIGN_IDENTITY}" \
            --entitlements RemindMe.entitlements \
            ${APP_DIR}; then
            SIGN_OK=true
            break
        fi
        echo "⚠️  Signing attempt ${attempt} failed (timestamp server unreachable?), retrying in 3s..."
        sleep 3
    done
    if [ "$SIGN_OK" = false ]; then
        echo "❌ Signing failed after 3 attempts."
        exit 1
    fi

    echo "🔍 Verifying..."
    codesign --verify --deep --strict ${APP_DIR}

    echo "🗜️ Creating ZIP..."
    local ZIP_NAME="${APP_NAME}_${SUFFIX}.zip"
    ditto -ck --rsrc --sequesterRsrc --keepParent ${APP_DIR} ${ZIP_NAME}
    echo "✅ ZIP: ${ZIP_NAME}"

    echo "📂 Preparing DMG..."
    mkdir -p ${DMG_DIR}
    cp -R ${APP_DIR} ${DMG_DIR}/
    ln -s /Applications ${DMG_DIR}/Applications

    echo "💿 Creating DMG..."
    hdiutil create \
    -volname "${APP_NAME} ${SUFFIX}" \
    -srcfolder ${DMG_DIR} \
    -ov \
    -format UDZO \
    ${DMG_NAME}

    echo "🔏 Signing DMG..."
    codesign \
    --force \
    --sign "${SIGN_IDENTITY}" \
    ${DMG_NAME}

    echo "📤 Notarizing DMG..."
    xcrun notarytool submit ${DMG_NAME} \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

    echo "📎 Stapling DMG..."
    xcrun stapler staple ${DMG_NAME}

    echo "🧼 Cleanup..."
    rm -rf ${DMG_DIR}
    
    echo "✅ Finished ${SUFFIX}: ${DMG_NAME}"
}

package_app ".build/arm64-apple-macosx/release/RemindMe" "Silicon"
package_app ".build/x86_64-apple-macosx/release/RemindMe" "Intel"

echo ""
echo "🎉 ALL BUILDS COMPLETE"
