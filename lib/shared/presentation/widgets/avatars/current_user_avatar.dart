import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';

/// A convenience widget that displays the current user's avatar
/// Automatically handles authentication state and provides consistent styling
class CurrentUserAvatar extends StatefulWidget {
  /// Size of the avatar (width and height)
  final double size;

  /// Whether to show a border around the avatar
  final bool showBorder;

  /// Color of the border if shown
  final Color? borderColor;

  /// Border radius - defaults to circular
  final BorderRadius? borderRadius;

  /// What to do when the avatar is tapped
  final VoidCallback? onTap;

  /// Whether to show a loading state while fetching user data
  final bool showLoading;

  const CurrentUserAvatar({
    super.key,
    this.size = 40,
    this.showBorder = true,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.showLoading = true,
  });

  @override
  _CurrentUserAvatarState createState() => _CurrentUserAvatarState();
}

class _CurrentUserAvatarState extends State<CurrentUserAvatar> {
  User? _currentUser;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();

    // Listen for auth state changes - but only actual changes to the user login state
    // not profile picture or other property changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      // Compare only the UID to avoid unnecessary rebuilds for other user property changes
      if (mounted && (_currentUser?.uid != user?.uid)) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (mounted && !_isInitialized) {
      setState(() {
        _currentUser = user;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use key to prevent unnecessary rebuilds
    final key = _currentUser != null
        ? ValueKey('current_user_avatar_${_currentUser!.uid}_${widget.size}')
        : ValueKey('guest_avatar_${widget.size}');

    if (_currentUser == null) {
      return _buildGuestAvatar(key);
    }

    return GestureDetector(
      key: key,
      onTap: widget.onTap,
      child: UserAvatar.fromUserId(
        userId: _currentUser!.uid,
        size: widget.size,
        showBorder: widget.showBorder,
        borderColor: widget.borderColor ??
            Theme.of(context).primaryColor.withValues(alpha: 178),
        borderRadius: widget.borderRadius,
      ),
    );
  }

  Widget _buildGuestAvatar(Key key) {
    return GestureDetector(
      key: key,
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: widget.borderRadius == null
              ? BoxShape.circle
              : BoxShape.rectangle,
          borderRadius: widget.borderRadius,
          border: widget.showBorder
              ? Border.all(
                  color: widget.borderColor ??
                      Theme.of(context).primaryColor.withValues(alpha: 178),
                  width: 1.5,
                )
              : null,
          color: Colors.grey[300],
        ),
        child: widget.showLoading
            ? null  // Empty placeholder, no spinner
            : Icon(
                Icons.person,
                color: Colors.grey[600],
                size: widget.size * 0.6,
              ),
      ),
    );
  }
}
