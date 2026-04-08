import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Response chunk from Gemini containing text and optional grounding metadata
class GeminiChunk {
  final String text;
  final List<String>? searchQueries;
  final List<GeminiSource>? sources;
  final bool isComplete;

  GeminiChunk({
    required this.text,
    this.searchQueries,
    this.sources,
    this.isComplete = false,
  });
}

/// Search source from Google Search grounding
class GeminiSource {
  final String title;
  final String url;

  GeminiSource({required this.title, required this.url});
}

/// Unified Gemini service for both text and audio messages
/// Uses Firebase AI Logic SDK (Vertex AI backend) directly
/// No backend round-trip needed - Firebase handles auth/quotas
///
/// https://firebase.google.com/docs/ai-logic/get-started?platform=flutter
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;

  /// Initialize the Gemini model via Vertex AI with Google Search grounding
  Future<bool> initialize() async {
    if (_isInitialized && _model != null) return true;

    try {
      // Firebase AI Logic - uses Vertex AI backend
      // No API key needed - Firebase handles auth automatically!
      final ai = FirebaseAI.vertexAI(location: 'global');
      _model = ai.generativeModel(
        model:
            'gemini-2.0-flash', // Auto-updated alias with Google Search support
        generationConfig: GenerationConfig(
          temperature: 1.0, // Recommended for grounding
          maxOutputTokens: 2048,
        ),
        tools: [
          Tool.googleSearch(), // Free Google Search grounding
        ],
      );

      _isInitialized = true;
      AppLogger.i(
          '🤖 Gemini Service initialized via Vertex AI (with Google Search)',
          category: LogCategory.voice);
      return true;
    } catch (e) {
      AppLogger.e('Failed to initialize Gemini Service',
          category: LogCategory.voice, error: e);
      return false;
    }
  }

  /// Send a text message and stream the response
  Stream<GeminiChunk> sendTextMessage({
    required String text,
    required Map<String, dynamic> astrologyContext,
    List<Map<String, dynamic>>? chatHistory,
    String? userLocation,
    String? systemPrompt,
  }) async* {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        yield GeminiChunk(
          text: "I'm having trouble connecting. Please try again.",
          isComplete: true,
        );
        return;
      }
    }

    try {
      AppLogger.i('🚀 Sending text to Gemini via Vertex AI',
          category: LogCategory.voice,
          data: {
            'messageLength': text.length,
            'hasAstrology': astrologyContext.isNotEmpty,
            'chatHistoryCount': chatHistory?.length ?? 0,
          });

      final effectivePrompt = systemPrompt ??
          _buildSystemPrompt(astrologyContext, userLocation, isVoice: false);
      final historyText = _buildChatHistory(chatHistory);

      final prompt = [
        Content.multi([
          TextPart(effectivePrompt),
          if (historyText.isNotEmpty)
            TextPart('\n\n=== CONVERSATION HISTORY ===\n$historyText'),
          TextPart('\n\n=== USER\'S MESSAGE ===\n$text'),
        ]),
      ];

      yield* _streamResponse(prompt);
    } catch (e) {
      AppLogger.e('❌ Error processing text with Gemini',
          category: LogCategory.voice, error: e);
      yield GeminiChunk(
        text: "I had trouble processing your message. Please try again.",
        isComplete: true,
      );
    }
  }

  /// Send an audio message and stream the response
  Stream<GeminiChunk> sendAudioMessage({
    required String audioPath,
    required Map<String, dynamic> astrologyContext,
    List<Map<String, dynamic>>? chatHistory,
    String? userLocation,
    String? systemPrompt,
  }) async* {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        yield GeminiChunk(
          text: "I'm having trouble connecting. Please try again.",
          isComplete: true,
        );
        return;
      }
    }

    try {
      // Read audio file
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        yield GeminiChunk(
          text: "I couldn't find the audio file. Please try recording again.",
          isComplete: true,
        );
        return;
      }

      final Uint8List audioBytes = await audioFile.readAsBytes();

      // Detect mime type
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
            'audioSizeKB': (audioBytes.length / 1024).toStringAsFixed(1),
            'mimeType': mimeType,
            'hasAstrology': astrologyContext.isNotEmpty,
            'chatHistoryCount': chatHistory?.length ?? 0,
          });

      final effectivePrompt = systemPrompt ??
          _buildSystemPrompt(astrologyContext, userLocation, isVoice: true);
      final historyText = _buildChatHistory(chatHistory);

      final prompt = [
        Content.multi([
          TextPart(effectivePrompt),
          if (historyText.isNotEmpty)
            TextPart('\n\n=== CONVERSATION HISTORY ===\n$historyText'),
          TextPart(
              '\n\n=== USER\'S VOICE MESSAGE ===\nListen to and respond to this voice message:'),
          InlineDataPart(mimeType, audioBytes),
        ]),
      ];

      yield* _streamResponse(prompt);
    } catch (e) {
      AppLogger.e('❌ Error processing audio with Gemini',
          category: LogCategory.voice, error: e);
      yield GeminiChunk(
        text:
            "I had trouble understanding your voice message. Please try again.",
        isComplete: true,
      );
    }
  }

  /// Stream response from Gemini and yield chunks
  Stream<GeminiChunk> _streamResponse(List<Content> prompt) async* {
    final response = _model!.generateContentStream(prompt);

    int chunkCount = 0;
    int totalLength = 0;
    List<String>? searchQueries;
    List<GeminiSource>? sources;
    bool searchLogged = false;

    await for (final chunk in response) {
      // Check for grounding metadata (Google Search results)
      if (!searchLogged) {
        final candidates = chunk.candidates;
        if (candidates.isNotEmpty) {
          try {
            final metadata = candidates.first.groundingMetadata;
            if (metadata != null) {
              searchLogged = true;

              // Extract search queries
              final queries = metadata.webSearchQueries;
              if (queries.isNotEmpty) {
                searchQueries = queries.toList();
                AppLogger.i('🔍 Google Search grounding used',
                    category: LogCategory.voice,
                    data: {'searchQueries': queries});
              }

              // Extract sources
              final groundingChunks = metadata.groundingChunks;
              if (groundingChunks.isNotEmpty) {
                sources = groundingChunks
                    .where((c) => c.web != null)
                    .map((c) => GeminiSource(
                          title: c.web?.title ?? 'Unknown',
                          url: c.web?.uri ?? '',
                        ))
                    .toList();
              }
            }
          } catch (e) {
            // Grounding metadata might not exist
          }
        }
      }

      final text = chunk.text;
      if (text != null && text.isNotEmpty) {
        chunkCount++;
        totalLength += text.length;
        yield GeminiChunk(
          text: text,
          searchQueries: searchQueries,
          sources: sources,
        );
      }
    }

    AppLogger.i('✅ Gemini response complete',
        category: LogCategory.voice,
        data: {
          'chunks': chunkCount,
          'totalLength': totalLength,
          'searchUsed': searchQueries != null,
        });

    // Yield a final "complete" marker
    yield GeminiChunk(text: '', isComplete: true);
  }

  /// Build system prompt (unified for text and voice). Fallback when [systemPrompt] from backend (getChatPromptConfig) is null.
  String _buildSystemPrompt(
      Map<String, dynamic> astrologyContext, String? userLocation,
      {bool isVoice = false}) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final hasAstrology = astrologyContext.isNotEmpty &&
        (astrologyContext['ascendant'] != null ||
            astrologyContext['moonSign'] != null);

    if (hasAstrology) {
      final voiceContext = isVoice
          ? '''

VOICE CONTEXT:
• User is speaking - respond conversationally
• Keep response focused (50-120 words ideal)
• Acknowledge what you understood briefly'''
          : '';

      return '''You are HolyCow, a brilliant Vedic astrologer with personality.
Today is $dateStr.
${userLocation != null ? 'User location: $userLocation.' : ''}
$voiceContext

YOUR STYLE:
• Be a confident mentor - make bold calls, don't hedge
• Answer the question first, then explain briefly
• Be specific: give months, dates, timeframes
• Make it personal: 'your Saturn', 'your Jupiter period'
• Keep responses 50-120 words, rarely exceed 150
• Use **bold** for key emphasis

NEVER DO:
• Never say 'Would you like me to analyze further?'
• Never list 'several possibilities' - pick one
• Never sound like a generic horoscope
• No emojis

${_buildAstrologyContextString(astrologyContext)}''';
    } else {
      return '''You are a helpful, friendly assistant for the Tribes app.
Today: $dateStr.
${userLocation != null ? 'User location: $userLocation.' : ''}
${isVoice ? 'User is speaking via voice.' : ''}

STYLE:
• Be direct and helpful
• Use Google Search for current info
• Be conversational, not robotic
• Keep responses concise''';
    }
  }

  /// Build complete astrology context string
  String _buildAstrologyContextString(Map<String, dynamic> ctx) {
    if (ctx.isEmpty) return '';

    final lines = <String>['\n=== USER\'S VEDIC ASTROLOGY PROFILE ==='];
    lines.add('(Use for analysis - only mention what supports your answer)');

    // Core chart data
    if (ctx['ascendant'] != null) lines.add('☉ Ascendant: ${ctx['ascendant']}');
    if (ctx['moonSign'] != null) lines.add('☽ Moon Sign: ${ctx['moonSign']}');
    if (ctx['sunSign'] != null) lines.add('☀ Sun Sign: ${ctx['sunSign']}');
    if (ctx['nakshatra'] != null) lines.add('✧ Nakshatra: ${ctx['nakshatra']}');

    // Dasha
    if (ctx['currentDasha'] != null) {
      final dasha = ctx['currentDasha'];
      if (dasha is Map<String, dynamic>) {
        final parts = <String>[];
        if (dasha['mahadasha'] != null || dasha['maha_dasha'] != null) {
          parts.add('Maha: ${dasha['mahadasha'] ?? dasha['maha_dasha']}');
        }
        if (dasha['antardasha'] != null || dasha['antar_dasha'] != null) {
          parts.add('Antar: ${dasha['antardasha'] ?? dasha['antar_dasha']}');
        }
        if (parts.isNotEmpty) lines.add('⟳ Dasha: ${parts.join(', ')}');
      }
    }

    // Planets
    if (ctx['planets'] != null && ctx['planets'] is List) {
      lines.add('\n📍 PLANETS:');
      for (final p in ctx['planets']) {
        if (p is Map) {
          final name = p['name'] ?? p['planet'];
          final sign = p['sign'] ?? p['rashi'];
          if (name != null && sign != null) {
            var info = '   $name: $sign';
            if (p['house'] != null) info += ' (H${p['house']})';
            if (p['retrograde'] == true) info += ' [R]';
            lines.add(info);
          }
        }
      }
    }

    // Transits
    if (ctx['todayTransits'] != null && ctx['todayTransits'] is Map) {
      lines.add('\n🔄 TRANSITS:');
      final transits = ctx['todayTransits'] as Map<String, dynamic>;
      for (final entry in transits.entries) {
        final planet = entry.key;
        final data = entry.value;
        if (!['Uranus', 'Neptune', 'Pluto', 'Ascendant'].contains(planet) &&
            data is Map) {
          var info = '   $planet: ${data['sign'] ?? '?'}';
          if (data['house'] != null) info += ' (H${data['house']})';
          lines.add(info);
        }
      }
    }

    // Yogas
    if (ctx['rajYogas'] != null &&
        ctx['rajYogas'] is List &&
        (ctx['rajYogas'] as List).isNotEmpty) {
      final yogaNames = (ctx['rajYogas'] as List)
          .map((y) =>
              y is String ? y : (y is Map ? y['name'] ?? y['yoga'] : null))
          .where((n) => n != null)
          .take(5)
          .join(', ');
      if (yogaNames.isNotEmpty) lines.add('\n✦ Yogas: $yogaNames');
    }

    // Doshas
    if (ctx['doshas'] != null && ctx['doshas'] is Map) {
      final doshas = ctx['doshas'] as Map;
      final doshaList = <String>[];
      if (doshas['mangalDosha']?['present'] == true ||
          doshas['mangal_dosha'] == true) {
        doshaList.add('Mangal');
      }
      if (doshas['kaalSarpDosha']?['present'] == true ||
          doshas['kaal_sarp_dosha'] == true) {
        doshaList.add('Kaal Sarp');
      }
      if (doshaList.isNotEmpty) lines.add('⚠️ Doshas: ${doshaList.join(', ')}');
    }

    return lines.join('\n');
  }

  /// Build chat history string
  String _buildChatHistory(List<Map<String, dynamic>>? history) {
    if (history == null || history.isEmpty) return '';

    final recentHistory =
        history.length > 10 ? history.sublist(history.length - 10) : history;

    return recentHistory.map((msg) {
      final role = msg['role'] == 'assistant' ? 'Assistant' : 'User';
      final content = msg['content'] ?? '';

      if (role == 'User' &&
          (content == '🎤 Voice message' || content.trim().isEmpty)) {
        return 'User: [Voice message - see assistant\'s response for context]';
      }

      return '$role: $content';
    }).join('\n\n');
  }
}
