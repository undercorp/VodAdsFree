#!/usr/bin/env bash
# Pulls an installed app (base + split APKs) from a connected device into samples/<service>/<version>/.
#
#   scripts/pull-apk.sh <service> [package]
#
# Works for phones, Android TV and Fire TV. For Fire TV, enable ADB debugging first and run
# `adb connect <fire-tv-ip>:5555`. Pulling from your own device is the most reliable way to get
# an APK that matches what you actually run.
source "$(dirname "$0")/lib/common.sh"
need adb "Install Android platform-tools."

svc="${1:?usage: pull-apk.sh <service> [package]}"; check_service "$svc"
pkg="${2:-}"
if [[ -z "$pkg" ]]; then
  for p in ${SERVICE_PACKAGES[$svc]}; do
    if adb shell pm path "$p" >/dev/null 2>&1; then pkg="$p"; break; fi
  done
fi
[[ -n "$pkg" ]] || die "None of ${SERVICE_PACKAGES[$svc]} is installed on the device."

version="$(adb shell dumpsys package "$pkg" | sed -n 's/.*versionName=\([^ ]*\).*/\1/p' | head -1 | tr -d '\r')"
model="$(adb shell getprop ro.product.model | tr -d '\r' | tr ' ' '_')"
dest="$SAMPLES_DIR/$svc/$pkg-$version"
mkdir -p "$dest"
log "Pulling $pkg $version from $model into $dest"

adb shell pm path "$pkg" | tr -d '\r' | sed 's/^package://' | while read -r path; do
  adb pull "$path" "$dest/$(basename "$path")" >/dev/null
  log "  $(basename "$path")"
done

cat > "$dest/SOURCE.txt" <<INFO
package: $pkg
version: $version
device:  $model
pulled:  $(date -u +%Y-%m-%dT%H:%M:%SZ)
INFO
ls "$dest"/split_*.apk >/dev/null 2>&1 && log "Split APKs found: merge them with scripts/merge-splits.sh $dest"
