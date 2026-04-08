import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/models/call.dart';

// ── Page imports (centralized — services must NOT import these) ────────────
import 'package:aurogram/features/astrology/presentation/pages/daily_insight_page.dart';
import 'package:aurogram/features/feed/presentation/pages/thread_view.dart';
import 'package:aurogram/features/spaces/presentation/pages/space_screen.dart';
import 'package:aurogram/features/spaces/presentation/pages/space_chat_screen.dart';
import 'package:aurogram/features/profile/presentation/pages/user_profile.dart';
import 'package:aurogram/features/profile/presentation/pages/social/invites.dart';
import 'package:aurogram/features/profile/presentation/pages/social/requests.dart';
import 'package:aurogram/features/calling/presentation/pages/group_call_screen.dart';
import 'package:aurogram/features/calling/presentation/pages/incoming_call_screen.dart'
    if (dart.library.html) 'package:aurogram/pages/call/incoming_call_screen_stub.dart';
import 'package:aurogram/features/calling/presentation/pages/call_screen.dart'
    if (dart.library.html) 'package:aurogram/pages/call/call_screen_stub.dart';
import 'package:aurogram/features/anonymous_messages/pages/inbox_screen.dart';

/// Builds a [Route] for the given [routeName] and [arguments].
///
/// This is the ONLY file that should import page widgets.
/// Services navigate by calling:
///   `navigatorKey.currentState!.push(PageFactory.route(RouteNames.x, args));`
class PageFactory {
  PageFactory._();

  /// Build a MaterialPageRoute (or CupertinoPageRoute for calls) from a route name.
  static Route<dynamic> route(String routeName, {Object? arguments}) {
    final args = arguments is Map<String, dynamic> ? arguments : <String, dynamic>{};

    switch (routeName) {
      case RouteNames.userProfile:
        return MaterialPageRoute(
          builder: (_) => UserProfilePage(uid: args['uid'] as String?),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.spaceScreen:
        return MaterialPageRoute(
          builder: (_) => SpaceScreen(
            rid: args['rid'] as String? ?? args['spaceId'] as String? ?? '',
            postId: args['postId'] as String?,
          ),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.spaceChatScreen:
        return MaterialPageRoute(
          builder: (_) => SpaceChatScreen(
            spaceId: args['spaceId'] as String? ?? '',
            space: args['space'],
            otherUserId: args['otherUserId'] as String?,
          ),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.threadView:
        return MaterialPageRoute(
          builder: (_) => ThreadView(postId: args['postId'] as String? ?? ''),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.dailyInsight:
        return MaterialPageRoute(
          builder: (_) => DailyInsightPage(
            uid: args['uid'] as String? ?? '',
            highlightCardIndex: args['cardIndex'] as int?,
            insightDate: args['insightDate'] as String?,
          ),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.callScreen:
        return CupertinoPageRoute(
          builder: (_) => CallScreen(
            calleeId: args['calleeId'] as String? ?? '',
            calleeName: args['calleeName'] as String? ?? '',
            calleeAvatar: args['calleeAvatar'] as String?,
            callType: args['callType'] as CallType? ?? CallType.voice,
            isIncoming: args['isIncoming'] as bool? ?? false,
          ),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.incomingCall:
        return CupertinoPageRoute(
          builder: (_) => IncomingCallScreen(call: args['call']),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.groupCall:
        return CupertinoPageRoute(
          builder: (_) => GroupCallScreen(
            spaceId: args['spaceId'] as String? ?? '',
            spaceName: args['spaceName'] as String? ?? 'Group Call',
          ),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.invites:
        return MaterialPageRoute(
          builder: (_) => const Invites(),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.requests:
        return MaterialPageRoute(
          builder: (_) => Requests(space: args['space'] as String?),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      case RouteNames.secretMessagesInbox:
        return MaterialPageRoute(
          builder: (_) => const SecretMessagesInboxScreen(),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: $routeName')),
          ),
          settings: RouteSettings(name: routeName, arguments: arguments),
        );
    }
  }
}
