import test from "node:test";
import assert from "node:assert/strict";

import { withAuthoritativeAccount } from "../src/auth_directive.js";

test("verified phone auth overrides stale guest session facts", () => {
  const result = withAuthoritativeAccount(
    "[SESSION FACTS] account=guest | chart=exists",
    { firebase: { sign_in_provider: "phone" } },
  );

  assert.match(result, /^\[SESSION FACTS\] account=secured \| chart=exists/);
  assert.match(result, /already logged in to a secured account/);
  assert.match(result, /Never ask, offer, or nudge them to log in/);
});

test("verified anonymous auth overrides stale secured session facts", () => {
  const result = withAuthoritativeAccount(
    "[SESSION FACTS] account=secured",
    { firebase: { sign_in_provider: "anonymous" } },
  );

  assert.match(result, /^\[SESSION FACTS\] account=guest/);
  assert.match(result, /anonymous account/);
});

test("current phone provider beats a stale anonymous token", () => {
  const result = withAuthoritativeAccount(
    "[SESSION FACTS] account=guest",
    { firebase: { sign_in_provider: "anonymous" } },
    ["phone"],
  );

  assert.match(result, /^\[SESSION FACTS\] account=secured/);
  assert.match(result, /already logged in to a secured account/);
});

test("verified auth appends account when client omitted it", () => {
  const result = withAuthoritativeAccount(
    "[SESSION FACTS] chart=unknown",
    { firebase: { sign_in_provider: "google.com" } },
  );

  assert.match(result, /\[VERIFIED AUTH\] account=secured/);
  assert.match(result, /never navigate to login/i);
});

test("local bypass without provider leaves directive unchanged", () => {
  assert.equal(
    withAuthoritativeAccount("account=guest", { uid: "dev-bypass" }),
    "account=guest",
  );
});
