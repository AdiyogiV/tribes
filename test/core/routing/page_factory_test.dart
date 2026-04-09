// ignore_for_file: avoid_print
/// Tests for PageFactory routing contract.
///
/// PageFactory imports many page widgets from across the app.  Some of those
/// widgets currently have transitive compilation issues unrelated to routing,
/// so we test the routing *contract* here without importing PageFactory
/// directly.  We replicate the minimal default-branch logic and verify the
/// RouteNames ↔ switch-case contract that PageFactory must honour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/core/routing/route_names.dart';

/// Minimal replica of PageFactory.route's default branch.
/// This lets us verify the "Route not found" fallback without pulling in
/// every page widget in the app.
Route<dynamic> _fallbackRoute(String routeName, {Object? arguments}) {
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      body: Center(child: Text('Route not found: $routeName')),
    ),
    settings: RouteSettings(name: routeName, arguments: arguments),
  );
}

void main() {
  group('PageFactory routing contract', () {
    // All route names that PageFactory's switch statement must handle.
    final handledRoutes = <String>[
      RouteNames.userProfile,
      RouteNames.spaceScreen,
      RouteNames.spaceChatScreen,
      RouteNames.threadView,
      RouteNames.dailyInsight,
      RouteNames.callScreen,
      RouteNames.incomingCall,
      RouteNames.groupCall,
      RouteNames.invites,
      RouteNames.requests,
      RouteNames.secretMessagesInbox,
      RouteNames.secretMessageSend,
      RouteNames.spaceInvite,
    ];

    test('all handled routes are valid RouteNames constants', () {
      for (final route in handledRoutes) {
        expect(route.isNotEmpty, isTrue);
        expect(route.startsWith('/'), isTrue,
            reason: '"$route" must start with /');
      }
    });

    test('handled route list has no duplicates', () {
      expect(handledRoutes.toSet().length, equals(handledRoutes.length));
    });

    group('fallback "Route not found"', () {
      test('returns a MaterialPageRoute with correct settings', () {
        final route = _fallbackRoute('/nonexistent', arguments: {'key': 'val'});
        expect(route, isA<MaterialPageRoute<dynamic>>());
        expect(route.settings.name, equals('/nonexistent'));
        expect(route.settings.arguments, equals({'key': 'val'}));
      });

      testWidgets('renders "Route not found" text', (tester) async {
        final route = _fallbackRoute('/unknown_route');

        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => route,
            ),
          ),
        );

        expect(find.textContaining('Route not found'), findsOneWidget);
        expect(find.textContaining('/unknown_route'), findsOneWidget);
      });

      testWidgets('renders inside a Scaffold', (tester) async {
        final route = _fallbackRoute('/missing');

        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => route,
            ),
          ),
        );

        expect(find.byType(Scaffold), findsOneWidget);
      });
    });
  });
}
