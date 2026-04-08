import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Utility class to generate missing assets
class AssetGenerator {
  /// Generate and save default assets to the application's documents directory
  static Future<void> generateDefaultAssets() async {
    try {
      final missingAssets = await _checkMissingAssets();
      if (missingAssets.isEmpty) {
        AppLogger.i('All required assets are present',
            category: LogCategory.performance);
        return;
      }

      // Get the application's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final String assetsPath = '${directory.path}/generated_assets';

      // Create the directory if it doesn't exist
      final assetDir = Directory(assetsPath);
      if (!await assetDir.exists()) {
        await assetDir.create(recursive: true);
        AppLogger.d('Created directory for generated assets',
            category: LogCategory.performance, data: {'path': assetsPath});
      }

      // Generate each missing asset
      for (final asset in missingAssets) {
        final assetName = asset.split('/').last;
        final savePath = '$assetsPath/$assetName';

        AppLogger.d('Generating asset',
            category: LogCategory.performance,
            data: {'asset': asset, 'savePath': savePath});

        // Generate the appropriate asset
        Uint8List? imageData;
        if (asset.contains('logo.png')) {
          imageData = await _generateLogo();
        } else if (asset.contains('placeholder.png')) {
          imageData = await _generatePlaceholder();
        } else if (asset.contains('error.png')) {
          imageData = await _generateErrorImage();
        } else if (asset.contains('user.png')) {
          imageData = await _generateUserAvatar();
        } else {
          // Default placeholder for unknown types
          imageData = await _generatePlaceholder();
        }

        if (imageData != null) {
          // Save the generated image
          final file = File(savePath);
          await file.writeAsBytes(imageData);

          AppLogger.i('Generated and saved asset',
              category: LogCategory.performance,
              data: {'asset': asset, 'path': savePath});
        }
      }
    } catch (e) {
      AppLogger.e('Failed to generate default assets',
          category: LogCategory.performance, error: e);
    }
  }

  /// Check which required assets are missing
  static Future<List<String>> _checkMissingAssets() async {
    final requiredAssets = [
      'assets/images/logo.png',
      'assets/images/placeholder.png',
      'assets/images/error.png',
      'assets/images/user.png',
    ];

    final missingAssets = <String>[];

    for (final asset in requiredAssets) {
      try {
        await rootBundle.load(asset);
      } catch (e) {
        missingAssets.add(asset);
      }
    }

    return missingAssets;
  }

  /// Generate a logo image
  static Future<Uint8List?> _generateLogo() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(200, 200);

      // Background
      final bgPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 100, bgPaint);

      // Text
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 48,
        fontWeight: FontWeight.bold,
      ))
        ..pushStyle(ui.TextStyle(color: Colors.white))
        ..addText('T');
      final paragraph = builder.build();
      paragraph.layout(ui.ParagraphConstraints(width: size.width));
      canvas.drawParagraph(
          paragraph,
          Offset(size.width / 2 - paragraph.width / 2,
              size.height / 2 - paragraph.height / 2));

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      AppLogger.e('Error generating logo',
          category: LogCategory.performance, error: e);
      return null;
    }
  }

  /// Generate a placeholder image
  static Future<Uint8List?> _generatePlaceholder() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(200, 200);

      // Gray background
      final bgPaint = Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // Draw image icon
      final iconPaint = Paint()
        ..color = Colors.grey[700]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8;

      // Draw a simple picture frame icon
      final rect = Rect.fromLTWH(50, 50, 100, 80);
      canvas.drawRect(rect, iconPaint);

      // Draw a triangle for "mountain"
      final path = Path();
      path.moveTo(70, 100);
      path.lineTo(90, 70);
      path.lineTo(110, 100);
      path.close();
      canvas.drawPath(path, iconPaint);

      // Draw a circle for "sun"
      canvas.drawCircle(Offset(120, 70), 10, iconPaint);

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      AppLogger.e('Error generating placeholder',
          category: LogCategory.performance, error: e);
      return null;
    }
  }

  /// Generate an error image
  static Future<Uint8List?> _generateErrorImage() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(200, 200);

      // Background
      final bgPaint = Paint()
        ..color = Colors.red[100]!
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // Draw error icon
      final iconPaint = Paint()
        ..color = Colors.red[700]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8;

      // Draw a circle with X
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 70, iconPaint);
      canvas.drawLine(
        Offset(size.width / 2 - 40, size.height / 2 - 40),
        Offset(size.width / 2 + 40, size.height / 2 + 40),
        iconPaint,
      );
      canvas.drawLine(
        Offset(size.width / 2 - 40, size.height / 2 + 40),
        Offset(size.width / 2 + 40, size.height / 2 - 40),
        iconPaint,
      );

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      AppLogger.e('Error generating error image',
          category: LogCategory.performance, error: e);
      return null;
    }
  }

  /// Generate a user avatar
  static Future<Uint8List?> _generateUserAvatar() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(200, 200);

      // Background
      final bgPaint = Paint()
        ..color = Colors.blue[100]!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 100, bgPaint);

      // Draw person icon
      final iconPaint = Paint()
        ..color = Colors.blue[700]!
        ..style = PaintingStyle.fill;

      // Head
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2 - 20), 30, iconPaint);

      // Body
      final bodyPath = Path();
      bodyPath.moveTo(size.width / 2, size.height / 2 + 10);
      bodyPath.addOval(Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2 + 60),
        width: 80,
        height: 80,
      ));
      canvas.drawPath(bodyPath, iconPaint);

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      AppLogger.e('Error generating user avatar',
          category: LogCategory.performance, error: e);
      return null;
    }
  }
}
