import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:cached_network_image/cached_network_image.dart';

// =============================================================================
// SHARED HELPERS
// =============================================================================

/// Shared utilities for compatibility share cards
class _ShareCardHelpers {
  static Widget buildAvatar(String? photoUrl, Color borderColor,
      {double radius = 32}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [borderColor, borderColor.withValues(alpha: 0.5)],
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.darkGradientBase,
        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(photoUrl)
            : null,
        child: photoUrl == null || photoUrl.isEmpty
            ? Icon(Icons.person,
                size: radius, color: Colors.white.withValues(alpha: 0.5))
            : null,
      ),
    );
  }

  static Widget buildBranding() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
          child: Image.asset(
            'assets/images/icon_transparent.png',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Text(
          'Aurogram',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  static String truncateName(String name, {int maxLength = 10}) {
    if (name.length <= maxLength) return name;
    return '${name.substring(0, maxLength - 1)}…';
  }
}

// =============================================================================
// COSMIC VIBE MATCH CARD
// =============================================================================

/// Shareable card for Cosmic Vibe Match compatibility score
class CosmicVibeShareCard extends StatelessWidget {
  final int score;
  final String label;
  final List<PillarData> pillars;
  final String user1Name;
  final String user2Name;
  final String? user1PhotoUrl;
  final String? user2PhotoUrl;
  final String? user1Sun;
  final String? user1Moon;
  final String? user1Rising;
  final String? user2Sun;
  final String? user2Moon;
  final String? user2Rising;

  const CosmicVibeShareCard({
    super.key,
    required this.score,
    required this.label,
    required this.pillars,
    required this.user1Name,
    required this.user2Name,
    this.user1PhotoUrl,
    this.user2PhotoUrl,
    this.user1Sun,
    this.user1Moon,
    this.user1Rising,
    this.user2Sun,
    this.user2Moon,
    this.user2Rising,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkGradientBase,
            AppTheme.callGradientMid,
            AppTheme.darkGradientMid,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title - prominent at top
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.softViolet, AppTheme.rosePink],
            ).createShader(bounds),
            child: const Text(
              'Cosmic Vibe Match',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),

          // User avatars with connection
          _buildUserAvatars(),
          const SizedBox(height: AppDimensions.spacingXl),

          // Big score with glow effect
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.softViolet, Color(0xFFFFFFFF), AppTheme.rosePink],
            ).createShader(bounds),
            child: Text(
              '$score%',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w200,
                color: Colors.white,
                height: 1,
                letterSpacing: -3,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),

          // Label badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.softViolet.withValues(alpha: 0.2),
                  AppTheme.rosePink.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),

          // Pillars grid with icons - adapts to pillar count
          _buildPillarsGrid(),

          const SizedBox(height: AppDimensions.spacingXxl),

          // Branding
          _ShareCardHelpers.buildBranding(),
        ],
      ),
    );
  }

  Widget _buildUserAvatars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User 1
        Column(
          children: [
            _ShareCardHelpers.buildAvatar(
                user1PhotoUrl, AppTheme.softViolet),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              _ShareCardHelpers.truncateName(user1Name),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmMd),
            _buildSignsColumn(user1Sun, user1Moon, user1Rising),
          ],
        ),
        // Connection indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              '&',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        // User 2
        Column(
          children: [
            _ShareCardHelpers.buildAvatar(
                user2PhotoUrl, AppTheme.rosePink),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              _ShareCardHelpers.truncateName(user2Name),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmMd),
            _buildSignsColumn(user2Sun, user2Moon, user2Rising),
          ],
        ),
      ],
    );
  }

  Widget _buildSignsColumn(String? sun, String? moon, String? rising) {
    final signs = <Widget>[];

    if (sun != null && sun.isNotEmpty) {
      signs.add(_buildSignRow('☉', sun));
    }
    if (moon != null && moon.isNotEmpty) {
      signs.add(_buildSignRow('☽', moon));
    }
    if (rising != null && rising.isNotEmpty) {
      signs.add(_buildSignRow('↑', rising));
    }

    if (signs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: signs,
    );
  }

  Widget _buildSignRow(String symbol, String sign) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            symbol,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            sign,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarsGrid() {
    // For 4 or fewer pillars, use single row
    // For 5+ pillars, use two rows
    if (pillars.length <= 4) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: pillars.map((p) => _buildPillarItem(p)).toList(),
        ),
      );
    }

    // For 5+ pillars, split into two rows
    // First row: first half (rounded up), Second row: rest
    final firstRowCount = (pillars.length / 2).ceil();
    final firstRow = pillars.take(firstRowCount).toList();
    final secondRow = pillars.skip(firstRowCount).toList();

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: firstRow.map((p) => _buildPillarItem(p, compact: true)).toList(),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: secondRow.map((p) => _buildPillarItem(p, compact: true)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarItem(PillarData pillar, {bool compact = false}) {
    // Format long names to two lines
    final displayName = _formatPillarName(pillar.name);
    
    return SizedBox(
      width: compact ? 60 : 70,
      child: Column(
        children: [
          Text(
            '${pillar.score}%',
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            displayName,
            style: TextStyle(
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  /// Format pillar names to fit in two lines
  /// e.g., "Mental Wavelength" -> "Mental\nWavelength"
  String _formatPillarName(String name) {
    if (name.contains(' ') && name.length > 8) {
      return name.replaceFirst(' ', '\n');
    }
    return name;
  }
}

// =============================================================================
// ASHTAKOOT MATCH CARD
// =============================================================================

/// Shareable card for Ashtakoot Match score
class AshtakootShareCard extends StatelessWidget {
  final double score;
  final int outOf;
  final String label;
  final List<KootaData> kootas;
  final String user1Name;
  final String user2Name;
  final String? user1PhotoUrl;
  final String? user2PhotoUrl;

  const AshtakootShareCard({
    super.key,
    required this.score,
    required this.outOf,
    required this.label,
    required this.kootas,
    required this.user1Name,
    required this.user2Name,
    this.user1PhotoUrl,
    this.user2PhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkGradientBase,
            Color(0xFF2d1b4e),
            AppTheme.darkGradientBase,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title - prominent at top
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.lavenderGlow, AppTheme.goldColor],
            ).createShader(bounds),
            child: const Text(
              'Ashtakoot Match',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),

          // User avatars with connection
          _buildUserAvatars(),
          const SizedBox(height: AppDimensions.spacingXl),

          // Big score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.lavenderGlow, AppTheme.goldColor],
                ).createShader(bounds),
                child: Text(
                  score % 1 == 0
                      ? score.toInt().toString()
                      : score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: -3,
                  ),
                ),
              ),
              Text(
                '/$outOf',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),

          // Label badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.lavenderGlow.withValues(alpha: 0.2),
                  AppTheme.goldColor.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),

          // Kootas grid
          _buildKootasGrid(),

          const SizedBox(height: AppDimensions.spacingXxl),

          // Branding
          _ShareCardHelpers.buildBranding(),
        ],
      ),
    );
  }

  Widget _buildUserAvatars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            _ShareCardHelpers.buildAvatar(
                user1PhotoUrl, AppTheme.lavenderGlow),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              _ShareCardHelpers.truncateName(user1Name),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
          child: Text(
            '&',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        Column(
          children: [
            _ShareCardHelpers.buildAvatar(
                user2PhotoUrl, AppTheme.goldColor),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              _ShareCardHelpers.truncateName(user2Name),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKootasGrid() {
    final firstRow = kootas.take(4).toList();
    final secondRow = kootas.skip(4).take(4).toList();

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: firstRow.map((k) => _buildKootaItem(k)).toList(),
          ),
          const SizedBox(height: AppDimensions.spacingMdLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: secondRow.map((k) => _buildKootaItem(k)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKootaItem(KootaData koota) {
    final scoreDisplay = koota.score % 1 == 0
        ? koota.score.toInt().toString()
        : koota.score.toStringAsFixed(1);

    return SizedBox(
      width: 65,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                scoreDisplay,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                '/${koota.maxScore}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            koota.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LIFE PHASE SYNC CARD
// =============================================================================

/// Shareable card for Life Phase Sync
class LifePhaseShareCard extends StatelessWidget {
  final String syncLabel;
  final String user1MahaDasha;
  final String? user1AntarDasha;
  final String user1Theme;
  final String user2MahaDasha;
  final String? user2AntarDasha;
  final String user2Theme;
  final String insight;
  final String user1Name;
  final String user2Name;
  final String? user1PhotoUrl;
  final String? user2PhotoUrl;

  const LifePhaseShareCard({
    super.key,
    required this.syncLabel,
    required this.user1MahaDasha,
    this.user1AntarDasha,
    required this.user1Theme,
    required this.user2MahaDasha,
    this.user2AntarDasha,
    required this.user2Theme,
    required this.insight,
    required this.user1Name,
    required this.user2Name,
    this.user1PhotoUrl,
    this.user2PhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkGradientBase,
            Color(0xFF1e3a5f),
            AppTheme.darkGradientMid,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title - prominent at top
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.lightBlueAccent, AppTheme.aquamarine],
            ).createShader(bounds),
            child: const Text(
              'Life Phase Sync',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),

          // Sync label badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.lightBlueAccent.withValues(alpha: 0.2),
                  AppTheme.aquamarine.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              syncLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),

          // Two user phase cards side by side
          Row(
            children: [
              Expanded(
                child: _buildUserPhaseCard(
                  name: user1Name,
                  photoUrl: user1PhotoUrl,
                  mahaDasha: user1MahaDasha,
                  antarDasha: user1AntarDasha,
                  theme: user1Theme,
                  color: AppTheme.lightBlueAccent,
                ),
              ),
              // Connection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '&',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Expanded(
                child: _buildUserPhaseCard(
                  name: user2Name,
                  photoUrl: user2PhotoUrl,
                  mahaDasha: user2MahaDasha,
                  antarDasha: user2AntarDasha,
                  theme: user2Theme,
                  color: AppTheme.aquamarine,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacingLg),

          // Insight
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Text(
              insight,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.spacingXl),

          // Branding
          _ShareCardHelpers.buildBranding(),
        ],
      ),
    );
  }

  Widget _buildUserPhaseCard({
    required String name,
    String? photoUrl,
    required String mahaDasha,
    String? antarDasha,
    required String theme,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Avatar and name
          _ShareCardHelpers.buildAvatar(photoUrl, color, radius: 20),
          const SizedBox(height: AppDimensions.spacingSmMd),
          Text(
            _ShareCardHelpers.truncateName(name, maxLength: 8),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMdSm),
          // Dasha info
          Text(
            'Mahadasha',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            mahaDasha,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (antarDasha != null && antarDasha.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSmMd),
            Text(
              'Antardasha',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXxs),
            Text(
              antarDasha,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.spacingSmMd),
          Text(
            theme,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DATA CLASSES
// =============================================================================

/// Data class for pillar info
class PillarData {
  final String name;
  final int score;

  const PillarData({required this.name, required this.score});
}

/// Data class for koota info
class KootaData {
  final String name;
  final double score;
  final int maxScore;

  const KootaData(
      {required this.name, required this.score, required this.maxScore});
}
