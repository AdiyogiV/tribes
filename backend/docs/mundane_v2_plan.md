# Mundane Jyotish v2 — Architecture Plan

## Timing Layers (How We Do World Predictions Without Any Nation's Birthday)

Classical Medini Jyotish uses **5 independent timing layers** — none require
a nation's birth chart. Think of them like zoom levels on a map:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Layer 1: ERA (Jupiter-Saturn conjunction, 20 years)              │
│   Dec 2020 in Capricorn → institutional restructuring era        │
│   Next: ~2040 in Aquarius                                       │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ Layer 2: YEAR (Mesha Sankranti chart, annual)                   │ │
│ │   2026: Moon in Shatabhisha → Saturn-ruled year                 │ │
│ │   Annual Vimshottari dasha (120 yrs compressed to 1 yr)        │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │ Layer 3: ECLIPSE WINDOW (6 months per eclipse)              │ │ │
│ │ │   Feb 2026 solar eclipse Aquarius-Leo axis                  │ │ │
│ │ │   Mar 2026 lunar eclipse → defines disruption window        │ │ │
│ │ │ ┌─────────────────────────────────────────────────────────────┐ │ │ │
│ │ │ │ Layer 4: WEEK (transit perfections, weekly signals)       │ │ │ │
│ │ │ │   What aspect perfected? What ingress happened?            │ │ │ │
│ │ │ │   What changed from last week?                             │ │ │ │
│ │ │ │ ┌─────────────────────────────────────────────────────────┐ │ │ │ │
│ │ │ │ │ Layer 5: GEOGRAPHY (Koorma Chakra)                     │ │ │ │ │
│ │ │ │ │   Saturn in Pisces → Middle East/Oceania under stress    │ │ │ │ │
│ │ │ │ │   Rahu in Aquarius → Russia/Ethiopia disrupted            │ │ │ │ │
│ │ │ │ │   Ketu in Leo → France/Italy identity crisis              │ │ │ │ │
│ │ │ │ └─────────────────────────────────────────────────────────┘ │ │ │ │
│ │ │ └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

Optional Layer 6: NATION CHARTS (India 1947, USA 1776, etc.)
  → Adds nation-specific dasha for targeted predictions
  → Enrichment layer, NOT the foundation
```

**Every layer is computable from pure ephemeris math. No birth chart needed.
No API needed. No LLM needed. Just planetary positions.**

---

## Status Quo

### What Exists (and works)
| Module | Lines | What It Does | Used by Mundane? |
|---|---|---|---|
| `vedic_analysis.js` | 2021 | Ashtakavarga, dignity, friendships, Vedic aspects, Raj Yogas, transit scoring | ❌ NO |
| `free_astro.js` | 2700+ | Birth chart + dasha parsing from API | ❌ NO |
| `signal_engine.js` | 648 | Aspects (hybrid!), yogas, stellium, combustion, ingress | ✅ Yes |
| `aspect_calculator.js` | 400 | Western geometric + Vedic drishti (hybrid) | ✅ Yes |
| `house_lords.js` | 137 | Kalpurush lordship context | ✅ Yes |
| `vedic_yogas.js` | 222 | 5 mundane yogas (no strength check) | ✅ Yes |
| `vedic_utils.js` | 250 | Panchanga (tithi, nakshatra, yoga, vara) | ✅ Yes |
| `upcoming_transits.js` | 150 | Ingress/station/aspect perfection scanner | ✅ Yes |
| `news_feed.js` | 100 | Google News RSS (raw dump) | ✅ Yes |
| `agent_memory.js` | 350 | Gemini embedding + Firestore recall | ✅ Yes |

**The gap:** 2021 lines of proper Vedic math sit unused. The mundane pipeline
reinvented weaker versions of dignity, aspects, and yogas without strength.

### Data Available
- **Sky positions:** 181 days (Dec 2025 → Jun 2026) in Firestore
- **Source:** freeastrologyapi.com (Lahiri sidereal, Ujjain reference)
- **Fields per planet:** longitude, sign, signDegree, isRetro, nakshatra
- **Planets:** 9 Navagraha (no outer planets in stored data, good)
- **No nation charts, no dasha for mundane, no historical news**

---

## What Needs To Change

### Problem 1: Hybrid Western-Vedic Aspects
The signal engine uses Western sextile/square/trine alongside Vedic drishti.
These are different systems with different philosophies.

**Fix:** Vedic-only for mundane. Remove geometric aspects entirely.
Keep ONLY: conjunction (same sign) + 7th (all planets) + special drishti.
All sign-based, no orbs.

### Problem 2: No Strength
Every planet treated equally. A debilitated Saturn and an exalted Saturn
produce the same signal. `vedic_analysis.js` already has `calculatePlanetDignity()`
with a 0-100 scoring system based on BPHS. Just wire it in.

**Fix:** Every signal carries a strength score. Yoga quality = f(participant strengths).

### Problem 3: No Dasha = No Timing
Vedic prediction without dasha is random. For WORLD mundane prediction, classical
Medini Jyotish provides multiple timing layers — none of which require a nation's
birth chart:

#### Layer 1: Mesha Sankranti Chart (Annual — PRIMARY)
The exact moment Sun enters sidereal Aries each year. This is THE classical method
(Varahamihira's Brihat Samhita). Gives:
- Ascendant for the year (computed from exact ingress time + Ujjain coordinates)
- Moon's position → Vimshottari dasha for the year (proportional, 1 year = 120 years)
- Full planetary configuration = the year's themes

**2026 Mesha Sankranti (April 14):**
- Moon at 17.7° Aquarius = Shatabhisha nakshatra = **Saturn lord** → Saturn-dominated year
- Saturn in Pisces (H12) + Mars in Pisces + Mercury debilitated in Pisces = heavy H12 themes
- Moon conjunct Rahu in Aquarius = mass anxiety, tech disruption
- Venus in Aries (H1) = some diplomatic/cultural brightness

#### Layer 2: Jupiter-Saturn Cycle (20-year era)
Last conjunction: Dec 2020, ~6° Capricorn (sidereal). Defines the macro theme.
Capricorn = institutional restructuring, power consolidation. We're 6 years in.

#### Layer 3: Eclipse Charts (6-month windows)
Each solar/lunar eclipse defines a ~6-month disruption window.
**Found in data:** Solar eclipse ~Feb 17, 2026. Lunar eclipse ~Mar 3, 2026.
The eclipse axis (Aquarius-Leo) tells us which domains get disrupted.

#### Layer 4: Koorma Chakra (Geographic mapping)
Varahamihira's mapping of regions to zodiac signs:

| Sign | Regions |
|---|---|
| Aries | India (central), Iran, UK |
| Taurus | Persia, Afghanistan, Ukraine |
| Gemini | USA (east), Egypt, Belgium |
| Cancer | East India, Netherlands, Scotland |
| Leo | France, Italy, Romania |
| Virgo | Turkey, Greece, West Indies |
| Libra | China (trade), Japan, Argentina |
| Scorpio | North Africa, Norway, Korea |
| Sagittarius | Spain, Australia, Arabia |
| Capricorn | India (south), Germany, Mexico |
| Aquarius | Russia, Sweden, Ethiopia |
| Pisces | Portugal, Middle East, Oceania |

Saturn in Pisces → Middle East + Portugal + Oceania under Saturn's pressure.
Rahu in Aquarius → Russia + Sweden + Ethiopia face Rahu-type disruptions.

#### Layer 5: Samvatsara Lord (Annual ruler)
The ruling planet of the Hindu year based on weekday of Chaitra Shukla Pratipada.

#### Layer 6: Nation Charts (OPTIONAL, supporting)
India 1947, USA 1776 etc. are **supporting** evidence, not the foundation.
Useful for nation-specific dasha timing but not required for world predictions.

**Fix:** Compute Mesha Sankranti chart + annual Vimshottari + Eclipse charts +
Koorma mapping + Jupiter-Saturn era context. All pure math, no API needed.
Nation charts become an optional enrichment layer.

### Problem 4: No Ashtakavarga for Transits  
`vedic_analysis.js` has full BPHS-standard Ashtakavarga tables.
Saturn transiting a sign with 1 bindu (weak) vs 5 bindus (strong) =
completely different impact. This is THE classical transit strength tool.

**Fix:** Compute Ashtakavarga for:
- Kalpurush kundli (Aries ascendant — universal baseline)
- Mesha Sankranti chart (annual — the year's transit strengths)
- Optionally, nation charts for nation-specific analysis
Use bindu scores to weight transit significance.

### Problem 5: News Is Unstructured
Raw headlines dumped as text. LLM guesses the connection.

**Fix:** Pre-classify headlines by house domain before LLM sees them.
Map "Israel strikes Lebanon" → H7 (foreign) + H6 (military).
Map "Fed raises rates" → H2 (economy) + H10 (government).

### Problem 6: No Backtesting
Can't know if predictions work without historical validation.

**Fix:** Week-by-week simulation over 1 year of past data.
Score predictions against actual outcomes.

### Problem 7: Daily Is Noisy
Moon changes sign every 2.3 days. Daily runs produce noise.

**Fix:** Weekly cadence. Aggregate daily data into weekly signatures.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    LOCAL DATA LAYER                      │
│                                                         │
│  sky_positions.json    730 days of planetary positions   │
│  future_timeline.json  Pre-computed events for 1 year   │
│  nation_charts.json    India, USA birth data + dasha    │
│  news_archive/         Weekly news (for backtesting)    │
│  run_history/          Past outputs + scores            │
└──────────────┬──────────────────────────────────────────┘
               │
    ┌──────────▼──────────┐
    │   VEDIC MATH ENGINE  │  ← Pure math. No LLM. No cost.
    │                      │
    │  vedic_aspects       │  Sign-based drishti ONLY
    │  vedic_strength      │  Dignity + friendship + Ashtakavarga
    │  vedic_yogas         │  Yoga detection + quality grading
    │  vedic_dasha         │  Vimshottari calculator (local)
    │  weekly_aggregator   │  Daily signals → weekly summary
    │  future_timeline     │  All events for next year
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐
    │  NEWS INTELLIGENCE   │  ← Classify, don't just dump.
    │                      │
    │  classifier          │  Headline → house domain mapping
    │  retrodiction        │  Match predictions → outcomes
    │  archive             │  Historical news loader
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐
    │  LLM LAYER           │  ← Writer, NOT astrologer.
    │  (3-step pipeline)   │
    │                      │
    │  Step 1: Retrodiction│  "Last week's news matched H7/H10
    │                      │   because Mars aspected Saturn."
    │                      │
    │  Step 2: Analysis    │  "This week's dominant theme is X
    │                      │   because [dasha] + [transit] + [yoga]."
    │                      │
    │  Step 3: Prediction  │  "Next 4 weeks: 3 predictions anchored
    │                      │   to specific upcoming transits."
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐
    │  VALIDATION &        │
    │  BACKTESTING         │
    │                      │
    │  validator           │  Reject vague/unfalsifiable predictions
    │  scorer              │  Domain accuracy, timing, specificity
    │  simulate            │  Run week-by-week for 1 year
    │  ml_feedback         │  Learn signal → outcome correlations
    └─────────────────────┘
```

---

## Phase Plan

### Phase 1: Local Data Foundation (3-4 days)

**Goal:** Get 2 years of sky data locally. Set up weekly structure.

1. **Batch-fetch sky positions** — Apr 2025 → Apr 2027 from freeastrologyapi.
   Store as `data/sky_positions.json`. ~730 entries. One-time cost.

2. **Weekly aggregator** — Group daily positions into ISO weeks.
   For each week, compute:
   - Dominant configuration (tightest aspect, strongest yoga)
   - What changed from last week (ingresses, dignity shifts, stations)
   - Week "signature" — compressed set of active signals
   
3. **Future event timeline** — Pre-compute ALL significant events for full 2-year window:
   - Every slow-planet ingress
   - Every exact aspect between slow planets (Mars/Jupiter/Saturn/Rahu/Ketu)
   - Every retrograde/direct station
   - Every eclipse (Sun/Moon within orb of Rahu/Ketu)
   - Output: ~100-200 events total, deterministic, compute once

4. **Mundane reference charts** — Compute from sky data (no API needed):
   
   a) **Mesha Sankranti 2026** (April 14, 2026)
      - Sun at 0° Aries, Moon at 17.7° Aquarius (Shatabhisha, Saturn lord)
      - Full planetary config already in our data
      - Compute ascendant for Ujjain at exact ingress time
      - Derive annual Vimshottari dasha proportions
   
   b) **Eclipse charts** (Feb 17 solar, Mar 3 lunar, 2026)
      - Already detected in our data
      - Eclipse axis, afflicted houses, affected Koorma regions
   
   c) **Jupiter-Saturn conjunction** (Dec 2020, ~6° Capricorn)
      - Hardcode — this is a known historical event
      - Defines the 20-year era context
   
   d) **Koorma Chakra mapping** — Static lookup table
      - Sign → regions of the world
      - Used to translate "Saturn in Pisces" → "Middle East under pressure"
   
   e) **Nation charts** (OPTIONAL enrichment)
      - India: Aug 15, 1947, 00:00 IST, Delhi (Taurus lagna)
      - USA: Jul 4, 1776, 18:30 LMT, Philadelphia (Sagittarius lagna, disputed)
      - These ADD specificity but aren't required for world-level analysis

**Deliverable:** `data/` directory with all positions, future events, mundane charts.
`npm run simulate:week 2026-W15` works locally without Firestore.

---

### Phase 2: Vedic Math — Do It Right (4-5 days)

**Goal:** Replace hybrid aspects with pure Vedic. Add strength. Add dasha.

1. **Pure Vedic aspects** — New `mundane/vedic_aspects.js`:
   - Input: planet positions (sign-based)
   - Output: all active drishti relationships
   - Rules: conjunction (same sign), 7th (all), Mars 4/8, Jupiter 5/9, Saturn 3/10, Rahu/Ketu 5/9
   - NO orbs. NO degrees. Sign-to-sign only.
   - Strength = 100% if aspecting, 0% if not. Binary.
   
2. **Dignity-weighted signals** — Wire `calculatePlanetDignity()` from `vedic_analysis.js`:
   - Every planet in every signal gets a strength score (0-100)
   - Signal intensity = f(planet_weights × dignity_scores)
   - A Raja Yoga between two exalted planets: intensity 9-10
   - A Raja Yoga between two debilitated planets: intensity 4-5
   - This ALONE fixes the "every yoga is equally important" problem

3. **Ashtakavarga transit scoring** — Reuse `calculateBhinnashtakavarga()`:
   - Compute BAV for Kalpurush kundli (Aries = H1) — universal baseline
   - AND for Mesha Sankranti 2026 chart — this year's transit strengths
   - When Saturn transits Pisces, check bindu count in Pisces
   - High bindus (4-5) = constructive transit. Low (0-2) = destructive.
   - This replaces arbitrary "PLANET_WEIGHT" numbers with classical math.

4. **Mundane Vimshottari Dasha** — New `mundane/engine/vedic_dasha.js`:
   - Pure math: Moon's nakshatra at reference moment → lord → starting dasha
   - Vimshottari periods: Ketu 7, Venus 20, Sun 6, Moon 10, Mars 7,
     Rahu 18, Jupiter 16, Saturn 19, Mercury 17 = 120 years
   
   **For annual chart (Mesha Sankranti):**
   - 120 years compressed to 1 year (proportional dasha)
   - Moon in Shatabhisha (Saturn lord) at 2026 Sankranti
   - Saturn gets 19/120 of the year ≈ 58 days first
   - Then Mercury 52 days, then Ketu 21 days, etc.
   - Tells you which planet's themes dominate each period of the year
   
   **For era chart (Jupiter-Saturn conjunction):**
   - 120 years mapped to 20 years
   - Tells you the macro planetary theme of the decade
   
   **For nation charts (optional):**
   - Standard 120-year Vimshottari
   - India: Moon in Ashlesha (Mercury lord) → Mercury Mahadasha math
   - Output: "India is in X Mahadasha, Y Antardasha (dates)"
   
5. **Yoga quality grading** — Enhance `vedic_yogas.js`:
   - Grade A: Both planets dignified (exalted/own sign/mool trikona)
   - Grade B: One dignified, one neutral
   - Grade C: Both neutral
   - Grade D: One or both debilitated/combust
   - Add: check if yoga planets are aspected by benefics (Jupiter/Venus) or malefics

**Deliverable:** `npm run analyze:week 2026-W15` outputs pure Vedic analysis
with strength scores, dasha context, Ashtakavarga transit grades.

---

### Phase 3: News Intelligence (3-4 days)

**Goal:** News becomes structured input, not raw dump.

1. **House domain classifier** — `mundane/news_classifier.js`:
   
   Start with keyword-based (no ML needed for v1):
   ```
   DOMAIN_KEYWORDS = {
     H1: ["national identity", "patriotism", "public mood", "protest"],
     H2: ["economy", "GDP", "trade", "tariff", "bank", "currency", "stock"],
     H3: ["media", "journalist", "telecom", "transport", "railway"],
     H4: ["real estate", "agriculture", "weather", "flood", "earthquake", "opposition party"],
     H5: ["education", "entertainment", "sports", "children", "diplomacy", "speculation"],
     H6: ["military", "army", "navy", "health", "disease", "epidemic", "labor", "strike"],
     H7: ["foreign", "treaty", "sanctions", "war", "alliance", "partnership", "marriage"],
     H8: ["death", "crisis", "scandal", "tax", "insurance", "hidden", "occult"],
     H9: ["law", "supreme court", "religion", "university", "philosophy", "immigration"],
     H10: ["president", "PM", "government", "authority", "regulation", "executive"],
     H11: ["parliament", "congress", "legislature", "UN", "gains", "social movement"],
     H12: ["prison", "hospital", "exile", "espionage", "refugee", "foreign settlement"],
   }
   ```
   
   Score each headline against all houses. Top 1-2 houses per headline.
   
   **Phase 2 (later):** Use a small classifier model or LLM to do entity
   extraction + domain mapping with better accuracy.

2. **Retrodiction engine** — `mundane/retrodiction.js`:
   - Input: this week's classified news + last week's predictions
   - For each prediction: find news items that match the predicted domain
   - Score: exact domain match = 1.0, adjacent domain = 0.5, no match = 0.0
   - Output: `{ prediction, matchedNews[], score, explanation }`
   - Feed this back to the LLM in Step 1 of the pipeline

3. **Historical news archive** — For backtesting:
   - **Primary:** GDELT Project API (free, structured, covers years)
     - Query by date range, get event counts per category
     - Categories map roughly to house domains
   - **Fallback:** Wikipedia "Portal:Current events" (structured by date)
   - **Manual curation:** For v1, curate ~52 weeks of major events
     (one paragraph per week summarizing key world events)
   - Store as `data/news_archive/2025-W20.json` etc.

**Deliverable:** `npm run classify:news "Israel strikes Lebanon"` outputs
`{ houses: [6, 7], confidence: 0.8, entities: ["Israel", "Lebanon"] }`

---

### Phase 4: LLM Pipeline Redesign (3-4 days)

**Goal:** LLM is the writer, not the astrologer. Three-step pipeline.

#### Step 1: Retrodiction (explain last week)

**Input to LLM:**
```
Last week's predictions: [structured list]
This week's news (classified by house): 
  H2 (economy): "Fed raises rates", "Trade deficit widens"
  H6 (military): "NATO exercises in Baltic"
  H7 (foreign): "US-China sanctions"
Matching results: [from retrodiction engine]
```

**Task:** "Explain which predictions matched and which missed. 
For matches, trace the Vedic mechanism. For misses, explain why."

**Output:** `{ retrodiction: "...", lessons: "..." }`

#### Step 2: This Week's Analysis

**Input to LLM:**
```
## World Context — Temporal Layers

### Era (Jupiter-Saturn cycle, 2020-2040)
Conjunction in Capricorn. Theme: institutional restructuring.
Currently 6 years in. Era dasha: [computed from conjunction chart Moon]

### Year (Mesha Sankranti 2026)
Saturn-ruled year (Moon in Shatabhisha). Annual dasha: currently in [X] period.
Eclipse axis: Aquarius-Leo (H11-H5 for Kalpurush).
Key pattern: Saturn+Mars+Mercury(debil) in Pisces H12 = losses/foreign/endings.

### Geographic Pressure (Koorma Chakra)
Pisces activated (Saturn+Mars) → Middle East, Portugal, Oceania under stress
Aquarius activated (Moon+Rahu at Sankranti) → Russia, Sweden, Ethiopia disrupted
Leo (Ketu) → France, Italy, Romania face identity/leadership crises

## This Week's Vedic Signals (pure Vedic, strength-scored)
[Ranked by intensity × dignity score]
1. [★9, A-grade] Raja Yoga: Saturn (H10/H11 lord, dignity:75) + Mars (H1/H8 lord, dignity:45) in H12
   Ashtakavarga: Saturn has 4 bindus in Pisces (moderate), Mars has 2 (weak)
2. [★7, C-grade] Parivartana: Mercury (H3/H6 lord, dignity:15 DEBILITATED) ↔ Jupiter (H9/H12 lord, dignity:60)
...

## Panchanga Summary
Dominant nakshatra theme: Shravana (listening/surveillance)
Tithi trend: Krishna paksha (waning = decline/completion)

## House Lord Context
[Pre-computed lordship summary with dignity scores]
```

**Task:** "Identify the dominant theme. Layer: dasha era → slow planet season → this week.
What houses are most activated? What's the quality of the activation (strong/weak)?"

**Output:** `{ worldEnergy: "...", mainEvent: "...", activatedHouses: [...] }`

#### Step 3: Prediction

**Input to LLM:**
```
## Analysis from Step 2 [passed through]

## Future Signal Timeline
Week +1: Sun→Aries (H12→H1 for India). Mesha Sankranti.
Week +2: Mars-Saturn conjunction perfects (0.2°) in Pisces.
         For India: H7/H12 lord + H9/H10 lord perfect in H11.
         Ashtakavarga: Mars 2 bindus (WEAK), Saturn 4 (moderate).
Week +4: Jupiter→Cancer (EXALTED). For India: H8/H11 lord exalted in H3.
Week +6: Venus retrograde station in Gemini.
Week +8: Eclipse season — Solar eclipse in Leo.
...
[Full year compressed into ~50 lines]

## This Week's News (classified)
[So predictions connect to ONGOING storylines]

## Rules
- 3-5 predictions, each referencing a DIFFERENT upcoming event
- Include strength assessment: "Mars has only 2 bindus so this will be
  a weak expression — verbal conflict not military action"
- Be falsifiable: specific domain, specific timeframe, measurable if possible
- Connect to ongoing news storylines (don't predict in a vacuum)
```

**Output:** `{ predictions: [...], observations: "..." }`

#### Post-Processing / Validation

After LLM returns, automatically:
- Reject predictions without a transit anchor → regenerate
- Reject predictions with weasel words ("potential", "may", "could") → regenerate
- Flag contradictions between predictions
- Score falsifiability (keyword check)
- Store in run history for future retrodiction

---

### Phase 5: Backtesting Harness (3-4 days)

**Goal:** Run the full pipeline for 52 past weeks. Score it.

1. **Simulator** — `scripts/simulate.js`:
   ```
   for each week in [2025-W16 ... 2026-W15]:
     signals = compute_vedic_signals(week)
     dasha = compute_dasha(India, week.start_date)
     news = load_news_archive(week)
     classified_news = classify(news)
     
     retrodiction = retrodiction_engine(last_predictions, classified_news)
     analysis = llm_step2(signals, dasha, ...)
     predictions = llm_step3(analysis, future_timeline, classified_news)
     
     store(week, { signals, predictions, retrodiction })
     last_predictions = predictions
   ```

2. **Scorer** — `scripts/scorer.js`:
   - For each week's predictions, check against next 4 weeks of news
   - Domain accuracy: predicted domain matches news domain?
   - Timing accuracy: event in predicted timeframe?
   - Specificity bonus: measurable claims score higher
   - Output: per-prediction scores + aggregate accuracy

3. **ML feedback (optional, Phase 2)**:
   - Collect (signal_vector, outcome_domain) tuples from backtesting
   - Signal vector: [saturn_dignity, mars_dignity, active_yogas, dasha_lord,
     ashtakavarga_scores, aspect_count_per_house, ...]
   - Outcome: which house domains saw major events that week
   - Train: logistic regression or random forest per house domain
   - This learns: "when Saturn has low bindus in H7's sign AND Mars aspects H7
     AND dasha lord is connected to H7, there's a 73% chance of foreign affairs event"
   - Interpretable model > black box. We need to explain WHY.

**Deliverable:** `npm run backtest` runs 52 weeks, outputs accuracy report.
`npm run backtest:report` generates HTML dashboard with charts.

---

## Future Signal Compression — How Much to Show LLM

Planetary positions are **deterministic**. We know exactly where every planet
will be for the next 1000 years. So pre-compute and compress.

### Three Tiers

**Tier 1: This week (full detail)** ~1.5KB
```
All 7 days of signals, all active yogas with grades, all dignity states,
panchanga per day, all active drishti relationships.
For India: transit-over-natal aspects, dasha context.
```

**Tier 2: Next 10 weeks (event list)** ~500 bytes
```
W+2: Mars-Saturn conj perfects. Sun→Aries. 
W+4: Jupiter→Cancer (EXALTED). Venus stations retro.
W+6: Mercury→Aries. Eclipse approaching.
W+8: Solar eclipse Leo (H5). Saturn stations retro.
W+10: Mars→Aries (own sign). Jupiter-Rahu trine.
```

**Tier 3: Full year (quarterly arcs)** ~300 bytes
```
Q2 2026: Jupiter exalted Cancer. Saturn Pisces. Theme: institutional expansion.
Q3 2026: Eclipse axis Leo-Aquarius. Saturn retro. Theme: reckoning.
Q4 2026: Jupiter-Saturn trine. Theme: structural reform.
Q1 2027: Rahu-Ketu shift axis. New 18-month cycle begins.
```

**Total future context: ~2.5KB.** Fits trivially. 100% deterministic.
Compute once when sky data is fetched, reuse for every weekly run.

---

## File Structure

```
tribes/backend/
├── mundane/                          ← NEW: self-contained mundane system
│   ├── data/
│   │   ├── sky_positions.json        730 days of positions
│   │   ├── future_timeline.json      Pre-computed events
│   │   ├── mundane_charts.json        Sankranti, eclipse, era + optional nation charts
│   │   └── news_archive/             Weekly news files
│   │       ├── 2025-W20.json
│   │       └── ...
│   │
│   ├── engine/                       ← Pure Vedic math (reuses vedic_analysis.js)
│   │   ├── vedic_aspects.js          Sign-based drishti only
│   │   ├── vedic_strength.js         Dignity + Ashtakavarga
│   │   ├── vedic_dasha.js            Vimshottari (annual + era + nation)
│   │   ├── koorma_chakra.js          Geographic sign → region mapping
│   │   ├── vedic_yogas.js            Yoga detection + quality grading
│   │   ├── weekly_signals.js         Daily → weekly aggregation
│   │   └── future_timeline.js        Pre-compute year of events
│   │
│   ├── news/                         ← News intelligence
│   │   ├── classifier.js             Headline → house domain
│   │   ├── retrodiction.js           Match predictions → outcomes
│   │   └── archive_loader.js         Load historical news
│   │
│   ├── llm/                          ← 3-step LLM pipeline
│   │   ├── step1_retrodiction.js     Explain last week
│   │   ├── step2_analysis.js         This week's theme
│   │   ├── step3_prediction.js       Next 4 weeks
│   │   ├── prompts.js                System + user prompts
│   │   └── validator.js              Post-process + reject bad predictions
│   │
│   ├── backtest/                     ← Simulation & scoring
│   │   ├── simulate.js               Week-by-week runner
│   │   ├── scorer.js                 Score predictions vs outcomes
│   │   └── report.js                 Generate accuracy report
│   │
│   ├── tests/
│   │   ├── test_vedic_aspects.js
│   │   ├── test_strength.js
│   │   ├── test_dasha.js
│   │   ├── test_koorma.js
│   │   ├── test_classifier.js
│   │   └── test_weekly_signals.js
│   │
│   └── run.js                        ← Main entry: `node mundane/run.js --week 2026-W15`
│
├── functions/                        ← Existing (untouched for now)
│   ├── cosmic_daily.js               Will eventually call mundane/
│   ├── vedic_analysis.js             SOURCE of truth for Vedic math
│   └── ...
│
└── lib/                              ← Existing (shared utilities)
    ├── constants.js
    ├── vedic_utils.js
    └── ...
```

---

## Reuse Map (what to extract from existing code)

| Existing Code | What to Reuse | New Location |
|---|---|---|
| `vedic_analysis.js:calculatePlanetDignity()` | Dignity scoring (0-100) | `engine/vedic_strength.js` |
| `vedic_analysis.js:calculateBhinnashtakavarga()` | Full BAV tables (BPHS) | `engine/vedic_strength.js` |
| `vedic_analysis.js:calculateSarvashtakavarga()` | SAV totals | `engine/vedic_strength.js` |
| `vedic_analysis.js:calculateVedicAspect()` | Sign-based drishti | `engine/vedic_aspects.js` |
| `vedic_analysis.js:PLANET_FRIENDSHIPS` | Naisargika Maitri | `engine/vedic_strength.js` |
| `vedic_analysis.js:YOGAKARAKA` | Per-ascendant yogakaraka | `engine/vedic_yogas.js` |
| `vedic_analysis.js:calculateRajYogas()` | Ascendant-based Raj Yogas | `engine/vedic_yogas.js` |
| `vedic_analysis.js:scoreHouseActivations()` | Transit scoring with dasha | `engine/weekly_signals.js` |
| `vedic_analysis.js:getTransitBinduScore()` | Ashtakavarga transit score | `engine/vedic_strength.js` |
| `vedic_utils.js:getPanchanga()` | Tithi, nakshatra, yoga, vara | Keep in place, import |
| `vedic_utils.js:getNakshatra()` | Nakshatra calculation | Keep in place, import |
| `upcoming_transits.js:scanUpcomingTransits()` | Ingress/station scanner | `engine/future_timeline.js` |
| `signal_types.js:PLANET_DOMAINS` | Domain mappings | `news/classifier.js` |
| `house_lords.js:buildHouseLordContext()` | Lordship summary | Keep, enhance with strength |

---

## Execution Order

```
Phase 1 (3-4 days): Local data + weekly structure
  → Can run: node mundane/run.js --week 2026-W15 --dry-run
  → Outputs: raw weekly signal summary (no LLM yet)

Phase 2 (4-5 days): Vedic math engine  
  → Can run: node mundane/run.js --week 2026-W15 --vedic-only
  → Outputs: strength-scored Vedic analysis with dasha context

Phase 3 (3-4 days): News intelligence
  → Can run: node mundane/run.js --week 2026-W15 --with-news
  → Outputs: classified news + retrodiction of last week

Phase 4 (3-4 days): LLM pipeline
  → Can run: node mundane/run.js --week 2026-W15
  → Outputs: full 3-step analysis with validated predictions

Phase 5 (3-4 days): Backtesting
  → Can run: node mundane/backtest.js --from 2025-W16 --to 2026-W15
  → Outputs: 52-week accuracy report
```

**Total: ~17-21 days of focused work.**
Each phase is independently testable and deployable.
Each phase produces a working `run.js` with progressively richer output.

---

## Key Design Principles

1. **World-first, nation-optional.**
   The primary timing layers are universal: Mesha Sankranti (annual),
   Jupiter-Saturn cycle (era), eclipses (6-month), Koorma Chakra (geographic).
   Nation charts are optional enrichment, not the foundation.

2. **Math does the astrology. LLM does the writing.**
   Every Vedic judgment (dignity, strength, yoga quality, dasha timing)
   is computed in code, not delegated to the LLM.

2. **Strength is everything.**
   A signal without strength is noise. Every planet, every yoga, every
   transit carries a computed strength score.

3. **Dasha provides the season.**
   Without dasha, every transit is equally likely to manifest.
   With dasha, you know which planet's themes are "awake."

4. **News is structured input, not decoration.**
   Classified by house domain before LLM sees it.
   Retrodiction creates the feedback loop.

5. **Falsifiability is mandatory.**
   Post-processing rejects vague predictions. Backtesting proves or
   disproves the system. We learn from misses.

6. **Deterministic future is free.**
   Pre-compute the full year of events. Show it all to the LLM.
   It costs nothing and gives temporal depth.

7. **Weekly cadence matches mundane reality.**
   Slow planets move ~0.5-2° per week. That's the natural rhythm.
   Daily is Moon-noise. Weekly is signal.
