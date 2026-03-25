import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/services/feed_service.dart';

/// Unit tests for FeedService
/// Note: These test the FeedItem data model. Full integration tests 
/// require Firebase mocking.
void main() {
  group('FeedItem', () {
    test('toJson serializes correctly', () {
      final item = FeedItem(
        postId: 'post123',
        timestamp: DateTime(2024, 1, 15, 10, 30),
        source: 'space',
        sourceId: 'space456',
      );

      final json = item.toJson();

      expect(json['postId'], 'post123');
      expect(json['source'], 'space');
      expect(json['sourceId'], 'space456');
      expect(json['timestamp'], isA<int>());
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'postId': 'post789',
        'timestamp': DateTime(2024, 1, 15, 10, 30).millisecondsSinceEpoch,
        'source': 'profile',
        'sourceId': 'user123',
      };

      final item = FeedItem.fromJson(json);

      expect(item.postId, 'post789');
      expect(item.source, 'profile');
      expect(item.sourceId, 'user123');
      expect(item.timestamp.year, 2024);
      expect(item.timestamp.month, 1);
      expect(item.timestamp.day, 15);
    });

    test('fromJson handles null sourceId', () {
      final json = {
        'postId': 'globalPost',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'source': 'global',
        'sourceId': null,
      };

      final item = FeedItem.fromJson(json);

      expect(item.postId, 'globalPost');
      expect(item.source, 'global');
      expect(item.sourceId, isNull);
    });

    test('roundtrip serialization preserves data', () {
      final original = FeedItem(
        postId: 'test123',
        timestamp: DateTime.now(),
        source: 'space',
        sourceId: 'spaceABC',
      );

      final json = original.toJson();
      final restored = FeedItem.fromJson(json);

      expect(restored.postId, original.postId);
      expect(restored.source, original.source);
      expect(restored.sourceId, original.sourceId);
      // Timestamps may differ by milliseconds due to serialization
      expect(
        restored.timestamp.difference(original.timestamp).inSeconds.abs(),
        lessThan(1),
      );
    });
  });

  group('FeedService singleton', () {
    // Note: FeedService uses Firebase, so singleton test requires Firebase initialization
    // This test is skipped in unit tests - covered by integration tests
    test('returns same instance', () {
      // Skip: Requires Firebase initialization
      // In a real app, FeedService() returns the same singleton instance
    }, skip: 'Requires Firebase initialization');
  });
}
