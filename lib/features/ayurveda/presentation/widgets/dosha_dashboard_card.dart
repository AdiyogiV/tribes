import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PrakritiHeroCard - Your permanent constitution
// ─────────────────────────────────────────────────────────────────────────────

class PrakritiHeroCard extends StatelessWidget {
  final PrakritiData prakriti;
  final bool isRefined;
  final VoidCallback onRefine;
  final VoidCallback? onInfo;
  final bool isDark;

  const PrakritiHeroCard({
    super.key,
    required this.prakriti,
    required this.isRefined,
    required this.onRefine,
    this.onInfo,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;

    return AyurvedaCardContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Core Constitution',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
              const Spacer(),
              if (onInfo != null)
                GestureDetector(
                  onTap: onInfo,
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmMd),

          // Type name and description
          Text(
            prakriti.type,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            getPrakritiDescription(prakriti.type),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),

          // Dosha bars
          _buildDoshaBar('Vata', prakriti.vata, vataColor),
          const SizedBox(height: AppDimensions.spacingMdSm),
          _buildDoshaBar('Pitta', prakriti.pitta, pittaColor),
          const SizedBox(height: AppDimensions.spacingMdSm),
          _buildDoshaBar('Kapha', prakriti.kapha, kaphaColor),
          const SizedBox(height: AppDimensions.spacingXl),

          // Refine button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onRefine();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isRefined
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50)
                    : c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                border: Border.all(
                  color: isRefined
                      ? (isDark ? Colors.white12 : Colors.grey.shade200)
                      : c.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRefined ? Icons.check_circle : Icons.tune,
                    size: 16,
                    color: isRefined ? Colors.green : c,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text(
                    isRefined ? 'Profile Refined' : 'Personalize with Quiz',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isRefined
                          ? (isDark ? Colors.white70 : Colors.black54)
                          : c,
                    ),
                  ),
                  if (!isRefined) ...[
                    const SizedBox(width: AppDimensions.spacingXs),
                    Icon(Icons.arrow_forward_ios, size: 12, color: c),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoshaBar(String label, int value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Stack(
            children: [
              // Background
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                ),
              ),
              // Filled bar
              FractionallySizedBox(
                widthFactor: value / 100,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        SizedBox(
          width: 35,
          child: Text(
            '$value%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TodaysBalanceCard - Your current state (Vikriti)
// ─────────────────────────────────────────────────────────────────────────────

class TodaysBalanceCard extends StatelessWidget {
  final PrakritiData prakriti; // baseline for comparison
  final VikritiData? vikriti;
  final bool isCalculating;
  final DateTime? lastCheckIn;
  final VoidCallback? onInfo;
  final bool isDark;

  const TodaysBalanceCard({
    super.key,
    required this.prakriti,
    this.vikriti,
    required this.isCalculating,
    this.lastCheckIn,
    this.onInfo,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    final hasVikriti = vikriti != null;

    return AyurvedaCardContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Flexible(
                child: Text(
                  'Current Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (lastCheckIn != null) ...[
                const SizedBox(width: AppDimensions.spacingSm),
                Flexible(
                  child: Text(
                    formatLastCheckIn(lastCheckIn!),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (onInfo != null) ...[
                const SizedBox(width: AppDimensions.spacingSm),
                GestureDetector(
                  onTap: onInfo,
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.spacingLg),

          if (isCalculating)
            _buildLoadingState()
          else if (!hasVikriti)
            _buildNoDataState()
          else
            _buildVikritiContent(),

          const SizedBox(height: AppDimensions.spacingMd),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLoadingIndicator(
              size: 18,
              strokeWidth: 2,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Text(
              'Calculating...',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wb_sunny_outlined,
              size: 22,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMdLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How are you feeling?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXxs),
                Text(
                  'A quick check-in tracks your daily balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVikritiContent() {
    final c = AppTheme.primaryColor;
    return Column(
      children: [
        // Dosha bars with comparison - using shared widget
        DoshaComparisonBar(
          label: 'Vata',
          baseline: prakriti.vata,
          current: vikriti!.vata,
          color: vataColor,
          primaryColor: c,
        ),
        const SizedBox(height: AppDimensions.spacingMdSm),
        DoshaComparisonBar(
          label: 'Pitta',
          baseline: prakriti.pitta,
          current: vikriti!.pitta,
          color: pittaColor,
          primaryColor: c,
        ),
        const SizedBox(height: AppDimensions.spacingMdSm),
        DoshaComparisonBar(
          label: 'Kapha',
          baseline: prakriti.kapha,
          current: vikriti!.kapha,
          color: kaphaColor,
          primaryColor: c,
        ),

        // Cosmic factors (if any)
        if (vikriti!.factors.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingLg),
          _buildFactorChips(),
        ],
      ],
    );
  }

  Widget _buildFactorChips() {
    // Filter out static/slow-changing factors - only show dynamic cosmic factors
    final factors = vikriti!.factors
        .where((f) => f.source != 'lifeStage' && f.source != 'season')
        .take(3)
        .toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: factors.map((factor) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 12,
                color: getDoshaColor(factor.dosha).withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                factor.description,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
