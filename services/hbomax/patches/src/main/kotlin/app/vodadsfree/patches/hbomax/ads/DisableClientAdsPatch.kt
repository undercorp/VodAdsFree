package app.vodadsfree.patches.hbomax.ads

import app.revanced.patcher.patch.bytecodePatch
import app.revanced.patcher.patch.stringsOption
import app.vodadsfree.patches.shared.applyMethodTargets

// HBO Max (package com.wbd.stream, inherited from the "Max" app) is obfuscated, so like Netflix the
// concrete methods come from per-version analysis. The two patches map to the two halves of the
// analysis in services/hbomax/analysis/: deciding *whether* the client handles ads at all
// ("ad strategy"), and *what happens* when the user seeks across an ad break ("ad skip / snap-back").

@Suppress("unused")
val disableClientAdStrategyPatch = bytecodePatch(
    name = "Disable client-side ad strategy",
    description = "Makes the player treat streams as ad-free: no ad break schedule, no ad UI, no ad beacons.",
    use = false,
) {
    compatibleWith("com.wbd.stream")

    val targets by stringsOption(
        name = "Target methods",
        description = "Descriptors of the ad strategy / ad break provider methods for this APK version. " +
            "See services/hbomax/targets/.",
        required = true,
    )

    apply {
        applyMethodTargets(targets!!)
    }
}

@Suppress("unused")
val allowAdSkipPatch = bytecodePatch(
    name = "Allow seeking past ads",
    description = "Removes the forced snap-back to an unwatched ad break when seeking, including on Fire TV.",
    use = false,
) {
    compatibleWith("com.wbd.stream")

    val targets by stringsOption(
        name = "Target methods",
        description = "Descriptors of the seek-guard / snap-back methods for this APK version " +
            "(usually a boolean \"should snap back\" check: use \"= false\"). See services/hbomax/targets/.",
        required = true,
    )

    apply {
        applyMethodTargets(targets!!)
    }
}
