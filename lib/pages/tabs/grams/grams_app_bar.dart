import 'package:flutter/material.dart';
import 'package:aurogram/pages/uploads/uploads_page.dart';
import 'package:aurogram/services/media/media_compression_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Upload indicator badge that shows active upload count.
class GramsUploadIndicator extends StatelessWidget {
  const GramsUploadIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: MediaCompressionService().getUploadProgress(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final activeUploads = snapshot.data
                ?.where((item) =>
                    item['status'] != 'completed' &&
                    item['status'] != 'failed' &&
                    item['status'] != 'cancelled')
                .length ??
            0;

        if (activeUploads > 0) {
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => UploadsPage()),
              );
            },
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingSm),
              child: Badge(
                label: Text(
                  activeUploads.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                backgroundColor: AppTheme.errorColor,
                child: Icon(
                  Icons.cloud_upload_outlined,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// Builds the SliverAppBar for the mobile grams page.
SliverAppBar buildGramsSliverAppBar({
  required BuildContext context,
  required bool isRefreshing,
  required bool hasUser,
  required VoidCallback onShowCreationDialog,
  required VoidCallback onShowInvites,
}) {
  Widget uploadIndicator = FutureBuilder<List<Map<String, dynamic>>>(
    future: MediaCompressionService().getUploadProgress(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox.shrink();
      }

      final activeUploads = snapshot.data
              ?.where((item) =>
                  item['status'] != 'completed' &&
                  item['status'] != 'failed' &&
                  item['status'] != 'cancelled')
              .length ??
          0;

      if (activeUploads > 0) {
        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => UploadsPage()),
            );
          },
          child: Badge(
            label: Text(
              activeUploads.toString(),
              style: TextStyle(
                  color: AppTheme.scaffoldLightColor, fontSize: 10),
            ),
            backgroundColor: AppTheme.errorColor,
            child: Icon(
              Icons.cloud_upload,
              color: AppTheme.primaryColor,
              size: AppHeaderStyle.headerIconSize,
            ),
          ),
        );
      }

      return const SizedBox.shrink();
    },
  );

  Widget actionButtons = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Invites icon button
      IconButton(
        onPressed: onShowInvites,
        icon: Icon(
          Icons.card_giftcard,
          color: AppTheme.primaryColor,
          size: AppHeaderStyle.headerIconSize,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: 'Gram Invites',
      ),
      const SizedBox(width: AppDimensions.spacingXs),
      uploadIndicator,
      if (uploadIndicator is! SizedBox) const SizedBox(width: AppDimensions.spacingXs),
    ],
  );

  // Plus button moved to left side
  Widget? leadingButton;
  if (hasUser) {
    leadingButton = AppHeaderStyle.buildCreateButton(
      label: "Gram",
      onPressed: onShowCreationDialog,
      simpleIcon: true,
    );
  }

  return AppHeaderStyle.buildStandardHeader(
    context: context,
    title: 'sub-grams',
    actionButton: actionButtons,
    leadingWidget: leadingButton ?? const SizedBox.shrink(),
    showSearchField: false,
    isRefreshing: isRefreshing,
  );
}
