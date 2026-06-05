#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$(cd "${CORE_DIR:-"$REPO_ROOT/../Core"}" && pwd)"
UNIFFI_DIR="$CORE_DIR/drop-core/uniffi"
SWIFT_SOURCES_DIR="$REPO_ROOT/core/Sources/ArkDrop"
GENERATED_DIR="$REPO_ROOT/core/Generated"

if [[ ! -d "$UNIFFI_DIR" ]]; then
    echo "Core UniFFI directory not found: $UNIFFI_DIR" >&2
    echo "Set CORE_DIR to a checkout of ARK-Builders/ark-core." >&2
    exit 1
fi

if ! grep -q "uniffi-bindgen-swift" "$UNIFFI_DIR/Cargo.toml"; then
    echo "Core checkout does not expose uniffi-bindgen-swift yet." >&2
    echo "Port the minimal Swift UniFFI helper from Core-Swift-Bindings first." >&2
    exit 1
fi

mkdir -p "$SWIFT_SOURCES_DIR" "$GENERATED_DIR"
rm -f "$GENERATED_DIR"/*.h "$GENERATED_DIR"/*.modulemap "$GENERATED_DIR"/module.modulemap

echo "Building arkdrop-uniffi for binding generation..."
cargo build --manifest-path "$UNIFFI_DIR/Cargo.toml" --lib --release

LIBRARY_PATH="$CORE_DIR/target/release/libarkdrop_uniffi.a"
if [[ ! -f "$LIBRARY_PATH" ]]; then
    echo "Static library not found: $LIBRARY_PATH" >&2
    echo "Core may need crate-type staticlib for Swift binding generation." >&2
    exit 1
fi

echo "Generating Swift source..."
(
    cd "$UNIFFI_DIR"
    cargo run --bin uniffi-bindgen-swift -- \
        --swift-sources "$LIBRARY_PATH" "$SWIFT_SOURCES_DIR"
)

echo "Generating C header..."
(
    cd "$UNIFFI_DIR"
    cargo run --bin uniffi-bindgen-swift -- \
        --headers "$LIBRARY_PATH" "$GENERATED_DIR"
)

echo "Generating module map..."
(
    cd "$UNIFFI_DIR"
    cargo run --bin uniffi-bindgen-swift -- \
        --modulemap "$LIBRARY_PATH" "$GENERATED_DIR"
)

if [[ -f "$GENERATED_DIR/arkdrop_uniffi.modulemap" ]]; then
    mv "$GENERATED_DIR/arkdrop_uniffi.modulemap" "$GENERATED_DIR/module.modulemap"
fi

for required_file in \
    "$SWIFT_SOURCES_DIR/ArkDrop.swift" \
    "$GENERATED_DIR/module.modulemap"; do
    if [[ ! -f "$required_file" ]]; then
        echo "Required generated file missing: $required_file" >&2
        exit 1
    fi
done

HEADER_NAME="$(sed -n 's/.*header "\([^"]*\)".*/\1/p' "$GENERATED_DIR/module.modulemap" | head -n 1)"
if [[ -z "$HEADER_NAME" || ! -f "$GENERATED_DIR/$HEADER_NAME" ]]; then
    echo "Generated module map does not reference an existing header." >&2
    exit 1
fi

echo "Swift bindings generated successfully."
