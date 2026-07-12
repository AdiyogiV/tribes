/**
 * Behavior test for the FreeAstrologyAPI client's resilience (timeout + retry).
 * Stubs global.fetch — no network, no real key needed.
 * Run: FREE_ASTROLOGY_API_KEY=test-key node tests/test_free_astro_client.js
 */
process.env.FREE_ASTROLOGY_API_KEY ||= "test-key";
const { callFreeAstro, MAX_RETRIES } = await import("../functions/free_astro_client.js");

let pass = 0, fail = 0;
const ok = (label, cond) => { cond ? pass++ : (fail++, console.error("  FAIL", label)); };

// 1) Success path: JSON passes through, single call.
let calls = 0;
globalThis.fetch = async () => { calls++; return { ok: true, status: 200, json: async () => ({ output: "good" }) }; };
let r = await callFreeAstro("/x", { a: 1 });
ok("success returns json", r.output === "good");
ok("success = 1 attempt", calls === 1);

// 2) Transient 503 twice then 200: retries and succeeds.
calls = 0;
globalThis.fetch = async () => {
    calls++;
    if (calls < 3) return { ok: false, status: 503, text: async () => "busy" };
    return { ok: true, status: 200, json: async () => ({ output: "recovered" }) };
};
r = await callFreeAstro("/x", {});
ok("retries transient then succeeds", r.output === "recovered");
ok("took 3 attempts", calls === 3);

// 3) 4xx fails fast (no retry).
calls = 0;
globalThis.fetch = async () => { calls++; return { ok: false, status: 400, text: async () => "bad req" }; };
try { await callFreeAstro("/x", {}); ok("4xx should throw", false); }
catch { ok("4xx throws", true); ok("4xx = 1 attempt (fail fast)", calls === 1); }

// 4) Network error retried MAX+1 times then throws.
calls = 0;
globalThis.fetch = async () => { calls++; throw new Error("ECONNRESET"); };
try { await callFreeAstro("/x", {}); ok("network err should throw", false); }
catch { ok("network err throws", true); ok("network err = MAX+1 attempts", calls === MAX_RETRIES + 1); }

console.log(`\nfree_astro_client: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
