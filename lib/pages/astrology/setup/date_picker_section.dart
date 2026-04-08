import 'package:flutter/material.dart';
import 'picker_widget.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Date picker section for birth date selection.
class DatePickerSection extends StatelessWidget {
  final int day;
  final int month;
  final int year;
  final Color primaryColor;
  final bool dark;
  final FixedExtentScrollController dayController;
  final FixedExtentScrollController monthController;
  final FixedExtentScrollController yearController;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  const DatePickerSection({
    super.key,
    required this.day,
    required this.month,
    required this.year,
    required this.primaryColor,
    required this.dark,
    required this.dayController,
    required this.monthController,
    required this.yearController,
    required this.onDayChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  List<String> get _days => List.generate(31, (i) => '${i + 1}');

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  List<String> get _years => List.generate(
      DateTime.now().year - 1920 + 1, (i) => '${DateTime.now().year - i}');

  @override
  Widget build(BuildContext context) {
    final c = primaryColor;
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: [
          // Day
          Expanded(
            flex: 2,
            child: SetupPicker(
              items: _days,
              controller: dayController,
              onChanged: onDayChanged,
              primaryColor: c,
              dark: dark,
              label: 'Day',
            ),
          ),
          PickerDivider(primaryColor: c),
          // Month
          Expanded(
            flex: 3,
            child: SetupPicker(
              items: _months,
              controller: monthController,
              onChanged: onMonthChanged,
              primaryColor: c,
              dark: dark,
              label: 'Month',
            ),
          ),
          PickerDivider(primaryColor: c),
          // Year
          Expanded(
            flex: 3,
            child: SetupPicker(
              items: _years,
              controller: yearController,
              onChanged: onYearChanged,
              primaryColor: c,
              dark: dark,
              label: 'Year',
            ),
          ),
        ],
      ),
    );
  }
}
