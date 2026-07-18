import test from "node:test";
import assert from "node:assert/strict";

import { withAuthoritativeAccount } from "../src/auth_directive.js";

test("verified phone auth overrides stale guest session facts", () => {
  const result = withAuthoritativeAccount(
    "[SESSION FACTS] account=guest | chart=exists",
    { firebase: { sign_in_provider: "phone" } },
  );

  assert.equal(result, "[SESSION FACTS] account=secured | chart=exists");
});

test("verified anonymous auth overrides stale secured session facts", () => {
  const result = withAuthoritativeAccount(
    "[SESSION FACTS] account=secured",
    { firebase: { sign_in_provider: "anonymous" } },
  );

  assert.equal(result, "[SESSION FACTS] account=guest");
});

test("verified auth appends account when client omitted it", () => {
  const result = withAuthoritativeAccount(
    "[SESSION FACTS] chart=unknown",
    { firebase: { sign_in_provider: "google.com" } },
  );

  assert.match(result, /\[VERIFIED AUTH\] account=secured$/);
});

test("local bypass without provider leaves directive unchanged", () => {
  assert.equal(
    withAuthoritativeAccount("account=guest", { uid: "dev-bypass" }),
    "account=guest",
  );
});
