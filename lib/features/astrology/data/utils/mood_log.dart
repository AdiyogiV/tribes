// Mood Log — lightweight daily mood tracker backed by SharedPreferences.
//
// The product goal isn't a mood-tracking app per se — it's to give the
// user a second hook to come back daily (alongside the vibe reading)
// and, over time, surface a connection between "what the day says" and
// "how it actually felt".  That correlation is the long-term magic.
//
// Data shape on disk:
//   key:   mood_log_YYYY-MM-DD  →  value: 0..4 (Mood.index)
//   key:   mood_log_streak_count    →  current streak length
//   key:   mood_log_streak_last     →  YYYY-MM-DD of last logged day
//
// We keep the model deliberately tiny and synchronous-feeling: the
// caller does an `await load()` once on widget init, then everything
// else is in-memory until the next save.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Five-point mood scale.  Order matters — lower index = worse day.
enum Mood {
  rough,
  okay,
  good,
  great,
  amazing,
}

/// Display metadata for a single mood option.
class MoodOption {
  final Mood mood;
  final String emoji;
  final String label;
  final Color color;

  const MoodOption({
    required this.mood,
    required this.emoji,
    required this.label,
    required this.color,
  });
}

/// All mood options in display order.
const List<MoodOption> kMoodOptions = [
  MoodOption(
    mood: Mood.rough,
    emoji: '😔',
    label: 'Rough',
    color: Color(0xFF7986CB), // muted indigo
  ),
  MoodOption(
    mood: Mood.okay,
    emoji: '😐',
    label: 'Okay',
    color: Color(0xFF90A4AE), // blue-grey
  ),
  MoodOption(
    mood: Mood.good,
    emoji: '🙂',
    label: 'Good',
    color: Color(0xFF66BB6A), // light green
  ),
  MoodOption(
    mood: Mood.great,
    emoji: '😄',
    label: 'Great',
    color: Color(0xFF26A69A), // teal
  ),
  MoodOption(
    mood: Mood.amazing,
    emoji: '🤩',
    label: 'Amazing',
    color: Color(0xFFFFB300), // amber
  ),
];

/// Convenience accessor by Mood enum.
MoodOption moodOption(Mood m) => kMoodOptions[m.index];

/// Persistent mood log.  Call [load] once before reading [todayMood] /
/// [streak]; call [setToday] to record today's mood.
class MoodLog {
  static const _prefix = 'mood_log_';
  static const _keyStreakCount = 'mood_log_streak_count';
  static const _keyStreakLast = 'mood_log_streak_last';

  Mood? _todayMood;
  int _streak = 0;

  /// Today's mood, or null if not yet logged.
  Mood? get todayMood => _todayMood;

  /// Current consecutive-day streak.  Resets to 0 if the user misses a day.
  int get streak => _streak;

  /// Format a date as YYYY-MM-DD (the form used as the daily key).
  static String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  /// Read today's mood + current streak from disk.  Cheap & idempotent.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());

    final idx = prefs.getInt('$_prefix$today');
    _todayMood = (idx != null && idx >= 0 && idx < Mood.values.length)
        ? Mood.values[idx]
        : null;

    final storedStreak = prefs.getInt(_keyStreakCount) ?? 0;
    final lastDay = prefs.getString(_keyStreakLast);
    _streak = _validateStreak(
      storedStreak: storedStreak,
      lastDay: lastDay,
      today: today,
    );
  }

  /// Record today's mood and bump the streak if appropriate.
  Future<void> setToday(Mood mood) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));

    await prefs.setInt('$_prefix$today', mood.index);
    _todayMood = mood;

    // Streak logic:
    //  - first log today: previous-last was yesterday → +1; else reset to 1.
    //  - re-log today (changing mood): keep streak unchanged.
    final lastDay = prefs.getString(_keyStreakLast);
    if (lastDay == today) {
      // Already counted today; nothing to do.
      return;
    }
    final next = lastDay == yesterday ? _streak + 1 : 1;
    _streak = next;
    await prefs.setInt(_keyStreakCount, next);
    await prefs.setString(_keyStreakLast, today);
  }

  /// Compute the effective streak given disk state vs. today's date.
  ///
  /// If the last logged day is more than one day in the past, the streak
  /// is broken (returns 0).  Otherwise the stored value is honoured.
  int _validateStreak({
    required int storedStreak,
    required String? lastDay,
    required String today,
  }) {
    if (lastDay == null) return 0;
    if (lastDay == today) return storedStreak;
    // Last entry is yesterday → streak still alive but not yet incremented.
    final now = DateTime.now();
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    if (lastDay == yesterday) return storedStreak;
    // Gap of 2+ days → streak broken.
    return 0;
  }
}
