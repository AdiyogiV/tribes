import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/pages/spaces/spaceScreen.dart';
import 'package:aurogram/pages/tabs/userProfile.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/widgets/previewBoxes/userPreviewBox.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class SpaceInviteTile extends StatefulWidget {
  final String? space;
  final String? inviter;
  final Function? onRefresh;

  const SpaceInviteTile({this.space, this.inviter, this.onRefresh, Key? key})
      : super(key: key);

  @override
  _SpaceInviteTileState createState() => _SpaceInviteTileState();
}

class _SpaceInviteTileState extends State<SpaceInviteTile> {
  String name = 'Unknown Space';
  String username = 'Unknown User';
  File? spacePicture;
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
          final cacheService = locator<CacheService>();
          spacePicture = await cacheService.getFile(spaceDoc.displayPicture!);
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.0),
        child: Container(
          child: (spacePicture == null)
              ? AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color: AppTheme.scaffoldLightColor,
                  ),
                )
              : AspectRatio(
                  aspectRatio: 1,
                  child: Image.file(
                    spacePicture!,
                    fit: BoxFit.cover,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SkeletonListItem(height: 80),
      );
    }

    return Container(
      padding: EdgeInsets.all(8),
      child: Material(
        borderRadius: BorderRadius.circular(10),
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
                      fontSize: 14,
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
