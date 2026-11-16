#!/usr/bin/env bash
# Builds WebWatcher.app (release) into ~/Applications and starts it. The app
# registers itself to start at login once, from this stable path.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="$HOME/Applications/WebWatcher.app"
VERSION="$(git describe --tags --always 2>/dev/null || echo dev)"

echo "[1/4] swift build -c release"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/WebWatcher"

echo "[2/4] bundle $APP"
# Quit a running copy, then replace the bundle rather than overwrite it in place.
pkill -x WebWatcher 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WebWatcher"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.geekychris.webwatcher</string>
  <key>CFBundleName</key><string>Web Watcher</string>
  <key>CFBundleDisplayName</key><string>Web Watcher</string>
  <key>CFBundleExecutable</key><string>WebWatcher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "[3/4] sign (ad hoc)"
codesign --force --sign - "$APP"

echo "[4/4] start"
open "$APP"
sleep 2
pgrep -fl "$APP/Contents/MacOS/WebWatcher" || { echo "WebWatcher didn't start" >&2; exit 1; }
echo "Installed $APP. It adds itself to Login Items (System Settings › General › Login Items)."
