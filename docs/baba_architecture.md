# Aurobhatt (Baba) — Companion Architecture & Roadmap

Baba is a voice + text companion that **wraps the whole app**: he can see where
the user is, read what's on screen, operate the UI, and speak with a persona.
This doc is the single source of truth for HOW that system is built and where
it's going.

## 1. The three layers (never mix them)

| Layer | Owns | Lives in |
|---|---|---|
| **BEHAVIOUR** — persona, how he greets/leads/onboards, tone | The CX playbook | `voice-relay/src/cx_tools.js` (provisioned) |
| **FACTS** — live state he can't know (screen, chart, session) | Snapshots + directives | Dart (`BabaContext`, `[REVEAL]` cues) |
| **ACTIONS** — operating the app | Tool handlers | Dart tool catalog + feature tools |

Rule: **never** put behavioural prose in Dart directives, and **never** hardcode
live facts in the playbook. Behaviour → playbook. Facts → app. Actions → tools.

## 2. The spine (already built — keep it)

- **`BabaContext`** (singleton, `ChangeNotifier`) — the ONE source of "where is
  the user + what's on screen." Listens to the router once; derives location via
  `BabaAppMap`. Two channels:
  - *Ambient*: location, pulled on demand by `whereAmI`.
  - *Proactive*: a screen `publish()`es a salient detail to be narrated now.
- **`BabaAppMap`** — the ONE list of screens (key, path, label, description,
  navigable). Drives `navigateTo` enum, `whereAmI` labels, and the persona
  briefing. Add a screen here → Baba can name/describe/open it, zero wiring.
- **`BabaScreenAware` mixin + snapshot registry** — a screen returns its live,
  structured state; `whereAmI` reads it fresh every call.
- **`BabaToolRegistry`** — global, stable tool DECLARATIONS (fixed at session
  connect, no mid-call reconnect) + per-screen swappable HANDLERS. Truthful `ok`.
- **Generic verbs** — `whereAmI / navigateTo / goBack / endCall` work on every
  screen. Feature tools (`getMyChart`, `setBirthDate`, `setPhoneNumber`) live in
  their own feature and self-register.

## 3. What was wrong (the gaps this roadmap fixes)

1. **Coverage**: only 5/13 screens registered live state → Baba blind on 8.
2. **No contract**: `babaSnapshot()` returned free-form `Map<String,dynamic>` —
   every screen invented its own keys; won't scale.
3. **Dead/duplicated code**: `BabaAppMap.promptSummary` built an app briefing
   that nothing consumed and that manually mirrored the playbook.
4. **No memory**: amnesiac between calls.
5. **No knowledge base**: astrology/ayurveda depth came from the LLM's parametric
   memory → generic, sometimes wrong readings.
6. **Prompt-size ceiling**: CX generative input is token-capped (~8192). Adding
   rules is paid every turn → not scalable.

## 4. Roadmap (phased, each independently shippable)

### Phase 1 — Typed snapshot contract   (this change)
`BabaSnapshot` value type: `{status, headline, facts, items}`. Every screen
speaks the same shape. `whereAmI` returns it under `onScreen`; the voice context
flattens `headline`. Enum `BabaScreenStatus {loading, ready, empty, error}` so
Baba always knows "still loading" vs "nothing here."

### Phase 2 — Full screen coverage   (this change, core screens)
Wire the missing screens (`ayurveda`, `chat`, `savedInsights`, `settings`,
`notifications`) to the contract. Remaining low-value screens (`profile`,
`spaces`) can adopt it later — the label/description already answers `whereAmI`.

### Phase 3 — Kill dead code / single source   (this change)
Remove `BabaAppMap.promptSummary` (dead). The playbook is the only persona
briefing; `BabaAppMap` stays the only screen list.

### Phase 4 — Per-call memory (next)
On call end, persist a 2–3 line summary + preferences to
`users/{uid}/babaMemory`. On next call, fold a compact recall line into the
`[SESSION FACTS]` directive ("last time: discussed Saturn dasha; prefers short
answers"). ~50 tokens, big continuity/engagement win.

### Phase 5 — Knowledge base / RAG (DONE — native CX)
Astrology + Ayurveda canon is QUERYABLE via the NATIVE CX path: a Vertex AI
Search data store `baba-canon` (Discovery Engine) holds the canon as documents,
and a CX Data Store Tool `vedicCanon` attached to the playbook retrieves + cites
grounded passages server-side. No app-side tool, no bundled asset. Source of
truth: `assets/baba/knowledge.json`; provision/re-import via
`voice-relay/tools/provision_cx_datastore.sh` then `provision_cx_tools.mjs`.
NOTE: Discovery Engine is behind Walmart's VPC Service Controls perimeter — all
provisioning goes through the corporate proxy; it is a billable service
(indexing + per-query).

### Phase 6 — Character depth
Compact persona doc + 2–3 few-shot exchanges in the playbook (tone is taught
better by examples than by imperative rules), plus richer `getMyChart` facts so
he narrates specifics pulled at runtime.

## 5. Invariants (do not regress)

- Playbook = behaviour only; keep it lean (token ceiling is real).
- `ok` from a tool must be truthful (never blanket `ok:true`).
- Snapshots: small, factual, no PII beyond what's already on screen.
- One screen list (`BabaAppMap`), one context spine (`BabaContext`).
