class CompatibilityLabelUtils {
  static const Map<String, String> kootaExplanations = {
    'Varna':
        'Spiritual compatibility and intellectual harmony. Shows how well two people connect at a spiritual level, examining whether their individual egos, personalities, and spiritual inclinations complement each other.',
    'Vashya':
        'Mutual influence and control dynamics. Measures how naturally people affect and complement each other, indicating the balance of influence, control, and mutual respect in the relationship.',
    'Tara':
        'Health and well-being compatibility. Examines how well two people support each other\'s physical health, mental wellness, and overall vitality throughout life.',
    'Yoni':
        'Physical and intimate compatibility. Represents the natural chemistry, physical attraction, and intimate harmony between two people.',
    'Maitri':
        'Mental compatibility and natural friendship. Based on planetary positions, this shows how well two minds connect, understand each other, and form a natural bond of friendship.',
    'Gana':
        'Temperamental and behavioral compatibility. Indicates how well personalities, behaviors, and natural temperaments align, showing whether people\'s natures complement or conflict.',
    'Rasi':
        'Emotional compatibility and mutual affection. Examines love, emotional bonding, and how well two people support each other emotionally and materially.',
    'Nadi':
        'Genetic compatibility and health of future generations. Examines physical health compatibility, genetic alignment, and the potential health of offspring. Considered one of the most important factors.',
  };

  static const Map<String, String> cosmicLabels = {
    'Exceptional': 'Cosmic Soulmates ✨',
    'Excellent': 'Deep Resonance 💫',
    'Strong': 'Aligned Vibes',
    'Good': 'Growing Together',
    'Moderate': 'Unique Dynamic',
    'Developing': 'Different Orbits',
    'Low': 'Different Orbits',
  };

  static const Map<String, String> lifePhaseLabels = {
    'Excellent Sync': 'Perfect Rhythm 🌙',
    'Strong Sync': 'In Harmony',
    'Good Sync': 'Flowing Together',
    'Moderate Sync': 'Finding Balance',
    'Challenging Sync': 'Growth Phase',
    'Growth Sync': 'Evolving Together',
  };

  static const Map<String, String> pillarDescriptions = {
    'mental':
        'Based on Graha Maitri (Planetary Friendship). Measures how well your ruling planets align, indicating intellectual compatibility and how naturally you understand each other\'s thinking.',
    'temperament':
        'Based on Gana (Nature). Compares your fundamental temperaments - Deva (divine/gentle), Manushya (human/balanced), or Rakshasa (intense/powerful) - to see how well your personalities complement.',
    'flow':
        'Based on Tara (Star). Examines the relationship between your birth stars, revealing the natural energy flow between you and indicating daily harmony.',
    'emotional':
        'Based on Rashi Position (Moon Sign). Measures emotional wavelength compatibility by analyzing the aspect between your Moon signs.',
    'instinctual':
        'Based on Yoni (Animal Instinct). Represents your natural animal instincts and how they align. This affects how naturally you react to situations together and your instinctual chemistry.',
    'energyFlow':
        'Based on Nadi (Energy Channel). Examines the flow of vital energy between you. Different nadis can create a complementary exchange of energy.',
    'coreIdentity':
        'Based on Sun Sign Harmony. Your Sun signs represent your core identity and ego. This shows how your fundamental selves interact and express together.',
    'social':
        'Based on Ascendant (Lagna) Harmony. Your rising signs affect how you present yourselves to the world. This indicates social compatibility and first impressions.',
    'elementBalance':
        'Based on Element Distribution. Examines the balance of Fire, Earth, Air, and Water elements between you, showing how your energies complement.',
    // Legacy key mappings
    'nature':
        'Based on Gana (Nature). Compares your fundamental temperaments - Deva (divine/gentle), Manushya (human/balanced), or Rakshasa (intense/powerful) - to see how well your personalities complement.',
    'harmony':
        'Based on Tara (Star). Examines the relationship between your birth stars, revealing the natural energy flow between you and indicating daily harmony.',
  };

  static String getCreativeCosmicLabel(String label) {
    return cosmicLabels[label] ?? label;
  }

  static String getCreativeLifePhaseLabel(String label) {
    return lifePhaseLabels[label] ?? label;
  }

  static String formatPillarName(String name) {
    if (name.contains(' ') && name.length > 8) {
      return name.replaceFirst(' ', '\n');
    }
    return name;
  }
}
