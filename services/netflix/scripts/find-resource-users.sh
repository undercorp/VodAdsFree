#!/usr/bin/env bash
# Follows Android resources (layouts, strings, ids) whose names match a regex to the smali code
# that uses them. In an obfuscated app this is often the fastest way from "there is a pause-ad
# layout" to "this class inflates it".
#
#   services/netflix/scripts/find-resource-users.sh <extracted-dir> [name-regex]
#
# Default regex: pause.*ad|ad.*pause
source "$(dirname "$0")/../../../scripts/lib/common.sh"
dir="${1:?usage: find-resource-users.sh <extracted-dir> [name-regex]}"
regex="${2:-pause.*ad|ad.*pause}"
public="$dir/apktool/res/values/public.xml"
[[ -f "$public" ]] || die "$public not found; decode with scripts/decompile.sh (apktool, resources on)"

grep -i -E "name=\"[^\"]*($regex)[^\"]*\"" "$public" |
  sed -n 's/.*type="\([^"]*\)" name="\([^"]*\)" id="\(0x[0-9a-f]*\)".*/\1 \2 \3/p' |
  while read -r type name id; do
    echo "== $type/$name ($id)"
    # apktool smali references resource IDs as literals (const v0, 0x7f0b0123); R8 strips R classes.
    grep -rl --include='*.smali' -E "(const(/high16)?|const) [vp][0-9]+, $id\b" "$dir/apktool" 2>/dev/null |
      sed "s|$dir/apktool/||; s|^|   used in |" | head -10 || echo "   (no direct smali references)"
  done
