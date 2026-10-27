#!/usr/bin/env bash
# Patches an APK with ReVanced CLI using this repo's patch bundle (or any .rvp you pass).
#
#   scripts/patch-with-cli.sh <apk> [cli args...]
#
# Examples:
#   scripts/patch-with-cli.sh samples/disneyplus/disney.apk
#   scripts/patch-with-cli.sh nf.apk -e "Disable pause ads" -O"Target methods=[...]"   # see services/netflix/README.md
#   VAF_BUNDLE=~/Downloads/patches.rvp scripts/patch-with-cli.sh pv.apk
#
# For the option-driven patches (Netflix, HBO Max) you can pass a targets file instead of typing -O:
#   VAF_PATCH="Disable pause ads" VAF_TARGETS=services/netflix/targets/9.90.0.txt \
#     scripts/patch-with-cli.sh samples/netflix/netflix-9.90.0.apk
#
# The bundle defaults to the newest patches/build/libs/*.rvp (build it with ./gradlew build).
source "$(dirname "$0")/lib/common.sh"
cli="$(need_jar revanced-cli.jar)"
apk="${1:?usage: patch-with-cli.sh <apk> [cli args...]}"; shift
bundle="${VAF_BUNDLE:-$(ls -t "$REPO_ROOT"/patches/build/libs/*.rvp 2>/dev/null | head -1)}"
[[ -f "$bundle" ]] || die "No patch bundle. Run ./gradlew build (see README) or set VAF_BUNDLE."

mkdir -p "$OUT_DIR"
out="$OUT_DIR/$(basename "${apk%.apk}")-patched.apk"
ks_args=()
[[ -n "${VAF_KEYSTORE:-}" ]] && ks_args=(--keystore "$VAF_KEYSTORE")

extra=()
if [[ -n "${VAF_TARGETS:-}" ]]; then
  [[ -n "${VAF_PATCH:-}" ]] || die "VAF_TARGETS needs VAF_PATCH (the patch name to enable)"
  # One descriptor per line; comments/blank lines dropped; commas escaped for the CLI list parser.
  list="$(grep -v '^\s*#' "$VAF_TARGETS" | sed '/^\s*$/d; s/,/\\,/g' | paste -sd, -)"
  [[ -n "$list" ]] || die "$VAF_TARGETS has no targets"
  extra=(-e "$VAF_PATCH" "-OTarget methods=[$list]")
fi

log "Patches available in $bundle:"
# -b bypasses PGP/provenance verification: a locally built bundle is not signed.
java -jar "$cli" list-patches --packages --versions --options -bp "$bundle" >&2 || true

java -jar "$cli" patch -bp "$bundle" "${ks_args[@]}" -o "$out" "${extra[@]}" "$@" "$apk"
log "Patched APK: $out"
