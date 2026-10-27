#!/usr/bin/env bash
# Approach B: this repo's ReVanced patch (services/primevideo/patches).
# Same idea as upstream but pure smali (no extension DEX), so it is easy to read and tweak.
#
#   services/primevideo/scripts/patch-vodadsfree.sh <primevideo.apk>
#
# Build the bundle first: ./gradlew build   (see the top-level README)
here="$(dirname "$0")"
exec "$here/../../../scripts/patch-with-cli.sh" "$1" --exclusive -e "Skip ads" "${@:2}"
