# Aurogram Unit Economics Calculator

Interactive fundraising model: `unit-economics.html` (open in any browser).

## What it does
- Computes **blended cost-to-serve per active user/month** from your real cost drivers:
  Gemini 2.5-flash chat, Google Search grounding, the nightly **per-user** insight cron,
  Agora calls, Firestore reads/writes/storage, and Cloud Functions.
- Models **three revenue models side-by-side** (Freemium / Pay-per-credit / Hybrid).
- Projects across **three scale tiers** (10k / 100k / 1M MAU).
- Derives ARPU, contribution margin, gross margin, LTV, **LTV:CAC**, and payback period.
- Every assumption is an editable input — recomputes live.

## Cost params grounded in the codebase
| Param | Value | Source |
|---|---|---|
| Chat model | `gemini-2.5-flash` | `backend/lib/config.js` (`AI_MODELS.GEMINI_FLASH`) |
| Max output tokens / msg | 2048 | `CHAT_CONFIG.MAX_OUTPUT_TOKENS` |
| Thinking budget | 0 (no hidden thinking spend) | `CHAT_CONFIG.THINKING_BUDGET` |
| Search tool | always attached, billed per grounding req | `ai_gemini.js` |
| Daily insights | per-user, nightly cron | `schedulers/unified_orchestrator.js` Phase 4 |
| Agora token TTL | 3600s | `agora_token.js` |

Prices in the calculator are **list-price defaults** — override with your negotiated/committed-use rates.

## Plugging in REAL telemetry numbers
The app already logs per-request token counts to the `aiChatMetrics` Firestore collection
(`ai_telemetry.js`). The sandbox can't read it (locked down), but you can:

```bash
# From a machine authenticated to the ty-dev-516d7 project:
cd backend
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
node pull-metrics.mjs
```

It prints average `inTok`, `outTok`, and search rate. Paste those into the
"Input tokens / msg", "Output tokens / msg", and "Search rate %" fields in the
calculator and your cost side becomes empirical instead of estimated.

## Note on revenue
Aurogram is **pre-monetization** ($0 revenue today; "Monetization v1" is on the roadmap
per the pitch deck). All revenue figures are *projections* driven by the conversion/price
assumptions you set. Be explicit about that with investors — model, not actuals.
