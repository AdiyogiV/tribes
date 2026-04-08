import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Service for processing audio with Gemini via Vertex AI
/// Handles voice messages directly without backend round-trip
/// 
/// Uses Firebase AI Logic SDK (Vertex AI backend) as per:
/// https://firebase.google.com/docs/ai-logic/get-started?platform=flutter
class GeminiAudioService {
  static final GeminiAudioService _instance = GeminiAudioService._internal();
  factory GeminiAudioService() => _instance;
  GeminiAudioService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;

  /// Initialize the Gemini model via Vertex AI with Google Search grounding
  Future<bool> initialize() async {
    if (_isInitialized && _model != null) return true;

    try {
      // Firebase AI Logic - uses Vertex AI backend
      // No API key needed - Firebase handles auth automatically!
      // Using location: 'global' as recommended by Firebase docs
      final ai = FirebaseAI.vertexAI(location: 'global');
      _model = ai.generativeModel(
        model: 'gemini-2.0-flash', // Use the auto-updated alias (supports Google Search grounding)
        generationConfig: GenerationConfig(
          temperature: 1.0, // Recommended temperature for grounding
          maxOutputTokens: 2048,
        ),
        // Enable Google Search grounding for real-time information
        // Supported models: gemini-2.0-flash, gemini-2.5-flash, gemini-2.5-pro
        tools: [
          Tool.googleSearch(),
        ],
      );

      _isInitialized = true;
      AppLogger.i('🤖 Gemini Audio Service initialized via Vertex AI (with Google Search)',
          category: LogCategory.voice);
      return true;
    } catch (e) {
      AppLogger.e('Failed to initialize Gemini Audio Service',
          category: LogCategory.voice, error: e);
      return false;
    }
  }

  /// Process audio file with astrology context and stream response
  /// Returns a stream of text chunks for real-time display
  Stream<String> processAudioWithContext({
    required String audioPath,
    required Map<String, dynamic> astrologyContext,
    List<Map<String, dynamic>>? chatHistory,
    String? userLocation,
  }) async* {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        yield "I'm having trouble connecting to the AI service. Please try again.";
        return;
      }
    }

    try {
      // Read audio file
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        yield "I couldn't find the audio file. Please try recording again.";
        return;
      }

      final Uint8List audioBytes = await audioFile.readAsBytes();
      
      // Detect mime type based on file extension
      String mimeType = 'audio/wav';
      if (audioPath.endsWith('.mp3')) {
        mimeType = 'audio/mp3';
      } else if (audioPath.endsWith('.m4a')) {
        mimeType = 'audio/mp4';
      } else if (audioPath.endsWith('.aac')) {
        mimeType = 'audio/aac';
      }

      AppLogger.i('🎙️ Processing audio with Gemini via Vertex AI',
          category: LogCategory.voice,
          data: {
            'audioSize': audioBytes.length,
            'audioSizeKB': (audioBytes.length / 1024).toStringAsFixed(1),
            'mimeType': mimeType,
            'hasAstrology': astrologyContext.isNotEmpty,
            'model': 'gemini-2.0-flash',
            'location': 'global',
            'chatHistoryCount': chatHistory?.length ?? 0,
            'googleSearchEnabled': true,
          });

      // Log what astrology context we have
      AppLogger.i('🔮 Astrology context for Gemini',
          category: LogCategory.voice,
          data: {
            'hasAscendant': astrologyContext['ascendant'] != null,
            'hasMoonSign': astrologyContext['moonSign'] != null,
            'hasSunSign': astrologyContext['sunSign'] != null,
            'hasNakshatra': astrologyContext['nakshatra'] != null,
            'hasDasha': astrologyContext['currentDasha'] != null,
            'hasPlanets': astrologyContext['planets'] != null,
            'planetsCount': (astrologyContext['planets'] as List?)?.length ?? 0,
            'hasTodayTransits': astrologyContext['todayTransits'] != null,
            'hasYogas': astrologyContext['yogas'] != null || astrologyContext['rajYogas'] != null,
            'hasDoshas': astrologyContext['doshas'] != null,
            'hasNavamsa': astrologyContext['navamsa'] != null,
            'hasDailyInsight': astrologyContext['dailyInsight'] != null,
            'hasBirthChart': astrologyContext['birthChart'] != null,
          });

      // Build the prompt with astrology context
      final systemPrompt = _buildSystemPrompt(astrologyContext, userLocation);
      final historyText = _buildChatHistory(chatHistory);

      // Create content with audio using Vertex AI API
      final prompt = [
        Content.multi([
          TextPart(systemPrompt),
          if (historyText.isNotEmpty) 
            TextPart('\n\n=== CONVERSATION HISTORY ===\n$historyText'),
          TextPart('\n\n=== USER\'S VOICE MESSAGE ===\nListen to and respond to this voice message:'),
          InlineDataPart(mimeType, audioBytes),
        ]),
      ];

      // Stream the response
      AppLogger.i('🚀 Sending audio to Gemini...',
          category: LogCategory.voice);
          
      final response = _model!.generateContentStream(prompt);

      int chunkCount = 0;
      int totalLength = 0;
      bool searchUsed = false;
      
      await for (final chunk in response) {
        // Log chunk structure for debugging (first chunk only)
        if (chunkCount == 0) {
          final candidates = chunk.candidates;
          AppLogger.d('📦 First chunk received',
              category: LogCategory.voice,
              data: {
                'hasCandidates': candidates.isNotEmpty,
                'candidateCount': candidates.length,
              });
        }
        
        // Check for grounding metadata (Google Search results)
        final candidates = chunk.candidates;
        if (candidates.isNotEmpty) {
          final candidate = candidates.first;
          
          // Log grounding metadata if available (per Firebase AI Logic docs)
          try {
            final metadata = candidate.groundingMetadata;
            if (metadata != null && !searchUsed) {
              searchUsed = true;
              
              // Log search queries used
              final queries = metadata.webSearchQueries;
              if (queries.isNotEmpty) {
                AppLogger.i('🔍 Google Search grounding used',
                    category: LogCategory.voice,
                    data: {
                      'searchQueries': queries,
                      'hasSearchEntry': metadata.searchEntryPoint != null,
                    });
              }
              
              // Log grounding chunks (sources)
              final groundingChunks = metadata.groundingChunks;
              if (groundingChunks.isNotEmpty) {
                final sources = groundingChunks
                    .where((c) => c.web != null)
                    .map((c) => c.web?.title ?? c.web?.uri ?? '')
                    .take(3)
                    .toList();
                AppLogger.i('📚 Search sources found',
                    category: LogCategory.voice,
                    data: {'sources': sources, 'totalSources': groundingChunks.length});
              }
            }
          } catch (e) {
            // Grounding metadata might not exist or have different structure
            AppLogger.d('Grounding check: $e', category: LogCategory.voice);
          }
        }
        
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          chunkCount++;
          totalLength += text.length;
          yield text;
        }
      }

      AppLogger.i('✅ Gemini audio response complete',
          category: LogCategory.voice,
          data: {
            'chunks': chunkCount,
            'totalResponseLength': totalLength,
            'searchUsed': searchUsed,
          });
    } catch (e) {
      AppLogger.e('❌ Error processing audio with Gemini',
          category: LogCategory.voice, 
          error: e,
          data: {
            'errorType': e.runtimeType.toString(),
            'errorMessage': e.toString(),
          });
      yield "I had trouble understanding your voice message. Error: ${e.toString().split('\n').first}";
    }
  }

  /// Build system prompt with astrology context
  String _buildSystemPrompt(
      Map<String, dynamic> astrologyContext, String? userLocation) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Check if this is an astrology chat
    final hasAstrology = astrologyContext.isNotEmpty &&
        (astrologyContext['ascendant'] != null ||
            astrologyContext['moonSign'] != null);

    if (hasAstrology) {
      return '''You are HolyCow, a knowledgeable Vedic astrologer in the Tribes app.
Today is $dateStr.
${userLocation != null ? 'The user is located in $userLocation.' : ''}

IMPORTANT - VOICE MESSAGE:
• The user is speaking to you via voice (you can hear their audio)
• They may be speaking in Hindi, English, or mixing both (Hinglish) - understand them naturally
• Respond warmly as if having a conversation
• ALWAYS start your response by briefly acknowledging what you understood from their voice (e.g., "You're asking about..." or "Regarding your question on...") - this helps maintain conversation context

CAPABILITIES:
• You have Google Search - use it for current info, places, travel, weather, news, prices, etc.
• When you search, provide the answer directly with the information found
• Always give complete, actionable answers based on search results

CONVERSATION STYLE:
• Speak warmly and naturally, like a trusted advisor
• Answer the specific question asked - don't overwhelm with unasked information
• Be conversational and invite follow-up questions
• Keep responses focused and under 300 words unless depth is needed

PREDICTION METHODOLOGY (Vedic Principles):
• Dasha is PRIMARY for timing - what the current planetary period allows
• House Lords matter - check who rules the relevant house for this Lagna
• Transits trigger events but only when Dasha supports them

${_buildAstrologyContextString(astrologyContext)}''';
    } else {
      return '''You are a helpful assistant for the Tribes app.
Today's date is $dateStr.
${userLocation != null ? 'The user is located in $userLocation. Tailor your responses to their location.' : ''}

IMPORTANT - VOICE MESSAGE:
• The user is speaking to you via voice (you can hear their audio)
• They may be speaking in Hindi, English, or mixing both - understand them naturally
• Respond helpfully and conversationally
• ALWAYS start your response by briefly acknowledging what you understood from their voice (e.g., "You're asking about..." or "I heard you say...") - this helps maintain conversation context

CAPABILITIES:
• You have Google Search - use it for current info, places, travel, weather, news, prices, etc.
• When you search, provide the answer directly with the information found
• Always give complete, actionable answers

Keep replies under 250 words.''';
    }
  }

  /// Build COMPLETE astrology context string with all available data
  String _buildAstrologyContextString(Map<String, dynamic> ctx) {
    if (ctx.isEmpty) return '';

    final lines = <String>['\n=== USER\'S COMPLETE VEDIC ASTROLOGY PROFILE ==='];

    // === CORE CHART DATA ===
    lines.add('\n--- BIRTH CHART BASICS ---');
    if (ctx['ascendant'] != null) lines.add('☉ Ascendant (Lagna): ${ctx['ascendant']}');
    if (ctx['moonSign'] != null) lines.add('☽ Moon Sign (Rashi): ${ctx['moonSign']}');
    if (ctx['sunSign'] != null) lines.add('☀ Sun Sign: ${ctx['sunSign']}');
    if (ctx['nakshatra'] != null) lines.add('✧ Moon Nakshatra: ${ctx['nakshatra']}');
    if (ctx['lagnaNakshatra'] != null) lines.add('✧ Lagna Nakshatra: ${ctx['lagnaNakshatra']}');
    if (ctx['birthTime'] != null) lines.add('🕐 Birth Time: ${ctx['birthTime']}');
    if (ctx['birthPlace'] != null) lines.add('📍 Birth Place: ${ctx['birthPlace']}');

    // === FULL DASHA SYSTEM ===
    if (ctx['currentDasha'] != null) {
      lines.add('\n--- VIMSHOTTARI DASHA (TIMING) ---');
      final dasha = ctx['currentDasha'];
      if (dasha is Map<String, dynamic>) {
        if (dasha['mahadasha'] != null || dasha['maha_dasha'] != null) {
          lines.add('⟳ Mahadasha: ${dasha['mahadasha'] ?? dasha['maha_dasha']}');
          if (dasha['mahadasha_end'] != null || dasha['maha_end'] != null) {
            lines.add('   Ends: ${dasha['mahadasha_end'] ?? dasha['maha_end']}');
          }
        }
        if (dasha['antardasha'] != null || dasha['antar_dasha'] != null) {
          lines.add('⟳ Antardasha: ${dasha['antardasha'] ?? dasha['antar_dasha']}');
          if (dasha['antardasha_end'] != null || dasha['antar_end'] != null) {
            lines.add('   Ends: ${dasha['antardasha_end'] ?? dasha['antar_end']}');
          }
        }
        if (dasha['pratyantardasha'] != null || dasha['pratyantar_dasha'] != null) {
          lines.add('⟳ Pratyantardasha: ${dasha['pratyantardasha'] ?? dasha['pratyantar_dasha']}');
        }
      }
    }

    // === ALL NATAL PLANETS WITH COMPLETE DATA ===
    if (ctx['planets'] != null && ctx['planets'] is List) {
      lines.add('\n--- NATAL PLANETARY POSITIONS ---');
      for (final p in ctx['planets']) {
        if (p is Map) {
          final name = p['name'] ?? p['planet'];
          final sign = p['sign'] ?? p['rashi'];
          if (name != null && sign != null) {
            var planetInfo = '   $name: $sign';
            if (p['house'] != null) planetInfo += ' in House ${p['house']}';
            if (p['degree'] != null) planetInfo += ' at ${p['degree']}°';
            if (p['nakshatra'] != null) planetInfo += ' (${p['nakshatra']})';
            if (p['retrograde'] == true) planetInfo += ' [RETROGRADE]';
            if (p['combust'] == true) planetInfo += ' [COMBUST]';
            if (p['exalted'] == true) planetInfo += ' [EXALTED]';
            if (p['debilitated'] == true) planetInfo += ' [DEBILITATED]';
            if (p['own_sign'] == true || p['ownSign'] == true) planetInfo += ' [OWN SIGN]';
            lines.add(planetInfo);
          }
        }
      }
    }

    // === HOUSE LORDS (critical for predictions) ===
    if (ctx['birthChart'] != null && ctx['birthChart'] is Map) {
      final chart = ctx['birthChart'] as Map<String, dynamic>;
      if (chart['houseLords'] != null) {
        lines.add('\n--- HOUSE LORDS ---');
        final lords = chart['houseLords'];
        if (lords is Map) {
          lords.forEach((house, lord) {
            lines.add('   House $house Lord: $lord');
          });
        }
      }
    }

    // === CURRENT TRANSITS ===
    if (ctx['todayTransits'] != null && ctx['todayTransits'] is Map) {
      lines.add('\n--- TODAY\'S PLANETARY TRANSITS ---');
      final transits = ctx['todayTransits'] as Map<String, dynamic>;
      for (final entry in transits.entries) {
        final planet = entry.key;
        final data = entry.value;
        if (!['Uranus', 'Neptune', 'Pluto'].contains(planet) && data is Map) {
          var transitInfo = '   $planet transiting: ${data['sign'] ?? '?'}';
          if (data['house'] != null) transitInfo += ' (House ${data['house']})';
          if (data['degree'] != null) transitInfo += ' at ${data['degree']}°';
          if (data['retrograde'] == true) transitInfo += ' [R]';
          lines.add(transitInfo);
        }
      }
    }

    // === YOGAS (BOTH RAJ YOGAS AND OTHER YOGAS) ===
    if (ctx['rajYogas'] != null && ctx['rajYogas'] is List && (ctx['rajYogas'] as List).isNotEmpty) {
      lines.add('\n--- RAJ YOGAS (AUSPICIOUS COMBINATIONS) ---');
      for (final yoga in ctx['rajYogas']) {
        if (yoga is String) {
          lines.add('   ✦ $yoga');
        } else if (yoga is Map) {
          final name = yoga['name'] ?? yoga['yoga'];
          final desc = yoga['description'] ?? yoga['effect'];
          lines.add('   ✦ $name${desc != null ? ': $desc' : ''}');
        }
      }
    }

    if (ctx['yogas'] != null && ctx['yogas'] is List && (ctx['yogas'] as List).isNotEmpty) {
      lines.add('\n--- OTHER YOGAS ---');
      for (final yoga in ctx['yogas']) {
        if (yoga is String) {
          lines.add('   • $yoga');
        } else if (yoga is Map) {
          final name = yoga['name'] ?? yoga['yoga'];
          lines.add('   • $name');
        }
      }
    }
    
    // === YOGAS DETAILED (if available) ===
    if (ctx['yogasDetailed'] != null && ctx['yogasDetailed'] is Map) {
      final detailed = ctx['yogasDetailed'] as Map<String, dynamic>;
      if (detailed.isNotEmpty) {
        lines.add('\n--- DETAILED YOGA ANALYSIS ---');
        detailed.forEach((category, yogaList) {
          if (yogaList is List && yogaList.isNotEmpty) {
            lines.add('   $category:');
            for (final yoga in yogaList) {
              if (yoga is Map) {
                final name = yoga['name'] ?? yoga['yoga'];
                final effect = yoga['effect'] ?? yoga['result'];
                lines.add('      • $name${effect != null ? ': $effect' : ''}');
              } else if (yoga is String) {
                lines.add('      • $yoga');
              }
            }
          }
        });
      }
    }

    // === DOSHAS ===
    if (ctx['doshas'] != null) {
      lines.add('\n--- DOSHAS (AFFLICTIONS) ---');
      final doshas = ctx['doshas'];
      if (doshas is Map) {
        // Doshas is a Map with dosha types as keys
        doshas.forEach((doshaName, doshaData) {
          if (doshaData is Map) {
            final isPresent = doshaData['present'] == true || doshaData['has_dosha'] == true;
            final severity = doshaData['severity'] ?? doshaData['level'];
            if (isPresent) {
              lines.add('   ⚠ $doshaName${severity != null ? ' ($severity)' : ''}');
              if (doshaData['description'] != null) {
                lines.add('      ${doshaData['description']}');
              }
            }
          } else if (doshaData == true) {
            lines.add('   ⚠ $doshaName');
          }
        });
      } else if (doshas is List) {
        // Doshas as a list
        for (final dosha in doshas) {
          if (dosha is String) {
            lines.add('   ⚠ $dosha');
          } else if (dosha is Map) {
            final name = dosha['name'] ?? dosha['dosha'];
            final level = dosha['level'] ?? dosha['severity'];
            lines.add('   ⚠ $name${level != null ? ' ($level)' : ''}');
          }
        }
      }
    }

    // === NAVAMSA (D9) DATA ===
    if (ctx['navamsa'] != null && ctx['navamsa'] is Map) {
      lines.add('\n--- NAVAMSA (D9) CHART ---');
      final navamsa = ctx['navamsa'] as Map<String, dynamic>;
      if (navamsa['ascendant'] != null) lines.add('   Navamsa Lagna: ${navamsa['ascendant']}');
      if (navamsa['moonSign'] != null) lines.add('   Navamsa Moon: ${navamsa['moonSign']}');
    }

    // === PANCHANG DATA ===
    if (ctx['todayPanchang'] != null && ctx['todayPanchang'] is Map) {
      lines.add('\n--- TODAY\'S PANCHANG ---');
      final panchang = ctx['todayPanchang'] as Map<String, dynamic>;
      if (panchang['tithi'] != null) lines.add('   Tithi: ${panchang['tithi']}');
      if (panchang['nakshatra'] != null) lines.add('   Nakshatra: ${panchang['nakshatra']}');
      if (panchang['yoga'] != null) lines.add('   Yoga: ${panchang['yoga']}');
      if (panchang['karana'] != null) lines.add('   Karana: ${panchang['karana']}');
      if (panchang['vara'] != null) lines.add('   Vara (Day): ${panchang['vara']}');
    }

    // === DAILY INSIGHT CONTEXT ===
    if (ctx['dailyInsight'] != null) {
      lines.add('\n--- TODAY\'S PERSONALIZED INSIGHT ---');
      lines.add('Theme: ${ctx['insightTheme'] ?? 'General'}');
      lines.add('Message: ${ctx['dailyInsight']}');
    }

    // === COSMIC WEATHER ===
    if (ctx['cosmicWeather'] != null) {
      lines.add('\n--- COSMIC WEATHER ---');
      final weather = ctx['cosmicWeather'];
      if (weather is Map) {
        if (weather['summary'] != null) lines.add('Summary: ${weather['summary']}');
        if (weather['mood'] != null) lines.add('Cosmic Mood: ${weather['mood']}');
      } else if (weather is String) {
        lines.add(weather);
      }
    }

    return lines.join('\n');
  }

  /// Build chat history string
  String _buildChatHistory(List<Map<String, dynamic>>? history) {
    if (history == null || history.isEmpty) return '';

    // Only include last 10 messages for context (recent conversation)
    final recentHistory = history.length > 10 
        ? history.sublist(history.length - 10) 
        : history;

    return recentHistory.map((msg) {
      final role = msg['role'] == 'assistant' ? 'Assistant' : 'User';
      final content = msg['content'] ?? '';
      
      // For voice messages without transcription, note that context is in AI's response
      if (role == 'User' && (content == '🎤 Voice message' || content.trim().isEmpty)) {
        return 'User: [Voice message - see assistant\'s response for context]';
      }
      
      return '$role: $content';
    }).join('\n\n');
  }
}
