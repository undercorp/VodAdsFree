# samples/

APKs go here, one folder per service and app version. **Nothing in here is committed** except
these READMEs (see `.gitignore`): the apps are proprietary, and sharing them isn't ours to do.

```
samples/<service>/<package>-<versionName>/
    base.apk, split_*.apk     as pulled from the device (scripts/pull-apk.sh)
    merged.apk                single APK for tools (scripts/merge-splits.sh)
    SOURCE.txt                where/when it came from (written by pull-apk.sh)
```

Get APKs from your own device with `scripts/pull-apk.sh <service>`. If you download one instead,
use a source that preserves the original signature (and check it with
`apksigner verify --print-certs`), and write where it came from in `SOURCE.txt`.

Keep old versions around while a patch supports them: when a fingerprint breaks, diffing the
old and new decompiled code is the fastest way to find what moved.
