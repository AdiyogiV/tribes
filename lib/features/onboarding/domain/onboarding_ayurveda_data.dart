/// Static data helpers for Ayurveda descriptions and expanded content.
/// Extracted from onboarding_complete.dart to reduce file size.
library;

import 'package:aurogram/shared/models/ayurveda_profile.dart';

class OnboardingAyurvedaData {
  // Card 1: Constitution Description (2-3 lines, interesting, direct)
  static String getConstitutionDescription(
      PrakritiData prakriti, bool isTridoshic, bool isDualDosha) {
    if (isTridoshic) {
      return 'All three doshas are balanced. You adapt well to different situations.';
    } else if (isDualDosha) {
      final doshas = prakriti.type.toLowerCase().split('-');
      final primary = doshas[0];
      final secondary = doshas.length > 1 ? doshas[1] : '';

      String primaryDesc = '';
      if (primary == 'vata') {
        primaryDesc = 'Creative and quick';
      } else if (primary == 'pitta') {
        primaryDesc = 'Focused and sharp';
      } else if (primary == 'kapha') {
        primaryDesc = 'Calm and steady';
      }

      String secondaryDesc = '';
      if (secondary == 'vata') {
        secondaryDesc = 'energetic';
      } else if (secondary == 'pitta') {
        secondaryDesc = 'driven';
      } else if (secondary == 'kapha') {
        secondaryDesc = 'grounded';
      }

      return '$primaryDesc, with $secondaryDesc qualities. Your nature shifts with seasons and life phases.';
    } else {
      final dominant = prakriti.dominant.toLowerCase();

      if (dominant == 'vata') {
        return 'You\'re creative, quick-thinking, and energetic. Your mind moves fast and you adapt easily.';
      } else if (dominant == 'pitta') {
        return 'You\'re focused, driven, and sharp. You\'re goal-oriented and organized.';
      } else if (dominant == 'kapha') {
        return 'You\'re calm, steady, and nurturing. You have strong stamina and stay grounded.';
      } else {
        return 'Your unique nature shapes how you experience the world.';
      }
    }
  }

  // Card 2: Dosha Balance Title
  static String getDoshaBalanceTitle(PrakritiData prakriti, bool isTridoshic) {
    if (isTridoshic) {
      return 'Balanced';
    } else {
      return 'Prakriti';
    }
  }

  // Card 2: Dosha Balance Description
  static String getDoshaBalanceDescription(
      PrakritiData prakriti, bool isTridoshic) {
    if (isTridoshic) {
      return 'All three doshas are evenly balanced';
    } else {
      return 'Your natural dosha levels';
    }
  }

  // Card 3: Vikriti Title
  static String getVikritiTitle(VikritiData vikriti) {
    if (vikriti.isBalanced) {
      return 'Balanced';
    } else {
      final imbalances = vikriti.imbalances;
      if (imbalances.isNotEmpty) {
        final dosha = imbalances[0].dosha;
        return dosha.substring(0, 1).toUpperCase() + dosha.substring(1);
      }
      return 'Current State';
    }
  }

  // Card 3: Vikriti Description
  static String getVikritiDescription(VikritiData vikriti) {
    if (vikriti.isBalanced) {
      return 'Your current balance matches your natural state. You\'re in harmony.';
    } else {
      final imbalances = vikriti.imbalances;
      if (imbalances.isNotEmpty) {
        final dosha = imbalances[0].dosha.toLowerCase();
        if (dosha == 'vata') {
          return 'You may feel scattered or anxious. Focus on staying grounded and warm.';
        } else if (dosha == 'pitta') {
          return 'You may feel irritable or overheated. Focus on cooling down and taking breaks.';
        } else if (dosha == 'kapha') {
          return 'You may feel sluggish or heavy. Focus on staying active and moving.';
        }
      }
      return 'Your current balance has shifted. Understanding this helps you adjust.';
    }
  }

  // Expanded Vikriti Content
  static String getExpandedVikritiContent(
      VikritiData vikriti, PrakritiData prakriti) {
    final isBalanced = vikriti.isBalanced;
    final imbalances = vikriti.imbalances;
    final dominant = prakriti.dominant.toLowerCase();

    if (isBalanced) {
      return 'You\'re in harmony right now. Your current state matches your natural baseline.\n\n'
          'You\'re likely feeling balanced, healthy, and at ease. This is ideal - you\'re aligned with your natural constitution.\n\n'
          'To maintain this:\n'
          '• Continue your current practices\n'
          '• Pay attention to seasonal changes\n'
          '• Stay attuned to your body\'s signals';
    } else {
      String content = '';
      String tips = '';

      if (imbalances.isNotEmpty) {
        for (var imbalance in imbalances) {
          final String dosha = imbalance.dosha;
          // ignore: unused_local_variable
          final doshaName =
              dosha.substring(0, 1).toUpperCase() + dosha.substring(1);

          if (dosha.toLowerCase() == 'vata') {
            if (dominant == 'vata') {
              content =
                  'Your creative, quick-thinking nature is elevated right now. You may be feeling more scattered, anxious, or having trouble sleeping than usual.\n\n'
                  'This happens when you\'re overstimulated or have too much change. Your mind is moving even faster than normal, which can leave you feeling ungrounded.\n\n';
            } else {
              content =
                  'Your creative, quick-thinking side is elevated right now. You may be feeling scattered, anxious, or having trouble sleeping.\n\n'
                  'This is different from your natural state. You\'re experiencing more movement and change than usual, which can feel unsettling.\n\n';
            }
            tips = '• Keep warm, maintain routines\n'
                '• Eat warm, nourishing foods\n'
                '• Practice grounding activities\n'
                '• Slow down and create stability';
          } else if (dosha.toLowerCase() == 'pitta') {
            if (dominant == 'pitta') {
              content =
                  'Your focused, driven nature is elevated right now. You may be feeling more irritable, overheated, or experiencing acidity than usual.\n\n'
                  'This happens when you\'re pushing too hard or under stress. Your drive is intensified, which can make you feel burned out or critical.\n\n';
            } else {
              content =
                  'Your focused, driven side is elevated right now. You may be feeling irritable, overheated, or experiencing acidity.\n\n'
                  'This is different from your natural state. You\'re experiencing more intensity and heat than usual, which can feel overwhelming.\n\n';
            }
            tips = '• Stay cool, avoid excessive heat\n'
                '• Eat cooling foods\n'
                '• Practice moderation\n'
                '• Take breaks and relax';
          } else if (dosha.toLowerCase() == 'kapha') {
            if (dominant == 'kapha') {
              content =
                  'Your steady, patient nature is elevated right now. You may be feeling more sluggish, heavy, or resistant to change than usual.\n\n'
                  'This happens when you\'re too comfortable or stagnant. Your stability is intensified, which can make you feel stuck or unmotivated.\n\n';
            } else {
              content =
                  'Your steady, patient side is elevated right now. You may be feeling sluggish, heavy, or resistant to change.\n\n'
                  'This is different from your natural state. You\'re experiencing more heaviness and stability than usual, which can feel limiting.\n\n';
            }
            tips = '• Stay active, maintain variety\n'
                '• Eat light, warm foods\n'
                '• Avoid stagnation\n'
                '• Create movement and stimulation';
          }
        }
      }

      content += 'To restore balance:\n'
          '$tips';

      return content;
    }
  }

  static String getExpandedConstitutionContent(
      String type, bool isTridoshic, bool isDualDosha, PrakritiData prakriti) {
    if (isTridoshic) {
      return 'You adapt well to different situations. This is rare.\n\n'
          'You can thrive in various environments, but you need to pay attention to your body\'s signals. When you feel off, one of your doshas may be shifting.\n\n'
          'Maintain regular routines and adjust your diet and activities based on seasons.';
    } else if (isDualDosha) {
      final doshas = type.toLowerCase().split('-');
      final primary = doshas[0];
      final secondary = doshas.length > 1 ? doshas[1] : '';

      String content = '';
      String tips = '';

      if (primary == 'vata' && secondary == 'pitta') {
        content =
            'You\'re creative and quick-thinking, but also focused and driven. Your mind moves fast and you get things done.\n\n'
            'You thrive on new ideas and projects, but you need structure to channel your energy. Without it, you can feel scattered or burn out.\n\n'
            'You\'re naturally innovative - you see possibilities others miss. But you also need to slow down sometimes and let ideas settle.';
        tips =
            '• Keep warm, maintain routines\n• Eat warm, nourishing foods\n• Take breaks to cool down\n• Balance creativity with structure';
      } else if (primary == 'vata' && secondary == 'kapha') {
        content =
            'You\'re creative and energetic, but also steady and grounded. Your mind moves fast, but you have the stamina to follow through.\n\n'
            'You\'re naturally adaptable - you can shift between being spontaneous and being methodical. This makes you versatile, but you need to watch for extremes.\n\n'
            'You may find yourself swinging between wanting change and wanting stability. Learning to balance both helps you thrive.';
        tips =
            '• Keep warm, maintain routines\n• Eat warm, nourishing foods\n• Stay active but don\'t overdo it\n• Balance spontaneity with structure';
      } else if (primary == 'pitta' && secondary == 'vata') {
        content =
            'You\'re focused and driven, but also creative and quick-thinking. You\'re goal-oriented, but your mind moves fast.\n\n'
            'You get things done efficiently, but you also have bursts of inspiration. You need to channel your drive without burning out.\n\n'
            'You\'re naturally organized, but you also need flexibility. Too much structure can stifle your creativity, too little can make you scattered.';
        tips =
            '• Stay cool, avoid excessive heat\n• Eat cooling foods\n• Maintain routines but allow flexibility\n• Balance focus with creativity';
      } else if (primary == 'pitta' && secondary == 'kapha') {
        content =
            'You\'re focused and driven, but also steady and patient. You\'re goal-oriented, but you have the stamina to see things through.\n\n'
            'You\'re naturally organized and methodical. You plan well and execute consistently. But you need to watch for becoming too rigid.\n\n'
            'You have strong willpower and determination. You can push through challenges, but you also need to take breaks and not overwork yourself.';
        tips =
            '• Stay cool, avoid excessive heat\n• Eat cooling foods\n• Stay active but don\'t overwork\n• Balance drive with rest';
      } else if (primary == 'kapha' && secondary == 'vata') {
        content =
            'You\'re steady and grounded, but also creative and adaptable. You have strong stamina, but your mind can move fast.\n\n'
            'You\'re naturally patient and reliable, but you also have bursts of energy and inspiration. You can be both methodical and spontaneous.\n\n'
            'You may find yourself wanting stability but also craving change. Learning to embrace both helps you grow without losing your grounding.';
        tips =
            '• Stay active, maintain variety\n• Eat light, warm foods\n• Keep warm, maintain routines\n• Balance stability with change';
      } else if (primary == 'kapha' && secondary == 'pitta') {
        content =
            'You\'re steady and patient, but also focused and driven. You have strong stamina, but you\'re also goal-oriented.\n\n'
            'You\'re naturally reliable and methodical. You plan well and follow through consistently. But you need to watch for becoming too comfortable.\n\n'
            'You have the patience to see things through and the drive to achieve goals. You work steadily, but you also need stimulation to avoid stagnation.';
        tips =
            '• Stay active, maintain variety\n• Eat light, warm foods\n• Stay cool, avoid excessive heat\n• Balance patience with drive';
      } else {
        content =
            'You have qualities from both doshas. This blend means you experience characteristics from both. One may feel stronger during different seasons or life phases.';
        tips =
            '• Pay attention to your body\'s signals\n• Adjust your routine based on how you feel\n• Maintain balance between both doshas';
      }

      return '$content\n\n'
          'To stay balanced:\n'
          '$tips';
    } else {
      final dominant = prakriti.dominant.toLowerCase();
      String content = '';
      String tips = '';

      if (dominant == 'vata') {
        content =
            'You\'re naturally creative, quick-thinking, and energetic. Your mind moves fast and you adapt easily.\n\n'
            'You thrive on new experiences and ideas. You\'re innovative and flexible - you see possibilities others miss. But you need grounding to channel your energy.\n\n'
            'You may find yourself jumping from one thing to another. While this keeps you engaged, you also need routines to feel stable. Without them, you can feel scattered or anxious.';
        tips =
            '• Keep warm, maintain routines\n• Eat warm, nourishing foods\n• Practice grounding activities\n• Avoid excessive travel or change';
      } else if (dominant == 'pitta') {
        content =
            'You\'re naturally focused, driven, and sharp. You\'re goal-oriented and organized.\n\n'
            'You get things done efficiently. You\'re a natural leader with clear vision. You thrive on challenges and achievement. But you need to watch for burning out.\n\n'
            'You may find yourself pushing too hard or being too critical. While this drives results, you also need to slow down and take breaks. Without them, you can feel irritable or overheated.';
        tips =
            '• Stay cool, avoid excessive heat\n• Eat cooling foods\n• Practice moderation\n• Take time for relaxation';
      } else if (dominant == 'kapha') {
        content =
            'You\'re naturally calm, steady, and nurturing. You have strong stamina and stay grounded.\n\n'
            'You\'re reliable and patient. You have the endurance to see things through. You thrive on routine and stability. But you need stimulation to avoid stagnation.\n\n'
            'You may find yourself getting too comfortable or resistant to change. While this provides security, you also need variety and activity. Without them, you can feel sluggish or heavy.';
        tips =
            '• Stay active, regular exercise\n• Eat light, warm foods\n• Maintain variety\n• Wake up early, avoid excessive sleep';
      } else {
        return 'Your unique nature shapes how you experience the world. Pay attention to what makes you feel balanced and what throws you off.';
      }

      return '$content\n\n'
          'To stay balanced:\n'
          '$tips';
    }
  }

  static String getExpandedPercentagesContent(
      PrakritiData prakriti, bool isTridoshic) {
    final vata = prakriti.vata;
    final pitta = prakriti.pitta;
    final kapha = prakriti.kapha;

    if (isTridoshic) {
      return 'Your baseline shows roughly equal Vata, Pitta, and Kapha. That balance is rare.\n\n'
          'Think of this as your natural "set point." Day to day, one dosha may temporarily increase (stress, season, diet), but your system tends to return to this equilibrium.\n\n'
          'Noticing when you feel off helps you spot which dosha is elevated so you can gently adjust—diet, routine, or rest—until you feel aligned again.';
    } else {
      final dominant = prakriti.dominant.toLowerCase();
      String content = '';

      if (dominant == 'vata') {
        if (pitta > kapha) {
          content =
              'Your creative, quick-thinking nature is strongest. Your focused, driven side supports it.\n\n'
              'You\'re naturally innovative and adaptable. You see possibilities quickly and act on them. Your drive helps you follow through, but you need to watch for burning out.\n\n'
              'You may find yourself jumping between ideas and projects. While this keeps you engaged, you also need routines to feel stable.';
        } else {
          content =
              'Your creative, quick-thinking nature is strongest. Your steady, patient side supports it.\n\n'
              'You\'re naturally innovative and adaptable. You see possibilities quickly, and your patience helps you see them through. But you need to watch for getting stuck.\n\n'
              'You may find yourself wanting change but also craving stability. Learning to balance both helps you thrive.';
        }
      } else if (dominant == 'pitta') {
        if (vata > kapha) {
          content =
              'Your focused, driven nature is strongest. Your creative, quick-thinking side supports it.\n\n'
              'You\'re naturally goal-oriented and efficient. You get things done, and your creativity helps you find new solutions. But you need to watch for overworking.\n\n'
              'You may find yourself pushing too hard or being too critical. While this drives results, you also need flexibility and breaks.';
        } else {
          content =
              'Your focused, driven nature is strongest. Your steady, patient side supports it.\n\n'
              'You\'re naturally goal-oriented and methodical. You plan well and execute consistently. But you need to watch for becoming too rigid.\n\n'
              'You may find yourself working steadily toward goals, but you also need variety and stimulation to avoid stagnation.';
        }
      } else if (dominant == 'kapha') {
        if (vata > pitta) {
          content =
              'Your steady, patient nature is strongest. Your creative, adaptable side supports it.\n\n'
              'You\'re naturally reliable and grounded. You have the stamina to see things through, and your adaptability helps you adjust when needed. But you need to watch for getting too comfortable.\n\n'
              'You may find yourself wanting stability but also craving change. Learning to embrace both helps you grow without losing your grounding.';
        } else {
          content =
              'Your steady, patient nature is strongest. Your focused, driven side supports it.\n\n'
              'You\'re naturally reliable and methodical. You have the patience to see things through and the drive to achieve goals. But you need to watch for becoming too comfortable.\n\n'
              'You may find yourself working steadily, but you also need stimulation and activity to avoid feeling stuck.';
        }
      }

      return '$content\n\n'
          'Pay attention to how you feel - this helps you recognize when you\'re balanced and when you need to adjust.';
    }
  }
}
