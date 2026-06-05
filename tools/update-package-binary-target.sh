#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <xcframework-zip-url> <swiftpm-checksum>" >&2
    exit 1
fi

URL="$1"
CHECKSUM="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_SWIFT="$REPO_ROOT/Package.swift"

if [[ ! -f "$PACKAGE_SWIFT" ]]; then
    echo "Package.swift not found: $PACKAGE_SWIFT" >&2
    exit 1
fi

URL="$URL" CHECKSUM="$CHECKSUM" perl -0pi -e '
    my $url = $ENV{"URL"};
    my $checksum = $ENV{"CHECKSUM"};
    my $replacement = ".binaryTarget(\n"
        . "            name: \"arkdrop_uniffiFFI\",\n"
        . "            url: \"$url\",\n"
        . "            checksum: \"$checksum\"\n"
        . "        )";
    my $count = s/\.binaryTarget\(\s*name:\s*"arkdrop_uniffiFFI",\s*(?:path:\s*"[^"]+"|url:\s*"[^"]+",\s*checksum:\s*"[^"]+")\s*\)/$replacement/s;
    die "Expected exactly one arkdrop_uniffiFFI binaryTarget to update\n" unless $count == 1;
' "$PACKAGE_SWIFT"

echo "Updated Package.swift binary target."
