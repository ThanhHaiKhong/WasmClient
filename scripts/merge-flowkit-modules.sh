#!/bin/bash
# Merge FlowKit XCFramework sub-module interfaces (AsyncWasm, TaskWasm, etc.)
# into a single directory so one -I flag works for all build destinations.
#
# EXCLUDES modules that SPM resolves on its own (FlowKit, SwiftProtobuf) to
# avoid conflicting with Xcode's per-slice framework search paths.
#
# Usage:
#   merge-flowkit-modules.sh <package-dir> <output-dir>
#   merge-flowkit-modules.sh                              # defaults: cwd, .build/flowkit-merged-modules

set -euo pipefail

PACKAGE_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
OUTPUT_DIR="${2:-$PACKAGE_DIR/.build/flowkit-merged-modules}"

# Modules managed by SPM — MUST be excluded to prevent slice conflicts.
EXCLUDE="FlowKit.swiftmodule SwiftProtobuf.swiftmodule"

# Search known xcframework locations (local dev + dependency consumer).
XCFW=""
for candidate in \
  "$PACKAGE_DIR/.build/artifacts/flow-kit/FlowKit/FlowKit.xcframework" \
  "$PACKAGE_DIR/../../artifacts/flow-kit/FlowKit/FlowKit.xcframework"; do
  if [ -d "$candidate" ]; then
    XCFW="$candidate"
    break
  fi
done

if [ -z "$XCFW" ]; then
  echo "warning: FlowKit.xcframework not found — sub-modules will not be available." >&2
  mkdir -p "$OUTPUT_DIR"
  exit 0
fi

DEVICE="$XCFW/ios-arm64/FlowKit.framework/Modules"
SIMULATOR="$XCFW/ios-arm64_x86_64-simulator/FlowKit.framework/Modules"

if [ ! -d "$DEVICE" ] || [ ! -d "$SIMULATOR" ]; then
  echo "warning: FlowKit framework slices missing — sub-modules will not be available." >&2
  mkdir -p "$OUTPUT_DIR"
  exit 0
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

count=0
for mod in "$DEVICE"/*.swiftmodule; do
  name=$(basename "$mod")

  # Skip SPM-managed modules.
  case " $EXCLUDE " in
    *" $name "*) continue ;;
  esac

  mkdir -p "$OUTPUT_DIR/$name"

  # Symlink device architecture files.
  for f in "$mod"/*; do
    ln -sf "$f" "$OUTPUT_DIR/$name/$(basename "$f")"
  done

  # Symlink simulator architecture files.
  simmod="$SIMULATOR/$name"
  if [ -d "$simmod" ]; then
    for f in "$simmod"/*; do
      ln -sf "$f" "$OUTPUT_DIR/$name/$(basename "$f")"
    done
  fi

  count=$((count + 1))
done

echo "Merged $count sub-modules into $OUTPUT_DIR"
