# Prime Video: how ads work and how we skip them

**Status:** patch implemented. The target code was identified by the upstream ReVanced "Skip ads"
patch (verified there on `com.amazon.avod.thirdpartyclient` 3.0.412.2947); this repo re-implements
it in plain smali. Re-verify on each new version with the checklist at the bottom.

## The short version

Prime Video's ads are **server-inserted**: the ad clips are part of the same stream as the show.
The app knows where each ad break starts and how long it is, and its player is a **state
machine**. When playback reaches a break, the player moves into an "ad break" state that plays
the clips and locks the controls. We replace what that state does on entry: instead of playing
the ads, it seeks to the end of the break and tells the state machine "no more ads".

Because the ads are in the stream, we can't *delete* them; we jump over them. You may see a
frame or two of the ad before the seek lands.

## How the player is built

Prime Video's code is not obfuscated, which makes it unusually readable.

- `com.amazon.avod.fsm.*` is a small generic finite-state-machine library: `StateBase` (a state
  with `enter`/`exit`), `Trigger` (an event), `SimpleTrigger` (an event carrying just a type),
  and `doTrigger(trigger)` (fire an event from inside a state).
- `com.amazon.avod.media.ads.internal.state.*` are the ad-related states of the playback FSM.
  `ServerInsertedAdBreakState` is the one used for ads stitched into the stream.
- `AdBreakTrigger` is the event that moves the player into an ad break. It carries:
  - `getBreak()` - the `AdBreak`, whose `getDurationExcludingAux()` is the length of the ad
    clips (excluding "aux" content like bumpers - we want to skip exactly the ads);
  - `getSeekStartPosition()` / `getSeekTarget()` - set when the break was hit because the
    **user seeked across it**. Prime forces you to watch the break you jumped over before
    continuing at your target.
- `AdEnabledPlayerTriggerType.NO_MORE_ADS_SKIP_TRANSITION` is the event the FSM already uses to
  leave ad state when there's nothing left to play.

So the "what happens at an ad break" logic all goes through one method:
`ServerInsertedAdBreakState.enter(Trigger)`. That's the chokepoint.

## The change

In `enter()`, right after the method fetches the video player (`getPrimaryPlayer()`), we call
our own helper and return before any ad clip is queued. The helper:

1. If the user seeked across the break (`getSeekStartPosition() != null`) - seek to
   `getSeekTarget()`, i.e. where they wanted to go.
2. Otherwise playback ran into the break naturally - seek to
   `currentPosition + break.getDurationExcludingAux()`.
3. Fire `NO_MORE_ADS_SKIP_TRANSITION` with `doTrigger()` so the FSM leaves ad state (otherwise
   controls stay locked and the ad UI stays up).
4. If anything throws (a method was renamed in a new version), log `VodAdsFree` to logcat and
   return: the ad plays, the app does not crash.

The helper is a new `private static` method added to `ServerInsertedAdBreakState` itself. Two
reasons: it can call the `protected` `doTrigger()` without changing access flags (upstream's
version makes `doTrigger` public so its Java extension can call it), and it has its own
registers, so we don't need to know which registers in `enter()` are free.

Same logic, four packagings (see `../README.md`): upstream ReVanced patch, this repo's ReVanced
patch, an apktool smali edit, and a Frida hook.

## What this does *not* do

- **Ad markers / "Ad" badge on the timeline** stay - they come from the same break metadata, but
  hiding them is cosmetic and not implemented.
- **Pre-roll** behaves like any other break: the seek happens once the player is ready, so the
  first second can flash.
- **Ad tracking**: since the break's state never runs, the clip-level playback events it would
  report aren't sent. Whether the server notices is unknown and not something we test.
- **Other apps**: Fire TV's built-in Prime Video (`com.amazon.firebat`) is a system app and can't
  be replaced without root. The Android TV app (`com.amazon.amazonvideo.livingroom`) is a
  different build; it's listed in `scripts/lib/common.sh` for pulling, but nobody has checked
  whether it shares this code. Run `scripts/find-ad-code.sh primevideo ...` on it and record the
  result here.

## Re-verifying on a new version

```bash
scripts/decompile.sh primevideo samples/primevideo/<ver>/merged.apk --no-jadx
scripts/find-ad-code.sh primevideo extracted/primevideo/<ver>
```

Check in `ad-candidates.txt` / the smali:

- [ ] `ServerInsertedAdBreakState` still has `enter(Lcom/amazon/avod/fsm/Trigger;)V`
- [ ] `enter()` still calls `getPrimaryPlayer()` followed by `move-result-object`
- [ ] `AdBreakTrigger` still has `getBreak`, `getSeekStartPosition`, `getSeekTarget`
- [ ] `AdEnabledPlayerTriggerType` still has `NO_MORE_ADS_SKIP_TRANSITION`
- [ ] `VideoPlayer` is still an interface with `getCurrentPosition()J` and `seekTo(J)V`

On device (ad-supported Prime account):

- [ ] Start an episode from the beginning: pre-roll is skipped (at most a brief flash)
- [ ] Let it play into a mid-roll: playback continues right after the break
- [ ] Seek across an unwatched break: you land where you seeked, not in the break
- [ ] Controls work right after each skip (pause, seek, subtitles)
- [ ] `adb logcat -s VodAdsFree` shows no "failed to skip" warnings
- [ ] Record the version and result in `../targets/`

## Findings log

| Date | Version | Approach | Result | Notes |
|---|---|---|---|---|
| (upstream) | 3.0.412.2947 | ReVanced "Skip ads" | works | fingerprints from upstream ReVanced |
