# Shared helpers for every script in this repo. Source it, don't run it.
# shellcheck shell=bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools/bin"
SAMPLES_DIR="$REPO_ROOT/samples"
EXTRACTED_DIR="$REPO_ROOT/extracted"
OUT_DIR="$REPO_ROOT/out"

# Package names per service. The first one is the main phone/tablet build.
declare -A SERVICE_PACKAGES=(
  [netflix]="com.netflix.mediaclient com.netflix.ninja"
  [disneyplus]="com.disney.disneyplus"
  [hbomax]="com.wbd.stream"
  [primevideo]="com.amazon.avod.thirdpartyclient com.amazon.amazonvideo.livingroom"
)

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed. $2"
}

need_jar() {
  local jar="$TOOLS_DIR/$1"
  [[ -f "$jar" ]] || die "$1 not found in tools/bin. Run scripts/setup-tools.sh first."
  printf '%s' "$jar"
}

check_service() {
  [[ -n "${SERVICE_PACKAGES[$1]:-}" ]] || die "Unknown service '$1'. Use one of: ${!SERVICE_PACKAGES[*]}"
}

# Reads versionName from an APK (needs aapt2 or apkanalyzer if present, falls back to apktool output).
apk_version() {
  local apk="$1"
  if command -v aapt2 >/dev/null 2>&1; then
    aapt2 dump badging "$apk" 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -1
  elif command -v aapt >/dev/null 2>&1; then
    aapt dump badging "$apk" 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -1
  else
    echo "unknown"
  fi
}

# Signs an APK with apksigner when available (Android build-tools), otherwise uber-apk-signer.
# Uses $VAF_KEYSTORE if set so updates keep the same signature; otherwise a debug key.
sign_apk() {
  local in="$1" out="$2"
  if command -v apksigner >/dev/null 2>&1 && [[ -n "${VAF_KEYSTORE:-}" ]]; then
    local aligned="${out%.apk}-aligned.apk"
    if command -v zipalign >/dev/null 2>&1; then zipalign -f -p 4 "$in" "$aligned"; else cp "$in" "$aligned"; fi
    apksigner sign --ks "$VAF_KEYSTORE" --ks-pass "env:VAF_KEYSTORE_PASS" --out "$out" "$aligned"
    rm -f "$aligned"
  else
    local signer; signer="$(need_jar uber-apk-signer.jar)"
    local tmp; tmp="$(mktemp -d)"
    local args=(-a "$in" -o "$tmp" --allowResign)
    [[ -n "${VAF_KEYSTORE:-}" ]] && args+=(--ks "$VAF_KEYSTORE" --ksPass "${VAF_KEYSTORE_PASS:-}" --ksAlias "${VAF_KEYSTORE_ALIAS:-vodadsfree}" --ksKeyPass "${VAF_KEYSTORE_PASS:-}")
    java -jar "$signer" "${args[@]}" >&2
    mv "$tmp"/*.apk "$out"
    rm -rf "$tmp"
  fi
  log "Signed: $out"
}
