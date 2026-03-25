import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:aurogram/utils/chat/url_launcher_utils.dart';
import 'package:aurogram/models/thought_process.dart';

class MarkdownUtils {
  /// Web-safe font family stack for regular text
  static String get _webSafeFontFamily => kIsWeb
      ? '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif'
      : '';

  /// Web-safe monospace font family stack
  static String get _webSafeMonoFontFamily => kIsWeb
      ? 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace'
      : 'monospace';

  static Widget buildRichContent(String content, BuildContext context,
      {List<SearchResult>? sources, Color? textColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final bodyColor = textColor ?? colorScheme.onSurface;

    // Build markdown widget - works on both web and mobile
    final markdownWidget = MarkdownBody(
      data: content,
      selectable:
          kIsWeb, // Enable native selection on web, use SelectionArea on mobile
      extensionSet: md.ExtensionSet.gitHubFlavored,
      // Removed CitationSyntax - using natural source references instead
      onTapLink: (text, href, title) {
        if (href != null) {
          // Handle source-1, source-2 etc links
          if (href.startsWith('source-') && sources != null) {
            final sourceIndex =
                int.tryParse(href.substring(7)); // Remove 'source-'
            if (sourceIndex != null &&
                sourceIndex > 0 &&
                sourceIndex <= sources.length) {
              final source = sources[sourceIndex - 1];
              UrlLauncherUtils.launchURL(source.link, context);
              return;
            }
          }
          // Handle regular URLs
          UrlLauncherUtils.launchURL(href, context);
        }
      },
      styleSheet: MarkdownStyleSheet(
        // Paragraph styling optimized for AI responses
        p: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: bodyColor,
        ),
        pPadding: const EdgeInsets.only(bottom: 12),

        // Headers with proper hierarchy and spacing
        h1: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: bodyColor,
          height: 1.3,
        ),
        h1Padding: const EdgeInsets.only(top: 16, bottom: 12),

        h2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: bodyColor,
          height: 1.3,
        ),
        h2Padding: const EdgeInsets.only(top: 20, bottom: 12),

        h3: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: 1.3,
        ),
        h3Padding: const EdgeInsets.only(top: 16, bottom: 10),

        h4: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: 1.3,
        ),
        h4Padding: const EdgeInsets.only(top: 10, bottom: 6),

        h5: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: 1.3,
        ),
        h5Padding: const EdgeInsets.only(top: 8, bottom: 4),

        h6: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: bodyColor.withValues(alpha: 0.8),
          height: 1.3,
        ),
        h6Padding: const EdgeInsets.only(top: 6, bottom: 4),

        // List styling optimized for AI bullet points
        listBullet: TextStyle(
          fontSize: 16,
          color: textColor ?? colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        listIndent: 20,

        // Optimized list spacing to match AI output format
        unorderedListAlign: WrapAlignment.start,
        orderedListAlign: WrapAlignment.start,

        // Inline code styling - use web-safe monospace font
        code: TextStyle(
          backgroundColor: isDark
              ? colorScheme.surface.withValues(alpha: 0.3)
              : colorScheme.surface.withValues(alpha: 0.8),
          color: textColor ?? colorScheme.primary,
          fontFamily: _webSafeMonoFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),

        // Code block decoration
        codeblockDecoration: BoxDecoration(
          color: isDark
              ? colorScheme.surface.withValues(alpha: 0.4)
              : colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        codeblockPadding: const EdgeInsets.all(16),

        // Blockquote styling
        blockquote: TextStyle(
          color: bodyColor.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
          fontSize: 16,
          height: 1.4,
        ),
        blockquotePadding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        blockquoteDecoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: textColor ?? colorScheme.primary,
              width: 4,
            ),
          ),
        ),

        // Table styling
        tableHead: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: bodyColor,
        ),
        tableBody: TextStyle(
          fontSize: 14,
          color: bodyColor,
        ),
        tableBorder: TableBorder.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
        tableHeadAlign: TextAlign.start,
        tableCellsPadding: const EdgeInsets.all(8),

        // Link styling - make links more visible
        a: TextStyle(
          color: textColor ?? colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor:
              (textColor ?? colorScheme.primary).withValues(alpha: 0.8),
          fontWeight: FontWeight.w600, // Make links bolder
        ),

        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),

        // Strong/bold text
        strong: TextStyle(
          fontWeight: FontWeight.bold,
          color: bodyColor,
        ),

        // Emphasized/italic text
        em: TextStyle(
          fontStyle: FontStyle.italic,
          color: bodyColor,
        ),
      ),
      builders: {
        'code': CodeBlockBuilder(context: context),
        // Removed citation builder - using natural source references
      },
    );

    // On mobile, wrap with SelectionArea for better text selection UX
    // On web, the markdown widget handles selection natively (selectable: true)
    if (kIsWeb) {
      return markdownWidget;
    }
    return SelectionArea(
      child: markdownWidget,
    );
  }

  static Widget buildCodeBlock(
      String code, String? language, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.4)
            : colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language != null && language.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      language.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildCopyButton(code, context),
                ],
              ),
            ),
          SelectableText(
            code,
            style: TextStyle(
              fontFamily: _webSafeMonoFontFamily,
              fontSize: 14,
              color: colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCopyButton(String code, BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          // Code copied silently with haptic feedback
          HapticFeedback.lightImpact();
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            Icons.copy,
            size: 16,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  CodeBlockBuilder({required this.context});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String code = element.textContent;
    final String? language =
        element.attributes['class']?.replaceFirst('language-', '');

    return MarkdownUtils.buildCodeBlock(code, language, context);
  }
}

// Citation functionality removed - now using natural source references in text
// Sources are shown in the sources section below the message
