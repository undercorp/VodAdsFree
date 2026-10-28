# HBO Max - client-side ad strategy and ad skip (incl. Fire TV)

| | |
|---|---|
| Package | `com.wbd.stream` (Play: phones, Android TV - Amazon Appstore: Fire tablets, Fire TV) |
| Patches | **Disable client-side ad strategy** - player treats streams as ad-free (no break schedule, ad UI or beacons) |
| | **Allow seeking past ads** - removes the snap-back to unwatched ad breaks |
| Status | Patch mechanism ready; **per-version targets not yet found** (no APK analysed) |
| Analysis | [analysis/ad-strategy.md](analysis/ad-strategy.md), [analysis/fire-tv-ad-skip.md](analysis/fire-tv-ad-skip.md) |

## Layout

```
analysis/        ad strategy model, snap-back guard, Fire TV notes, checklists
patches/         ReVanced patches (Kotlin), option-driven
targets/         confirmed descriptors per version: <pkg>-<ver>.ad-strategy.txt / .ad-skip.txt
scripts/         patch-hbomax.sh - applies both patches from the targets files
```

## What to expect

HBO Max's ads are believed to be stitched into the stream on the server (SSAI; see the analysis).
Client patches can stop the app from *treating* them as ads (no countdown, no locked seeking, no
snap-back), which lets you skip them, but can't cut frames out of the stream. Automatic skipping
is planned once the break model is mapped - see "Auto-skip" in the Fire TV note.

Both patches are disabled by default and need targets, because the app is obfuscated.

## Build and use

```bash
# 1. Get the APK. For Fire TV, pull from the Fire TV itself (Appstore build):
adb connect <fire-tv-ip>:5555
scripts/pull-apk.sh hbomax
scripts/merge-splits.sh samples/hbomax/com.wbd.stream-<ver>
scripts/decompile.sh hbomax samples/hbomax/com.wbd.stream-<ver>/merged.apk

# 2. Find candidates, confirm with Frida, write the targets files (start from targets/TEMPLATE.txt)
scripts/find-ad-code.sh hbomax extracted/hbomax/<ver>
scripts/frida/trace.sh com.wbd.stream my-candidates.txt --stack

# 3. Build the bundle once (see top-level README), then patch with both targets files
./gradlew build
services/hbomax/scripts/patch-hbomax.sh samples/hbomax/com.wbd.stream-<ver>/merged.apk \
  services/hbomax/targets/com.wbd.stream-<ver>

# 4. Install (works over adb connect for Fire TV) and run the checklists
scripts/install-apk.sh out/merged-patched.apk --replace com.wbd.stream
```

On Fire TV, decline the Amazon Appstore's offer to update the app afterwards, or it will replace
the patched build.
