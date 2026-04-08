import 'dart:io';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/services/cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:aurogram/core/di/injection.dart';

class UserPicture extends StatefulWidget {
  final String? displayPicture;
  @override
  final Key? key;

  const UserPicture({required this.displayPicture, this.key}) : super(key: key);

  @override
  _UserPictureState createState() => _UserPictureState();
}

class _UserPictureState extends State<UserPicture> {
  File? userPicture;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // On web, use CachedNetworkImage directly, no need to load file
    if (!kIsWeb) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.displayPicture != null && widget.displayPicture!.isNotEmpty) {
      setState(() {
        isLoading = true;
      });

      final cacheService = locator<CacheService>();
      userPicture = await cacheService.getFile(widget.displayPicture!);

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // On web, use CachedNetworkImage directly
    if (kIsWeb) {
      return Padding(
        padding: const EdgeInsets.all(5.0),
        child: Material(
          elevation: 2,
          shape: CircleBorder(),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: AspectRatio(
            aspectRatio: 1,
            child: widget.displayPicture != null && widget.displayPicture!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.displayPicture!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: AppTheme.skeletonLightColor, // Warm skeleton color
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.skeletonLightColor,
                      child: const Icon(Icons.person, color: Color(0xFFBDBDBD)),
                    ),
                  )
                : Container(
                    color: AppTheme.skeletonLightColor,
                    child: const Icon(Icons.person, color: Color(0xFFBDBDBD)),
                  ),
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Material(
        elevation: 2,
        shape: CircleBorder(),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: AspectRatio(
          aspectRatio: 1,
          child: (userPicture != null)
              ? Image.file(
                  userPicture!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : Container(
                  color: AppTheme.skeletonLightColor, // Warm skeleton color
                  child: const Icon(Icons.person, color: Color(0xFFBDBDBD)),
                ),
        ),
      ),
    );
  }
}
