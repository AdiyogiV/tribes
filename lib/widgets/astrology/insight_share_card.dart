import 'package:flutter/material.dart';

/// Utility class for insight card type styling
/// Used by both InsightShareCard and DailyInsightPage share options
class InsightCardTypeStyle {
  final IconData icon;
  final String label;
  final Color accentColor;
  final List<Color> gradientColors;

  const InsightCardTypeStyle({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.gradientColors,
  });

  /// Get style for a card type
  /// Unified style for all cards
  static InsightCardTypeStyle forType(String cardType) {
    // Unified style for all cards
    return const InsightCardTypeStyle(
      icon: Icons.nights_stay_outlined,
      label: "DAILY INSIGHT",
      accentColor: Color(0xFF7FFFD4), // Aqua
      gradientColors: [Color(0xFF1a1a2e), Color(0xFF0f1624), Color(0xFF0a0e17)],
    );
  }
}

/// A beautiful shareable card for daily astrology insights
/// Designed to be captured as an image for social sharing (Instagram Stories, WhatsApp, etc.)
class InsightShareCard extends StatelessWidget {
  final String cardType; // hero, prediction, strength, guidance
  final String title;
  final String content;
  final String? userName;
  final String? moonSign;
  final String? risingSign;
  final String? sunSign;

  const InsightShareCard({
    super.key,
    required this.cardType,
    required this.title,
    required this.content,
    this.userName,
    this.moonSign,
    this.risingSign,
    this.sunSign,
  });

  // Use cached style for efficiency
  InsightCardTypeStyle get _style => InsightCardTypeStyle.forType(cardType);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _style.gradientColors,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card type badge
          _buildCardTypeBadge(),
          const SizedBox(height: 20),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Container(
            width: 60,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),

          // Content excerpt (cleaned of markdown)
          Text(
            _cleanContent(content),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),

          // User's signs (if available)
          if (moonSign != null || risingSign != null || sunSign != null) ...[
            _buildSignsRow(),
            const SizedBox(height: 24),
          ],

          // Branding
          _buildBranding(),
        ],
      ),
    );
  }

  Widget _buildCardTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _style.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _style.accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _style.icon,
            size: 16,
            color: _style.accentColor,
          ),
          const SizedBox(width: 8),
          Text(
            _style.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _style.accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignsRow() {
    final signs = <Widget>[];

    if (sunSign != null && sunSign!.isNotEmpty) {
      signs.add(_buildSignChip('☉', sunSign!, 'Sun'));
    }
    if (moonSign != null && moonSign!.isNotEmpty) {
      signs.add(_buildSignChip('☽', moonSign!, 'Moon'));
    }
    if (risingSign != null && risingSign!.isNotEmpty) {
      signs.add(_buildSignChip('↑', risingSign!, 'Rising'));
    }

    if (signs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: signs
            .expand((w) => [w, const SizedBox(width: 16)])
            .toList()
          ..removeLast(),
      ),
    );
  }

  Widget _buildSignChip(String symbol, String sign, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          symbol,
          style: TextStyle(
            fontSize: 18,
            color: _style.accentColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sign,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 1,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        const SizedBox(height: 16),
        // App logo + name
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/icon_transparent.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Aurogram',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Get your personalized reading',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  /// Clean markdown formatting from content for display
  String _cleanContent(String text) {
    // Remove bold markers - use non-raw string for backreference
    String cleaned = text.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => match.group(1) ?? '',
    );
    // Remove italic markers
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => match.group(1) ?? '',
    );
    // Remove bullet points
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[-•]\s*', multiLine: true), '');
    // Collapse multiple newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{2,}'), '\n');
    // Trim
    return cleaned.trim();
  }
}

