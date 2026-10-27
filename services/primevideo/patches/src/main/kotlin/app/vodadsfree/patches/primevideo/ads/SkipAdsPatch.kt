package app.vodadsfree.patches.primevideo.ads

import app.revanced.com.android.tools.smali.dexlib2.mutable.MutableMethod.Companion.toMutable
import app.revanced.patcher.classDef
import app.revanced.patcher.extensions.addInstructions
import app.revanced.patcher.extensions.getInstruction
import app.revanced.patcher.extensions.instructions
import app.revanced.patcher.extensions.methodReference
import app.revanced.patcher.patch.PatchException
import app.revanced.patcher.patch.bytecodePatch
import com.android.tools.smali.dexlib2.AccessFlags
import com.android.tools.smali.dexlib2.Opcode
import com.android.tools.smali.dexlib2.builder.MutableMethodImplementation
import com.android.tools.smali.dexlib2.iface.instruction.OneRegisterInstruction
import com.android.tools.smali.dexlib2.immutable.ImmutableMethod
import com.android.tools.smali.dexlib2.immutable.ImmutableMethodParameter

private const val STATE = "Lcom/amazon/avod/media/ads/internal/state/ServerInsertedAdBreakState;"
private const val AD_BREAK_TRIGGER = "Lcom/amazon/avod/media/ads/internal/state/AdBreakTrigger;"
private const val VIDEO_PLAYER = "Lcom/amazon/avod/media/playback/VideoPlayer;"
private const val TIME_SPAN = "Lcom/amazon/avod/media/TimeSpan;"
private const val AD_BREAK = "Lcom/amazon/avod/media/ads/AdBreak;"
private const val TRIGGER_TYPE = "Lcom/amazon/avod/media/ads/internal/state/AdEnabledPlayerTriggerType;"
private const val SIMPLE_TRIGGER = "Lcom/amazon/avod/fsm/SimpleTrigger;"

private const val HELPER_NAME = "vafSkipAdBreak"

/**
 * The same logic as services/primevideo/smali/SkipAdBreak.smali (used by the apktool approach),
 * kept in sync by hand. Registers: p0 = state, p1 = trigger, p2 = player, v0..v4 scratch.
 */
private val HELPER_SMALI = """
    invoke-virtual {p1}, $AD_BREAK_TRIGGER->getSeekStartPosition()$TIME_SPAN
    move-result-object v0
    if-eqz v0, :natural_break

    # The user scrubbed past an ad break: jump straight to where they wanted to go.
    invoke-virtual {p1}, $AD_BREAK_TRIGGER->getSeekTarget()$TIME_SPAN
    move-result-object v0
    invoke-virtual {v0}, $TIME_SPAN->getTotalMilliseconds()J
    move-result-wide v1
    goto :seek

    # Playback ran into the break: jump to its end.
    :natural_break
    invoke-interface {p2}, $VIDEO_PLAYER->getCurrentPosition()J
    move-result-wide v1
    invoke-virtual {p1}, $AD_BREAK_TRIGGER->getBreak()$AD_BREAK
    move-result-object v0
    invoke-interface {v0}, $AD_BREAK->getDurationExcludingAux()$TIME_SPAN
    move-result-object v0
    invoke-virtual {v0}, $TIME_SPAN->getTotalMilliseconds()J
    move-result-wide v3
    add-long/2addr v1, v3

    :seek
    invoke-interface {p2, v1, v2}, $VIDEO_PLAYER->seekTo(J)V

    # Tell the state machine the break is over, otherwise it stays in "ad" state (no controls, etc).
    new-instance v0, $SIMPLE_TRIGGER
    sget-object v1, $TRIGGER_TYPE->NO_MORE_ADS_SKIP_TRANSITION:$TRIGGER_TYPE
    invoke-direct {v0, v1}, $SIMPLE_TRIGGER-><init>(Ljava/lang/Object;)V
    invoke-virtual {p0, v0}, $STATE->doTrigger(Lcom/amazon/avod/fsm/Trigger;)V
    return-void

    :on_error
    move-exception v0
    const-string v1, "VodAdsFree"
    const-string v2, "Prime Video: failed to skip ad break, playing it instead"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
"""

@Suppress("unused")
val skipAdsPatch = bytecodePatch(
    name = "Skip ads",
    description = "Seeks over server-inserted ad breaks in Prime Video instead of playing them.",
) {
    // Fingerprints verified against this version by upstream ReVanced. Other versions usually
    // work too; the patch fails loudly (instead of producing a broken APK) if the code moved.
    compatibleWith("com.amazon.avod.thirdpartyclient"("3.0.412.2947"))

    apply {
        enterServerInsertedAdBreakStateMethod.apply {
            // 1. Add a private static helper to ServerInsertedAdBreakState. Living inside the class
            //    means it may call the protected StateBase.doTrigger() without changing access flags,
            //    and having its own registers means we don't have to find free ones in enter().
            val helper = ImmutableMethod(
                STATE,
                HELPER_NAME,
                listOf(
                    ImmutableMethodParameter(STATE, emptySet(), "state"),
                    ImmutableMethodParameter(AD_BREAK_TRIGGER, emptySet(), "trigger"),
                    ImmutableMethodParameter(VIDEO_PLAYER, emptySet(), "player"),
                ),
                "V",
                AccessFlags.PRIVATE.value or AccessFlags.STATIC.value,
                null,
                null,
                MutableMethodImplementation(8),
            ).toMutable().apply {
                addInstructions(0, HELPER_SMALI)

                // Wrap everything before the first return-void in a catch-all so a renamed method in
                // a future app version degrades to "ad plays" instead of crashing playback.
                // (The smali compiler used by addInstructions ignores .catch directives.)
                val impl = implementation!!
                val tryEnd = instructions.indexOfFirst { it.opcode == Opcode.RETURN_VOID }
                val handler = instructions.indexOfFirst { it.opcode == Opcode.MOVE_EXCEPTION }
                impl.addCatch(
                    "Ljava/lang/Exception;",
                    impl.newLabelForIndex(0),
                    impl.newLabelForIndex(tryEnd),
                    impl.newLabelForIndex(handler),
                )
            }
            classDef.methods.add(helper)

            // 2. In enter(), right after the player is fetched, hand off to the helper and return
            //    before any ad clip is queued:
            //      invoke-virtual {...}, ...->getPrimaryPlayer()...
            //      move-result-object vPlayer
            val getPlayerIndex = instructions.indexOfFirst {
                it.opcode == Opcode.INVOKE_VIRTUAL && it.methodReference?.name == "getPrimaryPlayer"
            }
            if (getPlayerIndex < 0) throw PatchException("getPrimaryPlayer() call not found in $this")
            val playerRegister = getInstruction<OneRegisterInstruction>(getPlayerIndex + 1).registerA

            addInstructions(
                getPlayerIndex + 2,
                """
                    check-cast p1, $AD_BREAK_TRIGGER
                    invoke-static {p0, p1, v$playerRegister}, $STATE->$HELPER_NAME($STATE$AD_BREAK_TRIGGER$VIDEO_PLAYER)V
                    return-void
                """,
            )
        }
    }
}
