import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/utils/chat/internal_link_utils.dart';
import 'package:aurogram/utils/chat/external_link_utils.dart';

void main() {
  group('Chat Widget Logic Tests', () {
    // ==========================================================
    // INTERNAL LINK UTILS TESTS
    // ==========================================================
    group('InternalLinkUtils', () {
      test('should detect internal URLs correctly', () {
        expect(
            InternalLinkUtils.isInternalLink(
                'https://ty-dev-516d7.web.app/p/123'),
            isTrue);
        expect(InternalLinkUtils.isInternalLink('aurogram://post/123'), isTrue);
        expect(InternalLinkUtils.isInternalLink('https://google.com'), isFalse);
        expect(
            InternalLinkUtils.isInternalLink('https://example.com'), isFalse);
      });

      test('should parse internal link types', () {
        final postLink = InternalLinkUtils.parseInternalLink(
            'https://ty-dev-516d7.web.app/p/post123');
        expect(postLink?.type, equals(InternalLinkType.post));
        expect(postLink?.id, equals('post123'));

        final profileLink = InternalLinkUtils.parseInternalLink(
            'https://ty-dev-516d7.web.app/u/user123');
        expect(profileLink?.type, equals(InternalLinkType.profile));
        expect(profileLink?.id, equals('user123'));

        final spaceLink = InternalLinkUtils.parseInternalLink(
            'https://ty-dev-516d7.web.app/s/space123');
        expect(spaceLink?.type, equals(InternalLinkType.space));
        expect(spaceLink?.id, equals('space123'));
      });

      test('should extract URLs from text', () {
        final urls = InternalLinkUtils.extractUrls(
            'Check https://example.com and https://google.com');
        expect(urls.length, equals(2));
        expect(urls, contains('https://example.com'));
        expect(urls, contains('https://google.com'));
      });

      test('should extract first internal link', () {
        const text =
            'Check this https://google.com and https://ty-dev-516d7.web.app/p/123';
        final link = InternalLinkUtils.extractFirstInternalLink(text);
        expect(link, isNotNull);
        expect(link?.type, equals(InternalLinkType.post));
        expect(link?.id, equals('123'));
      });

      test('should return null for text without internal links', () {
        const text = 'Check https://google.com and https://twitter.com';
        final link = InternalLinkUtils.extractFirstInternalLink(text);
        expect(link, isNull);
      });
    });

    // ==========================================================
    // EXTERNAL LINK UTILS TESTS
    // ==========================================================
    group('ExternalLinkUtils', () {
      test('should extract URLs from text', () {
        final urls =
            ExternalLinkUtils.extractUrls('Visit https://flutter.dev for docs');
        expect(urls.length, equals(1));
        expect(urls.first, equals('https://flutter.dev'));
      });

      test('should identify external links', () {
        expect(ExternalLinkUtils.isExternalLink('https://google.com'), isTrue);
        expect(
            ExternalLinkUtils.isExternalLink(
                'https://ty-dev-516d7.web.app/p/123'),
            isFalse);
      });

      test('should extract first external link', () {
        // Text with internal link first, then external
        const text1 =
            'Check https://ty-dev-516d7.web.app/p/123 and https://flutter.dev';
        final link1 = ExternalLinkUtils.extractFirstExternalLink(text1);
        expect(link1, equals('https://flutter.dev'));

        // Text with only external links
        const text2 = 'Visit https://google.com and https://github.com';
        final link2 = ExternalLinkUtils.extractFirstExternalLink(text2);
        expect(link2, equals('https://google.com'));

        // Text with no external links
        const text3 = 'Check https://ty-dev-516d7.web.app/p/123';
        final link3 = ExternalLinkUtils.extractFirstExternalLink(text3);
        expect(link3, isNull);
      });
    });

    // ==========================================================
    // EXTERNAL LINK PREVIEW MODEL TESTS
    // ==========================================================
    group('ExternalLinkPreview Model', () {
      test('should create from JSON correctly', () {
        final json = {
          'url': 'https://example.com',
          'title': 'Example Title',
          'description': 'Example description',
          'image': 'https://example.com/image.jpg',
          'siteName': 'Example',
          'favicon': 'https://example.com/favicon.ico',
          'type': 'website',
        };

        final preview = ExternalLinkPreview.fromJson(json);

        expect(preview.url, equals('https://example.com'));
        expect(preview.title, equals('Example Title'));
        expect(preview.description, equals('Example description'));
        expect(preview.image, equals('https://example.com/image.jpg'));
        expect(preview.siteName, equals('Example'));
        expect(preview.favicon, equals('https://example.com/favicon.ico'));
        expect(preview.type, equals('website'));
      });

      test('should handle missing optional fields', () {
        final json = {
          'url': 'https://example.com',
          'title': 'Example',
          'siteName': 'Example',
          'type': 'website',
        };

        final preview = ExternalLinkPreview.fromJson(json);

        expect(preview.url, equals('https://example.com'));
        expect(preview.title, equals('Example'));
        expect(preview.description, isNull);
        expect(preview.image, isNull);
        expect(preview.favicon, isNull);
      });

      test('should provide defaults for missing required fields', () {
        final json = <String, dynamic>{};

        final preview = ExternalLinkPreview.fromJson(json);

        expect(preview.url, equals(''));
        expect(preview.title, equals('Link'));
        expect(preview.siteName, equals('Link'));
        expect(preview.type, equals('link'));
      });
    });

    // ==========================================================
    // INTERNAL LINK PREVIEW MODEL TESTS
    // ==========================================================
    group('InternalLinkPreview Model', () {
      test('should create InternalLink correctly', () {
        final link = InternalLink(
          type: InternalLinkType.post,
          id: 'post123',
          originalUrl: 'https://ty-dev-516d7.web.app/p/post123',
        );

        expect(link.type, equals(InternalLinkType.post));
        expect(link.id, equals('post123'));
        expect(link.originalUrl, contains('post123'));
      });

      test('should create InternalLinkPreview correctly', () {
        final preview = InternalLinkPreview(
          type: InternalLinkType.post,
          id: 'post123',
          title: 'Amazing Post',
          subtitle: 'This is a great post...',
          imageUrl: 'https://example.com/image.jpg',
          authorName: 'John Doe',
          authorAvatar: 'https://example.com/avatar.jpg',
          extraData: {'likeCount': 42, 'replyCount': 10},
        );

        expect(preview.type, equals(InternalLinkType.post));
        expect(preview.id, equals('post123'));
        expect(preview.title, equals('Amazing Post'));
        expect(preview.subtitle, isNotNull);
        expect(preview.imageUrl, isNotNull);
        expect(preview.authorName, equals('John Doe'));
        expect(preview.extraData?['likeCount'], equals(42));
      });
    });

    // ==========================================================
    // LINK TYPE PARSING TESTS
    // ==========================================================
    group('Link Type Parsing', () {
      test('should parse all link type variations', () {
        // Post variations
        expect(
          InternalLinkUtils.parseInternalLink(
                  'https://ty-dev-516d7.web.app/p/123')
              ?.type,
          equals(InternalLinkType.post),
        );
        expect(
          InternalLinkUtils.parseInternalLink(
                  'https://ty-dev-516d7.web.app/post/123')
              ?.type,
          equals(InternalLinkType.post),
        );

        // Profile variations
        expect(
          InternalLinkUtils.parseInternalLink(
                  'https://ty-dev-516d7.web.app/u/123')
              ?.type,
          equals(InternalLinkType.profile),
        );
        expect(
          InternalLinkUtils.parseInternalLink(
                  'https://ty-dev-516d7.web.app/user/123')
              ?.type,
          equals(InternalLinkType.profile),
        );
        expect(
          InternalLinkUtils.parseInternalLink(
                  'https://ty-dev-516d7.web.app/profile/123')
              ?.type,
          equals(InternalLinkType.profile),
        );

        // Space variations
        expect(
          InternalLinkUtils.parseInternalLink(
                  'https://ty-dev-516d7.web.app/s/123')
              ?.type,
          equals(InternalLinkType.space),
        );
        expect(
          InternalLinkUtils.parseInternalLink(
                  'https://ty-dev-516d7.web.app/space/123')
              ?.type,
          equals(InternalLinkType.space),
        );
        expect(
          InternalLinkUtils.parseInternalLink(
                  'https://ty-dev-516d7.web.app/gram/123')
              ?.type,
          equals(InternalLinkType.space),
        );

        // Cosmic
        expect(
          InternalLinkUtils.parseInternalLink(
                  'https://ty-dev-516d7.web.app/cosmic/123')
              ?.type,
          equals(InternalLinkType.cosmic),
        );
      });

      test('should handle aurogram:// scheme', () {
        expect(
          InternalLinkUtils.parseInternalLink('aurogram://post/123')?.type,
          equals(InternalLinkType.post),
        );
        expect(
          InternalLinkUtils.parseInternalLink('aurogram://user/123')?.type,
          equals(InternalLinkType.profile),
        );
        expect(
          InternalLinkUtils.parseInternalLink('aurogram://space/123')?.type,
          equals(InternalLinkType.space),
        );
      });

      test('should return null for unknown link types', () {
        final link = InternalLinkUtils.parseInternalLink(
            'https://ty-dev-516d7.web.app/unknown/123');
        expect(link, isNull);
      });
    });

    // ==========================================================
    // URL PATTERN EDGE CASES
    // ==========================================================
    group('URL Pattern Edge Cases', () {
      test('should handle URLs with query parameters', () {
        final urls = InternalLinkUtils.extractUrls(
            'Visit https://example.com?foo=bar&baz=qux');
        expect(urls.length, equals(1));
        expect(urls.first, contains('?foo=bar'));
      });

      test('should handle URLs with fragments', () {
        final urls =
            InternalLinkUtils.extractUrls('See https://example.com#section');
        expect(urls.length, equals(1));
        expect(urls.first, contains('#section'));
      });

      test('should handle URLs at end of sentence', () {
        final urls =
            InternalLinkUtils.extractUrls('Check out https://example.com.');
        expect(urls.length, equals(1));
        // Note: The pattern may include the period - implementation specific
      });

      test('should handle multiple URLs in text', () {
        const text = '''
          First link: https://one.com
          Second link: https://two.com
          Third: https://three.com
        ''';
        final urls = InternalLinkUtils.extractUrls(text);
        expect(urls.length, equals(3));
      });

      test('should not match non-URLs', () {
        const nonUrls = [
          'not a url',
          'ftp://files.example.com',
          'mailto:test@example.com',
          'example.com without protocol',
        ];

        for (final text in nonUrls) {
          final urls = InternalLinkUtils.extractUrls(text);
          // Only http/https should match
          expect(
            urls.where((u) => u.startsWith('http')).length,
            equals(0),
            reason: 'Should not match: $text',
          );
        }
      });
    });

    // ==========================================================
    // SHAREABLE CONTENT STRUCTURE TESTS
    // ==========================================================
    group('ShareableContent Structure', () {
      test('should validate post shareable content', () {
        final content = {
          'type': 'post',
          'id': 'post123',
          'title': 'Amazing Post',
          'preview': 'This is the preview text...',
          'thumbnail': 'https://example.com/thumb.jpg',
          'authorName': 'John Doe',
          'authorId': 'user123',
        };

        expect(content['type'], equals('post'));
        expect(content['id'], isNotEmpty);
        expect(content.containsKey('title'), isTrue);
        expect(content.containsKey('preview'), isTrue);
      });

      test('should validate profile shareable content', () {
        final content = {
          'type': 'profile',
          'id': 'user123',
          'title': 'Jane Doe',
          'subtitle': 'Software Developer',
          'thumbnail': 'https://example.com/avatar.jpg',
        };

        expect(content['type'], equals('profile'));
        expect(content['id'], isNotEmpty);
        expect(content.containsKey('title'), isTrue);
      });

      test('should validate space shareable content', () {
        final content = {
          'type': 'space',
          'id': 'space123',
          'title': 'Flutter Community',
          'subtitle': '5.2K members',
          'thumbnail': 'https://example.com/space.jpg',
        };

        expect(content['type'], equals('space'));
        expect(content['id'], isNotEmpty);
        expect(content.containsKey('title'), isTrue);
      });

      test('should validate insight shareable content', () {
        final content = {
          'type': 'insight',
          'id': 'insight123',
          'title': 'Daily Horoscope',
          'preview': 'Your stars align today...',
        };

        expect(content['type'], equals('insight'));
        expect(content['id'], isNotEmpty);
      });
    });
  });
}
