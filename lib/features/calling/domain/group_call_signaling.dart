import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/models/group_call_participant.dart';

/// Manages Firestore call signaling: presence, heartbeat, participant tracking,
/// and call history persistence.
class GroupCallSignalingManager {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  GroupCallSignalingManager({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // Participants — maps Agora UID to participant info
  final Map<int, GroupCallParticipant> participants = {};
  final _participantsController =
      StreamController<List<GroupCallParticipant>>.broadcast();

  Stream<List<GroupCallParticipant>> get participantsStream =>
      _participantsController.stream;
  List<GroupCallParticipant> get participantsList => participants.values.toList();

  String? get currentUserId => _auth.currentUser?.uid;

  // Heartbeat timer
  Timer? _heartbeatTimer;

  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _staleThreshold = Duration(seconds: 90);

  // --------------------------------------------------------------------------
  // Static cleanup
  // --------------------------------------------------------------------------

  /// Clean up stale call participants for a specific space.
  /// Returns true if cleanup was performed.
  static Future<bool> cleanupStaleCallParticipants(String spaceId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final callRef = firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active');

      final doc = await callRef.get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final participants = data['participants'] as List<dynamic>? ?? [];
      if (participants.isEmpty) {
        await callRef.delete();
        AppLogger.i('Cleaned up empty call document for space: $spaceId',
            category: LogCategory.general);
        return true;
      }

      final now = DateTime.now();
      final staleThreshold = now.subtract(const Duration(seconds: 90));

      final activeParticipants = participants.where((p) {
        final lastHeartbeat = p['lastHeartbeat'] as String?;
        if (lastHeartbeat == null) {
          final joinedAt = p['joinedAt'] as String?;
          if (joinedAt != null) {
            try {
              final joinTime = DateTime.parse(joinedAt);
              if (joinTime.isBefore(now.subtract(const Duration(hours: 2)))) {
                AppLogger.w('Removing legacy stale participant: ${p['displayName']}',
                    category: LogCategory.general);
                return false;
              }
            } catch (_) {
              AppLogger.w('GroupCallService: failed to parse joinedAt timestamp',
                  category: LogCategory.general);
            }
          }
          return true;
        }

        try {
          final heartbeatTime = DateTime.parse(lastHeartbeat);
          if (heartbeatTime.isBefore(staleThreshold)) {
            AppLogger.w('Removing stale participant: ${p['displayName']}',
                category: LogCategory.general);
            return false;
          }
        } catch (_) {
          AppLogger.w(
              'GroupCallService: failed to parse heartbeat timestamp during stale check',
              category: LogCategory.general);
        }
        return true;
      }).toList();

      if (activeParticipants.isEmpty) {
        await callRef.delete();
        AppLogger.i('Deleted call with all stale participants for space: $spaceId',
            category: LogCategory.general);
        return true;
      } else if (activeParticipants.length < participants.length) {
        await callRef.update({'participants': activeParticipants});
        AppLogger.i(
            'Removed ${participants.length - activeParticipants.length} stale participants from space: $spaceId',
            category: LogCategory.general);
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.e('Error cleaning up stale call participants',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // Call presence
  // --------------------------------------------------------------------------

  /// Update call presence in Firestore with Agora UID mapping.
  /// Uses transactions to prevent race conditions.
  Future<void> updateCallPresence(
    String spaceId,
    bool joining,
    int? agoraUid,
    String? displayName,
    String? avatarUrl, {
    required String? activeChannelName,
    required bool Function() isInCallCheck,
    required String? Function() activeSpaceIdGetter,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final callRef = _firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active');

      if (joining && agoraUid != null) {
        await _firestore.runTransaction((transaction) async {
          final doc = await transaction.get(callRef);
          final now = DateTime.now();
          final heartbeatTimestamp = now.toIso8601String();

          final newParticipant = {
            'oderId': currentUser.uid,
            'agoraUid': agoraUid,
            'displayName': displayName ?? 'User',
            'avatarUrl': avatarUrl,
            'joinedAt': heartbeatTimestamp,
            'lastHeartbeat': heartbeatTimestamp,
          };

          if (!doc.exists) {
            transaction.set(callRef, {
              'channelName': activeChannelName,
              'startedAt': FieldValue.serverTimestamp(),
              'participants': [newParticipant],
            });
          } else {
            final data = doc.data() ?? {};
            final participantList =
                List<dynamic>.from(data['participants'] ?? []);

            final staleThresholdTime = now.subtract(_staleThreshold);
            participantList.removeWhere((p) {
              if (p['oderId'] == currentUser.uid) return true;

              final lastHeartbeat = p['lastHeartbeat'] as String?;
              if (lastHeartbeat != null) {
                try {
                  final heartbeatTime = DateTime.parse(lastHeartbeat);
                  if (heartbeatTime.isBefore(staleThresholdTime)) {
                    AppLogger.w('Removing stale participant: ${p['displayName']}',
                        category: LogCategory.general);
                    return true;
                  }
                } catch (_) {
                  AppLogger.w(
                      'GroupCallService: failed to parse heartbeat timestamp during join',
                      category: LogCategory.general);
                }
              }
              return false;
            });

            participantList.add(newParticipant);
            transaction.update(callRef, {'participants': participantList});
          }
        });

        // Start heartbeat timer
        _startHeartbeat(spaceId, currentUser.uid,
            isInCallCheck: isInCallCheck,
            activeSpaceIdGetter: activeSpaceIdGetter);

        AppLogger.i('Added to call presence: $displayName (agora: $agoraUid)',
            category: LogCategory.general);
      } else {
        await _firestore.runTransaction((transaction) async {
          final doc = await transaction.get(callRef);
          if (!doc.exists) return;

          final data = doc.data() ?? {};
          final participantList =
              List<dynamic>.from(data['participants'] ?? []);

          final now = DateTime.now();
          final staleThresholdTime = now.subtract(_staleThreshold);

          participantList.removeWhere((p) {
            if (p['oderId'] == currentUser.uid) return true;

            final lastHeartbeat = p['lastHeartbeat'] as String?;
            if (lastHeartbeat != null) {
              try {
                final heartbeatTime = DateTime.parse(lastHeartbeat);
                if (heartbeatTime.isBefore(staleThresholdTime)) {
                  AppLogger.w(
                      'Removing stale participant during leave: ${p['displayName']}',
                      category: LogCategory.general);
                  return true;
                }
              } catch (_) {
                AppLogger.w(
                    'GroupCallService: failed to parse heartbeat timestamp during leave',
                    category: LogCategory.general);
              }
            }
            return false;
          });

          if (participantList.isEmpty) {
            transaction.delete(callRef);
            AppLogger.i('Deleted call record (last participant left)',
                category: LogCategory.general);
          } else {
            transaction.update(callRef, {'participants': participantList});
            AppLogger.i('Removed from call presence', category: LogCategory.general);
          }
        });

        stopHeartbeat();
      }
    } catch (e) {
      AppLogger.e('Error updating call presence',
          category: LogCategory.general, error: e);
    }
  }

  // --------------------------------------------------------------------------
  // Heartbeat
  // --------------------------------------------------------------------------

  void _startHeartbeat(
    String spaceId,
    String oderId, {
    required bool Function() isInCallCheck,
    required String? Function() activeSpaceIdGetter,
  }) {
    stopHeartbeat();

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!isInCallCheck() || activeSpaceIdGetter() != spaceId) {
        stopHeartbeat();
        return;
      }

      try {
        final callRef = _firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('calls')
            .doc('active');

        await _firestore.runTransaction((transaction) async {
          final doc = await transaction.get(callRef);
          if (!doc.exists) return;

          final data = doc.data() ?? {};
          final participantList =
              List<dynamic>.from(data['participants'] ?? []);
          final now = DateTime.now();
          final staleThresholdTime = now.subtract(_staleThreshold);

          bool updated = false;
          final updatedParticipants = participantList.where((p) {
            if (p['oderId'] == oderId) {
              p['lastHeartbeat'] = now.toIso8601String();
              updated = true;
              return true;
            }

            final lastHeartbeat = p['lastHeartbeat'] as String?;
            if (lastHeartbeat != null) {
              try {
                final heartbeatTime = DateTime.parse(lastHeartbeat);
                if (heartbeatTime.isBefore(staleThresholdTime)) {
                  AppLogger.w(
                      'Heartbeat cleanup: removing stale ${p['displayName']}',
                      category: LogCategory.general);
                  return false;
                }
              } catch (_) {
                AppLogger.w(
                    'GroupCallService: failed to parse heartbeat timestamp during cleanup',
                    category: LogCategory.general);
              }
            }
            return true;
          }).toList();

          if (updatedParticipants.isEmpty) {
            transaction.delete(callRef);
          } else if (updated ||
              updatedParticipants.length != participantList.length) {
            transaction.update(callRef, {'participants': updatedParticipants});
          }
        });
      } catch (e) {
        AppLogger.w('Heartbeat update failed', category: LogCategory.general);
      }
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // --------------------------------------------------------------------------
  // Queries
  // --------------------------------------------------------------------------

  Future<bool> hasActiveCall(String spaceId) async {
    try {
      final doc = await _firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active')
          .get();

      if (!doc.exists) return false;
      final data = doc.data();
      final participantList = data?['participants'] as List<dynamic>? ?? [];
      return participantList.isNotEmpty;
    } catch (e) {
      AppLogger.e('Error checking active call',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  Stream<Map<String, dynamic>?> activeCallStream(String spaceId) {
    return _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('calls')
        .doc('active')
        .snapshots()
        .map((doc) => doc.data());
  }

  // --------------------------------------------------------------------------
  // Participant tracking
  // --------------------------------------------------------------------------

  /// Add a remote participant by Agora UID and fetch their info from Firestore.
  void addParticipantAndFetchInfo(int agoraUid, String? activeSpaceId) async {
    participants[agoraUid] = GroupCallParticipant(
      agoraUid: agoraUid,
      oderId: '',
      displayName: 'Connecting...',
    );
    _notifyParticipantsChanged();

    if (activeSpaceId == null) return;

    try {
      final callDoc = await _firestore
          .collection('spaces')
          .doc(activeSpaceId)
          .collection('calls')
          .doc('active')
          .get();

      final data = callDoc.data();
      final participantList = data?['participants'] as List<dynamic>? ?? [];

      for (final p in participantList) {
        if (p['agoraUid'] == agoraUid) {
          participants[agoraUid] = GroupCallParticipant(
            agoraUid: agoraUid,
            oderId: p['oderId'] ?? '',
            displayName: p['displayName'] ?? 'User',
            avatarUrl: p['avatarUrl'],
          );
          _notifyParticipantsChanged();
          AppLogger.i('Fetched participant info: ${p['displayName']}',
              category: LogCategory.general);
          return;
        }
      }

      // Retry after a short delay for race conditions
      await Future.delayed(const Duration(milliseconds: 500));

      final updatedDoc = await _firestore
          .collection('spaces')
          .doc(activeSpaceId)
          .collection('calls')
          .doc('active')
          .get();

      final updatedData = updatedDoc.data();
      final updatedParticipants =
          updatedData?['participants'] as List<dynamic>? ?? [];

      for (final p in updatedParticipants) {
        if (p['agoraUid'] == agoraUid) {
          participants[agoraUid] = GroupCallParticipant(
            agoraUid: agoraUid,
            oderId: p['oderId'] ?? '',
            displayName: p['displayName'] ?? 'User',
            avatarUrl: p['avatarUrl'],
          );
          _notifyParticipantsChanged();
          AppLogger.i('Fetched participant info (retry): ${p['displayName']}',
              category: LogCategory.general);
          return;
        }
      }

      // Still not found
      participants[agoraUid] = GroupCallParticipant(
        agoraUid: agoraUid,
        oderId: '',
        displayName: 'User',
      );
      _notifyParticipantsChanged();
      AppLogger.w('Could not find participant info for agora uid: $agoraUid',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error fetching participant info',
          category: LogCategory.general, error: e);
      participants[agoraUid] = GroupCallParticipant(
        agoraUid: agoraUid,
        oderId: '',
        displayName: 'User',
      );
      _notifyParticipantsChanged();
    }
  }

  void removeParticipant(int uid) {
    final participant = participants[uid];
    if (participant != null) {
      AppLogger.i('Participant left: ${participant.displayName}',
          category: LogCategory.general);
    }
    participants.remove(uid);
    _notifyParticipantsChanged();
  }

  void updateParticipantAudioState(int uid, bool muted) {
    if (participants.containsKey(uid)) {
      participants[uid]!.isAudioMuted = muted;
      _notifyParticipantsChanged();
    }
  }

  void updateParticipantVideoState(int uid, bool muted) {
    if (participants.containsKey(uid)) {
      participants[uid]!.isVideoMuted = muted;
      _notifyParticipantsChanged();
    }
  }

  void _notifyParticipantsChanged() {
    _participantsController.add(participants.values.toList());
  }

  // --------------------------------------------------------------------------
  // Call history
  // --------------------------------------------------------------------------

  /// Save a group call summary to the space's chat messages.
  Future<void> saveCallHistory(
      String spaceId, int duration, int participantCount) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      String senderName = 'User';
      try {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        final userData = userDoc.data();
        if (userData != null) {
          senderName = userData['name'] ?? userData['nickname'] ?? 'User';
        }
      } catch (_) {
        AppLogger.w(
            'GroupCallService: failed to fetch sender name for call summary',
            category: LogCategory.general);
      }

      final durationStr = _formatDuration(duration);
      final content =
          'Group call \u2022 $durationStr \u2022 $participantCount participants';

      await _firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'senderName': senderName,
        'content': content,
        'messageType': 'group_call',
        'callDuration': duration,
        'participantCount': participantCount,
        'reactions': {},
        'readBy': [currentUser.uid],
        'timestamp': FieldValue.serverTimestamp(),
      });

      AppLogger.i('Group call logged to chat: $content',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to save group call history',
          category: LogCategory.general, error: e);
    }
  }

  /// Fetch display name and avatar for the current user.
  Future<({String displayName, String? avatarUrl})> fetchCurrentUserInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return (displayName: 'User', avatarUrl: null);
    }

    String displayName = currentUser.displayName ?? 'User';
    String? avatarUrl;
    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();
      if (userData != null) {
        displayName = userData['name'] ?? userData['nickname'] ?? displayName;
        avatarUrl = userData['imageUrl'];
      }
    } catch (e) {
      AppLogger.w('Failed to fetch user info', category: LogCategory.general);
    }
    return (displayName: displayName, avatarUrl: avatarUrl);
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes < 60) {
      return secs > 0 ? '${minutes}m ${secs}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  /// Clear all local participant state.
  void clearParticipants() {
    participants.clear();
    _notifyParticipantsChanged();
  }

  /// Close the participants stream controller.
  Future<void> dispose() async {
    stopHeartbeat();
    await _participantsController.close();
  }
}
