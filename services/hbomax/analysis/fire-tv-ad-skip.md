# HBO Max: seeking past ads, and Fire TV

**Status:** hypothesis + method; no APK analysed yet. Read [ad-strategy.md](ad-strategy.md)
first - this note builds on its model of breaks and strategies.

## The behaviour we want to change

On the ad-supported plan, if you seek forward over an ad break you haven't watched, the player
jumps you **back to the start of that break** ("snap-back"), plays it, then (often) continues at
the point you wanted. On a phone that's an annoyance; on **Fire TV** it's worse, because seeking
with the remote's D-pad or fast-forward happens in many small steps - each step that crosses a
break can trigger the guard, and coarse scrubbing makes it hard to land just after a break.

## How a snap-back guard works

Every implementation needs the same pieces, so this is what to look for:

1. A seek request arrives (from the seek bar, D-pad, or media key) with a target position.
2. The guard looks up ad breaks between the current position and the target.
3. If any of them is **not marked watched**, it replaces the target with that break's start and
   remembers the original target ("resume position after ad").
4. When the break finishes, it seeks to the remembered target and marks the break watched.

So there are three cut points:

| Cut point | Patch | Effect |
|---|---|---|
| "Should snap back?" check (step 2/3) | force `false` | seeks go where you asked; ads you didn't skip still play |
| "Is break watched?" | force `true` | same effect, but may also suppress ad UI/beacons for breaks; can confuse resume logic |
| Seek target rewrite | return the original target | works, but harder to patch cleanly mid-method |

The first is the target for **Allow seeking past ads**. Combined with the ad-strategy patch, the
player has no breaks at all and the guard has nothing to do; on its own it's the minimal change.

## Auto-skip (future work)

Allowing seeks still means *you* have to skip each break. Automatic skipping needs the Prime
Video approach: hook "entering a break" and seek to `breakStart + breakDuration`. That's only
possible once we know the break model (start/duration fields) and the "enter break" callback from
the analysis. Then it's a fixed-fingerprint or option-driven patch shaped like
`services/primevideo/patches` - see its `SkipAdsPatch.kt` for the pattern (new static helper +
one call). Track progress in the findings below.

## Fire TV specifics

- **Which APK**: Fire TV installs the Amazon Appstore build of `com.wbd.stream`. Pull it from
  the Fire TV itself so you analyse what actually runs there:
  ```bash
  adb connect <fire-tv-ip>:5555            # Settings > My Fire TV > Developer options > ADB debugging
  scripts/pull-apk.sh hbomax
  ```
  Its version may differ from the Play build, so it gets its own targets files.
- **Different input path**: on TV, seeks come from key events (D-pad left/right, FF/RW media
  keys) through the TV/leanback player controls, not the touch seek bar. Make sure the guard
  you patch is shared by both paths: trace while seeking with the remote, not just on a phone.
  If the TV controls have their own guard, it needs its own target line.
- **Install**: `scripts/install-apk.sh out/<patched>.apk --replace` works over `adb connect`.
  Amazon Appstore will offer to "update" the app later; decline, or it'll replace the patched one.
- **Logs**: `adb logcat -s VodAdsFree:* AndroidRuntime:E` works the same over network ADB.

## Finding it

After `find-ad-code.sh hbomax ...`, look for:

- Strings with `snap`, `resume`, `watched` near the break model's users.
- Methods taking (current position, target position) as two `long`s (`(JJ)`) and returning a
  `long` or `boolean`, in classes that also reference the break list.
- Analytics events for seeking during ads.

Then trace while seeking across a break on the TV:

```bash
scripts/frida/trace.sh com.wbd.stream candidates.txt --stack
```

The guard fires on each seek; on a seek across an unwatched break it returns `true` (or a
changed position).

## Test checklist (Fire TV, ad-supported account)

- [ ] Seek forward across an unwatched break with the D-pad: you land past it
- [ ] Same with FF/RW media keys, and with the on-screen seek bar
- [ ] Same on a phone build if you patched one
- [ ] Breaks you don't seek over still behave as before (patch scope is only the guard)
- [ ] After seeking, "continue watching" resumes at the right position later
- [ ] No new crashes

## Findings

_Nothing yet._
