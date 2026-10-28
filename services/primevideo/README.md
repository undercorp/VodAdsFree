# Prime Video - Skip ads

| | |
|---|---|
| Package | `com.amazon.avod.thirdpartyclient` (phones/tablets) |
| Patch | **Skip ads** - seeks over server-inserted ad breaks |
| Status | Implemented; target code verified upstream on 3.0.412.2947 |
| Analysis | [analysis/skip-ads.md](analysis/skip-ads.md) |

## Layout

```
analysis/        how the ad state machine works, checklist, findings log
patches/         ReVanced patch (Kotlin) - compiled into the repo bundle
smali/           the same helper as a .smali file, used by the apktool approach
scripts/         one script per patching approach + apply_smali_patch.py
targets/         record of tested versions
```

## 1. Get the APK

```bash
scripts/pull-apk.sh primevideo
scripts/merge-splits.sh samples/primevideo/com.amazon.avod.thirdpartyclient-<ver>
```

Use `3.0.412.2947` if you can; other versions usually work since the class names are stable,
and every approach below fails loudly instead of producing a broken APK if they changed.

## 2. Patch - pick an approach

All commands run from the repo root. Output goes to `out/`.

| | Approach | Needs | Pros | Cons |
|---|---|---|---|---|
| A | Upstream ReVanced | `revanced-cli` | maintained by ReVanced, nothing to build | upstream's version support only |
| B | This repo's ReVanced patch | `revanced-cli`, a built bundle | readable smali-only patch, easy to modify | you build the bundle (needs a GitHub token) |
| C | apktool + smali | `apktool`, `uber-apk-signer`, Python | no ReVanced, see every change | slow; apktool rebuilds can fail on some APKs |
| D | Frida hook | rooted device + frida-server | no repackaging, instant iteration | only while Frida is attached; for testing |

**A. Upstream ReVanced**

```bash
scripts/setup-tools.sh revanced-cli
services/primevideo/scripts/patch-upstream-revanced.sh samples/primevideo/<ver>/merged.apk
```

**B. This repo's patch**

```bash
./gradlew build                                  # once; see top-level README for the token
services/primevideo/scripts/patch-vodadsfree.sh samples/primevideo/<ver>/merged.apk
```

**C. apktool**

```bash
scripts/setup-tools.sh apktool signer
services/primevideo/scripts/patch-apktool.sh samples/primevideo/<ver>/merged.apk
# VAF_KEEP_WORKDIR=1 to keep the decoded tree in out/primevideo-apktool for inspection
```

To apply the smali edit to a tree you decoded yourself:
`python3 -I services/primevideo/scripts/apply_smali_patch.py <apktool-dir>` (idempotent).

**D. Frida**

```bash
frida -U -f com.amazon.avod.thirdpartyclient -l services/primevideo/scripts/frida-skip-ads.js
```

Set `TRACE_ONLY = true` at the top of the script to only log ad breaks (position, length, whether
you seeked) without skipping. That's the quickest way to check a new version.

## 3. Install and test

```bash
scripts/install-apk.sh out/<patched>.apk --replace com.amazon.avod.thirdpartyclient   # uninstalls the store version first
adb logcat -s VodAdsFree:*
```

Then run the device checklist in [analysis/skip-ads.md](analysis/skip-ads.md#re-verifying-on-a-new-version)
and add a row to its findings log.

## Fire TV / Android TV

Prime Video on Fire TV is a built-in system app and isn't replaceable without root. The Android
TV app is a separate package that hasn't been analysed yet - see the analysis notes.
