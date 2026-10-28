#!/usr/bin/env bash
# Installs a patched APK on the connected device (phone, Android TV or Fire TV).
#
#   scripts/install-apk.sh <patched.apk> [--replace [package]]
#
# A re-signed APK cannot update the store version (signature mismatch). With --replace the
# original is uninstalled first, which DELETES its data (downloads, login). The package name is
# read with aapt2 if available; otherwise pass it after --replace.
#
# Several devices connected (e.g. a phone over USB and a TV over Wi-Fi)? Pick one with
#   ANDROID_SERIAL=192.168.1.50:5555 scripts/install-apk.sh ...
source "$(dirname "$0")/lib/common.sh"
need adb "Install Android platform-tools."
apk="${1:?usage: install-apk.sh <apk> [--replace [package]]}"
[[ -f "$apk" ]] || die "No such file: $apk"

if [[ "${2:-}" == "--replace" ]]; then
  pkg="${3:-}"
  if [[ -z "$pkg" ]] && command -v aapt2 >/dev/null 2>&1; then
    pkg="$(aapt2 dump packagename "$apk" 2>/dev/null || true)"
  fi
  [[ -n "$pkg" ]] || die "Can't read the package name (no aapt2): pass it, e.g. --replace com.netflix.ninja"

  # Preinstalled (system) apps can't be removed without root, and the patched APK can't be
  # installed over them because the signatures differ.
  if adb shell pm list packages -s 2>/dev/null | tr -d '\r' | grep -qx "package:$pkg"; then
    die "$pkg is a preinstalled system app on this device: it can't be replaced without root (see docs/guide-android-tv.md)."
  fi

  warn "Uninstalling $pkg (its app data will be lost)"
  adb uninstall "$pkg" || true
fi
adb install -r "$apk" || die "Install failed. INSTALL_FAILED_UPDATE_INCOMPATIBLE means the store version is still installed: use --replace <package>."
log "Installed. Logs: adb logcat -s VodAdsFree:* AndroidRuntime:E"
