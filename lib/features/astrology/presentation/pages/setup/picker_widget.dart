import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: c.withValues(alpha: 0.3),
                letterSpacing: 2.0,
              ),
            ),
          ),
        Expanded(
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 44,
            diameterRatio: 1.5,
            squeeze: 1.1,
            selectionOverlay: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: c.withValues(alpha: 0.1), width: 1),
                  bottom: BorderSide(color: c.withValues(alpha: 0.1), width: 1),
                ),
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
                          fontFamily: 'serif',
                          fontSize: isMeridiem ? 16 : 28,
                          fontWeight: FontWeight.w400,
                          color: c,
                          letterSpacing: isMeridiem ? 2.0 : 0.0,
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
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: primaryColor.withValues(alpha: 0.1),
    );
  }
}
