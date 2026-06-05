#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$(cd "${CORE_DIR:-"$REPO_ROOT/../Core"}" && pwd)"
UNIFFI_DIR="$CORE_DIR/drop-core/uniffi"
GENERATED_DIR="$REPO_ROOT/core/Generated"
ARTIFACTS_DIR="$REPO_ROOT/core/Artifacts"
BUILD_DIR="$REPO_ROOT/.build/arkdrop-xcframework"
XCFRAMEWORK="$ARTIFACTS_DIR/arkdrop_uniffiFFI.xcframework"

if [[ ! -d "$UNIFFI_DIR" ]]; then
    echo "Core UniFFI directory not found: $UNIFFI_DIR" >&2
    echo "Set CORE_DIR to a checkout of ARK-Builders/ark-core." >&2
    exit 1
fi

for required_file in "$GENERATED_DIR/module.modulemap"; do
    if [[ ! -f "$required_file" ]]; then
        echo "Missing generated file: $required_file" >&2
        echo "Run tools/generate-bindings.sh first." >&2
        exit 1
    fi
done

HEADER_NAME="$(sed -n 's/.*header "\([^"]*\)".*/\1/p' "$GENERATED_DIR/module.modulemap" | head -n 1)"
if [[ -z "$HEADER_NAME" || ! -f "$GENERATED_DIR/$HEADER_NAME" ]]; then
    echo "Generated module map does not reference an existing header." >&2
    echo "Run tools/generate-bindings.sh first." >&2
    exit 1
fi

if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
    if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
        export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    fi
fi

rm -rf "$BUILD_DIR" "$XCFRAMEWORK"
mkdir -p "$BUILD_DIR" "$ARTIFACTS_DIR"

build_staticlib() {
    local target="$1"
    echo "Building $target..."
    cargo rustc --manifest-path "$UNIFFI_DIR/Cargo.toml" --lib --release \
        --target "$target" --crate-type staticlib
}

build_staticlib aarch64-apple-ios
build_staticlib x86_64-apple-ios
build_staticlib aarch64-apple-ios-sim
build_staticlib x86_64-apple-darwin
build_staticlib aarch64-apple-darwin

mkdir -p "$BUILD_DIR/ios" "$BUILD_DIR/ios-simulator" "$BUILD_DIR/macos"
cp "$CORE_DIR/target/aarch64-apple-ios/release/libarkdrop_uniffi.a" "$BUILD_DIR/ios/"

lipo -create \
    "$CORE_DIR/target/x86_64-apple-ios/release/libarkdrop_uniffi.a" \
    "$CORE_DIR/target/aarch64-apple-ios-sim/release/libarkdrop_uniffi.a" \
    -output "$BUILD_DIR/ios-simulator/libarkdrop_uniffi.a"

lipo -create \
    "$CORE_DIR/target/x86_64-apple-darwin/release/libarkdrop_uniffi.a" \
    "$CORE_DIR/target/aarch64-apple-darwin/release/libarkdrop_uniffi.a" \
    -output "$BUILD_DIR/macos/libarkdrop_uniffi.a"

for platform_dir in "$BUILD_DIR/ios" "$BUILD_DIR/ios-simulator" "$BUILD_DIR/macos"; do
    mkdir -p "$platform_dir/Headers"
    cp "$GENERATED_DIR/$HEADER_NAME" "$platform_dir/Headers/"
    cp "$GENERATED_DIR/module.modulemap" "$platform_dir/Headers/"
done

xcodebuild -create-xcframework \
    -library "$BUILD_DIR/ios/libarkdrop_uniffi.a" \
    -headers "$BUILD_DIR/ios/Headers" \
    -library "$BUILD_DIR/ios-simulator/libarkdrop_uniffi.a" \
    -headers "$BUILD_DIR/ios-simulator/Headers" \
    -library "$BUILD_DIR/macos/libarkdrop_uniffi.a" \
    -headers "$BUILD_DIR/macos/Headers" \
    -output "$XCFRAMEWORK"

echo "Created $XCFRAMEWORK"
