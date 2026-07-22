// Yoni Tribe mapping — each of the 27 nakshatras belongs to one of 14 tribes,
// derived from the Vedic yoni (animal) compatibility system but using a curated
// set of noble animals that feel universally dignified.
//
// Classic yoni → Noble upgrade rationale:
//   Mouse  → Peacock   (Magha = throne/royalty; P.Phalguni = beauty/charm)
//   Dog    → Wolf      (same canine family, elevated)
//   Cow    → Bull      (Nandi, Shiva's sacred mount — sacred & powerful)
//   Buffalo→ Eagle     (Swati = air/independence, Hasta = skill/Garuda energy)
//   Cat    → Panther   (same feline, more striking)
//   Monkey → Monkey    (kept — Hanuman association makes it noble in Indian context)
//   Goat   → Ram       (already noble form of same animal)
//   Deer   → Stag      (antlered, regal form)
//
// Storage: Firebase Storage — gs://ty-dev-516d7.appspot.com/yoni_tribes/{animal}.png
//          All 14 PNGs are uploaded; /yoni_tribes/{file} allows public read
//          (see backend/storage.rules) so no auth token is needed to render them.

import 'package:aurogram/features/astrology/data/utils/nakshatra_data.dart';

/// One of the 14 yoni tribes. Each tribe owns 1–2 nakshatras.
class YoniTribe {
  /// Lowercase identifier — matches the filename in Firebase Storage.
  final String animal;

  /// Human-readable name shown in UI.
  final String displayName;

  /// The classic Vedic yoni animal this replaces (for reference/compatibility logic).
  final String classicYoni;

  /// 0-based nakshatra indices from [NakshatraData.all] that belong to this tribe.
  /// All 27 nakshatras are covered; Uttara Ashadha (20) is the only singleton.
  final List<int> nakshatras;

  const YoniTribe({
    required this.animal,
    required this.displayName,
    required this.classicYoni,
    required this.nakshatras,
  });

  /// Firebase Storage public URL.
  /// Requires storage rule: `allow read: if true` for `/yoni_tribes/**`.
  String get imageUrl =>
      'https://firebasestorage.googleapis.com/v0/b/'
      'ty-dev-516d7.appspot.com/o/'
      'yoni_tribes%2F$animal.webp?alt=media';

  /// Local asset path (only valid if assets/yoni/ is bundled — not recommended
  /// for production due to image size; use [imageUrl] instead).
  String get localAsset => 'assets/yoni/$animal.webp';

  @override
  String toString() => 'YoniTribe($displayName)';
}

/// Central lookup for the 14 yoni tribes and their nakshatra assignments.
class YoniTribeData {
  YoniTribeData._();

  // Nakshatra index reference (from NakshatraData.all):
  //  0 Ashwini      1 Bharani       2 Krittika      3 Rohini
  //  4 Mrigashira   5 Ardra         6 Punarvasu     7 Pushya
  //  8 Ashlesha     9 Magha        10 Purva Phalguni 11 Uttara Phalguni
  // 12 Hasta        13 Chitra       14 Swati         15 Vishakha
  // 16 Anuradha     17 Jyeshtha     18 Mula          19 Purva Ashadha
  // 20 Uttara Ashadha 21 Shravana   22 Dhanishtha    23 Shatabhisha
  // 24 Purva Bhadrapada 25 Uttara Bhadrapada 26 Revati

  static const List<YoniTribe> all = [
    YoniTribe(
      animal: 'horse',
      displayName: 'Horse',
      classicYoni: 'Horse',
      nakshatras: [0, 23], // Ashwini, Shatabhisha
    ),
    YoniTribe(
      animal: 'elephant',
      displayName: 'Elephant',
      classicYoni: 'Elephant',
      nakshatras: [1, 26], // Bharani, Revati
    ),
    YoniTribe(
      animal: 'ram',
      displayName: 'Ram',
      classicYoni: 'Goat',
      nakshatras: [2, 7], // Krittika, Pushya
    ),
    YoniTribe(
      animal: 'cobra',
      displayName: 'Cobra',
      classicYoni: 'Serpent',
      nakshatras: [3, 4], // Rohini, Mrigashira
    ),
    YoniTribe(
      animal: 'wolf',
      displayName: 'Wolf',
      classicYoni: 'Dog',
      nakshatras: [5, 18], // Ardra, Mula
    ),
    YoniTribe(
      animal: 'panther',
      displayName: 'Panther',
      classicYoni: 'Cat',
      nakshatras: [6, 8], // Punarvasu, Ashlesha
    ),
    YoniTribe(
      animal: 'peacock',
      displayName: 'Peacock',
      classicYoni: 'Mouse',
      nakshatras: [9, 10], // Magha, Purva Phalguni
    ),
    YoniTribe(
      animal: 'bull',
      displayName: 'Bull',
      classicYoni: 'Cow',
      nakshatras: [11, 25], // Uttara Phalguni, Uttara Bhadrapada
    ),
    YoniTribe(
      animal: 'eagle',
      displayName: 'Eagle',
      classicYoni: 'Buffalo',
      nakshatras: [12, 14], // Hasta, Swati
    ),
    YoniTribe(
      animal: 'tiger',
      displayName: 'Tiger',
      classicYoni: 'Tiger',
      nakshatras: [13, 15], // Chitra, Vishakha
    ),
    YoniTribe(
      animal: 'stag',
      displayName: 'Stag',
      classicYoni: 'Deer',
      nakshatras: [16, 17], // Anuradha, Jyeshtha
    ),
    YoniTribe(
      animal: 'monkey',
      displayName: 'Monkey',
      classicYoni: 'Monkey',
      nakshatras: [19, 21], // Purva Ashadha, Shravana
    ),
    YoniTribe(
      animal: 'mongoose',
      displayName: 'Mongoose',
      classicYoni: 'Mongoose',
      nakshatras: [20], // Uttara Ashadha — the only singleton tribe
    ),
    YoniTribe(
      animal: 'lion',
      displayName: 'Lion',
      classicYoni: 'Lion',
      nakshatras: [22, 24], // Dhanishtha, Purva Bhadrapada
    ),
  ];

  /// Fast reverse lookup: nakshatra index (0-26) → tribe.
  /// Built once and reused.
  static final Map<int, YoniTribe> _byNakshatra = {
    for (final tribe in all)
      for (final idx in tribe.nakshatras) idx: tribe,
  };

  /// Returns the tribe for a given nakshatra index (0-26), or null if out of range.
  static YoniTribe? forNakshatraIndex(int index) => _byNakshatra[index];

  /// Returns the tribe for a named nakshatra using [NakshatraData.findIndex],
  /// which handles spelling variants and regional aliases (e.g. "Moola" → Mula).
  /// Returns null if the name is unrecognised.
  static YoniTribe? forNakshatraName(String? name) {
    final index = NakshatraData.findIndex(name);
    if (index < 0) return null;
    return forNakshatraIndex(index);
  }

  /// Returns the tribe for an animal key, e.g. 'lion'.
  static YoniTribe? forAnimal(String? animal) {
    if (animal == null || animal.isEmpty) return null;
    try {
      return all.firstWhere((t) => t.animal == animal.toLowerCase());
    } catch (_) {
      return null;
    }
  }
}
