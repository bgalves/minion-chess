#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build -c release --triple arm64-apple-macosx13.0 --scratch-path .build-arm
swift build -c release --triple x86_64-apple-macosx13.0 --scratch-path .build-x86
APP="Minion Chess.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
lipo -create .build-arm/release/MinionChess .build-x86/release/MinionChess -output "$APP/Contents/MacOS/MinionChess"
mkdir -p "$APP/Contents/Resources"; cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Minion Chess</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleExecutable</key><string>MinionChess</string>
<key>CFBundleIdentifier</key><string>com.minionchess.app</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PL
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
