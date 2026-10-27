# Disney+: the client-side ad pipeline

**Status:** patch implemented. The target (`com.dss.sdk.internal.media.Insertion`) is the one used
by upstream ReVanced's Disney+ "Skip ads" patch; the class lives in Disney's own playback SDK and
is not obfuscated, so the patch isn't pinned to a version. Verify with the checklist below.

## The short version

When you press play, Disney+ asks its backend for a playback "scenario". Alongside the stream
URLs, the answer describes the ads for that session: **where** in the timeline ad pods go
(*insertion points*) and **which spans** of the timeline are ads (*insertion ranges*). The
player builds everything ad-related from those two lists: it fetches and splices in ad pods,
draws the ad countdown/badge, locks seeking during ads and sends ad beacons.

The patch makes both lists come back empty. To the player, that looks exactly like a title with
no ads - a normal, well-tested case - so the whole pipeline simply doesn't start.

## Where the code lives

Disney+ is built on the **DSS SDK** (Disney Streaming Services, ex-BAMTech), under
`com.dss.sdk.*`. The app's own code is obfuscated, but the SDK keeps its names, which is what
makes a version-independent patch possible.

`com.dss.sdk.internal.media.Insertion` is the parsed "ads for this playback" object:

| Method | Returns | Meaning |
|---|---|---|
| `getPoints()` | `List<...>` | insertion points: timeline positions where an ad pod should be played, with pod metadata |
| `getRanges()` | `List<...>` | insertion ranges: spans of the timeline that are ad content |

Everything downstream (the ad scheduler, the timeline UI, beacons) iterates these lists.

## The change

At index 0 of both getters we insert:

```smali
new-instance v0, Ljava/util/ArrayList;
invoke-direct {v0}, Ljava/util/ArrayList;-><init>()V
return-object v0
```

We return an **empty list**, not `null`: callers iterate the result and a `null` would crash
them. That's what `returnEarly()` does for `List` return types (`services/_shared`).

## What can and can't be disabled client-side

| Thing | Client-side? | Result with the patch |
|---|---|---|
| Ad pods spliced in by the player (insertion points) | yes | not fetched, not played |
| Ad UI (countdown, "Ad" badge, ad markers) | yes | not shown (no ranges to draw) |
| Seek lock during ads | yes | gone (no ranges to protect) |
| Ad beacons/impressions | yes (driven by the same lists) | not sent |
| Ads already **baked into the stream** by the server | **no** | if a title/region serves those, they would play as if they were content, but without ad UI and with seeking unlocked, so you can skip manually |

The last row is the important caveat. The patch works by making the player unaware of ads; if
the server ever stitches ads into the main stream instead of having the player insert them,
the patch can't remove those frames. A follow-up patch could use the *original* ranges to seek
over them (like the Prime Video patch does). If you see ads play with no badge after patching,
that's what's happening - note the title and region in the findings log.

## Re-verifying on a new version

```bash
scripts/decompile.sh disneyplus samples/disneyplus/<ver>/merged.apk
scripts/find-ad-code.sh disneyplus extracted/disneyplus/<ver>
```

- [ ] `Lcom/dss/sdk/internal/media/Insertion;` still exists, with `getPoints` and `getRanges`
      returning `Ljava/util/List;`
- [ ] Optional, with Frida: `frida -U -f com.disney.disneyplus -l services/disneyplus/scripts/frida-insertions.js`
      and start an ad-tier title. You should see non-empty lists. Re-run with
      `-P '{"block":true}'` to preview the patch's effect without re-signing.

On device (ad-supported Disney+ account):

- [ ] Movie start: no pre-roll
- [ ] Episode with mid-rolls: plays straight through, no "Ad" badge or countdown
- [ ] Seeking anywhere works
- [ ] Playback doesn't stall or error at former ad positions
- [ ] Live/linear content (if you use it) still plays (it may use a different path; note it)

## Ideas not yet explored

- Live streams and ESPN content inside Disney+ may use a different insertion path. Search for
  other users of `Insertion` in jadx.
- The ad-tier "pause ad" style overlays, if Disney+ ships them, would be a separate UI path.

## Findings log

| Date | Version | Region | Result | Notes |
|---|---|---|---|---|
| | | | | |
