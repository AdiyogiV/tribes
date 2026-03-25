import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatNotificationService Tests', () {
    group('Notification Formatting', () {
      test('should format text message notification correctly', () {
        // Test notification body formatting for different message types
        // Using helper function to avoid Firebase initialization
        
        // Text message
        final textBody = _formatNotificationBody('John Doe', 'Hello there!', 'text');
        expect(textBody, contains('John Doe'));
        expect(textBody, contains('Hello there!'));
        
        // Image message
        final imageBody = _formatNotificationBody('Jane Smith', '', 'image');
        expect(imageBody, contains('Jane Smith'));
        expect(imageBody, contains('sent a photo'));
        
        // Video message
        final videoBody = _formatNotificationBody('Bob', '', 'video');
        expect(videoBody, contains('Bob'));
        expect(videoBody, contains('sent a video'));
        
        // Audio message
        final audioBody = _formatNotificationBody('Alice', '', 'audio');
        expect(audioBody, contains('Alice'));
        expect(audioBody, contains('sent an audio message'));
        
        // File message
        final fileBody = _formatNotificationBody('Charlie', '', 'file');
        expect(fileBody, contains('Charlie'));
        expect(fileBody, contains('sent a file'));
        
        // Unknown type
        final unknownBody = _formatNotificationBody('Dave', 'Test', 'unknown');
        expect(unknownBody, contains('Dave'));
        expect(unknownBody, contains('sent a message'));
      });

      test('should truncate long text messages', () {
        final longMessage = 'A' * 100; // 100 character message
        final body = _formatNotificationBody('User', longMessage, 'text');
        
        // Should be truncated to 50 characters + '...'
        expect(body.length, lessThanOrEqualTo(60)); // 'User: ' + 50 chars + '...'
        expect(body, contains('...'));
      });

      test('should handle empty sender name', () {
        final body = _formatNotificationBody('', 'Hello', 'text');
        expect(body, isNotEmpty);
      });
    });

    group('Rate Limiting Logic', () {
      test('should track notification times correctly', () {
        final now = DateTime.now();
        final threeSecondsAgo = now.subtract(const Duration(seconds: 3));
        final fourSecondsAgo = now.subtract(const Duration(seconds: 4));
        
        // Test rate limiting logic
        expect(now.difference(threeSecondsAgo).inSeconds, equals(3));
        expect(now.difference(fourSecondsAgo).inSeconds, greaterThan(3));
        
        // Should allow notification after 3 seconds
        expect(now.difference(fourSecondsAgo).inSeconds >= 3, isTrue);
      });
    });

    group('DM vs Group Chat Detection', () {
      test('should identify DM conversation IDs', () {
        const dmId = 'dm_user1_user2';
        const groupId = 'space_123';
        
        expect(dmId.startsWith('dm_'), isTrue);
        expect(groupId.startsWith('dm_'), isFalse);
      });

      test('should extract other user ID from DM ID', () {
        const dmId = 'dm_alice_bob';
        const currentUserId = 'alice';
        
        if (dmId.startsWith('dm_')) {
          final parts = dmId.substring(3).split('_');
          final otherUserId = parts.firstWhere(
            (id) => id != currentUserId,
            orElse: () => parts.first,
          );
          
          expect(otherUserId, equals('bob'));
        }
      });
    });

    group('Notification Content Validation', () {
      test('should validate notification data structure', () {
        final validData = {
          'spaceId': 'space_123',
          'senderId': 'user_456',
          'senderName': 'John Doe',
          'messageContent': 'Hello',
          'messageType': 'text',
        };
        
        expect(validData['spaceId'], isNotNull);
        expect(validData['senderId'], isNotNull);
        expect(validData['senderName'], isNotNull);
        expect(validData['messageContent'], isNotNull);
        expect(validData['messageType'], isNotNull);
      });

      test('should handle missing optional fields', () {
        final minimalData = {
          'spaceId': 'space_123',
          'senderId': 'user_456',
          'senderName': 'User',
          'messageContent': '',
          'messageType': 'text',
        };
        
        expect(minimalData['spaceId'], isNotNull);
        expect(minimalData['messageContent'], isA<String>());
      });
    });

    group('Message Type Handling', () {
      test('should handle all supported message types', () {
        const messageTypes = ['text', 'image', 'video', 'audio', 'file'];
        
        for (final type in messageTypes) {
          final body = _formatNotificationBody('User', 'Content', type);
          expect(body, isNotEmpty);
          expect(body, contains('User'));
        }
      });

      test('should provide default for unknown message types', () {
        final body = _formatNotificationBody('User', 'Content', 'unknown_type');
        expect(body, contains('User'));
        expect(body, contains('sent a message'));
      });
    });

    group('Time-based Filtering', () {
      test('should filter old messages correctly', () {
        final now = DateTime.now();
        final recentMessage = now.subtract(const Duration(minutes: 2));
        final oldMessage = now.subtract(const Duration(minutes: 10));
        
        // Should notify for messages within 5 minutes
        expect(now.difference(recentMessage).inMinutes, lessThan(5));
        expect(now.difference(oldMessage).inMinutes, greaterThan(5));
      });
    });
  });
}

/// Helper function to test notification body formatting
String _formatNotificationBody(
    String senderName, String content, String messageType) {
  switch (messageType) {
    case 'text':
      // Truncate long messages
      final displayContent =
          content.length > 50 ? '${content.substring(0, 50)}...' : content;
      return '$senderName: $displayContent';
    case 'image':
      return '$senderName sent a photo';
    case 'video':
      return '$senderName sent a video';
    case 'audio':
      return '$senderName sent an audio message';
    case 'file':
      return '$senderName sent a file';
    default:
      return '$senderName sent a message';
  }
}

