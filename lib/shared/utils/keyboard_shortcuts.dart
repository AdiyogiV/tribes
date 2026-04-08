import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom intents for app-wide keyboard shortcuts
class SwitchTabIntent extends Intent {
  final int tabIndex;
  const SwitchTabIntent(this.tabIndex);
}

class GoBackIntent extends Intent {
  const GoBackIntent();
}

class NewPostIntent extends Intent {
  const NewPostIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}

/// Keyboard shortcuts configuration for desktop web
class AppShortcuts {
  AppShortcuts._();

  /// Whether to enable keyboard shortcuts (only on web)
  static bool get isEnabled => kIsWeb;

  /// Get the shortcuts map for the app
  static Map<ShortcutActivator, Intent> get shortcuts {
    if (!isEnabled) return {};

    return {
      // Tab navigation with Cmd/Ctrl + 1-5
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.digit1,
      ): const SwitchTabIntent(0),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.digit1,
      ): const SwitchTabIntent(0),

      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.digit2,
      ): const SwitchTabIntent(1),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.digit2,
      ): const SwitchTabIntent(1),

      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.digit3,
      ): const SwitchTabIntent(2),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.digit3,
      ): const SwitchTabIntent(2),

      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.digit4,
      ): const SwitchTabIntent(3),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.digit4,
      ): const SwitchTabIntent(3),

      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.digit5,
      ): const SwitchTabIntent(4),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.digit5,
      ): const SwitchTabIntent(4),

      // Go back with Escape
      const SingleActivator(LogicalKeyboardKey.escape): const GoBackIntent(),

      // Refresh with Cmd/Ctrl + R (prevent browser refresh)
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyR,
      ): const RefreshIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyR,
      ): const RefreshIntent(),

      // Search with Cmd/Ctrl + K
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyK,
      ): const SearchIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyK,
      ): const SearchIntent(),

      // New post with Cmd/Ctrl + N
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyN,
      ): const NewPostIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyN,
      ): const NewPostIntent(),
    };
  }

  /// Wrap a widget with keyboard shortcut handling
  static Widget wrapWithShortcuts({
    required Widget child,
    required void Function(int) onSwitchTab,
    VoidCallback? onGoBack,
    VoidCallback? onNewPost,
    VoidCallback? onSearch,
    VoidCallback? onRefresh,
  }) {
    if (!isEnabled) return child;

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          SwitchTabIntent: CallbackAction<SwitchTabIntent>(
            onInvoke: (intent) {
              onSwitchTab(intent.tabIndex);
              return null;
            },
          ),
          GoBackIntent: CallbackAction<GoBackIntent>(
            onInvoke: (intent) {
              onGoBack?.call();
              return null;
            },
          ),
          NewPostIntent: CallbackAction<NewPostIntent>(
            onInvoke: (intent) {
              onNewPost?.call();
              return null;
            },
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (intent) {
              onSearch?.call();
              return null;
            },
          ),
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (intent) {
              onRefresh?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
