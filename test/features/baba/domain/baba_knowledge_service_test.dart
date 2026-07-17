import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/features/baba/domain/baba_knowledge_service.dart';

/// Locks the grounded-knowledge retrieval: the bundled canon loads and the
/// keyword scorer returns the RIGHT curated entry for natural queries, so Baba
/// answers meanings from canon (not invention). Uses the real asset via the
/// test asset bundle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final svc = BabaKnowledgeService.instance;

  test('exact concept name resolves to its entry', () async {
    final r = await svc.lookup('leo');
    expect(r, isNotEmpty);
    expect(r.first['id'], 'leo');
    expect(r.first['category'], 'sign');
    expect((r.first['summary'] as String).toLowerCase(), contains('sun'));
  });

  test('natural-language query targets the concept through stop-words',
      () async {
    final r = await svc.lookup('what is the meaning of vata dosha');
    expect(r.first['id'], 'vata');
    expect(r.first['category'], 'dosha');
  });

  test('multi-word concept (Saturn dasha) surfaces Saturn', () async {
    final r = await svc.lookup('saturn dasha');
    expect(r.map((e) => e['id']), contains('saturn'));
  });

  test('yoga names resolve', () async {
    final r = await svc.lookup('gaja kesari yoga');
    expect(r.first['id'], 'gaja_kesari');
  });

  test('a Sanskrit alias resolves (mesha -> aries)', () async {
    final r = await svc.lookup('mesha');
    expect(r.first['id'], 'aries');
  });

  test('unknown topic returns empty (Baba falls back to own words)', () async {
    final r = await svc.lookup('quarterly sales report');
    expect(r, isEmpty);
  });
}
