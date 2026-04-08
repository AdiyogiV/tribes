import 'package:flutter/material.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/pages/ayurveda/widgets/ayurveda_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CollapsibleRecommendationsCard - Expandable recommendations
// ─────────────────────────────────────────────────────────────────────────────

class CollapsibleRecommendationsCard extends StatefulWidget {
  final String dominantDosha;
  final Map<String, dynamic> recommendations;
  final List<HealthVulnerability>? vulnerabilities;
  final bool isDark;

  const CollapsibleRecommendationsCard({
    super.key,
    required this.dominantDosha,
    required this.recommendations,
    this.vulnerabilities,
    required this.isDark,
  });

  @override
  State<CollapsibleRecommendationsCard> createState() =>
      _CollapsibleRecommendationsCardState();
}

class _CollapsibleRecommendationsCardState
    extends State<CollapsibleRecommendationsCard> {
  bool _foodsExpanded = false;
  bool _lifestyleExpanded = false;
  bool _healthExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.recommendations.isEmpty) return const SizedBox.shrink();

    final c = AppTheme.primaryColor;
    final foods = widget.recommendations['foods'] as Map<String, dynamic>?;
    final lifestyle = widget.recommendations['lifestyle'] as List<dynamic>?;

    return AyurvedaCardContainer(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalized Tips',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Foods section (collapsible)
          if (foods != null)
            _buildCollapsibleSection(
              title: 'Foods to Favor',
              icon: Icons.restaurant_outlined,
              isExpanded: _foodsExpanded,
              onTap: () => setState(() => _foodsExpanded = !_foodsExpanded),
              child: _buildFoodsList(foods),
            ),

          // Lifestyle section (collapsible)
          if (lifestyle != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildCollapsibleSection(
              title: 'Lifestyle Tips',
              icon: Icons.self_improvement_outlined,
              isExpanded: _lifestyleExpanded,
              onTap: () =>
                  setState(() => _lifestyleExpanded = !_lifestyleExpanded),
              child: _buildLifestyleList(lifestyle),
            ),
          ],

          // Health insights (collapsible)
          if (widget.vulnerabilities != null &&
              widget.vulnerabilities!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildCollapsibleSection(
              title: 'Health Insights',
              icon: Icons.favorite_border,
              isExpanded: _healthExpanded,
              onTap: () => setState(() => _healthExpanded = !_healthExpanded),
              child: _buildHealthList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final c = AppTheme.primaryColor;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: c.withValues(alpha: 0.7)),
                const SizedBox(width: AppDimensions.spacingMdSm),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
            child: child,
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildFoodsList(Map<String, dynamic> foods) {
    final favorList =
        (foods['favor'] as List<dynamic>?)?.take(6).toList() ?? [];
    final doshaColor = getDoshaColor(widget.dominantDosha);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: favorList.map((food) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: doshaColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Text(
            food as String,
            style: TextStyle(fontSize: 12, color: doshaColor),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLifestyleList(List<dynamic> lifestyle) {
    return Column(
      children: lifestyle.take(4).map((tip) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 14,
                color: widget.isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Text(
                  tip as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHealthList() {
    return Column(
      children: widget.vulnerabilities!.take(3).map((vuln) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: widget.isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Text(
                  vuln.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
