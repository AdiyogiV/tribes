import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'prakriti_questions.dart';
import 'prakriti_step_widgets.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Displays a single question with its options.
class PrakritiQuestionStep extends StatelessWidget {
  final PrakritiQuestion question;
  final String? selectedDosha;
  final ValueChanged<String> onSelectAnswer;

  const PrakritiQuestionStep({
    super.key,
    required this.question,
    required this.selectedDosha,
    required this.onSelectAnswer,
  });

  Color get _accentColor => AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingXxl),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            ),
            child: Icon(question.icon, size: 36, color: _accentColor),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            question.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _accentColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            question.question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSection),
          ...question.options.map((option) {
            final isSelected = selectedDosha == option.dosha;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.paddingMd),
              child: OptionCard(
                option: option,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => onSelectAnswer(option.dosha),
              ),
            );
          }),
        ],
      ),
    );
  }
}
