import 'package:flutter/material.dart';
import 'picker_widget.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Time picker section for birth time selection.
class TimePickerSection extends StatelessWidget {
  final int hour;
  final int minute;
  final bool isAM;
  final String? timeZone;
  final Color primaryColor;
  final bool dark;
  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final FixedExtentScrollController ampmController;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final ValueChanged<int> onAmPmChanged;

  const TimePickerSection({
    super.key,
    required this.hour,
    required this.minute,
    required this.isAM,
    required this.timeZone,
    required this.primaryColor,
    required this.dark,
    required this.hourController,
    required this.minuteController,
    required this.ampmController,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onAmPmChanged,
  });

  List<String> get _hours => List.generate(12, (i) => '${i + 1}');
  List<String> get _minutes =>
      List.generate(60, (i) => i.toString().padLeft(2, '0'));

  @override
  Widget build(BuildContext context) {
    final c = primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Row(
            children: [
              // Hour
              Expanded(
                flex: 2,
                child: SetupPicker(
                  items: _hours,
                  controller: hourController,
                  onChanged: onHourChanged,
                  primaryColor: c,
                  dark: dark,
                  label: 'Hour',
                ),
              ),
              // Colon separator
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: c.withValues(alpha: 0.4),
                  ),
                ),
              ),
              // Minute
              Expanded(
                flex: 2,
                child: SetupPicker(
                  items: _minutes,
                  controller: minuteController,
                  onChanged: onMinuteChanged,
                  primaryColor: c,
                  dark: dark,
                  label: 'Min',
                ),
              ),
              PickerDivider(primaryColor: c),
              // AM/PM
              Expanded(
                flex: 2,
                child: SetupPicker(
                  items: const ['AM', 'PM'],
                  controller: ampmController,
                  onChanged: onAmPmChanged,
                  primaryColor: c,
                  dark: dark,
                  label: '',
                  isMeridiem: true,
                ),
              ),
            ],
          ),
        ),
        // Timezone display (only when set)
        if (timeZone != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: c.withValues(alpha: 0.4),
                ),
                const SizedBox(width: AppDimensions.spacingSmMd),
                Text(
                  timeZone!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
