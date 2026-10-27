#!/usr/bin/env bash
# Downloads the reverse-engineering and patching tools into tools/bin (git-ignored).
#
#   scripts/setup-tools.sh            # everything
#   scripts/setup-tools.sh apktool    # just one tool
#
# Tools: apktool, jadx, revanced-cli, APKEditor (split merging), uber-apk-signer.
# Each is fetched from its project's latest GitHub release. Set GITHUB_TOKEN to avoid API rate limits.
source "$(dirname "$0")/lib/common.sh"
need curl "Install curl."
need python3 "Install Python 3."
need java "Install a JDK 17+ (e.g. Temurin)."
mkdir -p "$TOOLS_DIR"

# latest_asset <owner/repo> <regex for asset name>  -> prints download URL
latest_asset() {
  local auth=()
  [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  curl -fsSL "${auth[@]}" "https://api.github.com/repos/$1/releases/latest" |
    python3 -c 'import json,re,sys
pat=re.compile(sys.argv[1])
for a in json.load(sys.stdin)["assets"]:
    if pat.search(a["name"]):
        print(a["browser_download_url"]); break' "$2"
}

fetch() { # fetch <name> <owner/repo> <asset regex> <dest>
  local url; url="$(latest_asset "$2" "$3")"
  [[ -n "$url" ]] || die "No release asset matching '$3' in $2"
  log "$1: $url"
  curl -fL --retry 3 -o "$4" "$url"
}

want() { [[ $# -eq 0 || " $* " == *" $TOOL "* ]]; }

ALL=(apktool jadx revanced-cli apkeditor signer)
for TOOL in "${ALL[@]}"; do
  want "$@" || continue
  case "$TOOL" in
    apktool)      fetch apktool iBotPeaches/Apktool '^apktool_.*\.jar$' "$TOOLS_DIR/apktool.jar" ;;
    jadx)
      fetch jadx skylot/jadx '^jadx-[0-9.]+\.zip$' "$TOOLS_DIR/jadx.zip"
      rm -rf "$TOOLS_DIR/jadx" && mkdir -p "$TOOLS_DIR/jadx"
      python3 -m zipfile -e "$TOOLS_DIR/jadx.zip" "$TOOLS_DIR/jadx" && rm "$TOOLS_DIR/jadx.zip"
      chmod +x "$TOOLS_DIR"/jadx/bin/* ;;
    revanced-cli) fetch revanced-cli ReVanced/revanced-cli '^revanced-cli-.*-all\.jar$' "$TOOLS_DIR/revanced-cli.jar" ;;
    apkeditor)    fetch APKEditor REAndroid/APKEditor '^APKEditor-.*\.jar$' "$TOOLS_DIR/APKEditor.jar" ;;
    signer)       fetch uber-apk-signer patrickfav/uber-apk-signer '^uber-apk-signer-.*\.jar$' "$TOOLS_DIR/uber-apk-signer.jar" ;;
  esac
done

log "Done. Optional extras not downloaded here: adb (Android platform-tools), frida-tools (pip install frida-tools)."
