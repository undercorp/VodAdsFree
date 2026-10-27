# Netflix: pause ads

**Status:** analysis method and patch mechanism ready; **no APK has been analysed yet**, so the
concrete methods to patch are still to be found. Everything under "How it most likely works" is
a hypothesis to confirm, written down so the search has a direction. Replace it with findings
as you go.

## What we're looking at

On the ad-supported plan, pausing playback for a few seconds can bring up an ad overlay over the
paused frame (an image or short creative, dismissed when you resume). This is separate from the
ad breaks that play during content; this note is only about the pause overlay.

Two Netflix apps matter:

| Package | Device | UI technology |
|---|---|---|
| `com.netflix.mediaclient` | phones, tablets | native Android (Kotlin/Java) |
| `com.netflix.ninja` | Android TV / Google TV | thin native shell; most of the UI is Netflix's own cross-device UI framework, delivered as script/assets rather than Java |

That second row matters: on TV, the pause-ad logic may live in UI code that isn't Dalvik
bytecode at all, and a ReVanced-style patch can only change bytecode. Start with the mobile app.
For `ninja`, the first job is to find out *whether* any of the logic is in Java; if it isn't,
document that and stop.

## How it most likely works (hypothesis)

Any pause-ad feature needs these four parts. Expect each to be a different class:

1. **Eligibility** - is this profile/plan/region/title eligible, is the feature switched on?
   Plan info and feature flags come from the server; the client reads them into some config
   object. Typically ends in a **boolean**.
2. **Trigger** - the player reports "paused"; a timer starts; if still paused after N seconds and
   nothing else is on screen (episode list, subtitles menu), request an overlay.
3. **Fetch** - ask the ad backend for a pause creative for this session. Returns a model object
   (image URL, click/impression tracking URLs, display duration) or nothing.
4. **Render + report** - show the overlay view, fire impression beacons, hide on resume.

Where to cut, best first (see [docs/workflow.md](../../../docs/workflow.md#3-find-candidates)):

| Cut point | How | Why / risk |
|---|---|---|
| 1. Eligibility gate | force the boolean to `false` | cleanest: the app runs its "no pause ad" path, which is what non-ad plans already do |
| 2. Trigger | make the "start pause-ad timer" method return early | also clean, but timers are sometimes re-armed from several places |
| 3. Fetch | return `null`/empty | the app must already handle "no ad available"; check it does, or it may retry |
| 4. Render | make "show overlay" return early | last resort: the request and maybe beacons still happen |

Don't patch the generic player pause/resume code: every feature uses it.

## Finding it in the mobile app

```bash
scripts/pull-apk.sh netflix com.netflix.mediaclient
scripts/merge-splits.sh samples/netflix/com.netflix.mediaclient-<ver>
scripts/decompile.sh netflix samples/netflix/com.netflix.mediaclient-<ver>/merged.apk
scripts/find-ad-code.sh netflix extracted/netflix/<ver>
```

Netflix is heavily obfuscated (class names like `o/fXz`), so lean on strings. What to look for
in `ad-candidates.txt` and jadx:

- **Literal strings with "pause" and "ad" together** (`keywords.txt` has variants). Log tags,
  analytics/event names, GraphQL operation or field names and JSON keys all survive R8.
- **Layout and resource names**: `extracted/.../apktool/res/layout/` and `res/values/strings.xml`
  for anything like a pause-ad overlay layout or an "Ad" label. A layout's ID
  (`R.layout.xxx` -> an integer in `res/values/public.xml`) leads you to the view code that
  inflates it (search the smali for the hex ID).
- **Feature flags**: Netflix reads experiment/feature config by name. A flag whose name mentions
  pause ads gives you the eligibility gate almost directly - find the method that reads it and
  returns a boolean.
- **The plan/tier**: something like "has ads" on the user/plan model. Don't force *that* off:
  it's used for many things (downloads availability, ad breaks, UI labels) and changes a lot
  more than pause ads. Use it to find callers, then pick the pause-ad-specific one.

Then confirm at runtime: put the candidate descriptors in a file and

```bash
scripts/frida/trace.sh com.netflix.mediaclient candidates.txt --stack
```

Play something on an ad-plan profile, pause, wait for the overlay, resume. The right gate fires
right after pause (or once per session) and returns `true`; the render method fires when the
overlay appears. Write the call order you saw into the findings section below.

## Patching

The patch, **Disable pause ads**, takes the confirmed methods as an option (one descriptor per
line, `= false` to force a boolean). Record them in
`../targets/com.netflix.mediaclient-<ver>.txt` (start from `TEMPLATE.txt`), then:

```bash
VAF_PATCH="Disable pause ads" VAF_TARGETS=services/netflix/targets/com.netflix.mediaclient-<ver>.txt \
  scripts/patch-with-cli.sh samples/netflix/com.netflix.mediaclient-<ver>/merged.apk
```

Why an option instead of a fingerprint: obfuscated names change every release, and a fingerprint
written blind would be guesswork. Once the same string anchors are confirmed on two or three
versions, convert the targets into a proper string-based fingerprint (see
[docs/writing-patches.md](../../../docs/writing-patches.md#matching-on-obfuscated-code)) so
updates need no manual step.

## Things that may get in the way

- **Integrity checks.** Netflix may check its own signature or use Play Integrity; a re-signed
  app might refuse to start or refuse playback. If that happens, note the exact error (logcat)
  here. Working around integrity/DRM checks is out of scope ([docs/scope.md](../../../docs/scope.md)).
- **Server-side fallbacks.** If the eligibility decision is made fully on the server and the
  client only receives "show this creative now", cut point 1 doesn't exist client-side; use 3
  or 4.

## Test checklist

On a profile on the ad-supported plan:

- [ ] Pause for 30 s: no overlay appears
- [ ] Resume: playback continues normally, no black frame or stuck UI
- [ ] Pause/resume repeatedly, and pause during the first minute of a title
- [ ] Regular ad breaks still behave as before (this patch must not touch them)
- [ ] Subtitles/audio menus, episode list and "skip intro" still work while paused
- [ ] No new crashes: `adb logcat -b crash`

## Findings

_Nothing yet. Template:_

### `com.netflix.mediaclient` <version> - <date>

- Anchors found: ...
- Call order observed (Frida): pause -> ... -> overlay shown
- Chosen targets: see `../targets/...txt`
- Checklist result: ...
