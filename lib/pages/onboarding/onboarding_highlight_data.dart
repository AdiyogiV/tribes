/// Static data helpers for highlights: dasha, nakshatra, and yoga content.
/// Extracted from onboarding_complete.dart to reduce file size.
library;

import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class OnboardingHighlightData {
  static List<Map<String, dynamic>> buildHighlights(AstrologyProfile profile) {
    final highlights = <Map<String, dynamic>>[];

    // 1. Raj Yoga (if present) - most special
    if (profile.rajYogas != null && profile.rajYogas!.isNotEmpty) {
      final yoga = profile.rajYogas!.first;
      final yogaName = yoga['name'] ?? yoga['yoga'] ?? 'Raj Yoga';
      final yogaDesc = yoga['description'] ??
          yoga['meaning'] ??
          'A powerful combination bringing success and prosperity';
      highlights.add({
        'type': 'yoga',
        'icon': Icons.auto_awesome_rounded,
        'title': yogaName,
        'subtitle': 'Special Blessing in Your Chart',
        'description': yogaDesc,
        'color': AppTheme.amberAccent,
      });
    }

    // 2. Current Dasha - always relevant
    if (profile.currentDasha != null) {
      final dasha = profile.currentDasha!;
      final mahaDasha = dasha['mahadasha'] ?? dasha['maha_dasha'] ?? '';
      final antarDasha = dasha['antardasha'] ?? dasha['antar_dasha'] ?? '';

      if (mahaDasha.toString().isNotEmpty) {
        final desc = getDashaDescription(mahaDasha.toString());
        final periodInfo = getDashaPeriodInfo(dasha);
        highlights.add({
          'type': 'dasha',
          'icon': Icons.blur_circular_rounded,
          'title': '$mahaDasha Mahadasha',
          'subtitle': antarDasha.toString().isNotEmpty
              ? 'Currently in $antarDasha phase'
              : 'Your Current Life Chapter',
          'description': '$desc${periodInfo.isNotEmpty ? '\n$periodInfo' : ''}',
          'color': AppTheme.cosmicPurple,
        });
      }
    }

    // 3. Nakshatra - personal identity
    final nakshatra = profile.moonNakshatra ?? profile.nakshatra;
    if (nakshatra != null && nakshatra.isNotEmpty) {
      final info = getNakshatraInfo(nakshatra);
      highlights.add({
        'type': 'nakshatra',
        'icon': Icons.nights_stay_rounded,
        'title': nakshatra,
        'subtitle': info['title'] ?? 'Moon Nakshatra',
        'description': info['description'] ??
            'Your lunar mansion reveals your soul\'s nature',
        'color': AppTheme.emeraldGreen,
      });
    }

    return highlights.take(3).toList();
  }

  static String getDashaDescription(String dasha) {
    const descriptions = {
      'Sun':
          'A time of increased confidence, leadership opportunities, and self-discovery.',
      'Moon':
          'An emotionally rich period bringing deeper connections and intuition.',
      'Mars':
          'An energetic phase for taking action and pursuing your ambitions.',
      'Mercury':
          'A period favoring learning, communication, and intellectual growth.',
      'Jupiter': 'A blessed time of expansion, wisdom, and good fortune.',
      'Venus':
          'A beautiful period for love, creativity, and enjoying life\'s pleasures.',
      'Saturn':
          'A time for building lasting foundations through discipline and patience.',
      'Rahu':
          'A transformative period of worldly ambitions and unconventional paths.',
      'Ketu': 'A spiritual phase of letting go and inner growth.',
    };
    return descriptions[dasha] ??
        'A significant planetary period shaping your journey.';
  }

  static String getDashaPeriodInfo(Map<String, dynamic> dasha) {
    try {
      final levels = dasha['levels'] as Map<String, dynamic>?;
      if (levels != null && levels['maha'] != null) {
        final mahaEnd = levels['maha']['end'];
        if (mahaEnd != null) {
          final endDate = DateTime.parse(mahaEnd.toString());
          final years = endDate.difference(DateTime.now()).inDays ~/ 365;
          if (years > 0) {
            return '~$years years remaining in this phase';
          }
        }
      }
    } catch (_) {
      AppLogger.w('OnboardingComplete: dasha phase calculation failed', category: LogCategory.general);
    }
    return '';
  }

  static Map<String, String> getNakshatraInfo(String nakshatra) {
    const info = {
      'Ashwini': {
        'title': 'The Star of Transport',
        'description':
            'Swift healers with pioneering spirit. You have natural ability to initiate and heal.'
      },
      'Bharani': {
        'title': 'The Star of Restraint',
        'description':
            'Creative transformers with deep intensity. You understand life\'s cycles deeply.'
      },
      'Krittika': {
        'title': 'The Star of Fire',
        'description':
            'Sharp, purifying presence with strong determination. You cut through illusion.'
      },
      'Rohini': {
        'title': 'The Star of Ascent',
        'description':
            'Naturally creative and magnetic. Beauty and growth follow wherever you go.'
      },
      'Mrigashira': {
        'title': 'The Searching Star',
        'description':
            'Curious seekers with gentle nature. Your quest for truth leads to wisdom.'
      },
      'Ardra': {
        'title': 'The Storm Star',
        'description':
            'Transformative intellect with emotional depth. You bring necessary change.'
      },
      'Punarvasu': {
        'title': 'The Star of Renewal',
        'description':
            'Optimistic nurturers with wisdom. You have the gift of starting fresh.'
      },
      'Pushya': {
        'title': 'The Nourishing Star',
        'description':
            'Deeply caring and spiritual. Your support helps others flourish.'
      },
      'Ashlesha': {
        'title': 'The Embracing Star',
        'description':
            'Intuitive and mysterious. You understand hidden truths others miss.'
      },
      'Magha': {
        'title': 'The Royal Star',
        'description':
            'Natural authority and ancestral connection. Leadership comes naturally.'
      },
      'Purva Phalguni': {
        'title': 'The Star of Fortune',
        'description':
            'Creative and romantic soul. You bring joy and beauty to life.'
      },
      'Uttara Phalguni': {
        'title': 'The Star of Patronage',
        'description':
            'Generous helper who creates prosperity. Others trust you deeply.'
      },
      'Hasta': {
        'title': 'The Hand Star',
        'description':
            'Skillful creator with clever mind. Your hands bring ideas to life.'
      },
      'Chitra': {
        'title': 'The Bright Star',
        'description':
            'Brilliant visionary with artistic gifts. You see beauty in possibility.'
      },
      'Swati': {
        'title': 'The Self-Going Star',
        'description':
            'Independent and balanced. You find your own path with grace.'
      },
      'Vishakha': {
        'title': 'The Star of Purpose',
        'description':
            'Determined achiever with clear goals. Your focus brings success.'
      },
      'Anuradha': {
        'title': 'The Star of Success',
        'description':
            'Devoted friend who achieves goals. Loyalty and success define you.'
      },
      'Jyeshtha': {
        'title': 'The Elder Star',
        'description':
            'Protective wisdom with natural authority. You guide and protect others.'
      },
      'Mula': {
        'title': 'The Root Star',
        'description':
            'Deep investigator who transforms. You get to the root of everything.'
      },
      'Purva Ashadha': {
        'title': 'The Invincible Star',
        'description':
            'Confident warrior who purifies. Victory follows your convictions.'
      },
      'Uttara Ashadha': {
        'title': 'The Universal Star',
        'description':
            'Principled leader who endures. Your integrity wins lasting respect.'
      },
      'Shravana': {
        'title': 'The Star of Learning',
        'description':
            'Wise listener who connects. Knowledge flows to you naturally.'
      },
      'Dhanishtha': {
        'title': 'The Star of Symphony',
        'description':
            'Rhythmic and prosperous. You create harmony in all you do.'
      },
      'Shatabhisha': {
        'title': 'The Hundred Healers',
        'description':
            'Mysterious healer with independence. You solve what others cannot.'
      },
      'Purva Bhadrapada': {
        'title': 'The Burning Pair',
        'description':
            'Intense spiritual warrior. Your passion transforms everything.'
      },
      'Uttara Bhadrapada': {
        'title': 'The Warrior Star',
        'description':
            'Deep wisdom with self-control. Inner strength is your power.'
      },
      'Revati': {
        'title': 'The Wealthy Star',
        'description':
            'Nurturing and prosperous soul. You guide others to safe harbor.'
      },
    };
    return info[nakshatra] ??
        {
          'title': 'Moon Nakshatra',
          'description':
              'Your lunar mansion reveals your soul\'s unique gifts and nature.'
        };
  }

  static String getExpandedHighlightContent(String title, String type) {
    switch (type) {
      case 'yoga':
        return getYogaExpandedContent(title);
      case 'dasha':
        return getDashaExpandedContent(title);
      case 'nakshatra':
        return getNakshatraExpandedContent(title);
      default:
        return 'This is a unique aspect of your birth chart that influences your life path.';
    }
  }

  static String getYogaExpandedContent(String yogaName) {
    final yogaInsights = {
      'Gaja Kesari':
          'This blessing in your chart indicates you\'ll gain wisdom and respect through your life. People naturally look to you for guidance.',
      'Budh Aditya':
          'Your mind and will align powerfully. You have the ability to communicate with authority and clarity.',
      'Chandra Mangal':
          'Financial prosperity tends to flow to you. Your emotional drive creates material success.',
      'Neechabhanga Raja':
          'A debilitation cancelled—what seemed like weakness becomes your greatest strength. Your challenges transform into victories.',
      'Viparita Raja':
          'Obstacles dissolve before you. You have the karmic blessing of enemies turning into stepping stones.',
      'Dhana':
          'Wealth accumulation is favored in your chart. You have natural ability to grow resources.',
      'Pancha Mahapurusha':
          'A great person yoga. You carry the energy of exceptional capability in specific life areas.',
      'Saraswati':
          'The goddess of knowledge blesses you. Learning, creativity, and eloquence come naturally.',
      'Lakshmi':
          'Prosperity and beauty naturally gravitate toward you. You attract abundance with grace.',
    };

    for (final entry in yogaInsights.entries) {
      if (yogaName.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return 'This special combination in your chart brings unique blessings. It indicates a favorable alignment that supports your success and growth.';
  }

  static String getDashaExpandedContent(String dashaTitle) {
    final planet = dashaTitle.replaceAll(' Mahadasha', '').trim();

    final dashaInsights = {
      'Sun':
          'Now is the time to step into your authority. Focus on leadership roles, health, and father-related matters. Your confidence is your currency.',
      'Moon':
          'Emotional growth takes center stage. Pay attention to mother, home, and inner peace. Your intuition is heightened—trust it.',
      'Mars':
          'Energy and ambition peak. Take bold action on your goals. Physical health and brothers/siblings are highlighted. Channel aggression constructively.',
      'Mercury':
          'Communication and learning are favored. Business, writing, and intellectual pursuits flourish. Stay adaptable and curious.',
      'Jupiter':
          'A blessed period of expansion. Wisdom, teachers, and opportunities for growth appear. Be generous—it returns multiplied.',
      'Venus':
          'Love, beauty, and comfort are highlighted. Relationships, creativity, and pleasures bring fulfillment. Enjoy life while creating value.',
      'Saturn':
          'Hard work builds lasting foundations. Patience is required but rewards are permanent. Discipline transforms into mastery.',
      'Rahu':
          'Unconventional paths open. Worldly ambitions intensify. This is a time to break patterns and explore new territories.',
      'Ketu':
          'Spiritual growth accelerates. Past patterns release. Focus inward—external losses often mean internal gains.',
    };

    return dashaInsights[planet] ??
        'This planetary period shapes your current life chapter. Pay attention to its themes—they\'re your curriculum right now.';
  }

  static String getNakshatraExpandedContent(String nakshatra) {
    final nakshatraInsights = {
      'Ashwini':
          'Your healing ability is innate—not just physical, but the power to restore hope. Quick decisions often serve you well.',
      'Bharani':
          'You understand transformation at a soul level. You can hold space for others going through difficult changes.',
      'Krittika':
          'Your clarity cuts through confusion. When you speak truth, others can\'t ignore it. Use this power wisely.',
      'Rohini':
          'Creative fertility flows through you. Whatever you nurture grows beautifully. Your appreciation for beauty is a gift, not indulgence.',
      'Mrigashira':
          'Your search leads you to discoveries others miss. Restlessness is your teacher—it pushes you toward growth.',
      'Ardra':
          'You process the storms others avoid. Your willingness to face darkness makes you a powerful catalyst for change.',
      'Punarvasu':
          'Renewal is your superpower. No matter what happens, you find your way back to center. This resilience inspires others.',
      'Pushya':
          'Your nurturing nature is your greatest strength. You help others flourish without depleting yourself.',
      'Ashlesha':
          'You perceive what\'s hidden. Trust your instincts about people and situations—they rarely fail you.',
      'Magha':
          'Ancestral blessings flow through you. Honoring your lineage activates your power. You carry royal energy.',
      'Purva Phalguni':
          'Creativity and pleasure are your paths to wisdom. Your joy is productive, not escapism.',
      'Uttara Phalguni':
          'You create through service. Your generosity builds lasting prosperity. Others benefit from your success.',
      'Hasta':
          'Your hands carry intelligence. Whether physical craft or subtle manipulation of energy, skill is your domain.',
      'Chitra':
          'You see the finished masterpiece where others see raw material. Your vision creates beauty in practical form.',
      'Swati':
          'Independence isn\'t loneliness for you—it\'s freedom. Your ability to bend without breaking is your strength.',
      'Vishakha':
          'Determination is your middle name. What you decide to achieve, you achieve. Focus is your superpower.',
      'Anuradha':
          'Devotion in friendship and purpose creates your success. Your loyalty attracts equally loyal companions.',
      'Jyeshtha':
          'Elder wisdom flows through you, regardless of age. You protect what matters with fierce dedication.',
      'Mula':
          'You get to the root. Surface solutions don\'t satisfy you. Your investigations reveal fundamental truths.',
      'Purva Ashadha':
          'You purify what you touch. Your convictions have power—use them to elevate, not destroy.',
      'Uttara Ashadha':
          'Final victory is yours. Your principles may be tested, but you emerge with lasting respect.',
      'Shravana':
          'Listening is your path to wisdom. What you learn, you can teach. Knowledge flows through you.',
      'Dhanishtha':
          'Rhythm and prosperity dance together in your life. Your sense of timing brings wealth.',
      'Shatabhisha':
          'Mysterious healing powers are yours. You fix what others give up on. Solitude recharges you.',
      'Purva Bhadrapada':
          'Intense spiritual fire burns in you. Your passion for truth transforms everything it touches.',
      'Uttara Bhadrapada':
          'Depth without attachment—this is your gift. You understand letting go while caring deeply.',
      'Revati':
          'Safe harbor for wandering souls—this is your role. You guide others home to themselves.',
    };

    return nakshatraInsights[nakshatra] ??
        'Your nakshatra reveals the unique flavor of your soul. It influences how you naturally express yourself in the world.';
  }
}
