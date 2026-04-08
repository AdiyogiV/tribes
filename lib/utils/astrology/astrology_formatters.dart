import 'package:aurogram/utils/logging/app_logger.dart';

/// Utility class for astrology-related date/time formatting
class AstrologyFormatters {
  AstrologyFormatters._();

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  static const List<String> _weekdaysShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  /// Format today's date nicely (e.g., "Thu, Dec 4")
  static String formatTodayDate() {
    final now = DateTime.now();
    return '${_weekdaysShort[now.weekday - 1]}, ${_monthsShort[now.month - 1]} ${now.day}';
  }

  /// Get full month name from month number (1-12)
  static String getMonthName(int month) {
    if (month < 1 || month > 12) return '';
    return _months[month - 1];
  }

  /// Get short month name from month number (1-12)
  static String getMonthNameShort(int month) {
    if (month < 1 || month > 12) return '';
    return _monthsShort[month - 1];
  }

  /// Get full weekday name from weekday number (1-7, Monday=1)
  static String getWeekdayName(int weekday) {
    if (weekday < 1 || weekday > 7) return '';
    return _weekdays[weekday - 1];
  }

  /// Get short weekday name from weekday number (1-7, Monday=1)
  static String getWeekdayNameShort(int weekday) {
    if (weekday < 1 || weekday > 7) return '';
    return _weekdaysShort[weekday - 1];
  }

  /// Format time string to 12-hour format with AM/PM
  static String formatTime12Hour(String? time) {
    if (time == null || time.isEmpty) return '—';
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        return '$hour:$minute $period';
      }
    } catch (_) {
      AppLogger.w('AstrologyFormatters: failed to parse time string', category: LogCategory.general);
    }
    return time;
  }

  /// Format relative time (e.g., "just now", "5m ago", "2h ago")
  static String formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  /// Format latitude with direction (e.g., "23.45° North of Equator")
  static String formatLatitude(double lat) {
    final dir = lat >= 0 ? 'North' : 'South';
    return '${lat.abs().toStringAsFixed(2)}° $dir of Equator';
  }

  /// Format longitude with direction (e.g., "75.80° East of Greenwich")
  static String formatLongitude(double lng) {
    final dir = lng >= 0 ? 'East' : 'West';
    return '${lng.abs().toStringAsFixed(2)}° $dir of Greenwich';
  }

  /// Format latitude relative to Ujjain (Hindu Prime Meridian)
  static String formatLatitudeFromUjjain(double lat) {
    const ujjainLat = 23.183; // 23°11'N
    final offset = lat - ujjainLat;
    final dir = offset >= 0 ? 'North' : 'South';
    return '${offset.abs().toStringAsFixed(2)}° $dir of Ujjain';
  }

  /// Format longitude relative to Ujjain (Hindu Prime Meridian)
  static String formatLongitudeFromUjjain(double lng) {
    const ujjainLng = 75.767; // 75°46'E
    final offset = lng - ujjainLng;
    final dir = offset >= 0 ? 'East' : 'West';
    return '${offset.abs().toStringAsFixed(2)}° $dir of Ujjain';
  }

  /// Format a date label (DD/MM/YYYY)
  static String? formatDateLabel(DateTime? date) {
    if (date == null) return null;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Format time with AM/PM from absolute minutes
  static String formatTimeWithAMPM(int absoluteMinutes) {
    final minutesOfDay = absoluteMinutes % (24 * 60);
    final hour = minutesOfDay ~/ 60;
    final min = minutesOfDay % 60;
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = hour < 12 ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} $ampm';
  }

  /// Parse time string to minutes since midnight
  static int parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timePart = parts.length > 1 ? parts[1] : parts[0];
      final timeComponents = timePart.split(':');
      if (timeComponents.length >= 2) {
        final hours = int.parse(timeComponents[0]);
        final minutes = int.parse(timeComponents[1]);
        return hours * 60 + minutes;
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return 0;
  }

  /// Format date key to human readable (e.g., "Today", "Tomorrow", "Mon, 12/4")
  static String formatDateKey(String dateKey) {
    try {
      final parts = dateKey.split('-');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final today = DateTime.now();
        final tomorrow = today.add(const Duration(days: 1));

        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          return 'Today';
        } else if (date.year == tomorrow.year &&
            date.month == tomorrow.month &&
            date.day == tomorrow.day) {
          return 'Tomorrow';
        } else {
          return '${_weekdaysShort[date.weekday - 1]}, ${date.month}/${date.day}';
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return dateKey;
  }

  /// Calculate Prahar from birth time (Vedic time division)
  /// 1 Prahar = 3 hours, starting from sunrise (~6 AM)
  static Map<String, dynamic>? calculatePrahar(String? birthTime) {
    if (birthTime == null || birthTime.isEmpty) return null;
    
    try {
      final parts = birthTime.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        // Minutes from sunrise (approximating sunrise at 6:00 AM)
        const sunriseHour = 6;
        var minutesFromSunrise = (hour - sunriseHour) * 60 + minute;
        if (minutesFromSunrise < 0) minutesFromSunrise += 24 * 60;

        // Calculate Prahar (1 Prahar = 3 hours = 180 minutes)
        final prahar = (minutesFromSunrise ~/ 180) + 1;
        final praharNames = [
          'Pratham', 'Dwitiya', 'Tritiya', 'Chaturth',
          'Pancham', 'Shashth', 'Saptam', 'Ashtam'
        ];
        final praharName = praharNames[(prahar - 1) % 8];

        // Convert to Ghatis (1 Ghati = 24 minutes)
        final totalGhatis = minutesFromSunrise / 24.0;
        final ghatis = totalGhatis.floor();
        final palas = ((totalGhatis - ghatis) * 60).round();

        return {
          'prahar': prahar,
          'praharName': praharName,
          'ghatis': ghatis,
          'palas': palas,
        };
      }
    } catch (_) {
      AppLogger.w('AstrologyFormatters: failed to calculate Vedic time units', category: LogCategory.general);
    }
    return null;
  }
}




