#!/usr/bin/env bash
# Merges a split install (base.apk + split_*.apk, or an .apks/.apkm/.xapk bundle) into one APK,
# which is what apktool, jadx and ReVanced CLI expect.
#
#   scripts/merge-splits.sh <dir-or-bundle> [out.apk]
source "$(dirname "$0")/lib/common.sh"
editor="$(need_jar APKEditor.jar)"

in="${1:?usage: merge-splits.sh <dir-or-bundle> [out.apk]}"
if [[ -d "$in" ]]; then out="${2:-$in/merged.apk}"; else out="${2:-${in%.*}-merged.apk}"; fi

java -jar "$editor" m -i "$in" -o "$out" -f
log "Merged APK: $out"
