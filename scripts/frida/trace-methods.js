/*
 * Generic Frida tracer: logs every call (args + return value) to the methods you list.
 * The main tool for confirming a hypothesis from the static analysis: "does this method run
 * when the pause ad shows / when the ad break starts / when I seek?"
 *
 * Usage:
 *   frida -U -f <package> -l scripts/frida/trace-methods.js -P '{"targets":["Lo/abc;->a()Z","com.foo.Bar"]}'
 *
 * Each target is either
 *   - a smali descriptor  Lpkg/Class;->name(Params)Ret   (one overload), or
 *   - a dotted class name com.foo.Bar                       (every method in the class).
 * Pass "stack": true to also print a short Java stack for each call.
 *
 * Classes loaded later (lazy features like ads usually are) are hooked as soon as they appear.
 */
// frida's -P '{...}' JSON arrives through rpc.exports.init (called before the app resumes).
let targets = [];
let showStack = false;
rpc.exports = {
  init(stage, params) {
    targets = (params && params.targets) || [];
    showStack = !!(params && params.stack);
    if (targets.length === 0) console.log("No targets: pass -P '{\"targets\":[...]}'");
    else Java.perform(main);
  },
};

function smaliToJava(t) {
  // "Lcom/foo/Bar;" -> "com.foo.Bar", "[I" -> "[I" (Frida's overload format)
  if (t.startsWith("L") && t.endsWith(";")) return t.slice(1, -1).replace(/\//g, ".");
  if (t.startsWith("[")) return t.replace(/\//g, ".");
  return { Z: "boolean", B: "byte", S: "short", C: "char", I: "int", J: "long", F: "float", D: "double", V: "void" }[t];
}

function splitParams(p) {
  const out = []; let i = 0;
  while (i < p.length) {
    const s = i;
    while (p[i] === "[") i++;
    if (p[i] === "L") i = p.indexOf(";", i);
    i++;
    out.push(p.substring(s, i));
  }
  return out;
}

function fmt(v) {
  try { return v === null || v === undefined ? String(v) : v.toString().slice(0, 200); } catch (e) { return "<?>"; }
}

function hookOverload(className, method, overload) {
  overload.implementation = function () {
    const args = Array.prototype.slice.call(arguments).map(fmt).join(", ");
    const ret = overload.apply(this, arguments);
    console.log(`[call] ${className}.${method}(${args}) -> ${fmt(ret)}`);
    if (showStack) {
      const st = Java.use("android.util.Log").getStackTraceString(Java.use("java.lang.Exception").$new());
      console.log(st.split("\n").slice(1, 8).join("\n"));
    }
    return ret;
  };
}

function hookTarget(t, loader) {
  const factory = loader ? Java.ClassFactory.get(loader) : Java;
  const m = t.match(/^(L[^;]+;)->([^(]+)\(([^)]*)\)(.+)$/);
  if (m) {
    const cls = smaliToJava(m[1]);
    const C = factory.use(cls);
    const types = splitParams(m[3]).map(smaliToJava);
    hookOverload(cls, m[2], C[m[2]].overload.apply(C[m[2]], types));
    console.log(`[hooked] ${t}`);
  } else {
    const C = factory.use(t);
    C.class.getDeclaredMethods().forEach((jm) => {
      const name = jm.getName();
      if (!C[name]) return;
      C[name].overloads.forEach((o) => hookOverload(t, name, o));
    });
    console.log(`[hooked] all methods of ${t}`);
  }
}

function main() {
  const pending = new Set(targets);
  const tryAll = (loader) => {
    for (const t of Array.from(pending)) {
      try { hookTarget(t, loader); pending.delete(t); } catch (e) { /* not loaded yet */ }
    }
  };
  tryAll(null);
  if (pending.size === 0) return;

  // Retry whenever a new class loader shows up or a class is loaded.
  const ClassLoader = Java.use("java.lang.ClassLoader");
  ClassLoader.loadClass.overload("java.lang.String", "boolean").implementation = function (n, r) {
    const c = this.loadClass(n, r);
    if (pending.size > 0) tryAll(this);
    return c;
  };
  console.log(`[waiting] ${Array.from(pending).join(", ")}`);
}
