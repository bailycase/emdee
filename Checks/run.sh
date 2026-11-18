#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
bin=$(mktemp -d)
trap 'rm -f "$bin/check"; rmdir "$bin"' EXIT
xcrun swiftc Checks/main.swift emdee/MarkdownDocument.swift emdee/MarkdownPreview.swift -o "$bin/check"
"$bin/check"
