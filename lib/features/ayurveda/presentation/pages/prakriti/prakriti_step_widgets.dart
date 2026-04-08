import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'prakriti_questions.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// Use app's primary color for consistency
Color get accentColor => AppTheme.primaryColor;

/// Option card widget for a question
class OptionCard extends StatelessWidget {
  final QuestionOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  Color get _doshaColor {
    switch (option.dosha) {
      case 'vata':
        return const Color(0xFF7C9CBF);
      case 'pitta':
        return const Color(0xFFE67E22);
      case 'kapha':
        return const Color(0xFF27AE60);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        decoration: BoxDecoration(
          color: isSelected
              ? _doshaColor.withValues(alpha: 0.15)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: isSelected ? _doshaColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _doshaColor : null,
                      )),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(option.subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _doshaColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

/// Results bottom sheet shown after submission
class ResultsSheet extends StatelessWidget {
  final PrakritiData predicted;
  final PrakritiData refined;
  final int questionsAnswered;
  final VoidCallback onDone;

  const ResultsSheet({
    super.key,
    required this.predicted,
    required this.refined,
    required this.questionsAnswered,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.nearBlackColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle,
                size: 40, color: Colors.green.shade600),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          const Text('Prakriti Refined!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Based on $questionsAnswered questions',
            style: TextStyle(
                fontSize: 14, color: isDark ? Colors.white54 : Colors.black54),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          Row(
            children: [
              Expanded(
                child: ComparisonColumn(
                  title: 'Predicted',
                  subtitle: '(astrology)',
                  prakriti: predicted,
                  isDark: isDark,
                  isHighlighted: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward,
                    color: isDark ? Colors.white38 : Colors.black26),
              ),
              Expanded(
                child: ComparisonColumn(
                  title: 'Refined',
                  subtitle: '(personalized)',
                  prakriti: refined,
                  isDark: isDark,
                  isHighlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.spa_outlined, size: 22, color: accentColor),
                const SizedBox(width: AppDimensions.spacingMdSm),
                Text('Your Prakriti: ${refined.type}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: accentColor)),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                ),
              ),
              child: const Text('Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class ComparisonColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final PrakritiData prakriti;
  final bool isDark;
  final bool isHighlighted;

  const ComparisonColumn({
    super.key,
    required this.title,
    required this.subtitle,
    required this.prakriti,
    required this.isDark,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: isHighlighted
            ? accentColor.withValues(alpha: 0.1)
            : isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: isHighlighted
            ? Border.all(color: accentColor.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted ? accentColor : null)),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(height: AppDimensions.spacingSm),
          MiniDoshaBar(
              label: 'V', value: prakriti.vata, color: const Color(0xFF7C9CBF)),
          const SizedBox(height: AppDimensions.spacingXs),
          MiniDoshaBar(
              label: 'P',
              value: prakriti.pitta,
              color: const Color(0xFFE67E22)),
          const SizedBox(height: AppDimensions.spacingXs),
          MiniDoshaBar(
              label: 'K',
              value: prakriti.kapha,
              color: const Color(0xFF27AE60)),
        ],
      ),
    );
  }
}

class MiniDoshaBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const MiniDoshaBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        SizedBox(
          width: 24,
          child: Text('$value',
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
