#!/usr/bin/env bash
# Approach A: official ReVanced patches.
# Uses the "Skip ads" patch from the upstream ReVanced Patches bundle. Easiest and best maintained,
# but you get whatever version upstream supports (check with list-patches).
#
#   services/primevideo/scripts/patch-upstream-revanced.sh <primevideo.apk>
#
# The bundle is downloaded from GitHub, falling back to the GitLab mirror (the GitHub repo was
# temporarily taken down in 2026 after a DMCA notice; see github.com/ReVanced/where-is-revanced-patches).
source "$(dirname "$0")/../../../scripts/lib/common.sh"
cli="$(need_jar revanced-cli.jar)"
apk="${1:?usage: patch-upstream-revanced.sh <apk>}"
bundle="$TOOLS_DIR/revanced-patches.rvp"

if [[ ! -f "$bundle" ]]; then
  url="$(curl -fsSL https://api.github.com/repos/ReVanced/revanced-patches/releases/latest 2>/dev/null |
    python3 -c 'import json,sys
for a in json.load(sys.stdin).get("assets", []):
    if a["name"].endswith(".rvp"): print(a["browser_download_url"]); break' 2>/dev/null || true)"
  if [[ -z "$url" ]]; then
    log "GitHub unavailable, trying the GitLab mirror"
    url="$(curl -fsSL "https://gitlab.com/api/v4/projects/ReVanced%2Frevanced-patches/releases/permalink/latest" |
      python3 -c 'import json,sys
for l in json.load(sys.stdin)["assets"]["links"]:
    if l["name"].endswith(".rvp"): print(l["direct_asset_url"] if "direct_asset_url" in l else l["url"]); break')"
  fi
  [[ -n "$url" ]] || die "Could not find a ReVanced patches release. Download the .rvp manually to $bundle"
  log "Downloading $url"
  curl -fL -o "$bundle" "$url"
fi

mkdir -p "$OUT_DIR"
out="$OUT_DIR/primevideo-upstream-patched.apk"
# --exclusive: only the patch we want, nothing else from the big upstream bundle.
# -b: skip PGP/provenance verification (pass -k/-s/-a/-r instead to verify; see ReVanced CLI docs).
java -jar "$cli" patch -bp "$bundle" --exclusive -e "Skip ads" -o "$out" "$apk"
log "Done: $out"
