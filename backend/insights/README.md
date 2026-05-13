# Insights Engine

A unified pipeline for generating any kind of AI-powered astrological reading.

## The Idea

Today, every "kind of reading" (daily insight, first reading, current times, house
interpretation, cosmic daily, news digest...) lives in its own ~300-500 line file.
Each one independently:

- Sets up the Gemini client
- Builds its own prompt
- Calls Gemini and parses JSON
- Handles errors and retries
- Implements its own caching
- Stores the result somewhere in Firestore

That's ~6 places where Gemini setup is copy-pasted, ~6 places where JSON parsing has
slightly different fallback behavior, ~6 places where bugs hide.

## The Architecture

```
┌────────────────────────────────────────────────────────────┐
│  L4  ORCHESTRATE  (schedulers, dispatchers, workers)       │
├────────────────────────────────────────────────────────────┤
│  L3  GENERATE  →  one InsightEngine, many "flavors"        │
├────────────────────────────────────────────────────────────┤
│  L2  CONTEXT   →  one assembler with scope filters         │
├────────────────────────────────────────────────────────────┤
│  L1  COMPUTE   →  pure math (vedic_analysis, signal_engine)│
└────────────────────────────────────────────────────────────┘
```

A **flavor** is a small config object (~60-100 lines) that describes ONE kind of
reading: what data it needs, what the prompt is, what shape the answer should be,
where to store it, and how long to cache it.

The **engine** is the shared pipeline that runs ANY flavor. One place to fix bugs.
One place to add observability. One place to manage retries.

## File Layout

```
backend/insights/
├── engine/
│   ├── ai_client.js          Gemini wrapper (setup, retry, JSON parse)
│   ├── cache.js              Read-through caching abstraction
│   └── insight_engine.js     The runFlavor() orchestrator
├── flavors/                   ← one file per "kind of reading"
│   └── per_house.js          The first new flavor (per-house popup)
└── README.md                  This file
```

## Adding A New Flavor

```js
// backend/insights/flavors/my_new_reading.js
export const myNewReadingFlavor = {
  name: "my_new_reading",
  needs: { include: ["dasha", "transits"] },
  prompt: ({ context, params }) => `...`,
  schema: { headline: "string", body: "string" },
  cache: { ttlHours: 24, key: (p) => `my_new:${p.uid}:${p.date}` },
  store: (params, result) =>
    db.collection("users").doc(params.uid)
      .update({ "astrologyData.myNewReading": result }),
};
```

Then call:
```js
import { runFlavor } from "../insights/engine/insight_engine.js";
import { myNewReadingFlavor } from "../insights/flavors/my_new_reading.js";

const result = await runFlavor(myNewReadingFlavor, { uid, date });
```

That's it. Engine handles Gemini, parsing, retries, caching, storage, telemetry.

## Migration Status

| Reading type            | Status      | Source file                    |
|-------------------------|-------------|--------------------------------|
| per_house (popup)       | ✅ SHIPPED  | flavors/per_house.js           |
| daily_insight           | TODO        | functions/daily_astro_insights |
| first_reading           | TODO        | functions/first_reading        |
| current_times           | TODO        | functions/current_times_reading|
| cosmic_daily            | TODO        | functions/cosmic_daily         |
| house_interpretations   | TODO        | functions/house_interpretations|
| news_digest             | TODO        | functions/ai_daily_digest      |

Migrations happen one flavor at a time, each behind a feature flag, never big-bang.

---

## per_house Flavor (shipped)

**Cadence:** Biweekly (14-day cycles). Each cycle = one Gemini call generating
all 12 houses together (coherent, ~6× cheaper than 12 calls).

**Generation triggers (in order of frequency):**
1. **Daily scheduler** (`enqueuePerHouseReadings`) — runs 5:30 AM IST, scans
   users, enqueues anyone whose `cycleEndDate` < today. Spreads load across 1h.
2. **First-time hook** — `astro_sync.js` triggers it after house interpretations
   succeed (so natal context is rich on first run).
3. **Manual callable** (`generatePerHouseNow`) — force regenerate from the app.

**Storage:**
```
users/{uid}/astrologyData.skyHouseReadings = {
  cycleStartDate: "2026-05-13",
  cycleEndDate:   "2026-05-27",
  generatedAt:    <serverTimestamp>,
  houses: {
    "1": { headline, reading, focus, watch },
    "2": { ... },
    ...
    "12": { ... }
  }
}
```

**Frontend tap behavior:**
Tap a house in astro details → read directly from
`astrologyData.skyHouseReadings.houses[N]`. **Zero AI latency.** If the field
is missing (very new users mid-sync), fall back to
`astrologyData.houseInterpretations[N].interpretation` (the static natal one)
and show a tiny "Today's reading is generating…" hint.

**Data the AI sees per house:**
- Natal foundation (from cached `houseInterpretations`)
- Current transits in this house (whole-sign, computed from global sky positions)
- Upcoming ingresses into this house in the next 14 days
- Active Mahadasha + Antardasha (translated to plain language)
- House topic significations

**Cost estimate:** ~$0.005 per user per 14 days = ~$0.01/user/month. For 10k
users that's ~$100/month for the whole feature.
