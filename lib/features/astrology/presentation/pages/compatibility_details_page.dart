import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/astrology/domain/compatibility_service.dart';
import 'package:aurogram/shared/services/share/share_service.dart';
import 'package:aurogram/shared/utils/compatibility_constants.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/services/share/compatibility_share_cards.dart';
import 'package:aurogram/features/astrology/presentation/utils/compatibility_label_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/compatibility_cosmic_section.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Compatibility details page - multi-layer design
/// Shows Cosmic Match (primary) and Traditional Ashtakoot (secondary)
class CompatibilityDetailsPage extends StatelessWidget {
  final CompatibilityResult result;
  final String otherUserId;
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

  const CompatibilityDetailsPage({
    super.key,
    required this.result,
    required this.otherUserId,
    required this.currentUserName,
    required this.otherUserName,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppTheme.primaryColor;
    final cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20, color: c),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'compatibility',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: c,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: AppDimensions.spacingLg),

                  // ==========================================================
                  // COSMIC MATCH (Primary)
                  // ==========================================================
                  if (result.cosmicMatch != null) ...[
                    CompatibilityCosmicSection(
                      cosmic: result.cosmicMatch!,
                      currentUserName: currentUserName,
                      otherUserName: otherUserName,
                      currentUserPhotoUrl: currentUserPhotoUrl,
                      otherUserPhotoUrl: otherUserPhotoUrl,
                      currentUserSun: currentUserSun,
                      currentUserMoon: currentUserMoon,
                      currentUserRising: currentUserRising,
                      otherUserSun: otherUserSun,
                      otherUserMoon: otherUserMoon,
                      otherUserRising: otherUserRising,
                      accentColor: c,
                      cardColor: cardColor,
                    ),
                    const SizedBox(height: 28),
                    Divider(
                      color: c.withValues(alpha: 0.12),
                      thickness: 1,
                      height: 1,
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ==========================================================
                  // FULL VEDIC MATCH (Secondary) - Only show if available
                  // ==========================================================
                  if (result.hasTraditionalMatch)
                    _buildTraditionalMatchSection(context, isDark, c, cardColor),

                  // ==========================================================
                  // LIFE PHASE SYNC
                  // ==========================================================
                  if (result.lifePhaseSync != null) ...[
                    const SizedBox(height: 28),
                    Divider(
                      color: c.withValues(alpha: 0.12),
                      thickness: 1,
                      height: 1,
                    ),
                    const SizedBox(height: 28),
                    _buildLifePhaseSyncSection(context, isDark, c, cardColor),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // LIFE PHASE SYNC SECTION
  // ============================================================================

  Widget _buildLifePhaseSyncSection(
      BuildContext context, bool isDark, Color c, Color cardColor) {
    final lifePhase = result.lifePhaseSync!;
    final sync = lifePhase.sync;
    final user1 = lifePhase.user1;
    final user2 = lifePhase.user2;

    return Column(
      children: [
        // Section header with info
        GestureDetector(
          onTap: () => _showLifePhaseSyncInfo(context, c),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Life Phase Sync',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmMd),
              Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: c.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXl),

        // Sync label badge (using theme color)
        Material(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
            child: Text(
              CompatibilityLabelUtils.getCreativeLifePhaseLabel(sync.label),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXl),

        // Two user phase cards side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPhaseCard(
                context,
                isDark,
                c,
                cardColor,
                label: 'You',
                mahaDasha: user1.mahaDasha,
                antarDasha: user1.antarDasha,
                theme: user1.theme,
                mahaStartDate: user1.mahaStartDate,
                mahaEndDate: user1.mahaEndDate,
                antarStartDate: user1.antarStartDate,
                antarEndDate: user1.antarEndDate,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: _buildPhaseCard(
                context,
                isDark,
                c,
                cardColor,
                label: 'Them',
                mahaDasha: user2.mahaDasha,
                antarDasha: user2.antarDasha,
                theme: user2.theme,
                mahaStartDate: user2.mahaStartDate,
                mahaEndDate: user2.mahaEndDate,
                antarStartDate: user2.antarStartDate,
                antarEndDate: user2.antarEndDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMd),

        // Insight text
        Material(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
            child: Text(
              sync.insight,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ),

        // Share button
        const SizedBox(height: AppDimensions.spacingLg),
        _buildShareButton(
          context: context,
          c: c,
          onTap: () => _shareLifePhase(context, lifePhase),
        ),
      ],
    );
  }

  void _shareLifePhase(BuildContext context, LifePhaseSyncResult lifePhase) {
    ShareService.showLifePhaseCardPreview(
      context: context,
      syncLabel: CompatibilityLabelUtils.getCreativeLifePhaseLabel(
          lifePhase.sync.label),
      user1MahaDasha: lifePhase.user1.mahaDasha,
      user1AntarDasha: lifePhase.user1.antarDasha,
      user1Theme: lifePhase.user1.theme,
      user2MahaDasha: lifePhase.user2.mahaDasha,
      user2AntarDasha: lifePhase.user2.antarDasha,
      user2Theme: lifePhase.user2.theme,
      insight: lifePhase.sync.insight,
      user1Name: currentUserName,
      user2Name: otherUserName,
      user1PhotoUrl: currentUserPhotoUrl,
      user2PhotoUrl: otherUserPhotoUrl,
    );
  }

  Widget _buildPhaseCard(
    BuildContext context,
    bool isDark,
    Color c,
    Color cardColor, {
    required String label,
    required String mahaDasha,
    String? antarDasha,
    required String theme,
    String? mahaStartDate,
    String? mahaEndDate,
    String? antarStartDate,
    String? antarEndDate,
  }) {
    // Calculate Mahadasha progress if we have dates
    double? mahaProgress;
    String? mahaTimeRemaining;
    if (mahaStartDate != null && mahaEndDate != null) {
      final result = _calculateProgress(mahaStartDate, mahaEndDate);
      mahaProgress = result['progress'];
      mahaTimeRemaining = result['timeRemaining'];
    }

    // Calculate Antardasha progress if we have dates
    double? antarProgress;
    String? antarTimeRemaining;
    if (antarStartDate != null && antarEndDate != null) {
      final result = _calculateProgress(antarStartDate, antarEndDate);
      antarProgress = result['progress'];
      antarTimeRemaining = result['timeRemaining'];
    }

    return Material(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label (You / Them)
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: c.withValues(alpha: 0.5),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMdSm),

            // Mahadasha section
            Text(
              'MAHADASHA',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXxs),
            Text(
              mahaDasha,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.9),
              ),
            ),

            // Mahadasha progress bar
            if (mahaProgress != null) ...[
              const SizedBox(height: AppDimensions.spacingSmMd),
              _buildProgressBar(c.withValues(alpha: 0.9), mahaProgress,
                  mahaTimeRemaining, isDark),
            ],

            // Antardasha (if available)
            if (antarDasha != null && antarDasha.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'ANTARDASHA',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXxs),
              Text(
                antarDasha,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.withValues(alpha: 0.9),
                ),
              ),

              // Antardasha progress bar
              if (antarProgress != null) ...[
                const SizedBox(height: AppDimensions.spacingSmMd),
                _buildProgressBar(c.withValues(alpha: 0.9), antarProgress,
                    antarTimeRemaining, isDark),
              ],
            ],

            // Theme
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              theme,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate progress and time remaining from date strings
  Map<String, dynamic> _calculateProgress(String startDate, String endDate) {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final now = DateTime.now();
      final total = end.difference(start).inDays;
      final elapsed = now.difference(start).inDays;
      if (total > 0) {
        final progress = (elapsed / total).clamp(0.0, 1.0);
        final remaining = end.difference(now).inDays;
        String timeRemaining;
        if (remaining > 365) {
          final years = (remaining / 365).floor();
          timeRemaining = '${years}y left';
        } else if (remaining > 30) {
          final months = (remaining / 30).floor();
          timeRemaining = '${months}mo left';
        } else if (remaining > 0) {
          timeRemaining = '${remaining}d left';
        } else {
          timeRemaining = 'ending';
        }
        return {'progress': progress, 'timeRemaining': timeRemaining};
      }
    } catch (_) {
      AppLogger.w('CompatibilityDetailsPage: dasha progress calculation failed', category: LogCategory.general);
    }
    return {'progress': null, 'timeRemaining': null};
  }

  /// Build a progress bar widget
  Widget _buildProgressBar(
      Color color, double progress, String? timeRemaining, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor:
                AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.6)),
            minHeight: 3,
          ),
        ),
        if (timeRemaining != null) ...[
          const SizedBox(height: AppDimensions.spacingXxxs),
          Text(
            timeRemaining,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ],
    );
  }

  void _showLifePhaseSyncInfo(BuildContext context, Color c) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          'About Life Phase Sync',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
        message: Text(
          'In Vedic astrology, planetary periods (Dashas) shape your life themes:\n\n'
          'Mahadasha (Major Period)\n'
          'The main planetary influence lasting several years. It sets the overall tone for this phase of your life.\n\n'
          'Antardasha (Sub-Period)\n'
          'A shorter period within the Mahadasha that adds nuance to the current themes.\n\n'
          'Life Phase Sync shows how your current periods interact:\n'
          '• Same Dasha → Deep understanding\n'
          '• Complementary → Mutual support\n'
          '• Different → Growth opportunity',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: c.withValues(alpha: 0.7),
          ),
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: c)),
        ),
      ),
    );
  }

  // ============================================================================
  // FULL VEDIC MATCH SECTION
  // ============================================================================

  Widget _buildTraditionalMatchSection(
      BuildContext context, bool isDark, Color c, Color cardColor) {
    final traditional = result.traditionalMatch!;

    // Get creative label based on score
    String label;
    if (traditional.totalScore >= 25) {
      label = 'Divine Match 🙏';
    } else if (traditional.totalScore >= 18) {
      label = 'Blessed Bond';
    } else if (traditional.totalScore >= 12) {
      label = 'Balanced Journey';
    } else {
      label = 'Learning Bond';
    }

    return Column(
      children: [
        // Section header with info
        GestureDetector(
          onTap: () => _showAshtakootInfo(context, c),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ashtakoot Match',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmMd),
              Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: c.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),

        // Big score display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              traditional.totalScore.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w300,
                color: c,
                height: 1,
                letterSpacing: -1,
              ),
            ),
            Text(
              '/${traditional.outOf}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: c.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        Material(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),

        // Kootas grid
        if (traditional.details != null && traditional.details!.isNotEmpty)
          _buildKootasGrid(context, isDark, c, cardColor, traditional.details!),

        // Hint text
        Text(
          'tap to understand',
          style: TextStyle(
            fontSize: 11,
            color: c.withValues(alpha: 0.4),
          ),
        ),

        // Share button
        const SizedBox(height: AppDimensions.spacingLg),
        _buildShareButton(
          context: context,
          c: c,
          onTap: () => _shareAshtakoot(context, traditional),
        ),
      ],
    );
  }

  void _shareAshtakoot(BuildContext context, TraditionalMatch traditional) {
    final kootaNames = [
      'Varna',
      'Vashya',
      'Tara',
      'Yoni',
      'Maitri',
      'Gana',
      'Rasi',
      'Nadi'
    ];
    final kootaKeys = [
      'varna_kootam',
      'vasya_kootam',
      'tara_kootam',
      'yoni_kootam',
      'graha_maitri_kootam',
      'gana_kootam',
      'rasi_kootam',
      'nadi_kootam',
    ];

    final kootas = <KootaData>[];
    if (traditional.details != null) {
      for (var i = 0; i < kootaNames.length; i++) {
        var data = traditional.details![kootaKeys[i]];
        if (i == 6 && data == null) {
          data = traditional.details!['bhakut_kootam'];
        }
        if (data != null) {
          final kootaMap = Map<String, dynamic>.from(data as Map);
          kootas.add(KootaData(
            name: kootaNames[i],
            score: (kootaMap['score'] ?? 0).toDouble(),
            maxScore: (kootaMap['out_of'] ??
                    CompatibilityConstants.getMaxScoreForKoota(kootaNames[i]))
                .toInt(),
          ));
        }
      }
    }

    String label;
    if (traditional.totalScore >= 25) {
      label = 'Divine Match 🙏';
    } else if (traditional.totalScore >= 18) {
      label = 'Blessed Bond';
    } else if (traditional.totalScore >= 12) {
      label = 'Balanced Journey';
    } else {
      label = 'Learning Bond';
    }

    ShareService.showAshtakootCardPreview(
      context: context,
      score: traditional.totalScore,
      outOf: traditional.outOf,
      label: label,
      kootas: kootas,
      user1Name: currentUserName,
      user2Name: otherUserName,
      user1PhotoUrl: currentUserPhotoUrl,
      user2PhotoUrl: otherUserPhotoUrl,
    );
  }

  void _showAshtakootInfo(BuildContext context, Color c) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          'Ashtakoot Matching',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
        message: Text(
          'Ashtakoot (8 Kootas) is a traditional Vedic compatibility system used for marriage matching. It evaluates 8 different aspects of a relationship.\n\n'
          'Each koota has a maximum score, totaling 36 points.\n\n'
          '• 18+ points: Excellent match\n'
          '• 14-17 points: Good match\n'
          '• 10-13 points: Average match\n'
          '• Below 10: Challenging match\n\n'
          'Note: This system was designed for traditional arranged marriages and includes factors like genetic compatibility (nadi) for offspring.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: c.withValues(alpha: 0.7),
          ),
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Got it', style: TextStyle(color: c)),
        ),
      ),
    );
  }

  Widget _buildKootasGrid(BuildContext context, bool isDark, Color c,
      Color cardColor, Map<String, dynamic> details) {
    final kootaNames = [
      'Varna',
      'Vashya',
      'Tara',
      'Yoni',
      'Maitri',
      'Gana',
      'Rasi',
      'Nadi'
    ];
    final kootaKeys = [
      'varna_kootam',
      'vasya_kootam',
      'tara_kootam',
      'yoni_kootam',
      'graha_maitri_kootam',
      'gana_kootam',
      'rasi_kootam',
      'nadi_kootam',
    ];

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 10),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: kootaNames.length,
      itemBuilder: (context, index) {
        final name = kootaNames[index];
        var data = details[kootaKeys[index]];
        // Handle rasi/bhakut fallback
        if (index == 6 && data == null) {
          data = details['bhakut_kootam'];
        }
        return _buildKootaCard(context, isDark, c, cardColor, name, data);
      },
    );
  }

  Widget _buildKootaCard(BuildContext context, bool isDark, Color c,
      Color cardColor, String name, dynamic kootaData) {
    if (kootaData == null) return const SizedBox.shrink();

    final kootaMap = Map<String, dynamic>.from(kootaData as Map);
    final scoreVal = (kootaMap['score'] ?? 0).toDouble();
    final maxScore =
        (kootaMap['out_of'] ?? CompatibilityConstants.getMaxScoreForKoota(name))
            .toDouble();
    final scoreDisplay = scoreVal % 1 == 0
        ? scoreVal.toInt().toString()
        : scoreVal.toStringAsFixed(1);

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
      child: InkWell(
        onTap: () => _showKootaDetails(context, c, name, scoreVal, maxScore),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    scoreDisplay,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: c,
                    ),
                  ),
                  Text(
                    '/${maxScore.toInt()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.withValues(alpha: 0.6),
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKootaDetails(BuildContext context, Color c, String name,
      double score, double maxScore) {
    final explanation =
        CompatibilityLabelUtils.kootaExplanations[name] ??
            'No description available.';
    final scoreDisplay =
        score % 1 == 0 ? score.toInt().toString() : score.toStringAsFixed(1);

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Text(
              '$scoreDisplay/${maxScore.toInt()}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        message: Text(
          explanation,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: c.withValues(alpha: 0.7),
          ),
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: c)),
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required BuildContext context,
    required Color c,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.share_outlined,
                size: 14,
                color: c.withValues(alpha: 0.6),
              ),
              const SizedBox(width: AppDimensions.spacingSmMd),
              Text(
                'Share',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
