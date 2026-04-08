import 'package:flutter/material.dart';

/// Provides whether the bottom tab bar is currently hidden (e.g. when scrolling down in feed).
/// Used so Feed can position the scroll-to-top chevron above safe area when bar is hidden.
class BottomBarVisibilityScope extends InheritedWidget {
  const BottomBarVisibilityScope({
    super.key,
    required this.barHidden,
    required super.child,
  });

  final bool barHidden;

  static BottomBarVisibilityScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BottomBarVisibilityScope>();
  }

  @override
  bool updateShouldNotify(BottomBarVisibilityScope oldWidget) {
    return oldWidget.barHidden != barHidden;
  }
}
