# Research workflow

Every service in this repo goes through the same five steps. The per-service analysis notes follow
this structure, so once you know it you can read any of them.

```
 1. Get the APK      2. Decompile        3. Find candidates    4. Confirm at runtime   5. Patch + test
 pull-apk.sh    ->   decompile.sh   ->   find-ad-code.sh  ->   frida/trace.sh     ->   patch + checklist
 samples/<svc>/      extracted/<svc>/    ad-candidates.txt     notes in analysis/      targets/, patches/
```

## 1. Get the APK

Pull it from your own device so it matches what you actually run:

```bash
adb devices                       # phone, Android TV, or Fire TV (adb connect <ip>:5555)
scripts/pull-apk.sh netflix       # -> samples/netflix/com.netflix.mediaclient-<version>/
scripts/merge-splits.sh samples/netflix/com.netflix.mediaclient-<version>
```

Play Store installs are almost always *split* APKs (`base.apk` + `split_config.*.apk`). apktool,
jadx and ReVanced CLI all want one file, so merge them. Keep the folder name with the exact
version: obfuscated names are only valid for one build.

APKs never get committed (see `.gitignore`); `samples/<svc>/README.md` says what to keep there.

## 2. Decompile

```bash
scripts/decompile.sh netflix samples/netflix/<...>/merged.apk
```

You get two views of the same app in `extracted/netflix/<version>/`:

- `jadx/` - Java-like source. Read this to understand *what the code does*.
- `apktool/` - smali (Dalvik assembly) and decoded resources. This is what patches actually
  change, and what ReVanced fingerprints match against.

## 3. Find candidates

```bash
scripts/find-ad-code.sh netflix extracted/netflix/<version>
```

This greps the smali for the regexes in `services/<svc>/analysis/keywords.txt` and prints each
hit's enclosing method as a smali descriptor (`Lpkg/Class;->method(Args)Ret`). In obfuscated
apps (Netflix, HBO Max) class and method names are meaningless (`Lo/fXz;->a()Z`), but **string
constants survive**: log tags, JSON keys, analytics event names, feature-flag names. They are the
anchors.

From the candidate list, open the interesting ones in jadx and walk the call graph: who calls
this, what does it return, what does the caller do with it. You are looking for a *chokepoint*:
one method that everything ad-related flows through.

Good chokepoints, best first:

1. **A boolean gate** ("is this feature enabled / is this session ad-supported"). Forcing it to
   `false` makes the app take its normal ad-free path, which is well tested by the vendor.
2. **A data source** (the list of ad breaks, the ad config). Returning an empty list is
   usually handled gracefully, because "this title has no ads" is a normal case.
3. **A state transition** (entering "ad playing" state). Divert it to "ad finished".
4. **The UI** (hiding a view). Last resort: the ad logic still runs, beacons still fire, and
   timers may fight you.

## 4. Confirm at runtime

Static reading gives you hypotheses. Confirm them before writing a patch:

```bash
# targets file: one descriptor or class name per line
scripts/frida/trace.sh com.netflix.mediaclient my-candidates.txt --stack
```

Then do the thing that triggers ads (pause, start a title, seek past a break) and watch which
methods fire, with what arguments and return values. A good gate fires exactly when you expect
and nowhere else. Write what you saw into the service's analysis notes - including dead ends,
they save the next person time.

Frida needs root (frida-server) or a repackaged app with frida-gadget. If you have neither, skip
to step 5 and test the patch directly; it is slower but works.

## 5. Patch and test

Either:

- **Fixed fingerprints** (Disney+, Prime Video): the target code isn't obfuscated, so the patch
  matches classes by name and works across versions with no extra input.
- **Per-version targets** (Netflix, HBO Max): you write the confirmed descriptors to
  `services/<svc>/targets/<package>-<version>.txt` and the patch applies them via an option.

Then run the service's test checklist (in its analysis notes) on a real device, and only then
commit the targets file / mark the version as tested.

## Reading smali in 2 minutes

```smali
.method public final a(Lcom/foo/Session;)Z     # boolean a(Session s)
    .registers 4                               # v0..v1 locals, p0 = this (v2), p1 = s (v3)
    invoke-virtual {p1}, Lcom/foo/Session;->isAdTier()Z
    move-result v0                             # v0 = s.isAdTier()
    if-eqz v0, :cond_0                         # if (!v0) goto cond_0
    const/4 v0, 0x1
    return v0                                  # return true
    :cond_0
    const/4 v0, 0x0
    return v0                                  # return false
.end method
```

`L...;` is a class, `Z` boolean, `I` int, `J` long, `V` void, `[` array. `p0` is `this` in
instance methods. Wide values (`J`, `D`) take two registers.
