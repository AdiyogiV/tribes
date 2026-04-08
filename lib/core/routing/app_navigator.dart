import 'package:flutter/cupertino.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Routes defined for the application
class AppRoutes {
  // Main tabs
  static const String home = '/';
  static const String profile = '/profile';
  static const String spaces = '/spaces';

  // Authentication
  static const String login = '/login';
  static const String signup = '/signup';

  // Content
  static const String spaceDetail = '/space';
  static const String postDetail = '/post';
  static const String userProfile = '/user';
  static const String invites = '/invites';
  static const String requests = '/requests';
  static const String notifications = '/notifications';

  // Settings
  static const String settings = '/settings';
}

/// A service for handling navigation throughout the app
class AppNavigator {
  final GlobalKey<NavigatorState> _navigatorKey;

  /// Creates a new AppNavigator
  AppNavigator(this._navigatorKey);

  /// Gets the navigator state
  NavigatorState? get _navigator => _navigatorKey.currentState;

  /// Gets the current context
  BuildContext? get context => _navigatorKey.currentContext;

  /// Navigates to a named route
  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) async {
    AppLogger.d('Navigating to $routeName', category: LogCategory.navigation);
    return _navigator?.pushNamed<T>(routeName, arguments: arguments);
  }

  /// Replaces the current route with a new one
  Future<T?> replaceTo<T>(String routeName, {Object? arguments}) async {
    AppLogger.d('Replacing with $routeName', category: LogCategory.navigation);
    return _navigator?.pushReplacementNamed<T, dynamic>(routeName,
        arguments: arguments);
  }

  /// Clears the navigation stack and shows the given route
  Future<T?> resetTo<T>(String routeName, {Object? arguments}) async {
    AppLogger.d('Resetting to $routeName', category: LogCategory.navigation);
    return _navigator?.pushNamedAndRemoveUntil<T>(routeName, (route) => false,
        arguments: arguments);
  }

  /// Goes back to the previous screen
  void goBack<T>({T? result}) {
    AppLogger.d('Navigating back', category: LogCategory.navigation);
    return _navigator?.pop<T>(result);
  }

  /// Navigates to a route using CupertinoPageRoute
  Future<T?> push<T>(Widget page, {String? routeName}) async {
    final name = routeName ?? page.runtimeType.toString();
    AppLogger.d('Pushing page $name', category: LogCategory.navigation);

    return _navigator?.push<T>(
      CupertinoPageRoute(
        builder: (context) => page,
        settings: RouteSettings(name: name),
      ),
    );
  }

  /// Replaces the current route with a new page
  Future<T?> replace<T>(Widget page, {String? routeName}) async {
    final name = routeName ?? page.runtimeType.toString();
    AppLogger.d('Replacing with page $name', category: LogCategory.navigation);

    return _navigator?.pushReplacement<T, dynamic>(
      CupertinoPageRoute(
        builder: (context) => page,
        settings: RouteSettings(name: name),
      ),
    );
  }

  /// Goes back to a specific route
  void popUntil(String routeName) {
    AppLogger.d('Popping until $routeName', category: LogCategory.navigation);
    _navigator?.popUntil(ModalRoute.withName(routeName));
  }
}
