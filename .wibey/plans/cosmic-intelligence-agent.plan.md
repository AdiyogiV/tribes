# Cosmic Intelligence Agent — Implementation Plan

## What We're Building
A daily autonomous agent that observes the sky, researches what it means using memory of past observations, makes predictions, validates old predictions against real-world news, and gets smarter over time. Global intelligence first, personal readings derived from it.

## Stack
- **Agent loop**: LangGraph JS (already installed v0.4.9, upgrade to latest)
- **Brain**: Gemini 2.0 Flash (already in use)
- **Memory**: Mem0 (`mem0ai` npm — new) + Firestore (existing)
- **Web search**: Tavily (`@tavily/core` npm — new, $0.003/search)
- **Sky data**: Existing `sky_positions.js` + new signal calculator
- **Scheduler**: Cloud Scheduler (existing pattern)
- **Frontend**: Flutter (existing app)

## Cost Budget
- Tavily: ~20 searches/day × $0.003 = $0.06/day = **$1.80/month**
- Gemini Flash: ~15 calls/day × ~4K tokens = 60K tokens/day = **~$0.50/month**
- Mem0 OSS: self-hosted, vector store in-memory or Firestore = **$0/month**
- Firestore: minimal incremental reads/writes = **~$1/month**
- **Total: ~$3-5/month for the global agent**

---

## PHASE 1: Signal Engine (Pure Math — No LLM, No Cost)

### What
Extract **signals** from raw sky positions. A signal is: "something changed or is notable in the sky today."

### Files to Create
```
backend/functions/signal_engine.js       — main signal extraction
backend/lib/aspect_calculator.js         — planet-to-planet aspect math
backend/lib/signal_types.js              — signal type definitions
```

### Signal Types to Detect
1. **Aspect formations** — two planets reaching exact aspect (conjunction 0°, opposition 180°, trine 120°, square 90°, sextile 60°)
   - Track: applying (getting tighter) vs separating (getting looser)
   - Track: orb (how close to exact — tighter = stronger)
2. **Sign ingresses** — planet entering a new zodiac sign (already have this in `sky_positions.js`)
3. **Retrograde stations** — planet going retrograde or direct (already have this)
4. **Dignity shifts** — planet entering exaltation/debilitation/own sign
5. **Speed anomalies** — planet slowing down (approaching station) or unusually fast
6. **Eclipse indicators** — Sun/Moon near Rahu-Ketu axis within orb

### Key Function
```javascript
// signal_engine.js
export function extractSignals(todayPositions, yesterdayPositions) {
  // Returns: Signal[] — array of active signals with metadata
  // Each signal: { type, planets, description, intensity (1-10), 
  //               startDate, peakDate, endDate, domains[] }
}

export function diffSky(today, yesterday) {
  // Returns only what CHANGED — new aspects, sign entries, retro changes
  // This is what the agent looks at. Not everything. Just changes.
}
```

### Data Model — Signal
```javascript
{
  id: "mars-square-saturn-2026-04-11",
  type: "aspect",                          // aspect | ingress | station | dignity | eclipse
  planets: ["Mars", "Saturn"],
  aspect: "square",
  orb: 1.2,                               // degrees from exact
  applying: true,                          // getting tighter?
  intensity: 8,                            // 1-10 based on planet weight + orb tightness
  domains: ["conflict", "authority", "industry"],  // Vedic significations
  startDate: "2026-04-05",                 // when orb entered 10°
  peakDate: "2026-04-14",                  // when exact
  endDate: "2026-04-23",                   // when orb exits 10°
  status: "active"                         // active | peaked | fading | ended
}
```

### Reuse from Existing Code
- `sky_positions.js` → `extractPlanetData()` for positions
- `vedic_analysis.js` → `calculateHouseFromDegree()`, dignity calculations
- `future_transits.js` → sign change detection logic (refactor into signal_engine)
- `lib/constants.js` → zodiac signs, planet data

### Cost: $0 — pure math

---

## PHASE 2: Memory Layer

### What
Two memory systems working together:
- **Mem0**: Agent's working memory (unstructured — "what I know, what I noticed, what I was wrong about")
- **Firestore**: Structured data (signals, predictions with dates, validation outcomes, confidence scores)

### New Dependencies
```bash
cd backend && npm install mem0ai
```

### Mem0 Setup
```javascript
// backend/lib/agent_memory.js
import { Memory } from "mem0ai/oss";

const memory = new Memory({
  version: "v1.1",
  embedder: {
    provider: "google",  // use Gemini embeddings — already have API key
    config: { apiKey: geminiApiKey, model: "text-embedding-004" }
  },
  vectorStore: {
    provider: "memory",  // in-memory for now, upgrade later if needed
    config: { collectionName: "cosmic_memory", dimension: 768 }
  },
  llm: {
    provider: "google_genai",
    config: { apiKey: geminiApiKey, model: "gemini-2.0-flash" }
  }
});

// Namespaces:
// "global/signals"     — observations about sky signals
// "global/predictions" — predictions the agent made
// "global/reflections" — agent's self-reflections
// "global/research"    — findings from web searches
```

### Firestore Schema — New Collections
```
# Structured signal/prediction tracking

global_astro/signals/{signalId}
  - type, planets, aspect, orb, intensity, domains
  - startDate, peakDate, endDate, status
  - createdAt, lastUpdated

global_astro/predictions/{predictionId}
  - signalId (reference)
  - claim: "Geopolitical tension likely Apr 14-18"
  - domains: ["conflict", "geopolitics"]
  - confidence: 0.72
  - searchKeywords: ["geopolitical tension", "conflict", "military"]
  - createdAt
  - resolvesAt: "2026-04-20"
  - status: "pending" | "confirmed" | "unconfirmed" | "ambiguous"
  - validationEvidence: "..." (filled on validation)
  - brierScore: null (filled on validation)

global_astro/validations/{date}
  - predictionsChecked: 5
  - confirmed: 3
  - unconfirmed: 1
  - ambiguous: 1
  - brierScoreAvg: 0.18
  - reflectionSummary: "..." (agent's self-assessment)

global_astro/confidence/{signalType}
  - signalPattern: "mars-square-saturn"
  - totalInstances: 7
  - confirmedInstances: 5
  - currentConfidence: 0.71
  - lastUpdated
  - history: [{date, confidence, evidence}]
```

### Cost: $0 (Mem0 OSS, Firestore minimal writes)

---

## PHASE 3: Research Tools (Agent's Eyes on the World)

### New Dependencies
```bash
cd backend && npm install @tavily/core
```

### New Secret
```javascript
// backend/lib/secrets.js — add:
export const tavilyApiKey = defineSecret("TAVILY_API_KEY");
```

### Tool Definitions for the Agent
```
backend/functions/agent_tools.js  — all tools the agent can call
```

### Tools

**1. calculate_sky()**
- Calls `extractSignals()` and `diffSky()` from Phase 1
- Returns: new signals, changed signals, today's notable aspects
- Cost: $0

**2. search_web(query, options)**
- Calls Tavily with query
- Options: { topic: "news" | "general", days: 1-30, max_results: 5 }
- Returns: title, url, content snippet, published date
- Cost: $0.003/call

**3. search_historical(query)**
- Calls Tavily with "what happened during [astrological event]" type queries
- Specifically for grounding signals in historical events
- Cost: $0.003/call

**4. recall_memory(query)**
- Calls Mem0 search with query
- Returns: relevant past memories (observations, reflections, research)
- Cost: $0 (local)

**5. store_memory(content, metadata)**
- Calls Mem0 add with content + metadata (namespace, tags)
- Cost: $0 (local)

**6. read_signals(filter)**
- Reads from Firestore `global_astro/signals`
- Filter by: status, type, date range
- Cost: Firestore reads (minimal)

**7. read_predictions(filter)**
- Reads from Firestore `global_astro/predictions`
- Filter by: status ("pending"), resolvesAt range
- Cost: Firestore reads (minimal)

**8. write_prediction(prediction)**
- Writes to Firestore `global_astro/predictions`
- Cost: Firestore write (minimal)

**9. validate_prediction(predictionId, evidence, outcome)**
- Updates prediction with validation result
- Computes Brier score
- Updates confidence in `global_astro/confidence`
- Cost: Firestore writes (minimal)

**10. get_confidence(signalPattern)**
- Reads from `global_astro/confidence`
- Returns: historical accuracy for this signal type
- Cost: Firestore read (minimal)

### Daily Search Budget: ~20 calls = $0.06/day

---

## PHASE 4: The Agent (LangGraph JS)

### Upgrade LangGraph
```bash
cd backend && npm install @langchain/langgraph@latest @langchain/google-genai
```

### Files to Create
```
backend/functions/cosmic_agent.js        — the agent definition
backend/functions/cosmic_agent_prompt.js  — system prompt
backend/functions/cosmic_agent_runner.js  — Cloud Function trigger
```

### Agent Architecture (LangGraph State Machine)

```
                    ┌──────────┐
                    │  RECALL  │ ← Always starts here
                    │          │   Loads memory + active signals
                    └────┬─────┘
                         │
                    ┌────▼─────┐
                    │ OBSERVE  │ ← calculate_sky(), diffSky()
                    │          │   What's new since yesterday?
                    └────┬─────┘
                         │
                    ┌────▼─────┐
                    │  REASON  │ ← LLM decides what to do
                    │          │   Based on memory + observations
                    │          │   May call: recall_memory, 
                    │          │   get_confidence, search_web,
                    │          │   search_historical
                    │          │   LOOPS until satisfied
                    └────┬─────┘
                         │
                    ┌────▼─────┐
                    │ PREDICT  │ ← Makes claims with confidence
                    │          │   Calls: write_prediction
                    │          │   Skips if nothing new to predict
                    └────┬─────┘
                         │
                    ┌────▼─────┐
                    │ VALIDATE │ ← Checks old predictions
                    │          │   Calls: read_predictions, 
                    │          │   search_web, validate_prediction
                    └────┬─────┘
                         │
                    ┌────▼─────┐
                    │ REFLECT  │ ← Self-assessment
                    │          │   "What did I learn? Where was I wrong?"
                    │          │   Calls: store_memory
                    │          │   Writes session summary
                    └────┬─────┘
                         │
                    ┌────▼─────┐
                    │   END    │
                    └──────────┘
```

### The System Prompt (Critical — This IS The Agent's Intelligence)

```
backend/functions/cosmic_agent_prompt.js
```

```
You are a Vedic astrological research agent. You observe the sky daily, 
research what planetary configurations mean, make predictions, and validate 
them against real-world events. You get smarter over time by learning from 
your successes and failures.

RULES:
1. ALWAYS recall memory first. Never re-research what you already know.
2. Focus on what CHANGED since yesterday, not everything.
3. When you find a signal, check your confidence history for it.
   - High confidence (>0.7): make a bold prediction
   - Medium confidence (0.4-0.7): make a cautious prediction
   - Low confidence (<0.4) or no history: observe, don't predict
4. When validating predictions:
   - Be skeptical. Correlation ≠ causation.
   - Search for counter-evidence too.
   - Score honestly: confirmed, unconfirmed, or ambiguous.
5. In reflection:
   - Note which prediction types you're overconfident about
   - Note open questions you want to research tomorrow
   - Note novel signal combinations you haven't seen before
6. Budget: max 20 web searches per run. Prioritize.
7. Slow planets (Saturn, Jupiter, Rahu, Ketu) > fast planets for predictions.
8. Vedic framework: use whole-sign houses, Lahiri ayanamsha, classical aspects.
```

### State Schema
```javascript
const AgentState = {
  // Loaded at RECALL
  activeMemories: [],      // from Mem0
  activeSignals: [],       // from Firestore  
  pendingPredictions: [],  // predictions due for validation
  
  // Built at OBSERVE
  skyDiff: {},             // what changed since yesterday
  newSignals: [],          // newly detected signals
  
  // Built at REASON (accumulates as agent thinks)
  researchFindings: [],    // search results
  reasoning: "",           // agent's chain of thought
  
  // Built at PREDICT
  newPredictions: [],      // claims made this run
  
  // Built at VALIDATE  
  validationResults: [],   // outcomes of checked predictions
  
  // Built at REFLECT
  reflection: "",          // session summary for tomorrow
  confidenceUpdates: [],   // adjusted confidence scores
  
  // Control
  searchBudget: 20,        // remaining searches
  iterationCount: 0,       // safety limit
};
```

### Cost Controls (Built Into Agent)
```javascript
// Hard limits in the runner
const COST_LIMITS = {
  maxSearchCalls: 20,        // Tavily budget per run
  maxLLMCalls: 15,           // Gemini calls per run
  maxWallTimeMs: 180_000,    // 3 minutes max
  maxIterations: 30,         // ReAct loop iterations
};
```

### Cloud Function
```javascript
// cosmic_agent_runner.js
// Triggered by Cloud Scheduler at 2:30 AM UTC daily
// Also callable manually for testing

export const runCosmicAgent = onSchedule({
  schedule: "every day 02:30",
  timeZone: "UTC",
  timeoutSeconds: 300,
  memory: "1GiB",
  secrets: [geminiApiKey, tavilyApiKey],
  region: "asia-southeast2",
}, async () => {
  // 1. Initialize agent with tools
  // 2. Run LangGraph
  // 3. Log results
  // 4. Store run metadata for monitoring
});
```

### Cost: ~$0.05/run (15 Gemini calls + 20 Tavily searches)

---

## PHASE 5: Personal Layer (Global Signals → User Readings)

### What
Take the agent's global signals and translate them into personal meaning for each user. This runs AFTER the agent, using the agent's output.

### Files to Create
```
backend/functions/transit_personalization.js  — per-user signal translation
backend/functions/prompts/transit_reading.js  — prompt for personal readings
```

### How It Works
1. Agent produces global signals + predictions (Phase 4)
2. For each user (via Cloud Tasks, existing pattern):
   a. Map signals to user's houses (pure math using ascendant)
   b. Find transit-natal aspects (pure math)
   c. Check dasha resonance (is signal planet = dasha lord?)
   d. Generate personalized reading per active signal (1 LLM call per user)
3. Store in `users/{uid}/transitReadings/{date}`

### Per-Ascendant Batching (Cost Optimization)
Since house mapping is the same for all users with the same ascendant:
- Group users by ascendant (12 groups)
- Generate base reading per ascendant (12 LLM calls)
- Add personal overlay (natal aspects, dasha) per user (short LLM call)

### Data Model
```
users/{uid}/transitReadings/{date}
  - signals: [{ signalId, houseNumber, personalReading, intensity }]
  - worldSummary: "..." (from agent's global output)
  - personalSummary: "..." (synthesized for this user)
  - hotHouses: [10, 8, 7]  (most active houses today)
  - generatedAt
```

### Cost: 12 base readings + 1 short call per user ≈ $0.01/user/day

---

## PHASE 6: Frontend (Flutter)

### Files to Create
```
lib/features/astrology/domain/
  transit_sky_service.dart              — fetches transit readings
  transit_signal_models.dart            — data models

lib/features/astrology/presentation/
  pages/
    current_sky_page.dart               — main page
  widgets/
    world_sky_card.dart                 — global cosmic weather
    signal_feed.dart                    — signal list with confidence badges
    transit_date_scroll.dart            — horizontal date picker
    hot_houses_strip.dart               — quick-tap active houses
    dialogs/
      transit_house_dialog.dart         — house detail on tap
```

### Current Sky Page Layout
```
[← Current Sky]                    [🔍]
                                        
◀ Apr 10 │ ★ Apr 11 TODAY │ Apr 12 ▶
─────────────────────────────────────

🌍 WORLD SKY
  "Saturn-Mars tension peaks this week..."
  🔴 Mars □ Saturn (8/10) — 78% confident
  🟢 Venus enters Taurus — 65% confident
  📊 Last prediction: ✓ confirmed

👤 YOUR SKY (Leo Rising)
  ┌─────────────────────┐
  │   KUNDALI CHART     │
  │   transit overlay    │
  │   tap any house →   │
  └─────────────────────┘
  
  🔥 Hot Houses: [8th ♄] [10th ♂] [7th ♀]

🧠 PATTERNS  
  "Mars in your 10th: 4/5 times career energy confirmed"

💬 Ask about today's sky...
```

### Transit House Dialog (on tap)
```
[8th] Transformation                [✕]
Pisces • Jupiter (lord)

🌍 Global: "Saturn demanding transformation..."
👤 Personal: "With your natal Moon here, deeply emotional..."
🧠 Pattern: "Last time (Jan 2026), you saved this reading"

Transit planets: [♄ Saturn 4°23'] [☊ Rahu 8°15']
Your natal here: [☽ Moon 5°01'] ← Saturn crossing!

Timing: Entered Jan 15 → Peak Apr 18 → Leaves Mar 2028

[👍 Resonates]  [💾 Save]  [💬 Ask More]
```

### Routing
```dart
// Add to app_router.dart:
'/astrology/current-sky' → CurrentSkyPage
```

### Cost: $0 (reads from Firestore)

---

## PHASE 7: Scheduler & Production

### Schedule (extends existing)
```
02:00 UTC  │ refreshSkyPositionsDaily        │ EXISTING
02:30 UTC  │ runCosmicAgent                  │ NEW (the agent)
03:00 UTC  │ refreshMuhuratDaily             │ EXISTING
03:30 UTC  │ personalizeTransitReadings      │ NEW (per-user, Cloud Tasks)
05:00 UTC  │ generateDailyAstroInsights      │ EXISTING (now uses agent signals)
```

### Monitoring — New Firestore Collection
```
global_astro/agent_runs/{date}
  - startedAt, completedAt, durationMs
  - searchCalls, llmCalls, memoriesStored
  - signalsDetected, predictionsCreated, predictionsValidated
  - errors: []
  - cost: { tavily: $0.06, gemini: $0.02 }
  - agentReflection: "..."
```

### Cost Controls (Hard Limits)
- Tavily: max 20 calls/day (hard-coded in agent)
- Gemini: max 15 calls/day (hard-coded in agent)
- Wall time: 3 minutes max per run
- Cloud Tasks for personalization: max 10 concurrent (existing pattern)

### Error Recovery
- Agent checkpoints at each node (LangGraph built-in)
- If agent crashes mid-run: next day starts fresh (memory persists in Mem0)
- If Tavily fails: agent skips research, still does sky analysis + validation from memory
- If Gemini fails: retry once, then log and abort

---

## IMPLEMENTATION ORDER

### Week 1: Foundation
- [ ] **Day 1-2**: Phase 1 — Signal Engine
  - `aspect_calculator.js` (planet-to-planet aspects, orb tracking)
  - `signal_types.js` (signal definitions, domain mappings)
  - `signal_engine.js` (extractSignals, diffSky)
  - Unit tests with known planetary data
  
- [ ] **Day 3**: Phase 2 — Memory Layer
  - `npm install mem0ai`
  - `agent_memory.js` (Mem0 config with Gemini embeddings)
  - Firestore collections (signals, predictions, validations, confidence)
  - Test: store/recall cycle works

- [ ] **Day 4**: Phase 3 — Research Tools
  - `npm install @tavily/core`
  - Add `tavilyApiKey` secret
  - `agent_tools.js` (all 10 tool definitions)
  - Test: each tool works independently

### Week 2: The Agent
- [ ] **Day 5-6**: Phase 4 — Agent Core
  - Upgrade `@langchain/langgraph` to latest
  - `cosmic_agent_prompt.js` (system prompt)
  - `cosmic_agent.js` (LangGraph state machine)
  - `cosmic_agent_runner.js` (Cloud Function wrapper)
  - Test locally: run agent once, verify it recalls → observes → reasons → stores

- [ ] **Day 7**: Phase 4 — Agent Polish
  - Cost controls (search budget, iteration limits)
  - Error recovery (retry, fallback, graceful abort)
  - Run monitoring (agent_runs collection)
  - Test: run agent 3 consecutive days, verify memory accumulates

### Week 3: Personal + Frontend
- [ ] **Day 8-9**: Phase 5 — Personal Layer
  - `transit_personalization.js`
  - `prompts/transit_reading.js`
  - Cloud Tasks integration (existing pattern from insight_worker.js)
  - Test: generate reading for test user

- [ ] **Day 10-12**: Phase 6 — Frontend
  - Data models + service (`transit_sky_service.dart`, `transit_signal_models.dart`)
  - Current Sky page (`current_sky_page.dart`)
  - World Sky card, Signal feed, Hot houses strip
  - Transit house dialog (reuse HouseDetailsDialog pattern)
  - Date scroll widget
  - Route registration

### Week 4: Production
- [ ] **Day 13**: Phase 7 — Scheduler
  - Cloud Scheduler entries
  - Connect agent output → daily insights (enrich existing insights with signals)
  - Connect agent output → chat context (enrich existing chat with signals)

- [ ] **Day 14**: Testing & Polish
  - End-to-end: scheduler → agent → personalization → frontend
  - Cost monitoring dashboard (simple Firestore reads)
  - Edge cases: empty sky diff, all predictions validated, Tavily down

---

## COST SUMMARY

| Component | Daily | Monthly |
|-----------|-------|---------|
| Tavily (20 searches) | $0.06 | $1.80 |
| Gemini Flash (15 agent calls) | $0.02 | $0.60 |
| Gemini Flash (12 ascendant readings) | $0.01 | $0.30 |
| Gemini Flash (per-user personalization) | ~$0.01/user | ~$0.30/user |
| Firestore reads/writes | ~$0.03 | ~$1.00 |
| Mem0 (self-hosted, in-memory) | $0 | $0 |
| **Global agent total** | **$0.12** | **$3.70** |
| **Per 100 users** | **$1.12** | **$33.70** |
| **Per 1000 users** | **$10.12** | **$303.70** |

### Cost Optimization Levers
1. Ascendant batching: 12 readings cover ALL users (already planned)
2. Agent search budget: hard cap at 20/day, agent prioritizes
3. Gemini Flash (not Pro): 10x cheaper, fast enough
4. Mem0 OSS: no cloud fees, local vector store
5. Skip personalization for inactive users (no login in 7 days)
6. Cache personal readings: same ascendant + same dasha period = same reading

---

## WHAT SUCCESS LOOKS LIKE

### Week 1: Agent runs and produces signals
- Detects 3-8 signals per day from sky data
- Stores in Firestore with metadata

### Month 1: Agent makes and validates predictions
- 50+ predictions stored with confidence
- First validation cycle complete
- Initial Brier scores computed
- Agent's reflections show it adjusting confidence

### Month 3: Memory is meaningful
- Agent skips re-research on known patterns
- Confidence scores diverge (some signals reliable, some not)
- Novel signal combinations flagged and tracked
- Personal readings reference "last time this happened"

### Month 6: System intelligence visible to users
- Confidence badges on signals ("78% historically accurate")
- "Last time" patterns shown in transit house dialogs
- Weekly/monthly reflection summaries available
- Agent's predictions become a differentiating feature

### Year 1: Self-improving intelligence
- Full Brier score dashboard
- Agent knows which predictions to be bold about
- Accumulated memory makes readings richer
- Nobody else has this dataset
