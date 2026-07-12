import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gender selector with text buttons.
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildChip('Male', 'MALE'),
          _buildChip('Female', 'FEMALE'),
          _buildChip('Non-binary', 'OTHER'),
        ],
      ),
    );
  }

  Widget _buildChip(String value, String label) {
    final c = primaryColor;
    final isSelected = selectedGender == value;
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onGenderChanged(value);
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: isSelected ? 'serif' : null,
              fontStyle: isSelected ? FontStyle.italic : FontStyle.normal,
              fontWeight: isSelected ? FontWeight.w400 : FontWeight.w600,
              letterSpacing: isSelected ? 1.0 : 3.0,
              color: isSelected ? c : c.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 1,
            width: isSelected ? 24 : 0,
            color: c,
          ),
        ],
      ),
    );
  }
}
