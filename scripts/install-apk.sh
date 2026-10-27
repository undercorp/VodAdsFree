#!/usr/bin/env bash
# Installs a patched APK on the connected device (phone, Android TV or Fire TV).
#
#   scripts/install-apk.sh <patched.apk> [--replace]
#
# A re-signed APK cannot update the store version (signature mismatch). With --replace the
# original is uninstalled first, which DELETES its data (downloads, login).
source "$(dirname "$0")/lib/common.sh"
need adb "Install Android platform-tools."
apk="${1:?usage: install-apk.sh <apk> [--replace]}"
pkg=""
if command -v aapt2 >/dev/null 2>&1; then pkg="$(aapt2 dump packagename "$apk" 2>/dev/null || true)"; fi

if [[ "${2:-}" == "--replace" ]]; then
  [[ -n "$pkg" ]] || die "Can't read package name (install Android build-tools for aapt2), uninstall manually."
  warn "Uninstalling $pkg (its app data will be lost)"
  adb uninstall "$pkg" || true
fi
adb install -r "$apk" || die "Install failed. INSTALL_FAILED_UPDATE_INCOMPATIBLE means the store version is still installed: use --replace."
log "Installed. Logs: adb logcat -s VodAdsFree:* AndroidRuntime:E"
