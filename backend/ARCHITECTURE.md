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
  ephemeris.js (runEphemerisFlow)  --calls-->  FreeAstrologyAPI (real ephemeris)
      returns: D1 chart, D9 navamsa, D10, Vimshottari dasha,
               panchang, shadbala, ashtakavarga, yogas
      stored on: users/{uid}.astrologyData   (via astro_sync.js on signup/refresh)

COMPUTE (pure math, no AI)         lib/vedic_analysis.js
      houses, aspects (drishti), dignities, combustion,
      raj yogas, ashtakavarga (BAV/SAV), transit scoring
      lib/vedic_day_signal.js       -> auditable 0-100 daily alignment
      functions/forecast/sense.js   -> rolling forecast read-model
      lib/daily_insight_context.js  -> dasha phase, today's transits vs natal lagna

GENERATE (AI)                      lib/gemini.js  (callGemini)
      the ONE place we call Gemini (retries, JSON parsing, telemetry).
      Each reading is one flat self-contained file: gather context -> prompt
      -> callGemini -> validate -> store. No engine, no flavor objects.
      functions/first_reading.js    one-time birth personality read
      functions/current_times_reading.js  "where you are now" read
      functions/forecast/narrate.js rolling continuous forecast story
      functions/per_house.js        12-house Gochara, 14-day cycle (+ scheduler)
      functions/daily_astro_insights.js   compatibility daily cards, anchored
                                          to forecast alignment + one "ready" push

ORCHESTRATE                        functions/schedulers/unified_orchestrator.js
      one nightly cron (4:30 AM IST): refresh sky -> forecast SENSE -> enqueue
      daily cards / per-house / forecast NARRATE -> health.
      One "your daily reading is ready" push
      per user (functions/notifications.js FCM trigger).
```

## Deployed surface (`index.js`)
- **5 gateways** (onCall routers): `astroGateway`, `insightGateway`, `healthGateway`, `socialGateway`, `commsGateway`
- **1 scheduler**: `unifiedOrchestrator`
- **1 task worker**: `taskRouter`
- **Firestore triggers** + **1 SSE `aiChat`**

## The Vedic 4-step recipe (and where each lives)
| Step | Question | Tool | File |
|---|---|---|---|
| Promise | Does the chart promise it? | D1 + D9 + house lords | ephemeris / vedic_analysis |
| Timing  | Is that period running? | Vimshottari dasha | daily_insight_context |
| Trigger | Is a transit activating it? | Gochara (Moon + Lagna) | flavors/per_house |
| Strength| Strong enough to deliver? | Ashtakavarga + Shadbala | vedic_analysis -> wired into readings |

> Strength is wired: forecast SENSE consumes BAV through a canonical
> sign-index adapter; daily and per-house transit prompts carry Ashtakavarga
> bindus (0-8) + quality. Shadbala (strong/weak planets) is in the daily too.
>
> D9 Navamsa is computed + stored (`astrologyData.navamsa`) but intentionally
> NOT fed into daily/per-house prompts: D9 speaks to long-term *promise*, not
> daily *timing*, so it belongs in the one-time first/current-times readings.
> Kept simple on purpose.

## Adding a new reading
Create one file in `functions/` with a flat generator:
gather context -> build prompt -> `callGemini` (from `lib/gemini.js`) ->
validate -> store on the user doc. Wire the handler into a gateway method
registry. No engine or flavor objects — just one readable file per reading.
