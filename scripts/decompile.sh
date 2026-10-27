#!/usr/bin/env bash
# Decompiles an APK twice into extracted/<service>/<version>/:
#   apktool/  smali + decoded resources   (what you patch, and what ReVanced fingerprints match)
#   jadx/     Java-ish source              (what you read to understand the logic)
#
#   scripts/decompile.sh <service> <apk> [--no-jadx|--no-apktool]
source "$(dirname "$0")/lib/common.sh"
svc="${1:?usage: decompile.sh <service> <apk>}"; check_service "$svc"
apk="${2:?usage: decompile.sh <service> <apk>}"; [[ -f "$apk" ]] || die "No such file: $apk"
shift 2

ver="$(apk_version "$apk")"; [[ "$ver" == unknown ]] && ver="$(basename "$apk" .apk)"
dest="$EXTRACTED_DIR/$svc/$ver"
mkdir -p "$dest"

if [[ " $* " != *" --no-apktool "* ]]; then
  log "apktool -> $dest/apktool"
  java -jar "$(need_jar apktool.jar)" d -f -o "$dest/apktool" "$apk"
fi
if [[ " $* " != *" --no-jadx "* ]]; then
  [[ -x "$TOOLS_DIR/jadx/bin/jadx" ]] || die "jadx not found. Run scripts/setup-tools.sh jadx"
  log "jadx -> $dest/jadx (errors on a few methods are normal for big apps)"
  "$TOOLS_DIR/jadx/bin/jadx" --show-bad-code --deobf --deobf-min 2 -d "$dest/jadx" "$apk" || warn "jadx finished with errors"
fi
echo "$apk" > "$dest/SOURCE_APK.txt"
log "Next: scripts/find-ad-code.sh $svc $dest"
