const ACCOUNT_FACT = /\baccount=(guest|secured)\b/g;

/**
 * Override client-supplied account state with the verified Firebase token.
 * Anonymous-to-phone upgrades can leave a pre-warmed client directive stale;
 * the relay has the authoritative sign-in provider and must win.
 */
export function withAuthoritativeAccount(directive, decodedToken) {
  const provider = decodedToken?.firebase?.sign_in_provider;
  if (!provider) return directive || "";

  const account = provider === "anonymous" ? "guest" : "secured";
  const source = directive || "";
  if (ACCOUNT_FACT.test(source)) {
    ACCOUNT_FACT.lastIndex = 0;
    return source.replace(ACCOUNT_FACT, `account=${account}`);
  }
  ACCOUNT_FACT.lastIndex = 0;
  return `${source}\n[VERIFIED AUTH] account=${account}`.trim();
}
