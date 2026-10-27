#!/usr/bin/env bash
# Runs scripts/frida/trace-methods.js against an app, with targets from a file (same format as
# services/*/targets/*.txt: one descriptor or class name per line, '#' comments, "= value" ignored).
#
#   scripts/frida/trace.sh <package> <targets-file> [--stack]
#
# Needs frida-tools on this machine and frida-server running (as root) on the device.
source "$(dirname "$0")/../lib/common.sh"
need frida "pip install frida-tools"
pkg="${1:?usage: trace.sh <package> <targets-file> [--stack]}"
file="${2:?usage: trace.sh <package> <targets-file> [--stack]}"
stack=false; [[ "${3:-}" == "--stack" ]] && stack=true

json="$(grep -v '^\s*#' "$file" | sed '/^\s*$/d; s/\s*=.*$//' |
  python3 -c 'import json,sys; print(json.dumps({"targets":[l.strip() for l in sys.stdin], "stack": sys.argv[1]=="true"}))' "$stack")"
log "Tracing $pkg with $json"
exec frida -U -f "$pkg" -l "$REPO_ROOT/scripts/frida/trace-methods.js" -P "$json"
