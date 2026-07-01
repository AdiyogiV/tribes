/**
 * ग्रह फल — Graha Phala (Planetary Transit Effects)
 *
 * Brihat Samhita, Chapters 3-11
 *
 *   Ch.3  — आदित्यचार (Aditya-chara): Sun's transit effects
 *   Ch.6  — अङ्गारकचार (Angaaraka-chara): Mars' transit effects
 *   Ch.7  — बुधचार (Budha-chara): Mercury's transit effects
 *   Ch.8  — बृहस्पतिचार (Brihaspati-chara): Jupiter's transit effects
 *   Ch.9  — शुक्रचार (Shukra-chara): Venus' transit effects
 *   Ch.10 — शनिचार (Shani-chara): Saturn's transit effects
 *   Also: Phaladeepika/Saravali for Rahu & Ketu
 *
 * "When Saturn enters Pisces, maritime trade is disrupted,
 *  false prophets arise, and refugees flee their homes."
 *
 * Each effect: { domain, dir: "pos"|"neg"|"mix", desc, weight: 0.1-1.0 }
 *
 * Slow planets (Saturn, Jupiter, Rahu, Ketu) set the YEAR'S BACKGROUND.
 * Fast planets (Mars, Sun, Venus, Mercury) are FOREGROUND TRIGGERS.
 */

// ─── Planet Classification ──────────────────────────────────────────────

export const SLOW_PLANETS = ["Saturn", "Jupiter", "Rahu", "Ketu"];
export const FAST_PLANETS = ["Mars", "Sun", "Venus", "Mercury"];

// ─── Effect Tables ──────────────────────────────────────────────────────
// Planet → Sign → Effects[]

export const GRAHA_PHALA = {

    // ── शनि (Saturn) — BS Ch.10 ────────────────────────────────────────
    // Government, masses, agriculture, discipline, chronic suffering
    Saturn: {
        Aries:       [{ domain: "government",  dir: "neg", desc: "Authority weakened, rulers face opposition", weight: 0.8 },
                      { domain: "military",    dir: "neg", desc: "Army morale low, defense overspending", weight: 0.7 },
                      { domain: "public_mood", dir: "neg", desc: "General restlessness, impatience in populace", weight: 0.7 }],
        Taurus:      [{ domain: "economy",     dir: "neg", desc: "Agricultural losses, food prices rise", weight: 0.9 },
                      { domain: "banking",     dir: "neg", desc: "Banking sector stress, currency instability", weight: 0.8 },
                      { domain: "resources",   dir: "neg", desc: "Scarcity of essential goods, hoarding", weight: 0.7 }],
        Gemini:      [{ domain: "media",       dir: "neg", desc: "Press restrictions, communication breakdowns", weight: 0.7 },
                      { domain: "trade",       dir: "neg", desc: "Trade agreements stall, commerce disrupted", weight: 0.8 },
                      { domain: "transport",   dir: "neg", desc: "Transport infrastructure failures, delays", weight: 0.7 }],
        Cancer:      [{ domain: "public_mood", dir: "neg", desc: "Mass discontent, emotional unrest in populace", weight: 0.9 },
                      { domain: "agriculture", dir: "neg", desc: "Crops fail, water-related disasters", weight: 0.8 },
                      { domain: "real_estate", dir: "neg", desc: "Property market declines, housing crisis", weight: 0.7 }],
        Leo:         [{ domain: "government",  dir: "neg", desc: "Head of state under pressure, loss of prestige", weight: 0.9 },
                      { domain: "entertainment", dir: "neg", desc: "Entertainment industry suffers restrictions", weight: 0.6 },
                      { domain: "diplomacy",   dir: "neg", desc: "Diplomatic failures, loss of international standing", weight: 0.7 }],
        Virgo:       [{ domain: "health",      dir: "neg", desc: "Epidemics, chronic illness rises, healthcare strain", weight: 0.8 },
                      { domain: "labor",       dir: "neg", desc: "Labor unrest, workers' strikes, unemployment", weight: 0.8 },
                      { domain: "military",    dir: "neg", desc: "Military scandals, defense mismanagement", weight: 0.6 }],
        Libra:       [{ domain: "foreign_affairs", dir: "mix", desc: "Saturn exalted — firm but fair diplomacy, treaties enforced", weight: 0.8 },
                      { domain: "judiciary",   dir: "pos", desc: "Justice system strengthened, landmark rulings", weight: 0.7 },
                      { domain: "trade",       dir: "pos", desc: "International trade stabilizes under strict rules", weight: 0.7 }],
        Scorpio:     [{ domain: "crisis",      dir: "neg", desc: "Hidden scandals surface, institutional corruption exposed", weight: 0.9 },
                      { domain: "taxation",    dir: "neg", desc: "Tax burdens increase, financial secrets revealed", weight: 0.8 },
                      { domain: "mortality",   dir: "neg", desc: "Death toll events, mining disasters, underground crises", weight: 0.7 }],
        Sagittarius: [{ domain: "religion",    dir: "neg", desc: "Religious institutions face scandal, dogma challenged", weight: 0.8 },
                      { domain: "judiciary",   dir: "neg", desc: "Legal system delays, justice denied", weight: 0.7 },
                      { domain: "education",   dir: "neg", desc: "Higher education funding cut, universities struggle", weight: 0.7 }],
        Capricorn:   [{ domain: "government",  dir: "mix", desc: "Saturn in own sign — stern governance, structural reforms", weight: 0.9 },
                      { domain: "economy",     dir: "mix", desc: "Austerity measures, painful but necessary restructuring", weight: 0.8 },
                      { domain: "infrastructure", dir: "pos", desc: "Major infrastructure projects, long-term building", weight: 0.7 }],
        Aquarius:    [{ domain: "technology",  dir: "mix", desc: "Saturn in own sign — tech regulation, digital restrictions", weight: 0.8 },
                      { domain: "social_movements", dir: "pos", desc: "Mass movements gain structure, organized protest", weight: 0.8 },
                      { domain: "humanitarian", dir: "mix", desc: "Humanitarian crises but also organized relief", weight: 0.7 }],
        Pisces:      [{ domain: "maritime",    dir: "neg", desc: "Maritime trade disrupted, naval incidents, coastal flooding", weight: 0.8 },
                      { domain: "religion",    dir: "neg", desc: "Spiritual institutions face crisis, false prophets", weight: 0.7 },
                      { domain: "refugees",    dir: "neg", desc: "Refugee crises, exile of leaders, foreign imprisonment", weight: 0.8 },
                      { domain: "health",      dir: "neg", desc: "Waterborne diseases, hospital system strain", weight: 0.7 }],
    },

    // ── बृहस्पति (Jupiter) — BS Ch.8 ───────────────────────────────────
    // Wisdom, law, prosperity, religion, expansion
    Jupiter: {
        Aries:       [{ domain: "military",    dir: "pos", desc: "Righteous military action, defense modernization", weight: 0.7 },
                      { domain: "government",  dir: "pos", desc: "Bold leadership initiatives, new policies launched", weight: 0.7 },
                      { domain: "sports",      dir: "pos", desc: "Athletic achievements, sports events succeed", weight: 0.5 }],
        Taurus:      [{ domain: "economy",     dir: "pos", desc: "Economic growth, agricultural abundance", weight: 0.8 },
                      { domain: "banking",     dir: "pos", desc: "Financial institutions prosper, investments grow", weight: 0.7 },
                      { domain: "culture",     dir: "pos", desc: "Arts flourish, cultural heritage celebrated", weight: 0.6 }],
        Gemini:      [{ domain: "media",       dir: "pos", desc: "Intellectual discourse flourishes, publishing thrives", weight: 0.7 },
                      { domain: "trade",       dir: "pos", desc: "Trade agreements expand, commerce grows", weight: 0.7 },
                      { domain: "education",   dir: "pos", desc: "Educational initiatives succeed, scholarship", weight: 0.6 }],
        Cancer:      [{ domain: "public_mood", dir: "pos", desc: "Jupiter EXALTED — masses prosper, general happiness", weight: 1.0 },
                      { domain: "agriculture", dir: "pos", desc: "Bountiful harvests, water resources abundant", weight: 0.9 },
                      { domain: "real_estate", dir: "pos", desc: "Property values rise, housing prosperity", weight: 0.8 },
                      { domain: "religion",    dir: "pos", desc: "Religious harmony, spiritual revival", weight: 0.8 }],
        Leo:         [{ domain: "government",  dir: "pos", desc: "Wise leadership, ruler gains respect", weight: 0.8 },
                      { domain: "diplomacy",   dir: "pos", desc: "Successful diplomacy, international prestige", weight: 0.7 },
                      { domain: "entertainment", dir: "pos", desc: "Creative arts boom, celebrations", weight: 0.6 }],
        Virgo:       [{ domain: "health",      dir: "mix", desc: "Healthcare improvements but also health scares", weight: 0.6 },
                      { domain: "education",   dir: "pos", desc: "Practical education reforms, skill development", weight: 0.7 },
                      { domain: "labor",       dir: "pos", desc: "Employment opportunities increase, service sector grows", weight: 0.6 }],
        Libra:       [{ domain: "foreign_affairs", dir: "pos", desc: "Peace treaties, diplomatic breakthroughs", weight: 0.8 },
                      { domain: "judiciary",   dir: "pos", desc: "Justice served, fair legal outcomes", weight: 0.7 },
                      { domain: "trade",       dir: "pos", desc: "International partnerships flourish", weight: 0.7 }],
        Scorpio:     [{ domain: "research",    dir: "pos", desc: "Scientific breakthroughs, deep investigation yields results", weight: 0.7 },
                      { domain: "crisis",      dir: "mix", desc: "Crises resolved through wisdom, institutional reform", weight: 0.6 },
                      { domain: "insurance",   dir: "pos", desc: "Insurance/inheritance matters resolve favorably", weight: 0.5 }],
        Sagittarius: [{ domain: "religion",    dir: "pos", desc: "Jupiter in own sign — religious revival, dharma upheld", weight: 0.9 },
                      { domain: "judiciary",   dir: "pos", desc: "Legal system functions well, landmark judgments", weight: 0.8 },
                      { domain: "education",   dir: "pos", desc: "Universities thrive, philosophical discourse", weight: 0.8 }],
        Capricorn:   [{ domain: "government",  dir: "neg", desc: "Jupiter DEBILITATED — governance lacks wisdom", weight: 0.8 },
                      { domain: "religion",    dir: "neg", desc: "Religious hypocrisy exposed, moral decline", weight: 0.7 },
                      { domain: "judiciary",   dir: "neg", desc: "Justice delayed or corrupted", weight: 0.7 }],
        Aquarius:    [{ domain: "technology",  dir: "pos", desc: "Technological wisdom applied for social good", weight: 0.7 },
                      { domain: "humanitarian", dir: "pos", desc: "Humanitarian causes succeed, collective welfare", weight: 0.7 },
                      { domain: "social_movements", dir: "pos", desc: "Progressive reforms gain traction", weight: 0.6 }],
        Pisces:      [{ domain: "religion",    dir: "pos", desc: "Jupiter in own sign — deep spirituality, compassion", weight: 0.9 },
                      { domain: "maritime",    dir: "pos", desc: "Maritime prosperity, ocean resources", weight: 0.7 },
                      { domain: "humanitarian", dir: "pos", desc: "Charitable institutions thrive, empathy rises", weight: 0.8 }],
    },

    // ── राहु (Rahu) — Phaladeepika/Saravali ────────────────────────────
    // Deception, foreign influence, obsession, technology
    Rahu: {
        Aries:       [{ domain: "military",    dir: "neg", desc: "Unconventional warfare, terrorist threats, reckless aggression", weight: 0.8 },
                      { domain: "public_mood", dir: "neg", desc: "Mass anger, mob mentality, identity confusion", weight: 0.7 }],
        Taurus:      [{ domain: "economy",     dir: "neg", desc: "Financial deception, Ponzi schemes, currency manipulation", weight: 0.8 },
                      { domain: "agriculture", dir: "neg", desc: "Food contamination, GMO controversies", weight: 0.6 }],
        Gemini:      [{ domain: "media",       dir: "neg", desc: "Disinformation epidemic, deepfakes, media manipulation", weight: 0.9 },
                      { domain: "technology",  dir: "mix", desc: "Tech innovation but also cyber threats", weight: 0.7 }],
        Cancer:      [{ domain: "public_mood", dir: "neg", desc: "Mass anxiety, paranoia, homeland security fears", weight: 0.8 },
                      { domain: "real_estate", dir: "neg", desc: "Property fraud, housing bubbles", weight: 0.7 }],
        Leo:         [{ domain: "government",  dir: "neg", desc: "Power grabs, authoritarian tendencies, cult of personality", weight: 0.8 },
                      { domain: "entertainment", dir: "mix", desc: "Entertainment obsession, celebrity scandals", weight: 0.6 }],
        Virgo:       [{ domain: "health",      dir: "neg", desc: "Mysterious illnesses, misdiagnosis, pharma scandals", weight: 0.8 },
                      { domain: "labor",       dir: "neg", desc: "Exploitation of workers, illegal labor practices", weight: 0.7 }],
        Libra:       [{ domain: "foreign_affairs", dir: "neg", desc: "Deceptive diplomacy, broken treaties, espionage", weight: 0.8 },
                      { domain: "judiciary",   dir: "neg", desc: "Judicial corruption, false accusations", weight: 0.7 }],
        Scorpio:     [{ domain: "crisis",      dir: "neg", desc: "Rahu co-rules — deep conspiracies surface, power struggles", weight: 0.9 },
                      { domain: "terrorism",   dir: "neg", desc: "Underground threats, bioweapons, nuclear anxiety", weight: 0.8 }],
        Sagittarius: [{ domain: "religion",    dir: "neg", desc: "Religious extremism, false gurus, cult activity", weight: 0.8 },
                      { domain: "education",   dir: "neg", desc: "Academic fraud, credential inflation", weight: 0.6 }],
        Capricorn:   [{ domain: "government",  dir: "neg", desc: "Institutional corruption, shadow governance", weight: 0.8 },
                      { domain: "economy",     dir: "neg", desc: "Economic manipulation by hidden actors", weight: 0.7 }],
        Aquarius:    [{ domain: "technology",  dir: "mix", desc: "Rahu co-rules — tech revolution AND tech chaos", weight: 0.9 },
                      { domain: "social_movements", dir: "neg", desc: "Movements hijacked, revolutionary deception", weight: 0.7 },
                      { domain: "public_mood", dir: "neg", desc: "Mass delusion, conspiracy theories go mainstream", weight: 0.8 }],
        Pisces:      [{ domain: "religion",    dir: "neg", desc: "Spiritual deception, false miracles, cult exploitation", weight: 0.8 },
                      { domain: "refugees",    dir: "neg", desc: "Human trafficking, refugee exploitation", weight: 0.7 },
                      { domain: "maritime",    dir: "neg", desc: "Maritime deception, smuggling, piracy", weight: 0.6 }],
    },

    // ── केतु (Ketu) — Phaladeepika/Saravali ────────────────────────────
    // Liberation, loss, sudden events, past karma
    Ketu: {
        Aries:       [{ domain: "military",    dir: "mix", desc: "Sudden military events, unexpected heroism or defeat", weight: 0.7 },
                      { domain: "public_mood", dir: "mix", desc: "Detachment from nationalism, identity questioning", weight: 0.6 }],
        Taurus:      [{ domain: "economy",     dir: "neg", desc: "Sudden financial losses, detachment from material security", weight: 0.7 },
                      { domain: "agriculture", dir: "neg", desc: "Crop failures from unexpected causes", weight: 0.6 }],
        Gemini:      [{ domain: "media",       dir: "mix", desc: "Media outlets collapse or transform, old formats die", weight: 0.7 },
                      { domain: "trade",       dir: "neg", desc: "Trade routes suddenly disrupted", weight: 0.6 }],
        Cancer:      [{ domain: "public_mood", dir: "neg", desc: "Emotional detachment, homeland nostalgia, displaced people", weight: 0.7 },
                      { domain: "real_estate", dir: "neg", desc: "Property values drop suddenly", weight: 0.6 }],
        Leo:         [{ domain: "government",  dir: "neg", desc: "Sudden loss of leaders, abdication, power vacuum", weight: 0.8 },
                      { domain: "entertainment", dir: "mix", desc: "Entertainment industry disruption, old stars fade", weight: 0.5 }],
        Virgo:       [{ domain: "health",      dir: "neg", desc: "Sudden health crises, diagnostic breakthroughs", weight: 0.7 },
                      { domain: "labor",       dir: "mix", desc: "Workers suddenly walk out, automation displaces labor", weight: 0.6 }],
        Libra:       [{ domain: "foreign_affairs", dir: "neg", desc: "Alliances suddenly break, partnerships dissolve", weight: 0.7 },
                      { domain: "judiciary",   dir: "mix", desc: "Karmic justice — old cases resurface", weight: 0.6 }],
        Scorpio:     [{ domain: "crisis",      dir: "mix", desc: "Ketu co-rules — deep transformation, awakening through crisis", weight: 0.8 },
                      { domain: "mortality",   dir: "neg", desc: "Sudden mass casualty events, natural disasters", weight: 0.7 }],
        Sagittarius: [{ domain: "religion",    dir: "mix", desc: "Spiritual liberation, old religious orders dissolve", weight: 0.7 },
                      { domain: "education",   dir: "mix", desc: "Traditional education disrupted, alternative learning rises", weight: 0.6 }],
        Capricorn:   [{ domain: "government",  dir: "neg", desc: "Government structures suddenly fail or collapse", weight: 0.7 },
                      { domain: "infrastructure", dir: "neg", desc: "Infrastructure failures, old buildings collapse", weight: 0.6 }],
        Aquarius:    [{ domain: "technology",  dir: "mix", desc: "Old technologies die suddenly, paradigm shifts", weight: 0.7 },
                      { domain: "social_movements", dir: "mix", desc: "Movements lose steam or suddenly end", weight: 0.6 }],
        Pisces:      [{ domain: "religion",    dir: "pos", desc: "Ketu exalted — genuine spiritual awakening, mysticism", weight: 0.8 },
                      { domain: "humanitarian", dir: "pos", desc: "Selfless service, detachment from material aid", weight: 0.7 }],
    },

    // ── मङ्गल (Mars) — BS Ch.6 ─────────────────────────────────────────
    // War, fire, aggression, engineering, police
    Mars: {
        Aries:       [{ domain: "military",    dir: "pos", desc: "Mars in own sign — military strength, bold action succeeds", weight: 0.8 },
                      { domain: "government",  dir: "mix", desc: "Aggressive leadership, quick but forceful decisions", weight: 0.6 }],
        Taurus:      [{ domain: "economy",     dir: "neg", desc: "Aggressive economic moves, hostile takeovers, trade wars", weight: 0.7 },
                      { domain: "agriculture", dir: "neg", desc: "Land disputes, fires in agricultural areas", weight: 0.6 }],
        Gemini:      [{ domain: "media",       dir: "neg", desc: "Aggressive rhetoric in media, propaganda, heated debates", weight: 0.7 },
                      { domain: "transport",   dir: "neg", desc: "Transport accidents, road rage incidents", weight: 0.6 }],
        Cancer:      [{ domain: "public_mood", dir: "neg", desc: "Mars DEBILITATED — domestic violence rises, emotional aggression", weight: 0.8 },
                      { domain: "real_estate", dir: "neg", desc: "Property disputes, arson, construction accidents", weight: 0.7 }],
        Leo:         [{ domain: "government",  dir: "mix", desc: "Authoritarian enforcement, police action, executive orders", weight: 0.7 },
                      { domain: "entertainment", dir: "neg", desc: "Violence in public events, stadium incidents", weight: 0.5 }],
        Virgo:       [{ domain: "military",    dir: "mix", desc: "Military precision operations, surgical strikes", weight: 0.7 },
                      { domain: "health",      dir: "neg", desc: "Surgical complications, medical emergencies rise", weight: 0.7 }],
        Libra:       [{ domain: "foreign_affairs", dir: "neg", desc: "Diplomatic conflicts escalate, war threats", weight: 0.8 },
                      { domain: "judiciary",   dir: "neg", desc: "Legal battles intensify, aggressive litigation", weight: 0.6 }],
        Scorpio:     [{ domain: "military",    dir: "pos", desc: "Mars in own sign — military intelligence, covert ops succeed", weight: 0.8 },
                      { domain: "crisis",      dir: "neg", desc: "Hidden violence surfaces, underground explosions", weight: 0.7 }],
        Sagittarius: [{ domain: "religion",    dir: "neg", desc: "Religious violence, militant extremism", weight: 0.7 },
                      { domain: "foreign_affairs", dir: "neg", desc: "International military tensions, border clashes", weight: 0.7 }],
        Capricorn:   [{ domain: "government",  dir: "pos", desc: "Mars EXALTED — decisive governance, effective enforcement", weight: 0.8 },
                      { domain: "infrastructure", dir: "pos", desc: "Major construction projects advance rapidly", weight: 0.7 }],
        Aquarius:    [{ domain: "technology",  dir: "neg", desc: "Cyberattacks, tech infrastructure targeted", weight: 0.7 },
                      { domain: "social_movements", dir: "neg", desc: "Protests turn violent, revolution attempts", weight: 0.7 }],
        Pisces:      [{ domain: "maritime",    dir: "neg", desc: "Naval conflicts, maritime aggression, port fires", weight: 0.7 },
                      { domain: "health",      dir: "neg", desc: "Waterborne disease outbreaks, hospital crises", weight: 0.6 }],
    },

    // ── सूर्य (Sun) — BS Ch.3 ──────────────────────────────────────────
    // Authority, vitality, government, gold, health
    Sun: {
        Aries:       [{ domain: "government",  dir: "pos", desc: "Sun EXALTED — ruler gains strength, new governmental year", weight: 0.8 },
                      { domain: "public_mood", dir: "pos", desc: "National pride, collective confidence rises", weight: 0.7 }],
        Taurus:      [{ domain: "economy",     dir: "pos", desc: "Revenue collection strong, gold prices stable", weight: 0.6 },
                      { domain: "agriculture", dir: "pos", desc: "Good growing season begins, crops thrive", weight: 0.6 }],
        Gemini:      [{ domain: "media",       dir: "pos", desc: "Government communications effective, key announcements", weight: 0.6 },
                      { domain: "trade",       dir: "pos", desc: "Trade policies clarified, commercial activity", weight: 0.5 }],
        Cancer:      [{ domain: "public_mood", dir: "mix", desc: "Ruler focused on domestic issues, emotional leadership", weight: 0.6 },
                      { domain: "real_estate", dir: "pos", desc: "Government housing initiatives, land reforms", weight: 0.5 }],
        Leo:         [{ domain: "government",  dir: "pos", desc: "Sun in own sign — ruler at peak authority, strong governance", weight: 0.8 },
                      { domain: "diplomacy",   dir: "pos", desc: "International prestige high, state visits succeed", weight: 0.7 }],
        Virgo:       [{ domain: "health",      dir: "pos", desc: "Government health initiatives, medical breakthroughs", weight: 0.6 },
                      { domain: "labor",       dir: "pos", desc: "Employment policies, worker welfare programs", weight: 0.5 }],
        Libra:       [{ domain: "government",  dir: "neg", desc: "Sun DEBILITATED — ruler weakened, loss of authority", weight: 0.8 },
                      { domain: "foreign_affairs", dir: "neg", desc: "Diplomatic humiliation, unfavorable treaties", weight: 0.7 }],
        Scorpio:     [{ domain: "crisis",      dir: "mix", desc: "Government secrets revealed, power struggles intensify", weight: 0.7 },
                      { domain: "taxation",    dir: "pos", desc: "Tax reforms, government revenue initiatives", weight: 0.5 }],
        Sagittarius: [{ domain: "religion",    dir: "pos", desc: "Government supports religious/educational institutions", weight: 0.6 },
                      { domain: "judiciary",   dir: "pos", desc: "Legal reforms, constitutional matters highlighted", weight: 0.6 }],
        Capricorn:   [{ domain: "government",  dir: "mix", desc: "Government restructuring, cold/austere leadership", weight: 0.7 },
                      { domain: "economy",     dir: "mix", desc: "Budget announcements, fiscal discipline", weight: 0.6 }],
        Aquarius:    [{ domain: "technology",  dir: "pos", desc: "Government tech initiatives, digital governance", weight: 0.6 },
                      { domain: "social_movements", dir: "mix", desc: "Ruler engages with or opposes popular movements", weight: 0.5 }],
        Pisces:      [{ domain: "government",  dir: "neg", desc: "Ruler's authority dissolves, lack of direction", weight: 0.7 },
                      { domain: "humanitarian", dir: "pos", desc: "Compassionate policies, foreign aid", weight: 0.6 }],
    },

    // ── शुक्र (Venus) — BS Ch.9 ────────────────────────────────────────
    // Arts, luxury, diplomacy, agriculture, beauty
    Venus: {
        Aries:       [{ domain: "diplomacy",   dir: "neg", desc: "Diplomatic impatience, beauty industry disrupted", weight: 0.5 },
                      { domain: "culture",     dir: "mix", desc: "Bold new art forms, controversial expression", weight: 0.5 }],
        Taurus:      [{ domain: "economy",     dir: "pos", desc: "Venus in own sign — luxury markets thrive, currency stable", weight: 0.7 },
                      { domain: "agriculture", dir: "pos", desc: "Good rainfall, crops prosper", weight: 0.7 }],
        Gemini:      [{ domain: "trade",       dir: "pos", desc: "Trade flourishes, commercial partnerships", weight: 0.6 },
                      { domain: "media",       dir: "pos", desc: "Arts and media celebration, literary festivals", weight: 0.5 }],
        Cancer:      [{ domain: "public_mood", dir: "pos", desc: "Domestic comfort, marriage celebrations, emotional harmony", weight: 0.6 },
                      { domain: "agriculture", dir: "pos", desc: "Water resources abundant, good for crops", weight: 0.6 }],
        Leo:         [{ domain: "entertainment", dir: "pos", desc: "Entertainment industry booms, celebrity culture", weight: 0.6 },
                      { domain: "diplomacy",   dir: "pos", desc: "Royal/state celebrations, cultural diplomacy", weight: 0.6 }],
        Virgo:       [{ domain: "health",      dir: "mix", desc: "Venus DEBILITATED — beauty/health industry struggles", weight: 0.6 },
                      { domain: "economy",     dir: "neg", desc: "Luxury markets decline, austerity in consumption", weight: 0.6 }],
        Libra:       [{ domain: "foreign_affairs", dir: "pos", desc: "Venus in own sign — peace treaties, diplomatic breakthroughs", weight: 0.8 },
                      { domain: "culture",     dir: "pos", desc: "Arts renaissance, beauty celebrated", weight: 0.7 }],
        Scorpio:     [{ domain: "crisis",      dir: "neg", desc: "Scandals involving women/luxury, sexual misconduct exposed", weight: 0.7 },
                      { domain: "economy",     dir: "neg", desc: "Hidden financial losses in luxury/entertainment sectors", weight: 0.5 }],
        Sagittarius: [{ domain: "religion",    dir: "pos", desc: "Art in service of faith, religious celebrations", weight: 0.5 },
                      { domain: "foreign_affairs", dir: "pos", desc: "Cultural exchange programs, international arts", weight: 0.6 }],
        Capricorn:   [{ domain: "economy",     dir: "mix", desc: "Luxury meets austerity, practical beauty", weight: 0.5 },
                      { domain: "culture",     dir: "mix", desc: "Traditional arts revived, classical over modern", weight: 0.5 }],
        Aquarius:    [{ domain: "technology",  dir: "pos", desc: "Tech-art convergence, digital beauty, AI art", weight: 0.6 },
                      { domain: "social_movements", dir: "pos", desc: "Women's movements gain momentum", weight: 0.6 }],
        Pisces:      [{ domain: "culture",     dir: "pos", desc: "Venus EXALTED — artistic golden age, music/cinema peak", weight: 0.8 },
                      { domain: "humanitarian", dir: "pos", desc: "Compassionate giving, charity galas succeed", weight: 0.7 }],
    },

    // ── बुध (Mercury) — BS Ch.7 ────────────────────────────────────────
    // Trade, communication, intellect, youth
    Mercury: {
        Aries:       [{ domain: "media",       dir: "mix", desc: "Quick but reckless communications, hasty announcements", weight: 0.5 },
                      { domain: "trade",       dir: "mix", desc: "Fast-moving deals, impulsive trade agreements", weight: 0.5 }],
        Taurus:      [{ domain: "economy",     dir: "pos", desc: "Sound financial communications, steady trade", weight: 0.6 },
                      { domain: "trade",       dir: "pos", desc: "Agricultural trade prospers, commodity markets stable", weight: 0.5 }],
        Gemini:      [{ domain: "media",       dir: "pos", desc: "Mercury in own sign — communication excellence, journalism thrives", weight: 0.7 },
                      { domain: "trade",       dir: "pos", desc: "Commercial innovation, new trade routes", weight: 0.7 }],
        Cancer:      [{ domain: "media",       dir: "mix", desc: "Emotional communication, populist rhetoric", weight: 0.5 },
                      { domain: "education",   dir: "mix", desc: "Education reforms debated, childhood focus", weight: 0.5 }],
        Leo:         [{ domain: "government",  dir: "pos", desc: "Government communications strong, royal proclamations", weight: 0.6 },
                      { domain: "media",       dir: "pos", desc: "Official media effective, state messaging works", weight: 0.5 }],
        Virgo:       [{ domain: "trade",       dir: "pos", desc: "Mercury EXALTED — commerce peaks, analytical precision", weight: 0.8 },
                      { domain: "health",      dir: "pos", desc: "Medical research breakthroughs, diagnostic advances", weight: 0.7 },
                      { domain: "education",   dir: "pos", desc: "Educational excellence, scholarship", weight: 0.6 }],
        Libra:       [{ domain: "trade",       dir: "pos", desc: "Trade diplomacy, commercial treaties", weight: 0.6 },
                      { domain: "judiciary",   dir: "pos", desc: "Legal communications clear, contracts honored", weight: 0.5 }],
        Scorpio:     [{ domain: "media",       dir: "neg", desc: "Investigative journalism exposes secrets, whistleblowers", weight: 0.6 },
                      { domain: "crisis",      dir: "mix", desc: "Intelligence communications, spy revelations", weight: 0.5 }],
        Sagittarius: [{ domain: "education",   dir: "mix", desc: "Philosophical debate, academic disagreements", weight: 0.5 },
                      { domain: "religion",    dir: "mix", desc: "Religious texts reinterpreted, scriptural debates", weight: 0.5 }],
        Capricorn:   [{ domain: "government",  dir: "pos", desc: "Precise government communications, policy details", weight: 0.6 },
                      { domain: "trade",       dir: "mix", desc: "Trade regulated, commercial restrictions", weight: 0.5 }],
        Aquarius:    [{ domain: "technology",  dir: "pos", desc: "Tech innovation, software breakthroughs, AI advances", weight: 0.7 },
                      { domain: "media",       dir: "pos", desc: "Digital media innovation, new platforms", weight: 0.6 }],
        Pisces:      [{ domain: "media",       dir: "neg", desc: "Mercury DEBILITATED — misinformation, confused messaging", weight: 0.8 },
                      { domain: "trade",       dir: "neg", desc: "Trade deals fall through, commercial deception", weight: 0.7 },
                      { domain: "education",   dir: "neg", desc: "Educational standards decline, examination scandals", weight: 0.6 }],
    },
};

/**
 * Read the Graha Phala for given sky positions.
 *
 * @param {Object} positions - { planet: { sign, ... } }
 * @param {Object} [options]
 * @param {string} [options.filter] - "slow", "fast", or "all" (default)
 * @returns {Object[]} Active effects with layer classification
 */
export function readGrahaPhala(positions, options = {}) {
    const filter = options.filter || "all";
    const planets = filter === "slow" ? SLOW_PLANETS
        : filter === "fast" ? FAST_PLANETS
        : [...SLOW_PLANETS, ...FAST_PLANETS];

    const results = [];
    for (const planet of planets) {
        const sign = positions[planet]?.sign;
        const table = GRAHA_PHALA[planet];
        if (!sign || !table?.[sign]) continue;

        const isSlow = SLOW_PLANETS.includes(planet);
        const source = (planet === "Rahu" || planet === "Ketu") ? "Phaladeepika/Saravali" : "Brihat Samhita";

        for (const effect of table[sign]) {
            results.push({
                planet, sign, ...effect,
                ruleId: `${planet.toLowerCase()}_in_${sign.toLowerCase()}`,
                source,
                layer: isSlow ? "slow" : "fast",
            });
        }
    }
    return results;
}

// Backward-compatible aliases
export const getPlanetEffects = readGrahaPhala;
export const getSlowPlanetEffects = (pos) => readGrahaPhala(pos, { filter: "slow" });
export const getFastPlanetEffects = (pos) => readGrahaPhala(pos, { filter: "fast" });
