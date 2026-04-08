import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/features/spaces/presentation/pages/space_screen.dart';
import 'package:aurogram/features/profile/presentation/pages/user_profile.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/features/spaces/domain/space_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/user_preview_box.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class SpaceInviteTile extends StatefulWidget {
  final String? space;
  final String? inviter;
  final Function? onRefresh;

  const SpaceInviteTile({this.space, this.inviter, this.onRefresh, super.key});

  @override
  _SpaceInviteTileState createState() => _SpaceInviteTileState();
}

class _SpaceInviteTileState extends State<SpaceInviteTile> {
  String name = 'Unknown Space';
  String username = 'Unknown User';
  File? spacePicture;
  String? spacePictureUrl; // For web
  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');
  User? user = FirebaseAuth.instance.currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      if (widget.inviter != null) {
        DocumentSnapshot userDocument =
            await DatabaseService().getUser(widget.inviter!);
        username = userDocument.get('name') as String? ?? 'Unknown User';
      }

      if (widget.space != null) {
        final spaceService = locator<SpaceService>();
        Space spaceDoc = await spaceService.getSpace(widget.space!);
        name = spaceDoc.name ?? 'Unknown Space';
        if (spaceDoc.displayPicture != null) {
          spacePictureUrl = spaceDoc.displayPicture; // Store URL for web
          if (!kIsWeb) {
            final cacheService = locator<CacheService>();
            spacePicture = await cacheService.getFile(spaceDoc.displayPicture!);
          }
        }
      }
    } catch (e) {
      AppLogger.e('Error fetching space invite data',
          category: LogCategory.general, data: {'error': e.toString()});
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget getGramPicture() {
    Widget imageWidget;
    
    if (kIsWeb && spacePictureUrl != null && spacePictureUrl!.isNotEmpty) {
      // Web: use CachedNetworkImage
      imageWidget = CachedNetworkImage(
        imageUrl: spacePictureUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: AppTheme.scaffoldLightColor),
        errorWidget: (context, url, error) => Container(color: AppTheme.scaffoldLightColor),
      );
    } else if (!kIsWeb && spacePicture != null) {
      // Mobile: use Image.file
      imageWidget = Image.file(
        spacePicture!,
        fit: BoxFit.cover,
      );
    } else {
      // Placeholder
      imageWidget = Container(color: AppTheme.scaffoldLightColor);
    }
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.0),
        child: AspectRatio(
          aspectRatio: 1,
          child: imageWidget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.paddingSm),
        child: SkeletonListItem(height: 80),
      );
    }

    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingSm),
      child: Material(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
        elevation: 1,
        color: AppTheme.scaffoldLightColor,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  if (widget.inviter != null) {
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return UserProfilePage(uid: widget.inviter);
                    }));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: UserPreview(uid: widget.inviter),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "$username invited you to join $name",
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: AppTheme.holyCowTextSize,
                      color: AppTheme.textLightColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  if (widget.space != null) {
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return SpaceScreen(rid: widget.space!);
                    }));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: getGramPicture(),
                ),
              ),
            ),
            SizedBox(height: 50, width: 10),
            Container(
                color: AppTheme.textSecondaryLightColor.withValues(alpha: 0.5),
                height: 50,
                width: 0.5),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  if (widget.space != null && user != null) {
                    await DatabaseService()
                        .approveSpaceMember(widget.space!, user!.uid);
                    await widget.onRefresh?.call();
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return SpaceScreen(rid: widget.space!);
                    }));
                  }
                },
                child: Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 30,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  if (widget.space != null && user != null) {
                    await DatabaseService()
                        .rejectSpaceMember(widget.space!, user!.uid);
                    await widget.onRefresh?.call();
                  }
                },
                child: Icon(
                  Icons.cancel,
                  color: AppTheme.errorColor,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
