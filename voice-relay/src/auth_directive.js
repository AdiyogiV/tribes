const ACCOUNT_FACT = /\baccount=(guest|secured)\b/g;

function verifiedAuthInstruction(account) {
  if (account === "secured") {
    return "[VERIFIED AUTH] account=secured. The Firebase token proves this " +
      "user is already logged in to a secured account. Never ask, offer, or " +
      "nudge them to log in, and never navigate to login.";
  }
  return "[VERIFIED AUTH] account=guest. This is an anonymous account; follow " +
    "the guest login playbook after delivering value.";
}

/**
 * Override client-supplied account state with the verified Firebase token.
 * Anonymous-to-phone upgrades can leave a pre-warmed client directive stale;
 * the relay has the authoritative sign-in provider and must win.
 */
export function withAuthoritativeAccount(directive, decodedToken, providerIds = []) {
  const tokenProvider = decodedToken?.firebase?.sign_in_provider;
  const currentProviders = Array.isArray(providerIds) ? providerIds.filter(Boolean) : [];
  const provider = currentProviders[0] || tokenProvider;
  if (!provider) return directive || "";

  // The live Auth user record beats token claims. Right after an anonymous
  // account is linked to a phone number, a still-valid cached token may retain
  // sign_in_provider=anonymous even though the account is now secured.
  const account = currentProviders.length > 0 || provider !== "anonymous"
    ? "secured"
    : "guest";
  const source = directive || "";
  let corrected = source;
  if (ACCOUNT_FACT.test(source)) {
    ACCOUNT_FACT.lastIndex = 0;
    corrected = source.replace(ACCOUNT_FACT, `account=${account}`);
  }
  ACCOUNT_FACT.lastIndex = 0;
  return `${corrected}\n${verifiedAuthInstruction(account)}`.trim();
}
