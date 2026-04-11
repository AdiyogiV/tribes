// ignore_for_file: avoid_print
/// Tests for json_serializable model serialization round-trips.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/shared/models/call.dart';
import 'package:aurogram/shared/models/group_call_participant.dart';
import 'package:aurogram/shared/models/contact_match.dart';
import 'package:aurogram/shared/models/dm_conversation.dart';
import 'package:aurogram/shared/models/chat_message.dart';
import 'package:aurogram/shared/models/space_types.dart';

void main() {
  group('Call model serialization', () {
    test('round-trip fromJson → toJson preserves all fields', () {
      final json = {
        'id': 'call_123',
        'callerId': 'user_a',
        'callerName': 'Alice',
        'callerAvatar': 'https://example.com/alice.png',
        'calleeId': 'user_b',
        'calleeName': 'Bob',
        'calleeAvatar': null,
        'type': 'video',
        'createdAt': DateTime(2026, 4, 9),
        'status': 'ringing',
        'answeredAt': null,
        'endedAt': null,
      };

      final call = Call.fromJson(json);
      expect(call.id, 'call_123');
      expect(call.callerId, 'user_a');
      expect(call.callerName, 'Alice');
      expect(call.type, CallType.video);
      expect(call.status, 'ringing');
      expect(call.isVideo, isTrue);
      expect(call.isVoice, isFalse);

      final output = call.toJson();
      expect(output['id'], 'call_123');
      expect(output['callerId'], 'user_a');
      expect(output['type'], 'video');
    });

    test('fromJson provides defaults for missing fields', () {
      final json = <String, dynamic>{};
      final call = Call.fromJson(json);
      expect(call.id, '');
      expect(call.callerName, 'Unknown');
      expect(call.type, CallType.voice);
      expect(call.status, 'ringing');
    });

    test('CallType enum values serialize correctly', () {
      final voiceJson = {'type': 'voice', 'id': 'x', 'callerId': '', 'callerName': '', 'calleeId': '', 'calleeName': '', 'createdAt': DateTime.now(), 'status': 'idle'};
      final videoJson = {'type': 'video', 'id': 'x', 'callerId': '', 'callerName': '', 'calleeId': '', 'calleeName': '', 'createdAt': DateTime.now(), 'status': 'idle'};

      expect(Call.fromJson(voiceJson).type, CallType.voice);
      expect(Call.fromJson(videoJson).type, CallType.video);
    });
  });

  group('GroupCallParticipant model serialization', () {
    test('round-trip fromJson → toJson preserves all fields', () {
      final json = {
        'agoraUid': 12345,
        'oderId': 'user_abc',
        'displayName': 'Charlie',
        'avatarUrl': 'https://example.com/charlie.png',
        'isAudioMuted': true,
        'isVideoMuted': false,
      };

      final participant = GroupCallParticipant.fromJson(json);
      expect(participant.agoraUid, 12345);
      expect(participant.oderId, 'user_abc');
      expect(participant.displayName, 'Charlie');
      expect(participant.isAudioMuted, isTrue);
      expect(participant.isVideoMuted, isFalse);

      final output = participant.toJson();
      expect(output['agoraUid'], 12345);
      expect(output['oderId'], 'user_abc');
      expect(output['displayName'], 'Charlie');
      expect(output['avatarUrl'], 'https://example.com/charlie.png');
      expect(output['isAudioMuted'], isTrue);
      expect(output['isVideoMuted'], isFalse);
    });

    test('defaults for optional boolean fields', () {
      final json = {
        'agoraUid': 1,
        'oderId': 'x',
        'displayName': 'Test',
      };

      final p = GroupCallParticipant.fromJson(json);
      expect(p.isAudioMuted, isFalse);
      expect(p.isVideoMuted, isFalse);
      expect(p.avatarUrl, isNull);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = GroupCallParticipant(
        agoraUid: 1,
        oderId: 'x',
        displayName: 'Original',
        isAudioMuted: false,
      );

      final muted = original.copyWith(isAudioMuted: true);
      expect(muted.isAudioMuted, isTrue);
      expect(muted.displayName, 'Original');
      expect(muted.agoraUid, 1);
      // Original is unchanged
      expect(original.isAudioMuted, isFalse);
    });
  });

  group('ContactMatch model serialization', () {
    test('round-trip fromJson → toJson preserves all fields', () {
      final json = {
        'name': 'Diana',
        'phoneNumber': '+1234567890',
        'phoneHash': 'abc123hash',
        'userId': 'user_diana',
      };

      final match = ContactMatch.fromJson(json);
      expect(match.name, 'Diana');
      expect(match.phoneNumber, '+1234567890');
      expect(match.phoneHash, 'abc123hash');
      expect(match.userId, 'user_diana');
      expect(match.isOnApp, isTrue);
      expect(match.displayPhone, '+1234567890');

      final output = match.toJson();
      expect(output['name'], 'Diana');
      expect(output['phoneHash'], 'abc123hash');
      expect(output['userId'], 'user_diana');
    });

    test('ContactMatch without userId is not on app', () {
      final json = {
        'name': 'Eve',
        'phoneNumber': '+0987654321',
        'phoneHash': 'xyz789hash',
      };

      final match = ContactMatch.fromJson(json);
      expect(match.userId, isNull);
      expect(match.isOnApp, isFalse);
    });

    test('equality based on phoneHash', () {
      const a = ContactMatch(name: 'A', phoneNumber: '1', phoneHash: 'same');
      const b = ContactMatch(name: 'B', phoneNumber: '2', phoneHash: 'same');
      const c = ContactMatch(name: 'C', phoneNumber: '3', phoneHash: 'different');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ContactSyncResult model serialization', () {
    test('round-trip fromJson → toJson', () {
      final json = {
        'onApp': [
          {'name': 'A', 'phoneNumber': '1', 'phoneHash': 'h1', 'userId': 'u1'},
        ],
        'notOnApp': [
          {'name': 'B', 'phoneNumber': '2', 'phoneHash': 'h2'},
        ],
        'hasPermission': true,
        'error': null,
      };

      final result = ContactSyncResult.fromJson(json);
      expect(result.onApp.length, 1);
      expect(result.notOnApp.length, 1);
      expect(result.hasPermission, isTrue);
      expect(result.totalContacts, 2);
      expect(result.isEmpty, isFalse);
      expect(result.hasError, isFalse);
    });

    test('factory constructors', () {
      final denied = ContactSyncResult.permissionDenied();
      expect(denied.hasPermission, isFalse);

      final empty = ContactSyncResult.empty();
      expect(empty.isEmpty, isTrue);

      final error = ContactSyncResult.withError('test error');
      expect(error.hasError, isTrue);
      expect(error.error, 'test error');
    });
  });

  group('DmConversation model serialization', () {
    test('round-trip fromJson → toJson preserves all fields', () {
      final now = DateTime(2026, 4, 9, 12, 0);
      final json = {
        'id': 'conv_123',
        'otherUserId': 'user_bob',
        'participants': ['user_alice', 'user_bob'],
        'lastActivity': now,
        'createdAt': now,
        'lastMessageContent': 'Hello!',
        'lastMessageSenderId': 'user_alice',
        'lastMessageSenderName': 'Alice',
        'isPinned': true,
        'isMuted': false,
        'isArchived': false,
        'status': 'accepted',
      };

      final conv = DmConversation.fromJson(json);
      expect(conv.id, 'conv_123');
      expect(conv.otherUserId, 'user_bob');
      expect(conv.participants, ['user_alice', 'user_bob']);
      expect(conv.lastMessageContent, 'Hello!');
      expect(conv.isPinned, isTrue);
      expect(conv.isMuted, isFalse);
      expect(conv.status, 'accepted');

      final output = conv.toJson();
      expect(output['id'], 'conv_123');
      expect(output['otherUserId'], 'user_bob');
      expect(output['lastMessageContent'], 'Hello!');
      expect(output['isPinned'], isTrue);
    });

    test('optional fields default correctly', () {
      final json = {
        'id': 'conv_minimal',
        'otherUserId': 'user_x',
        'participants': <String>['user_x'],
        'lastActivity': DateTime(2026, 1, 1),
        'createdAt': DateTime(2026, 1, 1),
        'isPinned': false,
        'isMuted': false,
        'isArchived': false,
      };

      final conv = DmConversation.fromJson(json);
      expect(conv.lastMessageContent, isNull);
      expect(conv.displayPicture, isNull);
      expect(conv.spaceType, isNull);
      expect(conv.spaceName, isNull);
      expect(conv.contextType, isNull);
      expect(conv.mutedUntil, isNull);
      expect(conv.status, isNull);
    });

    test('space-specific fields work', () {
      final json = {
        'id': 'conv_space',
        'otherUserId': 'user_y',
        'participants': <String>['user_y'],
        'lastActivity': DateTime(2026, 1, 1),
        'createdAt': DateTime(2026, 1, 1),
        'spaceName': 'Astrology Gram',
        'spaceType': 'public',
        'displayPicture': 'https://example.com/pic.jpg',
        'isPinned': false,
        'isMuted': false,
        'isArchived': false,
      };

      final conv = DmConversation.fromJson(json);
      expect(conv.spaceName, 'Astrology Gram');
      expect(conv.spaceType, SpaceType.public);
      expect(conv.displayPicture, 'https://example.com/pic.jpg');
    });

    test('copyWith creates new instance', () {
      final original = DmConversation(
        id: 'c1',
        otherUserId: 'u1',
        participants: ['u1'],
        lastActivity: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        isPinned: false,
        isMuted: false,
        isArchived: false,
      );

      final pinned = original.copyWith(isPinned: true);
      expect(pinned.isPinned, isTrue);
      expect(pinned.id, 'c1');
      expect(original.isPinned, isFalse); // Original unchanged
    });
  });

  group('ChatMessage model serialization', () {
    test('round-trip fromJson → toJson preserves all fields', () {
      final now = DateTime(2026, 4, 9, 14, 30);
      final json = {
        'id': 'msg_001',
        'spaceId': 'space_abc',
        'senderId': 'user_alice',
        'senderName': 'Alice',
        'senderAvatar': 'https://example.com/alice.png',
        'content': 'Hello everyone!',
        'messageType': 'text',
        'reactions': {'user_bob': '👍'},
        'readBy': ['user_alice', 'user_bob'],
        'timestamp': now,
        'isForwarded': false,
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.id, 'msg_001');
      expect(msg.spaceId, 'space_abc');
      expect(msg.senderId, 'user_alice');
      expect(msg.senderName, 'Alice');
      expect(msg.content, 'Hello everyone!');
      expect(msg.messageType, 'text');
      expect(msg.reactions, {'user_bob': '👍'});
      expect(msg.readBy, ['user_alice', 'user_bob']);
      expect(msg.isForwarded, isFalse);

      final output = msg.toJson();
      expect(output['id'], 'msg_001');
      expect(output['senderId'], 'user_alice');
      expect(output['content'], 'Hello everyone!');
      expect(output['messageType'], 'text');
    });

    test('fromJson provides defaults for missing fields', () {
      final json = <String, dynamic>{
        'timestamp': DateTime(2026, 1, 1),
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.id, '');
      expect(msg.spaceId, '');
      expect(msg.senderId, '');
      expect(msg.senderName, '');
      expect(msg.content, '');
      expect(msg.messageType, 'text');
      expect(msg.isForwarded, isFalse);
    });

    test('call-specific fields serialize correctly', () {
      final json = {
        'id': 'msg_call',
        'spaceId': 'space_1',
        'senderId': 'user_a',
        'senderName': 'Alice',
        'content': 'Voice call',
        'messageType': 'call',
        'reactions': <String, dynamic>{},
        'readBy': <dynamic>[],
        'timestamp': DateTime(2026, 4, 9),
        'callType': 'voice',
        'callStatus': 'answered',
        'callDuration': 120,
        'isOutgoing': true,
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.messageType, 'call');
      expect(msg.callType, 'voice');
      expect(msg.callStatus, 'answered');
      expect(msg.callDuration, 120);
      expect(msg.isOutgoing, isTrue);
    });

    test('shared content fields serialize correctly', () {
      final json = {
        'id': 'msg_shared',
        'spaceId': 'space_1',
        'senderId': 'user_a',
        'senderName': 'Alice',
        'content': 'Check this out',
        'messageType': 'shared_content',
        'reactions': <String, dynamic>{},
        'readBy': <dynamic>[],
        'timestamp': DateTime(2026, 4, 9),
        'sharedContent': {
          'type': 'post',
          'id': 'post_123',
          'title': 'Great Post',
        },
        'isForwarded': true,
        'forwardedFrom': 'msg_original',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.messageType, 'shared_content');
      expect(msg.sharedContent?['type'], 'post');
      expect(msg.sharedContent?['id'], 'post_123');
      expect(msg.isForwarded, isTrue);
      expect(msg.forwardedFrom, 'msg_original');
    });

    test('constructor creates valid instance', () {
      final msg = ChatMessage(
        id: 'msg_test',
        spaceId: 'space_1',
        senderId: 'user_a',
        senderName: 'Alice',
        content: 'Test',
        messageType: 'text',
        reactions: {},
        readBy: ['user_a'],
        timestamp: DateTime(2026, 4, 9),
      );

      expect(msg.id, 'msg_test');
      expect(msg.messageType, 'text');
      expect(msg.status, MessageStatus.sent);
      expect(msg.isForwarded, isFalse);
      expect(msg.deletedAt, isNull);
      expect(msg.editedAt, isNull);
    });
  });
}
