# HBO Max targets

Two files per app version (they feed two different patches):

| File | Patch | What goes in it |
|---|---|---|
| `com.wbd.stream-<ver>.ad-strategy.txt` | Disable client-side ad strategy | the method(s) that build/return the ad break schedule or pick the ad strategy |
| `com.wbd.stream-<ver>.ad-skip.txt` | Allow seeking past ads | the "snap back to unwatched ad" check (usually a boolean, use `= false`) |

Start from `TEMPLATE.txt`. Apply with:

```bash
VAF_PATCH="Allow seeking past ads" VAF_TARGETS=services/hbomax/targets/com.wbd.stream-<ver>.ad-skip.txt \
  scripts/patch-with-cli.sh samples/hbomax/<apk>
```

To apply both at once, call `scripts/patch-with-cli.sh` directly with two `-e` / `-O` pairs
(see `../README.md`). Note the Fire TV build may have a different versionName than the phone
build; it gets its own files.
