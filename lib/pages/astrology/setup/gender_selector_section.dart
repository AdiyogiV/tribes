import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Gender selector with tappable chips.
class GenderSelectorSection extends StatelessWidget {
  final String? selectedGender;
  final Color primaryColor;
  final bool dark;
  final ValueChanged<String> onGenderChanged;

  const GenderSelectorSection({
    super.key,
    required this.selectedGender,
    required this.primaryColor,
    required this.dark,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip('Male', 'Male'),
        const SizedBox(width: AppDimensions.spacingMdSm),
        _buildChip('Female', 'Female'),
        const SizedBox(width: AppDimensions.spacingMdSm),
        _buildChip('Non-binary', 'Other'),
      ],
    );
  }

  Widget _buildChip(String value, String label) {
    final c = primaryColor;
    final isSelected = selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onGenderChanged(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? c.withValues(alpha: 0.15)
                : c.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color:
                  isSelected ? c.withValues(alpha: 0.3) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? c : c.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
