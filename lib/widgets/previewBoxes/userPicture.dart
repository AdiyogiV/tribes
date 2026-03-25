import 'dart:io';
import 'package:aurogram/services/cache_service.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/dependency_injection.dart';

class UserPicture extends StatefulWidget {
  final String? displayPicture;
  @override
  final Key? key;

  const UserPicture({@required this.displayPicture, this.key}) : super(key: key);

  @override
  _UserPictureState createState() => _UserPictureState();
}

class _UserPictureState extends State<UserPicture> {
  File? userPicture;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
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
              : Container(),
        ),
      ),
    );
  }
}
