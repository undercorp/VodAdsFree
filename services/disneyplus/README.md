# Disney+ - Disable ad pipeline

| | |
|---|---|
| Package | `com.disney.disneyplus` (phones, tablets, Android TV, Fire TV) |
| Patch | **Disable ad pipeline** - empties the ad insertion points/ranges so the player never schedules ads |
| Status | Implemented; not version-pinned (DSS SDK names are stable) |
| Analysis | [analysis/ad-pipeline.md](analysis/ad-pipeline.md) |

## Layout

```
analysis/        how the ad pipeline works, what's client-side, checklist, findings log
patches/         ReVanced patch (Kotlin)
scripts/         frida-insertions.js - log or block the ad lists at runtime
targets/         record of tested versions
```

## Build and use

```bash
# 1. Get the APK (from your device) and merge splits
scripts/pull-apk.sh disneyplus
scripts/merge-splits.sh samples/disneyplus/com.disney.disneyplus-<ver>

# 2. Build the bundle once (see top-level README for the GitHub token)
./gradlew build

# 3. Patch
scripts/patch-with-cli.sh samples/disneyplus/com.disney.disneyplus-<ver>/merged.apk \
  --exclusive -e "Disable ad pipeline"

# 4. Install (removes the store version and its data first) and test
scripts/install-apk.sh out/merged-patched.apk --replace
```

The same APK works on Android TV and Fire TV: `adb connect <tv-ip>:5555` before step 4.

## Testing without patching

With a rooted device and frida-server:

```bash
frida -U -f com.disney.disneyplus -l services/disneyplus/scripts/frida-insertions.js              # log only
frida -U -f com.disney.disneyplus -l services/disneyplus/scripts/frida-insertions.js -P '{"block":true}'
```

Then run the device checklist in [the analysis](analysis/ad-pipeline.md#re-verifying-on-a-new-version).
