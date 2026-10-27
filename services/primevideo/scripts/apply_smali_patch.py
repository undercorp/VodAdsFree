#!/usr/bin/env python3
"""Applies the Prime Video "skip ads" change to an apktool-decoded app, in place.

    python3 -I apply_smali_patch.py <apktool-dir>

What it does (same as the ReVanced patch, done with text edits on smali):
  1. Finds ServerInsertedAdBreakState.smali in any smali*/ folder.
  2. Appends the vafSkipAdBreak helper from ../smali/SkipAdBreak.smali.
  3. In enter(Lcom/amazon/avod/fsm/Trigger;)V, right after
         invoke-virtual {...}, ...->getPrimaryPlayer()...
         move-result-object vX
     inserts a call to the helper and returns, so no ad clip is ever queued.
Running it twice is a no-op.
"""
import pathlib
import re
import sys

CLASS_PATH = "com/amazon/avod/media/ads/internal/state/ServerInsertedAdBreakState.smali"
STATE = "Lcom/amazon/avod/media/ads/internal/state/ServerInsertedAdBreakState;"
TRIGGER = "Lcom/amazon/avod/media/ads/internal/state/AdBreakTrigger;"
PLAYER = "Lcom/amazon/avod/media/playback/VideoPlayer;"
MARKER = "# VodAdsFree: skip ads"
HELPER = pathlib.Path(__file__).resolve().parent.parent / "smali" / "SkipAdBreak.smali"


def fail(msg):
    sys.exit(f"error: {msg}")


def main():
    if len(sys.argv) != 2:
        fail(__doc__)
    root = pathlib.Path(sys.argv[1])
    candidates = sorted(root.glob(f"smali*/{CLASS_PATH}"))
    if not candidates:
        fail(f"{CLASS_PATH} not found under {root}/smali*/ (is this Prime Video, decoded with apktool?)")
    target = candidates[0]
    src = target.read_text(encoding="utf-8")

    if MARKER in src:
        print(f"already patched: {target}")
        return

    # Locate enter(Trigger)V.
    m = re.search(r"^\.method public (?:final )?enter\(Lcom/amazon/avod/fsm/Trigger;\)V$(.*?)^\.end method$",
                  src, re.S | re.M)
    if not m:
        fail("enter(Lcom/amazon/avod/fsm/Trigger;)V not found; the app changed, re-run the analysis")
    body = m.group(1)

    call = re.search(r"^\s*invoke-virtual \{[^}]*\}, [^\n]*->getPrimaryPlayer\(\)[^\n]*\n"
                     r"(?:\s*\n|\s*\.line [^\n]*\n)*"
                     r"\s*move-result-object (?P<reg>[vp]\d+)\n", body, re.M)
    if not call:
        fail("getPrimaryPlayer() + move-result-object not found in enter(); re-run the analysis")
    reg = call.group("reg")

    hook = (f"\n    {MARKER}\n"
            f"    check-cast p1, {TRIGGER}\n"
            f"    invoke-static {{p0, p1, {reg}}}, {STATE}->vafSkipAdBreak({STATE}{TRIGGER}{PLAYER})V\n"
            f"    return-void\n\n")
    new_body = body[:call.end()] + hook + body[call.end():]
    src = src[:m.start(1)] + new_body + src[m.end(1):]

    helper = HELPER.read_text(encoding="utf-8")
    helper = "\n".join(l for l in helper.splitlines() if not l.startswith("#"))
    src = src.rstrip("\n") + "\n\n" + helper.strip() + "\n"

    target.write_text(src, encoding="utf-8")
    print(f"patched: {target} (player register {reg})")


if __name__ == "__main__":
    main()
