# Aurogram Backend — Architecture (2-minute map)

## Three lanes
1. **Personal astrology** — per-user readings. THE core product. (this doc)
2. **Health** — Apple Watch biosignals -> dosha + vitality (`lib/nadi_engine.js`, `lib/ojas_engine.js`, `functions/ayurveda.js`).
3. **Mundane / world** — ARCHIVED. See `backend/_archive/` (world predictions, news nimitta). Off by choice.

---

## Personal astrology: how a reading is made

Everything follows the classical Vedic recipe: **promise -> timing -> trigger -> strength -> narrate.**

```
DATA SOURCE
  astro_api.js (runAstroFlow)  --calls-->  FreeAstrologyAPI (real ephemeris)
      returns: D1 chart, D9 navamsa, D10, Vimshottari dasha,
               panchang, shadbala, ashtakavarga, yogas
      stored on: users/{uid}.astrologyData   (via astro_sync.js on signup/refresh)

COMPUTE (pure math, no AI)         lib/vedic_analysis.js
      houses, aspects (drishti), dignities, combustion,
      raj yogas, ashtakavarga (BAV/SAV), transit scoring
      lib/house_interpretations.js  -> natal house text
      lib/daily_insight_context.js  -> dasha phase, today's transits vs natal lagna

GENERATE (AI)                      insights/engine/insight_engine.js  (runFlavor)
      one shared pipeline: gather context -> prompt -> Gemini -> validate -> cache -> store
      flavors/first_reading.js      one-time birth personality read
      flavors/current_times.js      "where you are now" read
      flavors/per_house.js          12-house Gochara, 14-day cycle
      functions/daily_astro_insights.js
                                    daily 4-card insight. Uses the SAME shared
                                    AI client, but stays its own module because
                                    it also schedules 4 timed notifications.

ORCHESTRATE                        functions/schedulers/unified_orchestrator.js
      one nightly cron (4:30 AM IST): refresh sky -> generate daily insights
      -> enqueue per-house -> health. Per-card notifications fire via
      functions/task_router.js (Cloud Tasks) at 6a / 12p / 5p / 9p IST.
```

## Deployed surface (`index.js`)
- **5 gateways** (onCall routers): `astroGateway`, `insightGateway`, `healthGateway`, `socialGateway`, `commsGateway`
- **1 scheduler**: `unifiedOrchestrator`
- **1 task worker**: `taskRouter`
- **Firestore triggers** + **1 SSE `aiChat`**

## The Vedic 4-step recipe (and where each lives)
| Step | Question | Tool | File |
|---|---|---|---|
| Promise | Does the chart promise it? | D1 + D9 + house lords | astro_api / vedic_analysis |
| Timing  | Is that period running? | Vimshottari dasha | daily_insight_context |
| Trigger | Is a transit activating it? | Gochara (Moon + Lagna) | flavors/per_house |
| Strength| Strong enough to deliver? | Ashtakavarga + Shadbala | vedic_analysis -> wired into readings |

> Strength IS wired: every transit in the daily insight and per-house reading
> now carries its Ashtakavarga bindus (0-8) + quality, and prompts weigh
> predictions by it. Shadbala (strong/weak planets) is in the daily too.
>
> D9 Navamsa is computed + stored (`astrologyData.navamsa`) but intentionally
> NOT fed into daily/per-house prompts: D9 speaks to long-term *promise*, not
> daily *timing*, so it belongs in the one-time first/current-times readings.
> Kept simple on purpose.

## Adding a new reading
Write a `flavor` (see `insights/README.md`) and call `runFlavor(flavor, { uid })`.
The engine handles Gemini, parsing, retries, caching, storage, telemetry.
