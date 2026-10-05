#!/usr/bin/env bash
# Builds Atlas Desktop.app from the Swift package.
#
#     Tools/make-app-bundle.sh [debug|release]
#
# `swift run AtlasDesktopApp` launches the same code, but a bare
# executable has no Info.plist, so macOS gives it a generic name and
# icon and no bundle identifier. The app window, menu title, Dock icon
# and preferences domain all come from this bundle, so this is the way
# to run it as a real app.
set -euo pipefail

CONFIGURATION="${1:-release}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -f Resources/AppIcon.icns ]; then
  echo "==> Generating the app icon"
  swift Tools/make-icon.swift
fi

echo "==> Building ($CONFIGURATION)"
# shellcheck disable=SC2046
swift build -c "$CONFIGURATION" --product AtlasDesktopApp $(Tools/toolchain-flags.sh)

BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path $(Tools/toolchain-flags.sh))"
APP="$REPO_ROOT/build/Atlas Desktop.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH/AtlasDesktopApp" "$APP/Contents/MacOS/Atlas Desktop"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# SwiftPM emits each target's resources as a bundle beside the binary.
# `Bundle.module` searches the main bundle's resource directory and the
# executable's own directory, so the bundle is copied to both and the
# lookup works wherever the app is launched from.
for RESOURCE_BUNDLE in "$BIN_PATH"/*.bundle; do
  [ -e "$RESOURCE_BUNDLE" ] || continue
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/MacOS/"
done

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Atlas Desktop</string>
	<key>CFBundleDisplayName</key>
	<string>Atlas Desktop</string>
	<key>CFBundleExecutable</key>
	<string>Atlas Desktop</string>
	<key>CFBundleIdentifier</key>
	<string>com.atlasdesktop.app</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.education</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Country boundaries, names and capitals from Natural Earth (public domain).</string>
	<key>NSSupportsAutomaticTermination</key>
	<true/>
	<key>NSSupportsSuddenTermination</key>
	<true/>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for the app to launch locally. Distribution
# would need a Developer ID certificate, which this repository does not
# and should not contain.
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || \
  echo "note: ad-hoc code signing was unavailable; the app will still run locally"

echo "==> Built $APP"
echo "    open \"$APP\""
