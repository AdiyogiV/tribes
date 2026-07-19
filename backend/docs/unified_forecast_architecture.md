# Unified Forecast Architecture

> **Status:** Unified daily forecast is implemented. Home, Today, Aurobhatt context,
> and daily notifications now consume one forecast read-model. Per-house and
> one-time/current-times readings remain deliberately separate product surfaces.
> **Decision log:** Grounding = **removed for now** (Pure Unified, no live search).
> **Supersedes:** the on-phone Daily Vibe (`daily_vibe.dart` 9 presets), the fake
> `50 + quality×47` alignment, the fuzzy `NakshatraData.findIndex` name→index path,
> and the "today hijack" in `nakshatra_ring_widget.dart`.

---

## 1. Why

Today the app has ~5 per-user AI engines (`user_memory`, `daily_astro_insights`,
`per_house`, `current_times_reading`, `first_reading`) plus the wheel computing its
own vibe on the phone. Each re-gathers context, each calls Gemini, each stores its
own truth. Result: **incoherent** (five slightly different stories), **inaccurate**
(the wheel silently falls back to fake data on any name mismatch — e.g. backend
`"Moola"` vs Flutter `"Mula"`), and **expensive** (many AI calls/user/day).

We are replacing the *personal narrative* surface with **one coherent system**.
SENSE/NARRATE/REMEMBER and the shared forecast read-model are live. The former
Daily Insight generator has been retired: Flutter adapts the forecast day into the
existing Today widgets without a second collection or AI call. Per-house readings
remain a separate chart surface.

---

## 2. The model: two inputs, one loop

Everything the app says about a person is a **projection** of two sources of truth:

1. **The Sky** — `sky(t)` → deterministic astronomy. No AI, no opinion. *WHAT is happening.*
2. **The Person** — one living doc: chart (fixed) + memory (who they are) + storyline
   (the plot so far). *WHO it happens to.*

The wheel, the daily card, the chat's opening context, and notifications are **views**
over these — not separate engines.

### The loop (per user, on cadence)

```
SENSE     sky(t) over horizon → computeDaySignal() per day
          → [{date, alignment 0-100, tara, favorable[], unfavorable[]}]   (pure math)
KNOW      load person doc: chart + memory + storyline arc                 (one read)
NARRATE   ONE Gemini call: (person + signals + dasha chapter)
          → horizon of {date, heading, narrative} + updated storyline arc (one write)
REMEMBER  fold finished chapter into arc (summary-of-summaries)           (compaction)
```

**Invariant:** *numbers are computed, words are narrated.* The AI receives the real
alignment + signals as ground truth and must write text that matches them. It never
invents a percentage. This is what keeps it "true Vedic" and auditable.

---

## 3. Data model (3 things; 2 already exist in spirit)

```
users/{uid}
  .astrologyData                  # chart + dasha (current implementation)
  memory/profile                  # memory + bounded storyline
  forecast/{yyyy-MM}              # shared computed/narrated read-model
global_astro/sky_positions        # global date-keyed positions + panchang
```

### 3.1 `users/{uid}/person`

```jsonc
{
  "chart": {                       // fixed at onboarding (from ephemeris)
    "moonNakshatraIndex": 18,      // 0-25 canonical index — NEVER a fuzzy string
    "moonSignIndex": 8,
    "ascendantDegree": 123.4,
    "ashtakavarga": { /* ... */ },
    "dasha": { "maha": "Jupiter", "antar": "Saturn", "antarStart": "...", "antarEnd": "..." }
  },
  "memory": {                      // mirrors today's users/{uid}/memory/profile
    "rollingSummary": "1-3 sentence portrait of who they are + what they navigate",
    "threads": [ { "topic": "career", "note": "...", "status": "open", "updatedAt": 0 } ]
  },
  "storyline": {                   // NEW — the astrological narrative dimension
    "arc": "the whole journey so far, compressed to one paragraph (summary-of-summaries)",
    "currentChapter": { "dasha": "Jupiter-Saturn", "phase": "CLOSING",
                        "throughline": "learning to commit vs keep options open" },
    "recentBeats": [ { "period": "2026-06", "gist": "..." } ],   // BOUNDED (keep last ~4)
    "threads": [ { "theme": "career pivot", "note": "...", "status": "open" } ]  // BOUNDED
  },
  "version": 7,
  "lastUpdated": "<serverTimestamp>"
}
```

**Bounded forever** (same discipline as `user_memory`: `MAX_THREADS`, TTL decay,
`recentBeats` capped). No RAG, no vectors — consistent with existing philosophy.

### 3.2 `users/{uid}/forecast/{yyyy-MM}`

```jsonc
{
  "period": "2026-07",
  "generatedAt": "...",
  "personVersion": 7,              // which person snapshot produced this (for staleness)
  "days": [
    { "date": "2026-07-01",
      "alignment": 63,             // REAL — from computeDaySignal
      "tara": "Sampat",
      "favorable": ["Jupiter 5th from Moon (favorable, 6 bindu)"],
      "unfavorable": [],
      "heading": "Momentum, quietly",   // AI — replaces "Restraint Energy"
      "narrative": "...",
      "action": "...", "caution": "...", "tip": "...", "timing": "..." }
  ]
}
```

Month-keyed → free history (past months = "past summaries"), natural archiving, no
unbounded arrays. The card reads the doc covering the scrubbed date.

### 3.3 `sky/{yyyy-MM-dd}` (global)

Deterministic planetary positions + panchang for a date. Computed once by the nightly
sky refresh (already exists: `refreshSkyPositionsDaily`). Shared by all users, so
`computeDaySignal` per user is pure CPU, no per-user ephemeris fetch.

---

## 4. NARRATE — the one AI call (spec)

**Model:** `GEMINI_FLASH` via `callGemini`, `expectJson: true`, `googleSearch: false`.

**System prompt (essence):**
- You write a personal astrological forecast as a *continuous story*, not isolated days.
- You are given REAL alignment numbers + classical signals per day — treat them as
  ground truth. Your words must match the number (high = supportive, low = cautious).
- Use the person's memory + storyline arc so the month references their real life and
  the ongoing plot. Reference earlier days ("the momentum from last week matures…").
- No astrology jargon in `narrative`/`heading` (plain, warm, specific). Jargon stays
  in the computed signals only.
- Output strict JSON.

**User prompt inputs:**
```
PERSON:    chart summary (plain), memory.rollingSummary, memory.threads,
           storyline.arc, storyline.currentChapter
SIGNALS:   the horizon array from SENSE (date, alignment, tara, favorable, unfavorable)
CALENDAR:  dasha phase + guidance (from buildDashaContext)
```

**Output:**
```jsonc
{
  "days": [ { "date": "2026-07-01", "heading": "≤4 words", "narrative": "1-3 sentences",
                "action": "...", "caution": "...", "tip": "...", "timing": "..." } ],
  "storylineUpdate": {
    "arc": "new compacted arc paragraph",
    "beatGist": "one-line gist of this chapter for recentBeats",
    "threads": [ { "theme": "...", "note": "...", "status": "open" } ]
  }
}
```

Token budget: input ~5-8k, output ~3.3k for 30 days. Cap is 65k out / 1M context.
The rolling daily forecast costs **~1 AI call / active user / month**. Per-house
remains cyclical, while first/current-times readings are separate on-demand calls.

---

## 5. REMEMBER — compaction

After NARRATE returns `storylineUpdate`:
- `storyline.arc = storylineUpdate.arc` (the summary-of-summaries; stays one paragraph)
- push `{period, gist: beatGist}` into `recentBeats`; drop oldest beyond cap
- merge `threads` with decay (reuse `applyThreadDecay` pattern from `user_memory`)
- bump `person.version`

**Hierarchy = the dasha tree** (principled, bounded, meaningful):
```
Mahadasha (years)  → life chapter   → storyline.arc
Antardasha (months)→ sub-chapter    → recentBeats / forecast month
Pratyantar (weeks) → scene          → weekly texture on the wheel
Day-signal (day)   → beat           → per-day heading + %
```
A dasha turnover = a natural chapter break.

---

## 6. Cadence (reuses `unifiedOrchestrator`, no new scheduler)

- **Nightly, no AI:** refresh global `sky`; recompute Layer-1 signals for the rolling
  window. This alone makes the wheel % real immediately.
- **~Monthly per user, 1 AI call:** when a user's forecast window runs low
  (< N days remaining), run NARRATE + REMEMBER for the next month. Users hit their own
  boundary → load **self-staggers** across the month → scales linearly.
- **On-demand:** birth-data edit, large location move, or app-open past window end.

---

## 7. Migration / deprecation map

| Today | Fate |
|---|---|
| `computeDaySignal()` (unused, tested) | **PROMOTE** → the SENSE layer |
| `daily_astro_insights.js` (per-day) | **RETIRED** — Today is a compatibility view over `forecast/{yyyy-MM}` |
| `user_memory.js` | **ABSORB** → memory updates happen inside NARRATE/REMEMBER |
| `nakshatra_ring_widget.dart` on-phone vibe + fuzzy `findIndex` + fake % | **MOSTLY MIGRATED** — forecast drives number/story; presets remain out-of-window fallback |
| `daily_vibe.dart` (9 presets) | **DEPRECATE** after every wheel surface has forecast coverage |
| "today hijack" (insight text under Tara label) | **DELETE** |
| `first_reading`, `current_times_reading` | **FOLD** → views of the same forecast (onboarding = chapter 1) |
| `per_house.js` | **KEEP** as specialized compute, but reads `person` (not its own context) |
| compatibility, ayurveda-health | **KEEP** separate domains; draw from `person` |

---

## 8. Why this is better

- **Accurate:** one number engine, canonical indices (never fuzzy strings), no fake
  fallbacks. The known bugs cannot exist — nowhere to hide.
- **Coherent target:** card and chat read the shared forecast. Daily Insight is now
  constrained by the same computed day, but final consolidation is still pending.
- **Efficient target:** the forecast is ~1 call/user/month and SENSE is free math;
  legacy Daily Insight and per-house calls still contribute additional cost.
- **Scalable:** bounded `person` doc, month-keyed forecast, dasha-nested summaries.
  Nothing grows unbounded.

---

## 9. Rollout (each phase ships independently)

0. **Real number, zero AI:** wire `computeDaySignal` → store `forecast.days[].alignment`
   → card shows a true %. Immediate credibility fix, low risk. *(proof the spine works)*
1. **Real words:** NARRATE the month → real `heading` + `narrative` on the card.
2. **The story:** `storyline` + REMEMBER compaction → continuity that compounds.
3. **Cleanup:** delete the 9 presets, fuzzy matcher, hijack; fold `first_reading` /
   `current_times`; keep the daily Insight page as a plain view of `forecast`.

---

## 10. Open questions (track here)

- N = how many days-remaining triggers monthly regen? (start 7)
- `recentBeats` cap? (start 4)
- Do we keep a separate Daily Insight *page*, or is it just the "today" slice of
  `forecast`? (lean: it's a view of `forecast`, no separate engine)
