/*
 * Approach D: runtime hook with Frida. Nothing is repackaged or re-signed.
 *
 * Use it to test the skip logic against a new app version before writing/updating a patch, or
 * on a rooted device where you don't want to replace the app. Needs frida-server on the device
 * (root) or the app repackaged with frida-gadget.
 *
 *   frida -U -f com.amazon.avod.thirdpartyclient -l services/primevideo/scripts/frida-skip-ads.js
 *
 * Set TRACE_ONLY = true to just log ad breaks (what the analysis notes were written from).
 */
const TRACE_ONLY = false;

Java.perform(() => {
  const State = Java.use("com.amazon.avod.media.ads.internal.state.ServerInsertedAdBreakState");
  const AdBreakTrigger = Java.use("com.amazon.avod.media.ads.internal.state.AdBreakTrigger");
  const SimpleTrigger = Java.use("com.amazon.avod.fsm.SimpleTrigger");
  const TriggerType = Java.use("com.amazon.avod.media.ads.internal.state.AdEnabledPlayerTriggerType");

  State.enter.overload("com.amazon.avod.fsm.Trigger").implementation = function (trigger) {
    let player;
    try {
      const t = Java.cast(trigger, AdBreakTrigger);
      const adBreak = t.getBreak();
      const durationMs = adBreak.getDurationExcludingAux().getTotalMilliseconds();
      const seekStart = t.getSeekStartPosition();
      // enter() gets the player via getPrimaryPlayer(). In the analysed builds that method is
      // reachable from the state object; if your build differs, check enter() in jadx.
      if (this.getPrimaryPlayer === undefined) throw new Error("getPrimaryPlayer() not on state in this build");
      player = this.getPrimaryPlayer();
      const now = player.getCurrentPosition();
      console.log(`[ad break] at=${now}ms length=${durationMs}ms ` +
        (seekStart ? `(user seeked from ${seekStart.getTotalMilliseconds()} to ${t.getSeekTarget().getTotalMilliseconds()})` : "(reached naturally)"));

      if (TRACE_ONLY) return this.enter(trigger);

      const target = seekStart ? t.getSeekTarget().getTotalMilliseconds() : now + durationMs;
      player.seekTo(target);
      this.doTrigger(SimpleTrigger.$new(TriggerType.NO_MORE_ADS_SKIP_TRANSITION.value));
      console.log(`[ad break] skipped -> ${target}ms`);
    } catch (e) {
      console.log(`[ad break] hook failed, playing ad: ${e}`);
      return this.enter(trigger);
    }
  };
  console.log("VodAdsFree Prime Video hook installed" + (TRACE_ONLY ? " (trace only)" : ""));
});
