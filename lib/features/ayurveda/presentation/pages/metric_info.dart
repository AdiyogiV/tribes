import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Metric Info — concise explanations for each health signal
// ─────────────────────────────────────────────────────────────────────────────

class MetricRange {
  final String label;
  final String range;
  final Color color;
  const MetricRange(this.label, this.range, this.color);
}

class MetricInfo {
  final String explanation;
  final String ayurvedicNote;
  final List<MetricRange> ranges;
  const MetricInfo({
    required this.explanation,
    required this.ayurvedicNote,
    required this.ranges,
  });
}

const metricInfoMap = <String, MetricInfo>{
  'heartRate': MetricInfo(
    explanation:
        'Your current heart rate — how fast your heart is beating right now. '
        'Varies with activity, stress, caffeine, and emotions.',
    ayurvedicNote:
        'Directly reflects Vyana Vayu (circulatory force). Fast pulse may indicate '
        'Pitta or Vata aggravation. Slow, steady pulse suggests Kapha dominance.',
    ranges: [
      MetricRange('Resting', '60–100 bpm', Color(0xFF27AE60)),
      MetricRange('Elevated', '100–120 bpm', Color(0xFFE67E22)),
      MetricRange('High', '> 120 bpm', Color(0xFFE74C3C)),
    ],
  ),
  'hrv': MetricInfo(
    explanation:
        'Variation between heartbeats, controlled by your nervous system. '
        'Higher HRV means better stress resilience and recovery.',
    ayurvedicNote:
        'Reflects Prana Vayu (life force). High HRV suggests active Vata energy. '
        'Low HRV may indicate Kapha stagnation in the heart channels.',
    ranges: [
      MetricRange('Good', '> 50 ms', Color(0xFF27AE60)),
      MetricRange('Fair', '25–50 ms', Color(0xFFE67E22)),
      MetricRange('Low', '< 25 ms', Color(0xFFE74C3C)),
    ],
  ),
  'restingHR': MetricInfo(
    explanation:
        'Heart rate at complete rest. Lower values usually mean better '
        'cardiovascular fitness. Consistently elevated may signal stress.',
    ayurvedicNote:
        'Relates to Sadhaka Pitta (heart fire). '
        'Elevated RHR suggests Pitta aggravation; very low may indicate Kapha calm.',
    ranges: [
      MetricRange('Good', '< 65 bpm', Color(0xFF27AE60)),
      MetricRange('Normal', '65–80 bpm', Color(0xFFE67E22)),
      MetricRange('Elevated', '> 80 bpm', Color(0xFFE74C3C)),
    ],
  ),
  'spO2': MetricInfo(
    explanation:
        'Oxygen in your blood. Your cells need adequate oxygen for energy '
        'and repair. Below 95% may need attention.',
    ayurvedicNote:
        'Prana flowing through respiratory channels (Pranavaha Srotas). '
        'Low oxygen may indicate Kapha blockage. Pranayama can help.',
    ranges: [
      MetricRange('Normal', '≥ 95%', Color(0xFF27AE60)),
      MetricRange('Fair', '92–94%', Color(0xFFE67E22)),
      MetricRange('Low', '< 92%', Color(0xFFE74C3C)),
    ],
  ),
  'respRate': MetricInfo(
    explanation:
        'Breaths per minute at rest. Reflects your respiratory health '
        'and stress levels.',
    ayurvedicNote:
        'Direct reflection of Prana Vayu. Fast breathing suggests Vata aggravation. '
        'Nadi Shodhana (alternate nostril breathing) can restore balance.',
    ranges: [
      MetricRange('Normal', '12–20 /min', Color(0xFF27AE60)),
      MetricRange('Elevated', '> 20 /min', Color(0xFFE74C3C)),
    ],
  ),
  'steps': MetricInfo(
    explanation:
        'Daily step count — a simple measure of how active you are. '
        'Regular movement supports heart, mood, and metabolism.',
    ayurvedicNote:
        'Movement circulates Vyana Vayu. Too little aggravates Kapha (lethargy). '
        'Too much depletes Vata (exhaustion). Find your balance.',
    ranges: [
      MetricRange('Active', '> 8,000', Color(0xFF27AE60)),
      MetricRange('Fair', '4–8,000', Color(0xFFE67E22)),
      MetricRange('Low', '< 4,000', Color(0xFFE74C3C)),
    ],
  ),
  'activeEnergy': MetricInfo(
    explanation:
        'Calories burned through physical activity today, '
        'not counting your resting metabolism.',
    ayurvedicNote:
        'Reflects Agni (metabolic fire) transformation. Strong Agni = active energy output. '
        'Low output may mean the digestive fire needs stoking.',
    ranges: [
      MetricRange('Active', '> 300 kcal', Color(0xFF27AE60)),
      MetricRange('Low', '< 150 kcal', Color(0xFFE67E22)),
    ],
  ),
  'sleepHours': MetricInfo(
    explanation:
        'Total sleep duration. Quality matters as much as hours — '
        'deep sleep repairs, REM processes emotions.',
    ayurvedicNote:
        'Nidra is one of three pillars of health in Ayurveda. '
        'Insufficient sleep depletes Ojas (vitality). Excess creates Ama (toxins).',
    ranges: [
      MetricRange('Good', '7–9 hrs', Color(0xFF27AE60)),
      MetricRange('Fair', '5–7 hrs', Color(0xFFE67E22)),
      MetricRange('Low', '< 5 hrs', Color(0xFFE74C3C)),
    ],
  ),
  'wristTemp': MetricInfo(
    explanation:
        'Deviation from your baseline. Small shifts are normal; '
        'larger changes may signal illness or hormonal shifts.',
    ayurvedicNote:
        'Directly reflects Pitta dosha. Elevated = more fire in the body. '
        'Decreased = Vata or Kapha cooling influence.',
    ranges: [
      MetricRange('Stable', '± 0.3°C', Color(0xFF27AE60)),
      MetricRange('Shifted', '> 0.3°C', Color(0xFFE74C3C)),
    ],
  ),
  'vo2Max': MetricInfo(
    explanation:
        'Maximum oxygen your body uses during exercise. '
        'A key marker of cardiovascular fitness.',
    ayurvedicNote:
        'Efficiency of Prana distribution. Higher values indicate '
        'clear channels and strong life force.',
    ranges: [
      MetricRange('Good', '> 40', Color(0xFF27AE60)),
      MetricRange('Fair', '30–40', Color(0xFFE67E22)),
      MetricRange('Low', '< 30', Color(0xFFE74C3C)),
    ],
  ),
  'hrRecovery': MetricInfo(
    explanation:
        'How quickly your heart rate drops after exercise. '
        'Faster recovery indicates better cardiovascular fitness.',
    ayurvedicNote:
        'Reflects the resilience of Ojas. Strong recovery means the heart\'s '
        'fire (Sadhaka Pitta) is balanced and channels are clear.',
    ranges: [
      MetricRange('Good', '≥ 20 bpm', Color(0xFF27AE60)),
      MetricRange('Fair', '12–20 bpm', Color(0xFFE67E22)),
      MetricRange('Low', '< 12 bpm', Color(0xFFE74C3C)),
    ],
  ),
  'mindfulMins': MetricInfo(
    explanation:
        'Minutes spent in mindfulness or meditation today. '
        'Regular practice supports stress resilience and emotional balance.',
    ayurvedicNote:
        'Dhyana (meditation) is a core Ayurvedic practice. '
        'It calms Vata, cools Pitta, and energizes Kapha.',
    ranges: [
      MetricRange('Good', '≥ 10 min', Color(0xFF27AE60)),
      MetricRange('Brief', '< 10 min', Color(0xFFE67E22)),
    ],
  ),
  'deepSleepMins': MetricInfo(
    explanation:
        'Time in deep (slow-wave) sleep. This is when your body '
        'does most physical repair and growth hormone release.',
    ayurvedicNote:
        'Deep sleep is when Ojas (vitality essence) is replenished. '
        'Insufficient deep sleep depletes immunity and strength.',
    ranges: [
      MetricRange('Good', '≥ 60 min', Color(0xFF27AE60)),
      MetricRange('Fair', '30–60 min', Color(0xFFE67E22)),
      MetricRange('Low', '< 30 min', Color(0xFFE74C3C)),
    ],
  ),
  'remSleepMins': MetricInfo(
    explanation:
        'REM sleep is when dreams occur and emotional memories '
        'are processed. Essential for cognitive function and mood.',
    ayurvedicNote:
        'REM relates to Manas (mind) processing. Sufficient REM '
        'keeps Sadhaka Pitta balanced and supports mental clarity.',
    ranges: [
      MetricRange('Good', '≥ 90 min', Color(0xFF27AE60)),
      MetricRange('Fair', '60–90 min', Color(0xFFE67E22)),
      MetricRange('Low', '< 60 min', Color(0xFFE74C3C)),
    ],
  ),
  'walkingSteadiness': MetricInfo(
    explanation:
        'How steady you are on your feet during daily movement. '
        'Changes may indicate balance issues, fatigue, or injury risk.',
    ayurvedicNote:
        'Balance reflects harmony of all three doshas. Unsteadiness '
        'suggests Vata aggravation affecting Asthi Dhatu (bones/joints).',
    ranges: [
      MetricRange('OK', 'Stable', Color(0xFF27AE60)),
      MetricRange('Low', 'Declining', Color(0xFFE67E22)),
      MetricRange('Very Low', 'Unstable', Color(0xFFE74C3C)),
    ],
  ),

  // ── Beat-to-beat HRV ───────────────────────────────────────────────────
  'rmssd': MetricInfo(
    explanation:
        'RMSSD (Root Mean Square of Successive Differences) measures '
        'beat-to-beat heart rate variability — the gold standard marker '
        'of parasympathetic (vagal) tone. Higher values indicate better '
        'recovery and stress resilience.',
    ayurvedicNote:
        'High vagal tone reflects strong Prana Vayu and balanced Ojas. '
        'Low RMSSD suggests Vata aggravation and depleted vitality.',
    ranges: [
      MetricRange('Good', '≥ 50 ms', Color(0xFF27AE60)),
      MetricRange('Fair', '20–49 ms', Color(0xFFE67E22)),
      MetricRange('Low', '< 20 ms', Color(0xFFE74C3C)),
    ],
  ),

  // ── Walking & Gait ────────────────────────────────────────────────────
  'walkingHR': MetricInfo(
    explanation:
        'Your average heart rate during walking. Lower values suggest '
        'better cardiovascular efficiency.',
    ayurvedicNote:
        'Elevated walking HR may signal Pitta aggravation or Agni '
        'working hard to metabolize during movement.',
    ranges: [
      MetricRange('Normal', '< 110 bpm', Color(0xFF27AE60)),
      MetricRange('Elevated', '110–130 bpm', Color(0xFFE67E22)),
      MetricRange('High', '> 130 bpm', Color(0xFFE74C3C)),
    ],
  ),

  // ── Activity ──────────────────────────────────────────────────────────
  'standHours': MetricInfo(
    explanation:
        'Hours during which you stood and moved for at least 1 minute. '
        'Consistent standing breaks improve circulation and posture.',
    ayurvedicNote:
        'Regular movement prevents Kapha stagnation and supports '
        'Vyana Vayu (circulation of energy through the body).',
    ranges: [
      MetricRange('Good', '≥ 10 hrs', Color(0xFF27AE60)),
      MetricRange('Fair', '6–9 hrs', Color(0xFFE67E22)),
      MetricRange('Low', '< 6 hrs', Color(0xFFE74C3C)),
    ],
  ),
  'exerciseMins': MetricInfo(
    explanation:
        'Minutes of exercise at or above a brisk walk, as measured by '
        'your Apple Watch activity ring.',
    ayurvedicNote:
        'Balanced exercise supports Agni and all doshas. Over-exercise '
        'aggravates Vata; under-exercise allows Kapha accumulation.',
    ranges: [
      MetricRange('Good', '≥ 30 min', Color(0xFF27AE60)),
      MetricRange('Fair', '15–29 min', Color(0xFFE67E22)),
      MetricRange('Low', '< 15 min', Color(0xFFE74C3C)),
    ],
  ),
  'distance': MetricInfo(
    explanation:
        'Total distance covered today from walking, running, and other '
        'movement tracked by your Apple Watch.',
    ayurvedicNote:
        'Movement supports Vyana Vayu (circulation) and helps balance '
        'Kapha. Excessive distance may aggravate Vata.',
    ranges: [
      MetricRange('Active', '≥ 5 km', Color(0xFF27AE60)),
      MetricRange('Fair', '2–5 km', Color(0xFFE67E22)),
      MetricRange('Low', '< 2 km', Color(0xFFE74C3C)),
    ],
  ),
  'workoutMins': MetricInfo(
    explanation:
        'Total recorded workout minutes today. Includes all workout '
        'types tracked by the Apple Watch Workout app.',
    ayurvedicNote:
        'Structured exercise strengthens Ojas and supports Agni. '
        'The type and intensity should match your Prakriti.',
    ranges: [
      MetricRange('Active', '≥ 30 min', Color(0xFF27AE60)),
      MetricRange('Moderate', '15–29 min', Color(0xFFE67E22)),
      MetricRange('Light', '< 15 min', Color(0xFFE74C3C)),
    ],
  ),

  // ── Ojas Vitality ──────────────────────────────────────────────────────
  'ojasScore': MetricInfo(
    explanation:
        'Ojas is a composite vitality score (0–100) computed from all your '
        'Apple Watch signals. It combines sleep quality, heart rhythm, '
        'blood oxygen, breathing, movement, fitness, and recovery into '
        'a single measure of overall wellbeing.',
    ayurvedicNote:
        'In Ayurveda, Ojas is the subtle essence of all seven Dhatus '
        '(tissues). It represents your immunity, vitality, and life '
        'force. High Ojas means strong immunity and mental clarity. '
        'Low Ojas manifests as fatigue, low immunity, and brain fog.',
    ranges: [
      MetricRange('Vital', '85–100', Color(0xFF27AE60)),
      MetricRange('Steady', '70–84', Color(0xFF27AE60)),
      MetricRange('Moderate', '55–69', Color(0xFFE67E22)),
      MetricRange('Depleted', '40–54', Color(0xFFE67E22)),
      MetricRange('Rest', '< 40', Color(0xFFE74C3C)),
    ],
  ),
};

/// Get info for a metric key, with a safe fallback.
MetricInfo getMetricInfo(String key) {
  return metricInfoMap[key] ??
      const MetricInfo(
        explanation: 'Health signal from your Apple Watch.',
        ayurvedicNote: 'Part of your body\'s natural intelligence.',
        ranges: [],
      );
}
