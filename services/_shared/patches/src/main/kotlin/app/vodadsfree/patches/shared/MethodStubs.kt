package app.vodadsfree.patches.shared

import app.revanced.com.android.tools.smali.dexlib2.mutable.MutableMethod
import app.revanced.patcher.definingClass
import app.revanced.patcher.extensions.addInstructions
import app.revanced.patcher.firstMethodDeclarativelyOrNull
import app.revanced.patcher.name
import app.revanced.patcher.parameterTypes
import app.revanced.patcher.patch.BytecodePatchContext
import app.revanced.patcher.patch.PatchException
import app.revanced.patcher.returnType

/**
 * Makes [this] method return immediately with a "nothing here" value:
 *  - `void`      -> return
 *  - boolean/int/float -> false / 0
 *  - long/double       -> 0
 *  - object      -> null, or an empty `ArrayList` when [emptyListForCollections] is set and the
 *                   return type is a `List`/`Collection`/`Iterable` (callers often don't null-check).
 *
 * The stub is inserted at index 0, before any original code runs. At that point no local register
 * holds a value yet, so clobbering `v0`/`v1` is safe.
 */
fun MutableMethod.returnEarly(emptyListForCollections: Boolean = true) {
    val smali = when (returnType.first()) {
        'V' -> "return-void"
        'Z', 'B', 'S', 'C', 'I', 'F' -> "const/4 v0, 0x0\nreturn v0"
        'J', 'D' -> "const-wide/16 v0, 0x0\nreturn-wide v0"
        else -> if (emptyListForCollections && returnType in COLLECTION_TYPES) {
            """
                new-instance v0, Ljava/util/ArrayList;
                invoke-direct {v0}, Ljava/util/ArrayList;-><init>()V
                return-object v0
            """
        } else {
            "const/4 v0, 0x0\nreturn-object v0"
        }
    }

    addInstructions(0, smali)
}

private val COLLECTION_TYPES = setOf(
    "Ljava/util/List;",
    "Ljava/util/Collection;",
    "Ljava/lang/Iterable;",
)

/**
 * A full smali method descriptor such as `Lcom/foo/Bar;->baz(ILjava/lang/String;)Z`, split into parts.
 *
 * Descriptors are what jadx shows under "Copy as smali" / what `scripts/find-ad-code.sh` prints, so
 * analysis notes can hand a finding straight to a patch option without writing a new fingerprint.
 */
data class MethodDescriptor(
    val definingClass: String,
    val name: String,
    val parameterTypes: List<String>,
    val returnType: String,
) {
    override fun toString() = "$definingClass->$name(${parameterTypes.joinToString("")})$returnType"

    companion object {
        private val REGEX = Regex("""^(L[^;]+;)->([^(]+)\(([^)]*)\)(.+)$""")

        fun parse(descriptor: String): MethodDescriptor {
            val match = REGEX.matchEntire(descriptor.trim())
                ?: throw PatchException("Not a smali method descriptor: \"$descriptor\" (expected Lpkg/Class;->name(Params)Ret)")
            val (cls, name, params, ret) = match.destructured
            return MethodDescriptor(cls, name, splitTypes(params), ret)
        }

        private fun splitTypes(params: String): List<String> {
            val types = mutableListOf<String>()
            var i = 0
            while (i < params.length) {
                val start = i
                while (params[i] == '[') i++
                if (params[i] == 'L') i = params.indexOf(';', i)
                i++
                types += params.substring(start, i)
            }
            return types
        }
    }
}

/** Finds the method named by [descriptor] or fails the patch with a message that says what to re-check. */
fun BytecodePatchContext.methodByDescriptor(descriptor: MethodDescriptor): MutableMethod =
    firstMethodDeclarativelyOrNull {
        definingClass(descriptor.definingClass)
        name(descriptor.name)
        returnType(descriptor.returnType)
        parameterTypes(*descriptor.parameterTypes.toTypedArray())
    } ?: throw PatchException(
            "Method $descriptor was not found. Obfuscated names change between app versions: " +
                "re-run scripts/find-ad-code.sh on this exact APK and update the option.",
        )
