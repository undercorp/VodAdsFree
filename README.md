# VodAdsFree

Research notes, tooling and ReVanced-style patches for the client-side ad systems of four Android
streaming apps. For each one the goal is the same: **understand how ads get on screen, work out
which parts the app decides by itself, and patch those** where it's possible.

| Service | Focus | Patch | Status |
|---|---|---|---|
| [Prime Video](services/primevideo/) | in-stream ad breaks | **Skip ads**: seek over server-inserted breaks | implemented; target code verified upstream on 3.0.412.2947; 4 patching approaches |
| [Disney+](services/disneyplus/) | client ad pipeline | **Disable ad pipeline**: player gets an empty ad schedule | implemented; not version-pinned |
| [HBO Max](services/hbomax/) | ad strategy + ad skip on Fire TV | **Disable client-side ad strategy**, **Allow seeking past ads** | mechanism ready; needs per-version targets from analysis |
| [Netflix](services/netflix/) | pause ads | **Disable pause ads** | mechanism ready; needs per-version targets from analysis |

"Needs per-version targets" means those apps are obfuscated and no APK has been analysed in this
repo yet. Their analysis notes say exactly how to find the methods; the patch then applies
whatever you found, without any code change. Read [docs/scope.md](docs/scope.md) for what is
and isn't in scope (no DRM, no entitlement tricks, no APK redistribution).

## Layout

```
services/<service>/
    README.md            how to build and use that service's patch
    analysis/            plain-language notes: how the ads work, what's client-side, checklists, findings
        keywords.txt     search terms for scripts/find-ad-code.sh
    patches/src/...      ReVanced patch source (Kotlin)
    targets/             per-version method lists (obfuscated apps) / record of tested versions
    scripts/             service-specific helpers (Prime Video: one script per patching approach)
services/_shared/        Kotlin helpers used by several patches
samples/<service>/       APKs you pulled (git-ignored)
extracted/<service>/     decompiled output (git-ignored)
scripts/                 shared tooling: setup, pull, merge, decompile, search, patch, install
scripts/frida/           runtime tracing to confirm what the static analysis suggests
docs/                    workflow, toolchain, patch-writing guide, scope
patches/                 Gradle module that compiles every services/*/patches into one .rvp bundle
```

## Quick start

Requirements: JDK 17+, Python 3, bash 4+ (macOS: `brew install bash`), `adb`. Optional: Frida + a rooted device for runtime tracing.

```bash
scripts/setup-tools.sh                       # apktool, jadx, revanced-cli, APKEditor, signer -> tools/bin

scripts/pull-apk.sh primevideo               # from a connected device -> samples/primevideo/<pkg>-<ver>/
scripts/merge-splits.sh samples/primevideo/com.amazon.avod.thirdpartyclient-<ver>
scripts/decompile.sh primevideo samples/primevideo/com.amazon.avod.thirdpartyclient-<ver>/merged.apk
scripts/find-ad-code.sh primevideo extracted/primevideo/<ver>
```

Then follow the service's README. The general method is in [docs/workflow.md](docs/workflow.md).

**Android TV / Google TV / Fire TV over Wi-Fi:** step-by-step guide (in French) to pull an APK from
the TV with remote ADB, patch it and reinstall it: [docs/guide-android-tv.md](docs/guide-android-tv.md).

## Build the patch bundle

ReVanced publishes its patcher and Gradle plugin to GitHub Packages, which requires a token
even though they're public:

1. Create a GitHub **classic** token with only the `read:packages` scope
   (Settings -> Developer settings -> Personal access tokens).
2. Put it in `~/.gradle/gradle.properties` (not in the repo):
   ```properties
   githubPackagesUsername = <your GitHub username>
   githubPackagesPassword = <the token>
   ```
3. Build:
   ```bash
   ./gradlew build
   # -> patches/build/libs/patches-<version>.rvp
   ```

The bundle works with ReVanced CLI (`scripts/patch-with-cli.sh`) and ReVanced Manager (add it
as a local patch source). Because it isn't PGP-signed, the CLI scripts pass `-b` to skip
signature verification.

CI ([.github/workflows/build.yml](.github/workflows/build.yml)) builds the bundle on every push
using the workflow's own token and uploads the `.rvp` as an artifact.

## Patching an app

```bash
scripts/patch-with-cli.sh <apk> --exclusive -e "<patch name>"          # fixed-fingerprint patches
VAF_PATCH="<patch name>" VAF_TARGETS=<targets file> scripts/patch-with-cli.sh <apk>   # option-driven ones
scripts/install-apk.sh out/<name>-patched.apk --replace                # uninstalls the store app first
```

Keep using the same signing key for updates; see [docs/toolchain.md](docs/toolchain.md#signing-keys).

## Contributing a finding

1. Work through the service's analysis note on your APK version.
2. Add what you found to its **Findings** section, in plain language: anchors, call order seen in
   Frida, what you chose to patch and why.
3. Commit the targets file (obfuscated apps) or a tested-version note (others) only after the
   on-device checklist passes.

## Credits and license

The Prime Video and Disney+ patch targets come from the
[ReVanced Patches](https://gitlab.com/ReVanced/revanced-patches) project, and this repo uses its
patcher and tooling. Like ReVanced Patches, this repo is licensed under the GPLv3 ([LICENSE](LICENSE)).
