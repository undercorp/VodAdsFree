#!/usr/bin/env bash
# Applies both HBO Max patches with the targets files for one app version.
#
#   services/hbomax/scripts/patch-hbomax.sh <apk> <targets-prefix>
#
# <targets-prefix> is e.g. services/hbomax/targets/com.wbd.stream-5.10.0 ; the script uses
# <prefix>.ad-strategy.txt and/or <prefix>.ad-skip.txt, whichever exist.
source "$(dirname "$0")/../../../scripts/lib/common.sh"
apk="${1:?usage: patch-hbomax.sh <apk> <targets-prefix>}"
prefix="${2:?usage: patch-hbomax.sh <apk> <targets-prefix>}"

to_list() { grep -v '^\s*#' "$1" | sed '/^\s*$/d; s/,/\\,/g' | paste -sd, -; }

args=(--exclusive)
if [[ -f "$prefix.ad-strategy.txt" ]]; then
  args+=(-e "Disable client-side ad strategy" "-OTarget methods=[$(to_list "$prefix.ad-strategy.txt")]")
fi
if [[ -f "$prefix.ad-skip.txt" ]]; then
  args+=(-e "Allow seeking past ads" "-OTarget methods=[$(to_list "$prefix.ad-skip.txt")]")
fi
[[ ${#args[@]} -gt 1 ]] || die "Neither $prefix.ad-strategy.txt nor $prefix.ad-skip.txt exists"

exec "$REPO_ROOT/scripts/patch-with-cli.sh" "$apk" "${args[@]}"
