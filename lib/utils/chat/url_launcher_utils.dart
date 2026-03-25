import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class UrlLauncherUtils {
  static Future<void> launchURL(String url, BuildContext context) async {
    try {
      // Validate and process URL
      String processedUrl = url.trim();
      if (processedUrl.isEmpty) {
        _showUrlError('Invalid link', context);
        return;
      }

      // Ensure URL has a proper scheme
      if (!processedUrl.startsWith('http://') &&
          !processedUrl.startsWith('https://') &&
          !processedUrl.startsWith('mailto:') &&
          !processedUrl.startsWith('tel:') &&
          !processedUrl.startsWith('ftp://')) {
        if (processedUrl.contains('@')) {
          processedUrl = 'mailto:$processedUrl';
        } else if (processedUrl.startsWith('www.')) {
          processedUrl = 'https://$processedUrl';
        } else {
          // Check if it looks like a domain
          if (RegExp(
                  r'^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}')
              .hasMatch(processedUrl)) {
            processedUrl = 'https://$processedUrl';
          } else {
            // Assume it's a search query or invalid URL
            _showUrlError('Invalid link format', context);
            return;
          }
        }
      }

      final uri = Uri.parse(processedUrl);

      // Additional validation
      if (!uri.hasScheme || uri.host.isEmpty) {
        _showUrlError('Invalid link format', context);
        return;
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );

        // Link opened silently - modern apps don't show feedback for this
        if (context.mounted) {
          HapticFeedback.lightImpact();
        }
      } else {
        _showUrlError('Cannot open this link', context);
      }
    } catch (e) {
      AppLogger.e('URL launch error: $e');
      if (context.mounted) {
        _showUrlError('Failed to open link: ${e.toString()}', context);
      }
    }
  }

  static void _showUrlError(String message, BuildContext context) {
    // Log error instead of showing intrusive snackbar
    AppLogger.e('URL launch failed: $message', category: LogCategory.general);
  }
}
