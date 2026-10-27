# extracted/

Decompiled output, written by `scripts/decompile.sh`; not committed (it's derived from the
proprietary APKs, and it's large).

```
extracted/<service>/<versionName>/
    apktool/             smali + decoded resources
    jadx/                Java-like source
    ad-candidates.txt    output of scripts/find-ad-code.sh
    SOURCE_APK.txt       which APK this came from
```

Findings worth keeping go into `services/<service>/analysis/` (in your own words, with the
relevant smali/descriptor snippets), not here.
