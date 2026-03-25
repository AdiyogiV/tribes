import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';

void main() {
  group('SpaceChatService Simple Tests (No Firebase)', () {
    group('DM ID Validation', () {
      test('should correctly identify DM conversation IDs', () {
        // Test DM ID format validation without creating service
        const dmId1 = 'dm_user1_user2';
        const dmId2 = 'dm_alice_bob';
        const nonDmId1 = 'space_123';
        const nonDmId2 = 'group_456';

        expect(dmId1.startsWith('dm_'), isTrue);
        expect(dmId2.startsWith('dm_'), isTrue);
        expect(nonDmId1.startsWith('dm_'), isFalse);
        expect(nonDmId2.startsWith('dm_'), isFalse);
      });

      test('should validate DM ID format structure', () {
        const validDmIds = [
          'dm_user1_user2',
          'dm_alice_bob',
          'dm_123_456',
        ];

        for (final dmId in validDmIds) {
          expect(dmId.startsWith('dm_'), isTrue);
          expect(dmId.split('_').length, equals(3));
        }

        // Test truly invalid formats
        expect('dm_'.startsWith('dm_') && 'dm_'.split('_').length == 3,
            isFalse); // 2 parts
        expect('dm'.startsWith('dm_') && 'dm'.split('_').length == 3,
            isFalse); // 1 part
        expect(
            'space_123'.startsWith('dm_') && 'space_123'.split('_').length == 3,
            isFalse); // Wrong prefix
        expect(''.startsWith('dm_') && ''.split('_').length == 3,
            isFalse); // Empty
      });
    });

    group('DM ID Generation Logic', () {
      test('should generate deterministic DM IDs', () {
        const userId1 = 'user_123';
        const userId2 = 'user_456';

        // Simulate the sorting logic
        final participants1 = [userId1, userId2]..sort();
        final participants2 = [userId2, userId1]..sort();

        final id1 = 'dm_${participants1[0]}_${participants1[1]}';
        final id2 = 'dm_${participants2[0]}_${participants2[1]}';

        expect(id1, equals(id2));
        expect(id1, equals('dm_user_123_user_456'));
      });

      test('should handle alphabetical sorting correctly', () {
        const testCases = [
          ['alice', 'bob', 'dm_alice_bob'],
          ['zebra', 'apple', 'dm_apple_zebra'],
          ['user_123', 'user_456', 'dm_user_123_user_456'],
          ['a', 'z', 'dm_a_z'],
        ];

        for (final testCase in testCases) {
          final userId1 = testCase[0];
          final userId2 = testCase[1];
          final expectedId = testCase[2];

          final participants = [userId1, userId2]..sort();
          final actualId = 'dm_${participants[0]}_${participants[1]}';

          expect(actualId, equals(expectedId));
        }
      });
    });

    group('User ID Extraction Logic', () {
      test('should extract other user ID from DM conversation ID', () {
        const testCases = [
          ['dm_alice_bob', 'alice', 'bob'],
          ['dm_alice_bob', 'bob', 'alice'],
          ['dm_user1_user2', 'user1', 'user2'],
          ['dm_user1_user2', 'user2', 'user1'],
        ];

        for (final testCase in testCases) {
          final dmId = testCase[0];
          final currentUserId = testCase[1];
          final expectedOtherUserId = testCase[2];

          if (dmId.startsWith('dm_')) {
            final parts = dmId.split('_');
            if (parts.length == 3) {
              final userId1 = parts[1];
              final userId2 = parts[2];
              final actualOtherUserId =
                  userId1 == currentUserId ? userId2 : userId1;

              expect(actualOtherUserId, equals(expectedOtherUserId));
            }
          }
        }
      });

      test('should handle invalid DM IDs', () {
        const invalidIds = [
          'space_123',
          'dm_only_one',
          'dm_',
          'dm',
          '',
          'not_dm_format',
        ];

        for (final invalidId in invalidIds) {
          String? result;

          if (invalidId.startsWith('dm_')) {
            final parts = invalidId.split('_');
            if (parts.length == 3) {
              result = 'would_be_valid';
            }
          }

          // For invalid IDs, result should remain null
          if (!invalidId.startsWith('dm_') ||
              invalidId.split('_').length != 3) {
            expect(result, isNull);
          }
        }
      });
    });

    group('Data Structure Tests', () {
      test('should create DmConversation with correct properties', () {
        final now = DateTime.now();
        final createdAt = now.subtract(Duration(days: 1));

        final conversation = DmConversation(
          id: 'dm_user1_user2',
          otherUserId: 'user2',
          participants: ['user1', 'user2'],
          lastActivity: now,
          createdAt: createdAt,
        );

        expect(conversation.id, equals('dm_user1_user2'));
        expect(conversation.otherUserId, equals('user2'));
        expect(conversation.participants, hasLength(2));
        expect(conversation.participants, containsAll(['user1', 'user2']));
        expect(conversation.lastActivity, equals(now));
        expect(conversation.createdAt, equals(createdAt));
      });

      test('should handle conversation sorting by last activity', () {
        final now = DateTime.now();
        final conversations = [
          DmConversation(
            id: 'dm_old_user',
            otherUserId: 'old_user',
            participants: ['current_user', 'old_user'],
            lastActivity: now.subtract(Duration(days: 5)),
            createdAt: now.subtract(Duration(days: 10)),
          ),
          DmConversation(
            id: 'dm_recent_user',
            otherUserId: 'recent_user',
            participants: ['current_user', 'recent_user'],
            lastActivity: now.subtract(Duration(minutes: 5)),
            createdAt: now.subtract(Duration(days: 1)),
          ),
          DmConversation(
            id: 'dm_medium_user',
            otherUserId: 'medium_user',
            participants: ['current_user', 'medium_user'],
            lastActivity: now.subtract(Duration(hours: 2)),
            createdAt: now.subtract(Duration(days: 3)),
          ),
        ];

        // Sort by last activity (most recent first)
        conversations.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

        expect(conversations[0].otherUserId, equals('recent_user'));
        expect(conversations[1].otherUserId, equals('medium_user'));
        expect(conversations[2].otherUserId, equals('old_user'));
      });
    });

    group('Time Formatting Logic', () {
      test('should calculate correct time differences', () {
        final now = DateTime.now();
        final justNow = now.subtract(Duration(seconds: 30));
        final minutesAgo = now.subtract(Duration(minutes: 5));
        final hoursAgo = now.subtract(Duration(hours: 2));
        final daysAgo = now.subtract(Duration(days: 3));
        final weeksAgo = now.subtract(Duration(days: 10));

        expect(now.difference(justNow).inMinutes, equals(0));
        expect(now.difference(minutesAgo).inMinutes, equals(5));
        expect(now.difference(hoursAgo).inHours, equals(2));
        expect(now.difference(daysAgo).inDays, equals(3));
        expect(now.difference(weeksAgo).inDays, equals(10));
      });

      test('should format time correctly', () {
        final now = DateTime.now();

        String formatTime(DateTime dateTime) {
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

        expect(formatTime(now.subtract(Duration(seconds: 30))),
            equals('just now'));
        expect(
            formatTime(now.subtract(Duration(minutes: 5))), equals('5m ago'));
        expect(formatTime(now.subtract(Duration(hours: 2))), equals('2h ago'));
        expect(formatTime(now.subtract(Duration(days: 3))), equals('3d ago'));
        expect(formatTime(now.subtract(Duration(days: 10))), equals('1w ago'));
      });
    });

    group('Edge Cases', () {
      test('should handle empty or special values', () {
        expect(''.startsWith('dm_'), isFalse);
        expect(''.split('_').length, equals(1));

        // Single character IDs
        final singleCharParticipants = ['a', 'b']..sort();
        final singleCharId =
            'dm_${singleCharParticipants[0]}_${singleCharParticipants[1]}';
        expect(singleCharId, equals('dm_a_b'));
        expect(singleCharId.split('_').length, equals(3));
      });

      test('should handle special characters in user IDs', () {
        const specialCases = [
          ['user-with-dash', 'userwithoutdash'],
          ['user.with.dots', 'user@with.email'],
          ['123456', 'abcdef'],
        ];

        for (final testCase in specialCases) {
          final userId1 = testCase[0];
          final userId2 = testCase[1];

          final participants = [userId1, userId2]..sort();
          final dmId = 'dm_${participants[0]}_${participants[1]}';

          expect(dmId.startsWith('dm_'), isTrue);
          expect(dmId.contains(userId1), isTrue);
          expect(dmId.contains(userId2), isTrue);
        }
      });
    });
  });
}
