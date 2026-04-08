import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A utility class for displaying time with consistent formatting
class TimeDisplay {
  /// Format time text for display in the UI
  /// Uses light font weight to make it less prominent as requested
  static Widget formatTimeText(
    DateTime? dateTime, {
    double fontSize = 12.0,
    Color? color,
    TextAlign align = TextAlign.start,
  }) {
    if (dateTime == null) {
      return Text(
        '',
        style: TextStyle(
          fontSize: fontSize,
          color: color ?? Colors.grey[400],
          fontWeight:
              FontWeight.w300, // Lighter weight to make it less prominent
        ),
        textAlign: align,
      );
    }

    final String formattedTime = _getFormattedTimeString(dateTime);

    return Text(
      formattedTime,
      style: TextStyle(
        fontSize: fontSize,
        color: color ?? Colors.grey[500],
        fontWeight: FontWeight.w300, // Lighter weight to make it less prominent
        letterSpacing:
            0.2, // Slightly wider letter spacing for better readability
      ),
      textAlign: align,
    );
  }

  /// Get formatted time string based on how long ago the date was
  /// Uses compact format (e.g., "2d", "4mo", "5y") for consistency
  static String _getFormattedTimeString(DateTime dateTime) {
    return getCompactTimestamp(dateTime);
  }

  /// Get a compact timestamp (e.g., "5m", "2h", "3d")
  static String getCompactTimestamp(DateTime dateTime) {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo';
    } else {
      return '${(difference.inDays / 365).floor()}y';
    }
  }

  /// Get full date and time (e.g., "Jan 5, 2023 at 2:30 PM")
  static String getFullDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy \'at\' h:mm a').format(dateTime);
  }

  /// Get date only (e.g., "January 5, 2023")
  static String getDateOnly(DateTime dateTime) {
    return DateFormat('MMMM d, yyyy').format(dateTime);
  }

  /// Get time only (e.g., "2:30 PM")
  static String getTimeOnly(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Get compact timestamp text widget for UI
  /// This is the preferred method for displaying timestamps consistently across the app
  static Widget getCompactTimestampWidget(
    DateTime dateTime, {
    double fontSize = 11,
    Color? color,
    FontWeight fontWeight = FontWeight.w300,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Text(
      getCompactTimestamp(dateTime),
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      ),
      textAlign: textAlign,
    );
  }

  /// Get relative time (e.g., "5 minutes ago", "Yesterday", "Last week")
  /// @deprecated Use getCompactTimestamp() instead for consistency across the app
  @Deprecated(
      'Use getCompactTimestamp() instead for consistency across the app')
  static String getRelativeTime(DateTime dateTime) {
    // For backwards compatibility, redirect to compact timestamp
    return getCompactTimestamp(dateTime);
  }

  /// Get time ago in full words (e.g. "5 minutes ago", "1 hour ago", "2 days ago", "1 year ago")
  /// Use for feed captions and anywhere a more readable timestamp is needed.
  static String getTimeAgo(DateTime dateTime) {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      return m == 1 ? '1 minute ago' : '$m minutes ago';
    } else if (difference.inHours < 24) {
      final h = difference.inHours;
      return h == 1 ? '1 hour ago' : '$h hours ago';
    } else if (difference.inDays < 7) {
      final d = difference.inDays;
      return d == 1 ? '1 day ago' : '$d days ago';
    } else if (difference.inDays < 30) {
      final w = (difference.inDays / 7).floor();
      return w == 1 ? '1 week ago' : '$w weeks ago';
    } else if (difference.inDays < 365) {
      final mo = (difference.inDays / 30).floor();
      return mo == 1 ? '1 month ago' : '$mo months ago';
    } else {
      final y = (difference.inDays / 365).floor();
      return y == 1 ? '1 year ago' : '$y years ago';
    }
  }
}
