import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Helper functions for testing
class TestHelpers {
  /// Creates a MaterialApp wrapper for widget testing
  static Widget createTestApp(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: AppTheme.primaryColor,
        scaffoldBackgroundColor: AppTheme.scaffoldLightColor,
      ),
      home: child,
    );
  }

  /// Creates test data for DM conversations
  static List<Map<String, dynamic>> createTestDmConversations() {
    final now = DateTime.now();
    return [
      {
        'id': 'dm_alice_test_user',
        'otherUserId': 'alice',
        'participants': ['alice', 'test_user'],
        'lastActivity': now.subtract(Duration(minutes: 5)),
        'createdAt': now.subtract(Duration(days: 1)),
      },
      {
        'id': 'dm_bob_test_user',
        'otherUserId': 'bob',
        'participants': ['bob', 'test_user'],
        'lastActivity': now.subtract(Duration(hours: 2)),
        'createdAt': now.subtract(Duration(days: 2)),
      },
      {
        'id': 'dm_charlie_test_user',
        'otherUserId': 'charlie',
        'participants': ['charlie', 'test_user'],
        'lastActivity': now.subtract(Duration(days: 1)),
        'createdAt': now.subtract(Duration(days: 3)),
      },
    ];
  }

  /// Creates test messages data
  static List<Map<String, dynamic>> createTestMessages(String conversationId) {
    final now = DateTime.now();
    return [
      {
        'id': 'msg1',
        'spaceId': conversationId,
        'senderId': 'test_user',
        'senderName': 'Test User',
        'content': 'Hello there!',
        'messageType': 'text',
        'timestamp': now.subtract(Duration(minutes: 10)),
        'reactions': {},
        'readBy': ['test_user'],
      },
      {
        'id': 'msg2',
        'spaceId': conversationId,
        'senderId': 'other_user',
        'senderName': 'Other User',
        'content': 'Hi! How are you?',
        'messageType': 'text',
        'timestamp': now.subtract(Duration(minutes: 5)),
        'reactions': {},
        'readBy': ['other_user', 'test_user'],
      },
      {
        'id': 'msg3',
        'spaceId': conversationId,
        'senderId': 'test_user',
        'senderName': 'Test User',
        'content': 'I am doing great, thanks!',
        'messageType': 'text',
        'timestamp': now.subtract(Duration(minutes: 2)),
        'reactions': {'other_user': '👍'},
        'readBy': ['test_user'],
      },
    ];
  }

  /// Helper to pump and settle with a specific duration
  static Future<void> pumpAndSettleWithDelay(WidgetTester tester,
      [Duration? duration]) async {
    await tester.pumpAndSettle(duration ?? const Duration(milliseconds: 100));
  }

  /// Helper to enter text and trigger changes
  static Future<void> enterTextAndSettle(
      WidgetTester tester, Finder finder, String text) async {
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// Helper to tap and settle
  static Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Verify that a specific number of widgets are found
  static void expectWidgetCount(Finder finder, int count) {
    expect(finder, findsNWidgets(count));
  }

  /// Verify that text appears in the widget tree
  static void expectTextExists(String text) {
    expect(find.text(text), findsOneWidget);
  }

  /// Verify that text does not appear in the widget tree
  static void expectTextNotExists(String text) {
    expect(find.text(text), findsNothing);
  }

  /// Verify that an icon appears in the widget tree
  static void expectIconExists(IconData icon) {
    expect(find.byIcon(icon), findsOneWidget);
  }

  /// Create a mock Firestore timestamp
  static DateTime mockTimestamp(
      {int? daysAgo, int? hoursAgo, int? minutesAgo}) {
    final now = DateTime.now();
    Duration offset = Duration.zero;

    if (daysAgo != null) offset += Duration(days: daysAgo);
    if (hoursAgo != null) offset += Duration(hours: hoursAgo);
    if (minutesAgo != null) offset += Duration(minutes: minutesAgo);

    return now.subtract(offset);
  }

  /// Format time for testing (matches the app's time formatting logic)
  static String formatTestTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    }
  }

  /// Generate a deterministic DM conversation ID
  static String generateDmId(String userId1, String userId2) {
    final participants = [userId1, userId2]..sort();
    return 'dm_${participants[0]}_${participants[1]}';
  }

  /// Validate DM conversation ID format
  static bool isValidDmId(String id) {
    return id.startsWith('dm_') && id.split('_').length == 3;
  }
}
