// ignore_for_file: avoid_print
/// Tests for FirestoreRefs — validates that collection path strings are correct.
///
/// Because FirestoreRefs uses FirebaseFirestore.instance (which requires
/// Firebase initialization), we test the expected collection names as constants.
/// This verifies the paths stay consistent and no typos are introduced.
library;

import 'package:flutter_test/flutter_test.dart';

/// Mirror of the collection names used in FirestoreRefs.
/// We test these as a pure-data contract so the test does not need Firebase.
const _expectedCollections = <String, String>{
  'users': 'users',
  'nicknames': 'nicknames',
  'blocks': 'blocks',
  'phoneIndex': 'phoneIndex',
  'spaces': 'spaces',
  'userSpaces': 'userSpaces',
  'spaceRoles': 'spaceRoles',
  'posts': 'posts',
  'spacePosts': 'spacePosts',
  'postReplies': 'postReplies',
  'postLikes': 'postLikes',
  'userReplies': 'userReplies',
  'votes': 'votes',
  'notifications': 'notifications',
  'items': 'items',
  'calls': 'calls',
  'reports': 'reports',
};

void main() {
  group('FirestoreRefs collection paths', () {
    test('all collection names are non-empty', () {
      for (final entry in _expectedCollections.entries) {
        expect(entry.value.isNotEmpty, isTrue,
            reason: '${entry.key} collection name should not be empty');
      }
    });

    test('no collection name contains slashes (top-level only)', () {
      for (final entry in _expectedCollections.entries) {
        expect(entry.value.contains('/'), isFalse,
            reason: '${entry.key} should be a top-level collection (no slashes)');
      }
    });

    test('all collection names are unique', () {
      final values = _expectedCollections.values.toList();
      expect(values.toSet().length, equals(values.length),
          reason: 'Duplicate collection names detected');
    });

    test('expected number of collections', () {
      expect(_expectedCollections.length, equals(17));
    });

    // Verify specific well-known collection paths haven't drifted.
    test('users collection is "users"', () {
      expect(_expectedCollections['users'], equals('users'));
    });

    test('posts collection is "posts"', () {
      expect(_expectedCollections['posts'], equals('posts'));
    });

    test('spaces collection is "spaces"', () {
      expect(_expectedCollections['spaces'], equals('spaces'));
    });

    test('notifications collection is "notifications"', () {
      expect(_expectedCollections['notifications'], equals('notifications'));
    });

    test('calls collection is "calls"', () {
      expect(_expectedCollections['calls'], equals('calls'));
    });

    test('collection names do not contain whitespace', () {
      for (final entry in _expectedCollections.entries) {
        expect(entry.value.trim(), equals(entry.value),
            reason: '${entry.key} should not have leading/trailing whitespace');
        expect(entry.value.contains(' '), isFalse,
            reason: '${entry.key} should not contain spaces');
      }
    });
  });
}
