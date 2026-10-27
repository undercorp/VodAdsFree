# Writing a patch (ReVanced Patcher 22)

Patches are Kotlin. They are compiled into one bundle (`patches/build/libs/*.rvp`) that ReVanced
CLI or ReVanced Manager load. The source for each service lives next to its notes in
`services/<svc>/patches/src/main/kotlin/`; `patches/build.gradle.kts` compiles all of them,
plus the helpers in `services/_shared/`.

## Anatomy

```kotlin
// Fingerprints.kt - *how to find* the code
internal val BytecodePatchContext.insertionGetPointsMethod by gettingFirstMethodDeclaratively {
    name("getPoints")
    definingClass("Lcom/dss/sdk/internal/media/Insertion;")
    returnType("Ljava/util/List")
}

// SomePatch.kt - *what to change*
val disableAdPipelinePatch = bytecodePatch(
    name = "Disable ad pipeline",            // what users see and pass to `-e`
    description = "...",
) {
    compatibleWith("com.disney.disneyplus")  // optionally pinned: "pkg"("1.2.3")

    apply {
        insertionGetPointsMethod.returnEarly()  // returns an empty list before the original code
    }
}
```

`gettingFirstMethodDeclaratively` is lazy: the search runs the first time the property is read
inside `apply`, and throws if nothing matches. That's what you want: a patch that can't find its
target must fail the build of the APK, not silently produce one that crashes.

### Matching on obfuscated code

When names are useless, match on what survives obfuscation:

```kotlin
internal val BytecodePatchContext.someGateMethod by gettingFirstMethodDeclaratively(
    "some_log_tag_or_json_key",             // (illustrative) string constants the method must contain
) {
    returnType("Z")
    parameterTypes()                        // no parameters
    opcodes(Opcode.IGET_BOOLEAN, Opcode.RETURN)
}
```

Strings are the strongest anchor; add return type, parameter count and a short opcode sequence
until exactly one method matches. Then check it across two or three app versions. This repo's
Netflix/HBO Max patches take descriptors as options instead, because without APKs on hand we
haven't been able to pick anchors that are proven stable - once you have, turning a targets
file into a real fingerprint like the above is the natural next step.

## Changing code

The common edits, all from `app.revanced.patcher.extensions`:

| Goal | Code |
|---|---|
| Return early with a neutral value | `method.returnEarly()` (repo helper, `services/_shared`) |
| Insert smali at an index | `method.addInstructions(index, """ smali """)` |
| Insert with jumps to existing code | `method.addInstructionsWithLabels(index, smali, ExternalLabel("x", method.getInstruction(n)))` |
| Replace / remove | `replaceInstruction(i, "...")`, `removeInstructions(i, count)` |
| Read a register used by existing code | `getInstruction<OneRegisterInstruction>(i).registerA` |
| Add a whole new method | build an `ImmutableMethod(...)`, `.toMutable()`, add smali, `classDef.methods.add(it)` (see Prime Video) |

Rules of thumb for injected smali:

- At **index 0** no local register holds a value yet, so `v0`, `v1` are free to clobber.
- **Mid-method**, you don't know which registers are live. Either read the register the existing
  code uses (as the Prime Video patch does for the player), or move your logic into a new static
  method with its own registers and just call it.
- Non-range `invoke-*` instructions can only address `v0`-`v15`. In big methods, `p0`/`p1` may
  be above that; the patcher will refuse to assemble and tell you.
- `addInstructions` ignores `.catch` directives. Add try/catch with
  `implementation.addCatch(type, fromLabel, toLabel, handlerLabel)` (see Prime Video).

## Build

```bash
./gradlew build                  # -> patches/build/libs/patches-<version>.rvp
```

Building needs a GitHub token because ReVanced publishes the patcher and the Gradle plugin to
GitHub Packages; see the top-level README.

## Further reading

- ReVanced Patcher source and docs: <https://github.com/ReVanced/revanced-patcher>
- Upstream patches (lots of examples): <https://gitlab.com/ReVanced/revanced-patches> (GitLab
  mirror; the GitHub repo was taken down by a DMCA notice in 2026 and ReVanced filed a
  counter-notice - see <https://github.com/ReVanced/where-is-revanced-patches>)
- ReVanced CLI usage: <https://github.com/ReVanced/revanced-cli/blob/main/docs/1_usage.md>
