package app.vodadsfree.patches.shared

import app.revanced.patcher.extensions.addInstructions
import app.revanced.patcher.patch.BytecodePatchContext
import app.revanced.patcher.patch.PatchException

/**
 * Applies a list of "method targets" coming from a patch option. Each entry is
 *
 *     <smali descriptor>                 -> return the neutral value (see [returnEarly])
 *     <smali descriptor> = true|false    -> boolean method returns that constant
 *
 * e.g. `Lo/fXz;->a()Z = false` or `Lcom/foo/PauseAdController;->show(Landroid/view/View;)V`.
 * Blank lines and lines starting with `#` are ignored so notes can be pasted in as-is.
 *
 * This is how the Netflix and HBO Max patches stay usable across obfuscated releases: the analysis
 * for a given APK produces the descriptors, and the patch applies them without a code change.
 */
fun BytecodePatchContext.applyMethodTargets(entries: List<String>) {
    val parsed = entries.map(String::trim).filter { it.isNotEmpty() && !it.startsWith("#") }
    if (parsed.isEmpty()) throw PatchException("No target methods given. See this service's README for how to find them.")

    parsed.forEach { entry ->
        val (descriptorText, forced) = entry.split("=", limit = 2).map(String::trim).let { it[0] to it.getOrNull(1) }
        val method = methodByDescriptor(MethodDescriptor.parse(descriptorText))

        when (forced?.lowercase()) {
            null, "", "default" -> method.returnEarly()
            "true", "false" -> {
                if (method.returnType != "Z") throw PatchException("\"= $forced\" only works on boolean methods: $entry")
                method.addInstructions(0, "const/4 v0, ${if (forced == "true") "0x1" else "0x0"}\nreturn v0")
            }
            else -> throw PatchException("Unknown value \"$forced\" in \"$entry\" (use true, false or nothing)")
        }
    }
}
