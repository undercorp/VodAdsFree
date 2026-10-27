#!/usr/bin/env bash
# Approach C: no ReVanced at all. apktool decode -> edit smali -> rebuild -> sign.
# Slowest and most fragile (apktool must re-encode all resources), but needs nothing except
# Java + Python, and shows exactly what changes. Useful when the patcher can't handle an APK,
# or to experiment with the smali by hand before turning it into a patch.
#
#   services/primevideo/scripts/patch-apktool.sh <primevideo.apk>
#
# Env: VAF_KEEP_WORKDIR=1 keeps the decoded tree in out/ for inspection.
source "$(dirname "$0")/../../../scripts/lib/common.sh"
apktool="$(need_jar apktool.jar)"
apk="${1:?usage: patch-apktool.sh <apk>}"
here="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$OUT_DIR"
work="$OUT_DIR/primevideo-apktool"
rm -rf "$work"

log "Decoding (resources are only copied, -r, to avoid resource re-encoding problems)"
java -jar "$apktool" d -r -f -o "$work" "$apk"

log "Applying smali patch"
python3 -I "$here/apply_smali_patch.py" "$work"

log "Rebuilding"
java -jar "$apktool" b -o "$OUT_DIR/primevideo-apktool-unsigned.apk" "$work"

sign_apk "$OUT_DIR/primevideo-apktool-unsigned.apk" "$OUT_DIR/primevideo-apktool-patched.apk"
rm -f "$OUT_DIR/primevideo-apktool-unsigned.apk"
[[ "${VAF_KEEP_WORKDIR:-}" == 1 ]] || rm -rf "$work"
log "Done: $OUT_DIR/primevideo-apktool-patched.apk"
