#!/usr/bin/env bash
# Greps a decompiled app for ad-related code and prints candidate methods as smali descriptors,
# ready to paste into a patch option or analysis notes.
#
#   scripts/find-ad-code.sh <service> <extracted-dir> [extra-regex]
#
# Keyword lists live in services/<service>/analysis/keywords.txt (one regex per line). Matches on
# string constants are the most useful in obfuscated apps: class names change, log tags and JSON
# keys don't.
source "$(dirname "$0")/lib/common.sh"
svc="${1:?usage: find-ad-code.sh <service> <extracted-dir> [extra-regex]}"; check_service "$svc"
dir="${2:?usage: find-ad-code.sh <service> <extracted-dir>}"
smali_root="$dir/apktool"; [[ -d "$smali_root" ]] || die "$smali_root missing; run scripts/decompile.sh first"

kw_file="$REPO_ROOT/services/$svc/analysis/keywords.txt"
patterns="$(grep -v '^\s*#' "$kw_file" | grep -v '^\s*$' | paste -sd'|')"
[[ -n "${3:-}" ]] && patterns="$patterns|$3"
report="$dir/ad-candidates.txt"

log "Searching smali for: $patterns"
# For each matching line, report the enclosing method as Lclass;->method(sig)ret plus the hit.
find "$smali_root" -path '*/smali*' -name '*.smali' -print0 |
  xargs -0 grep -H -n -i -E "$patterns" 2>/dev/null |
  python3 -c '
import re, sys, collections
hits = collections.OrderedDict()
cache = {}
for line in sys.stdin:
    path, lineno, text = line.split(":", 2)
    if path not in cache:
        with open(path, encoding="utf-8", errors="replace") as f:
            cache.clear(); cache[path] = f.read().splitlines()
    lines = cache[path]
    cls = next((l.split()[-1] for l in lines if l.startswith(".class")), "?")
    method = None
    for i in range(int(lineno) - 1, -1, -1):
        if lines[i].startswith(".method"):
            method = lines[i].split()[-1]; break
        if lines[i].startswith(".end method"):
            break
    key = cls + ("->" + method if method else " (field/class level)")
    hits.setdefault(key, []).append(text.strip()[:140])
for key, texts in hits.items():
    print(key)
    for t in texts[:5]:
        print("    " + t)
    if len(texts) > 5:
        print("    ... %d more" % (len(texts) - 5))
' | tee "$report"
log "Saved to $report ($(grep -c '^L' "$report" || true) methods)."
