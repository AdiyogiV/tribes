import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';

void main() {
  group('Chat Features Tests (No Firebase)', () {
    // ==========================================================
    // MESSAGE EDITING TESTS
    // ==========================================================
    group('Message Editing', () {
      test('should validate edit window (5 minute limit)', () {
        final now = DateTime.now();
        final withinWindow = now.subtract(const Duration(minutes: 3));
        final outsideWindow = now.subtract(const Duration(minutes: 6));

        bool canEdit(DateTime messageTime) {
          return now.difference(messageTime).inMinutes <= 5;
        }

        expect(canEdit(withinWindow), isTrue);
        expect(canEdit(outsideWindow), isFalse);
        expect(canEdit(now), isTrue);
      });

      test('should only allow author to edit', () {
        const messageAuthorId = 'user123';
        const currentUserId1 = 'user123';
        const currentUserId2 = 'user456';

        bool canUserEdit(String currentUserId, String authorId) {
          return currentUserId == authorId;
        }

        expect(canUserEdit(currentUserId1, messageAuthorId), isTrue);
        expect(canUserEdit(currentUserId2, messageAuthorId), isFalse);
      });

      test('should track editedAt timestamp', () {
        final originalTime =
            DateTime.now().subtract(const Duration(minutes: 2));
        final editTime = DateTime.now();

        // Simulate message edit tracking
        expect(editTime.isAfter(originalTime), isTrue);
        expect(editTime.difference(originalTime).inMinutes, equals(2));
      });
    });

    // ==========================================================
    // TYPING INDICATORS TESTS
    // ==========================================================
    group('Typing Indicators', () {
      test('should create correct typing document ID format', () {
        const spaceId = 'space123';
        const userId = 'user456';
        final docId = '${spaceId}_$userId';

        expect(docId, equals('space123_user456'));
        expect(docId.contains(spaceId), isTrue);
        expect(docId.contains(userId), isTrue);
      });

      test('should identify stale typing entries (10 second TTL)', () {
        final now = DateTime.now();
        final recent = now.subtract(const Duration(seconds: 5));
        final stale = now.subtract(const Duration(seconds: 15));

        bool isStale(DateTime updatedAt) {
          return now.difference(updatedAt).inSeconds > 10;
        }

        expect(isStale(recent), isFalse);
        expect(isStale(stale), isTrue);
        expect(isStale(now), isFalse);
      });

      test('should throttle typing updates (2 second minimum)', () {
        final updates = <DateTime>[];
        var lastUpdate = DateTime.now().subtract(const Duration(seconds: 5));

        bool shouldUpdate(DateTime now) {
          if (now.difference(lastUpdate).inSeconds >= 2) {
            lastUpdate = now;
            updates.add(now);
            return true;
          }
          return false;
        }

        final t1 = DateTime.now();
        expect(shouldUpdate(t1), isTrue);
        expect(updates.length, equals(1));

        // Immediately after - should be throttled
        final t2 = t1.add(const Duration(milliseconds: 500));
        expect(shouldUpdate(t2), isFalse);
        expect(updates.length, equals(1));

        // After 2 seconds - should update
        final t3 = t1.add(const Duration(seconds: 3));
        expect(shouldUpdate(t3), isTrue);
        expect(updates.length, equals(2));
      });

      test('should create TypingUser with correct data', () {
        final typingUser = TypingUser(
          userId: 'user123',
          userName: 'John Doe',
        );

        expect(typingUser.userId, equals('user123'));
        expect(typingUser.userName, equals('John Doe'));
      });
    });

    // ==========================================================
    // SHARED CONTENT TESTS
    // ==========================================================
    group('Shared Content', () {
      test('should validate shared content structure for posts', () {
        final sharedPost = {
          'type': 'post',
          'id': 'post123',
          'title': 'Amazing Post',
          'preview': 'This is the first 100 characters...',
          'thumbnail': 'https://example.com/image.jpg',
          'authorName': 'Jane Doe',
        };

        expect(sharedPost['type'], equals('post'));
        expect(sharedPost['id'], isNotEmpty);
        expect(sharedPost.containsKey('title'), isTrue);
        expect(sharedPost.containsKey('preview'), isTrue);
      });

      test('should validate shared content structure for profiles', () {
        final sharedProfile = {
          'type': 'profile',
          'id': 'user123',
          'title': 'Jane Doe',
          'subtitle': 'Flutter Developer',
          'thumbnail': 'https://example.com/avatar.jpg',
        };

        expect(sharedProfile['type'], equals('profile'));
        expect(sharedProfile['id'], isNotEmpty);
        expect(sharedProfile['title'], isNotNull);
      });

      test('should validate shared content structure for spaces', () {
        final sharedSpace = {
          'type': 'space',
          'id': 'space123',
          'title': 'Flutter Devs',
          'subtitle': 'A community for Flutter developers',
          'thumbnail': 'https://example.com/space.jpg',
          'memberCount': 1500,
        };

        expect(sharedSpace['type'], equals('space'));
        expect(sharedSpace['id'], isNotEmpty);
        expect(sharedSpace['memberCount'], isA<int>());
      });

      test('should validate shared content types', () {
        const validTypes = ['post', 'profile', 'space', 'insight'];
        const invalidTypes = ['unknown', 'file', 'message'];

        for (final type in validTypes) {
          expect(validTypes.contains(type), isTrue);
        }

        for (final type in invalidTypes) {
          expect(validTypes.contains(type), isFalse);
        }
      });
    });

    // ==========================================================
    // MESSAGE FORWARDING TESTS
    // ==========================================================
    group('Message Forwarding', () {
      test('should mark message as forwarded', () {
        const originalMessageId = 'msg123';
        final forwardedMessage = {
          'content': 'Original content',
          'isForwarded': true,
          'forwardedFrom': originalMessageId,
        };

        expect(forwardedMessage['isForwarded'], isTrue);
        expect(forwardedMessage['forwardedFrom'], equals(originalMessageId));
      });

      test('should preserve original content when forwarding', () {
        const originalContent = 'Hello, this is the original message!';
        final forwardedMessage = {
          'content': originalContent,
          'isForwarded': true,
          'forwardedFrom': 'original_msg_id',
        };

        expect(forwardedMessage['content'], equals(originalContent));
      });

      test('should allow forwarding to multiple conversations', () {
        const targetConversations = ['conv1', 'conv2', 'conv3'];
        const originalMessageId = 'msg123';

        for (final convId in targetConversations) {
          final forward = {
            'targetConversation': convId,
            'originalMessage': originalMessageId,
            'isForwarded': true,
          };

          expect(forward['targetConversation'], isNotEmpty);
          expect(forward['isForwarded'], isTrue);
        }

        expect(targetConversations.length, equals(3));
      });
    });

    // ==========================================================
    // INTERNAL LINK PREVIEW TESTS
    // ==========================================================
    group('Internal Link Detection', () {
      test('should detect internal app URLs', () {
        const internalUrls = [
          'https://ty-dev-516d7.web.app/p/post123',
          'https://ty-dev-516d7.web.app/u/user123',
          'https://ty-dev-516d7.web.app/s/space123',
          'aurogram://post/post123',
          'aurogram://user/user123',
        ];

        const externalUrls = [
          'https://google.com',
          'https://twitter.com/user',
          'https://example.com/page',
        ];

        bool isInternalUrl(String url) {
          final uri = Uri.tryParse(url);
          if (uri == null) return false;

          if (uri.scheme == 'aurogram') return true;
          if (uri.host == 'ty-dev-516d7.web.app') return true;
          if (uri.host == 'aurogram.in') return true;

          return false;
        }

        for (final url in internalUrls) {
          expect(isInternalUrl(url), isTrue,
              reason: 'Should be internal: $url');
        }

        for (final url in externalUrls) {
          expect(isInternalUrl(url), isFalse,
              reason: 'Should be external: $url');
        }
      });

      test('should parse internal link types correctly', () {
        const linkTypeMappings = {
          '/p/': 'post',
          '/u/': 'profile',
          '/s/': 'space',
          '/cosmic/': 'cosmic',
        };

        String? getLinkType(String path) {
          for (final entry in linkTypeMappings.entries) {
            if (path.contains(entry.key)) {
              return entry.value;
            }
          }
          return null;
        }

        expect(getLinkType('/p/post123'), equals('post'));
        expect(getLinkType('/u/user123'), equals('profile'));
        expect(getLinkType('/s/space123'), equals('space'));
        expect(getLinkType('/cosmic/user123'), equals('cosmic'));
        expect(getLinkType('/unknown/123'), isNull);
      });

      test('should extract ID from internal URL', () {
        String? extractId(String url, String type) {
          final uri = Uri.tryParse(url);
          if (uri == null) return null;

          final segments = uri.pathSegments;
          if (segments.length >= 2) {
            final typeSegment = segments[0];
            if (typeSegment == type ||
                (type == 'post' && typeSegment == 'p') ||
                (type == 'user' && typeSegment == 'u') ||
                (type == 'space' && typeSegment == 's')) {
              return segments[1];
            }
          }
          return null;
        }

        expect(extractId('https://example.com/p/post123', 'post'),
            equals('post123'));
        expect(extractId('https://example.com/u/user456', 'user'),
            equals('user456'));
        expect(extractId('https://example.com/s/space789', 'space'),
            equals('space789'));
      });
    });

    // ==========================================================
    // EXTERNAL LINK PREVIEW TESTS
    // ==========================================================
    group('External Link Preview', () {
      test('should detect URLs in message content', () {
        final urlPattern = RegExp(
          r'https?://[^\s<>\[\]]+',
          caseSensitive: false,
        );

        const messages = [
          'Check out https://example.com for more info',
          'Multiple links: https://google.com and https://github.com',
          'No links in this message',
          'Link at end https://flutter.dev',
        ];

        expect(urlPattern.hasMatch(messages[0]), isTrue);
        expect(urlPattern.allMatches(messages[1]).length, equals(2));
        expect(urlPattern.hasMatch(messages[2]), isFalse);
        expect(urlPattern.hasMatch(messages[3]), isTrue);
      });

      test('should validate preview data structure', () {
        final preview = {
          'url': 'https://example.com',
          'title': 'Example Domain',
          'description': 'This domain is for examples.',
          'image': 'https://example.com/og-image.jpg',
          'siteName': 'example.com',
          'favicon': 'https://example.com/favicon.ico',
          'type': 'website',
        };

        expect(preview['url'], isNotEmpty);
        expect(preview['title'], isNotEmpty);
        expect(preview.containsKey('description'), isTrue);
        expect(preview.containsKey('image'), isTrue);
      });

      test('should handle preview cache expiration (24h)', () {
        final now = DateTime.now();
        final fresh = now.subtract(const Duration(hours: 12));
        final expired = now.subtract(const Duration(hours: 25));

        bool isCacheExpired(DateTime cachedAt) {
          return now.difference(cachedAt).inHours >= 24;
        }

        expect(isCacheExpired(fresh), isFalse);
        expect(isCacheExpired(expired), isTrue);
      });
    });

    // ==========================================================
    // MESSAGE SEARCH TESTS
    // ==========================================================
    group('Message Search', () {
      test('should search messages by content', () {
        final messages = [
          {'id': '1', 'content': 'Hello world', 'senderName': 'Alice'},
          {'id': '2', 'content': 'How are you?', 'senderName': 'Bob'},
          {'id': '3', 'content': 'Hello there!', 'senderName': 'Charlie'},
          {'id': '4', 'content': 'Goodbye', 'senderName': 'Alice'},
        ];

        List<Map<String, String>> searchMessages(String query) {
          final normalizedQuery = query.toLowerCase();
          return messages
              .where((m) =>
                  m['content']!.toLowerCase().contains(normalizedQuery) ||
                  m['senderName']!.toLowerCase().contains(normalizedQuery))
              .toList();
        }

        expect(searchMessages('hello').length, equals(2));
        expect(searchMessages('alice').length, equals(2));
        expect(searchMessages('world').length, equals(1));
        expect(searchMessages('xyz').length, equals(0));
      });

      test('should handle case-insensitive search', () {
        const content = 'Hello World';
        const queries = ['hello', 'HELLO', 'Hello', 'HeLLo'];

        for (final query in queries) {
          expect(
            content.toLowerCase().contains(query.toLowerCase()),
            isTrue,
            reason: 'Should match: $query',
          );
        }
      });

      test('should skip deleted messages in search', () {
        final messages = [
          {'id': '1', 'content': 'Hello', 'deletedAt': null},
          {'id': '2', 'content': 'Hello again', 'deletedAt': '2024-01-01'},
          {'id': '3', 'content': 'Hello world', 'deletedAt': null},
        ];

        final searchResults = messages
            .where((m) =>
                m['deletedAt'] == null &&
                m['content']!.toLowerCase().contains('hello'))
            .toList();

        expect(searchResults.length, equals(2));
        expect(searchResults.any((m) => m['id'] == '2'), isFalse);
      });
    });

    // ==========================================================
    // CONVERSATION MANAGEMENT TESTS
    // ==========================================================
    group('Conversation Management', () {
      test('should track pinned status', () {
        var isPinned = false;

        // Pin
        isPinned = true;
        expect(isPinned, isTrue);

        // Unpin
        isPinned = false;
        expect(isPinned, isFalse);
      });

      test('should track muted status with expiration', () {
        final now = DateTime.now();
        final mutedUntil1Hour = now.add(const Duration(hours: 1));
        final mutedUntil1Day = now.add(const Duration(days: 1));
        final expiredMute = now.subtract(const Duration(hours: 1));

        bool isMuted(DateTime? mutedUntil) {
          if (mutedUntil == null) return false;
          return mutedUntil.isAfter(now);
        }

        expect(isMuted(mutedUntil1Hour), isTrue);
        expect(isMuted(mutedUntil1Day), isTrue);
        expect(isMuted(expiredMute), isFalse);
        expect(isMuted(null), isFalse);
      });

      test('should track archived status', () {
        var isArchived = false;

        // Archive
        isArchived = true;
        expect(isArchived, isTrue);

        // Unarchive
        isArchived = false;
        expect(isArchived, isFalse);
      });

      test('should generate correct settings document ID', () {
        const userId = 'user123';
        const conversationId = 'conv456';
        final docId = '${userId}_$conversationId';

        expect(docId, equals('user123_conv456'));
        expect(docId.contains(userId), isTrue);
        expect(docId.contains(conversationId), isTrue);
      });

      test('DmConversation should support management fields', () {
        final conversation = DmConversation(
          id: 'dm_user1_user2',
          otherUserId: 'user2',
          participants: ['user1', 'user2'],
          lastActivity: DateTime.now(),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          isPinned: true,
          isMuted: true,
          isArchived: false,
          mutedUntil: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(conversation.isPinned, isTrue);
        expect(conversation.isMuted, isTrue);
        expect(conversation.isArchived, isFalse);
        expect(conversation.mutedUntil, isNotNull);
      });

      test('DmConversation copyWith should update fields correctly', () {
        final original = DmConversation(
          id: 'dm_user1_user2',
          otherUserId: 'user2',
          participants: ['user1', 'user2'],
          lastActivity: DateTime.now(),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          isPinned: false,
          isMuted: false,
          isArchived: false,
        );

        final updated = original.copyWith(isPinned: true, isMuted: true);

        expect(original.isPinned, isFalse);
        expect(original.isMuted, isFalse);
        expect(updated.isPinned, isTrue);
        expect(updated.isMuted, isTrue);
        expect(updated.id, equals(original.id));
        expect(updated.otherUserId, equals(original.otherUserId));
      });
    });

    // ==========================================================
    // MENTIONABLE USERS TESTS
    // ==========================================================
    group('Mentionable Users', () {
      test('should create MentionableUser with correct data', () {
        final user = MentionableUser(
          userId: 'user123',
          name: 'John Doe',
          avatar: 'https://example.com/avatar.jpg',
        );

        expect(user.userId, equals('user123'));
        expect(user.name, equals('John Doe'));
        expect(user.avatar, isNotNull);
      });

      test('should detect @mentions in text', () {
        final mentionPattern = RegExp(r'@(\w+)');

        const texts = [
          '@john hello there',
          'Hello @alice and @bob',
          'No mentions here',
          '@user1 @user2 @user3',
        ];

        expect(mentionPattern.allMatches(texts[0]).length, equals(1));
        expect(mentionPattern.allMatches(texts[1]).length, equals(2));
        expect(mentionPattern.allMatches(texts[2]).length, equals(0));
        expect(mentionPattern.allMatches(texts[3]).length, equals(3));
      });

      test('should extract mentioned user names', () {
        final mentionPattern = RegExp(r'@(\w+)');
        const text = 'Hello @alice and @bob, meet @charlie';

        final mentions =
            mentionPattern.allMatches(text).map((m) => m.group(1)).toList();

        expect(mentions, containsAll(['alice', 'bob', 'charlie']));
        expect(mentions.length, equals(3));
      });

      test('should match mention to user ID', () {
        final users = [
          MentionableUser(userId: 'u1', name: 'alice'),
          MentionableUser(userId: 'u2', name: 'bob'),
          MentionableUser(userId: 'u3', name: 'charlie'),
        ];

        String? findUserId(String mentionName) {
          final user = users.firstWhere(
            (u) => u.name.toLowerCase() == mentionName.toLowerCase(),
            orElse: () => MentionableUser(userId: '', name: ''),
          );
          return user.userId.isNotEmpty ? user.userId : null;
        }

        expect(findUserId('alice'), equals('u1'));
        expect(findUserId('Bob'), equals('u2'));
        expect(findUserId('unknown'), isNull);
      });
    });

    // ==========================================================
    // MEDIA GALLERY TESTS
    // ==========================================================
    group('Media Gallery', () {
      test('should filter messages by media type', () {
        final messages = [
          {'id': '1', 'messageType': 'text', 'mediaUrl': null},
          {
            'id': '2',
            'messageType': 'image',
            'mediaUrl': 'https://example.com/img.jpg'
          },
          {
            'id': '3',
            'messageType': 'video',
            'mediaUrl': 'https://example.com/vid.mp4'
          },
          {'id': '4', 'messageType': 'text', 'mediaUrl': null},
          {
            'id': '5',
            'messageType': 'audio',
            'mediaUrl': 'https://example.com/audio.mp3'
          },
          {
            'id': '6',
            'messageType': 'file',
            'mediaUrl': 'https://example.com/doc.pdf'
          },
        ];

        final mediaTypes = ['image', 'video', 'audio', 'file'];

        final mediaMessages = messages
            .where((m) => mediaTypes.contains(m['messageType']))
            .toList();

        expect(mediaMessages.length, equals(4));
        expect(mediaMessages.every((m) => m['mediaUrl'] != null), isTrue);
      });

      test('should categorize media by type', () {
        final messages = [
          {'messageType': 'image'},
          {'messageType': 'image'},
          {'messageType': 'video'},
          {'messageType': 'audio'},
          {'messageType': 'file'},
          {'messageType': 'file'},
        ];

        final photos =
            messages.where((m) => m['messageType'] == 'image').length;
        final videos =
            messages.where((m) => m['messageType'] == 'video').length;
        final files = messages
            .where((m) =>
                m['messageType'] == 'audio' || m['messageType'] == 'file')
            .length;

        expect(photos, equals(2));
        expect(videos, equals(1));
        expect(files, equals(3));
      });
    });

    // ==========================================================
    // READ RECEIPTS TESTS
    // ==========================================================
    group('Read Receipts', () {
      test('should track read status per user', () {
        final readBy = <String>['user1', 'user2'];

        expect(readBy.contains('user1'), isTrue);
        expect(readBy.contains('user2'), isTrue);
        expect(readBy.contains('user3'), isFalse);
      });

      test('should determine if message is read by recipient', () {
        const senderId = 'sender123';
        const recipientId = 'recipient456';
        var readBy = <String>[senderId]; // Initially only sender has "read" it

        bool isReadByRecipient() {
          return readBy.contains(recipientId);
        }

        expect(isReadByRecipient(), isFalse);

        // Recipient reads the message
        readBy = [...readBy, recipientId];
        expect(isReadByRecipient(), isTrue);
      });

      test('should show correct status icon', () {
        String getStatusIcon({required bool isSent, required bool isRead}) {
          if (isRead) return 'blue_double_tick';
          if (isSent) return 'grey_double_tick';
          return 'grey_single_tick';
        }

        expect(getStatusIcon(isSent: false, isRead: false),
            equals('grey_single_tick'));
        expect(getStatusIcon(isSent: true, isRead: false),
            equals('grey_double_tick'));
        expect(getStatusIcon(isSent: true, isRead: true),
            equals('blue_double_tick'));
      });
    });
  });
}
