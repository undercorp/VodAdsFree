# Netflix - Disable pause ads

| | |
|---|---|
| Packages | `com.netflix.mediaclient` (phones/tablets), `com.netflix.ninja` (Android TV) |
| Patch | **Disable pause ads** - neutralizes the pause-ad gate/overlay methods you pass in |
| Status | Patch mechanism ready; **per-version targets not yet found** (no APK analysed) |
| Analysis | [analysis/pause-ads.md](analysis/pause-ads.md) |

## Layout

```
analysis/        how pause ads (probably) work, where to cut, how to find it, checklist
patches/         ReVanced patch (Kotlin), option-driven
targets/         confirmed method descriptors per app version (TEMPLATE.txt to start)
scripts/         find-resource-users.sh - layout/string name -> smali that uses it
```

## Why it needs targets

Netflix is obfuscated and renames classes on every release, so this patch doesn't hard-code
where pause ads live. You find the methods for your APK version once (the analysis walks through
it), save them in `targets/`, and the patch applies them. It is disabled by default
(`use = false`) so it never runs without targets.

## Build and use

```bash
# 1. Get and unpack the APK
scripts/pull-apk.sh netflix com.netflix.mediaclient
scripts/merge-splits.sh samples/netflix/com.netflix.mediaclient-<ver>
scripts/decompile.sh netflix samples/netflix/com.netflix.mediaclient-<ver>/merged.apk

# 2. Find candidates, confirm with Frida, write targets/com.netflix.mediaclient-<ver>.txt
scripts/find-ad-code.sh netflix extracted/netflix/<ver>
scripts/frida/trace.sh com.netflix.mediaclient my-candidates.txt --stack

# 3. Build the bundle once (see top-level README), then patch with the targets file
./gradlew build
VAF_PATCH="Disable pause ads" VAF_TARGETS=services/netflix/targets/com.netflix.mediaclient-<ver>.txt \
  scripts/patch-with-cli.sh samples/netflix/com.netflix.mediaclient-<ver>/merged.apk

# 4. Install and run the checklist in analysis/pause-ads.md
scripts/install-apk.sh out/merged-patched.apk --replace com.netflix.mediaclient   # TV: com.netflix.ninja
```

Passing the option by hand instead of `VAF_TARGETS`:

```bash
scripts/patch-with-cli.sh nf.apk -e "Disable pause ads" \
  '-OTarget methods=[Lo/abc;->a()Z = false,Lo/def;->b(Landroid/view/View;)V]'
```

## Android TV (`com.netflix.ninja`)

Same commands with the `ninja` package. Read the "What we're looking at" section of the analysis
first: much of the TV UI is not Java code, so there may be nothing for a bytecode patch to hook.
