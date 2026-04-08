import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/config/api_endpoints.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:http/http.dart' as http;

class AiChatService {
  final FirebaseAuth _auth;
  final http.Client _client = http.Client();

  static const String _aiChatUrl = ApiEndpoints.aiChat;

  AiChatService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    return await user?.getIdToken();
  }

  Stream<Map<String, dynamic>> streamChat({
    required List<Map<String, dynamic>> messages,
    Map<String, dynamic>? context,
  }) async* {
    final token = await _getIdToken();
    final request = http.Request('POST', Uri.parse(_aiChatUrl));

    request.headers['Content-Type'] = 'application/json';
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final requestBody = <String, dynamic>{
      'messages': messages,
      if (context != null) ...context,
    };
    request.body = jsonEncode(requestBody);
    
    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(
        const Duration(seconds: 120), // Increased timeout for long responses
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );
    } catch (e) {
      AppLogger.e(
        'AiChatService network error',
        category: LogCategory.network,
        error: e,
      );
      rethrow;
    }

    if (response.statusCode != 200) {
      final errorText = await response.stream.bytesToString();
      throw HttpException(
        'Streaming request failed: ${response.statusCode} $errorText',
        uri: request.url,
      );
    }

    // Buffer for incomplete SSE lines
    String buffer = '';

    try {
      await for (final chunk in response.stream.transform(const Utf8Decoder())) {
        buffer += chunk;

        // Process complete lines
        final lines = buffer.split('\n');
        final hasCompleteEnding = buffer.endsWith('\n');
        final completeLines = hasCompleteEnding ? lines : lines.sublist(0, lines.length - 1);
        buffer = hasCompleteEnding ? '' : lines.last;

        for (final line in completeLines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;

          final payload = trimmed.substring(5).trim();
          if (payload.isEmpty) continue;

          try {
            final decoded = jsonDecode(payload) as Map<String, dynamic>;
            yield decoded;
          } catch (e) {
            if (e is! FormatException) rethrow;
            // Skip malformed JSON and continue
          }
        }
      }

      // Process remaining buffer
      if (buffer.trim().isNotEmpty) {
        final trimmed = buffer.trim();
        if (trimmed.startsWith('data:')) {
          final payload = trimmed.substring(5).trim();
          if (payload.isNotEmpty) {
            try {
              final decoded = jsonDecode(payload) as Map<String, dynamic>;
              yield decoded;
            } catch (_) {
              // Ignore final buffer parse errors
            }
          }
        }
      }
    } catch (e) {
      if (e is! FormatException) rethrow;

      // Try to recover from FormatException
      if (buffer.trim().isNotEmpty) {
        final trimmed = buffer.trim();
        if (trimmed.startsWith('data:')) {
          final payload = trimmed.substring(5).trim();
          if (payload.isNotEmpty) {
            try {
              final decoded = jsonDecode(payload) as Map<String, dynamic>;
              yield decoded;
              return;
            } catch (_) {
              AppLogger.w('AiChatService: failed to decode SSE fallback payload', category: LogCategory.general);
            }
          }
        }
      }
      rethrow;
    }
  }

  void dispose() => _client.close();
}
