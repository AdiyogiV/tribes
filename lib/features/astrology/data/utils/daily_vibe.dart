// Daily Vibe — translates Tara Bala (Vedic concept) into plain-English,
// actionable daily guidance.
//
// Product rationale: most users won't recognize "Sampat Tara" but they
// will understand "Building Energy — great for starting projects." The
// vibe layer is what we show first; the underlying Tara is fine print.

import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/data/utils/nakshatra_data.dart';

/// A plain-English daily energy description with concrete suggestions.
///
/// Each [TaraType] maps to exactly one [DailyVibe].  This is the layer
/// the user reads first — short, actionable, and free of Sanskrit.
class DailyVibe {
  /// Short, evocative name — e.g. "Building Energy".
  final String label;

  /// Material icon representing this vibe's character.
  final IconData icon;

  /// One-to-two sentence narrative.  Plain English, no jargon.
  final String narrative;

  /// 2–3 concrete things this energy supports.
  final List<String> goodFor;

  /// 1–2 concrete things to skip today.
  final List<String> avoid;

  /// Accent colour for the card (favourable = green, mixed = primary,
  /// cautious = amber/red, sacred = gold).
  final VibeTone tone;

  const DailyVibe({
    required this.label,
    required this.icon,
    required this.narrative,
    required this.goodFor,
    required this.avoid,
    required this.tone,
  });

  /// Resolve the vibe for a user given their birth nakshatra and today's
  /// Moon nakshatra.  Returns null when birth data is missing — callers
  /// should render the empty-state prompt instead.
  static DailyVibe? forUser({
    required int birthIndex,
    required int todayIndex,
  }) {
    if (birthIndex < 0 || todayIndex < 0) return null;
    final tara = TaraBala.calculate(birthIndex, todayIndex);
    return _byTara[tara.type];
  }

  /// Direct lookup by Tara type (handy for previews / detail card).
  static DailyVibe? forTara(TaraType type) => _byTara[type];

  // ──────────────────────────────────────────────────────────────────────
  // Tara → Vibe mapping
  // ──────────────────────────────────────────────────────────────────────
  static const Map<TaraType, DailyVibe> _byTara = {
    TaraType.janma: DailyVibe(
      label: 'Sacred Energy',
      icon: Icons.spa_rounded,
      narrative:
          'The Moon returns to your birth star today. '
          'An inward day — take time for reflection and honour what feels true.',
      goodFor: ['Self-reflection', 'Rituals & prayer', 'Resting deeply'],
      avoid: ['Big launches', 'Overcommitting socially'],
      tone: VibeTone.sacred,
    ),
    TaraType.sampat: DailyVibe(
      label: 'Building Energy',
      icon: Icons.trending_up_rounded,
      narrative:
          'A growth-oriented day. What you plant now tends to take root — '
          'set intentions and follow through on new beginnings.',
      goodFor: ['Starting projects', 'Learning something new', 'Money matters'],
      avoid: ['Closing things prematurely'],
      tone: VibeTone.favorable,
    ),
    TaraType.vipat: DailyVibe(
      label: 'Cautious Energy',
      icon: Icons.visibility_rounded,
      narrative:
          'Subtle friction today. Not a bad day — just one that '
          'punishes shortcuts. Slow down and double-check the details.',
      goodFor: ['Reviewing work', 'Routine tasks', 'Careful planning'],
      avoid: ['Big decisions', 'Signing contracts'],
      tone: VibeTone.cautious,
    ),
    TaraType.kshema: DailyVibe(
      label: 'Easy Energy',
      icon: Icons.water_drop_rounded,
      narrative:
          'A gentle, well-supported day. Things tend to land softly — '
          'lean into comfort and let small good things accumulate.',
      goodFor: ['Family time', 'Healing & self-care', 'Important meetings'],
      avoid: ['Forcing aggressive moves'],
      tone: VibeTone.favorable,
    ),
    TaraType.pratyari: DailyVibe(
      label: 'Resistance Energy',
      icon: Icons.shield_rounded,
      narrative:
          'Headwinds today. Push too hard and things push back. '
          'Patience and diplomacy will carry you further than force.',
      goodFor: ['Diplomatic conversations', 'Persistence on long projects'],
      avoid: ['Confrontations', 'Critical negotiations'],
      tone: VibeTone.cautious,
    ),
    TaraType.sadhaka: DailyVibe(
      label: 'Focused Energy',
      icon: Icons.center_focus_strong_rounded,
      narrative:
          'Discipline pays a premium today. Pick one important thing '
          'and commit fully — the day rewards depth over breadth.',
      goodFor: ['Deep work', 'Launches', 'Bold initiatives'],
      avoid: ['Multitasking', 'Distractions'],
      tone: VibeTone.favorable,
    ),
    TaraType.vadha: DailyVibe(
      label: 'Restraint Energy',
      icon: Icons.pause_circle_outline_rounded,
      narrative:
          'A day that rewards stillness over reaction. Take care of '
          'yourself and let any provocations pass without engaging.',
      goodFor: ['Rest', 'Gentle routine', 'Health appointments'],
      avoid: ['Risky activity', 'Conflict', 'Long travel'],
      tone: VibeTone.cautious,
    ),
    TaraType.mitra: DailyVibe(
      label: 'Connected Energy',
      icon: Icons.people_outline_rounded,
      narrative:
          'Doors open through conversation today. Good outcomes '
          'arrive through other people — reach out instead of going it alone.',
      goodFor: ['Networking', 'Collaboration', 'Calling old friends'],
      avoid: ['Withdrawing into isolation'],
      tone: VibeTone.favorable,
    ),
    TaraType.paramaMitra: DailyVibe(
      label: 'Flow Energy',
      icon: Icons.auto_awesome_rounded,
      narrative:
          'The most auspicious day of your cycle. '
          'Things align with less effort than usual — use the day deliberately.',
      goodFor: ['Anything important', 'Big moves', 'Asking for what you want'],
      avoid: ['Wasting the day passively'],
      tone: VibeTone.flow,
    ),
  };
}

/// Visual tone of a vibe — drives the card accent colour.
enum VibeTone {
  /// Favourable — green accent.
  favorable,

  /// Mixed / cautious — amber accent.
  cautious,

  /// Janma — gold / introspective.
  sacred,

  /// Parama Mitra — most auspicious, brightest accent.
  flow,
}

/// Resolve a tone to a concrete colour for a given brightness.
Color vibeAccent(VibeTone tone, {required bool isDark}) {
  switch (tone) {
    case VibeTone.favorable:
      return isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    case VibeTone.cautious:
      return isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
    case VibeTone.sacred:
      return const Color(0xFFB8860B); // dark gold — same as Janma Day badge
    case VibeTone.flow:
      return const Color(0xFFFFD700); // bright gold
  }
}
