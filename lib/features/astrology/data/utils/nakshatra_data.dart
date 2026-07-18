// Nakshatra metadata, Tara Bala calculation, and lookup utilities.
//
// Tara Bala (Star Strength) is a Vedic system that assigns a personal
// daily rating based on the Moon's nakshatra relative to the user's
// birth (Janma) nakshatra. The 9 Taras cycle 3× through the 27
// nakshatras, giving each day a unique quality for each person.

/// The nine Tara types, in order from the birth nakshatra outward.
enum TaraType {
  janma, // 0 — Birth star, introspective
  sampat, // 1 — Wealth, favorable
  vipat, // 2 — Danger, caution
  kshema, // 3 — Well-being, favorable
  pratyari, // 4 — Obstacle, caution
  sadhaka, // 5 — Achievement, favorable
  vadha, // 6 — Harm, caution
  mitra, // 7 — Friend, favorable
  paramaMitra, // 8 — Best Friend, most auspicious
}

/// Result of a Tara Bala calculation.
class TaraBala {
  final TaraType type;
  final String name;
  final String meaning;
  final bool isFavorable;
  final String guidance;

  const TaraBala._({
    required this.type,
    required this.name,
    required this.meaning,
    required this.isFavorable,
    required this.guidance,
  });

  /// Calculate Tara Bala from birth nakshatra index to target nakshatra index.
  /// Both are 0-based (0 = Ashwini, 26 = Revati).
  static TaraBala calculate(int birthIndex, int targetIndex) {
    if (birthIndex < 0 || birthIndex > 26 || targetIndex < 0 || targetIndex > 26) {
      return _taras[0];
    }
    final distance = (targetIndex - birthIndex + 27) % 27;
    return _taras[distance % 9];
  }

  static const _taras = [
    TaraBala._(
      type: TaraType.janma,
      name: 'Janma',
      meaning: 'Birth Star',
      isFavorable: true,
      guidance:
          'A day for self-reflection. Your birth star activates — honor your inner nature and core needs.',
    ),
    TaraBala._(
      type: TaraType.sampat,
      name: 'Sampat',
      meaning: 'Wealth',
      isFavorable: true,
      guidance:
          'Prosperity flows easily today. Favorable for financial decisions, investments, and material pursuits.',
    ),
    TaraBala._(
      type: TaraType.vipat,
      name: 'Vipat',
      meaning: 'Danger',
      isFavorable: false,
      guidance:
          'Obstacles may surface. Avoid major decisions and new ventures — focus on routine and careful planning.',
    ),
    TaraBala._(
      type: TaraType.kshema,
      name: 'Kshema',
      meaning: 'Well-being',
      isFavorable: true,
      guidance:
          'Comfort and safety surround you. A good day for important activities, health focus, and personal care.',
    ),
    TaraBala._(
      type: TaraType.pratyari,
      name: 'Pratyari',
      meaning: 'Obstacle',
      isFavorable: false,
      guidance:
          'Opposition energy present. Be diplomatic, avoid confrontations, and postpone critical negotiations.',
    ),
    TaraBala._(
      type: TaraType.sadhaka,
      name: 'Sadhaka',
      meaning: 'Achievement',
      isFavorable: true,
      guidance:
          'Achievement energy peaks. Excellent for launching projects, pursuing goals, and bold initiatives.',
    ),
    TaraBala._(
      type: TaraType.vadha,
      name: 'Vadha',
      meaning: 'Caution',
      isFavorable: false,
      guidance:
          'Proceed mindfully. Not ideal for risky activities — prioritize health, rest, and gentle routines.',
    ),
    TaraBala._(
      type: TaraType.mitra,
      name: 'Mitra',
      meaning: 'Friend',
      isFavorable: true,
      guidance:
          'Social harmony flows naturally. Great for friendships, collaborations, teamwork, and community.',
    ),
    TaraBala._(
      type: TaraType.paramaMitra,
      name: 'Parama Mitra',
      meaning: 'Best Friend',
      isFavorable: true,
      guidance:
          'Your most auspicious star alignment. Deep connections and blessings — whatever you begin today carries grace.',
    ),
  ];
}

/// Metadata for one of the 27 nakshatras.
class NakshatraInfo {
  final int index;
  final String name;
  final String title; // e.g. "The Star of Transport"
  final String description; // One-liner personality
  final String ruler; // Ruling planet
  final String deity; // Presiding deity
  final String nature; // Deva / Manushya / Rakshasa
  final String symbol; // Traditional symbol

  const NakshatraInfo({
    required this.index,
    required this.name,
    required this.title,
    required this.description,
    required this.ruler,
    required this.deity,
    required this.nature,
    required this.symbol,
  });
}

/// Central repository of nakshatra data and lookup utilities.
class NakshatraData {
  NakshatraData._();

  // @formatter:off
  static const all = <NakshatraInfo>[
    NakshatraInfo(index: 0,  name: 'Ashwini',            title: 'The Star of Transport',   description: 'Swift healers with pioneering spirit',           ruler: 'Ketu',    deity: 'Ashwini Kumaras', nature: 'Deva',     symbol: 'Horse Head'),
    NakshatraInfo(index: 1,  name: 'Bharani',            title: 'The Star of Restraint',   description: 'Creative transformers with deep intensity',      ruler: 'Venus',   deity: 'Yama',            nature: 'Manushya', symbol: 'Yoni'),
    NakshatraInfo(index: 2,  name: 'Krittika',           title: 'The Star of Fire',        description: 'Sharp, purifying presence with determination',   ruler: 'Sun',     deity: 'Agni',            nature: 'Rakshasa', symbol: 'Razor'),
    NakshatraInfo(index: 3,  name: 'Rohini',             title: 'The Star of Ascent',      description: 'Naturally creative and magnetic',                ruler: 'Moon',    deity: 'Brahma',          nature: 'Manushya', symbol: 'Ox Cart'),
    NakshatraInfo(index: 4,  name: 'Mrigashira',         title: 'The Searching Star',      description: 'Curious seekers with gentle nature',             ruler: 'Mars',    deity: 'Soma',            nature: 'Deva',     symbol: 'Deer Head'),
    NakshatraInfo(index: 5,  name: 'Ardra',              title: 'The Storm Star',          description: 'Transformative intellect with emotional depth',  ruler: 'Rahu',    deity: 'Rudra',           nature: 'Manushya', symbol: 'Teardrop'),
    NakshatraInfo(index: 6,  name: 'Punarvasu',          title: 'The Star of Renewal',     description: 'Optimistic nurturers with wisdom',               ruler: 'Jupiter', deity: 'Aditi',           nature: 'Deva',     symbol: 'Bow'),
    NakshatraInfo(index: 7,  name: 'Pushya',             title: 'The Nourishing Star',     description: 'Deeply caring and spiritual',                    ruler: 'Saturn',  deity: 'Brihaspati',      nature: 'Deva',     symbol: 'Udder'),
    NakshatraInfo(index: 8,  name: 'Ashlesha',           title: 'The Embracing Star',      description: 'Intuitive and mysteriously perceptive',          ruler: 'Mercury', deity: 'Nagas',           nature: 'Rakshasa', symbol: 'Serpent'),
    NakshatraInfo(index: 9,  name: 'Magha',              title: 'The Royal Star',          description: 'Natural authority and ancestral connection',     ruler: 'Ketu',    deity: 'Pitris',          nature: 'Rakshasa', symbol: 'Throne'),
    NakshatraInfo(index: 10, name: 'Purva Phalguni',     title: 'The Star of Fortune',     description: 'Creative and romantic soul',                     ruler: 'Venus',   deity: 'Bhaga',           nature: 'Manushya', symbol: 'Hammock'),
    NakshatraInfo(index: 11, name: 'Uttara Phalguni',    title: 'The Star of Patronage',   description: 'Generous helper who creates prosperity',         ruler: 'Sun',     deity: 'Aryaman',         nature: 'Manushya', symbol: 'Bed'),
    NakshatraInfo(index: 12, name: 'Hasta',              title: 'The Hand Star',           description: 'Skillful creator with clever mind',              ruler: 'Moon',    deity: 'Savitar',         nature: 'Deva',     symbol: 'Open Hand'),
    NakshatraInfo(index: 13, name: 'Chitra',             title: 'The Bright Star',         description: 'Brilliant visionary with artistic gifts',        ruler: 'Mars',    deity: 'Tvashtar',        nature: 'Rakshasa', symbol: 'Pearl'),
    NakshatraInfo(index: 14, name: 'Swati',              title: 'The Self-Going Star',     description: 'Independent and gracefully balanced',            ruler: 'Rahu',    deity: 'Vayu',            nature: 'Deva',     symbol: 'Coral'),
    NakshatraInfo(index: 15, name: 'Vishakha',           title: 'The Star of Purpose',     description: 'Determined achiever with clear goals',           ruler: 'Jupiter', deity: 'Indra-Agni',      nature: 'Rakshasa', symbol: 'Gateway'),
    NakshatraInfo(index: 16, name: 'Anuradha',           title: 'The Star of Success',     description: 'Devoted friend who achieves goals',              ruler: 'Saturn',  deity: 'Mitra',           nature: 'Deva',     symbol: 'Lotus'),
    NakshatraInfo(index: 17, name: 'Jyeshtha',           title: 'The Elder Star',          description: 'Protective wisdom with natural authority',       ruler: 'Mercury', deity: 'Indra',           nature: 'Rakshasa', symbol: 'Earring'),
    NakshatraInfo(index: 18, name: 'Mula',               title: 'The Root Star',           description: 'Deep investigator who transforms',               ruler: 'Ketu',    deity: 'Nirriti',         nature: 'Rakshasa', symbol: 'Root'),
    NakshatraInfo(index: 19, name: 'Purva Ashadha',      title: 'The Invincible Star',     description: 'Confident warrior who purifies',                 ruler: 'Venus',   deity: 'Apas',            nature: 'Manushya', symbol: 'Fan'),
    NakshatraInfo(index: 20, name: 'Uttara Ashadha',     title: 'The Universal Star',      description: 'Principled leader who endures',                  ruler: 'Sun',     deity: 'Vishvedevas',     nature: 'Manushya', symbol: 'Tusk'),
    NakshatraInfo(index: 21, name: 'Shravana',           title: 'The Star of Learning',    description: 'Wise listener who connects knowledge',           ruler: 'Moon',    deity: 'Vishnu',          nature: 'Deva',     symbol: 'Ear'),
    NakshatraInfo(index: 22, name: 'Dhanishta',          title: 'The Star of Symphony',    description: 'Rhythmic and naturally prosperous',              ruler: 'Mars',    deity: 'Vasus',           nature: 'Rakshasa', symbol: 'Drum'),
    NakshatraInfo(index: 23, name: 'Shatabhisha',        title: 'The Hundred Healers',     description: 'Mysterious healer with independence',            ruler: 'Rahu',    deity: 'Varuna',          nature: 'Rakshasa', symbol: 'Circle'),
    NakshatraInfo(index: 24, name: 'Purva Bhadrapada',   title: 'The Burning Pair',        description: 'Intense spiritual warrior',                      ruler: 'Jupiter', deity: 'Aja Ekapada',     nature: 'Manushya', symbol: 'Sword'),
    NakshatraInfo(index: 25, name: 'Uttara Bhadrapada',  title: 'The Warrior Star',        description: 'Deep wisdom with self-control',                  ruler: 'Saturn',  deity: 'Ahir Budhnya',    nature: 'Manushya', symbol: 'Twins'),
    NakshatraInfo(index: 26, name: 'Revati',             title: 'The Wealthy Star',        description: 'Nurturing soul who guides others',               ruler: 'Mercury', deity: 'Pushan',          nature: 'Deva',     symbol: 'Fish'),
  ];
  // @formatter:on

  /// Spelling aliases → the canonical name used in [all] (lowercased).
  ///
  /// The backend normalizes every nakshatra to its canonical set
  /// (backend/lib/nakshatras.js). The one name that historically differed from
  /// our list is "Moola" (backend) vs "Mula" (here) — that mismatch made
  /// findIndex("Moola") return -1 and silently fall back to the WRONG star for
  /// anyone born under it. This table closes that gap (plus common regional
  /// transliterations) so a real match is found and the fallbacks never fire in
  /// production. Keep in sync with backend NAKSHATRA_ALIASES.
  static const Map<String, String> _aliases = {
    'moola': 'mula', 'mool': 'mula', 'moolam': 'mula',
    'thiruvathira': 'ardra', 'arudra': 'ardra', 'aardra': 'ardra',
    'jyeshta': 'jyeshtha', 'kettai': 'jyeshtha',
    'dhanistha': 'dhanishta', 'avittam': 'dhanishta',
    'shatabhishak': 'shatabhisha', 'satabisha': 'shatabhisha',
    'shravanam': 'shravana', 'thiruvonam': 'shravana',
    'revathi': 'revati', 'visakha': 'vishakha',
    'krithika': 'krittika', 'mrigasira': 'mrigashira',
  };

  /// Fuzzy match — handles spelling variations between backend and our list.
  static int findIndex(String? name) {
    if (name == null || name.isEmpty) return -1;
    var lower = name.toLowerCase().trim();
    // Strip parenthetical alternatives like "Poorva Phalguni(Pubba)".
    lower = lower.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ').trim();
    // Resolve known aliases to the canonical spelling first.
    lower = _aliases[lower] ?? lower;
    for (int i = 0; i < all.length; i++) {
      if (all[i].name.toLowerCase() == lower) return i;
    }
    // Partial match fallback (e.g. "P.Phalguni" vs "Purva Phalguni")
    for (int i = 0; i < all.length; i++) {
      if (all[i].name.toLowerCase().startsWith(lower) ||
          lower.startsWith(all[i].name.toLowerCase())) {
        return i;
      }
    }
    return -1;
  }

  /// Get info by index (0-26). Returns null for invalid index.
  static NakshatraInfo? getInfo(int index) {
    if (index < 0 || index >= all.length) return null;
    return all[index];
  }
}
