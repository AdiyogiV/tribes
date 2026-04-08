import 'package:flutter/material.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Utility class for Dasha-related calculations and parsing
class DashaUtils {
  DashaUtils._();

  /// Level metadata for dasha display
  static const List<Map<String, dynamic>> levelMeta = [
    {'key': 'maha', 'label': 'Maha Dasha', 'icon': Icons.wb_sunny_rounded},
    {'key': 'antar', 'label': 'Antar Dasha', 'icon': Icons.brightness_medium_rounded},
    {'key': 'pratyantar', 'label': 'Pratyantar', 'icon': Icons.auto_awesome_motion_rounded},
    {'key': 'sookshma', 'label': 'Sookshma', 'icon': Icons.grain_rounded},
    {'key': 'praana', 'label': 'Praana', 'icon': Icons.bubble_chart_rounded},
    {'key': 'deha', 'label': 'Deha', 'icon': Icons.blur_on_rounded},
  ];

  /// Extract all dasha levels from dasha data
  static List<Map<String, dynamic>> extractDashaLevels(Map<String, dynamic>? dasha) {
    if (dasha == null) return [];
    final rawLevels = dasha['levels'];
    if (rawLevels is! Map<String, dynamic>) return [];

    final List<Map<String, dynamic>> levels = [];

    for (final meta in levelMeta) {
      final levelKey = meta['key'] as String;
      final levelData = rawLevels[levelKey];
      if (levelData is! Map<String, dynamic>) continue;
      final lord = levelData['lord']?.toString();
      if (lord == null || lord.isEmpty) continue;

      levels.add({
        'key': levelKey,
        'label': meta['label'],
        'icon': meta['icon'],
        'lord': lord,
        'startDate': levelData['startDate']?.toString(),
        'endDate': levelData['endDate']?.toString(),
      });
    }

    return levels;
  }

  /// Parse dasha date string to DateTime
  static DateTime? parseDashaDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    try {
      final parsed = DateTime.parse(normalized).toLocal();
      // Validate parsed date is reasonable
      if (parsed.year < 1900 || parsed.year > 2100) return null;
      return parsed;
    } catch (e) {
      AppLogger.w(
        'Failed to parse dasha date',
        category: LogCategory.general,
        data: {'raw': raw, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Calculate progress through a dasha period (0.0 to 1.0)
  static double? calculateDashaProgress(String? start, String? end) {
    final startDate = parseDashaDate(start);
    final endDate = parseDashaDate(end);
    if (startDate == null || endDate == null) return null;
    if (!endDate.isAfter(startDate)) return null;

    try {
      final now = DateTime.now();
      final total = endDate.difference(startDate).inSeconds.toDouble();
      final elapsed = now.difference(startDate).inSeconds.toDouble();

      if (total <= 0) return null;

      final progress = (elapsed / total).clamp(0.0, 1.0);
      if (progress.isNaN || !progress.isFinite) return null;
      return progress;
    } catch (e) {
      AppLogger.w(
        'Error calculating dasha progress',
        category: LogCategory.general,
        data: {'start': start, 'end': end, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Format dasha date range (DD/MM/YYYY → DD/MM/YYYY)
  static String formatDashaDateRange(String? start, String? end) {
    final startDate = parseDashaDate(start);
    final endDate = parseDashaDate(end);
    final startLabel = _formatDateLabel(startDate);
    final endLabel = _formatDateLabel(endDate);
    if (startLabel == null && endLabel == null) {
      return 'Dates unavailable';
    }
    return '${startLabel ?? '—'} → ${endLabel ?? '—'}';
  }

  /// Format short date range (Jan '24 → Dec '25)
  static String formatShortDashaDateRange(String? start, String? end) {
    final startDate = parseDashaDate(start);
    final endDate = parseDashaDate(end);
    if (startDate == null && endDate == null) return '—';

    String formatShort(DateTime? date) {
      if (date == null) return '—';
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return "${months[date.month - 1]} '${date.year.toString().substring(2)}";
    }

    return '${formatShort(startDate)} → ${formatShort(endDate)}';
  }

  /// Format duration label (e.g., "2y 3m")
  static String? formatDurationLabel(String? start, String? end) {
    final startDate = parseDashaDate(start);
    final endDate = parseDashaDate(end);
    if (startDate == null || endDate == null) return null;
    final totalDays = endDate.difference(startDate).inDays;
    if (totalDays <= 0) return null;
    final years = totalDays ~/ 365;
    final months = (totalDays % 365) ~/ 30;
    final days = totalDays % 30;
    final parts = <String>[];
    if (years > 0) parts.add('${years}y');
    if (months > 0) parts.add('${months}m');
    if (parts.isEmpty && days > 0) parts.add('${days}d');
    return parts.join(' ');
  }

  static String? _formatDateLabel(DateTime? date) {
    if (date == null) return null;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Extract all Maha Dashas
  static List<Map<String, dynamic>> extractMahaDashas(Map<String, dynamic>? dasha) {
    final list = dasha?['allMahaDashas'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  /// Extract Antar Dashas for current Maha Dasha
  static List<Map<String, dynamic>> extractAntarDashasForCurrent(Map<String, dynamic>? dasha) {
    if (dasha == null) return [];
    final levels = dasha['levels'];
    final currentMaha = levels is Map<String, dynamic>
        ? levels['maha'] as Map<String, dynamic>?
        : null;
    final currentLord = currentMaha?['lord']?.toString().toLowerCase();
    if (currentLord == null) return [];

    final mahas = extractMahaDashas(dasha);
    Map<String, dynamic>? activeMaha;
    for (final maha in mahas) {
      final lordName = maha['lord']?.toString().toLowerCase();
      if (lordName == currentLord) {
        activeMaha = maha;
        break;
      }
    }
    if (activeMaha == null) return [];
    final antars = activeMaha['antarDashas'];
    if (antars is! List) return [];
    return antars
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  /// Extract detailed periods for a specific level
  static List<Map<String, dynamic>> extractDetailedPeriodsForLevel(
      String levelKey, Map<String, dynamic>? dasha) {
    final detailed = dasha?['detailed'];
    if (detailed is! Map<String, dynamic>) return [];
    final keyMap = {
      'pratyantar': 'pratyantar_dasa',
      'sookshma': 'sookshma_antar_dasa',
      'praana': 'praana_antar_dasa',
      'deha': 'deha_antar_dasa',
    };
    final targetKey = keyMap[levelKey] ?? '${levelKey}_dasa';
    final source = detailed[targetKey];
    return _flattenDetailedSource(source);
  }

  /// Extract periods for a dasha level
  static List<Map<String, dynamic>> extractPeriodsForLevel(
      String levelKey, Map<String, dynamic>? dasha) {
    if (dasha == null) return [];
    if (levelKey == 'maha') {
      return _normalizePeriodList(
        extractMahaDashas(dasha),
        levelKey: levelKey,
      );
    }
    if (levelKey == 'antar') {
      return _normalizePeriodList(
        extractAntarDashasForCurrent(dasha),
        levelKey: levelKey,
      );
    }
    return _normalizePeriodList(
      extractDetailedPeriodsForLevel(levelKey, dasha),
      levelKey: levelKey,
    );
  }

  static List<Map<String, dynamic>> _flattenDetailedSource(dynamic source) {
    if (source is List) {
      return source
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    }

    if (source is Map<String, dynamic>) {
      final possibleLists = [
        'list', 'periods', 'items', 'children',
        'antar_dasa_list', 'pratyantar_dasa_list',
        'sookshma_dasa_list', 'praana_dasa_list', 'deha_dasa_list',
      ];
      for (final key in possibleLists) {
        if (source.containsKey(key)) {
          final nested = _flattenDetailedSource(source[key]);
          if (nested.isNotEmpty) return nested;
        }
      }
      return [source];
    }

    return [];
  }

  static List<Map<String, dynamic>> _normalizePeriodList(
      List<Map<String, dynamic>> raw,
      {required String levelKey}) {
    final normalized = <Map<String, dynamic>>[];
    for (final entry in raw) {
      final normalizedEntry = _normalizePeriodEntry(entry, levelKey);
      if (normalizedEntry != null) normalized.add(normalizedEntry);
    }
    return normalized;
  }

  static Map<String, dynamic>? _normalizePeriodEntry(
      Map<String, dynamic> entry, String levelKey) {
    final lord = (entry['lord'] ?? entry['Lord'])?.toString();
    if (lord == null || lord.isEmpty) return null;
    final start =
        (entry['startDate'] ?? entry['start_date'] ?? entry['start_time'])
            ?.toString();
    final end = (entry['endDate'] ?? entry['end_date'] ?? entry['end_time'])
        ?.toString();
    return {
      'level': levelKey,
      'lord': lord,
      'startDate': start,
      'endDate': end,
    };
  }
}




