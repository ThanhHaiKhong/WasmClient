#!/bin/bash
# Merge FlowKit XCFramework module interfaces from device + simulator slices
# into a single directory so one -I flag works for all build destinations.
#
# Run after: swift package resolve

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCFW="$REPO_ROOT/.build/artifacts/flow-kit/FlowKit/FlowKit.xcframework"
DEVICE="$XCFW/ios-arm64/FlowKit.framework/Modules"
SIMULATOR="$XCFW/ios-arm64_x86_64-simulator/FlowKit.framework/Modules"
MERGED="$REPO_ROOT/.build/flowkit-merged-modules"

if [ ! -d "$DEVICE" ] || [ ! -d "$SIMULATOR" ]; then
  echo "error: FlowKit xcframework not found. Run 'swift package resolve' first." >&2
  exit 1
fi

rm -rf "$MERGED"
mkdir -p "$MERGED"

for mod in "$DEVICE"/*.swiftmodule; do
  name=$(basename "$mod")
  mkdir -p "$MERGED/$name"

  # Symlink device architecture files
  for f in "$mod"/*; do
    ln -sf "$f" "$MERGED/$name/$(basename "$f")"
  done

  # Symlink simulator architecture files
  simmod="$SIMULATOR/$name"
  if [ -d "$simmod" ]; then
    for f in "$simmod"/*; do
      ln -sf "$f" "$MERGED/$name/$(basename "$f")"
    done
  fi
done

echo "Merged $(ls -1 "$MERGED" | wc -l | tr -d ' ') modules into $MERGED"
