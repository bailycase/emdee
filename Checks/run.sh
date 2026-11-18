#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
bin=$(mktemp -d)
trap 'rm -f "$bin/check"; rmdir "$bin"' EXIT
xcrun swiftc -swift-version 6 -o "$bin/check" Checks/main.swift \
  emdee/MarkdownFile.swift emdee/Recents.swift emdee/Source.swift emdee/Theme.swift
"$bin/check"
