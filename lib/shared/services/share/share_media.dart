import 'dart:io';
import 'dart:typed_data';
import 'package:aurogram/shared/services/share/share_ui.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';

/// On Android, share-to-Instagram-Story often fails or does nothing (plugin/visibility).
/// Use system share sheet so the user always gets a dialog and can pick Instagram or others.
bool get _useSystemShareSheet =>
    Platform.isAndroid;

class ShareMedia {
  static const String _instagramAppId = '964631802585634';

  /// Capture a widget to image bytes (e.g. for "Add to Story"). Same pipeline as _captureWidgetToFile.
  static Future<Uint8List?> captureWidgetToBytes({
    required Widget card,
  }) async {
    try {
      final screenshotController = ScreenshotController();
      final imageBytes = await screenshotController.captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(
            devicePixelRatio: 3.0,
            textScaler: TextScaler.linear(1.0),
          ),
          child: Material(
            color: Colors.transparent,
            child: card,
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.5,
      );
      return imageBytes;
    } catch (e) {
      AppLogger.e('ShareMedia.captureWidgetToBytes failed', error: e);
      return null;
    }
  }

  static Future<File> _captureWidgetToFile({
    required BuildContext context,
    required Widget card,
    required String filePrefix,
  }) async {
    final screenshotController = ScreenshotController();
    final Uint8List imageBytes = await screenshotController.captureFromWidget(
      MediaQuery(
        data: const MediaQueryData(
          devicePixelRatio: 3.0,
          textScaler: TextScaler.linear(1.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: card,
        ),
      ),
      delay: const Duration(milliseconds: 100),
      pixelRatio: 2.5,
    );

    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(imageBytes);
    return file;
  }

  static Future<void> shareWidgetAsImage({
    required BuildContext context,
    required Widget card,
    required String filePrefix,
    required String shareText,
    String? logLabel,
  }) async {
    try {
      final file = await _captureWidgetToFile(
        context: context,
        card: card,
        filePrefix: filePrefix,
      );

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: shareText),
      );

      Future.delayed(const Duration(seconds: 30), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
    } catch (e) {
      if (context.mounted) {
        ShareUi.showErrorSnackbar(context, 'Failed to share');
      }
      final label = logLabel ?? filePrefix;
      AppLogger.e('Error sharing $label', error: e);
    }
  }

  static Future<void> shareWidgetToInstagramStory({
    required BuildContext context,
    required Widget card,
    required String filePrefix,
    required String shareUrl,
    String backgroundTopColor = '#141726',
    String backgroundBottomColor = '#101421',
    String? logLabel,
  }) async {
    // On Android, use system share sheet so something always happens (Instagram story plugin is unreliable).
    if (_useSystemShareSheet) {
      try {
        final file = await _captureWidgetToFile(
          context: context,
          card: card,
          filePrefix: filePrefix,
        );
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: shareUrl),
        );
        Future.delayed(const Duration(seconds: 30), () {
          if (file.existsSync()) file.deleteSync();
        });
      } catch (e) {
        if (context.mounted) {
          ShareUi.showErrorSnackbar(context, 'Failed to share');
        }
        AppLogger.e('Error sharing ${logLabel ?? filePrefix}', error: e);
      }
      return;
    }

    // iOS: use system share sheet (same as Android)
    try {
      final file = await _captureWidgetToFile(
        context: context,
        card: card,
        filePrefix: filePrefix,
      );
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: shareUrl),
      );
      Future.delayed(const Duration(seconds: 30), () {
        if (file.existsSync()) file.deleteSync();
      });
    } catch (e) {
      final label = logLabel ?? filePrefix;
      AppLogger.e('Error sharing $label to Instagram', error: e);
      if (context.mounted) {
        ShareUi.showErrorSnackbar(context, 'Failed to share to Instagram');
      }
    }
  }
}
