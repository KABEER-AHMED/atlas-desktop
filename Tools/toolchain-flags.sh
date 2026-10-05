#!/usr/bin/env bash
# Prints the extra `swift build` / `swift test` flags needed on this
# machine, if any.
#
# Why this exists: SwiftUI's `@State` and the `Testing` framework's
# `@Test` are macros, and macro expansion needs the compiler plugins.
# A full Xcode install provides them and needs no flags. A machine with
# only the Command Line Tools has the `Testing` plugin in a
# subdirectory the compiler does not search by default, and no SwiftUI
# plugin at all — but Xcode's copy loads correctly in the Command Line
# Tools compiler, so if Xcode is present the plugin directories are
# simply added to the search path.
#
# Usage:
#   swift build $(Tools/toolchain-flags.sh)
#   swift test  $(Tools/toolchain-flags.sh)
set -euo pipefail

ACTIVE="$(xcode-select -p 2>/dev/null || echo '')"

# A full Xcode toolchain already finds every plugin.
case "$ACTIVE" in
  *Xcode*) exit 0 ;;
esac

FLAGS=()

TESTING_PLUGINS="$ACTIVE/usr/lib/swift/host/plugins/testing"
if [ -d "$TESTING_PLUGINS" ]; then
  FLAGS+=(-Xswiftc -plugin-path -Xswiftc "$TESTING_PLUGINS")
fi

for CANDIDATE in /Applications/Xcode*.app; do
  XCODE_PLUGINS="$CANDIDATE/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
  if [ -d "$XCODE_PLUGINS" ]; then
    FLAGS+=(-Xswiftc -plugin-path -Xswiftc "$XCODE_PLUGINS")
    break
  fi
done

printf '%s ' "${FLAGS[@]+"${FLAGS[@]}"}"
