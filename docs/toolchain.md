# Toolchain

| Tool | What it's for | How to get it |
|---|---|---|
| JDK 17+ | everything below is Java | Temurin / your package manager |
| [apktool](https://apktool.org) | APK <-> smali + resources | `scripts/setup-tools.sh apktool` |
| [jadx](https://github.com/skylot/jadx) | APK -> readable Java (jadx-gui for browsing) | `scripts/setup-tools.sh jadx` |
| [ReVanced CLI](https://github.com/ReVanced/revanced-cli) | applies `.rvp` patch bundles, signs | `scripts/setup-tools.sh revanced-cli` |
| [APKEditor](https://github.com/REAndroid/APKEditor) | merges split APKs / bundles into one APK | `scripts/setup-tools.sh apkeditor` |
| [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer) | zipalign + sign (apktool approach) | `scripts/setup-tools.sh signer` |
| adb (platform-tools) | pull / install / logcat | Android SDK or your package manager |
| [Frida](https://frida.re) | runtime tracing and hook prototyping | `pip install frida-tools` + frida-server on a rooted device |
| Python 3 | helper scripts | your package manager |

`scripts/setup-tools.sh` puts the jars in `tools/bin/` (git-ignored). Set `GITHUB_TOKEN` if you
hit GitHub API rate limits.

## Signing keys

Every patched APK has to be re-signed, which means it can't update over the store version
(different signature) and you must keep using **the same key** for later updates or you'll have
to uninstall (and lose app data) each time.

- ReVanced CLI creates and reuses its own keystore unless you pass `--keystore`.
- The apktool approach uses a debug key unless you set `VAF_KEYSTORE` (+ `VAF_KEYSTORE_PASS`,
  `VAF_KEYSTORE_ALIAS`).

Practical setup:

- **ReVanced CLI**: let it create its keystore on the first run (it writes a `.keystore` next to
  the output APK), move that file somewhere safe, and pass it on every later run with
  `VAF_KEYSTORE=/path/to/it scripts/patch-with-cli.sh ...`. The CLI uses BouncyCastle's BKS
  format, so a `keytool`-made PKCS12 file may be rejected.
- **apktool approach**: create a normal keystore and export the variables:

```bash
keytool -genkeypair -keystore ~/.vodadsfree-apktool.p12 -alias vodadsfree -keyalg RSA -keysize 4096 -validity 10000
export VAF_KEYSTORE=~/.vodadsfree-apktool.p12 VAF_KEYSTORE_PASS=... VAF_KEYSTORE_ALIAS=vodadsfree
```

Whichever approach you pick for an app, stick with it, because the two keys differ.

## Versions used when this repo was written

ReVanced Patcher 22.0.0 and the `app.revanced.patches` Gradle plugin 1.0.0-dev.10 (the same as
upstream ReVanced Patches 6.1.0). Patcher 22 replaced the old `fingerprint { }` objects with a
declarative matching API; see [writing-patches.md](writing-patches.md).
