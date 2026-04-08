import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Reusable Cupertino-style picker used in date/time sections.
class SetupPicker extends StatelessWidget {
  final List<String> items;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onChanged;
  final Color primaryColor;
  final bool dark;
  final String label;
  final bool isMeridiem;

  const SetupPicker({
    super.key,
    required this.items,
    required this.controller,
    required this.onChanged,
    required this.primaryColor,
    required this.dark,
    required this.label,
    this.isMeridiem = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = primaryColor;
    return Column(
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
          ),
        Expanded(
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 36,
            diameterRatio: 1.1,
            squeeze: 1.0,
            selectionOverlay: Container(
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
              ),
            ),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            children: items
                .map((s) => Center(
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: isMeridiem ? 14 : 18,
                          fontWeight: FontWeight.w600,
                          color: c,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// Vertical divider between picker columns.
class PickerDivider extends StatelessWidget {
  final Color primaryColor;

  const PickerDivider({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: primaryColor.withValues(alpha: 0.08),
    );
  }
}
