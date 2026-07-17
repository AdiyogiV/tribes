import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:aurogram/core/logging/app_logger.dart';

/// Baba's grounded knowledge base: a curated Vedic astrology + Ayurveda canon
/// bundled as an asset (`assets/baba/knowledge.json`) and retrieved at runtime.
///
/// ## Why local-asset RAG (not a cloud data store)
/// The domain vocabulary is FINITE and well-structured (12 signs, 9 grahas, 27
/// nakshatras, 3 doshas, a handful of yogas + concepts). Curated keyword
/// retrieval over that beats fuzzy embeddings for precision and NEVER
/// hallucinates a meaning. And it costs nothing per query - no Vertex AI Search
/// bill, no embeddings API, no Firestore reads (which are App-Check-blocked for
/// guests anyway). If we ever outgrow curation, this same `lookup` seam can be
/// swapped for a Vertex data store without touching the tool or the playbook.
///
/// Loaded once, lazily; cached for the app's lifetime.
class BabaKnowledgeService {
  BabaKnowledgeService._();
  static final BabaKnowledgeService instance = BabaKnowledgeService._();

  static const _assetPath = 'assets/baba/knowledge.json';

  List<_Entry>? _entries;

  /// Load + index the canon once. Safe to call repeatedly.
  Future<void> ensureLoaded() async {
    if (_entries != null) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = (json['entries'] as List?) ?? const [];
      _entries = list
          .whereType<Map<String, dynamic>>()
          .map(_Entry.fromJson)
          .toList(growable: false);
      AppLogger.i('BabaKnowledge: loaded ${_entries!.length} entries',
          category: LogCategory.general);
    } catch (e) {
      // Never let a missing/broken asset crash Baba - he just falls back to his
      // own words for that turn.
      AppLogger.w('BabaKnowledge: load failed: $e',
          category: LogCategory.general);
      _entries = const [];
    }
  }

  /// Retrieve the best-matching canon entries for a free-text [query]
  /// (e.g. "leo", "what is vata", "saturn dasha", "gaja kesari").
  /// Returns at most [max] entries, highest relevance first, or empty if none
  /// clear the relevance bar.
  Future<List<Map<String, dynamic>>> lookup(String query, {int max = 2}) async {
    await ensureLoaded();
    final entries = _entries;
    if (entries == null || entries.isEmpty) return const [];

    final tokens = _tokenize(query);
    if (tokens.isEmpty) return const [];
    final q = tokens.join(' ');

    final scored = <_Scored>[];
    for (final e in entries) {
      final score = e.score(q, tokens);
      if (score > 0) scored.add(_Scored(e, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored
        .take(max)
        .map((s) => s.entry.toResult())
        .toList(growable: false);
  }

  static List<String> _tokenize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && !_stop.contains(t))
      .toList(growable: false);

  // Tiny stop-list so "what is the meaning of vata" still targets "vata".
  static const _stop = {
    'a', 'an', 'the', 'is', 'are', 'what', 'whats', 'of', 'my', 'me', 'mean',
    'means', 'meaning', 'about', 'tell', 'in', 'to', 'for', 'and', 'kya', 'hai',
    'ka', 'ki', 'ke', 'ko', 'mera', 'meri', 'batao', 'kaun',
  };
}

class _Entry {
  _Entry({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.aliases,
  });

  final String id;
  final String category;
  final String title;
  final String summary;
  final List<String> aliases; // lowercased

  factory _Entry.fromJson(Map<String, dynamic> j) => _Entry(
        id: (j['id'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
        aliases: ((j['aliases'] as List?) ?? const [])
            .map((a) => a.toString().toLowerCase())
            .toList(growable: false),
      );

  /// Relevance of this entry to a normalised query [q] and its [tokens].
  int score(String q, List<String> tokens) {
    var score = 0;
    for (final alias in aliases) {
      // Whole-query or query-contains-alias is the strongest signal (longer
      // alias = more specific = higher).
      if (q == alias) return 100 + alias.length;
      if (q.contains(alias)) score += 20 + alias.length;
      // A single token exactly equal to an alias (e.g. "leo").
      if (tokens.contains(alias)) score += 15;
    }
    // Fall back to title-word overlap for fuzzier queries.
    final titleLc = title.toLowerCase();
    for (final t in tokens) {
      if (t.length >= 3 && titleLc.contains(t)) score += 3;
    }
    return score;
  }

  Map<String, dynamic> toResult() => {
        'id': id,
        'category': category,
        'title': title,
        'summary': summary,
      };
}

class _Scored {
  _Scored(this.entry, this.score);
  final _Entry entry;
  final int score;
}
