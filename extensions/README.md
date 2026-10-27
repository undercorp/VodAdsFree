# extensions/

The ReVanced Gradle plugin builds every sub-folder here into a DEX "extension" that a patch can
merge into the target app (`extendWith(...)`). Extensions are handy when hook logic is too long
to write comfortably in smali.

This repo does not need one right now: every patch injects plain smali, which keeps the bundle
buildable without an Android SDK. If you add an extension, follow the upstream layout
(`extensions/<app>/build.gradle.kts` + `src/main/java/...` + a `stub/` module for the app's
classes) and you will need the Android SDK installed (`ANDROID_HOME`).
