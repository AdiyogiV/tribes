# How Classical Medini Jyotish Actually Works
# And What Varahamihira Would Build With AI Agents

---

## The Fundamental Misunderstanding We Had

We were thinking like natal astrologers: "cast a chart, interpret it."
Varahamihira didn't cast charts for the world. **The sky IS the chart.**
It's always running. There's no birth moment for "the world."

His system in Brihat Samhita (~550 CE) is a **rules engine**:
- Planet P is in sign S → effects E happen in regions R
- Planet P conjoins planet Q → interaction effects
- Planet P is exalted/debilitated → modifies intensity
- Eclipse in sign S → disruption in regions R for D months

That's it. No annual charts. No special dates. No dashas for nations.
Just: **where are the planets right now, and what do the rules say?**

The Mesha Sankranti system, Tajika annual charts, nation charts —
these are all LATER medieval additions (heavily Persian-influenced).
Varahamihira's original system is simpler and more direct.

---

## The Classical Rules (What Brihat Samhita Actually Says)

### Layer 1: Planet-in-Sign Effects (Grahachara)

This is the backbone. Each planet in each sign produces SPECIFIC mundane effects.
Not "Saturn is restrictive" — specific predictions like:

**Saturn in Pisces** (BS Ch.5, approximate):
- Suffering in maritime/coastal regions
- Loss of fish, sea trade disrupted
- Floods in low-lying areas
- Religious institutions under stress
- Spiritual leaders face scandal or loss
- People near rivers/oceans suffer

**Jupiter in Gemini** (BS Ch.8, approximate):
- Intellectual discourse flourishes
- Trade and commerce expand
- Writers, scholars gain prominence
- Some deception in communication
- Northern wind-belt regions prosper

**Mars in Pisces** (BS Ch.9, approximate):
- Military action near water/coasts
- Naval conflicts
- Fire incidents in port cities
- Aggression in spiritual/religious spaces
- Surgeons, butchers, fire-workers affected

These are NOT vague. They're specific domain + region predictions
that fire whenever the planet is in that sign. **No chart needed.**

**Total rules: 9 planets × 12 signs = 108 sign-level rules.**

### Layer 2: Planet-in-Nakshatra Effects

Even more granular. Each planet in each of 27 nakshatras has effects.
Slow planets spend weeks-to-months per nakshatra, creating sub-periods
within their sign transit.

Example: Saturn in Pisces spans 3 nakshatras:
- Saturn in Purva Bhadrapada (Jupiter's nakshatra): institutional crisis
- Saturn in Uttara Bhadrapada (Saturn's own nakshatra): deep structural change
- Saturn in Revati (Mercury's nakshatra): communication/trade disruption

This gives NATURAL sub-periods without needing any dasha system.
The nakshatras ARE the timing mechanism.

**Saturn spends ~337 days per nakshatra.**
**Jupiter spends ~162 days per nakshatra.**
**Mars spends ~27 days per nakshatra (when direct).**

These create nested timing cycles:
```
Saturn sign transit (2.5 yrs)
  └─ Saturn nakshatra transit (~1 yr each, 3 per sign)
       └─ Jupiter sign transit (~1 yr)
            └─ Jupiter nakshatra transit (~5 months)
                 └─ Mars sign transit (~2 months)
                      └─ Mars nakshatra transit (~1 month)
                           └─ Sun/Moon daily nakshatra (triggers)
```

**Total rules: 7 planets × 27 nakshatras = 189 nakshatra-level rules.**
(Rahu/Ketu are handled separately — their sign transit IS 18 months.)

### Layer 3: Conjunctions (Grahayuddha — Planetary War)

When two planets come within 1° (some texts say same sign), they're in
"war." The winner is determined by:
- **Northern latitude** (higher = stronger) — the planet farther north wins
- **Brightness** (brighter = stronger)
- **Retrograde** planet is considered stronger (fighting back)

The winner's significations **prosper**. The loser's **suffer**.

Example: Mars conjunct Saturn in Pisces
- If Mars wins → military dominates government, forceful action
- If Saturn wins → government suppresses military, restrictions prevail
- Both in Pisces → the conflict plays out in H12 domains (foreign, exile, loss)
  AND in Koorma Pisces regions (Middle East, Oceania)

**Total: C(9,2) = 36 possible planet pairs, each with winner/loser effects.**

### Layer 4: Aspects (Drishti)

NOT the hybrid orb-based system we built. Classical Vedic aspects:
- ALL planets aspect the 7th sign from themselves (opposition)
- Mars ALSO aspects 4th and 8th signs
- Jupiter ALSO aspects 5th and 9th signs
- Saturn ALSO aspects 3rd and 10th signs
- Rahu/Ketu aspect 5th and 9th signs

Sign-based. Binary. No orbs. If Jupiter is in Gemini, it aspects
Sagittarius (7th), Libra (5th), Aquarius (9th). Period.

The aspect creates a LINK between the domains of the aspecting sign
and the aspected sign. It doesn't create effects on its own — it
modifies and connects the sign-level effects.

### Layer 5: Dignities (Quality Modifier)

Dignity doesn't create effects — it MODIFIES them:
- **Exalted** planet → its sign-level effects are INTENSELY positive
- **Debilitated** planet → its sign-level effects are INTENSELY negative
- **Own sign** → effects manifest naturally, as described
- **Friendly/neutral/enemy** → gradations in between
- **Combust** (too close to Sun) → effects are HIDDEN or suppressed
- **Retrograde** → effects are INTERNALIZED, delayed, then intense

### Layer 6: Koorma Chakra (Geographic Mapping)

This is the spatial layer. Every sign is mapped to world regions.
When a planet's effects fire in a sign, those effects hit those regions.

The Koorma Chakra from classical texts (modernized somewhat):

| Sign | Classical Regions | Modern Mapping |
|---|---|---|
| Aries | Kalinga, Panchala | Central India, Iran, UK, Germany |
| Taurus | Kamboja, Gandhara | Afghanistan, Ukraine, Ireland |
| Gemini | Kuru, Panchala | NE USA, Belgium, Egypt, Sardinia |
| Cancer | Kalinga, Vanga | E India, Netherlands, Scotland |
| Leo | Madhya-desha | France, Italy, Romania, Bohemia |
| Virgo | Mlechha-desha | Turkey, Greece, Caribbean, Croatia |
| Libra | Sindh, Kashmir | China (trade), Japan, Argentina, Austria |
| Scorpio | Surashtra | N Africa, Norway, Korea, Bavaria |
| Sagittarius | Yavana-desha | Spain, Australia, Arabia, Hungary |
| Capricorn | Dravida | S India, Germany, Mexico, Afghanistan |
| Aquarius | Mleccha-desha | Russia, Sweden, Ethiopia, Poland |
| Pisces | Romaka-desha | Portugal, Middle East, Oceania |

**NOTE:** These mappings are approximate and debated. Different commentators
give different assignments. For v1, we use a consensus mapping and note
the uncertainty. The system should support multiple Koorma traditions.

### Layer 7: Eclipses

Eclipses are DISRUPTION events. The effects depend on:
1. **Sign of eclipse** → which domains and regions disrupted
2. **Duration** → hours of eclipse = months of effects
3. **Visibility** → regions where eclipse is visible are most affected
4. **Planets aspecting/conjoining the eclipse point** → nature of disruption
5. **Solar vs lunar**:
   - Solar: authority, rulers, government disrupted
   - Lunar: masses, public mood, agriculture disrupted

### Layer 8: Speed and Station

A planet's speed through the zodiac modifies WHEN effects manifest:
- **Fast** (above average daily motion) → effects come quickly
- **Slow** (below average) → effects build gradually
- **Stationary** (at retrograde/direct station) → effects peak and persist
- **Retrograde** → effects replay, reverse, or intensify past themes

### Layer 9: Samvatsara (60-Year Cycle)

Jupiter completes the zodiac in ~12 years. Combined with the 5 elements
(and some variations), this creates a 60-year cycle where each year has
a name and character. The current year's character provides background context.

---

## What This Means for Our System

### The Core Insight

**The system is a deterministic rules engine, not a chart interpretation system.**

Input: planetary positions (which we have)
Rules: Brihat Samhita effects tables (which we need to encode)
Output: active effects with domains, regions, and intensities

The LLM's job is SYNTHESIS and WRITING, not ASTROLOGY.
The astrology is done by the rules engine.

### What Fires When

At any given moment, the following rules are active:
- 9 planets × 1 sign each = 9 sign-level effects (ALWAYS active)
- 9 planets × 1 nakshatra each = 9 nakshatra-level effects (ALWAYS active)
- N active aspects between planets (typically 10-20)
- 0-3 conjunctions/planetary wars
- 0-1 eclipses (within effect window)
- 9 dignity states (modifier on each planet's effects)
- 9 speed/direction states (modifier on each planet's effects)
- 12 Koorma regions activated by occupied signs

That's roughly 50-70 active rules AT ALL TIMES.

### What Changes (Events)

Analysis should be EVENT-DRIVEN — triggered when something CHANGES:

| Event Type | Frequency | Significance |
|---|---|---|
| Slow planet ingress (new sign) | ~4-6/year | ★★★★★ Major theme shift |
| Slow planet nakshatra change | ~15-20/year | ★★★★ Sub-theme shift |
| Aspect perfection (exact) | ~30-50/year | ★★★ Connection peaks |
| Planetary station (retro/direct) | ~10/year | ★★★★ Reversal point |
| Eclipse | 4-6/year | ★★★★★ Disruption window |
| Planetary war (within 1°) | ~5-10/year | ★★★★ Dominance battle |
| Fast planet ingress | ~50-60/year | ★★ Trigger on slow-planet themes |
| Moon nakshatra transit | ~365/year | ★ Daily trigger/activation |

**~140-180 significant sky events per year ≈ ~3 per week on average.**

This is the natural cadence. Not daily (too noisy). Not monthly (too slow).
About weekly, driven by WHAT CHANGED, not a fixed schedule.

---

## What Varahamihira Would Build With AI Agents

He was a mathematician, astronomer, and pattern-matcher. With AI agents,
he'd build a system that does what he did — but faster, with memory,
and covering the entire world simultaneously.

### Agent Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     THE SKY (Ephemeris Data)                     │
│  Deterministic. Known for 1000 years forward and back.          │
│  Input: just longitude, speed, direction for 9 planets.         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
           ┌───────────────▼───────────────┐
           │     AGENT 1: SKY WATCHER      │
           │     (Change Detection)         │
           │                               │
           │  Monitors planetary positions  │
           │  Detects: ingresses, aspects,  │
           │  stations, wars, eclipses      │
           │  Outputs: "EVENT happened"     │
           │                               │
           │  Runs: continuously or daily   │
           │  Cost: ZERO (pure math)        │
           └───────────────┬───────────────┘
                           │ events
           ┌───────────────▼───────────────┐
           │    AGENT 2: RULE APPLIER      │
           │    (Brihat Samhita Engine)     │
           │                               │
           │  For each active planet/sign:  │
           │    → Look up BS effects table  │
           │    → Apply dignity modifier    │
           │    → Apply speed modifier      │
           │    → Apply aspect connections  │
           │    → Map to Koorma regions     │
           │                               │
           │  Output: scored effects list   │
           │  { domain, region, intensity,  │
           │    direction, source_rule }    │
           │                               │
           │  Cost: ZERO (table lookup)     │
           └───────────────┬───────────────┘
                           │ scored effects
           ┌───────────────▼───────────────┐
           │   AGENT 3: PATTERN MATCHER    │
           │   (Historical Memory)          │
           │                               │
           │  "When was the sky last like   │
           │   this? What happened then?"   │
           │                               │
           │  Searches: past configurations │
           │  Matches: similar sign/nak     │
           │    placements for slow planets │
           │  Returns: historical parallels │
           │    with what actually happened │
           │                               │
           │  Example: "Saturn was last in  │
           │  Pisces 1994-1997. Events:     │
           │  Rwanda genocide, Oklahoma     │
           │  bombing, Kobe earthquake."    │
           │                               │
           │  Cost: DB lookup, maybe LLM    │
           │  for summarizing past events   │
           └───────────────┬───────────────┘
                           │ historical parallels
           ┌───────────────▼───────────────┐
           │  AGENT 4: NEWS CORRELATOR     │
           │  (Reality Check)               │
           │                               │
           │  Fetches current news          │
           │  Classifies by domain + region │
           │  Matches news to active rules: │
           │    "Rule says H7 (foreign) in  │
           │     Pisces regions stressed.   │
           │     News: 'Iran sanctions.'"   │
           │                               │
           │  Also: retrodiction            │
           │    "Last week we predicted X.  │
           │     This week, Y happened.     │
           │     Match score: 0.8"          │
           │                               │
           │  Cost: news API + light LLM    │
           └───────────────┬───────────────┘
                           │ correlated evidence
           ┌───────────────▼───────────────┐
           │   AGENT 5: UPCOMING SCANNER   │
           │   (What's Next)                │
           │                               │
           │  Scans future positions for    │
           │  upcoming events:              │
           │    "Mars enters Aries in 12    │
           │     days → martial energy in   │
           │     Aries/Koorma regions"      │
           │    "Jupiter-Saturn trine       │
           │     perfects in 3 weeks"       │
           │                               │
           │  Pre-applies BS rules to       │
           │  upcoming configurations       │
           │                               │
           │  Cost: ZERO (pure math)        │
           └───────────────┬───────────────┘
                           │ future signals
           ┌───────────────▼───────────────┐
           │    AGENT 6: SYNTHESIZER       │
           │    (The Writer — LLM)          │
           │                               │
           │  Receives:                     │
           │    - Current active rules      │
           │    - What changed this week    │
           │    - Historical parallels      │
           │    - News correlations         │
           │    - Upcoming events           │
           │    - Past prediction scores    │
           │                               │
           │  Produces:                     │
           │    - Narrative analysis         │
           │    - 3-5 falsifiable predictions│
           │    - Regional focus areas      │
           │    - Retrodiction report       │
           │                               │
           │  THIS is the only LLM call.    │
           │  Everything before is math     │
           │  and table lookups.            │
           └───────────────┬───────────────┘
                           │
           ┌───────────────▼───────────────┐
           │   AGENT 7: VALIDATOR          │
           │   (Quality Gate)               │
           │                               │
           │  Checks predictions:           │
           │    ✓ References specific rule? │
           │    ✓ Names specific region?    │
           │    ✓ Has timeframe?            │
           │    ✓ Is falsifiable?           │
           │    ✓ Different from last week? │
           │    ✗ Reject if vague           │
           │    ✗ Reject if contradicts     │
           │      active rules              │
           │                               │
           │  Cost: rule-based checks       │
           └───────────────────────────────┘
```

### The Key Difference From What We Have

**Current system:** Sky positions → signal engine → LLM does the astrology → predictions
**Varahamihira's system:** Sky positions → rules engine does the astrology → LLM writes the narrative

The LLM never decides what Saturn in Pisces means. The rules engine knows.
The LLM's job is to weave 50 active rules into a readable story,
connect them to news, and articulate predictions that the rules imply.

---

## The Rules Database: Heart of the System

This is the big build. We need to encode the Brihat Samhita effects.

### Structure

```javascript
// Each rule: what happens when planet P is in sign/nakshatra S
{
  planet: "Saturn",
  sign: "Pisces",           // or nakshatra: "Uttara Bhadrapada"
  effects: [
    {
      domain: "maritime",
      direction: "negative",  // positive, negative, mixed
      description: "Maritime trade disrupted, coastal flooding",
      intensity: 0.8,         // base intensity (modified by dignity/speed)
      regions: ["Pisces"],    // Koorma regions for this sign
    },
    {
      domain: "religion",
      direction: "negative",
      description: "Religious institutions face scandal, spiritual leaders under pressure",
      intensity: 0.7,
      regions: ["Pisces"],
    },
  ],
  // Modifier when planet is in specific dignity
  dignityModifiers: {
    exalted: { multiplier: 1.5, note: "Effects are powerfully constructive" },
    debilitated: { multiplier: 1.5, note: "Effects are powerfully destructive" },
    own_sign: { multiplier: 1.2, note: "Effects manifest naturally" },
    retrograde: { multiplier: 1.3, note: "Effects intensify, revisit old themes" },
  },
  // Classical source reference
  source: "Brihat Samhita Ch.5, Shlokas 28-30",
}
```

### How Many Rules?

| Category | Count | Source |
|---|---|---|
| Planet × Sign (mundane effects) | 108 | BS Ch.5-12 |
| Planet × Nakshatra (sub-period effects) | 189 | BS + Saravali |
| Conjunction effects (planet pairs) | 36 | BS Ch.17 |
| Aspect modifications | ~50 | BS + general principles |
| Eclipse effects by sign | 12 | BS Ch.5 |
| Koorma Chakra mapping | 12 | BS Ch.14 |
| Dignity modifiers | 42 (7 planets × 6 dignities) | BPHS general |
| **Total** | **~449** | |

This is finite. Encodeable. A weekend of careful work with the texts.
And once encoded, it NEVER changes — these are fixed classical rules.

### The Conjunction Rules (Most Powerful)

From BS Ch.17, planetary conjunctions carry the strongest effects:

| Pair | Classical Effect |
|---|---|
| Jupiter + Saturn | Governance restructuring, religious reform, economic cycles |
| Mars + Saturn | War, destruction, natural disaster, building collapse |
| Mars + Jupiter | Military expansion, religious conflict, righteous war |
| Sun + Saturn | Authority challenged, ruler's health, father figures |
| Venus + Saturn | Art/beauty restricted, marriage delays, famine |
| Mercury + Saturn | Communication blocked, trade halted, education disrupted |
| Mars + Rahu | Sudden violence, explosions, unconventional warfare |
| Jupiter + Rahu | Religious deception, cult activity, false gurus |
| Saturn + Rahu | Mass suffering, epidemics, institutional collapse |

These fire when the planets are in the same sign (conjunction)
or within 1° (planetary war — then winner/loser matters).

---

## Mapping to What We Already Have

### Already Built ✅
- Sky positions for 181 days ✅
- Sign detection from longitude ✅
- Nakshatra detection from longitude ✅ (`vedic_utils.js`)
- Dignity calculation (exalted/debilitated/etc.) ✅ (`vedic_analysis.js`)
- Aspect detection (partially — needs Vedic-only cleanup) ⚠️
- Conjunction detection ✅ (`signal_engine.js`)
- Planetary war detection ✅ (`vedic_yogas.js`)
- Eclipse detection ✅ (found in sky data)
- Retrograde detection ✅
- Combustion detection ✅
- Ingress detection ✅
- Station detection ✅
- Ashtakavarga tables ✅ (`vedic_analysis.js`)
- News feed ✅ (Google News RSS)

### Needs Building 🔨
- **Brihat Samhita rules database** — the 449 rules
- **Koorma Chakra mapping** — sign → regions table
- **Rule application engine** — apply rules to current positions
- **Historical pattern memory** — past similar configurations
- **News domain classifier** — headline → house/domain mapping
- **Retrodiction engine** — match predictions to outcomes
- **Upcoming events pre-computation** — future rules that will fire
- **Weekly change aggregation** — what's different from last week
- **Synthesis prompt** — structured input for LLM writer

### Should Be Removed/Replaced 🗑️
- Western aspects (sextile, square, trine) — not in classical system
- Orb-based aspect calculations — classical is sign-based
- The LLM "astrologer" prompt — LLM should be writer, not analyst
- Fixed-intensity scoring — should come from dignity × rules, not arbitrary weights
- Mesha Sankranti as primary timing — it's secondary at best

---

## Implementation Plan (Revised)

### Phase 1: Rules Database + Koorma (3-4 days)

The Brihat Samhita effects tables. This is the core IP.

```
mundane/
  rules/
    planet_sign_effects.js    108 rules: planet × sign → effects
    planet_nakshatra_effects.js  189 rules: planet × nakshatra → effects  
    conjunction_effects.js     36 rules: planet pairs → effects
    eclipse_effects.js         12 rules: eclipse by sign → effects
    koorma_chakra.js           12 entries: sign → world regions
    dignity_modifiers.js       Exalted/debilitated/retro modifiers
    index.js                   Lookup functions
```

Each rule is a data object with:
- Affected domains
- Direction (positive/negative/mixed)
- Base intensity
- Description (for LLM context)
- Source reference (BS chapter/shloka)

### Phase 2: Rule Application Engine (3-4 days)

Takes current sky positions + rules database → scored effects list.

```
mundane/
  engine/
    sky_state.js              Current state of all 9 planets
    rule_applier.js           Apply all matching rules to current sky
    change_detector.js        Diff this week vs last week
    future_scanner.js         What rules will fire in coming weeks
    strength_scorer.js        Dignity × speed × aspect → final intensity
```

Output: a ranked list of active effects with domains, regions, intensities.
This is the "Varahamihira output" — what the astrologer would say
before any modern interpretation or news correlation.

### Phase 3: Historical Memory (2-3 days)

When was the sky last like this?

```
mundane/
  memory/
    historical_patterns.js    Known past configurations + events
    similarity_search.js      Find similar sky states in history
```

Example entries:
```javascript
{
  period: "1994-1997",
  config: "Saturn in Pisces",
  events: [
    "Rwanda genocide (1994)",
    "Kobe earthquake (1995)",
    "Oklahoma City bombing (1995)",
    "Floods in China (1996)",
  ],
  regions_affected: ["Middle East", "Oceania", "East Africa"],
  koorma_match: true,  // Did events match Koorma predictions?
}
```

This is a manually curated database for now. 
Later, an agent can build it by searching historical events.

### Phase 4: News Intelligence (2-3 days)

Already partially built. Enhance with:
- Domain classification (headline → house)
- Region extraction (headline → country → Koorma sign)
- Retrodiction (match last predictions to this week's news)

### Phase 5: Synthesis Agent (3-4 days)

The LLM writer. Receives ALL pre-computed data and writes.

```
mundane/
  synthesis/
    prompt_builder.js         Structure all agent outputs into prompt
    writer.js                 LLM call — narrative + predictions
    validator.js              Quality gate on predictions
```

The prompt is structured, NOT open-ended:

```
You are a writer synthesizing pre-computed Vedic mundane astrology analysis.
All astrological judgments have been made by the rules engine.
Your job: weave them into readable narrative and articulate predictions.

## ACTIVE RULES (from Brihat Samhita)
[Rule 1: Saturn in Pisces → maritime disruption, religious stress. Intensity: 8/10]
[Rule 2: Mars in Pisces → naval conflict, port fires. Intensity: 6/10]
[Rule 3: Mercury debilitated in Pisces → trade deception. Intensity: 7/10]

## WHAT CHANGED THIS WEEK
[Mars entered Pisces on Monday → activated Rule 2]
[Mercury-Saturn conjunction perfected → trade+government crisis in Pisces regions]

## GEOGRAPHIC FOCUS (Koorma)
[Pisces active (Saturn+Mars+Mercury): Middle East, Portugal, Oceania]
[Aquarius active (Rahu): Russia, Sweden, Ethiopia]

## HISTORICAL PARALLEL
[Saturn was last in Pisces 1994-1997. Events: ...]
[Mars last conjoined Saturn in Pisces: 1996. Events: ...]

## CURRENT NEWS (classified)
[H7/Middle East: "Iran sanctions tightened" — matches Rule 1 + Koorma Pisces]
[H12/Foreign: "Refugee crisis worsens" — matches Saturn in Pisces (H12)]

## UPCOMING EVENTS (next 4 weeks)
[Week +2: Jupiter enters Cancer (EXALTED) → Rule X fires → positive shift]
[Week +3: Mars-Saturn conjunction perfects → Rule Y fires → peak crisis]

## PAST PREDICTION SCORES
[Last week predicted "maritime disruption in ME" — score: 0.8 (confirmed)]
[Last week predicted "tech regulation" — score: 0.2 (not yet)]

Write:
1. Narrative connecting active rules to current events
2. 3-5 predictions, each citing the RULE NUMBER and REGION
3. Retrodiction of last week's predictions
```

### Phase 6: Backtesting (3-4 days)

Run the full pipeline for 52 past weeks. Score it.
This is the only way to know if the rules engine actually works.

---

## What's Different About This Approach

| Aspect | Old System | Varahamihira System |
|---|---|---|
| Core logic | LLM interprets positions | Rules engine applies BS tables |
| Aspects | Western + Vedic hybrid | Vedic sign-based only |
| Timing | Mesha Sankranti dasha | Nakshatra sub-periods (natural) |
| Geography | None | Koorma Chakra (every prediction localized) |
| History | None | Pattern matching against past configurations |
| Predictions | LLM guesses | Rules imply → LLM articulates |
| Validation | None | Retrodiction + backtesting |
| LLM role | Astrologer | Writer/synthesizer |
| Cost per run | LLM-heavy | 1 LLM call (synthesis only) |

---

## The Deepest Insight

Varahamihira wouldn't be impressed by our LLM. He'd be impressed by
having 2 years of pre-computed positions and the ability to run
pattern matching against 2000 years of history in milliseconds.

His workflow would be:

1. **Observe** — "What's in the sky right now?" (Agent 1)
2. **Apply** — "What do my texts say about this configuration?" (Agent 2)  
3. **Remember** — "When did I see this before? What happened?" (Agent 3)
4. **Verify** — "Is the world reflecting what the texts predict?" (Agent 4)
5. **Anticipate** — "What's coming next in the sky?" (Agent 5)
6. **Narrate** — "Here's what it means, in plain language." (Agent 6)
7. **Check** — "Was I right last time?" (Agent 7)

Steps 1-5 are pure computation. Step 6 is where the LLM helps.
Step 7 closes the feedback loop.

**The astrology is in the rules. The AI is in the synthesis.**
