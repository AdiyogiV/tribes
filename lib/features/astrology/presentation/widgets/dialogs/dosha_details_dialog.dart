import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Minimal dosha details dialog - clean data-rich display
class DoshaDetailsDialog extends StatelessWidget {
  final String name;
  final String? description;
  final String? severity;
  final Color accentColor;
  final bool isDark;
  final String? insight;
  final String? guidance;
  final int? house;
  final String? type;
  final Map<String, dynamic>? doshaData;

  const DoshaDetailsDialog({
    super.key,
    required this.name,
    this.description,
    this.severity,
    required this.accentColor,
    required this.isDark,
    this.insight,
    this.guidance,
    this.house,
    this.type,
    this.doshaData,
  });

  static void show(
    BuildContext context,
    String name,
    String? description,
    String? severity,
    Color accentColor,
    bool isDark, {
    List<dynamic> remedies = const [],
    String? effects,
    IconData? icon,
    String? insight,
    String? guidance,
    int? house,
    String? type,
    Map<String, dynamic>? doshaData,
  }) {
    showDialog(
      context: context,
      builder: (context) => DoshaDetailsDialog(
        name: name,
        description: description,
        severity: severity,
        accentColor: accentColor,
        isDark: isDark,
        insight: insight,
        guidance: guidance,
        house: house,
        type: type,
        doshaData: doshaData,
      ),
    );
  }

  String _getSeverityText() {
    final s = (doshaData?['severity']?.toString() ?? severity ?? 'Present').toLowerCase();
    switch (s) {
      case 'strong':
      case 'high':
        return 'Strong';
      case 'moderate':
      case 'medium':
        return 'Moderate';
      case 'mild':
      case 'weak':
      case 'low':
        return 'Mild';
      default:
        return 'Present';
    }
  }

  String _getHouseName(dynamic h) {
    if (h == null) return '';
    final houseNum = h is int ? h : int.tryParse(h.toString());
    if (houseNum == null) return '';
    const names = {
      1: '1st (Self)', 2: '2nd (Wealth)', 3: '3rd (Courage)', 4: '4th (Home)',
      5: '5th (Children)', 6: '6th (Health)', 7: '7th (Partner)', 8: '8th (Transformation)',
      9: '9th (Fortune)', 10: '10th (Career)', 11: '11th (Gains)', 12: '12th (Liberation)',
    };
    return names[houseNum] ?? '${houseNum}th';
  }

  Map<String, String> _getDoshaDetails() {
    final nameLower = name.toLowerCase();
    
    if (nameLower.contains('mangal') || nameLower.contains('kuja')) {
      final h = doshaData?['mangal_dosha_house'] ?? house;
      final houseName = h != null ? _getHouseName(h) : '';
      final houseNum = h is int ? h : int.tryParse(h?.toString() ?? '');
      final isMitigated = doshaData?['mangal_dosha_mitigated'] == true;
      final mitigation = doshaData?['mangal_dosha_mitigation']?.toString();
      
      // House-specific insights per Vedic tradition
      String houseInsight = insight ?? 'Strong willpower, direct nature. Excels in fitness, competition, engineering, military, leadership.';
      String houseGuidance = guidance ?? 'Practice patience in relationships. Physical exercise balances Mars energy.';
      
      if (houseNum != null) {
        switch (houseNum) {
          case 1:
            houseInsight = 'Strong personality and physical vitality. Natural leader with assertive presence. Athletic potential.';
            houseGuidance = 'Channel energy into leadership roles. Physical activities help balance. Cultivate patience with others.';
            break;
          case 2:
            houseInsight = 'Direct in speech, protective of family. Can be assertive about resources and values.';
            houseGuidance = 'Mindful communication strengthens bonds. This is considered a milder placement.';
            break;
          case 4:
            houseInsight = 'Strong emotions, protective of home and loved ones. May experience property matters.';
            houseGuidance = 'Create harmonious home environment. Gardening or home improvement channels energy positively.';
            break;
          case 7:
            houseInsight = 'Passionate partnerships, seeks dynamic relationship. Attracts strong-willed partners.';
            houseGuidance = 'Open communication is key. Partner with Mangal Dosha or strong Mars can be harmonious.';
            break;
          case 8:
            houseInsight = 'Deep transformative energy, research abilities. Interest in hidden matters.';
            houseGuidance = 'Regular spiritual practice is beneficial. This placement gives profound insights through challenges.';
            break;
          case 12:
            houseInsight = 'Spiritual warrior energy, expenses on good causes. May travel abroad.';
            houseGuidance = 'This is considered milder. Channel Mars into spiritual pursuits or charitable activities.';
            break;
        }
      }
      
      // Add mitigation info if present
      if (isMitigated && mitigation != null) {
        houseGuidance = '$houseGuidance Effect is reduced: $mitigation.';
      }
      
      return {
        'desc': description ?? 'Mars in ${houseName.isNotEmpty ? houseName : "key houses"} brings strong drive and passionate energy.',
        'insight': houseInsight,
        'guidance': houseGuidance,
        'placement': houseName,
      };
    }
    
    if (nameLower.contains('kaal') && nameLower.contains('sarp')) {
      return {
        'desc': description ?? 'All planets between Rahu-Ketu axis. Concentrated karmic pattern.',
        'insight': insight ?? 'Intense focus on specific goals. Success comes in waves. Many achievers have this.',
        'guidance': guidance ?? 'Trust timing. Meditation channels this energy. Breakthroughs can be sudden.',
        'placement': 'Rahu-Ketu Axis',
      };
    }
    
    if (nameLower.contains('pitra')) {
      final t = doshaData?['pitra_dosha_type'] ?? type;
      return {
        'desc': description ?? 'Ancestral karma pattern${t != null ? " ($t)" : ""}. Connection to lineage.',
        'insight': insight ?? 'Deep family connection. Called to honor traditions or heal family patterns.',
        'guidance': guidance ?? 'Stay connected with elders. Charity aligns well. Tarpan is traditional remedy.',
        'placement': t ?? '',
      };
    }
    
    if (nameLower.contains('shani')) {
      final h = doshaData?['shani_dosha_house'] ?? house;
      final fromMoon = doshaData?['shani_from_moon'];
      final houseName = h != null ? _getHouseName(h) : '';
      final houseNum = h is int ? h : int.tryParse(h?.toString() ?? '');
      
      // House-specific insights for Saturn
      String saturnInsight = insight ?? 'Teaches through patience. Achievements built to last. Creates experts and masters.';
      String saturnGuidance = guidance ?? 'Embrace gradual progress. Structure is your ally. Help elderly as remedy.';
      
      if (houseNum != null) {
        switch (houseNum) {
          case 1:
            saturnInsight = 'Serious demeanor, early maturity. Success through persistent effort. Often improves with age.';
            saturnGuidance = 'Don\'t be hard on yourself. Your discipline is a gift. Regular exercise helps maintain vitality.';
            break;
          case 4:
            saturnInsight = 'Deep emotional wisdom, may have responsibilities at home. Strong sense of duty to family.';
            saturnGuidance = 'Create structure in home life. Caring for elderly family members brings blessings.';
            break;
          case 7:
            saturnInsight = 'Seeks committed, mature partnerships. Marriage may come later but tends to be stable.';
            saturnGuidance = 'Don\'t rush relationships. Quality over quantity. Older or mature partners may be compatible.';
            break;
          case 8:
            saturnInsight = 'Research abilities, interest in longevity and hidden matters. Transformations through discipline.';
            saturnGuidance = 'Regular health checkups recommended. Spiritual practices provide strength through challenges.';
            break;
          case 10:
            saturnInsight = 'Career success through hard work. May face delays but builds lasting achievements.';
            saturnGuidance = 'Persistence pays off. Your career legacy will be substantial. Don\'t expect shortcuts.';
            break;
        }
      }
      
      // Add Kantaka Shani info if present
      if (fromMoon != null) {
        saturnGuidance = '$saturnGuidance Saturn is also in Kendra from Moon (Kantaka Shani) - extra patience during Saturn periods.';
      }
      
      return {
        'desc': description ?? 'Saturn influence${houseName.isNotEmpty ? " in $houseName" : ""}${fromMoon != null ? ", $fromMoon from Moon" : ""}.',
        'insight': saturnInsight,
        'guidance': saturnGuidance,
        'placement': houseName,
      };
    }
    
    if (nameLower.contains('grahan')) {
      final t = doshaData?['grahan_type'] ?? type;
      return {
        'desc': description ?? 'Eclipse influence${t != null ? " ($t)" : ""}. Luminary conjunct shadow planet.',
        'insight': insight ?? 'Depth of perception, psychic sensitivity. Healers and researchers have this.',
        'guidance': guidance ?? 'Meditation helps. Avoid major decisions during eclipses. Chant luminary mantras.',
        'placement': t ?? '',
      };
    }
    
    if (nameLower.contains('gandmool')) {
      final nak = doshaData?['gandmool_nakshatra'];
      return {
        'desc': description ?? 'Birth in ${nak ?? "junction"} nakshatra. Transformative energy point.',
        'insight': insight ?? 'Powerful but needs channeling. Many successful people have this.',
        'guidance': guidance ?? 'Gandmool Shanti puja recommended. Nakshatra mantras help.',
        'placement': nak ?? '',
      };
    }
    
    return {
      'desc': description ?? 'Unique planetary pattern adding distinctive qualities.',
      'insight': insight ?? 'Understanding helps work with this energy consciously.',
      'guidance': guidance ?? 'Awareness is key. Appropriate remedies if desired.',
      'placement': '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color cardColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white54 : Colors.black45;
    
    final details = _getDoshaDetails();
    final severityText = _getSeverityText();
    final placement = details['placement'] ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Name + Close
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, size: 20, color: subtleColor),
                  ),
                ],
              ),
              
              // Severity + Placement (if any)
              const SizedBox(height: AppDimensions.spacingSmMd),
              Text(
                '$severityText${placement.isNotEmpty ? ' • $placement' : ''}',
                style: TextStyle(fontSize: 12, color: subtleColor, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: AppDimensions.spacingMdLg),
              
              // Description
              Text(
                details['desc'] ?? '',
                style: TextStyle(fontSize: 13, height: 1.5, color: textColor),
              ),

              const SizedBox(height: AppDimensions.spacingMdLg),
              
              // Insight
              _buildSection('Insight', details['insight'] ?? '', textColor, subtleColor),
              
              const SizedBox(height: AppDimensions.spacingMdSm),
              
              // Guidance
              _buildSection('Guidance', details['guidance'] ?? '', textColor, subtleColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, Color textColor, Color subtleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtleColor, letterSpacing: 0.5),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          content,
          style: TextStyle(fontSize: 12, height: 1.5, color: textColor.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}
