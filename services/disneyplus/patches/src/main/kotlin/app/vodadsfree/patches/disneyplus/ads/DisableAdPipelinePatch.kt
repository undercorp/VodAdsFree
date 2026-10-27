package app.vodadsfree.patches.disneyplus.ads

import app.revanced.patcher.patch.bytecodePatch
import app.vodadsfree.patches.shared.returnEarly

@Suppress("unused")
val disableAdPipelinePatch = bytecodePatch(
    name = "Disable ad pipeline",
    description = "Hides every ad insertion point and range from the Disney+ player, so no ad pods are " +
        "requested, stitched in or tracked.",
) {
    // No version pin: the SDK class/method names have been stable for a long time. If they ever
    // change, the fingerprints fail and patching stops with an error instead of a broken APK.
    compatibleWith("com.disney.disneyplus")

    apply {
        // Both getters return a fresh, empty ArrayList. Downstream code (ad scheduler, timeline
        // markers, beaconing) iterates these lists, so "empty" means "this title has no ads".
        insertionGetPointsMethod.returnEarly()
        insertionGetRangesMethod.returnEarly()
    }
}
