#!/usr/bin/env bash
# Signs a built emdee.app inside-out, as Shepherd's scripts/sign-app.sh does: every nested code
# item first, deepest path first, then the app itself with the app's entitlements. Never
# `codesign --deep`, which would stamp the app's sandbox entitlements onto Sparkle's helpers.
#
# Nested apps and XPC services keep the entitlements Sparkle built them with; everything else is
# signed with none, as in Sparkle's own signing instructions.
#
# usage: scripts/sign-app.sh <emdee.app> <identity> <entitlements.plist>
#   identity "-" signs ad-hoc, without the hardened runtime or a secure timestamp.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <app> <identity|-> <entitlements.plist>" >&2
  exit 64
fi
app=$1
identity=$2
entitlements=$3

[[ -d "$app/Contents" ]] || { echo "error: not an app bundle: $app" >&2; exit 66; }
plutil -lint "$entitlements" >/dev/null

physical() {
  printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd -P)" "$(basename "$1")"
}
app=$(physical "$app")

# Ad-hoc signatures carry no Team ID, so library validation under the hardened runtime would
# refuse the app's own frameworks. Ad-hoc builds skip the runtime, as Xcode's Sign to Run Locally.
sign=(codesign --force --sign "$identity")
if [[ "$identity" != "-" ]]; then
  sign+=(--options runtime --timestamp)
fi

main_executable() {
  local bundle=$1 info dir exe
  case "$bundle" in
    *.framework) dir="$bundle/Versions/Current"; info="$dir/Resources/Info.plist" ;;
    *)           dir="$bundle/Contents/MacOS";   info="$bundle/Contents/Info.plist" ;;
  esac
  [[ -f "$info" ]] || return 0
  exe=$(plutil -extract CFBundleExecutable raw -o - "$info" 2>/dev/null) || return 0
  if [[ -f "$dir/$exe" ]]; then physical "$dir/$exe"; fi
}

# Code bundles, plus loose Mach-O files that are not a bundle's main executable (Sparkle's
# Autoupdate). `find` does not follow symlinks, so each framework version is visited once.
nested_code() {
  local bundle exe file owned
  owned=$(main_executable "$app")$'\n'
  while IFS= read -r bundle; do
    exe=$(main_executable "$bundle")
    [[ -n "$exe" ]] || continue
    echo "$bundle"
    owned+="$exe"$'\n'
  done < <(find "$app/Contents" -type d \( -name '*.framework' -o -name '*.xpc' \
    -o -name '*.app' -o -name '*.appex' -o -name '*.bundle' -o -name '*.plugin' \))

  while IFS= read -r file; do
    [[ "$(file -b "$file")" == Mach-O* ]] || continue
    grep -Fxq -- "$file" <<<"$owned" && continue
    echo "$file"
  done < <(find "$app/Contents" -type f \( -perm -u+x -o -name '*.dylib' \))
}

items=$(nested_code | awk -F/ '{ print NF "\t" $0 }' | sort -rn -k1,1 | cut -f2-)
while IFS= read -r item; do
  [[ -n "$item" ]] || continue
  case "$item" in
    *.app|*.xpc|*.appex) keep=(--preserve-metadata=entitlements) ;;
    *) keep=() ;;
  esac
  echo "sign ${item#"$app"/}${keep:+ (keeping its entitlements)}"
  "${sign[@]}" ${keep[@]+"${keep[@]}"} "$item"
done <<<"$items"

echo "sign $(basename "$app") with $entitlements"
"${sign[@]}" --entitlements "$entitlements" "$app"

codesign --verify --deep --strict --verbose=2 "$app"
