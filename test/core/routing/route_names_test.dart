// ignore_for_file: avoid_print
/// Tests for RouteNames constants — validates uniqueness, non-emptiness,
/// and correct '/' prefix for all route name constants.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/core/routing/route_names.dart';

void main() {
  // Collect all route name constants in a single map so we can verify
  // properties across all of them without missing newly-added routes.
  final allRoutes = <String, String>{
    'home': RouteNames.home,
    'profile': RouteNames.profile,
    'spaces': RouteNames.spaces,
    'login': RouteNames.login,
    'signup': RouteNames.signup,
    'userProfile': RouteNames.userProfile,
    'spaceScreen': RouteNames.spaceScreen,
    'spaceChatScreen': RouteNames.spaceChatScreen,
    'threadView': RouteNames.threadView,
    'dailyInsight': RouteNames.dailyInsight,
    'callScreen': RouteNames.callScreen,
    'incomingCall': RouteNames.incomingCall,
    'groupCall': RouteNames.groupCall,
    'invites': RouteNames.invites,
    'requests': RouteNames.requests,
    'secretMessagesInbox': RouteNames.secretMessagesInbox,
    'secretMessageSend': RouteNames.secretMessageSend,
    'spaceInvite': RouteNames.spaceInvite,
    'storyComposer': RouteNames.storyComposer,
    'notifications': RouteNames.notifications,
    'settings': RouteNames.settings,
  };

  group('RouteNames', () {
    test('all route names are non-empty', () {
      for (final entry in allRoutes.entries) {
        expect(entry.value.isNotEmpty, isTrue,
            reason: '${entry.key} should not be empty');
      }
    });

    test('all route names start with "/"', () {
      for (final entry in allRoutes.entries) {
        expect(entry.value.startsWith('/'), isTrue,
            reason: '${entry.key} ("${entry.value}") should start with "/"');
      }
    });

    test('all route name values are unique', () {
      final values = allRoutes.values.toList();
      final uniqueValues = values.toSet();
      expect(uniqueValues.length, equals(values.length),
          reason: 'Duplicate route names detected: '
              '${values.where((v) => values.indexOf(v) != values.lastIndexOf(v)).toSet()}');
    });

    test('contains expected number of routes', () {
      // Sanity check — update this when new routes are added so we don't
      // forget to add them to the allRoutes map above.
      expect(allRoutes.length, equals(21));
    });

    test('specific well-known routes have correct values', () {
      expect(RouteNames.home, equals('/'));
      expect(RouteNames.login, equals('/login'));
      expect(RouteNames.profile, equals('/profile'));
      expect(RouteNames.settings, equals('/settings'));
    });
  });
}
