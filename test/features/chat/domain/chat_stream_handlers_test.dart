import 'package:aurogram/features/chat/domain/chat_stream_handlers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countUnreadMessages', () {
    test('counts only unread messages from other users', () {
      final messages = [
        {'senderId': 'other', 'readBy': <String>[]},
        {'senderId': 'me', 'readBy': <String>[]},
        {
          'senderId': 'other',
          'readBy': ['me']
        },
        {'senderId': 'other', 'readBy': <String>[], 'deletedAt': 'deleted'},
      ];

      expect(countUnreadMessages(messages, 'me'), 1);
    });

    test('handles missing and malformed readBy values', () {
      final messages = [
        {'senderId': 'other'},
        {'senderId': 'other', 'readBy': 'not-a-list'},
      ];

      expect(countUnreadMessages(messages, 'me'), 2);
    });

    test('saturates at the badge limit', () {
      final messages = List.generate(
        150,
        (_) => <String, dynamic>{
          'senderId': 'other',
          'readBy': <String>[],
        },
      );

      expect(countUnreadMessages(messages, 'me'), unreadBadgeLimit);
    });
  });
}
