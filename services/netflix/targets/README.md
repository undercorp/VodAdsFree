# Netflix targets

One file per app version: `<package>-<versionName>.txt`, one smali method descriptor per line.
Lines starting with `#` are comments; use them to say *why* each method was picked and how it was
verified. Copy `TEMPLATE.txt` to start.

Feed a file to the patch with:

```bash
VAF_PATCH="Disable pause ads" VAF_TARGETS=services/netflix/targets/com.netflix.mediaclient-<ver>.txt \
  scripts/patch-with-cli.sh samples/netflix/<apk>
```

Only commit a targets file after the test checklist in `../analysis/pause-ads.md` passes.
