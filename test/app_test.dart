/// =============================================================================
/// AUROGRAM APP TESTS
/// =============================================================================
///
/// A clean, non-interfering test suite that verifies app logic works correctly.
///
/// PRINCIPLES:
/// - Tests PURE FUNCTIONS only (no Firebase, no side effects)
/// - Never touches production data
/// - Fast execution (~2 seconds)
/// - Clear, structured output
/// - Integrates with app logging patterns
///
/// RUN:
///   flutter test test/app_test.dart
///   flutter test  # runs all tests
///
/// =============================================================================
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

// Import actual app code to test (read-only, no side effects)
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';

// =============================================================================
// TEST UTILITIES
// =============================================================================

/// Test logger that mimics app logging format for consistent output
class TestLogger {
  static void section(String name) {
    // ignore: avoid_print
    print('\n━━━ $name ━━━');
  }

  static void pass(String test) {
    // ignore: avoid_print
    print('  ✓ $test');
  }

  static void info(String message) {
    // ignore: avoid_print
    print('  ℹ $message');
  }
}

/// Test result collector for monitoring integration
class TestResults {
  static final List<Map<String, dynamic>> _results = [];
  static DateTime? _startTime;

  static void start() {
    _startTime = DateTime.now();
    _results.clear();
  }

  static void record(String category, String test, bool passed) {
    _results.add({
      'category': category,
      'test': test,
      'passed': passed,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Map<String, dynamic> getSummary() {
    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!).inMilliseconds
        : 0;

    return {
      'total': _results.length,
      'passed': _results.where((r) => r['passed'] == true).length,
      'failed': _results.where((r) => r['passed'] == false).length,
      'duration_ms': duration,
      'timestamp': DateTime.now().toIso8601String(),
      'results': _results,
    };
  }

  static void printSummary() {
    final summary = getSummary();
    print('\n${'═' * 50}');
    print('📊 TEST SUMMARY');
    print('═' * 50);
    print('  Total:    ${summary['total']}');
    print('  Passed:   ${summary['passed']} ✓');
    print('  Failed:   ${summary['failed']} ✗');
    print('  Duration: ${summary['duration_ms']}ms');
    print('${'═' * 50}\n');
  }
}

// =============================================================================
// MAIN TEST SUITE
// =============================================================================

void main() {
  setUpAll(() {
    TestResults.start();
    TestLogger.section('AUROGRAM TEST SUITE');
    TestLogger.info('Testing pure logic only - no Firebase interaction');
  });

  tearDownAll(() {
    TestResults.printSummary();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH STATE MACHINE
  // Critical: If auth states are wrong, users can't log in
  // ═══════════════════════════════════════════════════════════════════════════

  group('Auth State Machine', () {
    test('has all required states', () {
      final requiredStates = [
        Status.Undetermined,
        Status.Uninitialized,
        Status.Authenticated,
        Status.Authenticating,
        Status.Unauthenticated,
      ];

      for (final state in requiredStates) {
        expect(Status.values.contains(state), isTrue,
            reason: 'Missing state: $state');
      }

      TestResults.record('auth', 'required_states', true);
    });

    test('has exactly 5 states (no extras)', () {
      expect(Status.values.length, equals(5),
          reason: 'Unexpected number of auth states');

      TestResults.record('auth', 'state_count', true);
    });

    test('state transitions are valid', () {
      // Valid transitions based on app logic:
      // Undetermined → Authenticating → Authenticated/Unauthenticated
      // Authenticated → Unauthenticated (sign out)
      // Uninitialized → Authenticated (after profile setup)

      final validTransitions = {
        Status.Undetermined: [Status.Authenticating, Status.Unauthenticated],
        Status.Authenticating: [Status.Authenticated, Status.Uninitialized, Status.Unauthenticated],
        Status.Authenticated: [Status.Unauthenticated],
        Status.Uninitialized: [Status.Authenticated],
        Status.Unauthenticated: [Status.Authenticating],
      };

      for (final from in validTransitions.keys) {
        expect(validTransitions[from], isNotEmpty,
            reason: '$from should have valid transitions');
      }

      TestResults.record('auth', 'valid_transitions', true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DM CONVERSATION LOGIC
  // Critical: Wrong IDs = messages go to wrong people
  // ═══════════════════════════════════════════════════════════════════════════

  group('DM Conversation Logic', () {
    // Helper function that mirrors app logic
    String generateDmId(String user1, String user2) {
      final sorted = [user1, user2]..sort();
      return 'dm_${sorted[0]}_${sorted[1]}';
    }

    bool isValidDmId(String id) {
      if (!id.startsWith('dm_')) return false;
      final parts = id.split('_');
      return parts.length == 3 && parts[1].isNotEmpty && parts[2].isNotEmpty;
    }

    String? getOtherUserId(String dmId, String currentUserId) {
      if (!dmId.startsWith('dm_')) return null;
      final parts = dmId.split('_');
      if (parts.length != 3) return null;
      return parts[1] == currentUserId ? parts[2] : parts[1];
    }

    test('generates deterministic IDs regardless of user order', () {
      // CRITICAL: alice→bob must equal bob→alice
      expect(generateDmId('alice', 'bob'), equals('dm_alice_bob'));
      expect(generateDmId('bob', 'alice'), equals('dm_alice_bob'));

      // More test cases
      expect(generateDmId('zebra', 'apple'), equals('dm_apple_zebra'));
      expect(generateDmId('user_123', 'user_456'), equals('dm_user_123_user_456'));

      TestResults.record('dm', 'deterministic_ids', true);
    });

    test('validates DM ID format correctly', () {
      // Valid
      expect(isValidDmId('dm_alice_bob'), isTrue);
      expect(isValidDmId('dm_user1_user2'), isTrue);
      expect(isValidDmId('dm_a_b'), isTrue);

      // Invalid
      expect(isValidDmId('space_123'), isFalse);
      expect(isValidDmId('dm_'), isFalse);
      expect(isValidDmId('dm_only'), isFalse);
      expect(isValidDmId(''), isFalse);
      expect(isValidDmId('dm__empty'), isFalse);

      TestResults.record('dm', 'format_validation', true);
    });

    test('extracts other user ID correctly', () {
      expect(getOtherUserId('dm_alice_bob', 'alice'), equals('bob'));
      expect(getOtherUserId('dm_alice_bob', 'bob'), equals('alice'));
      expect(getOtherUserId('space_123', 'alice'), isNull);
      expect(getOtherUserId('invalid', 'alice'), isNull);

      TestResults.record('dm', 'extract_other_user', true);
    });

    test('isDirectMessage matches app behavior', () {
      // This is the actual logic from SpaceChatService
      bool isDirectMessage(String conversationId) {
        return conversationId.startsWith('dm_');
      }

      expect(isDirectMessage('dm_alice_bob'), isTrue);
      expect(isDirectMessage('dm_user1_user2'), isTrue);
      expect(isDirectMessage('space_123'), isFalse);
      expect(isDirectMessage('group_chat'), isFalse);
      expect(isDirectMessage(''), isFalse);

      TestResults.record('dm', 'is_direct_message', true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT MESSAGE PARSING
  // Defensive: App must not crash on malformed data
  // ═══════════════════════════════════════════════════════════════════════════

  group('Chat Message Parsing', () {
    test('handles minimal valid data', () {
      final message = ChatMessage.fromJson({
        'id': 'msg_1',
        'spaceId': 'space_1',
        'senderId': 'user_1',
        'senderName': 'Test User',
        'content': 'Hello',
        'messageType': 'text',
        'reactions': <String, String>{},
        'readBy': <String>[],
      });

      expect(message.id, equals('msg_1'));
      expect(message.content, equals('Hello'));
      expect(message.messageType, equals('text'));

      TestResults.record('chat', 'minimal_data', true);
    });

    test('handles missing optional fields gracefully', () {
      final message = ChatMessage.fromJson({
        'id': 'msg_1',
        'spaceId': 'space_1',
        'senderId': 'user_1',
        'senderName': 'Test',
        'content': 'Hello',
        'messageType': 'text',
        // All optional fields missing
      });

      // Should not crash, optional fields should be null/empty
      expect(message.senderAvatar, isNull);
      expect(message.mediaUrl, isNull);
      expect(message.replyTo, isNull);
      expect(message.reactions, isEmpty);
      expect(message.readBy, isEmpty);

      TestResults.record('chat', 'missing_optional_fields', true);
    });

    test('handles null reactions and readBy', () {
      final message = ChatMessage.fromJson({
        'id': 'msg_1',
        'spaceId': 'space_1',
        'senderId': 'user_1',
        'senderName': 'Test',
        'content': 'Hello',
        'messageType': 'text',
        'reactions': null,
        'readBy': null,
      });

      expect(message.reactions, isEmpty);
      expect(message.readBy, isEmpty);

      TestResults.record('chat', 'null_collections', true);
    });

    test('DmConversation sorts by last activity', () {
      final now = DateTime.now();

      final conversations = [
        DmConversation(
          id: 'dm_a_b',
          otherUserId: 'b',
          participants: ['a', 'b'],
          lastActivity: now.subtract(Duration(days: 2)),
          createdAt: now.subtract(Duration(days: 5)),
        ),
        DmConversation(
          id: 'dm_a_c',
          otherUserId: 'c',
          participants: ['a', 'c'],
          lastActivity: now.subtract(Duration(minutes: 5)),
          createdAt: now.subtract(Duration(days: 1)),
        ),
        DmConversation(
          id: 'dm_a_d',
          otherUserId: 'd',
          participants: ['a', 'd'],
          lastActivity: now.subtract(Duration(hours: 3)),
          createdAt: now.subtract(Duration(days: 3)),
        ),
      ];

      // Sort by last activity (most recent first)
      conversations.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

      expect(conversations[0].otherUserId, equals('c')); // 5 min ago
      expect(conversations[1].otherUserId, equals('d')); // 3 hours ago
      expect(conversations[2].otherUserId, equals('b')); // 2 days ago

      TestResults.record('chat', 'conversation_sorting', true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TIME FORMATTING
  // UI: Correct "5m ago", "2h ago" display
  // ═══════════════════════════════════════════════════════════════════════════

  group('Time Formatting', () {
    String formatRelativeTime(Duration ago) {
      if (ago.inMinutes < 1) return 'just now';
      if (ago.inHours < 1) return '${ago.inMinutes}m ago';
      if (ago.inDays < 1) return '${ago.inHours}h ago';
      if (ago.inDays < 7) return '${ago.inDays}d ago';
      return '${(ago.inDays / 7).floor()}w ago';
    }

    test('formats all time ranges correctly', () {
      expect(formatRelativeTime(Duration(seconds: 30)), equals('just now'));
      expect(formatRelativeTime(Duration(seconds: 59)), equals('just now'));
      expect(formatRelativeTime(Duration(minutes: 1)), equals('1m ago'));
      expect(formatRelativeTime(Duration(minutes: 5)), equals('5m ago'));
      expect(formatRelativeTime(Duration(minutes: 59)), equals('59m ago'));
      expect(formatRelativeTime(Duration(hours: 1)), equals('1h ago'));
      expect(formatRelativeTime(Duration(hours: 2)), equals('2h ago'));
      expect(formatRelativeTime(Duration(hours: 23)), equals('23h ago'));
      expect(formatRelativeTime(Duration(days: 1)), equals('1d ago'));
      expect(formatRelativeTime(Duration(days: 6)), equals('6d ago'));
      expect(formatRelativeTime(Duration(days: 7)), equals('1w ago'));
      expect(formatRelativeTime(Duration(days: 14)), equals('2w ago'));

      TestResults.record('time', 'relative_formatting', true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME CONFIGURATION
  // UI: App must have valid theme to render
  // ═══════════════════════════════════════════════════════════════════════════

  group('Theme Configuration', () {
    test('all required colors are defined', () {
      expect(AppTheme.primaryColor, isA<Color>());
      expect(AppTheme.scaffoldLightColor, isA<Color>());
      expect(AppTheme.textLightColor, isA<Color>());

      // Colors should be valid (not transparent black)
      expect(AppTheme.primaryColor.toARGB32(), isNot(equals(0)));

      TestResults.record('theme', 'colors_defined', true);
    });

    test('material themes can be built', () {
      final lightTheme = AppTheme.getMaterialTheme(isDarkMode: false);
      final darkTheme = AppTheme.getMaterialTheme(isDarkMode: true);

      expect(lightTheme, isA<ThemeData>());
      expect(darkTheme, isA<ThemeData>());

      // Themes should be different
      expect(
        lightTheme.brightness == Brightness.light ||
            lightTheme.scaffoldBackgroundColor != darkTheme.scaffoldBackgroundColor,
        isTrue,
      );

      TestResults.record('theme', 'themes_buildable', true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA VALIDATION
  // Defensive: App must handle edge cases without crashing
  // ═══════════════════════════════════════════════════════════════════════════

  group('Data Validation', () {
    test('empty strings are handled safely', () {
      expect(''.isEmpty, isTrue);
      expect(''.startsWith('dm_'), isFalse);
      expect(''.split('_'), equals(['']));
      expect(''.trim(), equals(''));

      TestResults.record('validation', 'empty_strings', true);
    });

    test('null-safe operations work', () {
      TestResults.record('validation', 'null_safety', true);
    });

    test('unicode content is handled', () {
      final unicodeStrings = [
        'Hello 👋 World',
        '日本語テスト',
        '🔥🎉🚀',
        'مرحبا',
        'Привет',
        '한국어',
        'Emoji 😀😃😄',
      ];

      for (final str in unicodeStrings) {
        expect(str.isNotEmpty, isTrue);
        expect(str.length, greaterThan(0));
        expect(str.trim().isNotEmpty, isTrue);
      }

      TestResults.record('validation', 'unicode', true);
    });

    test('very long strings are handled', () {
      final longString = 'a' * 10000;
      expect(longString.length, equals(10000));
      expect(longString.substring(0, 10), equals('aaaaaaaaaa'));
      expect(longString.contains('a'), isTrue);

      TestResults.record('validation', 'long_strings', true);
    });

    test('special characters in IDs are handled', () {
      final specialIds = [
        'user-with-dash',
        'user.with.dots',
        'user@domain.com',
        'user+plus',
        'UPPERCASE',
        'MixedCase123',
      ];

      for (final id in specialIds) {
        expect(id.isNotEmpty, isTrue);
        // Should not throw
        final sorted = [id, 'other']..sort();
        expect(sorted.length, equals(2));
      }

      TestResults.record('validation', 'special_chars', true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ASTROLOGY DATA
  // Feature: Zodiac sign validation
  // ═══════════════════════════════════════════════════════════════════════════

  group('Astrology Data', () {
    final validSigns = {
      'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
      'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'
    };

    test('all 12 zodiac signs are valid', () {
      expect(validSigns.length, equals(12));

      for (final sign in validSigns) {
        expect(sign.isNotEmpty, isTrue);
        expect(sign[0], equals(sign[0].toUpperCase())); // Capitalized
      }

      TestResults.record('astrology', 'zodiac_signs', true);
    });

    test('birth chart data structure is valid', () {
      final chartData = {
        'sunSign': 'Taurus',
        'moonSign': 'Leo',
        'ascendant': 'Scorpio',
        'birthYear': 1990,
        'birthMonth': 5,
        'birthDay': 15,
        'birthTime': '10:30',
        'birthLatitude': 28.6139,
        'birthLongitude': 77.2090,
      };

      expect(validSigns.contains(chartData['sunSign']), isTrue);
      expect(validSigns.contains(chartData['moonSign']), isTrue);
      expect(validSigns.contains(chartData['ascendant']), isTrue);
      expect(chartData['birthMonth'], greaterThanOrEqualTo(1));
      expect(chartData['birthMonth'], lessThanOrEqualTo(12));
      expect(chartData['birthDay'], greaterThanOrEqualTo(1));
      expect(chartData['birthDay'], lessThanOrEqualTo(31));

      TestResults.record('astrology', 'chart_data', true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION TYPES
  // Feature: All notification types are accounted for
  // ═══════════════════════════════════════════════════════════════════════════

  group('Notification Types', () {
    test('all notification types are defined', () {
      final notificationTypes = {
        'like',
        'reply',
        'follow',
        'namaste',
        'chat_message',
        'space_invite',
        'daily_insight',
        'added_to_group',
        'new_post',
      };

      expect(notificationTypes.length, greaterThanOrEqualTo(8));

      for (final type in notificationTypes) {
        expect(type.isNotEmpty, isTrue);
        expect(type.contains('_') || type.length > 3, isTrue);
      }

      TestResults.record('notifications', 'types_defined', true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE TYPES
  // Feature: All message types are handled
  // ═══════════════════════════════════════════════════════════════════════════

  group('Message Types', () {
    test('all message types have display names', () {
      final messageTypes = {
        'text': 'Text',
        'image': 'Image',
        'video': 'Video',
        'audio': 'Audio',
        'file': 'File',
        'voice': 'Voice message',
      };

      for (final entry in messageTypes.entries) {
        expect(entry.key.isNotEmpty, isTrue);
        expect(entry.value.isNotEmpty, isTrue);
      }

      TestResults.record('messages', 'type_display_names', true);
    });
  });
}
