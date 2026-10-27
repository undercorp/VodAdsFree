package app.vodadsfree.patches.netflix.ads

import app.revanced.patcher.patch.bytecodePatch
import app.revanced.patcher.patch.stringsOption
import app.vodadsfree.patches.shared.applyMethodTargets

/**
 * Netflix is fully obfuscated with R8 and renames classes every release, so a hard-coded
 * fingerprint would be wrong within weeks. Instead this patch takes the methods to neutralize as
 * an option, produced per APK version by the procedure in services/netflix/analysis/pause-ads.md.
 *
 * Verified targets per version are recorded in services/netflix/targets/<version>.txt and can be
 * passed straight to the CLI (see services/netflix/README.md).
 */
@Suppress("unused")
val disablePauseAdsPatch = bytecodePatch(
    name = "Disable pause ads",
    description = "Stops the ad overlay that appears when playback is paused on ad-supported plans.",
    use = false, // Needs per-version targets; must be enabled explicitly.
) {
    compatibleWith(
        "com.netflix.mediaclient", // phones and tablets
        "com.netflix.ninja", // Android TV / Google TV (see analysis: most of this UI is not in Java code)
    )

    val targets by stringsOption(
        name = "Target methods",
        description = "Smali descriptors of the pause-ad gate/show methods for this APK version, one per entry. " +
            "Append \"= false\" to force a boolean gate off. See services/netflix/targets/.",
        required = true,
    )

    apply {
        applyMethodTargets(targets!!)
    }
}
