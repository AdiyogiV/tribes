import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/user_service.dart';

class UserPreview extends StatefulWidget {
  final String? uid;
  final bool? showName;

  const UserPreview({this.uid, this.showName, super.key});
  @override
  _UserPreviewState createState() => _UserPreviewState();
}

class _UserPreviewState extends State<UserPreview> {
  String? imageUrl;
  String name = '';
  String username = 'user';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.uid != null && widget.uid!.isNotEmpty) {
      getData();
    }
  }

  // Make sure we don't refetch data if the user ID didn't change
  @override
  void didUpdateWidget(UserPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uid != oldWidget.uid) {
      if (widget.uid != null && widget.uid!.isNotEmpty) {
        getData();
      } else {
        // Reset if uid is null or empty
        if (mounted) {
          setState(() {
            imageUrl = null;
            name = '';
            username = 'user';
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> getData() async {
    try {
      final userService = locator<UserService>();
      final displayName = await userService.getUserDisplayName(widget.uid!);

      // Fetch user document for avatar and other data
      DocumentSnapshot authorDocuments = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      if (mounted) {
        final newName = displayName;
        final userData = authorDocuments.exists
            ? authorDocuments.data() as Map<String, dynamic>?
            : null;
        final newUsername = userData?['nickname'] as String? ?? 'user';
        final newImageUrl = userData?['displayPicture'] as String? ?? '';

        // Only update state if data actually changed
        if (name != newName ||
            username != newUsername ||
            imageUrl != newImageUrl) {
          setState(() {
            name = newName;
            username = newUsername;
            imageUrl = newImageUrl;
            isLoading = false;
          });
        } else if (isLoading) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Error fetching user data',
          category: LogCategory.general, data: {'error': e.toString()});
      if (mounted) {
        setState(() {
          // Use generic fallback instead of "Deleted User" on errors
          // getUserDisplayName already handles deleted users correctly
          name = 'User';
          isLoading = false;
        });
      }
    }
  }

  TextStyle getTextStyleWithShadow(BuildContext context) {
    return TextStyle(
      color: AppTheme.textDarkColor,
      fontWeight: FontWeight.w500,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use key to prevent unnecessary rebuilds
    final key = widget.uid != null
        ? ValueKey('user_preview_${widget.uid}_${widget.showName}')
        : ValueKey('user_preview_unknown_${widget.showName}');

    return Padding(
      key: key,
      padding: const EdgeInsets.all(5.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: () {
          final children = <Widget>[
            UserAvatar(
              key: ValueKey('avatar_in_preview_${widget.uid}'),
              userId: widget.uid,
              imageUrl: imageUrl,
              size: 40,
              showBorder: true,
              borderColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              nameInitials: name.isNotEmpty ? name.substring(0, 1) : null,
            ),
            const SizedBox(
              width: 7,
            ),
          ];

          if (widget.showName == true) {
            children.add(
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    name,
                    style: getTextStyleWithShadow(context),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }

          return children;
        }(),
      ),
    );
  }
}
