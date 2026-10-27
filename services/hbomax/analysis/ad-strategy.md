# HBO Max: client-side ad strategy

**Status:** analysis method and patch mechanism ready; **no APK has been analysed yet**. The
architecture below is the working hypothesis, based on how ad-supported streaming players are
generally built and on what's publicly known about HBO Max. Confirm or correct each point and
log it in the findings section.

Companion note: [fire-tv-ad-skip.md](fire-tv-ad-skip.md) (seeking past ads, Fire TV specifics).

## Background

HBO Max's Android app is the former **Max** app (renamed back to HBO Max in 2025), package
`com.wbd.stream`. It's built on Warner Bros. Discovery's shared streaming platform, the same
lineage as discovery+. The same package is distributed through Google Play (phones, Android TV)
and the Amazon Appstore (Fire tablets, Fire TV), with the Amazon builds sometimes on a different
version number.

## How ads probably reach the screen

Ad-supported streaming players generally use one of two models:

- **CSAI (client-side ad insertion)**: the player pauses content, fetches ads itself (VAST/VMAP,
  often through Google IMA or FreeWheel), plays them in a separate player, then resumes.
- **SSAI (server-side ad insertion)**: the server stitches ads into the content stream. The
  player gets the stream *plus* a timeline of where the ad breaks are, and uses it to show ad UI,
  send tracking beacons, and enforce rules (no skipping).

Industry coverage of HBO Max describes it as SSAI. So the hypothesis is:

1. The playback request returns stream URLs **and an ad description**: an ad mode/strategy
   (SSAI, CSAI, none) and a list of ad breaks (start, duration, tracking URLs, watched state).
2. The client picks an **ad strategy** implementation from that: an object that receives player
   position updates and decides "we're in a break now" -> show countdown, lock controls, fire
   beacons, mark break watched.
3. A **seek guard** uses the same break list to snap you back to an unwatched break you seeked
   over (details in the Fire TV note).

The interesting consequence: with SSAI, the ad frames are in the stream. A client patch can't
cut them out, but if the client believes there are *no* breaks, the stream just plays straight
through them as if they were content - no countdown, no locked controls, and seeking works, so
you can jump past them. That's the realistic target for "disable the client-side ad strategy".
For actual automatic skipping, see the Fire TV note.

## Where to cut

| Cut point | Effect | Notes |
|---|---|---|
| Strategy selection -> "no ads" | client runs its ad-free code path | best, if a selector with a "none" case exists (ad-free plans must take that path) |
| Ad break list -> empty | strategy has nothing to act on | robust; same idea as the Disney+ patch |
| Strategy's "on position update / enter break" -> return | breaks never "start" | ok, but other components may still read the list (e.g. seek guard) |
| Ad UI -> hidden | cosmetic only | last resort |

The ad-free plan is the reference: find the code path that runs when the account has no ads.
Wherever that diverges from the ad-plan path is the cleanest gate.

## Finding it

```bash
scripts/pull-apk.sh hbomax
scripts/merge-splits.sh samples/hbomax/com.wbd.stream-<ver>
scripts/decompile.sh hbomax samples/hbomax/com.wbd.stream-<ver>/merged.apk
scripts/find-ad-code.sh hbomax extracted/hbomax/<ver>
```

What to look for:

- **Strings for ad modes**: `ssai`, `csai`, enum-like names, JSON keys in the playback response
  model (the app parses JSON; parser code keeps the key strings even when obfuscated).
- **Third-party ad SDKs**: Google IMA (`com/google/ads/interactivemedia`), FreeWheel, Yospace
  and similar SSAI SDKs keep their own package names. If one is present, the app's glue code
  calling into it is the strategy. If none is present, the strategy is in-house.
- **Kotlin metadata**: R8 often leaves `toString()` strings like `"AdBreak(start=..., duration="`
  on data classes. Search for `(start=` / `duration=` / `watched=`: they name fields of the
  break model and lead you to its users.
- **An enum/sealed class with a "none"/"no ads" case** near the playback-response parser.

Confirm with `scripts/frida/trace.sh com.wbd.stream candidates.txt --stack`: start a title on an
ad plan; the strategy selector runs once per playback, break-list getters run at start and on
seek, and "enter break" fires as the countdown appears.

## Patching

**Disable client-side ad strategy** takes the confirmed methods as an option. Typical targets:

```
# selector: "does this playback use client ad handling?"   -> force off
Lxx/yy;->a(Lxx/PlaybackInfo;)Z = false
# break list getter                                          -> empty list
Lxx/zz;->getAdBreaks()Ljava/util/List;
```

Save them in `../targets/com.wbd.stream-<ver>.ad-strategy.txt` and see `../README.md`.

## Test checklist (ad-supported account)

- [ ] Start a title: no ad countdown/badge at pre-roll (ad frames may still play as content - expected with SSAI)
- [ ] Seek bar works everywhere, including across former ad positions
- [ ] No snap-back after seeking (if it still happens, also apply the ad-skip patch)
- [ ] Playback, subtitles, next-episode autoplay work normally
- [ ] Ad-free account (if available): nothing changes
- [ ] No new crashes: `adb logcat -b crash`

## Findings

_Nothing yet. Template:_

### `com.wbd.stream` <version> (Play / Appstore) - <date>

- Ad SDKs present: ...
- Ad modes seen in the playback model: ...
- Strategy selector / break list: ...
- Checklist result: ...
