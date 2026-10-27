package app.vodadsfree.patches.primevideo.ads

import app.revanced.patcher.accessFlags
import app.revanced.patcher.definingClass
import app.revanced.patcher.gettingFirstMethodDeclaratively
import app.revanced.patcher.name
import app.revanced.patcher.opcodes
import app.revanced.patcher.parameterTypes
import app.revanced.patcher.patch.BytecodePatchContext
import app.revanced.patcher.returnType
import com.android.tools.smali.dexlib2.AccessFlags
import com.android.tools.smali.dexlib2.Opcode

// Prime Video ships its player state machine un-obfuscated, so we can match on real names.
// See services/primevideo/analysis/skip-ads.md for how these were identified.

/**
 * `ServerInsertedAdBreakState.enter(Trigger)`: called when playback reaches (or the user seeks
 * across) a server-inserted ad break. Its body starts the ad clips, so this is where we divert.
 */
internal val BytecodePatchContext.enterServerInsertedAdBreakStateMethod by gettingFirstMethodDeclaratively {
    name("enter")
    definingClass("Lcom/amazon/avod/media/ads/internal/state/ServerInsertedAdBreakState;")
    accessFlags(AccessFlags.PUBLIC)
    parameterTypes("Lcom/amazon/avod/fsm/Trigger;")
    returnType("V")
    opcodes(
        Opcode.INVOKE_VIRTUAL,
        Opcode.MOVE_RESULT_OBJECT,
        Opcode.CONST_4,
        Opcode.CONST_4,
    )
}
