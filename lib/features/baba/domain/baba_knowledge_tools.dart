import 'package:aurogram/features/baba/domain/baba_knowledge_service.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// Baba's grounded lookup of the Vedic astrology + Ayurveda CANON.
///
/// WHY: the meanings of signs, planets, dashas, yogas, nakshatras and doshas
/// must come from a curated source, not the model's parametric memory (which is
/// generic and sometimes wrong - the reason readings felt "off"). Rather than
/// stuff the whole canon into the CX prompt (token budget) or pay for a cloud
/// data store, Baba PULLS the 1-2 relevant curated snippets on demand.
///
/// This is a KNOWLEDGE tool (general meanings), distinct from `getMyChart`
/// (the user's OWN chart facts). Use getMyChart for "what's MY rising sign",
/// use lookupKnowledge for "what DOES a Leo rising mean".
class BabaKnowledgeTools {
  BabaKnowledgeTools._();

  static const String lookupKnowledge = 'lookupKnowledge';

  static BabaTool declaration() => BabaTool(
        name: lookupKnowledge,
        description:
            'Look up the canonical MEANING of a Vedic astrology or Ayurveda '
            'concept - a sign/rashi, planet/graha, dasha, yoga, nakshatra, '
            'ascendant, or dosha (vata/pitta/kapha). Call this BEFORE '
            'explaining any such concept and answer FROM the returned summary '
            "rather than your own memory. Use the user's OWN chart facts from "
            'getMyChart to know WHICH concepts to look up (e.g. their moon '
            'sign, their current dasha lord), then look up what each means.',
        parameters: const {
          'type': 'object',
          'properties': {
            'topic': {
              'type': 'string',
              'description':
                  'The concept to explain, e.g. "Leo", "Saturn dasha", '
                  '"vata dosha", "Gaja Kesari yoga", "nakshatra".',
            },
          },
          'required': ['topic'],
        },
        defaultHandler: (args) async {
          final topic = (args['topic'] as String?)?.trim() ?? '';
          if (topic.isEmpty) {
            return {'ok': false, 'reason': 'no topic given'};
          }
          final results = await BabaKnowledgeService.instance.lookup(topic);
          if (results.isEmpty) {
            return {
              'ok': true,
              'found': false,
              'topic': topic,
              'hint':
                  'No canonical entry - explain briefly in your own words and '
                  'offer to go deeper on their chart.',
            };
          }
          return {'ok': true, 'found': true, 'topic': topic, 'entries': results};
        },
      );
}
