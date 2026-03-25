import 'package:flutter/material.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Horizontal scrollable list of Yoga cards - minimal design
/// Sorted by: Raj Yogas first, then by strength (Strong > Moderate > Mild)
class RajYogasWidget extends StatelessWidget {
  final AstrologyProfile profile;
  final void Function(
    BuildContext context,
    String name,
    String? description,
    String? strength,
    Color accentColor,
    bool isDark, {
    List<dynamic> planets,
    List<dynamic> houses,
    Map<String, dynamic>? yogaData,
  })? onYogaTap;

  const RajYogasWidget({
    super.key,
    required this.profile,
    this.onYogaTap,
  });

  /// Check if yoga name indicates a Raj Yoga (royal/important)
  static bool isRajYoga(String name) {
    final nameLower = name.toLowerCase();
    return nameLower.contains('raj') ||
        nameLower.contains('gaja kesari') ||
        nameLower.contains('hamsa') ||
        nameLower.contains('malavya') ||
        nameLower.contains('ruchaka') ||
        nameLower.contains('bhadra') ||
        nameLower.contains('shasha') ||
        nameLower.contains('sasa') ||
        nameLower.contains('pancha mahapurusha') ||
        nameLower.contains('lakshmi') ||
        nameLower.contains('laxmi');
  }

  /// Get strength priority for sorting (higher = more important)
  static int _getStrengthPriority(String? strength) {
    switch (strength?.toLowerCase()) {
      case 'strong':
      case 'high':
      case 'powerful':
        return 3;
      case 'moderate':
      case 'medium':
      case 'active':
        return 2;
      case 'mild':
      case 'weak':
      case 'low':
        return 1;
      default:
        return 2;
    }
  }

  /// Get color based on strength
  static Color getStrengthColor(String? strength, bool isDark) {
    switch (strength?.toLowerCase()) {
      case 'strong':
      case 'high':
      case 'powerful':
        return isDark ? const Color(0xFFFFD700) : const Color(0xFFB8860B);
      case 'moderate':
      case 'medium':
      case 'active':
        return isDark ? const Color(0xFFD4AF37) : const Color(0xFFC49B3A);
      case 'mild':
      case 'weak':
      case 'low':
        return isDark ? const Color(0xFFBFA34D) : const Color(0xFFD4A84B);
      default:
        return isDark ? const Color(0xFFD4AF37) : const Color(0xFFB8860B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rajYogas = profile.rajYogas;

    AppLogger.d('🔮 Raj Yogas: ${rajYogas?.length ?? 0} from profile.rajYogas',
        category: LogCategory.navigation,
        data: {'hasYogas': rajYogas != null, 'count': rajYogas?.length ?? 0});

    if (rajYogas != null && rajYogas.isNotEmpty) {
      return _buildYogasUI(context, rajYogas, isDark);
    }

    // FALLBACK: Legacy support
    final rajYogaList = <Map<String, dynamic>>[];
    final yogasDetailed = profile.yogasDetailed;
    if (yogasDetailed != null && yogasDetailed.isNotEmpty) {
      for (final key in yogasDetailed.keys) {
        final keyLower = key.toString().toLowerCase();
        final value = yogasDetailed[key];

        if (keyLower.contains('raj') || keyLower.contains('yoga')) {
          String yogaName = key
              .toString()
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) =>
                  w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
              .join(' ');

          String description = 'Beneficial planetary combination';
          String strength = 'Moderate';

          if (value is Map) {
            description = value['description']?.toString() ?? description;
            strength = value['strength']?.toString() ??
                value['intensity']?.toString() ??
                strength;
            if (value['name'] != null) yogaName = value['name'].toString();
          } else if (value is String && value.isNotEmpty) {
            description = value;
          } else if (value is List) {
            for (final item in value) {
              if (item is Map) {
                rajYogaList.add({
                  'name': item['name']?.toString() ?? 'Yoga',
                  'description': item['description']?.toString() ??
                      'Beneficial combination',
                  'strength': item['strength']?.toString() ?? 'Moderate',
                });
              }
            }
            continue;
          }

          rajYogaList.add({
            'name': yogaName,
            'description': description,
            'strength': strength,
          });
        }
      }
    }

    if (rajYogaList.isNotEmpty) {
      return _buildYogasUI(context, rajYogaList, isDark);
    }

    return const SizedBox.shrink();
  }

  Widget _buildYogasUI(
      BuildContext context, List<Map<String, dynamic>> yogaList, bool isDark) {
    if (yogaList.isEmpty) return const SizedBox.shrink();

    // Sort: Raj Yogas first, then by strength
    yogaList.sort((a, b) {
      final aName = a['name']?.toString() ?? '';
      final bName = b['name']?.toString() ?? '';
      final aIsRaj = isRajYoga(aName);
      final bIsRaj = isRajYoga(bName);

      if (aIsRaj && !bIsRaj) return -1;
      if (!aIsRaj && bIsRaj) return 1;

      final aStrength = _getStrengthPriority(a['strength']?.toString());
      final bStrength = _getStrengthPriority(b['strength']?.toString());
      return bStrength.compareTo(aStrength);
    });

    final screenWidth = MediaQuery.of(context).size.width;
    // Cap card width for web - max 160px per card
    final cardWidth = (screenWidth * 2 / 5).clamp(100.0, 160.0);

    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        itemCount: yogaList.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final yoga = yogaList[index];
          final yogaName = yoga['name']?.toString() ?? 'Yoga';
          final description = yoga['description']?.toString();
          final strength = yoga['strength']?.toString() ?? 'Active';
          final planets = yoga['planets'] as List<dynamic>? ?? [];
          final houses = yoga['houses'] as List<dynamic>? ?? [];
          final yogaColor = getStrengthColor(strength, isDark);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SizedBox(
              width: cardWidth,
              child: Material(
                color: cardColor,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onYogaTap != null
                      ? () => onYogaTap!(
                            context,
                            yogaName,
                            description,
                            strength,
                            yogaColor,
                            isDark,
                            planets: planets,
                            houses: houses,
                            yogaData: yoga,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Center(
                      child: Text(
                        yogaName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: yogaColor,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Helper to get yoga benefit and guidance text
/// Now provides more detailed, context-aware guidance based on yoga data
class YogaBenefits {
  static String getBenefits(String yogaName, {Map<String, dynamic>? yogaData}) {
    final nameLower = yogaName.toLowerCase();
    final strength =
        yogaData?['strength']?.toString().toLowerCase() ?? 'moderate';
    final planets = yogaData?['planets'] as List<dynamic>? ?? [];

    // Panch Mahapurusha Yogas - formed by 5 planets in Kendra in own/exalted sign
    if (nameLower.contains('gaja') || nameLower.contains('kesari')) {
      return strength == 'strong'
          ? 'Powerful wisdom and leadership. Your words carry weight and inspire others. Strong potential for recognition and respect.'
          : 'Natural wisdom, inner strength, and the ability to inspire others. Magnetic presence and respect through character.';
    } else if (nameLower.contains('hamsa') || nameLower.contains('hans')) {
      return 'Inclination toward truth and ethical living. Excellence in education, spirituality, and advisory roles. Natural teacher.';
    } else if (nameLower.contains('malavya')) {
      return 'Venus in strength brings appreciation for beauty, harmony, and meaningful relationships. Natural charm, artistic talents, and material comforts.';
    } else if (nameLower.contains('ruchaka')) {
      return 'Mars in strength provides natural courage and leadership. Success in competitive fields, sports, military, engineering, and positions of responsibility.';
    } else if (nameLower.contains('bhadra')) {
      return 'Mercury in strength gives exceptional communication skills and intellectual abilities. Excellence in learning, writing, business, and analytical work.';
    } else if (nameLower.contains('shasha') || nameLower.contains('sasa')) {
      return 'Saturn in strength builds lasting success through discipline. Achievements are stable and enduring. Authority in traditional fields.';
    } else if (nameLower.contains('lakshmi') || nameLower.contains('laxmi')) {
      return 'Venus-related wealth yoga supports financial wellbeing and material comfort. Potential for abundance through honest effort and good karma.';
    } else if (nameLower.contains('vipreet') ||
        nameLower.contains('vipareeta')) {
      return 'Ability to turn challenges into opportunities. Resilience as your strength—difficult situations become catalysts for growth and success.';
    } else if (nameLower.contains('neecha') && nameLower.contains('bhanga')) {
      return 'Debilitation cancelled! Initial struggles transform into unique strengths. Success often comes in areas where others struggle.';
    } else if (nameLower.contains('dharmakarma')) {
      return 'Powerful alignment of fortune (9th) and action (10th). Your righteous deeds lead to success. Career and destiny work in harmony.';
    } else if (nameLower.contains('dhana') || nameLower.contains('dhan')) {
      return 'Wealth yoga connecting houses 2 and 11. Supports wealth building through ${planets.isNotEmpty ? planets.join(" and ") : "effort"}. Financial stability indicated.';
    } else if (nameLower.contains('budhaditya')) {
      return 'Sun-Mercury conjunction gives sharp intellect, fame through communication, and success in intellectual pursuits.';
    } else if (nameLower.contains('chandra') && nameLower.contains('mangal')) {
      return 'Moon-Mars combination provides wealth through courage and enterprise. Good for business and real estate.';
    } else if (nameLower.contains('adhi')) {
      return 'Benefics in key positions from Moon grant leadership abilities, authority, and command over resources.';
    } else if (nameLower.contains('parashari')) {
      return 'Kendra and Trikona lords in association—one of the most powerful Raj Yogas. Brings authority, position, and success through the right combination of action and fortune.';
    } else if (nameLower == 'raja yoga' ||
        (nameLower.contains('raja yoga') &&
            !nameLower.contains('parashari') &&
            !nameLower.contains('viparita') &&
            !nameLower.contains('neecha'))) {
      return 'Potential for recognition, leadership, and meaningful achievements. ${strength == "strong" ? "This yoga is particularly powerful in your chart." : ""}';
    } else if (nameLower.contains('saraswati')) {
      return 'Jupiter, Venus, and Mercury in auspicious positions support wisdom, learning, eloquence, and artistic or intellectual success.';
    } else if (nameLower.contains('veshi')) {
      return 'Planets in the 2nd house from Sun support wealth, influence, and the ability to grow resources through your own efforts.';
    } else if (nameLower.contains('voshi')) {
      return 'Planets in the 12th from Sun support a charitable nature, spiritual inclination, and the ability to let go and serve.';
    } else if (nameLower.contains('sunapha')) {
      return 'Planets in the 2nd from Moon support self-made success, intelligence, and accumulation of wealth and knowledge.';
    } else if (nameLower.contains('anapha')) {
      return 'Planets in the 12th from Moon support good health, reputation, and benefits from behind-the-scenes or spiritual efforts.';
    } else if (nameLower.contains('durudhara')) {
      return 'Planets flanking Moon give wealth, comforts, vehicles, and a balanced emotional and material life.';
    } else if (nameLower.contains('kahala')) {
      return '4th and 9th lords in kendras support courage, leadership, and success through education and dharma.';
    } else if (nameLower.contains('chamara')) {
      return 'Lagna lord in a kendra aspected by Jupiter supports learning, longevity, and fame through character.';
    } else if (nameLower.contains('yogakaraka')) {
      return 'The Yogakaraka planet for your ascendant is strong—exceptional fortune and success in career and life direction.';
    } else if (nameLower.contains('ubhayachari')) {
      return 'Planets on both sides of Sun support fame, influence, and the ability to shine in public or leadership roles.';
    } else if (nameLower.contains('amala')) {
      return 'Benefic in the 10th house or 10th from Moon supports purity of character, reputation, and fame through righteous action.';
    } else if (nameLower.contains('shakata')) {
      return 'Moon in 6th, 8th, or 12th from Jupiter can bring fluctuating fortunes; resilience and patience help you navigate cycles.';
    } else if (nameLower.contains('guru') && nameLower.contains('mangal')) {
      return 'Jupiter-Mars combination combines wisdom with courage—leadership, discipline, and success in competitive or authoritative fields.';
    }
    return 'Enhances positive outcomes in related areas of life. Supports growth and success.';
  }

  static String getGuidance(String yogaName, {Map<String, dynamic>? yogaData}) {
    final nameLower = yogaName.toLowerCase();
    final isChallenging = yogaData?['isChallenging'] == true;

    if (isChallenging) {
      if (nameLower.contains('kemadruma')) {
        return 'Strengthen Moon through meditation and nurturing relationships. Jupiter\'s aspect or dasha can mitigate this yoga significantly.';
      }
      final planets = yogaData?['planets'] as List<dynamic>? ?? [];
      if (planets.isNotEmpty) {
        return 'Awareness of this pattern helps you work with it consciously. Remedies for ${planets.join(", ")} can help.';
      }
      return 'Awareness of this pattern helps you work with it consciously. Remedies for the involved planets can help.';
    }

    if (nameLower.contains('gaja') || nameLower.contains('kesari')) {
      return 'Nurture wisdom through continuous learning. Lead by example and mentor others. Thursday activities amplify benefits.';
    } else if (nameLower.contains('hamsa') || nameLower.contains('hans')) {
      return 'Pursue higher knowledge and truth. Teaching, counseling, or advisory roles amplify this yoga\'s benefits.';
    } else if (nameLower.contains('malavya')) {
      return 'Engage with arts, beauty, and meaningful relationships. Friday is auspicious. Quality over quantity in all things.';
    } else if (nameLower.contains('ruchaka')) {
      return 'Channel Mars energy into constructive goals. Physical activity, sports, or competitive fields suit you. Tuesday is powerful.';
    } else if (nameLower.contains('bhadra')) {
      return 'Continuous learning and communication amplify benefits. Writing, business, and technology align with your strengths.';
    } else if (nameLower.contains('shasha') || nameLower.contains('sasa')) {
      return 'Trust the process—Saturn rewards patience. Build systematically. Saturday observances strengthen this yoga.';
    } else if (nameLower.contains('dharmakarma')) {
      return 'Align your career with your values. Success comes through righteous action. Don\'t compromise ethics for shortcuts.';
    } else if (nameLower.contains('vipreet') ||
        nameLower.contains('vipareeta')) {
      return 'Don\'t fear challenges—they\'re your growth opportunities. What seems difficult becomes your unique path to success.';
    } else if (nameLower.contains('neecha') && nameLower.contains('bhanga')) {
      return 'Early life may have challenges, but persist. Your unique perspective becomes your greatest asset over time.';
    } else if (nameLower.contains('parashari')) {
      return 'Use your authority with responsibility. When Kendra and Trikona lords align, act in line with dharma—success follows.';
    } else if (nameLower == 'raja yoga' ||
        (nameLower.contains('raja yoga') &&
            !nameLower.contains('parashari') &&
            !nameLower.contains('viparita') &&
            !nameLower.contains('neecha'))) {
      return 'Work consciously with this energy through consistent effort. Dasha periods of involved planets activate the yoga\'s potential.';
    } else if (nameLower.contains('saraswati')) {
      return 'Prioritize learning, teaching, and creative or analytical work. Jupiter, Venus, and Mercury periods are especially favorable.';
    } else if (nameLower.contains('veshi')) {
      return 'Wealth from Sun-related timing and authority. Use your influence wisely; avoid overspending in Sun or 2nd-house dashas.';
    } else if (nameLower.contains('voshi')) {
      return 'Channel 12th-house energy into charity, meditation, or service. Balance material and spiritual pursuits.';
    } else if (nameLower.contains('sunapha')) {
      return 'Build savings and skills in Moon and 2nd-house periods. Self-made success is highlighted—take initiative.';
    } else if (nameLower.contains('anapha')) {
      return 'Health and reputation are supported. Rest and retreat when needed; 12th-from-Moon periods can be good for inner work.';
    } else if (nameLower.contains('durudhara')) {
      return 'Balance emotional and material needs. Moon and the flanking planets\' dashas can bring comforts—use them wisely.';
    } else if (nameLower.contains('kahala')) {
      return 'Stand firm in your values. Education and ethics (4th and 9th) support your leadership.';
    } else if (nameLower.contains('chamara')) {
      return 'Jupiter\'s blessing on your lagna lord is a gift. Learning and integrity strengthen your reputation.';
    } else if (nameLower.contains('yogakaraka')) {
      return 'Your Yogakaraka planet\'s dasha is especially powerful. Align career and major decisions with its positive expression.';
    } else if (nameLower.contains('ubhayachari')) {
      return 'Sun-related dashas can bring visibility. Lead by example and avoid arrogance to sustain fame.';
    } else if (nameLower.contains('amala')) {
      return 'Reputation is built on conduct. Keep actions clean and ethical; 10th-house benefic supports lasting fame.';
    } else if (nameLower.contains('shakata')) {
      return 'Accept cycles of gain and loss. Build resilience; Jupiter remedies and Moon-strengthening practices help.';
    } else if (nameLower.contains('dhana') || nameLower.contains('dhan')) {
      return 'Wealth-building periods are favored when 2nd/11th lords or Jupiter/Venus are active. Save and invest wisely.';
    } else if (nameLower.contains('budhaditya')) {
      return 'Mercury and Sun periods favor communication, intellect, and fame. Writing, teaching, or business can flourish.';
    } else if (nameLower.contains('chandra') && nameLower.contains('mangal')) {
      return 'Moon and Mars dashas can support enterprise and real estate. Balance emotion with action.';
    } else if (nameLower.contains('guru') && nameLower.contains('mangal')) {
      return 'Jupiter-Mars periods favor leadership and discipline. Direct energy toward constructive, ethical goals.';
    }
    return 'Work consciously with this energy through consistent effort. Dasha periods of involved planets activate the yoga\'s potential.';
  }
}
