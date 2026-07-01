# Archived: Mundane / World Astrology Engine

**Status:** Disabled (kept for reference / possible future revival).
**Archived on:** 2026-07-01

## What this is
The "Mundane" (Medini Jyotish) engine — **world/global** astrology, distinct from
the per-user **personal** astrology engine. It analyzed the global sky + news
("nimitta") to produce world-energy narratives and world-event predictions.

Contents:
- `cosmic_daily.js` — daily world-intelligence generator (sky signals + Google
  Search news + Gemini). Wrote to Firestore `cosmic_daily_output/{date}`.
- `mundane/` — the Brihat Samhita rules engine (adhyaya / kriya / yantra / varga),
  a second, heavier world-prediction pipeline.

## Why it was turned off
It is a **separate product concern** from the personal daily reading and was
bleeding into personal surfaces. We shut it off to keep the app simple and
focused on the personal astrology engine.

## What was unwired (to revive, reverse these)
1. `functions/schedulers/unified_orchestrator.js` — removed Phase 3
   (`runCosmicDailyScheduled`, `runRefreshMundanePanchanga`) + their imports.
2. `gateways/insight.js` — removed methods `cosmicDailyManual`,
   `generateMundaneForecast`, `getMundaneForecast` + their imports.
3. Frontend: the "Current Sky" world view (`current_sky_page.dart`,
   `current_sky_service.dart`) + its route + entry button were removed/archived.

## Note
Dev scripts under `backend/scripts/` (test_cosmic, simulate_cosmic,
compare_pipelines, diagnose_pipeline, build_quality_report, check_mundane_collections)
reference this code by its OLD path (`../functions/cosmic_daily.js`,
`../mundane/...`). They are not deployed; update their import paths to
`../_archive/...` if you need to run them.
