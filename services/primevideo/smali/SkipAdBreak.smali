# Helper appended to com/amazon/avod/media/ads/internal/state/ServerInsertedAdBreakState.smali
# by services/primevideo/scripts/apply_smali_patch.py (the apktool approach).
#
# Same logic as the ReVanced patch in services/primevideo/patches (keep them in sync):
#   - user seeked across a break   -> seek to where they wanted to go
#   - playback ran into the break  -> seek to current position + break length
#   - then fire NO_MORE_ADS_SKIP_TRANSITION so the state machine leaves "ad" state
# Any exception falls back to just playing the ad.

.method private static vafSkipAdBreak(Lcom/amazon/avod/media/ads/internal/state/ServerInsertedAdBreakState;Lcom/amazon/avod/media/ads/internal/state/AdBreakTrigger;Lcom/amazon/avod/media/playback/VideoPlayer;)V
    .registers 8

    :try_start
    invoke-virtual {p1}, Lcom/amazon/avod/media/ads/internal/state/AdBreakTrigger;->getSeekStartPosition()Lcom/amazon/avod/media/TimeSpan;
    move-result-object v0
    if-eqz v0, :natural_break

    invoke-virtual {p1}, Lcom/amazon/avod/media/ads/internal/state/AdBreakTrigger;->getSeekTarget()Lcom/amazon/avod/media/TimeSpan;
    move-result-object v0
    invoke-virtual {v0}, Lcom/amazon/avod/media/TimeSpan;->getTotalMilliseconds()J
    move-result-wide v1
    goto :seek

    :natural_break
    invoke-interface {p2}, Lcom/amazon/avod/media/playback/VideoPlayer;->getCurrentPosition()J
    move-result-wide v1
    invoke-virtual {p1}, Lcom/amazon/avod/media/ads/internal/state/AdBreakTrigger;->getBreak()Lcom/amazon/avod/media/ads/AdBreak;
    move-result-object v0
    invoke-interface {v0}, Lcom/amazon/avod/media/ads/AdBreak;->getDurationExcludingAux()Lcom/amazon/avod/media/TimeSpan;
    move-result-object v0
    invoke-virtual {v0}, Lcom/amazon/avod/media/TimeSpan;->getTotalMilliseconds()J
    move-result-wide v3
    add-long/2addr v1, v3

    :seek
    invoke-interface {p2, v1, v2}, Lcom/amazon/avod/media/playback/VideoPlayer;->seekTo(J)V

    new-instance v0, Lcom/amazon/avod/fsm/SimpleTrigger;
    sget-object v1, Lcom/amazon/avod/media/ads/internal/state/AdEnabledPlayerTriggerType;->NO_MORE_ADS_SKIP_TRANSITION:Lcom/amazon/avod/media/ads/internal/state/AdEnabledPlayerTriggerType;
    invoke-direct {v0, v1}, Lcom/amazon/avod/fsm/SimpleTrigger;-><init>(Ljava/lang/Object;)V
    invoke-virtual {p0, v0}, Lcom/amazon/avod/media/ads/internal/state/ServerInsertedAdBreakState;->doTrigger(Lcom/amazon/avod/fsm/Trigger;)V
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :on_error

    return-void

    :on_error
    move-exception v0
    const-string v1, "VodAdsFree"
    const-string v2, "Prime Video: failed to skip ad break, playing it instead"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
.end method
