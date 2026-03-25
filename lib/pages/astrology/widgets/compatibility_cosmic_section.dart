import 'package:aurogram/pages/astrology/utils/compatibility_label_utils.dart';
import 'package:aurogram/services/compatibility_service.dart';
import 'package:aurogram/services/share_service.dart';
import 'package:aurogram/widgets/astrology/compatibility_share_cards.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CompatibilityCosmicSection extends StatelessWidget {
  final CosmicMatch cosmic;
  final String currentUserName;
  final String otherUserName;
  final String? currentUserPhotoUrl;
  final String? otherUserPhotoUrl;
  final String? currentUserSun;
  final String? currentUserMoon;
  final String? currentUserRising;
  final String? otherUserSun;
  final String? otherUserMoon;
  final String? otherUserRising;
  final Color accentColor;
  final Color cardColor;

  const CompatibilityCosmicSection({
    super.key,
    required this.cosmic,
    required this.currentUserName,
    required this.otherUserName,
    required this.accentColor,
    required this.cardColor,
    this.currentUserPhotoUrl,
    this.otherUserPhotoUrl,
    this.currentUserSun,
    this.currentUserMoon,
    this.currentUserRising,
    this.otherUserSun,
    this.otherUserMoon,
    this.otherUserRising,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showCosmicMatchInfo(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Cosmic Vibe Match',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: accentColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${cosmic.score}%',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w300,
            color: accentColor,
            height: 1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 20),
        Material(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              CompatibilityLabelUtils.getCreativeCosmicLabel(cosmic.label),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        _buildPillarsGrid(context, cosmic.pillars),
        Text(
          'tap to understand',
          style: TextStyle(
            fontSize: 11,
            color: accentColor.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 16),
        _buildShareButton(
          context: context,
          onTap: () => _shareCosmicVibe(context),
        ),
      ],
    );
  }

  Widget _buildShareButton({
    required BuildContext context,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Share Cosmic Match',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildPillarsGrid(
      BuildContext context, List<CosmicPillar> pillars) {
    final int crossAxisCount = pillars.length <= 4 ? 4 : 3;
    final double aspectRatio = pillars.length <= 4 ? 0.85 : 0.9;

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 10),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: pillars.length,
      itemBuilder: (context, index) {
        final pillar = pillars[index];
        return _buildPillarCard(context, pillar);
      },
    );
  }

  Widget _buildPillarCard(BuildContext context, CosmicPillar pillar) {
    final displayName =
        CompatibilityLabelUtils.formatPillarName(pillar.displayName);

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showPillarDetails(context, pillar),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${pillar.score}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: accentColor.withValues(alpha: 0.5),
                  letterSpacing: 0.2,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareCosmicVibe(BuildContext context) {
    final pillars = cosmic.pillars
        .map((p) => PillarData(
              name: p.displayName,
              score: p.score,
            ))
        .toList();

    ShareService.showCosmicVibeCardPreview(
      context: context,
      score: cosmic.score,
      label: CompatibilityLabelUtils.getCreativeCosmicLabel(cosmic.label),
      pillars: pillars,
      user1Name: currentUserName,
      user2Name: otherUserName,
      user1PhotoUrl: currentUserPhotoUrl,
      user2PhotoUrl: otherUserPhotoUrl,
      user1Sun: currentUserSun,
      user1Moon: currentUserMoon,
      user1Rising: currentUserRising,
      user2Sun: otherUserSun,
      user2Moon: otherUserMoon,
      user2Rising: otherUserRising,
    );
  }

  void _showCosmicMatchInfo(BuildContext context) {
    final pillarCount = cosmic.pillars.length;

    final String pillarDescription;
    if (pillarCount > 6) {
      pillarDescription =
          'This comprehensive analysis uses up to 9 pillars of cosmic compatibility:\n\n'
          '🧠 Mental - Planetary friendship (Graha Maitri)\n'
          '💫 Temperament - Nature harmony (Gana)\n'
          '✨ Flow - Star alignment (Tara)\n'
          '💚 Emotional - Moon sign bond\n'
          '🦋 Instinctual - Animal chemistry (Yoni)\n'
          '⚡ Energy - Vital flow (Nadi)\n'
          '☀️ Identity - Sun sign harmony\n'
          '🤝 Social - Rising sign compatibility\n'
          '🌍 Elements - Elemental balance\n\n'
          'The number of pillars used depends on the birth data available for both people.';
    } else {
      pillarDescription =
          'The Cosmic Match combines fundamental Vedic compatibility factors into one universal score:\n\n'
          '🧠 Mental - Planetary friendship\n'
          '💫 Temperament - Nature harmony\n'
          '✨ Flow - Star alignment\n'
          '💚 Emotional - Moon sign bond\n\n'
          'Each pillar is scored 0-100%, then weighted to create the overall Cosmic Match.';
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          'How Cosmic Match Works',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: accentColor,
          ),
        ),
        message: Text(
          'Unlike traditional marriage matching (Ashtakoot), the Cosmic Match is designed for all relationship types - friends, partners, family, colleagues.\n\n'
          '$pillarDescription\n\n'
          'Tap any pillar card to see details about your specific cosmic placements.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: accentColor.withValues(alpha: 0.7),
          ),
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Got it', style: TextStyle(color: accentColor)),
        ),
      ),
    );
  }

  void _showPillarDetails(BuildContext context, CosmicPillar pillar) {
    String title = pillar.displayName;
    String subtitle = '';
    String explanation = pillar.insight;

    String descKey;
    switch (pillar.source) {
      case 'graha_maitri':
        descKey = 'mental';
        break;
      case 'gana':
        descKey = 'temperament';
        break;
      case 'tara':
        descKey = 'flow';
        break;
      case 'rashi_position':
      case 'moon_position':
        descKey = 'emotional';
        break;
      case 'yoni':
      case 'yoni_affinity':
        descKey = 'instinctual';
        break;
      case 'nadi':
        descKey = 'energyFlow';
        break;
      case 'sun_sign_harmony':
      case 'sun_harmony':
        descKey = 'coreIdentity';
        break;
      case 'ascendant_harmony':
      case 'lagna_harmony':
        descKey = 'social';
        break;
      case 'element_balance':
        descKey = 'elementBalance';
        break;
      default:
        descKey = pillar.source;
    }
    final description =
        CompatibilityLabelUtils.pillarDescriptions[descKey] ?? '';

    switch (pillar.source) {
      case 'graha_maitri':
        final yourLord = pillar.details['yourLord'] ?? '';
        final theirLord = pillar.details['theirLord'] ?? '';
        final relationship = pillar.details['relationship'] ?? '';
        subtitle = yourLord == theirLord
            ? 'Both ruled by $yourLord'
            : '$yourLord ↔ $theirLord\n$relationship';
        break;
      case 'gana':
        final yourGana = pillar.details['yourGana'] ?? '';
        final theirGana = pillar.details['theirGana'] ?? '';
        subtitle = yourGana == theirGana
            ? 'Both $yourGana temperament'
            : 'You: $yourGana • Them: $theirGana';
        break;
      case 'tara':
        final yourTara = pillar.details['yourTara'] ?? '';
        final theirTara = pillar.details['theirTara'] ?? '';
        subtitle = yourTara == theirTara
            ? 'Both in $yourTara star'
            : '$yourTara ↔ $theirTara';
        break;
      case 'rashi_position':
      case 'moon_position':
        final yourSign = pillar.details['yourSign'] ?? '';
        final theirSign = pillar.details['theirSign'] ?? '';
        subtitle = '$yourSign ↔ $theirSign';
        break;
      case 'yoni':
      case 'yoni_affinity':
        final yourYoni = pillar.details['yourYoni'] ?? '';
        final theirYoni = pillar.details['theirYoni'] ?? '';
        subtitle = '$yourYoni ↔ $theirYoni';
        break;
      case 'nadi':
        final yourNadi = pillar.details['yourNadi'] ?? '';
        final theirNadi = pillar.details['theirNadi'] ?? '';
        subtitle = '$yourNadi ↔ $theirNadi';
        break;
      case 'sun_sign_harmony':
      case 'sun_harmony':
        final yourSign = pillar.details['yourSign'] ?? '';
        final theirSign = pillar.details['theirSign'] ?? '';
        subtitle = '$yourSign ↔ $theirSign';
        break;
      case 'ascendant_harmony':
      case 'lagna_harmony':
        final yourSign = pillar.details['yourSign'] ?? '';
        final theirSign = pillar.details['theirSign'] ?? '';
        subtitle = '$yourSign ↔ $theirSign';
        break;
      case 'element_balance':
        final yourElement = pillar.details['yourElement'] ?? '';
        final theirElement = pillar.details['theirElement'] ?? '';
        subtitle = '$yourElement ↔ $theirElement';
        break;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: accentColor,
          ),
        ),
        message: Column(
          children: [
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accentColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            if (subtitle.isNotEmpty) const SizedBox(height: 12),
            if (description.isNotEmpty)
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: accentColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            if (description.isNotEmpty) const SizedBox(height: 12),
            Text(
              explanation,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: accentColor.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: accentColor)),
        ),
      ),
    );
  }
}
