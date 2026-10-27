/*
 * Logs what the Disney+ player learns about ads for each title, and optionally empties it
 * (the same thing the patch does) so you can test the effect without re-signing the app.
 *
 *   frida -U -f com.disney.disneyplus -l services/disneyplus/scripts/frida-insertions.js
 *   frida -U -f com.disney.disneyplus -l services/disneyplus/scripts/frida-insertions.js -P '{"block":true}'
 */
let block = false;
rpc.exports = {
  init(stage, params) {
    block = !!(params && params.block);
    Java.perform(main);
  },
};

function main() {
  const Insertion = Java.use("com.dss.sdk.internal.media.Insertion");
  const ArrayList = Java.use("java.util.ArrayList");

  ["getPoints", "getRanges"].forEach((name) => {
    Insertion[name].overloads.forEach((o) => {
      o.implementation = function () {
        const real = o.apply(this, arguments);
        const n = real ? real.size() : 0;
        console.log(`[Insertion.${name}] ${n} item(s)` + (n ? `: ${real.toString().slice(0, 400)}` : ""));
        return block ? ArrayList.$new() : real;
      };
    });
  });
  console.log(`Disney+ insertion logger installed (${block ? "blocking" : "observe only"})`);
}
