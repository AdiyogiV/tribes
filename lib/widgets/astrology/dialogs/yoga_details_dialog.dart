import 'package:flutter/material.dart';
import 'package:aurogram/widgets/astrology/cards/raj_yogas_widget.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Minimal yoga details dialog - clean data-rich display
class YogaDetailsDialog extends StatelessWidget {
  final String name;
  final String? description;
  final String? strength;
  final Color accentColor;
  final bool isDark;
  final List<dynamic> planets;
  final List<dynamic> houses;
  final Map<String, dynamic>? yogaData;

  const YogaDetailsDialog({
    super.key,
    required this.name,
    this.description,
    this.strength,
    required this.accentColor,
    required this.isDark,
    this.planets = const [],
    this.houses = const [],
    this.yogaData,
  });

  static void show(
    BuildContext context,
    String name,
    String? description,
    String? strength,
    Color accentColor,
    bool isDark, {
    List<dynamic> planets = const [],
    List<dynamic> houses = const [],
    Map<String, dynamic>? yogaData,
  }) {
    showDialog(
      context: context,
      builder: (context) => YogaDetailsDialog(
        name: name,
        description: description,
        strength: strength,
        accentColor: accentColor,
        isDark: isDark,
        planets: planets,
        houses: houses,
        yogaData: yogaData,
      ),
    );
  }

  String _getYogaType() {
    final type = yogaData?['type']?.toString() ?? '';
    if (type.isNotEmpty) return type;
    
    final nameLower = name.toLowerCase();
    if (nameLower.contains('hamsa') || nameLower.contains('ruchaka') || 
        nameLower.contains('malavya') || nameLower.contains('bhadra') ||
        nameLower.contains('shasha') || nameLower.contains('sasa')) {
      return 'Panch Mahapurusha';
    } else if (nameLower.contains('gaja') || nameLower.contains('kesari')) {
      return 'Lunar Yoga';
    } else if (nameLower.contains('dhan') || nameLower.contains('lakshmi')) {
      return 'Dhana Yoga';
    } else if (nameLower.contains('raj')) {
      return 'Raj Yoga';
    }
    return 'Yoga';
  }

  String _getDescription() {
    final dataDesc = yogaData?['description']?.toString();
    if (dataDesc != null && dataDesc.isNotEmpty) return dataDesc;
    if (description != null && description!.isNotEmpty) return description!;
    return 'Beneficial planetary combination in your chart.';
  }

  List<String> _getPlanets() {
    final dataPlanets = yogaData?['planets'];
    if (dataPlanets is String && dataPlanets.isNotEmpty) {
      return dataPlanets.split(',').map((p) => p.trim()).toList();
    }
    if (dataPlanets is List && dataPlanets.isNotEmpty) {
      return dataPlanets.map((p) => p.toString()).toList();
    }
    if (planets.isNotEmpty) {
      return planets.map((p) => p.toString()).toList();
    }
    return [];
  }

  String _getStrengthText() {
    final s = (yogaData?['strength']?.toString() ?? strength ?? 'Active').toLowerCase();
    switch (s) {
      case 'strong': case 'high': case 'powerful': return 'Strong';
      case 'moderate': case 'medium': case 'active': return 'Moderate';
      case 'mild': case 'weak': case 'low': return 'Mild';
      default: return 'Active';
    }
  }

  String _getPlanetSymbol(String planet) {
    final p = planet.toLowerCase();
    if (p.contains('sun')) return '☉';
    if (p.contains('moon')) return '☽';
    if (p.contains('mars')) return '♂';
    if (p.contains('mercury')) return '☿';
    if (p.contains('jupiter')) return '♃';
    if (p.contains('venus')) return '♀';
    if (p.contains('saturn')) return '♄';
    if (p.contains('rahu')) return '☊';
    if (p.contains('ketu')) return '☋';
    return '★';
  }

  @override
  Widget build(BuildContext context) {
    final Color cardColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white54 : Colors.black45;

    final yogaType = _getYogaType();
    final desc = _getDescription();
    final planetList = _getPlanets();
    final strengthText = _getStrengthText();
    // Pass yogaData to get context-aware guidance
    final benefits = YogaBenefits.getBenefits(name, yogaData: yogaData);
    final guidance = YogaBenefits.getGuidance(name, yogaData: yogaData);

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
              
              // Type + Strength
              const SizedBox(height: AppDimensions.spacingSmMd),
              Text(
                '$yogaType • $strengthText',
                style: TextStyle(fontSize: 12, color: subtleColor, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: AppDimensions.spacingMdLg),
              
              // Formation description
              Text(
                desc,
                style: TextStyle(fontSize: 13, height: 1.5, color: textColor),
              ),

              // Planets involved
              if (planetList.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  'Planets: ${planetList.map((p) => '${_getPlanetSymbol(p)}$p').join(', ')}',
                  style: TextStyle(fontSize: 12, color: subtleColor),
                ),
              ],

              const SizedBox(height: AppDimensions.spacingMdLg),
              
              // Benefits
              _buildSection('Benefits', benefits, textColor, subtleColor),
              
              const SizedBox(height: AppDimensions.spacingMdSm),
              
              // Guidance  
              _buildSection('Guidance', guidance, textColor, subtleColor),
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
